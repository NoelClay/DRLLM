# Task 23 — Code Review: L3 Aggregation Fixtures + Test Harness

- **Base SHA**: `79932c7`
- **HEAD SHA**: `a55112b`
- **Scope**: 3 fixture sessions (A/B/C) under `tests/aggregation/fixtures/sessions/`, plus `expected-output.txt` and `test.sh`. Wired into `tools/run-tests.sh` via existing conditional gate.
- **Test status**: `./tools/run-tests.sh` → L1 PASS, L2 PASS (5/5 bats), L3 PASS. Standalone `bash tests/aggregation/test.sh` → PASS, exit 0.

## Verdict

🟡 **APPROVED WITH CONCERNS** — implementation is functionally correct, math reconciles, all CI levels green. However the test harness has one design weakness (silent touch failure) that should be addressed before this is treated as the long-term L3 baseline.

## Math Reconciliation (sanity check)

| Field | Computed from fixtures | Expected | Match |
|-------|------------------------|----------|-------|
| Sessions total | A+B+C = 3 | 3 | ✓ |
| Sessions done | A+B (status=done) = 2 | 2 | ✓ |
| P5 checks | 3+3+1 = 7 | 7 | ✓ |
| Correct | 3+2+1 = 6 | 6 | ✓ |
| Partial | 0+1+0 = 1 | 1 | ✓ |
| Skip | 0+0+1 = 1 | 1 | ✓ |
| Citations total | 5+10+4 = 19 | 19 | ✓ |
| Citations verified | 5+9+2 = 16 | 16 | ✓ |
| P5 score | (6 + 0.5)/7 = 0.9286 | 0.929 | ✓ |
| URL verify | 16/19 = 0.8421 | 0.842 | ✓ |
| Skip ratio | 1/(7+1) = 0.125 | 0.125 | ✓ |
| Complete ratio | 2/3 = 0.6667 | 0.667 | ✓ |
| Invalid (all 3 counters) | 0 | 0 | ✓ |

Math is internally consistent. Fixtures successfully exercise the happy-path aggregation and produce stable output under the touch-sync setup.

---

## Issues by Severity

### 🔴 Critical
*(none)*

### 🟡 Important

**I1 — Touch failure swallowed silently (test.sh line 14)**

```bash
touch -d "$started" "$session_dir"/* 2>/dev/null || true
```

Both stderr suppression *and* `|| true` are in play. If GNU `touch` is missing, refuses the date format, or one or more files cannot be touched (perms, race), the loop continues with stale mtime — producing exactly the B2 false-positive the harness was designed to prevent. The test would then either FAIL with a misleading diff (one extra `[INVALID_TIMESTAMP]` line on stderr but otherwise-correct stdout still matches expected, since the counter is on stderr-only emit before increment) **or** silently mismatch.

Concretely: under the current `set -euo pipefail`, the `|| true` also defeats `-e`, so a real environment problem (no GNU coreutils on macOS without `gtouch`) becomes a green test instead of a setup error.

**Recommended fix**:
```bash
if ! touch -d "$started" "$session_dir"/* ; then
  echo "test setup failed: cannot touch $session_dir to $started" >&2
  echo "  (requires GNU coreutils; on macOS install via brew install coreutils)" >&2
  exit 2
fi
```
Drop both `2>/dev/null` and `|| true`. A test setup failure should be an exit-2 error, not a silent skip.

**I2 — `DIR` is computed but never used distinctly from `cd "$(dirname "$0")/../.."`**

Line 5 sets `DIR` from `cd && pwd` (canonical absolute). Line 6 then re-derives the repo root from `dirname "$0"` *without* the `cd && pwd` idiom. If the script is invoked via a symlink or relative path, line 6's relative `../..` may resolve differently than `DIR`. Recommend:

```bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
cd "$ROOT"
```

This is also what `aggregate-metrics.sh` would expect for the path argument resolution. Currently it works because `tests/aggregation/test.sh` is invoked from the repo via relative path — but the inconsistency is fragile.

### 🟢 Suggestions (nice-to-have)

**S1 — Output diff is byte-exact; portability risk on CRLF / trailing whitespace.**

`if [ "$actual" = "$expected" ]` is strictest possible. If a Windows checkout (line-ending = CRLF) or an editor adds a trailing newline to `expected-output.txt`, the test FAILs with a diff that's hard to read. Two mitigations:

1. Use `diff <(echo "$actual") <(echo "$expected")` and let `diff` produce the human-readable report rather than two raw `echo` blobs.
2. Add a `.gitattributes` entry: `tests/aggregation/expected-output.txt text eol=lf` to lock the canonical line ending.

**S2 — Negative-path coverage gap.**

Current 3 fixtures only exercise the all-counters-zero happy path. The B1/B2 detection logic added in Task 22 is *exclusively* validated by ephemeral `/tmp` smoke tests. As code evolves (e.g., Task 24 EXTERNAL_TOOL_LEAK), a regression in B1/B2 would not be caught by `run-tests.sh`.

Recommendation: defer to **SP-2** but add a fixture-D (research_results_missing) and fixture-E (mtime drift > 3600s — explicitly *not* touched) in a follow-up Task 23.5 if SP-1 schedule allows. Capture the expected stderr lines in `expected-stderr.txt` for diff comparison. **Defer-to-SP-2 is acceptable** given Task 23 is fixture-only and detection logic itself was reviewed in Task 22.

**S3 — Fixture realism vs minimalism trade-off.**

Each `research-results.md` is YAML frontmatter + Citations table only — no Summary / Key Points / Open Questions. Aggregate script only greps `^| [0-9]` so this is functionally sufficient. A future maintainer reading these fixtures might think they're malformed (vs intentionally minimal). One-line comment near the top of each fixture would help, e.g. `<!-- minimal fixture: exercises citation row count only -->`. Optional.

**S4 — Session-C inconsistency (cosmetic).**

`metadata.json` says `"status": "tutor"` but `learning-log.md` frontmatter says `status: in_progress`. The aggregate script reads only `metadata.json` so this is harmless; however the divergence is confusing. Real sessions would have these aligned (both equal to whatever the current phase is). Recommend aligning to `status: in_progress` in metadata as well, or document the deliberate mismatch.

**S5 — Time literals will age.**

Fixtures use `2026-04-14` timestamps. As the code base ages past mid-2026, the gap between fixture timestamps and "real now" widens. The touch-sync setup is the *only* defense against this becoming a time-bomb. Once I1 is fixed (loud failure on touch error), this is acceptable; without the fix, this combined with I1 is a latent bug. **Accept as-is conditional on I1 being addressed.**

---

## Plan Alignment Analysis

The implementation closely follows plan lines 1769–1987 with two documented adaptations from Task 22 Scope B feedback:

1. **Adaptation A**: `research-results.md` was added to each fixture (not in original plan). **Justified** — without it B1 would flag every fixture as `research_results_missing`. Documented in description.
2. **Adaptation B**: `touch -d` mtime sync added to `test.sh`. **Justified** — without it B2 mtime drift (3600s tolerance) flags all fixtures as `[INVALID_TIMESTAMP]` once tests run more than 1h after the embedded literal date. Documented in description.

Both adaptations are *necessary consequences* of Task 22 scope creep into the validation domain and should be reflected in the v0.5 plan if not already.

The 3-counter invalid format (P5_MISSING / INVALID_CITATION_COUNT / INVALID_TIMESTAMP) in `expected-output.txt` matches `aggregate-metrics.sh` v2 output exactly — confirmed by run.

---

## Integration with run-tests.sh

`tools/run-tests.sh` line 15: `if [ -f tests/aggregation/test.sh ]` → consistent with the L2 conditional pattern (`if command -v bats …`). Auto-activates on file presence, no additional config needed. Verified working: L1+L2+L3 all run, all PASS, exit 0. CI-friendly.

---

## Recommendation

1. **Address I1 before merge** (5-line fix; eliminates silent false-positive risk).
2. **I2 is a 3-line cleanup** worth doing while you're in the file.
3. **S1 (CRLF/diff)** can be punted to "the day someone tests on Windows".
4. **S2 (negative fixtures)** — explicitly defer to **SP-2**. Carry forward as a known coverage gap; document in the SP-1 → SP-2 handoff that B1/B2 detection lacks permanent CI fixtures.
5. **S3, S4, S5** — optional polish; not blocking.

---

## Re-Review After I1+I2 Fix

- **Re-review date**: 2026-04-14
- **HEAD SHA**: `d0884f3`
- **Commits audited**: `4b650bd` (I1+I2 fix), `d0884f3` (B4 filing)

### Verification

1. `tests/aggregation/test.sh` L5-6: `DIR` and `ROOT` both use canonicalized `cd ... && pwd`. Symlink fragility (I2) resolved.
2. L15-18: touch block is now `if ! touch -d "$started" "$session_dir"/*; then echo ... >&2; exit 2; fi`. No `2>/dev/null || true` anywhere. Silent-failure path (I1) eliminated — GNU `date`/touch unavailability now fails loud with diagnostic and exit code 2.
3. `./tests/aggregation/test.sh` → `L3 aggregation: PASS`.
4. `./tools/run-tests.sh` → L1 schema PASS, L2 hooks 5/5 PASS, L3 aggregation PASS, smoke note printed. No regression.
5. `docs/superpowers/bugs/B4-aggregate-detection-fixtures.md` exists with all required sections (Severity Minor, Observed, Risk, Fix Plan with SP-2 scope detail, Verification, Status=open). Quality is high — fix plan enumerates 4 targeted negative fixtures with expected stderr/counter assertions.
6. `docs/superpowers/bugs/README.md` Index row 24: `B4 | ... | Minor | open | SP-2 (negative fixtures)` — matches convention.
7. No trailing whitespace introduced; `set -euo pipefail` semantics intact (explicit `exit 2` inside `if` is well-formed); no portability drift (still GNU-dependent by design, now with clear error surface).
8. `git show --stat 4b650bd d0884f3` — scopes clean: commit 1 touches only `tests/aggregation/test.sh` (+6/-2); commit 2 touches only `docs/superpowers/bugs/` (new B4 file + 1-line README index append). No collateral.

### Residual

- S1 (CRLF), S3-S5 (polish) unchanged — still non-blocking.
- S2 coverage gap formally tracked as B4 → SP-2. Acceptable.

### Verdict

**APPROVED**. Both Important findings resolved cleanly; coverage gap formally tracked with actionable SP-2 plan. No new issues introduced.
