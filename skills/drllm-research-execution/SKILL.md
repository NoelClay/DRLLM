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

### 5. Layer 2 Call 2 — 교차 검증

Call 1의 citations 배열과 fetch 결과 raw text를 함께 LLM에 전달하여 검증:

**시스템 프롬프트**:

> "각 citation에 대해 다음을 검증하라:
> (a) `url` 이 fetch 결과의 source URL 목록에 등장하는가?
> (b) `quote` 가 fetch 결과 본문에 exact substring으로 포함되는가? (공백/개행 normalize는 허용)
> (a)와 (b) 모두 true면 `verified=true`, 하나라도 false면 `verified=false` + `reason` 필드 추가.
> 같은 schema를 유지하되 `verified` (boolean) 필드를 각 citation에 추가하라."

### 6. 후처리 — research-results.md 작성

- `citations.verified=false` 인 항목 제거
- `url_verify_total = Call 1의 전체 citations 수`
- `url_verify_count = verified=true 인 수`
- `url_verify_ratio = url_verify_count / url_verify_total` (소수점 3자리)

**research-results.md 포맷**:

`generated_at` 은 LLM 직접 생성 금지 — shell 호출로 획득 (§1.2 Timestamp Acquisition Protocol, §6-8):

````bash
NOW=$(date -Iseconds)
````

````markdown
---
session_id: <session_id>
generated_at: ${NOW}
subqueries_count: <N>
citations_verified: <count>/<total>
---

## Summary
<Call 1의 summary, 한국어>

## Key Points
- <Call 1의 key_points[0]>
- <Call 1의 key_points[1]>
...

## Citations
| # | URL | Quote | Source Type | Verified |
|---|-----|-------|-------------|----------|
| 1 | <url> | "<quote>" | <source_type> | ✅ |
````

> verified=false 인 citation 은 테이블에 포함하지 않음 (§6 line 110 규칙).

### 6.1 Citations 테이블 무결성 (v2.2 B1 fix)

**규칙**:
- Call 2 에서 `verified=true` 로 판정된 citation 은 빠짐없이 Citations 테이블에 **각각 별도 row** 로 기재.
- 유사 URL (같은 base URL + 다른 `#fragment` 또는 `?query`) 은 **별도 row 로 유지**. 병합 금지.
- Citations 테이블 row 수 = `url_verify_count` (verified-only 테이블, §6 규칙) 이어야 함. 불일치 시 self-check 에서 감지하여 §6 HARD STOP-9 에 따라 `status="research_failed"` 전이.

**Self-check (종료 직전)**:

    ROW_COUNT=$(grep -c '^| [0-9]' .drllm/sessions/<id>/research-results.md)
    COUNT=$(jq -r .url_verify_count .drllm/sessions/<id>/metadata.json)
    if [ -z "$COUNT" ] || [ "$COUNT" = "null" ]; then
      echo >&2 "[S2] HARD STOP-9: url_verify_count field missing in metadata.json"
      exit 1
    fi
    if [ "$ROW_COUNT" != "$COUNT" ]; then
      # HARD STOP-9 위반
      jq '.status = "research_failed"' metadata.json > /tmp/m.$$ && mv /tmp/m.$$ metadata.json
      echo >&2 "[S2] HARD STOP-9: Citations count mismatch — table=$ROW_COUNT meta.url_verify_count=$COUNT"
      exit 1
    fi

### 7. metadata.json 갱신 (Task 21에서 강조)

S2 종료 전 다음 필드 반드시 갱신:

    {
      ...
      "url_verify_total": <Call 1 citations 전체 수, 정수>,
      "url_verify_count": <verified=true 인 수, 정수>,
      "url_verify_ratio": <count/total, 소수점 3자리>,
      "status": "tutor"
    }

**계산 예시**:
- Call 1 citations = 5개
- Call 2 verified=true = 4개
- ratio = 0.800

**Hard Gate**: 이 필드들을 기록하지 않으면 M1 POC aggregate에 반영되지 않음 — 세션 제외.

### 8. 사용자에게 보고 (한국어)

> "리서치 완료. 출처 검증 비율: <M>/<N> (<ratio>). 학습 대화 시작 준비 완료."

### 9. Marker tool 호출

`save_memory("__drllm_s2_done_<session_id>")` — hook이 감지하여 S4 체인.

**Hard Gate**: `url_verify_ratio < 0.5` 인 경우 marker tool 호출 금지. research-results.md 에 "⚠️ 출처 검증률 낮음" 경고 + 사용자에게 S4 진입 계속 여부 질문.

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
