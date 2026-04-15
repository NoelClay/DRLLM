# Task 22 Spec Review

**Date**: 2026-04-14
**Reviewer**: Claude Sonnet 4.6
**Commit**: 4f56b40
**Branch**: feat/sp1-tiny-drllm

## Verdict

SPEC COMPLIANT with two minor deviations (both deliberate and acceptable Scope-B extensions to the plan literal).

---

## Verification Evidence

### 1. File presence and executable bit

```
-rwxrwxr-x 1 namykim namykim 8177 Apr 15 12:31 tools/aggregate-metrics.sh
```

Executable. Shebang + comment: `#!/usr/bin/env bash` / `# M1 POC aggregate metrics from .drllm/sessions/*/`. Matches plan.

### 2. Scope A — Plan literal conformance (lines 1646-1740)

All required elements present:
- `set -euo pipefail` (line 3)
- `SESSIONS_DIR="${1:-.drllm/sessions}"` (line 5)
- All 10 counters: `total_checks / correct / partial / skip / missing / total_sources / verified_sources / completed / total_sessions / invalid_sessions` (lines 12-21)
- Per-session loop with `"$SESSIONS_DIR"/*/` glob (line 29)
- `grep -c '^\[P5_CHECK\]'` / `grep -c '^\[P5_SKIP\]'` / `grep -c '^\[P5_MISSING\]'` pattern (lines 38-42)
- `jq -r '.url_verify_total // 0'` / `jq -r '.url_verify_count // 0'` / `.status` (lines 55-59)
- `[P5_MISSING] > 0 → invalid_sessions++` (lines 49-51)
- `p5_score = (correct + partial*0.5) / total_checks` via awk, `%.3f` format (lines 144-146)
- `url_verify = verified_sources / total_sources` (lines 149-151)
- `skip_ratio = skip / (total_checks + skip)` (lines 154-157)
- `complete_ratio = completed / total_sessions` (lines 160-162)

**Two deviations from plan literal** (both deliberate, documented in implementer report):

| Item | Plan literal | Implementation | Impact |
|------|--------------|----------------|--------|
| `Sessions invalid:` output | Single line: `Sessions invalid: $invalid_sessions (contain [P5_MISSING] — §0-3 ...)` | Multi-line block with 3 named sub-counters (required for Scope B) | **Intentional Scope-B extension** — adds B1/B2 counters; old single-line form would not have accommodated them |
| Threshold sigil | `≥` (U+2265) | `>=` (ASCII) | Cosmetic. Neither form changes semantics |

Both deviations are justified by Scope B requirements. The plan literal was the Scope-A baseline; Scope B expansion unavoidably changes the `Sessions invalid:` output line.

### 3. Plan tests (Spec A)

**Nonexistent dir test:**
```
$ ./tools/aggregate-metrics.sh /nonexistent 2>&1; echo "exit=$?"
No sessions directory: /nonexistent
exit=1
```
PASS — matches spec exactly.

**Empty sessions dir test:**
```
$ ./tools/aggregate-metrics.sh /tmp/test-sessions
=== DRLLM M1 POC Aggregate Metrics ===
Sessions total:   0
Sessions done:    0
Sessions invalid:
  [P5_MISSING]:             0
  [INVALID_CITATION_COUNT]: 0
  [INVALID_TIMESTAMP]:      0
--------------------------------------
P5 score:         0.000 (필수 >= 0.700)
URL verify:       0.000 (필수 >= 0.950)
...
```
PASS — all metrics 0.000, all counters 0.

### 4. Scope B1 — [INVALID_CITATION_COUNT] detection

Detection logic (lines 61-81) confirmed correct:
- `status == "research_failed"` → emits flag to stderr + sets `b1_flagged=1`
- `research-results.md` exists: `grep -c '^| [0-9]'` counts data rows (not header); mismatch vs `url_verify_count` → emits `[INVALID_CITATION_COUNT] session=<id> table=<n> meta=<n>` to stderr
- `b1_flagged` guard prevents double-counting
- Missing `research-results.md` → skips file-check branch gracefully (no crash) — VERIFIED

**Live test (row-count mismatch):**
```
[INVALID_CITATION_COUNT] session=test-row-mismatch table=1 meta=2
```
PASS.

**Live test (research_failed):**
```
[INVALID_CITATION_COUNT] session=test-research-failed status=research_failed
```
PASS.

**Missing url_verify_count in metadata** (old session edge case): `jq -r '.url_verify_count // 0'` defaults to 0; row count also 0 → no false-positive flag. PASS.

Counter `invalid_citation_count_sessions` incremented and printed as `[INVALID_CITATION_COUNT]: Y`. PASS.

### 5. Scope B2 — [INVALID_TIMESTAMP] detection

Detection logic (lines 83-138) confirmed correct:
- `started_at` parsed via GNU `date -d`; unparseable → `reason=unparseable` flag
- `|started_epoch - mtime| > 86400` → `reason=mtime_divergence` flag with `diff_sec=` in message
- Duration sanity: `completed_at` + `duration_sec` from `[COMPLETE]` log line → `|actual - stated| > 10%` → `reason=duration_mismatch`
- Missing `completed_at` or `duration_sec=0` → skips duration check (defensive default)

Counter `invalid_timestamp_sessions` shown as `[INVALID_TIMESTAMP]: Z`. PASS.

### 6. B3 comment

Line 27: `# B3 EXTERNAL_TOOL_LEAK: preventive in Task 24 — no aggregate detection here.`
PASS — scoped correctly.

### 7. Bug tracker

`docs/superpowers/bugs/B2-timestamp-hallucination.md`: `**Status**: in_progress`. PASS.
`docs/superpowers/bugs/README.md` line 22: `B2 | ... | in_progress | Task 20 + drllm-core; Task 22 detection`. PASS.

### 8. Commit stat (4f56b40)

Four files changed:
- `tools/aggregate-metrics.sh` (new, 187 lines)
- `docs/superpowers/bugs/B2-timestamp-hallucination.md` (status open → in_progress)
- `docs/superpowers/bugs/README.md` (B2 index row updated)
- `docs/superpowers/reports/task-22/implementer.md` (new, 129 lines)

PASS — all expected files present, no unexpected files.

---

## Aggregate Output Against Real .drllm/sessions/

```
=== DRLLM M1 POC Aggregate Metrics ===
Sessions total:   2
Sessions done:    1
Sessions invalid:
  [P5_MISSING]:             0
  [INVALID_CITATION_COUNT]: 0
  [INVALID_TIMESTAMP]:      0
--------------------------------------
P5 score:         0.500 (필수 >= 0.700)
URL verify:       1.000 (필수 >= 0.950)
Skip ratio:       0.333 (기록만)
Complete ratio:   0.500 (기록만)
--------------------------------------
Detail:
  P5 checks:      2 (correct=1 partial=0)
  P5 skips:       1
  P5 missing:     0 (§6-1 위반 기록)
  Citations:      4 (verified=4)
```

No B1 or B2 flags on stderr. Expected — both sessions pass all checks.

---

## Implementer Claim Verification: "Task 21 (bc181b5) fixed research-results.md"

**CLAIM IS MISLEADING IN MECHANISM — BUT NET STATE IS CORRECT.**

`git show --stat bc181b5` shows bc181b5 modified only:
- `context/drllm-core.md`
- `docs/superpowers/bugs/B1-citations-count-mismatch.md`
- `docs/superpowers/bugs/README.md`
- `docs/superpowers/reports/task-21/implementer.md`
- `skills/drllm-research-execution/SKILL.md`

`.drllm/` is gitignored. The session file
`.drllm/sessions/20260415-innodb-buffer-pool-default-size/research-results.md`
has mtime `2026-04-15 11:40:02 KST`, which is **24 minutes before bc181b5 (12:04:39 KST)**. The file was therefore created during the original M1 session run — not rewritten by Task 21.

Task 21 is a contract/skill change only. The implementer's attribution of the 2-row state to bc181b5 is wrong about the mechanism. However, the actual state is:
- `ROW_COUNT = 2` (verified with `grep -c '^| [0-9]'`)
- `url_verify_count = 2` (from `metadata.json`)
- No B1 mismatch → no flag → aggregate output is **correct**

The original session's research-results.md was apparently created with 2 rows from the outset (the B1 bug did not actually manifest in this session's data). The "known B1 bug" referenced in spec context may refer to a design concern rather than a concrete data defect in this specific session.

---

## B2 Timestamp Analysis (20260415 session)

- `started_at`: `2026-04-15T14:30:00+09:00` → epoch `1776231000`
- `metadata.json` mtime: `1776220802` (2026-04-15 11:40:02 KST)
- `|diff| = 10198s` (2.83 hours) — under 86400s tolerance
- No B2 flag. Correct.

For 20260414 session:
- `started_at`: `2026-04-14T15:00:00+09:00` → epoch `1776146400`
- `metadata.json` mtime: `1776172916`
- `|diff| = 26516s` (7.36 hours) — under 86400s tolerance
- `completed_at - started_at = 3300s`; `duration_sec=3300` (from `[COMPLETE]` log) → exact match, no flag
- No B2 flag. Correct.

Note: Both sessions have hallucinated timestamps (known B2 bug), but the 1-day tolerance is intentionally wide for the M1 POC scope. Full B2 closure is deferred to Task 24 smoke re-verification.

---

## Summary

All Scope A requirements met (with two deliberate, justified output-format extensions to support Scope B counters). B1 detection functional and graceful on edge cases. B2 detection functional with proper tolerance and defensive defaults. Bug tracker correctly updated. Executable bit set. Plan tests pass. No defects found.
