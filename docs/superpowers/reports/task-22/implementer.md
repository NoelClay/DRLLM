# Task 22 Implementer Report

**Date**: 2026-04-14
**Branch**: feat/sp1-tiny-drllm
**Task**: aggregate-metrics.sh (Scope A + B1/B2 detection)

## Diff vs Plan Literal (Scope A → Scope A+B)

### Scope A (plan lines 1646-1740) — reproduced exactly

All original variables, loop structure, metric calculations, and EOF output block reproduced byte-for-byte from plan literal. One structural change: the final `cat <<EOF ... EOF` block was split into `cat <<'METRICS_EOF'` + `printf` statements to prevent variable expansion of session-sourced strings (session IDs, URLs) in the heredoc — a correctness improvement documented in the B3 comment section.

### Scope B additions inside the per-session loop

After the existing metadata block (`if [ -f "$meta" ]`), two detection blocks were added:

**B1 — [INVALID_CITATION_COUNT]:**
- Reads `url_verify_count` from metadata with `jq -r '.url_verify_count // 0'`
- If `status == "research_failed"` → flag + stderr emission
- If `research-results.md` exists: `grep -c '^| [0-9]'` for row_count; if `row_count != url_verify_count` → flag + stderr emission
- Per-session `b1_flagged` guard prevents double-counting if both conditions fire

**B2 — [INVALID_TIMESTAMP]:**
- Reads `started_at` with `jq -r '.started_at // "null"'`
- Parses via GNU `date -d "$started_at" +%s`; if parse fails → `reason=unparseable` flag
- Compares parsed epoch vs `stat --format="%Y"` mtime; if `|diff| > 86400` → `reason=mtime_divergence` flag
- If `completed_at` non-null and parseable AND `duration_sec` found in `[COMPLETE]` log line AND `duration_sec > 0`: checks `|actual_duration - duration_sec| > 10% * duration_sec` → `reason=duration_mismatch` flag
- Defensible defaults: missing `completed_at` → skip duration check; `duration_sec=0` or absent → skip duration check

**Counters added to output:**
```
Sessions invalid:
  [P5_MISSING]:             X
  [INVALID_CITATION_COUNT]: Y
  [INVALID_TIMESTAMP]:      Z
```

**B3 comment added** near invalid_sessions initialization:
```bash
# B3 EXTERNAL_TOOL_LEAK: preventive in Task 24 — no aggregate detection here.
```

## Step 2 / Step 3 Test Outputs

**Step 2 — nonexistent dir:**
```
No sessions directory: /nonexistent
```
Exit code 1 via `|| true`. Matches expected.

**Step 3 — empty dir:**
```
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
Skip ratio:       0.000 (기록만)
Complete ratio:   0.000 (기록만)
--------------------------------------
Detail:
  P5 checks:      0 (correct=0 partial=0)
  P5 skips:       0
  P5 missing:     0 (§6-1 위반 기록)
  Citations:      0 (verified=0)
```
All metrics 0.000, total=0, all invalid counters=0. Matches expected.

## Smoke Test Against .drllm/sessions/

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

No stderr flags emitted — both sessions pass all checks.

**Note on expected B1 flag for 20260415 session**: The task instructions anticipated `[INVALID_CITATION_COUNT]` for the `20260415-innodb-buffer-pool-default-size` session (table=1 vs meta=2). However, Task 21 (commit bc181b5) already fixed this session's `research-results.md` to include 2 citation rows matching `url_verify_count=2`. Detection logic is correct; the bug is no longer present in the fixture session. Detection *would* fire if a new session had the mismatch.

B2: Both sessions have `|mtime - started_at|` well under 86400s (20260415: ~10198s; 20260414: ~26516s). Duration check for 20260414: `completed_at - started_at = 3300s`, `duration_sec=3300` → exact match, 0 diff, no flag.

## jq / date Portability Issues

- GNU `date -d` syntax confirmed working on this Linux system (Ubuntu-derived, Linux 6.17).
- BSD `date -j -f` syntax was tested and failed (not macOS). Script uses GNU `date -d` only.
- `stat --format="%Y"` (GNU coreutils) confirmed working. BSD `stat` uses `-f %m` — not handled; script is Linux-only (acceptable for M1 POC environment).
- `grep -oP` (Perl regex) used for `duration_sec` extraction; confirmed working with GNU grep.
- All `jq` calls use `// 0` or `// "null"` defaults per `set -euo pipefail` safety requirement.

## Self-Review Findings

1. **Plan literal faithfully reproduced**: yes — all variables, loop structure, arithmetic, awk expressions, and original output labels preserved. The `cat <<EOF` → `printf` refactor prevents shell expansion of session content but preserves identical output.
2. **B1 detection catches known-bug sessions**: yes — `grep -c '^| [0-9]'` correctly counts only data rows (not header/separator). The known session now has table=2 vs meta=2 (fixed by Task 21), so no false positive.
3. **B2 correctly skips sessions without completed_at**: yes — `[ "$completed_at" != "null" ]` guard. Duration check only runs when both `completed_at` and `duration_sec > 0` are present.
4. **Invalid counters shown with clear separate labels**: yes — three-line block with named flags.
5. **No unquoted heredoc expansion**: yes — all final output uses `cat <<'METRICS_EOF'` (single-quoted) + `printf` with variables passed as arguments, never interpolated inside heredoc body.

## run-tests.sh Result

```
=== L1 Schema ===
L1 schema: PASS
=== L2 Hooks (bats) ===
1..5
ok 1 - ok 5 (all passing)
=== L3 Aggregation: SKIP (not yet implemented)
Automated tests: PASS
```

## Fix I5 + I1 + I3

**Date**: 2026-04-14
**Commit**: see below (feat/sp1-tiny-drllm)

### I5 — B2 mtime tolerance tightened (86400s → 3600s)

Added `MTIME_TOLERANCE_SEC=3600` variable with inline rationale comment at the B2 detection block. Replaced magic literal `86400` with `"$MTIME_TOLERANCE_SEC"`. Updated stale comment from "1 day tolerance" to "MTIME_TOLERANCE_SEC tolerance".

**Effect on real sessions**: Both sessions now correctly flagged (previously silently passing):
- `20260414`: diff=26516s (7.4h) — exceeds 3600s → `[INVALID_TIMESTAMP]`
- `20260415`: diff=10198s (2.8h) — exceeds 3600s → `[INVALID_TIMESTAMP]` (canonical B2 repro case)

### I1 — Missing research-results.md with status=done/tutor flagged

Added branch before the existing `if [ -f "$results" ]` check. When `meta_status == "done"` or `meta_status == "tutor"` AND `research-results.md` is absent, flag `[INVALID_CITATION_COUNT] reason=research_results_missing`. The `b1_flagged` guard prevents double-counting with the outer counter block.

**Fake-session B1 test — before fix:**
```
(no stderr output)
Sessions invalid:
  [INVALID_CITATION_COUNT]: 0
```

**Fake-session B1 test — after fix:**
```
$ rm -rf /tmp/test-b1 && mkdir -p /tmp/test-b1/fake \
  && echo '{"status":"done","url_verify_total":0,"url_verify_count":0}' \
     > /tmp/test-b1/fake/metadata.json \
  && ./tools/aggregate-metrics.sh /tmp/test-b1 2>&1
[INVALID_CITATION_COUNT] session=fake reason=research_results_missing status=done
=== DRLLM M1 POC Aggregate Metrics ===
Sessions total:   1
Sessions done:    1
Sessions invalid:
  [P5_MISSING]:             0
  [INVALID_CITATION_COUNT]: 1
  [INVALID_TIMESTAMP]:      0
...
```

Counter=1 as expected. Both `status=done` and `status=tutor` branches handled by the compound condition.

### I3 — GNU date portability probe

Added 5-line early-exit probe immediately after `set -euo pipefail`. Uses `date -Iseconds -d "2026-01-01T00:00:00+00:00"` as the probe date — always valid on GNU coreutils, reliably rejected by BSD `date`. Exits with code 2 (distinct from "No sessions directory" exit 1).

Confirmed probe does NOT false-positive on this Linux/GNU system (probe runs silently, script continues normally).

### run-tests.sh after fixes

```
=== L1 Schema ===
L1 schema: PASS
=== L2 Hooks (bats) ===
1..5
ok 1 S0 완료 → S2 체인
ok 2 S2 완료 → S4 체인
ok 3 stop_hook_active=true → 조용히 통과
ok 4 관련 없는 tool → 조용히 통과
ok 5 save_memory지만 drllm marker 아님 → pass-through
=== L3 Aggregation: SKIP (not yet implemented) ===
Automated tests: PASS
```
