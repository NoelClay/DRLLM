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

## Protocol

### 1. 세션 로드

- `session_id`는 호출 컨텍스트에서 주어진 값, 없으면 `.drllm/sessions/` 에서 `status=="research"` 인 가장 최근 항목 선택
- `metadata.json` 로드. `status != "research"` 면 에러 ("S2는 research 상태 세션만 실행")
- `domain` 필드로 `context/domains/<domain>.md` 로드

### 2. 인라인 쿼리 분해 (LLM 호출 1회)

주제를 2~4개 서브쿼리로 분해한다. 규칙:

- 각 서브쿼리는 단일 정답을 가진 구체 질문 (예: "InnoDB Buffer Pool의 정의", "innodb_buffer_pool_size 기본값", "128MiB가 기본값이 된 역사적 이유")
- 메타 질문 금지 ("X는 무엇인가?"는 OK, "X의 모든 것"은 금지)
- 도메인 프로파일의 우선 참조 URL을 힌트로 활용
- 최대 개수: `DRLLM_RESEARCH_MAX_SUBQUERIES` (default 4)

**출력 형식** (내부 JSON, 사용자에게는 표시 안 함):

```json
{
  "subqueries": [
    { "query": "...", "hint_url": "...", "source_type_expected": "official_docs" }
  ]
}
```

### 3. fetch MCP 병렬 호출

각 서브쿼리마다 fetch MCP를 호출한다:

- `hint_url` 이 있으면 먼저 그 URL을 fetch
- `hint_url` 이 없거나 응답이 빈 경우: web 검색(google_web_search)을 hint_url 생성용으로 사용 후 top-3 fetch
- fetch 결과는 raw text로 보존 (LLM 해석 전에 저장)
- 실패한 서브쿼리는 대안 쿼리로 1회 재시도 후 실패 기록
- 모든 서브쿼리 실패 → `status="research_failed"` 후 종료

### 4. Layer 2 Call 1 — 응답 생성 (schema 강제)

fetch 결과들을 결합하여 다음 JSON schema로 강제 응답 생성 (Gemini `response_schema`):

````json
{
  "type": "object",
  "properties": {
    "summary": { "type": "string", "minLength": 50 },
    "key_points": {
      "type": "array",
      "minItems": 2,
      "items": { "type": "string", "minLength": 20 }
    },
    "citations": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "properties": {
          "url": { "type": "string", "format": "uri", "pattern": "^https?://" },
          "quote": { "type": "string", "minLength": 15 },
          "source_type": {
            "type": "string",
            "enum": ["web", "official_docs", "github", "paper", "forum"]
          },
          "relevance_to_subquery": { "type": "string" }
        },
        "required": ["url", "quote", "source_type", "relevance_to_subquery"]
      }
    }
  },
  "required": ["summary", "key_points", "citations"]
}
````

**시스템 프롬프트**:

> "아래 fetch 결과들에서만 `citations.url`과 `citations.quote`를 추출하라. 추측으로 URL/quote를 생성하지 말라. fetch 결과에 없는 정보는 반드시 생략하라."

Gemini response_schema 실패 시 1회 재시도, 그래도 실패 시 에러 보고 및 종료.

(나머지 §5~§9 는 Task 12 에서 확장)

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
