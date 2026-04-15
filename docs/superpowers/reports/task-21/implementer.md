# Task 21 Implementer Report

**Date**: 2026-04-14
**Branch**: feat/sp1-tiny-drllm
**Scope**: Task 21 (Scope A: S2 §7 metadata contract) + B1 fix (Scope B: §6.1 Citations integrity + drllm-core §6 HARD STOP-9)

---

## Pre-edit Structure Analysis

### SKILL.md before edits

- §1–§5: Protocol steps (세션 로드, 쿼리 분해, fetch MCP, Call 1, Call 2)
- §6: 후처리 — research-results.md 작성 (lines 108–144), included url_verify_total/count/ratio inline but no explicit row-count integrity rule
- §7: metadata.json 갱신 (lines 146–156) — already existed as a basic 4-field JSON block with no examples, no hard gate note, no explicit field types
- §8: 사용자에게 보고
- §9: Marker tool 호출

**Ambiguity resolved**: §7 already existed. Task 21 instruction says to add/replace with the expanded version (examples + hard gate). Replaced §7 in-place with augmented version (title updated to "Task 21에서 강조", added explicit field descriptions, 계산 예시, and Hard Gate note). No duplication.

### drllm-core.md §6 before edits

HARD STOPS 1–8. Item 8 added in Task 20 for timestamp protocol.

---

## Edits Applied

### 1. `context/drllm-core.md` — HARD STOP 9 added

**Before** (end of §6):
```
8. 모든 timestamp 필드 (`started_at`/`completed_at`/`generated_at`, 이벤트 tail ISO 8601) 는 §1.2 Timestamp Acquisition Protocol 의 `date -Iseconds` shell 호출로만 획득. LLM 이 직접 생성한 timestamp 는 세션 측정 무효화 (aggregate 에서 `[INVALID_TIMESTAMP]` 기록 후 제외).
```

**After** (appended):
```
9. `research-results.md` Citations 테이블 row 수 는 `metadata.json.url_verify_total` 과 반드시 일치 (B1). `verified=true` 인 citation 은 모두 테이블에 row 로 표시. 유사 URL (fragment 만 다름) 병합 금지. 불일치 시 세션 status 를 `research_failed` 로 남기고 사용자에게 원인 보고 (aggregate 에서 `[INVALID_CITATION_COUNT]` 기록 후 M1 제외).
```

### 2. `skills/drllm-research-execution/SKILL.md` — §6.1 + §7 (expanded)

**Before §7** (lines 146–156):
```markdown
### 7. metadata.json 갱신

````json
{
  ...
  "url_verify_total": <N>,
  "url_verify_count": <M>,
  "url_verify_ratio": <M/N>,
  "status": "tutor"
}
````
```

**After** — §6.1 inserted before §7, §7 title and content expanded:

- §6.1 adds: explicit row-per-citation rule, no-merge rule for fragment-differing URLs, self-check bash block using 4-space indent (not nested triple-backtick) with quoted variables `"$ROW_COUNT"` and `"$TOTAL"`.
- §7 title changed to "### 7. metadata.json 갱신 (Task 21에서 강조)", JSON block uses 4-space indent (not nested triple-backtick), adds 계산 예시 and Hard Gate note.

### 3. `docs/superpowers/bugs/B1-citations-count-mismatch.md`

`Status: open` → `Status: in_progress`

### 4. `docs/superpowers/bugs/README.md`

Index row B1: `open` → `in_progress`

---

## run-tests.sh Output

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

All 5 hook tests pass. L1 schema pass. L3 skipped (not yet implemented).

---

## Ambiguity Resolution

1. **§7 pre-existence**: SKILL.md already had a `### 7. metadata.json 갱신` block. The Task 21 instruction says to add it "matching Task 20's pattern" and provides a richer version. Decision: replace in-place (augment) rather than duplicate. The old basic JSON block is superseded by the new expanded version with title suffix "(Task 21에서 강조)", field descriptions, 계산 예시, and Hard Gate. No two §7 blocks exist.

2. **Nested triple-backtick for bash self-check**: Used 4-space indent (markdown indented code block) instead of triple-backtick to avoid nesting issues inside an outer markdown block context. Consistent with Task 21 instructions.

3. **§6.1 insertion point**: Placed immediately after the closing ```` ``` ```` of §6's markdown format block (line 144), before §7. This maintains logical flow: §6 defines what goes in the table → §6.1 mandates integrity → §7 records in metadata.

---

## Self-Review Checklist

- [x] All 3 edits applied: drllm-core §6-9, S2 §6.1, S2 §7 (expanded)
- [x] No unquoted `<<EOF` heredoc used in any bash snippet — self-check uses plain 4-space indented block, no heredoc
- [x] Self-check bash variables quoted: `"$ROW_COUNT"` and `"$TOTAL"`
- [x] Bug tracker B1 updated: open → in_progress in both B1.md and README.md
- [x] run-tests.sh PASS (5/5 hook tests, L1 schema)
- [x] Commit will be atomic: all 4 files (drllm-core.md, SKILL.md, B1.md, bugs/README.md) + this report in one commit

---

## Fix C1 + I1 + Semantic Reconciliation

**Date**: 2026-04-14
**Commit**: b560a07
**Scope**: Task 21 code review — 1 Critical (C1) + 1 Important (I1)

### Root Cause

The original B1 fix introduced a semantic conflict: §6 line 110 states
`citations.verified=false` 항목을 **제거**하므로 Citations 테이블은 verified-only 행만
포함한다. 그러나 §6.1 self-check 는 `url_verify_total` (전체 citations 수) 과
비교했다. 부분 검증 세션(예: 5개 citation 중 4개 verified) 에서는 ROW_COUNT=4 ≠
url_verify_total=5 이 되어 self-check 가 false-positive `research_failed` 를 발동하는
C1 Critical 버그가 생긴다.

§6 format example 의 `| 2 | <url> | ... | ❌ (제거됨) |` 행도 §6 line 110 규칙과
모순된다 (제거된 항목이 테이블에 나타나면 안 됨).

### Changes Applied

| File | Change |
|------|--------|
| `skills/drllm-research-execution/SKILL.md` | §6 format example: `❌ (제거됨)` 행 제거 + prose note 추가 |
| `skills/drllm-research-execution/SKILL.md` | §6.1 규칙: `url_verify_total` → `url_verify_count` (verified-only 테이블, §6 규칙) |
| `skills/drllm-research-execution/SKILL.md` | §6.1 self-check: `TOTAL`/`url_verify_total` → `COUNT`/`url_verify_count` + null guard 추가 (I1) |
| `context/drllm-core.md` | §6 HARD STOP-9: `url_verify_total` → `url_verify_count`, 테이블 정책 명시 |
| `docs/superpowers/bugs/B1-citations-count-mismatch.md` | Fix Plan 에 수정 근거 note 추가 |

### I1 Null Guard

`jq -r .url_verify_count` 가 `"null"` 또는 빈 문자열을 반환하는 경우(metadata.json 에
필드 누락 시) 기존 코드는 `ROW_COUNT != "null"` 비교로 조용히 `research_failed` 전이하여
진단 불가능한 로그를 남겼다. null guard 추가로 field-missing 케이스는 즉시 HARD STOP-9
진단 메시지와 함께 `exit 1` 처리.

### Verification

`./tools/run-tests.sh`: PASS (5/5 hook tests, L1 schema, L3 skip)
