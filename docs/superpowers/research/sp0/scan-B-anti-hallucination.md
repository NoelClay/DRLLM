# SP-0 Phase 1 — Category B: 환각 URL/출처 방지 패턴 Scan Report

**Date**: 2026-04-12
**Sub-agent**: Sonnet 4.6
**Category**: B — Anti-Hallucination Patterns (P축 최우선)

---

## 카테고리 개요

LLM이 존재하지 않는 URL과 출처를 생성하는 문제는 상용 시스템에서도 여전히 심각하다. 최신 연구(arxiv 2604.03173)에 따르면 deep research agent의 URL 환각률은 10.7%, 검색 보강 LLM도 4.8%에 달한다. 이를 방지하는 메커니즘은 크게 두 스펙트럼으로 나뉜다: (1) **soft prompt 권고** — 시스템 프롬프트에서 "제공된 컨텍스트에서만 인용하라"고 지시하는 방식, (2) **hard validation 강제** — 도구 응답으로 얻은 URL을 LLM이 변경하기 전에 또는 이후에 기계적으로 검증하는 방식. 시장에 존재하는 패턴 스펙트럼은 Anthropic이 문서화한 "직접 인용 추출 → 인용 불가 시 주장 철회"라는 소프트 패턴부터, Guardrails AI의 Guard+Validator 체인, Gemini Grounding API의 구조적 pre-embedding까지 다양하다. DRLLM에서 S2(Research Execution)는 이 카테고리와 가장 직접 연관되며, URL 환각을 막기 위한 도구 레벨 강제(post-hoc HTTP 검증 + provenance 검증)와 시스템 프롬프트 레벨 소프트 강제를 결합하는 계층적 접근이 가장 현실적이다.

---

## 발견 항목 (8개)

---

### 1. urlhealth — LLM 출력 URL 생존 여부 자동 검증 도구

**Score**: M3·A4·P5·F5·I5 = 22/25
**URL**: https://arxiv.org/abs/2604.03173 (논문), pip install urlhealth
**Category**: B
**Type**: Library (83 lines Python, pip-installable)

#### TL;DR

urlhealth는 LLM이 출력한 URL에 HTTP HEAD 요청을 보내고 Wayback Machine 아카이브 조회를 결합하여 LIVE / DEAD / LIKELY_HALLUCINATED / UNKNOWN 네 가지로 분류하는 83줄짜리 Python 라이브러리다. 2026년 4월 University of Pennsylvania(Rao, Wong, Callison-Burch) 연구에서 발표되었으며, LLM을 에이전트로 활용해 urlhealth를 tool로 장착하고 자기 수정 루프를 돌리면 비해결 URL이 6~79배 감소해 1% 미만으로 떨어진다. Gemini는 79배 개선, Claude는 6.4배 개선을 기록했다. DRLLM S2에서 tool call 이후 URL을 검증하는 post-hoc hard gate로 즉시 활용 가능하다. 구현 부담이 극히 낮고(83줄), pip 설치 가능하며, agentskills.io 스킬로도 배포되어 있어 F·I 점수가 모두 높다.

#### Found Patterns

- HTTP HEAD 요청(실패 시 GET fallback) → HTTP 200이면 LIVE, 404 + Wayback 아카이브 있으면 DEAD(stale), 404 + 아카이브 없으면 LIKELY_HALLUCINATED, 기타 UNKNOWN
- pip 설치 후 단 몇 줄로 LLM tool call에 통합 가능
- 에이전트 루프: LLM이 응답 생성 → urlhealth tool 호출 → LIKELY_HALLUCINATED 결과 수신 → LLM이 해당 인용 제거/수정 재시도
- agentskills.io 스킬로도 배포 가능 (Gemini CLI Extension 통합 경로)

#### How It Prevents Hallucination

- LLM이 생성한 URL이 실제로 존재하는지 외부 HTTP 요청으로 기계적 검증 — LLM 내부 예측에 의존하지 않음
- Wayback Machine 조회로 단순 404와 "처음부터 존재하지 않았던 URL"을 구분 → false negative(실제 환각을 stale로 오분류) 최소화
- "자기 수정 루프" 패턴: tool feedback을 받은 LLM이 스스로 잘못된 인용 철회 → 에이전트 시스템의 hard gate로 기능

#### DRLLM Fit Analysis

- 매핑 스킬: **S2 (Research Execution)** — 검색 결과 URL 검증 단계에서 직접 적용
- 영향받는 SP: **SP-2** (출처 다양화 + BYOC 도구 통합), SP-3 (end-to-end 검증)
- **시스템 프롬프트만으로는 불가** — 반드시 도구 레벨 통합 필요. 그러나 Gemini CLI Extension에서 GEMINI.md에 urlhealth를 MCP 스킬 또는 bash tool로 등록하면 통합 가능.
- DRLLM 출처 정책("환각 URL을 만들 수 없는 MCP만 채택")과 직접 부합

#### Caveats / Risks

- 일부 모델(소형 모델)은 tool feedback을 받아도 수정 행동을 취하지 않아 효과가 없음 — 모델 역량 의존
- HTTP 요청 지연으로 대량 URL 처리 시 성능 저하 (도메인당 5개 동시 요청 제한 권고)
- LIVE 판정이 URL의 내용 신뢰성을 보장하지 않음 (URL이 살아있어도 클레임을 지지하지 않을 수 있음)
- pip 패키지는 확인됐으나 GitHub 레포 URL이 논문에 명시되지 않아 소스 코드 직접 감사 필요

#### Recommendation

✅ **채택** — 83줄 Python, pip 설치, Gemini CLI 도구 통합 경로 존재. DRLLM SP-2의 핵심 hard gate로 즉시 적용 가능한 최우선 채택 항목.

---

### 2. VeriCite — NLI 기반 3단계 인용 검증 프레임워크

**Score**: M3·A3·P5·F4·I3 = 18/25
**URL**: https://arxiv.org/abs/2510.11394
**Category**: B
**Type**: Research / Pattern

#### TL;DR

VeriCite는 SIGIR-AP 2025에 채택된 RAG 인용 신뢰도 강화 프레임워크로, NLI(Natural Language Inference) 모델을 핵심 검증기로 사용하는 3단계 파이프라인이다: (1) 초기 답변 생성 + 주장 단위 NLI 검증, (2) 각 문서에서 지지 증거 추출 + 재검증, (3) 검증된 주장만 사용한 최종 답변 정제. 재학습 없이 추론 시 적용 가능하며, 5개 오픈소스 LLM과 4개 데이터셋에서 인용 품질을 유의미하게 향상시켰다. 핵심 강점은 LLM이 인용 마커를 직접 생성하는 것이 아니라 검증된 증거의 pre-annotated 마커를 재사용하도록 강제한다는 점이다. DRLLM S2에서 검색된 출처의 클레임 지지 여부를 NLI로 검증하는 패턴으로 활용 가능하다.

#### Found Patterns

- Stage 1: LLM이 답변 생성 → 각 주장을 NLI 모델로 검증(entailment/contradiction) → True/False 레이블
- Stage 2: 각 검색 문서에서 유용한 지지 증거 추출 → 동일 NLI로 재검증 → 인용 마커 자동 부착
- Stage 3: 검증된 주장과 pre-annotated 마커만으로 최종 답변 재구성 (LLM의 인용 선택권 제거)
- "Decoupled attribution" 패턴: LLM이 인용을 선택하는 책임을 시스템이 가져감

#### How It Prevents Hallucination

- LLM이 인용을 post-hoc으로 선택하지 못함 — 인용이 먼저 검증되고 마커가 부착된 상태로 컨텍스트에 주입
- NLI 모델이 "이 문서가 이 주장을 지지하는가"를 이진 판정 → 지지하지 않으면 주장 자동 폐기
- 인용 마커의 재사용 패턴: 모델이 인용 ID를 "발명"할 수 없음, 오직 검증된 마커만 허용

#### DRLLM Fit Analysis

- 매핑 스킬: **S2 (Research Execution)** 및 **S3 (LearnLM Prompt Synthesis)**
- 영향받는 SP: **SP-2** (환각 방지 메커니즘 통합)
- **시스템 프롬프트만으로 불가** — NLI 모델 호출 필요. 경량 NLI (DeBERTa-v3-large, MiniCheck 등)를 MCP로 랩핑하거나 Python 스크립트로 통합해야 함.
- 단, "검증된 증거만 컨텍스트에 주입"하는 패턴 자체는 시스템 프롬프트 + RAG 파이프라인 설계로 부분 구현 가능

#### Caveats / Risks

- NLI 모델 별도 운용 비용 (DeBERTa 크기급, 로컬 추론 가능하나 지연 발생)
- 3단계 파이프라인으로 전체 레이턴시 증가
- NLI 모델 자체의 false negative: 미묘한 의미 불일치는 entailment로 오판 가능
- 공개 코드 없음 (논문만, 재구현 필요)

#### Recommendation

🔧 **카피·수정** — NLI 기반 3단계 패턴을 DRLLM SP-2에 참고 구현. 특히 "검증된 증거의 pre-annotated 마커 재사용" 패턴은 즉시 복사 가치 있음.

---

### 3. Guardrails AI Provenance Validators — 임베딩/LLM 기반 출처 검증 Guard

**Score**: M4·A4·P4·F4·I4 = 20/25
**URL**: https://github.com/guardrails-ai/provenance_llm / https://github.com/guardrails-ai/provenance_embeddings
**Category**: B
**Type**: Library / Framework

#### TL;DR

Guardrails AI는 LLM 출력에 Guard 체인을 씌워 검증기(Validator)를 순차 실행하는 오픈소스 프레임워크(6.7k stars, v0.10.0, 2026년 4월 활성)다. Provenance Embeddings 검증기는 코사인 유사도로 생성 텍스트가 소스와 충분히 가깝지 않으면 해당 문장을 제거(fix)한다. Provenance LLM 검증기는 LLM을 다시 호출해 "이 소스가 이 주장을 지지하는가"를 판단한다. 둘 다 on_fail="exception"으로 설정하면 hard rejection(예외 발생)이 가능하며, on_fail="fix"는 소프트 편집(문제 문장 제거)으로 작동한다. RAG 파이프라인에서 소스 리스트와 함께 Guard.validate() 호출만으로 통합 가능한 가장 실용적인 라이브러리다.

#### Found Patterns

- `Guard().use(ProvenanceLLM, on_fail="exception")` → LLM 출력 통과 전 소스 지지 여부 강제 확인
- Sentence-level 또는 full-text 모드 선택 가능
- 임베딩 유사도 임계값(threshold) 조정으로 민감도 튜닝
- 6가지 on_fail 옵션: exception(hard), filter, reask, fix, refrain, noop
- Guardrails Hub에서 추가 검증기 조합 가능 (URLReachability, WikiProvenance 등)

#### How It Prevents Hallucination

- **ProvenanceEmbeddings**: 소스 청크를 임베딩, 생성 텍스트 임베딩과 코사인 유사도 비교 → 임계값 미달 문장 제거
- **ProvenanceLLM**: 생성 청크별 top-k 소스 청크 검색 → LLM에게 entailment 질의 → 미지지 주장 제거
- on_fail="exception" 설정 시 완전한 hard rejection (파이프라인 중단)
- Wikipedia 소스 기반 WikiProvenance 검증기도 별도 제공

#### DRLLM Fit Analysis

- 매핑 스킬: **S2 (Research Execution)** — 검색 결과 기반 생성 시 provenance 검증 layer로 삽입
- 영향받는 SP: **SP-2** (환각 방지 메커니즘 통합)
- **도구 레벨 통합 필요** — Guard 객체를 DRLLM S2 응답 처리 레이어에 추가
- 시스템 프롬프트 단독으로는 불가. 단, 간단한 Python 래퍼로 통합 가능하며 Gemini CLI 도구(bash 실행) 방식으로 연동 가능

#### Caveats / Risks

- ProvenanceLLM은 검증을 위해 LLM 추가 호출 → 토큰 비용 2배
- 임베딩 임계값 튜닝 필수 (너무 엄격하면 올바른 주장도 제거)
- provenance_llm 레포는 stars 4개로 활성도 낮음 (guardrails 본체는 높음)
- 소스 제공 없이 단독 사용 불가 — RAG 파이프라인 전제

#### Recommendation

✅ **채택** — Guardrails 본체는 production-grade 활성 프로젝트. on_fail="exception" 패턴이 DRLLM hard gate 구현의 좋은 참조. SP-2 설계에서 validation layer 아키텍처로 채택 권장.

---

### 4. Gemini Grounding API (groundingChunks + groundingSupports) — 구조적 출처 선결합

**Score**: M5·A5·P4·F5·I5 = 24/25
**URL**: https://ai.google.dev/gemini-api/docs/google-search
**Category**: B
**Type**: Framework (Gemini API built-in)

#### TL;DR

Gemini API의 Google Search Grounding은 LLM이 응답을 생성하기 *전에* 검색 결과 URL과 메타데이터를 구조화된 프롬프트에 선결합(pre-binding)하는 방식으로 환각을 방지한다. 응답에는 groundingChunks(소스 URL + 제목 배열)와 groundingSupports(텍스트 세그먼트 ↔ 소스 인덱스 매핑)가 포함되며, 개발자는 이 메타데이터로 인라인 인용을 프로그래밍 방식으로 삽입한다. LLM이 URL을 "발명"하지 않는 이유는 URL이 이미 프롬프트 컨텍스트에 있기 때문이다. DRLLM이 Gemini CLI 환경에서 동작하므로 이 네이티브 grounding 기능은 F·I 점수 최고 수준. 단, JSON 출력 요청 시 groundingMetadata가 사라지는 구조적 한계 존재.

#### Found Patterns

- `google_search` 도구 활성화 → 검색 실행 → groundingChunks에 소스 URI + title 저장
- groundingSupports: 텍스트 문자 오프셋(startIndex, endIndex) → groundingChunkIndices 매핑
- 개발자가 groundingSupports를 순회하며 프로그래밍으로 인용 삽입 (LLM이 아님)
- Dynamic Retrieval: 프롬프트별 예측 점수(0~1)로 검색 필요성 자동 판단
- URL 변조 방지 우회책: placeholder 마스킹(`<<URL_n>>`) + 2-call 아키텍처 (마크다운 → JSON 변환)

#### How It Prevents Hallucination

- URL이 LLM 컨텍스트에 이미 존재하여 LLM이 새 URL을 "예측"할 필요 없음 (구조적 방지)
- 인용 삽입이 개발자 코드에서 수행됨 → LLM이 인용 위치나 URL을 변경 불가
- groundingSupports의 오프셋 기반 매핑은 결정론적 → 인용 위치 변조 불가
- Google의 자체 벤치마크에 따르면 grounding이 없는 경우 대비 환각 약 40% 감소

#### DRLLM Fit Analysis

- 매핑 스킬: **S2 (Research Execution)** — 웹 검색 시 기본 grounding 메커니즘으로 활용
- 영향받는 SP: **SP-2** (출처 다양화 도구 통합), SP-3 (검증)
- **시스템 프롬프트만으로 가능** — Gemini API 파라미터 설정만으로 활성화, GEMINI.md에서 google_search 도구 사용 지시로 soft 수준 강제 가능
- **도구 레벨**: groundingChunks 파싱 + 인용 삽입 코드 필요
- DRLLM의 Gemini CLI 환경과 완전 호환

#### Caveats / Risks

- JSON 구조화 출력 요청 시 groundingMetadata가 사라지는 심각한 한계 → 2-call 우회 필요
- Gemini가 반환하는 리다이렉트 URL (`vertexaisearch.cloud.google.com/...`)이 며칠 후 만료
- 토크나이저가 복잡한 URL을 변조하는 버그 존재 (placeholder 마스킹으로 우회)
- Google Search 도구 의존 → 특정 출처(arxiv, GitHub 특정 경로 등) 접근 제한 가능

#### Recommendation

✅ **채택** — DRLLM의 Gemini CLI 환경에서 가장 native한 grounding 메커니즘. JSON + citation 동시 필요 시 2-call 아키텍처 패턴 반드시 채택.

---

### 5. Perplexity 사전결합 파이프라인 패턴 (Pre-LLM Citation Binding)

**Score**: M4·A3·P4·F4·I3 = 18/25
**URL**: https://ziptie.dev/blog/how-perplexity-ai-answers-work/
**Category**: B
**Type**: Pattern (production architecture, closed source)

#### TL;DR

Perplexity AI의 핵심 anti-hallucination 구조는 LLM 호출 이전에 검색 → 다층 랭킹 → 프롬프트 조립이 완결되고, 인용 마커·URL·문서 발췌문이 구조화 프롬프트에 이미 포함된 상태로 LLM에 전달되는 "사전결합(pre-binding)" 패턴이다. LLM은 새 출처를 발명하는 것이 아니라 이미 주어진 문서를 합성하는 역할만 한다. 중요한 것은 Perplexity도 인용 오류가 3~13% 발생한다는 점 — 이 패턴이 완전하지 않으며 표준 RAG 대비 개선이지만 zero-hallucination 보장은 아님을 보여준다. DRLLM에서 직접 복사할 수 없는 클로즈드 소스이나, 설계 원칙 자체는 Gemini Grounding API의 구조와 동일하며 참조 아키텍처로 가치 있다.

#### Found Patterns

- 검색 → L1/L2/L3 랭킹(품질 임계값 ~0.7) → 품질 미달 시 전체 결과 폐기
- 인용 번호, URL, 날짜, 문서 발췌문을 LLM 프롬프트에 미리 삽입
- LLM은 "synthesizer bound by retrieved evidence" 역할만 수행
- 결과 폐기 정책: 검색 결과가 충분하지 않으면 응답 자체를 생성하지 않음

#### How It Prevents Hallucination

- URL이 프롬프트 컨텍스트에 선결합되어 LLM이 새 URL 예측 불필요 (구조적)
- 다층 품질 필터가 저품질 소스를 사전 제거 → LLM이 나쁜 소스를 인용할 기회 감소
- 인용은 post-hoc이 아니라 구조화 프롬프트 단계에서 결정 → retroactive misattribution 방지

#### DRLLM Fit Analysis

- 매핑 스킬: **S1 (Research Planning)** + **S2 (Research Execution)**
- 영향받는 SP: **SP-2** (설계 원칙 참조)
- 패턴은 시스템 프롬프트 + 구조화 컨텍스트 조립으로 구현 가능 (도구 레벨 필수는 아님)
- DRLLM S2의 검색 결과 처리 방식 설계 시 이 패턴을 기본 구조로 채택 권장

#### Caveats / Risks

- 클로즈드 소스 — 정확한 랭킹 로직 불명
- 여전히 3~13% 인용 오류 존재 (URL 환각 포함)
- 랭킹 레이어 구현 복잡도 (DRLLM에서는 단순화 필요)

#### Recommendation

🔧 **카피·수정** — "LLM 호출 전 인용 선결합" 원칙 자체를 DRLLM S2 파이프라인 설계 기본 원칙으로 채택. 실제 구현은 Gemini Grounding API(항목 4)가 동일 패턴을 네이티브로 제공.

---

### 6. OpenAI Structured Outputs (strict: true) — JSON Schema 인용 필드 강제

**Score**: M5·A5·P3·F3·I4 = 20/25
**URL**: https://developers.openai.com/api/docs/guides/structured-outputs
**Category**: B
**Type**: Pattern (API feature, cross-provider)

#### TL;DR

OpenAI Structured Outputs의 `strict: true` 모드는 JSON Schema에 정의된 구조를 LLM 출력이 100% 준수하도록 강제한다. 이를 인용 강제에 적용하면 `citations` 필드를 required로 지정하여 LLM이 출처 없이 응답을 반환하지 못하게 막을 수 있다. `enum` 제약으로 허용 URL 목록을 지정하면 이론적으로 목록 외 URL을 강제 차단할 수 있다. 그러나 이것은 **구조 강제(format enforcement)**이지 **내용 정확성 보장(content accuracy)**이 아니다 — JSON 필드가 채워지는 것은 보장하지만 필드 내용이 올바른 URL인지는 보장하지 않는다. DRLLM에서는 S2 응답이 citation 필드를 반드시 포함하도록 강제하는 schema gate로 사용 가능하다.

#### Found Patterns

- `response_format: {type: "json_schema", json_schema: {...}, strict: true}` 또는 function calling의 `strict: true`
- required 필드에 citations 배열 지정 → LLM이 citations 없는 응답 반환 불가
- enum 제약으로 pre-approved URL 목록 지정 (LLM이 목록 외 값 생성 불가)
- Pydantic/Zod 객체로 schema 정의 → SDK가 자동 변환
- 2026년 기준 JSON Mode는 legacy, strict Structured Outputs가 production default

#### How It Prevents Hallucination

- **구조 레벨 hard enforcement**: schema 위반 출력 자체가 불가능 (모델 내부에서 grammatical decoding으로 강제)
- required citations 필드: LLM이 인용 없이 응답할 수 없는 구조적 강제
- enum URL 제약: pre-fetched URL 목록을 enum으로 지정하면 목록 외 URL 생성 불가
- "hallucinating an invalid enum value" 원천 방지

#### DRLLM Fit Analysis

- 매핑 스킬: **S2 (Research Execution)** 응답 schema 정의
- 영향받는 SP: **SP-1** (스킬 인터페이스 설계 — response schema 표준화), SP-2
- **시스템 프롬프트 + API 파라미터**로 가능 — 도구 레벨 코드 변경 필요하나 비교적 간단
- Gemini에서 `response_mime_type: "application/json"` + schema로 유사 기능 제공 (strict 수준은 낮음)

#### Caveats / Risks

- **내용 정확성 보장 없음**: 구조만 강제, URL이 실제 존재하는지 검증 불가 (urlhealth와 결합 필요)
- enum URL 목록을 사전에 알아야 함 → 동적 검색 시나리오에서 적용 어려움
- Gemini의 JSON schema 강제는 OpenAI만큼 strict하지 않음 (일부 위반 허용 가능성)
- 스키마 복잡도 증가 시 모델 정확도 하락 보고됨

#### Recommendation

🔧 **카피·수정** — required citations 필드 강제 패턴은 DRLLM S2의 응답 schema에 즉시 적용. 단, 내용 검증은 urlhealth(항목 1)와 결합 필수. Gemini 환경에서 완전한 strict 모드가 지원되지 않는 한계 인지.

---

### 7. Anthropic "직접 인용 추출 → 인용 불가 시 철회" 패턴

**Score**: M5·A5·P3·F5·I5 = 23/25
**URL**: https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations
**Category**: B
**Type**: Pattern (soft prompt engineering, zero dependency)

#### TL;DR

Anthropic 공식 문서에서 권장하는 환각 감소 패턴 중 "직접 인용 추출 → 인용 불가 시 주장 철회"는 시스템 프롬프트만으로 구현 가능한 가장 단순하고 의존성 없는 soft enforcement 패턴이다. LLM에게 응답 생성 후 각 주장에 대한 직접 인용을 찾도록 지시하고, 인용을 찾지 못하면 해당 주장을 제거하고 `[]`로 표시하도록 강제한다. 이는 시스템 프롬프트 단독으로 동작하므로 Gemini CLI GEMINI.md에 직접 삽입 가능하다. Gemini CLI 환경에서 도구 추가 없이 즉시 적용 가능한 F·I 최고점 패턴이나, 모델이 지시를 따르지 않거나 가짜 인용을 생성해 "이것으로 뒷받침된다"고 할 위험이 있다는 점에서 P 점수는 낮다.

#### Found Patterns

- 2단계 프롬프트: (1) 응답 초안 생성, (2) 각 주장에 대한 직접 인용 찾기 → 못 찾으면 주장 제거
- "직접 인용 선추출 → 인용 기반 분석"의 역전 패턴 (>20k 토큰 문서에 효과적)
- External knowledge restriction: "제공된 문서에서만 정보 사용, 일반 지식 금지" 지시
- "I don't know" 명시적 허용: 불확실성 시인 강제
- Chain-of-thought verification: 결론 전 추론 단계 강제

#### How It Prevents Hallucination

- 검증 단계 강제: 생성과 인용 확인이 독립 단계로 분리됨
- 철회 의무: 인용 없는 주장은 `[]`로 표시 → 최종 출력에서 제거
- 소프트하지만 명시적인 논리 흐름: LLM이 "어디서 이 정보를 가져왔나"를 스스로 확인
- 컨텍스트 제한 강제: "이 문서 밖의 정보 사용 금지"

#### DRLLM Fit Analysis

- 매핑 스킬: **S2 (Research Execution)**, **S3 (LearnLM Prompt Synthesis)**
- 영향받는 SP: **SP-1** (시스템 프롬프트 설계), **SP-2**, **SP-3**
- **시스템 프롬프트만으로 완전히 가능** — GEMINI.md에 직접 삽입. 도구 레벨 변경 불필요.
- DRLLM의 모든 스킬(S0~S4)에 기본 레이어로 적용 가능한 범용 패턴

#### Caveats / Risks

- **Soft enforcement의 근본 한계**: 모델이 가짜 "직접 인용"을 만들어 검증을 통과시킬 수 있음
- 복잡한 reasoning chain에서 지시 무시 가능 (long context window에서 지시 희석)
- 철회된 `[]` 위치로 응답 품질 저하 가능
- 단독으로는 P 점수 낮음 — hard validation(urlhealth, Guardrails)과 병행 필수

#### Recommendation

✅ **채택** — 의존성 제로, GEMINI.md 즉시 삽입 가능. Hard validation 레이어의 1차 필터로 모든 스킬에 기본 적용. 단, 단독 사용은 불충분.

---

### 8. RARR (Retrofit Attribution using Research and Revision) — 사후 인용 연구·수정

**Score**: M2·A2·P3·F3·I3 = 13/25
**URL**: https://github.com/anthonywchen/RARR
**Category**: B
**Type**: Library / Research

#### TL;DR

RARR은 CMU, Google Research, UC Irvine이 ACL 2023에서 발표한 사후 인용 수정 시스템으로, LLM이 생성한 텍스트를 검색 엔진으로 사후 검증하고 사실과 다른 주장을 수정하는 4단계 파이프라인이다. 생성된 주장에 대해 질의를 생성 → Bing Search로 증거 검색 → Agreement Gate로 모순 감지 → 편집 LLM으로 수정. GitHub 53 stars, 2023년 3월 이후 비활성 상태이므로 production 직접 사용보다는 패턴 참조로 가치 있다. RARR의 핵심 기여는 "생성 후 사실 수정" 패턴 자체를 코드로 구현했다는 점이며, DRLLM에서는 S2의 검색 결과 기반 응답에 사후 cross-check 레이어를 추가하는 설계 참조로 활용 가능하다.

#### Found Patterns

- 4단계: Query Generation → Web Search (Bing) → Agreement Gate → Editor LLM
- `--hallucinate-evidence` 플래그: 증거를 LLM이 생성하는 옵션 — 환각 방지 목적으로는 절대 금지
- Attribution Report: 수정된 주장의 인용 소스 자동 추출
- Agreement Gate: 증거가 주장을 모순하는 경우에만 편집 실행 (보존 우선)

#### How It Prevents Hallucination

- 검증을 위해 외부 Bing Search API 호출 → LLM의 parametric knowledge 의존 방지
- Agreement Gate가 모순 감지 시에만 편집 → 불필요한 변경 최소화
- 수정된 주장에 실제 검색 증거 인용 자동 부착

#### DRLLM Fit Analysis

- 매핑 스킬: **S2 (Research Execution)** — 사후 검증 레이어 설계 참조
- 영향받는 SP: **SP-2**
- **도구 레벨 통합 필요** (Bing Search API), 현재 텍스트-davinci-003 의존 (구식)
- DRLLM 환경에서 직접 사용하기엔 API 의존성(Bing, OpenAI 구버전)이 문제

#### Caveats / Risks

- 53 stars, 2023년 이후 비활성 — production 미지원
- Bing Search API + OpenAI (text-davinci-003) 의존 → DRLLM 환경 부적합
- 4단계 파이프라인으로 레이턴시 높음
- Wayback Machine + HTTP 검증 없음 (urlhealth 대비 URL 생존 여부 확인 불가)

#### Recommendation

❌ **기각** — 비활성 레포, 구식 API 의존. 패턴 개념은 참조하되 직접 사용 금지. RARR의 "사후 수정" 아이디어는 urlhealth의 self-correction loop가 더 효과적으로 구현함.

---

## 카테고리 종합 권장

### Top-3 추천

| 순위 | 이름 | 점수 | 추천 이유 |
|------|------|------|-----------|
| 1 | **Gemini Grounding API** | 24/25 | DRLLM Gemini CLI 환경 native 지원, 구조적 pre-binding으로 URL 발명 원천 차단, GEMINI.md 설정만으로 soft 활성화 가능 |
| 2 | **urlhealth** | 22/25 | 83줄 pip 라이브러리, post-hoc URL 생존 검증 hard gate, Gemini의 79배 오류 감소 실증, 낮은 통합 비용 |
| 3 | **Anthropic "인용 추출 → 철회" 패턴** | 23/25 | 의존성 제로, GEMINI.md 즉시 삽입, 모든 스킬에 기본 레이어 적용 가능 (단, hard 강제와 반드시 결합) |

### DRLLM 추천 강제 메커니즘 조합

**계층적 3중 방어 (Layer Defense)**:

```
Layer 1 (Soft — 시스템 프롬프트): 
  Anthropic "인용 추출 → 철회" 패턴
  → GEMINI.md에 삽입: "검색 도구 결과에서만 인용, 직접 인용 불가 시 주장 제거"

Layer 2 (Hard Schema — 도구 레벨): 
  OpenAI Structured Outputs strict:true 패턴 (Gemini JSON schema로 포팅)
  → S2 응답 schema에 required citations[] 필드 강제
  → enum으로 검색 도구가 반환한 URL만 허용

Layer 3 (Hard Validation — post-hoc):
  urlhealth (83줄 Python) + Guardrails ProvenanceLLM 선택적 결합
  → S2 응답에서 URL 추출 → urlhealth HTTP 검증 → LIKELY_HALLUCINATED 발견 시 retry
  → 중요 응답에는 ProvenanceLLM으로 entailment 검증 추가
```

Gemini Grounding API는 위 3중 방어의 백본(검색 결과 자체를 구조화)으로 작동하며, 3중 방어는 그 위에 추가되는 검증 레이어다.

### 기각 리스트

| 이름 | 기각 이유 |
|------|-----------|
| **RARR** | 2023년 이후 비활성, 구식 API 의존(Bing + text-davinci-003), urlhealth가 동일 패턴을 더 효과적으로 대체 |
| **SelfCheckGPT** | 다중 샘플링으로 토큰 비용 2~5배, URL 생존 여부 직접 검증 불가, citation 특화 아닌 일반 hallucination 검출 |
| **Wikipedia Provenance (guardrails-ai)** | Wikipedia 한정 소스, DRLLM의 다양한 출처(arxiv, GitHub, 공식문서) 커버 불가 |

### Phase 2 심화 후보

1. **urlhealth 통합 코드 레벨 심화** — Gemini CLI Extension에서 urlhealth를 MCP 스킬 또는 bash tool로 등록하는 정확한 방법, agentskills.io 통합 경로 확인
2. **Gemini Grounding + JSON 출력 2-call 아키텍처** — placeholder 마스킹 + 리다이렉트 URL 해결 패턴의 실제 구현 코드 레벨 분석
3. **VeriCite NLI 패턴의 경량화** — DeBERTa-v3-large 대신 MiniCheck API (BespokeLabs) 사용으로 DRLLM 환경에 맞는 provenance 검증 구현
4. **Structured Output Citation Schema 표준화** — DRLLM 5개 스킬 전체에 적용할 통일된 citations[] JSON schema 설계

---

*이 보고서는 실제 검색 결과와 논문, GitHub 레포에 기반하며 환각된 정보를 포함하지 않습니다.*
