---
name: drllm-research-execution
description: DRLLM research phase. Loads session metadata, decomposes topic into 2-4 subqueries (inline S1), calls fetch MCP in parallel, applies Layer 2 JSON schema 2-call hallucination defense, writes research-results.md with verified citations, chains to adaptive-tutoring. TRIGGER when drllm-launcher marker `__drllm_s0_done_*` detected or user invokes `/drllm:research`.
---

# S2 — DRLLM Research Execution

## Mission (한국어)

S0가 생성한 세션 메타를 읽고, 주제를 서브쿼리로 분해, fetch MCP로 출처 수집, 환각 방지 2-call 검증, `research-results.md` 작성, S4 체인.

## Inputs

- `.drllm/sessions/<session_id>/metadata.json` (S0 산출물)
- 환경 변수 `DRLLM_DOMAIN_PROFILE`, `DRLLM_RESEARCH_MAX_SUBQUERIES`

## Protocol (상세는 Task 10~12에서 확장)

1. metadata.json 로드, status=="research" 확인
2. domain profile 로드 (우선 참조 URL 힌트 확보)
3. **인라인 쿼리 분해** (LLM 1회 호출): 주제 → 2~4 서브쿼리
4. **fetch MCP 병렬 호출** (서브쿼리별)
5. **Layer 2 Call 1**: fetch 결과 → JSON schema 강제 응답 (summary + key_points + citations)
6. **Layer 2 Call 2**: citations 교차 검증 (exact substring match) → verified 필드 부착
7. verified=false citation 제거 후 `research-results.md` 작성
8. metadata.json 갱신: `url_verify_total`, `url_verify_count`, `url_verify_ratio`, `status="tutor"`
9. Marker tool 호출: `save_memory("__drllm_s2_done_<session_id>")`

## Hard Gate

- status != "research" → 에러 반환
- fetch MCP 모두 실패 (1회 재시도 후) → status="research_failed" + 사용자 보고, marker tool 호출 금지
- Call 2 모든 citations verified=false → research-results.md에 경고 명시, marker tool 호출 금지

## Outputs

- `.drllm/sessions/<session_id>/research-results.md`
- metadata.json 갱신
- marker tool 호출

## See Also

- `@./context/drllm-core.md` 섹션 4 (출처 규율)
- `@./context/domains/born2beroot.md` (도메인 프로파일)
