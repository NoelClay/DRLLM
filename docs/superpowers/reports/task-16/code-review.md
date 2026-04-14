# Task 16 Code Review — `hooks/auto-chain-skills.sh`

- Base SHA: `a1e9fc9`
- Head SHA: `8458d97`
- Branch: `feat/sp1-tiny-drllm`
- Reviewer role: Senior Code Reviewer
- Date: 2026-04-14

## Verdict

**APPROVED WITH CONCERNS (minor)** — implementation matches the plan verbatim, all five smoke scenarios pass, and the concerns listed below are plan-level, not implementer-level. No changes are required for Task 16 to close; follow-up tasks (17–19) should cover the gaps.

## 1. Plan Alignment

| Plan item | Status | Evidence |
|---|---|---|
| Step 1: write `hooks/auto-chain-skills.sh` with the literal bash block (lines 1289–1323) | PASS | `diff` vs plan shows only the trailing markdown fence ``` ``` `` differs — the shell code is byte-identical |
| Step 2: `chmod +x` | PASS | `ls -l` → `-rwxrwxr-x` |
| Step 3: S0 smoke | PASS | stdout emits `tailToolCallRequest.args.skill_name = "drllm-research-execution"` |
| Step 4: `stop_hook_active=true` smoke | PASS | stdout is exactly `{}` |
| Step 5: commit `feat: auto-chain-skills.sh AfterTool hook` | PASS | HEAD is `8458d97` with that subject |

**Deviation from plan:** none. The implementer was constrained to the verbatim block and honored that constraint.

## 2. Behavioral Verification (live smoke)

Five inputs exercised in this review session:

1. `save_memory` + `__drllm_s0_done_…` + `stop_hook_active=false`  →  S0 chain JSON. **PASS**
2. `save_memory` + `__drllm_s0_done_…` + `stop_hook_active=true`   →  `{}`. **PASS** (loop guard)
3. `save_memory` + `__drllm_s2_done_…` + `stop_hook_active=false`  →  S2 chain JSON. **PASS**
4. Unrelated tool name                                             →  `{}`. **PASS**
5. `tool_input` as **object** (`{"fact":"__drllm_s0_done_x"}`)     →  S0 chain JSON. **PASS**

Case 5 is the one the review prompt explicitly flagged. `jq -r '.tool_input | tostring'` turns the object into `{"fact":"__drllm_s0_done_x"}` (string), and `grep -q '__drllm_s0_done_'` finds the marker as a substring. Works correctly for both string-shaped and object-shaped `tool_input`.

## 3. Shell-safety audit

| Check | Verdict | Note |
|---|---|---|
| `set -euo pipefail` | PASS | line 3 |
| Quoting of expansions (`"$input"`, `"$tool_name"`, `"$tool_input"`) | PASS | all user-derived vars are quoted in test/grep/echo |
| Heredoc delimiter `'EOF'` (single-quoted) | PASS | prevents any `$` expansion inside the JSON literals; the emitted JSON is byte-exact |
| stdout vs stderr separation | PASS | JSON goes to stdout; human-readable log goes to stderr via `echo >&2` — Gemini will parse only stdout |
| jq failure modes | SOFT-PASS (see Concern C1) | `jq -r '.foo // ""'` defends against missing keys, but malformed JSON on stdin would make jq exit non-zero and `set -e` would kill the hook silently from Gemini's perspective |
| Hardcoded paths / secrets | PASS | none; stateless |
| Single responsibility | PASS | parse hook input → branch → emit chain JSON or `{}`. No side effects other than one stderr log line |

## 4. Concerns

### C1 — Malformed-JSON input is handled by crash, not by pass-through  *(Minor, plan-level)*

If Gemini ever sends a non-JSON payload, `jq` exits non-zero, `set -e` aborts the hook, and no stdout is produced. Gemini will likely treat this as "no hook output" (pass-through) but that is an implicit contract. A more defensive shape would be:

```bash
parsed=$(echo "$input" | jq -c '.' 2>/dev/null) || { echo '{}'; exit 0; }
```

This is **not** a blocker because (a) the plan prescribed the verbatim block, and (b) Gemini's contract is to always send valid JSON. Flag for Task 18 (manual smoke) or a future hardening pass.

### C2 — `grep` against `tostring` is a substring match, not a structured check  *(Minor, plan-level)*

`__drllm_s0_done_` appearing anywhere in the serialized `tool_input` triggers the chain, including inside a longer fact like `"remember that __drllm_s0_done_ is a marker prefix"`. In practice the DRLLM skills emit the marker as the entire fact, so collisions are unlikely. If paranoid, a tighter check would be:

```bash
if echo "$tool_input" | grep -Eq '(^|[^A-Za-z0-9_])__drllm_s0_done_[0-9A-Za-z-]+([^A-Za-z0-9_]|$)'; then
```

Again plan-level, not a blocker.

### C3 — No test coverage yet  *(Expected — covered by Task 17)*

The plan splits bats unit tests into Task 17. I verified the five scenarios manually in this review; they should all become bats cases.

### C4 — Style note: duplicated `tool_name = "save_memory"` check  *(Cosmetic)*

Both branches re-test `tool_name`. A nested `if` or `case` would be one fewer comparison, but the current form reads left-to-right and matches the plan verbatim. **Do not change** — it is not worth deviating from the plan for cosmetic DRY.

## 5. Things done well

- Loop guard **before** any work — correct ordering; a stray `stop_hook_active=true` cannot accidentally trigger a chain.
- `jq -r '.foo // ""'` idiom — defends against missing keys without extra branches.
- `echo >&2 "[drllm-hook] …"` — namespaced log prefix makes logs greppable when debugging chained sessions.
- Single-quoted heredoc — the JSON is byte-exact regardless of shell state.
- Scope discipline — the script does one thing; no filesystem writes, no network, no config reads.
- 36 lines, one file — minimal surface area, easy to audit.

## 6. Recommendations

1. **For Task 17 (bats):** include cases for empty stdin, malformed JSON, object-shape `tool_input`, and marker appearing inside a longer string — not just the happy path.
2. **For Task 18 (settings.json registration):** verify Gemini's hook contract actually uses `tailToolCallRequest` under `hookSpecificOutput` at the version being targeted. If the schema changed, this hook is dead silent (exits 0, `{}`) and nothing will chain.
3. **For a future hardening pass (out of SP-1 scope):** add explicit jq-failure fallback per C1; tighten marker regex per C2.

## 7. Files reviewed

- `/home/namykim/workspace/DRLLM/hooks/auto-chain-skills.sh` (new, 36 lines, 0755)
- `/home/namykim/workspace/DRLLM/docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` lines 1279–1354 (plan spec)

## 8. Final call

**APPROVED WITH CONCERNS.** Task 16 can close; concerns C1/C2 are plan-level and should be revisited in Task 17 (test coverage) and Task 18 (manual smoke / contract check).
