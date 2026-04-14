# SP-0 Research Plan — DRLLM 선행 GitHub Deep Research

**Date**: 2026-04-12
**Status**: Draft → Pending User Review
**Scope**: SP-0 (Sub-Project 0) — DRLLM 본 설계에 선행하는 GitHub 생태계 조사

---

## 1. Context — DRLLM 재정의

기존 `DRLLM_PLAN.md`는 "Born2beRoot 학습 튜터"로 출발했으나, 사용자 피드백을 반영해 다음과 같이 본질이 재정의되었다.

### 1.1 새 본질

**DRLLM = "임의 도메인 → Deep Research 계획·실행 → LearnLM 교수법 변환 → 인출 기반 학습 대화"의 메타-프레임워크 시스템**, Gemini CLI Extension 형태로 패키징.

- Born2beRoot는 *첫 검증 케이스(SP-3)*일 뿐, 시스템 자체는 도메인-agnostic.
- 사용자가 주제를 입력하면 → Extension이 동적으로 리서치 계획 생성 → 실행 → 학습 컨텐츠로 변환 → P5(메타인지) 기반 대화 진행.

### 1.2 5개+ 분화된 스킬 (사용자 정의)

| # | 스킬 | 역할 |
|---|------|------|
| **S0** | Launcher | Extension 진입점, 주제 수신, 다음 스킬 호출 |
| **S1** | Research Planning | 주제 → 어떤 출처(논문/GitHub/포럼/공식문서/BYOC)에서 무엇을 찾을지 계획 |
| **S2** | Research Execution | 계획에 따라 검색, 환각 URL 차단, 출처 라벨링 |
| **S3** | LearnLM Prompt Synthesis | 리서치 결과 → 주제별 맞춤 LearnLM 교수법 프롬프트 동적 생성 |
| **S4** | Adaptive Tutoring | 학습 진행, P5 인출 기반 검증, 메타인지 추적 |
| (보조) | Hooks / Sub-agents | 자원 최적화, 병렬 처리 |

### 1.3 출처 정책 — 두 축

1. **검증된 도구만 사용**: 환각 URL을 만들 수 없는 MCP만 채택. 도구가 실제 응답을 그대로 반환해야 함.
2. **출처 다양성**: 논문 / GitHub Issue·PR / StackOverflow / Reddit / 공식문서 / **BYOC(사용자 제공 자료)** 모두 1급 출처.

### 1.4 Workflow 강제 — Superpowers 스타일

- 스킬 분화 (파일 단위)
- Hard Gate (다음 단계 진입 차단)
- 체크리스트 강제
- 다음 스킬 자동 호출

이 4중 메커니즘이 Gemini CLI 환경에서 어디까지 가능한지 SP-0에서 확인.

---

## 2. Sub-Project 분해

DRLLM은 단일 spec 크기를 넘어서므로 4개 sub-project로 분해. 각 SP는 자체 spec → plan → 구현 사이클을 갖는다.

| SP | 주제 | 산출물 |
|----|------|--------|
| **SP-0** | GitHub Deep Research (선행 조사) | 종합 리서치 보고서, SP-1~3 설계 입력 |
| **SP-1** | Skill 시스템 설계 | 5개 스킬 인터페이스, 호출 체인, hard gate 구현 방식 |
| **SP-2** | 출처 다양화 + BYOC 도구 통합 | MCP 조합, 환각 방지 메커니즘 통합 |
| **SP-3** | 첫 도메인 end-to-end 검증 | Born2beRoot로 전체 워크플로우 검증 |

본 문서는 **SP-0** 만 다룬다.

---

## 3. SP-0 목표

### 3.1 최종 산출물

`docs/superpowers/research/2026-04-12-sp0-final-report.md` — 6개 카테고리 통합 보고서:

- 카테고리별 발견된 도구/패턴 목록 + 다축 점수
- 분류: ✅ 채택 / 🔧 카피·수정 / ❌ 기각
- SP-1/2/3 설계에 미치는 영향
- 권장 도구·패턴 조합

### 3.2 진행 형식

3단계 구성:

```
[Phase 1: 광범위 스캔]
  Main (Opus 4.6, 현재 세션)
    ↓ Agent dispatch (sonnet 4.6) × 6 (병렬)
  Sub-agent 각각:
    1. 카테고리 내 GitHub 레포·MCP·Extension·패턴 조사
    2. 결과를 보고서 파일로 저장
       → docs/superpowers/research/sp0/scan-{X}-{topic}.md
    3. 메인 반환:
       - 다축 점수 (M·A·P·F·I)
       - 한 단락 요약 (5~10문장)
    ↓
  Main: 6개 요약+점수 검토 → "전문 읽을지" 결정
  Main: 심화할 카테고리 선정 + 사용자 합의

[Phase 2: 심화 딥리서치]
  선정된 카테고리에 대해 더 깊은 task로 sub-agent 재dispatch
  → docs/superpowers/research/sp0/deep-{topic}.md

[Phase 3: 종합]
  Main이 모든 보고서를 통합하여 final-report 작성
  → SP-1/2/3 설계 방향 결정
```

---

## 4. 다축 점수 정의

각 발견 항목은 5개 축을 1~5로 평가, 합산 25점 만점. 보고서 첫 줄에 `M_·A_·P_·F_·I_ = _/25` 표기.

| 축 | 의미 | 평가 신호 |
|----|------|-----------|
| **M (Maturity)** | 성숙도 — 안정성, 검증 정도 | 버전, 다운로드 수, production 사용 사례 |
| **A (Activity)** | 활성도 — 유지보수 건강도 | 최근 3개월 commit, issue 응답 속도, contributor 수 |
| **P (Performance)** | 성능 — DRLLM 핵심 성능 | 환각 방지 강도, 출처 정확도, 결과 풍부도, 응답 속도 |
| **F (Fit)** | 적합성 — DRLLM use case 정합성 | BYOC/스킬 분화/출처 다양성/워크플로우 강제 등 우리 요구 충족도 |
| **I (Integrability)** | 통합성 — Gemini CLI 통합 난이도 (역수) | MCP 표준 준수, 설치 단순함, 의존성 최소성 |

### 4.1 Threshold

| 합산 점수 | 처리 |
|----------|------|
| **≥ 18** | 자동 심화 후보. Phase 2에서 깊이 분석. |
| **12 ~ 17** | 메인이 요약 보고 후 사용자와 함께 결정. |
| **< 12** | 기각. 보고서에 기각 사유 기록. |

---

## 5. Sub-agent 보고서 템플릿

각 sub-agent는 발견 항목별로 다음 구조의 마크다운 섹션 생성. 카테고리 하나의 scan 파일 안에 여러 항목이 들어갈 수 있다.

```markdown
# [도구/패턴 이름]
**Score**: M_·A_·P_·F_·I_ = _/25
**URL**: <github URL>
**Category**: [A/B/C/D/E/F]
**Type**: [MCP / Extension / Pattern / Library / SaaS]

## TL;DR (한 단락, 5~10문장)
무엇인지, 무엇을 잘하고, 무엇이 약한지, DRLLM 어디에 쓸지.

## Found Tools / Capabilities
- 핵심 기능 리스트
- API/CLI 인터페이스
- MCP tool 리스트 (해당 시)

## Patterns Worth Copying
- 코드/설계 패턴
- 강제 메커니즘
- 환각 방지 기법

## DRLLM Fit Analysis
- 매핑 스킬: [S0/S1/S2/S3/S4 중 어느 것]
- 영향받는 SP: [SP-1/SP-2/SP-3]
- 교차 발견 (다른 카테고리에서 유사 발견 시 cross-link)

## Caveats / Risks
- 라이선스
- 의존성
- 유지보수 위험
- 알려진 이슈

## Recommendation
- ✅ 채택 / 🔧 카피·수정 / ❌ 기각 + 1줄 이유
```

---

## 6. 카테고리별 Sub-agent Prompt (6개)

각 sub-agent는 **sonnet 4.6**으로 dispatch. 산출물(보고서)은 디스크에, 신호(점수+요약)는 메인 컨텍스트에 반환.

### Category A — 출처 다양화 MCP/도구 (P축 최우선)

**Mission**: DRLLM이 환각 없이 다양한 출처에서 정보를 검색할 수 있게 해줄 MCP 서버/도구 발굴. 4개 서브영역 — A1 학술논문, A2 GitHub 코드/이슈, A3 커뮤니티(StackOverflow/Reddit/HackerNews), A4 공식문서/웹.

**Search Strategy**:
- GitHub Topics: `mcp-server`, `model-context-protocol`, `gemini-cli-extension`
- 카탈로그: `awesome-mcp-servers`, `Piebald-AI/awesome-gemini-cli`, `modelcontextprotocol/servers`
- 키워드: `arxiv mcp`, `semantic-scholar mcp`, `github mcp`, `stackoverflow mcp`, `reddit mcp`, `web search mcp`, `deepresearch`
- 후보 우선순위: `openags/paper-search-mcp`, `blazickjp/arxiv-mcp-server`, `zongmin-yu/semantic-scholar-fastmcp-mcp-server`, GitHub 공식 MCP

**평가 강조**: P (실제 fetch 결과 그대로 반환 vs LLM 합성 — 환각 방지 강도) > F (출처 라벨링 가능성)

**Output**: `docs/superpowers/research/sp0/scan-A-sources.md`

---

### Category B — 환각 URL/출처 방지 패턴 (P축 최우선)

**Mission**: 도구가 아니라 **설계 패턴** 발굴. LLM이 가짜 URL/출처를 만들지 못하게 강제하는 시스템적 메커니즘.

**Search Strategy**:
- 키워드: `citation enforcement`, `hallucination detection`, `url verification`, `source attribution`, `verified-citation`, `grounded generation`
- 분석 대상: Perplexity 클론, search-and-cite wrapper, RAG framework 중 강제 라벨링 패턴
- 코드 레벨 패턴: tool 응답 후 LLM이 raw URL을 변경 못 하게 하는 구조, response schema validation, post-hoc verification step
- 학술/엔지니어링 사례: Anthropic constitutional AI 패턴, OpenAI function calling 강제 응답 schema

**평가 강조**: P (강제 강도 — soft 권고 vs hard validation) > F (Gemini CLI 환경에서 시스템 프롬프트만으로 가능한가, 도구 레벨 강제까지 필요한가)

**Output**: `docs/superpowers/research/sp0/scan-B-anti-hallucination.md`

---

### Category C — Workflow 강제 메커니즘 (Superpowers 스타일) (F·I축 최우선)

**Mission**: "스킬 분화 + Hard Gate + 체크리스트 강제 + 다음 스킬 자동 호출" 4중 메커니즘이 Gemini CLI 환경에서 가능한 방법 발굴.

**Search Strategy**:
- **Superpowers 자체 직접 분석** (필수): `/home/namykim/.claude/plugins/cache/claude-plugins-official/superpowers/` 의 skill 정의 파일, hard-gate 패턴, brainstorming 스킬의 체크리스트 강제 메커니즘 코드 레벨 분석
- Gemini CLI 공식 docs/source: `commands/`, `tools/`, `agent` 관련 영역
- 키워드: `gemini-cli command`, `gemini extension multi-step`, `gemini workflow`, `gemini skill`, `gemini agent`
- Claude Skill SDK 패턴이 Gemini로 포팅된 사례
- Anthropic Agent SDK 패턴 (참고)

**평가 강조**: F (4중 메커니즘 중 몇 개를 Gemini가 지원하는가) > I (Extension 표준 안에서 구현 가능한가)

**보너스 신호**: Superpowers의 brainstorming/writing-plans/test-driven-development 같은 메타-스킬이 어떻게 다음 스킬을 강제 호출하는지 코드 패턴 추출.

**Output**: `docs/superpowers/research/sp0/scan-C-workflow-enforcement.md`

---

### Category D — Gemini CLI Extension 생태계 (F·I축 최우선)

**Mission**: 잘 만들어진 복잡한 Extension을 카피·참고할 수 있는 모범 사례 분석. 단순 GEMINI.md 1장짜리가 아닌 멀티-스킬/다중 MCP/조건부 로딩 등을 가진 것 우선.

**Search Strategy**:
- `Piebald-AI/awesome-gemini-cli` 전수 스캔
- GitHub Topics: `gemini-extension`, `gemini-cli-extension`
- 별 100+ 또는 production 사용 사례
- LearnLM 활용한 Extension (있다면 우선순위 ★★★)
- 조건부/다중 GEMINI.md 패턴 보유 사례
- 복잡한 워크플로우 (research, planning, multi-step) Extension

**평가 강조**: F (DRLLM 5개 스킬 분화에 참고할 구조인가) > I (Extension 표준 모범 사례인가)

**Output**: `docs/superpowers/research/sp0/scan-D-gemini-extensions.md`

---

### Category E — Gemini CLI 본체 capability (M·F축 최우선)

**Mission**: Gemini CLI 자체가 hooks, sub-agent dispatch, slash command, conditional context, skill 시스템 등 메타 기능을 지원하는지 본체 소스/공식 docs로 확인. (C/D는 외부 패턴, **E는 본체 기능**)

**Search Strategy**:
- `google-gemini/gemini-cli` 레포 직접 — `docs/`, `packages/`, `src/`
- 핵심 폴더: `docs/extensions/`, `docs/commands/`, `docs/configuration/`, `docs/tools/`, `docs/cli/`
- 최근 30일 issues/PRs 중 hooks·agent·skill 키워드
- Roadmap, milestones, RFC, CHANGELOG
- 공식 site: `google-gemini.github.io/gemini-cli/`
- 비교: Claude Code의 hooks/Agent/Skill 시스템과 1:1 매핑 시도

**평가 강조**: M (실험 기능 vs 정식 지원) > F (DRLLM 5스킬+워크플로우 강제에 직접 활용 가능성)

**Output**: `docs/superpowers/research/sp0/scan-E-gemini-cli-capabilities.md`

---

### Category F — BYOC Deep Review (P·F축 최우선) ⭐ 신규

**Mission**: 사용자가 합법적으로 보유한 자료(**PDF, EPUB, 비디오 transcript, 강의 슬라이드, 유료 콘텐츠**)를 시스템이 **통독 → 구조 매핑 → 질문 라우팅**하여 "이 책 X챕터 Y섹션이 다음 논리로 답을 준다" 형태의 응답을 만들 수 있는 도구/패턴 발굴.

**기존 RAG와 차별점 (반드시 명시)**:
- ❌ Top-k chunk retrieval + 합성 (단순 RAG)
- ✅ 전체 통독 → 목차/구조 인지 → 특정 질문에 대해 자료 위치 + 논리 흐름 답변
- 핵심: long-context LLM 활용 + 자료의 "지도 그리기"

**Search Strategy**:
- 키워드: `pdf deep analysis`, `document understanding mcp`, `long-context book analysis`, `structured pdf reading`, `epub mcp`, `youtube transcript mcp`, `lecture analysis llm`, `book indexing for tutoring`, `content map`
- 카탈로그: `awesome-mcp-servers` 의 document/PDF 섹션, `awesome-rag` (단순 RAG는 제외 기준)
- 특수 사례: NotebookLM 클론, Anthropic Claude PDF 처리 패턴, Gemini 1M context 활용 사례
- 영상 처리: `yt-dlp` + `whisper` + transcript 처리 chain, YouTube transcript MCP
- 비교 (구조 매핑만 참고): LightRAG, GraphRAG — RAG가 아닌 구조화 부분만 추출

**평가 강조**: P (통독 깊이 + 구조 인지 정확도) > F (학습 튜터 컨텍스트 — "이 자료가 어디서 답을 주는지"를 명시할 수 있는가) > I (Gemini CLI Extension 통합 난이도)

**보너스 신호**: 자료의 라이선스/저작권 안전 처리 (로컬 처리, 외부 송신 없음).

**Output**: `docs/superpowers/research/sp0/scan-F-byoc-deep-review.md`

---

## 7. Phase 별 진행 절차

### Phase 1 — 광범위 스캔 (병렬)

1. Main이 6개 sub-agent를 **단일 메시지에서 병렬 dispatch** (sonnet 4.6).
2. 각 sub-agent는 자기 카테고리 prompt에 따라 조사 → 보고서 파일 저장 → 점수+요약 반환.
3. Main은 6개 결과를 받아 표로 정리.

### Phase 1 종료 후 결정 게이트

Main이 사용자에게 다음을 보고:

- 6개 카테고리 결과 표 (점수 + 한 단락 요약)
- 카테고리별 핵심 발견 항목 강조
- Phase 2 심화 후보 (점수 ≥ 18 자동 / 점수 12~17 중 사용자가 우선순위로 지정한 항목 / SP-1·2·3 설계 방향에 결정적 영향 있다고 메인이 판단한 항목)

사용자 확인 후 Phase 2 진입.

### Phase 2 — 심화 딥리서치

1. 선정된 카테고리에 대해 sub-agent 재dispatch.
2. 새 task: "Phase 1에서 발견된 항목 X, Y, Z를 코드 레벨/문서 레벨로 깊이 분석. DRLLM 스킬 매핑까지 명시."
3. 보고서: `docs/superpowers/research/sp0/deep-{topic}.md`

### Phase 3 — 종합

1. Main이 모든 보고서 통합.
2. `docs/superpowers/research/2026-04-12-sp0-final-report.md` 작성.
3. 포함:
   - 카테고리별 권장 도구/패턴
   - SP-1/2/3 설계 방향
   - 채택 vs 카피·수정 vs 기각 분류
4. 사용자 리뷰 후 SP-1 brainstorming으로 진입.

---

## 8. Sub-agent 실행 모델

| 항목 | 정의 |
|------|------|
| 모델 | Claude Sonnet 4.6 |
| Dispatch 방식 | `Agent` 도구, `subagent_type: "general-purpose"` (기본), 카테고리당 1개 |
| 병렬성 | Phase 1은 6개 동시 (단일 메시지에서 6 tool call) |
| 산출물 | 보고서 파일 (디스크에 저장) |
| 메인 반환 | 다축 점수 + 한 단락 요약 (≤ 200 단어) |
| 도구 권한 | `*` (전체 권한 — Bash/Read/Write/Grep/Glob/WebFetch/WebSearch 모두 필요) |
| Isolation | 기본 (별도 워크트리 불필요 — 보고서 파일만 생성) |
| 중단 정책 | sub-agent 실패 시 메인이 재시도 또는 사용자에게 보고 |

---

## 9. 결정 게이트 — 사용자 확인 지점

| 게이트 | 위치 | 사용자 결정 사항 |
|--------|------|------------------|
| **G1** | 본 문서 작성 직후 | spec 자체의 승인 (이 문서) |
| **G2** | Phase 1 결과 후 | 심화 카테고리 선정 / 추가 카테고리 필요 여부 |
| **G3** | Phase 2 결과 후 | 추가 심화 필요 여부 / final report 진입 |
| **G4** | Phase 3 final report 후 | SP-1 brainstorming 진입 / 본 문서 또는 SP-1 spec 수정 필요 여부 |

---

## 10. 비용/시간 추정

| 항목 | 추정 |
|------|------|
| Phase 1 (병렬 6개) | 토큰: 중간 / 시간: 30~60분 |
| Phase 2 (심화 2~4개) | 토큰: 큼 / 시간: 60~120분 |
| Phase 3 (종합) | 토큰: 작음 / 시간: 30분 |
| 보고서 디스크 사용량 | 8~14개 마크다운 파일, 총 ~200~500KB |

(실제 비용은 Phase 1 결과 후 Phase 2 범위에 따라 변동)

---

## 11. 본 문서 이후 흐름

```
[현재] SP-0 spec 작성 완료
   ↓
G1: 사용자 spec 리뷰 (요청 중)
   ↓ 승인
Phase 1 실행 (6 sub-agents 병렬)
   ↓
G2: Phase 1 결과 보고 + 심화 카테고리 선정
   ↓ 승인
Phase 2 실행 (선정된 카테고리 심화)
   ↓
G3: 추가 심화 여부 확인
   ↓
Phase 3: final-report 작성
   ↓
G4: SP-1 brainstorming 진입
```

---

## Appendix A — 참고 링크

- Gemini CLI 공식: https://github.com/google-gemini/gemini-cli
- Extension 공식 문서: https://google-gemini.github.io/gemini-cli/docs/extensions/
- awesome-gemini-cli: https://github.com/Piebald-AI/awesome-gemini-cli
- modelcontextprotocol/servers: https://github.com/modelcontextprotocol/servers
- Superpowers (로컬): `/home/namykim/.claude/plugins/cache/claude-plugins-official/superpowers/`
- 기존 PLAN: `/home/namykim/workspace/DRLLM/DRLLM_PLAN.md` (Born2beRoot 특화 참고용)
