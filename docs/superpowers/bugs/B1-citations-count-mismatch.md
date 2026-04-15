# B1 — S2 citations count ≠ metadata url_verify_total

**Severity**: Important
**Status**: open
**Scheduled**: Task 21 (S2 metadata recording 강화)
**Filed**: 2026-04-15 (STEP 4 smoke, M1 2차 InnoDB 세션)

## Observed

Session: `.drllm/sessions/20260415-innodb-buffer-pool-default-size/`

`metadata.json`:
```json
{
  "url_verify_total": 2,
  "url_verify_count": 2,
  "url_verify_ratio": 1.0
}
```

`research-results.md` Citations 테이블:
```
| # | URL | Quote | Source Type | Verified |
|---|-----|-------|-------------|----------|
| 1 | https://dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool-resize.html | ... | official_docs | ✅ |
```

**Citations 테이블 row = 1개**, 그러나 **metadata url_verify_total = 2**. 값이 맞지 않음.

## 재현 경로

- `/drllm:launch "InnoDB Buffer Pool 왜 128MiB?"` 실행
- S2 가 fetch MCP 로 2개 URL 호출 + GoogleSearch 2회 호출
- Layer 2 Call 2 에서 URL verify 결과를 metadata 에 쓰고, research-results.md Citations 테이블에도 row 를 생성
- 이 단계에서 둘이 갈라짐

## Root Cause Hypothesis

Layer 2 Call 2 의 JSON 스키마 산출물에서:
- `verified_citations` 배열이 2개 (둘 다 fetch 성공) → metadata count 에 반영
- 그러나 markdown 렌더링 단계에서 LLM 이 1개 citation 만 테이블에 기재 (두 번째가 drop)

가능한 원인:
1. Citations 테이블 렌더링 시 LLM 이 중복/유사 URL 을 병합
2. 두 번째 URL (`innodb-parameters.html#sysvar_innodb_buffer_pool_size`) 는 앵커만 다르고 기본 URL 이 유사 → LLM 이 단일 row 로 통합
3. S2 SKILL.md §6 (Citations 테이블 구성 지시) 가 "각 verified URL 마다 1 row" 를 literal 로 강제하지 않음

## Fix Plan

**Task 21 (S2 metadata 기록 강화)** 단계에서:
- S2 SKILL.md 에 §6.1 신설: "Citations 테이블 row 수 = verified URL 수. 중복 앵커 (같은 URL 의 `#fragment` 차이)는 별도 row 로 기재. row 수와 `url_verify_total` 불일치 시 `metadata.json` 작성 금지 (HARD STOP)"
- L3 aggregation (Task 22) 에서 검증: `jq '.url_verify_total' metadata.json` 과 `grep -c '^|' research-results.md Citations section` 가 불일치하면 `[INVALID_CITATION_COUNT]` 이벤트 기록
- drllm-core.md §6 HARD STOPS 에 "metadata.url_verify_total 은 Citations 테이블 row 수와 일치" 규칙 추가

## Verification

Fix 후:
- 동일 세션 재실행 또는 기존 invalid 세션에 대해 aggregate 스크립트 돌려서 `[INVALID_CITATION_COUNT]` 가 없고 `total_citations == url_verify_total` 인지 확인
- M1 POC 3 시나리오 (Task 25-27) 결과 metadata vs markdown 일관성 100%
