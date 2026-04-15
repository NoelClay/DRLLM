# Task 23: L3 Aggregation Fixture Tests — Implementer Report

## Actual Aggregate Output Format (captured from aggregate-metrics.sh)

Running `./tools/aggregate-metrics.sh /tmp/exp` against empty dir:

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

Key difference from plan's expected-output: the `Sessions invalid:` block is **3 separate lines** (Scope B format), not a single `Sessions invalid: 0 (contain [P5_MISSING] — ...)` line.

## Diff: Plan's Original expected-output vs Produced expected-output.txt

Plan (Task 23 Step 4) specified:
```
Sessions invalid: 0 (contain [P5_MISSING] — §0-3 측정 무효 후보)
```

Produced (Scope B format matching actual script output):
```
Sessions invalid:
  [P5_MISSING]:             0
  [INVALID_CITATION_COUNT]: 0
  [INVALID_TIMESTAMP]:      0
```

Also, plan used `(필수 ≥ 0.700)` with Unicode ≥ but actual script outputs `(필수 >= 0.700)` with ASCII >=. The expected-output.txt uses ASCII >= to match the script exactly.

## Fixture Tweaks Beyond A/B/C (Adaptation Notes)

### Adaptation A: research-results.md files
Added 3 research-results.md files (session-A: 5 rows, session-B: 9 rows, session-C: 2 rows) to avoid B1 `research_results_missing` false-positive. The B1 check fires when `status == done|tutor` and `research-results.md` is absent.

### Adaptation B: touch-sync in test.sh
test.sh sets `touch -d "$started"` on all files in each fixture session directory before running aggregate. Without this, all 3 sessions produced `[INVALID_TIMESTAMP]` with diffs of ~89K–96K seconds (files written at test runtime vs started_at 2026-04-14T10:00–12:00+09:00). Verified the fix eliminates all 3 false-positives.

Pre-fix output showed:
```
[INVALID_TIMESTAMP]: 3
```
Post-fix output:
```
[INVALID_TIMESTAMP]: 0
```

### Duration consistency check (B2 secondary)
Session-A: completed - started = 1200s, log duration_sec=1200 → exact match.
Session-B: completed - started = 900s, log duration_sec=900 → exact match.
Session-C: completed_at=null → duration check skipped.

## No Additional Fixture Tweaks Required
The 3 adaptations (A/B/C) were sufficient. No unexpected fields or stdout leaks from the script.

## Test Output

```
L3 aggregation: PASS
```

Full suite (`./tools/run-tests.sh`):
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
=== L3 Aggregation ===
L3 aggregation: PASS

Automated tests: PASS
Manual smoke: see tests/manual/smoke-step*.md
```
