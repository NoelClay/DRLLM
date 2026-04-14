# Task 17 Code Review — L2 Hook Unit Tests (bats)

**Verdict:** APPROVED
**Reviewed range:** 8458d97..7f05563
**Reviewer:** Senior Code Reviewer
**Date:** 2026-04-14

## Summary

Task 17 delivers `tests/hooks/auto-chain-skills.bats` with 5 unit tests
covering every branch of `hooks/auto-chain-skills.sh` from Task 16. All
tests pass locally on bats 1.10.0. Implementation matches the synced
plan literally, and the plan sync (commit `7f05563`) correctly documents
the `tail -1` workaround in-line.

## Plan Alignment

- File path matches plan: `tests/hooks/auto-chain-skills.bats`.
- All 5 @test blocks match plan verbatim (post-sync).
- `tools/run-tests.sh` L2 branch auto-activates via existing
  `ls tests/hooks/*.bats` conditional — no changes needed, confirmed
  by reading current `run-tests.sh` (unchanged from Task 14).
- Commit history is clean: d53d3ed (initial), 4258c33 (match plan
  literal by removing `2>/dev/null`), 7f05563 (plan sync with
  explanatory comment). The mid-task plan sync is the right move —
  preserves traceability rather than silently deviating.

## Strengths

1. **Meaningful assertions** — every test asserts both `$status -eq 0`
   and a concrete output predicate (`jq`-extracted `skill_name` for
   chain cases, `[ "$output" = "{}" ]` for pass-through cases). Not a
   single tautological "bats ran" check.
2. **Branch coverage 1:1 with hook** — loop guard (hook L8–11), S0
   chain (L17–23), S2 chain (L26–32), save_memory-without-marker
   (falls through to L35), unrelated-tool (L35). Every `if` branch is
   exercised.
3. **Test isolation** — `setup()` re-initializes `HOOK` per test; each
   `run bash -c '...'` spawns a fresh subshell; no tempfiles, no env
   mutation, no chdir, no inter-test state bleed.
4. **Plan sync discipline** — rather than quietly diverging when the
   bats 1.x `run` stderr-merge behavior surfaced, the implementer
   synced the plan with an explanatory comment. Future readers of the
   plan see the `tail -1` reason in context.

## Minor Concerns (non-blocking, flag for SP-2)

### M1: `tail -1` is coupled to single-line JSON stdout contract

The extraction `echo "$output" | tail -1 | jq -r ...` works today
because the hook emits exactly one line of JSON on stdout. If the hook
were ever refactored to pretty-print (e.g. `jq .` for debuggability),
`tail -1` would silently parse only the closing `}` line and produce a
confusing jq error instead of a clear diff.

**Suggested fix (SP-2):** bats 1.10.0 supports `run --separate-stderr`
(added in bats 1.5). Upgrading would let the tests drop `tail -1`
entirely and make `$output` pure stdout:

```bash
run --separate-stderr bash -c 'echo "..." | '"$HOOK"
[ "$status" -eq 0 ]
skill=$(echo "$output" | jq -r '.hookSpecificOutput.tailToolCallRequest.args.skill_name')
```

Alternatively, encode the single-line contract into the hook (e.g.
`jq -c .` as a terminal filter) and document it. The `run
--separate-stderr` route is strictly cleaner — it also protects the
three `[ "$output" = "{}" ]` equality assertions from any future
stderr log line that might break them.

### M2: Silent stderr invariant in pass-through tests

Tests 3, 4, 5 assert `[ "$output" = "{}" ]`. This works because the
hook happens to be silent on stderr in those code paths. That's an
undocumented invariant of the hook; if someone later adds a debug log
to the pass-through branch, three tests break for a reason unrelated
to behavior. Same fix as M1 (`--separate-stderr`) addresses this too.

### Explicitly out of scope (per Task 17 spec)

Marker-in-longer-string, object-shape `tool_input`, malformed JSON
input — deferred to SP-2 per reviewer instructions. NOT flagged as
Task 17 gaps.

## Verification

```
$ bats --version
Bats 1.10.0

$ bats tests/hooks/auto-chain-skills.bats
1..5
ok 1 S0 완료 → S2 체인
ok 2 S2 완료 → S4 체인
ok 3 stop_hook_active=true → 조용히 통과
ok 4 관련 없는 tool → 조용히 통과
ok 5 save_memory지만 drllm marker 아님 → pass-through
```

All 5 tests pass. Ready to proceed to Task 18 (settings.json
registration) and Task 19 (manual smoke).

## Relevant Files

- `/home/namykim/workspace/DRLLM/tests/hooks/auto-chain-skills.bats`
- `/home/namykim/workspace/DRLLM/hooks/auto-chain-skills.sh`
- `/home/namykim/workspace/DRLLM/tools/run-tests.sh`
- `/home/namykim/workspace/DRLLM/docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` (lines 1357–1423)
