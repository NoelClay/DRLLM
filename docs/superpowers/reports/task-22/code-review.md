# Task 22 Code Review — `tools/aggregate-metrics.sh`

**Reviewer**: Senior Code Reviewer (Opus 4.6)
**Date**: 2026-04-14
**Base**: 589b23e → **Head**: 4f56b40
**Files changed**: `tools/aggregate-metrics.sh` (+187), `docs/superpowers/bugs/B2-timestamp-hallucination.md` (status), `docs/superpowers/bugs/README.md` (index), `docs/superpowers/reports/task-22/implementer.md` (+129)

---

## Verdict: APPROVED WITH CONCERNS

Scope A reproduces the plan literal faithfully. B1/B2 detection logic works as advertised on smoke and synthetic fixtures. The structural refactor (`cat <<'METRICS_EOF'` + `printf`) for the output block is a defensible safety improvement over the plan literal. However, several semantic gaps in B1/B2 detection — and a Linux-only portability assumption with no graceful guard — should be addressed before Task 23 fixtures are written, so test cases can codify the expected behavior.

---

## What Was Done Well

1. **Plan literal preserved** (lines 12-52, 142-162) — variables, arithmetic, awk float formatting, and label text reproduced byte-for-byte. The behavioral contract for Scope A is intact.
2. **Heredoc → printf refactor is correct** — splitting `cat <<EOF` into `cat <<'METRICS_EOF'` + `printf '%s' "$var"` matches the discipline established in Tasks 20/21 (S4 event log lesson). The body now contains only integer/float values, but the defensive choice is still right.
3. **Per-flag dedup guards** (`b1_flagged`, `b2_flagged` set to `0` then `1`) correctly prevent a single session from double-incrementing within the same flag class. A session can be flagged across multiple classes (P5_MISSING + INVALID_CITATION_COUNT + INVALID_TIMESTAMP) — that matches the prompt's "each flag separately" requirement.
4. **`jq // 0` / `// "null"` defaults** are present on every `jq -r` call (lines 55, 56, 59, 63, 73, 85, 86) — `set -e` will not kill on missing fields.
5. **Smoke + synthetic verification** — confirmed reviewer-side: nonexistent dir exits 1, empty dir produces all-zero output, mismatched table/meta correctly emits `[INVALID_CITATION_COUNT]`, mtime divergence correctly emits `[INVALID_TIMESTAMP]`.
6. **Bug tracker hygiene** — B2 status `open` → `in_progress` with task pointer; README index updated.

---

## Issues

### Critical

None. The script is correct for its intended environment and the M1 POC scope.

### Important

**I1 — B1 silently passes when `research-results.md` is missing.**
File: `tools/aggregate-metrics.sh:70-78`
```bash
if [ -f "$results" ]; then
    row_count=$(grep -c '^| [0-9]' "$results" 2>/dev/null || true)
    ...
fi
```
If `research-results.md` does not exist (session crashed mid-run, or `status=research_failed` left files partial), the row-count comparison is skipped entirely. The session is *only* flagged if `status=="research_failed"` — but a session with `status=="done"` that lacks a results file would pass both B1 checks despite being deeply broken. **Recommendation**: add an explicit branch — if `$meta_status == "done"` AND `! -f "$results"` AND `$url_verify_count > 0`, flag with `reason=results_missing`. Reviewer-verified this gap by synthesizing a session with `status=done`, `url_verify_count=0`, no `research-results.md` — script reported zero invalid flags.

**I2 — Zero-citation healthy state is indistinguishable from suspicious state.**
File: `tools/aggregate-metrics.sh:74`
A session where `url_verify_count == 0` AND `row_count == 0` (or no results file) currently passes B1. For an M1 research session this is suspicious: zero cited sources usually means the LLM produced no answer or fabricated one. Either flag it (`reason=zero_citations`) or document explicitly in the script comment that "zero citations is treated as healthy by design — Task NN enforces minimum-citation policy." Picking one is fine; leaving it ambiguous in the only measurement layer is not.

**I3 — Linux-only `date -d` and `stat --format` with no graceful guard.**
File: `tools/aggregate-metrics.sh:90, 94, 98, 110`
Implementer report acknowledges this (line 107). The script will fail confusingly on macOS / BSD: `date -d` returns nonzero (caught by `|| echo ""`), then `stat --format="%Y"` fails (caught by `|| echo "0"`), and B2 will incorrectly flag every session as `reason=mtime_divergence` with `mtime=0`. **Recommendation**: at the top of the script, add a one-line probe:
```bash
if ! date -d "1970-01-01" +%s >/dev/null 2>&1; then
    echo "ERROR: GNU date required (BSD/macOS not supported in M1 POC)" >&2
    exit 2
fi
```
This converts a silent false-positive into a loud abort.

**I4 — `duration_sec` ±10% tolerance has no absolute floor.**
File: `tools/aggregate-metrics.sh:125-126`
For a 60-second session, `tolerance = 6` seconds. Realistic clock jitter between `started_at` capture and `completed_at` capture, plus event-ordering variance, can plausibly exceed 6s without indicating hallucination. **Recommendation**: `tolerance = max(30, duration_sec * 0.10)`. One-line awk change:
```bash
tolerance=$(awk "BEGIN { t = $duration_sec * 0.10; if (t < 30) t = 30; printf \"%d\", t }")
```

**I5 — 86400s mtime tolerance is documented loose; should be tightened.**
File: `tools/aggregate-metrics.sh:103`
B2 spec (line 87 of `B2-timestamp-hallucination.md`) calls for "**±60초 이내**" tolerance. The implementation uses ±86400s (1 day). Same-day hallucinations — the *exact case observed* in the original B2 report (`14:30:00` claimed vs `11:40` actual, ~10198s gap) — would NOT be detected. The smoke output confirms this: the 20260415 session has `diff=10198s`, well below the 86400s threshold, so it passes despite being the canonical B2 example. **Recommendation**: tighten to 3600s (1 hour) or to the spec'd 60s. If 60s is too aggressive for real-world capture latency, document the chosen threshold in a comment with rationale.

### Suggestions

**S1 — Variable names: keep `b1_flagged`/`b2_flagged` consistent with their counter names** — `invalid_citation_count_sessions` and `invalid_timestamp_sessions` are descriptive (good); the per-iteration flags use short names (`b1_flagged`). Consider `citation_count_violation` / `timestamp_violation` for readability, but this is purely cosmetic.

**S2 — Stderr messages already include enough fields for debugging** (session, table/meta/diff/reason/tolerance). No change needed.

**S3 — The `printf '%s'` discipline is applied correctly to Scope A output.** Since the output body contains no user-derived strings (only integers and awk-formatted floats), the `<<'METRICS_EOF'` (single-quoted heredoc) is technically belt-and-suspenders. Keep it — the precedent matters more than the marginal safety here.

**S4 — `grep -oP` (Perl regex) is GNU-grep specific** — same portability bucket as I3. Listed once in I3 is sufficient.

---

## Plan Alignment

| Plan element | Status |
|---|---|
| `set -euo pipefail` + `\|\| true` discipline (Scope A) | Preserved exactly |
| `grep -c \|\| true` + `${var:-0}` defaults | Preserved on all 5 Scope A counters; B1 uses same idiom on `row_count` |
| `jq -r '.field // 0'` defaults | Preserved + extended to B1/B2 |
| Output labels & order | Preserved (Sessions invalid expanded from 1 line to 4 lines per Scope B) |
| `$invalid_sessions` semantics (P5_MISSING) | Preserved unchanged |
| Step 2 (nonexistent dir) | Verified PASS |
| Step 3 (empty dir) | Verified PASS |

Beneficial deviations:
- Output block split into `cat <<'METRICS_EOF'` + `printf` — improves safety without behavioral change.
- Three separate invalid counters instead of one — matches Scope B requirement and makes acceptance gate readings unambiguous.
- B1/B2 stderr emissions are well-formatted and grep-friendly for downstream tooling.

No problematic deviations from Scope A.

---

## B3 Deferral Verdict

Acceptable. The comment `# B3 EXTERNAL_TOOL_LEAK: preventive in Task 24 — no aggregate detection here.` (line 27) is correctly placed and accurately states the deferral. B3 is a runtime-prevention concern (skill-time leak detection), not a post-hoc aggregation concern, so deferring detection out of this script is the right architectural call.

---

## Testing

The plan-specified Step 2 / Step 3 tests are present and pass. B1/B2 detection has no fixture coverage in Task 22 — that's deferred to Task 23 per the prompt. **This is acceptable for the checkpoint** but raises the importance of issues I1, I2, I4, I5 above: those gaps will become test cases (or won't) in Task 23, and the implementer will lock in the current behavior either way. Recommend addressing I1, I3, I4, I5 *before* Task 23 fixture authoring so the fixtures codify the corrected behavior.

---

## Recommended Action

1. **Before Task 23**: address I1 (missing results file), I3 (BSD probe), I4 (tolerance floor), I5 (tighter mtime threshold). Each is a 2–5 line change.
2. **Defer to design discussion**: I2 (zero-citation policy) — needs product decision, not just a code change.
3. **No action**: S1–S4.

Once I1/I3/I4/I5 land, this code is fully ready for Task 23 fixture exercise.

---

## Files Referenced

- `/home/namykim/workspace/DRLLM/tools/aggregate-metrics.sh`
- `/home/namykim/workspace/DRLLM/docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` (lines 1637-1764)
- `/home/namykim/workspace/DRLLM/docs/superpowers/bugs/B2-timestamp-hallucination.md` (line 87, 93)
- `/home/namykim/workspace/DRLLM/docs/superpowers/reports/task-22/implementer.md`

## Re-Review After I1/I5/I3 Fix

**Commit reviewed**: `79932c7` (fix(sp1): Task 22 I1+I5+I3 — tighten B2 tolerance + catch missing research)

**Verdict**: APPROVED (green).

### Verification Summary

| Issue | Status | Evidence |
|-------|--------|----------|
| **I5** (B2 tolerance) | RESOLVED | `MTIME_TOLERANCE_SEC=3600` defined at line 98, used at line 118. No literal `86400` remains. Real run flags both canonical sessions (diff_sec=10198 and 26516) which were previously escaping. |
| **I1** (research-results.md absent) | RESOLVED | Lines 76-79: `if { status==done || status==tutor; } && [ ! -f "$results" ]` → emits `[INVALID_CITATION_COUNT] ... reason=research_results_missing`. Synthetic test produced exactly that line; counter incremented to 1. |
| **I3** (GNU coreutils probe) | RESOLVED | Lines 5-9: probe runs immediately after `set -euo pipefail`, before sessions-loop. Exit code 2 distinguishes from "No sessions directory" (exit 1, verified). |

### Test Results

1. `./tools/aggregate-metrics.sh /nonexistent` → exit=1 (correct, distinct from probe failure)
2. Synthetic `done`-status with no results.md → `[INVALID_CITATION_COUNT] session=fake reason=research_results_missing status=done`, counter=1 (correct)
3. Real `.drllm/sessions/` → both real sessions correctly flagged with `[INVALID_TIMESTAMP] ... reason=mtime_divergence diff_sec=10198|26516` (I5 working; previously only the larger gap might have been caught)
4. `./tools/run-tests.sh` → PASS (L1 schema, L2 bats 5/5)
5. `git show --stat 79932c7` → only `tools/aggregate-metrics.sh` (+17 lines) and `docs/superpowers/reports/task-22/implementer.md` (+65 lines) modified — no scope creep

### Implementation Notes (positive)

- I5 rationale documented inline (lines 95-97): "Tight enough to catch the canonical hallucination case (~2.8h gap observed), loose enough for normal session-duration mtime drift". Good defensive comment.
- I1 placement (after `meta_status` derivation, before existing row-count check) is clean — the three B1 conditions read top-to-bottom as a coherent decision tree.
- I3 probe uses a fixed timezone-bearing ISO8601 string (`+00:00`) which is the strictest GNU-date feature the script depends on; any BSD `date(1)` lacking `-d` will fail predictably here rather than silently downstream.

### No New Issues

- No regression in pattern coverage (B1 row-count compare and research_failed branch unchanged).
- No portability drift (probe is the only new external-cmd usage, and it's the very thing being checked).
- Counter semantics preserved (single `b1_flagged` flag means a session with both `research_failed` AND missing results.md still increments only once).

### Files

- `/home/namykim/workspace/DRLLM/tools/aggregate-metrics.sh` (lines 5-9 probe, 76-79 I1, 95-98 I5)
- `/home/namykim/workspace/DRLLM/docs/superpowers/reports/task-22/implementer.md` (fix narrative)
