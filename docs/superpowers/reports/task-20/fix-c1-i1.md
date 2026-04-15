# Task 20 Fix Report — C1 Critical + I1 Important

**Branch**: `feat/sp1-tiny-drllm`
**Base commit**: `cf78ede`
**Date**: 2026-04-14
**Files modified**: 2

---

## C1 Critical — heredoc `<<EOF` command injection fix

### Problem

Both `context/drllm-core.md` §1.2 and `skills/drllm-adaptive-tutoring/SKILL.md` §3.4 used unquoted `<<EOF` heredocs with user-controlled fields (`<질문>`, `<사용자 답변>`, `<url>`, `<이름>`). Unquoted heredoc expands `$VAR`, `$(cmd)`, and `` `cmd` `` inside the body — if a user's P5 answer contained `$(whoami)` or a citation quote contained `$HOME`, the shell would interpret it, causing data corruption or arbitrary command execution.

### Fix applied

Replaced `cat >> log <<EOF ... EOF` with `{ printf '%s' ... } >> log` pattern in both files. `printf '%s'` does not re-interpret shell metacharacters — all user-controlled values are passed as literal data.

Batch semantics (v2.1 §0-8) are preserved: a single `{ ... } >> log` group opens and closes the file descriptor once.

### Before/after: `context/drllm-core.md` §1.2

**Before** (lines 77–84):
```bash
NOW=$(date -Iseconds)
cat >> .drllm/sessions/<id>/learning-log.md <<EOF
[SUBTOPIC] <이름> | ${NOW}
[SOURCE] fetch::<url> | verified=true
[P5_CHECK] Q="<질문>" | A="<답변>" | score=correct
EOF
```

**After** (lines 77–87):
```bash
NOW=$(date -Iseconds)
{
  printf '[SUBTOPIC] %s | %s\n' "$SUBTOPIC_NAME" "$NOW"
  printf '[SOURCE] fetch::%s | verified=true\n' "$URL"
  printf '[P5_CHECK] Q="%s" | A="%s" | score=%s\n' "$Q" "$A" "$SCORE"
} >> .drllm/sessions/<id>/learning-log.md
```

> `%s` 는 literal 치환 — shell metachar 재해석 없음. `$`/`` ` ``/`$()` 포함 citation quote 안전.

### Before/after: `skills/drllm-adaptive-tutoring/SKILL.md` §3.4

**Before** (lines 109–116):
```bash
NOW=$(date -Iseconds)
cat >> .drllm/sessions/<session_id>/learning-log.md <<EOF
[SUBTOPIC] <이름> | ${NOW}
[SOURCE] fetch::<url> | verified=true
[P5_CHECK] Q="<질문>" | A="<사용자 답변>" | score=<correct|partial|incorrect>
EOF
```

Then plain text blocks:
```
[P5_SKIP] reason="<사용자 문장 인용>"
[P5_MISSING] triggers=T1,T3 | reason="<왜 발동 안 했는지>"
```

**After** (lines 109–132):
```bash
NOW=$(date -Iseconds)
{
  printf '[SUBTOPIC] %s | %s\n' "$SUBTOPIC_NAME" "$NOW"
  printf '[SOURCE] fetch::%s | verified=true\n' "$URL"
  printf '[P5_CHECK] Q="%s" | A="%s" | score=%s\n' "$Q" "$A" "$SCORE"
} >> ".drllm/sessions/${session_id}/learning-log.md"
```

skip-only 이벤트:
```bash
{
  printf '[P5_SKIP] reason="%s"\n' "$SKIP_REASON"
} >> ".drllm/sessions/${session_id}/learning-log.md"
```

missing-only 이벤트:
```bash
{
  printf '[P5_MISSING] triggers=%s | reason="%s"\n' "$TRIGGERS" "$MISSING_REASON"
} >> ".drllm/sessions/${session_id}/learning-log.md"
```

### Grep verification — no unquoted heredoc in user-content path

After fix, `<<EOF` occurrences in operative skill files:

| File | Line | Content | User content? |
|------|------|---------|---------------|
| `skills/drllm-adaptive-tutoring/SKILL.md:164` | `cat >> learning-log.md <<EOF` | `[COMPLETE] ... duration_sec=${DURATION}` | No — `DURATION` is shell-computed integer |
| `skills/drllm-launcher/SKILL.md:66` | `cat > metadata.json <<EOF` | LLM-authored JSON (out of C1 scope) | No |

Remaining `<<EOF` in docs/reports are historical records in non-operative markdown (review archives), not executed code.

---

## I1 Important — §4 Session 종료 list cleanup

### Problem

Three issues in S4 §4:
1. Two items numbered `3.` — the second (사용자 요약) shadowed metadata.json update.
2. A vestigial `# NOW, DURATION already captured above` bash block with no actual command — inert dead code that confused readers.
3. A ```` ```json ```` fence containing `"completed_at": "${NOW}"` — a reader implementing this literally would serialize the string `${NOW}` into the JSON file, not the actual timestamp.

### Before (lines 160–175):

```
3. metadata.json 갱신:

   ```bash
   # NOW, DURATION already captured above
   ```

   ```json
   {
     "completed_at": "${NOW}",
     "status": "done"
   }
   ```

3. 사용자에게 요약 (한국어):
```

### After (lines 169–181):

```
3. metadata.json 갱신:

   ```bash
   jq --arg now "$NOW" --argjson dur "$DURATION" \
      '.completed_at = $now | .status = "done" | .duration_sec = $dur' \
      ".drllm/sessions/${session_id}/metadata.json" > /tmp/meta.$$.json \
      && mv /tmp/meta.$$.json ".drllm/sessions/${session_id}/metadata.json"
   ```

4. 사용자에게 요약 (한국어):
```

Changes:
1. Second `3.` → `4.` (renumbered)
2. `# NOW, DURATION already captured above` inert block removed
3. `json` fence replaced with `bash` jq invocation — `$now` and `$dur` passed as jq-scoped args, never re-interpreted by shell as field values

---

## Test output

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

---

## Out of scope (not changed)

- `skills/drllm-launcher/SKILL.md` — writes `metadata.json` (LLM-authored JSON, no user echo). Reviewer M2 note: defer consolidation to SP-2.
- `skills/drllm-research-execution/SKILL.md` — body may contain citation quotes but reviewer rated M2 Minor. Deferred.
- `§4 step 2` `[COMPLETE]` heredoc — uses shell-computed `${DURATION}` integer only, no user content. Correct to keep.
