# B4 — No permanent fixtures exercise B1/B2 detection paths in L3

**Severity**: Minor
**Status**: open
**Scheduled**: SP-2
**Filed**: 2026-04-15 (Task 23 code review)

## Observed

`tests/aggregation/fixtures/sessions/` has 3 happy-path sessions (A/B/C). All pass B1 row-count check (research-results.md row count matches url_verify_count) and B2 mtime check (test.sh touch-syncs file mtimes to started_at).

No fixture intentionally triggers:
- `[INVALID_CITATION_COUNT] reason=research_results_missing` (status=done + no research-results.md)
- `[INVALID_CITATION_COUNT]` row-count mismatch (research-results.md row count ≠ url_verify_count)
- `[INVALID_TIMESTAMP]` (started_at diverges > 3600s from file mtime)
- `[P5_MISSING]` (plan already notes v0.5 deferral)

Task 22 detection code was validated manually with ephemeral `/tmp/fake-session` fixtures during code review; no permanent regression coverage.

## Risk

Future `aggregate-metrics.sh` refactor that breaks B1/B2 detection would pass L3 happy-path tests but silently break production detection. Bug B1/B2 could reappear with no test catching it.

## Fix Plan

### SP-2 scope

Add `tests/aggregation/fixtures/sessions-negative/` with 4 fixtures:

- `session-missing-research/` — status=done, metadata has url_verify_count=3, no research-results.md. Expect `[INVALID_CITATION_COUNT] reason=research_results_missing`.
- `session-row-mismatch/` — status=done, metadata has url_verify_count=5, research-results.md has only 3 rows. Expect `[INVALID_CITATION_COUNT] table=3 meta=5`.
- `session-stale-timestamp/` — metadata `started_at` is 10 hours earlier than file mtime (no touch-sync). Expect `[INVALID_TIMESTAMP]`.
- `session-p5-missing/` — learning-log contains `[P5_MISSING] triggers=T1,T2 | reason=...` event. Expect `invalid_p5_missing_sessions=1`.

Add `tests/aggregation/test-negative.sh` that:
- Runs `aggregate-metrics.sh sessions-negative/` and captures stderr.
- Asserts specific `[INVALID_*]` stderr lines appear.
- Asserts specific counters in stdout match expected values.
- exit 0 on all assertions pass, non-zero with diagnostic on any mismatch.

Keep happy-path `test.sh` (L3) unchanged; `test-negative.sh` runs alongside.

Update `tools/run-tests.sh` L3 branch to run both test.sh and test-negative.sh.

## Verification

After SP-2 fix:
- `./tools/run-tests.sh` runs L3 positive + L3 negative; both PASS.
- Temporarily removing I1 fix from aggregate-metrics.sh causes L3 negative to FAIL (regression caught).
- Temporarily changing `MTIME_TOLERANCE_SEC=3600` to `86400` causes `session-stale-timestamp` expectation to fail (regression caught).
