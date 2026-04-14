# Task 4 Code Review — L1 Schema Test + run-tests.sh Entry

**Reviewer**: Senior Code Reviewer (Opus 4.6)
**Date**: 2026-04-14
**Scope**: `tests/schema/test-extension.sh`, `tools/run-tests.sh`
**Base → Head**: `ef58e93` → `f87073b`
**Plan ref**: `docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` §Task 4 (L260–L366)

---

## Verdict

**CHANGES REQUESTED** — 0 Critical / 2 Important / 4 Minor.

Core behavior is correct and passes on the current HEAD. Two Important issues center on environment robustness (yq flavor) and regex precision (GEMINI.md import pattern). Scripts otherwise cleanly follow drllm-core v2 §0 Robust Design Principles.

---

## What Was Done Well

1. **Fail-fast discipline is consistent**: both scripts start with `set -euo pipefail` and a dedicated `fail()` helper that writes to **stderr** before `exit 1`. This aligns with §0-5 (Fail loud) and makes CI integration straightforward — non-zero exit + meaningful stderr is exactly what a test runner should produce.
2. **Clear stage banners in `run-tests.sh`** (`=== L1 Schema ===`, `=== L2 Hooks: SKIP ===`, etc.) give the operator an at-a-glance layered view, matching spec §8's 5-tier test strategy terminology.
3. **Graceful SKIP logic for L2/L3** is the right call for the current scaffolding state — the triple AND (`command -v bats`, `-d tests/hooks`, glob check) means the runner never fails on absence of not-yet-implemented layers, preserving the "auto-green until real tests exist" property.
4. **Defensive skills directory guard** (`if [ -d skills ] && [ "$(ls -A skills 2>/dev/null)" ]`) prevents an empty-glob `skills/*/SKILL.md` from producing a literal path when `nullglob` is off.
5. **Spec alignment**: both scripts are near-verbatim implementations of the plan, with no unexplained deviation. Commit message (`feat: DRLLM v0.1 extension skeleton`) matches spec §7.2 Commit Point 1.
6. **Runtime-verified**: invoking `./tools/run-tests.sh` on HEAD produces `L1 schema: PASS` + `Automated tests: PASS`, confirming all paths wire up against real repo layout.

---

## Issues

### Important

#### I1. `grep` regex in GEMINI.md import check is too permissive

**File**: `/home/namykim/workspace/DRLLM/tests/schema/test-extension.sh` L13

```bash
grep -q '^@\./context/drllm-core\.md' GEMINI.md
```

**Problem**: this pattern matches **any line starting with** `@./context/drllm-core.md`, including:

- `@./context/drllm-core.md/evil` (verified: MATCHES)
- `@./context/drllm-core.md-extra` (verified: MATCHES)
- `@./context/drllm-core.md.bak`

So a typo-mutated or malicious import path would silently pass L1. Since Task 4's stated role is "every-commit sanity check," tightening this is defensible.

**Recommendation**: anchor the tail with whitespace/EOL.

```bash
# Accepts exact line, or path followed by space/tab (trailing comment).
grep -Eq '^@\./context/drllm-core\.md([[:space:]]|$)' GEMINI.md \
  || fail "GEMINI.md must @import context/drllm-core.md"
```

**Severity rationale**: not critical because the current `GEMINI.md` contains the clean form on L5, but regression surface exists the moment anyone edits GEMINI.md.

---

#### I2. `yq` flavor dependency is undocumented and unguarded

**File**: `/home/namykim/workspace/DRLLM/tests/schema/test-extension.sh` L30

```bash
echo "$front" | yq -e '.name and .description' > /dev/null
```

**Problem**: the `-e` flag plus `.name and .description` boolean expression is **mikefarah yq v4** syntax (confirmed working against `/snap/bin/yq` v4.x on the dev host). On Ubuntu/Debian systems where users `apt install yq`, they receive **kislyuk python-yq**, which is a `jq` wrapper with different semantics — `-e` exists but the boolean composition returns different truthiness and can silently pass *or* crash with a Python traceback. Either mode produces a confusing failure unrelated to the actual L1 contract.

Per user brief item #2: "다른 환경 경고 필요하면 comment 권장" — a hard guard is cheap and matches §0 Fail-loud.

**Recommendation**: add a one-shot guard near the top of the script.

```bash
# Require mikefarah yq v4 (apt yq = kislyuk python wrapper, incompatible).
if ! yq --version 2>&1 | grep -qi 'mikefarah'; then
  fail "yq mikefarah v4 required (found: $(yq --version 2>&1 || echo none)). Install via: snap install yq"
fi
```

Alternative: restrict frontmatter parsing to a more portable shape (e.g., two `grep -q '^name:'` + `grep -q '^description:'`) — but that gives up YAML correctness, so the guard is preferred.

---

### Minor

#### M1. `awk` frontmatter parser silently accepts malformed files with no closing `---`

**File**: `test-extension.sh` L29

```bash
front=$(awk '/^---$/{c++; if (c==2) exit; next} c==1' "$skill")
```

**Edge cases verified** (see /tmp/awk-edge):

| Input shape | Behavior |
|---|---|
| Proper `--- fm ---` + body with extra `---` later | Correct (stops at 2nd) |
| `--- fm` then EOF (no closing `---`) | Still emits fm content; yq -e fails → `fail()` fires. Safe but error message is cryptic (`yq: ...` not "unterminated frontmatter"). |
| File with no `---` at all | `front` is empty; yq on empty stdin returns null, `null.name and .description` is false-ish, `-e` exits nonzero → `fail()` fires. Safe. |
| File with only `---\n` (single marker) | `front` is empty; same path as above. |

**Assessment**: robust on all edges (they all end at `fail()`), but error messages don't distinguish "frontmatter missing" vs "frontmatter malformed." Future skills authors will waste time on this.

**Recommendation (optional)**: add an explicit count check:

```bash
markers=$(grep -c '^---$' "$skill" || true)
[ "$markers" -ge 2 ] || fail "$skill has no closed frontmatter block"
```

Only worth adding if/when multiple SKILL.md files exist.

---

#### M2. `jq -e '.name and .description and .version and .contextFileName'` does not enforce non-empty values

**File**: `test-extension.sh` L8

In `jq`, empty string `""` is **truthy**, so `{"name":"","version":""}` would pass this check. The plan doesn't require non-empty-string validation at L1 (that's the point of L1 being a syntax check), so this is aligned with the plan — but flagging for when the schema test graduates.

**Recommendation (future)**: when moving to L1+, switch to length-based check: `jq -e '(.name|length>0) and (.version|length>0) and ...'`.

---

#### M3. `ls tests/hooks/*.bats >/dev/null 2>&1` relies on ls exit code for glob expansion

**File**: `tools/run-tests.sh` L8

When no `.bats` files exist, bash expands `tests/hooks/*.bats` literally (no `nullglob`) and `ls` errors out with exit 2 — which correctly triggers the `else` branch. But this is an unusual idiom. A slightly more canonical form:

```bash
if command -v bats >/dev/null 2>&1 \
   && compgen -G "tests/hooks/*.bats" > /dev/null; then
```

`compgen -G` is a bash-builtin glob test that's explicit about intent. No behavior difference on the current host; pure readability preference.

---

#### M4. No shellcheck pragma / no `IFS=` hardening

Neither script has a `# shellcheck shell=bash` directive or `IFS=$'\n\t'` reset. Not strictly needed for scripts this short, but adding shellcheck to CI later will want the pragma. Low priority.

---

## Plan Alignment

| Plan item | Implementation | Status |
|---|---|---|
| Step 1: `tests/schema/test-extension.sh` with 5 checks | All 5 present: jq schema / @import / core file / domain file / SKILL frontmatter | Aligned |
| Step 2: `chmod +x` + runs clean | Verified: `L1 schema: PASS` | Aligned |
| Step 3: `tools/run-tests.sh` with L1/L2/L3 stages + SKIP | All present, verbatim match | Aligned |
| Step 4: runs clean | Verified: `Automated tests: PASS` | Aligned |
| Step 5: commit `feat: DRLLM v0.1 extension skeleton` | HEAD `f87073b` matches | Aligned |

**No deviations from plan.** All differences between the plan-literal and HEAD are whitespace-only.

---

## drllm-core v2 §0 Robust Design Principles Check

| Principle | Check | Notes |
|---|---|---|
| §0-1 Single source of truth | N/A (no state) | — |
| §0-3 Defensive parsing | Partial | awk handles well; grep pattern too loose (I1) |
| §0-5 Fail loud | Yes | stderr + exit 1 everywhere |
| §0-6 Idempotence | Yes | Pure reads, no mutation |
| §0-7 Environment assumption | **Gap** | yq flavor unstated (I2) |

---

## Recommended Fix Order

1. **I2** first (yq guard) — one-line addition, biggest blast-radius reduction.
2. **I1** next (grep anchoring) — one-line change, closes regex loophole.
3. M1–M4 deferrable until Task 5+ when more SKILL.md files land.

After I1 + I2 land, this can move to APPROVED.

---

## Files Reviewed

- `/home/namykim/workspace/DRLLM/tests/schema/test-extension.sh`
- `/home/namykim/workspace/DRLLM/tools/run-tests.sh`
- `/home/namykim/workspace/DRLLM/GEMINI.md` (referenced by L1 test)
- `/home/namykim/workspace/DRLLM/docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` (L217–L321, Task 4 section)
