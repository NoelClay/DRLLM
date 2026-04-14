# SP-0 Phase 1 — Category D: Gemini CLI Extension 생태계 Scan Report

**Date**: 2026-04-12
**Sub-agent**: Sonnet 4.6
**Category**: D — Gemini Extension Ecosystem (F·I축 최우선)

---

## 카테고리 개요

Gemini CLI Extension 생태계는 2025년 하반기 Extensions 기능 공식 출시 이후 빠르게 성장하여, 현재 `awesome-gemini-cli` 기준 108개 이상의 엔트리가 존재한다. 그러나 생태계의 성숙도는 불균등하며, 대부분의 Extension은 단일 기능(단일 MCP 래핑, 단순 slash command 1개)에 그친다. 복잡한 멀티-스킬·다중 MCP·조건부 로딩·워크플로우 강제를 구현한 Extension은 전체의 10~15% 수준으로, `Conductor`(3.4k stars), `oh-my-gemini-cli`(118 stars), `Maestro`(318 stars), `allenhutchison/gemini-cli-deep-research`(66 stars) 등이 대표적이다. **LearnLM을 전용으로 활용하는 Extension은 현재 시점에서 발견되지 않았다** — LearnLM이 Gemini 2.5 시리즈에 통합되어 별도 모델 명칭이 사라졌고, CLI Extension 레벨에서 LearnLM-특화 orchestration을 구현한 프로젝트는 확인되지 않는다. DRLLM의 5스킬 분화(S0~S4) 설계에 가장 직접적으로 참고할 수 있는 사례는 `oh-my-gemini-cli`(다층 커맨드 + skills 디렉토리 + hooks + context engineering), `Conductor`(Context-Driven Development 3단계 파이프라인), `Maestro`(22-agent 4-phase + MCP 서버 + 환경변수 기반 설정)의 세 가지이며, Agent Skills 표준(`SKILL.md` + progressive disclosure)이 S0~S4 스킬 분화의 기술적 기반으로 직접 활용 가능하다.

---

## Part 1: 카탈로그 분석

### 1.1 awesome-gemini-cli 전수 분석

**총 규모**: 108개 엔트리 (15개 카테고리)

| 카테고리 | 항목 수 | 복잡도 분포 |
|---------|---------|-----------|
| Agent Orchestration | 9 | 높음 (대부분 multi-agent) |
| Commands & Extensions | 18 | 낮음~중간 (대부분 단일 slash command) |
| MCP Servers | 7 | 중간 (단일 MCP 래핑) |
| Development Tools | 13 | 낮음~중간 |
| Forks | 3 | 높음 (코드베이스 전체 수정) |
| Frameworks | 3 | 높음 |
| SDKs | 2 | 중간 |
| Interfaces | 4 | 낮음 |
| API Bridges | 7 | 낮음 |
| Documentation | 6 | 낮음 |
| Fun | 1 | 낮음 |

**별 100+ 항목**:
- `conductor` (gemini-cli-extensions/conductor): 3,400+ stars — Plan/Spec/Implement 3단계 파이프라인
- `google-gemini/gemini-skills`: 3,200+ stars — 공식 Agent Skills 레포
- `gemini-cli-extensions/security`: 706 stars — 멀티-레이어 보안 분석
- `gemini-cli-extensions/nanobanana`: 999 stars — 이미지 생성 (단순)
- `flutter/gemini-cli-extension`: 383 stars — 멀티-스텝 Flutter 개발 파이프라인
- `josstei/maestro-gemini`: 318 stars — 22-agent 4-phase 오케스트레이션
- `AsyncFuncAI/ralph-wiggum-extension`: 129 stars — 반복 루프 메커니즘
- `Joonghyun-Lee-Frieren/oh-my-gemini-cli`: 118 stars — 멀티-에이전트 워크플로우

**복잡도 "높음" 기준 충족 항목** (멀티-스킬/다중 MCP/조건부 로딩/워크플로우 강제 중 2개 이상):
- oh-my-gemini-cli, Maestro, Conductor, gemini-cli-deep-research, plan-commands, Flutter extension, security extension, gemini-cli-skillz, Skill_GEMINI_Extension (9개, 전체의 8%)

**Awesome-Gemini-CLI-Extensions 별도 카탈로그**: 54개 추가 엔트리 (주로 Google 공식 데이터베이스/클라우드 서비스 연동)

### 1.2 LearnLM 활용 사례

**발견 없음.** 조사 범위:
- `awesome-gemini-cli` 108개 전수 스캔
- `awesome-gemini-cli-extensions` 54개 전수 스캔
- GitHub 키워드 검색 (`gemini-cli extension LearnLM`, `learning tutoring education`)
- `gemini-cli-extensions` 조직 40개 레포 스캔

**이유 분석**:
1. LearnLM이 2025년 I/O에서 Gemini 2.5에 통합되어 별도 모델 엔드포인트가 폐기됨. `gemini-2.5-pro` 호출 시 LearnLM 기능이 자동 내포.
2. CLI Extension 레벨에서 LearnLM 특화 시스템 프롬프트를 가진 교육 Extension이 없음.
3. `oh-my-gemini-cli`가 `omg-learn-signal-after-agent` hook을 포함하지만, 이는 학습 신호 필터링 유틸리티이며 LearnLM API 활용과 무관.

**DRLLM 시사점**: LearnLM Extension은 미개척 영역. DRLLM이 S3(LearnLM Prompt Synthesis) 스킬로 구현하면 **생태계 최초** 사례가 될 수 있음.

---

## Part 2: 발견 항목

---

### [1] oh-my-gemini-cli (OmG)
**Score**: M3·A4·P3·F5·I4 = 19/25
**URL**: https://github.com/Joonghyun-Lee-Frieren/oh-my-gemini-cli
**Category**: D
**Type**: Gemini CLI Extension (Complex Multi-Agent)

#### TL;DR
OmG는 Gemini CLI를 "context-engineering-powered multi-agent workflow pack"으로 변환하는 Extension이다. 11개의 전문화된 agent 역할(omg-director, omg-planner, omg-architect, omg-executor, omg-reviewer, omg-verifier, omg-debugger, omg-editor, omg-researcher, omg-consultant, omg-product)을 정의하고, `/omg:intent → /omg:workspace → /omg:team-assemble → /omg:team-plan → /omg:team-prd → /omg:team-exec → /omg:team-verify → /omg:team-fix` 8단계 파이프라인으로 복잡한 엔지니어링 태스크를 구조화한다. Hard gate 구현이 특히 주목할 만하다: `team-exec`는 `team-plan`/`team-prd` 아티팩트가 없으면 실행을 차단한다. 8개 deep-work skill(`$plan`, `$execute`, `$research` 등)이 on-demand 로딩된다. DRLLM의 S0(Launcher)→S1(Research Planning)→S2(Research Execution)→S3(LearnLM Synthesis)→S4(Tutoring) 체인과 구조적으로 동형(isomorphic)이며, hard gate 패턴과 skill 디렉토리 구조가 직접 참고 가능하다.

#### Architecture
- **gemini-extension.json**: `contextFileName: "GEMINI.md"`, `settings: []` (단순 메타데이터, MCP 없음)
- **GEMINI.md**: 206바이트 미니멀 stub — `@./context/omg-core.md`로 핵심 로직 위임 (모듈화 패턴)
- **context/omg-core.md**: 오케스트레이션 정책, staged-execution gates, safety 강제 규칙
- **agents/*.md**: 11개 role 정의 파일 (각 에이전트의 책임/역할 명세)
- **commands/omg/*.toml**: 8개+ slash command 정의
- **skills/**: 8개 deep-work skill (`$plan`, `$execute`, `$research` 등)
- **hooks/**: 라이프사이클 핸들러 (omg-learn-signal-after-agent 포함)
- GEMINI.md는 단일 파일이지만 `@./context/omg-core.md` import로 실질적 다중 파일 패턴

#### Patterns Worth Copying
- **GEMINI.md 모듈화**: 얇은 stub + `@./context/`로 위임 → DRLLM도 `GEMINI.md`를 S0 launcher stub으로, 실제 스킬 로직은 `skills/` 하위에 분리
- **Hard Gate 패턴**: exec 명령이 plan/prd 아티팩트 존재 여부를 선행 확인 → DRLLM S2는 S1의 research plan 파일 존재를 gate 조건으로 사용 가능
- **Agents + Skills 이중 계층**: agents(role 정의) vs skills(deep-work 패키지) 분리 → DRLLM S0~S4 역할 파일과 S3 LearnLM synthesis skill 분리에 적용
- **Operating Profiles**: balanced/speed/deep/autopilot/ralph — DRLLM도 학습 깊이(quick/deep/adaptive) 모드 설정 가능
- **Workspace + Taskboard 상태 파일**: `.omg/state/` 디렉토리 — DRLLM의 research plan 파일 + learning session state 파일 패턴으로 응용

#### DRLLM Fit Analysis
- 매핑 스킬: S0(Launcher — `/omg:intent` 패턴), S1(Research Planning — `/omg:team-plan`), S4(Adaptive Tutoring — verify/fix 루프)
- 영향받는 SP: SP-1(스킬 분화 구조), SP-3(워크플로우 검증)
- 카피 vs 참고 vs 변형: **변형** — agents/ 디렉토리 구조와 hard gate 패턴을 DRLLM 5스킬용으로 재설계

#### Caveats / Risks
- MCP 없음 → 외부 도구 연동 시 별도 MCP 추가 필요
- hooks 시스템은 Gemini CLI 자체 hooks 지원에 의존 (E 카테고리에서 확인 필요)
- 스타 수(118)가 낮아 community 검증 제한적

#### Recommendation
🔧 카피·수정 — hard gate + GEMINI.md 모듈화 + agents/skills 이중 계층 구조를 DRLLM 5스킬 아키텍처에 직접 적용 가능

---

### [2] Conductor
**Score**: M4·A4·P3·F5·I5 = 21/25
**URL**: https://github.com/gemini-cli-extensions/conductor
**Category**: D
**Type**: Gemini CLI Extension (Workflow Enforcement)

#### TL;DR
Conductor는 "Context-Driven Development"를 구현하는 Extension으로, 3,400+ 스타를 보유한 생태계 최고 인기 Extension이다. 핵심 철학은 "Measure twice, code once" — 컨텍스트 아티팩트(product.md, tech-stack.md, workflow.md)를 코드와 함께 버전 관리하고, `/conductor:setup → /conductor:newTrack → /conductor:implement` 3단계 파이프라인을 강제한다. 각 단계는 명확한 입력 아티팩트와 출력 아티팩트를 정의하며, 중간 단계 생략이 구조적으로 불가능하다. GEMINI.md는 "Universal File Resolution Protocol" 5단계 프로세스를 정의하여, 에이전트가 context 파일을 찾을 때 일관된 절차를 따르도록 강제한다. DRLLM에서 S1(Research Planning) 단계가 plan 아티팩트를 생성하고, S2(Research Execution)가 plan 아티팩트를 의무적으로 참조하도록 강제하는 패턴의 모범 사례이다.

#### Architecture
- **gemini-extension.json**: `{"name": "conductor", "version": "0.4.1", "contextFileName": "GEMINI.md", "plan": {"directory": "conductor"}}` — MCP 없음, 순수 GEMINI.md + commands 구조
- **GEMINI.md**: Universal File Resolution Protocol 정의 (5단계 파일 찾기 프로토콜) + 기본 경로 매핑
- **commands/conductor/*.toml**: 6개 slash command 구현
- **skills/**: skill 디렉토리 존재 (내용 미공개)
- **policies/**, **templates/**: 정책 파일과 템플릿
- 아티팩트 저장소: `conductor/tracks/<id>/spec.md`, `plan.md`, `metadata.json` 구조

#### Patterns Worth Copying
- **Phase-gated Artifact Pattern**: setup 없이 newTrack 불가, newTrack 없이 implement 불가 — DRLLM S1 plan 없이 S2 execution 차단 구현에 직접 적용
- **Universal File Resolution Protocol**: 에이전트가 파일을 찾는 5단계 표준 절차 — DRLLM의 S2가 research source를 참조하거나, S3가 리서치 결과를 찾는 프로토콜로 채택 가능
- **Conductor/ 디렉토리 전략**: 아티팩트를 별도 네임스페이스 디렉토리에 격리 — DRLLM도 `.drllm/` 또는 `drllm/` 디렉토리에 plan·execution·synthesis 아티팩트 분리 관리
- **metadata.json per-track**: 각 실행 트랙(연구 주제)별 메타데이터 파일 → DRLLM의 각 연구 세션 상태 관리에 적용
- **gemini-extension.json 단순화**: MCP 없이 순수 commands + GEMINI.md만으로 복잡한 워크플로우 구현 가능함을 증명

#### DRLLM Fit Analysis
- 매핑 스킬: S0(setup 진입점), S1(newTrack → research planning), S2(implement → research execution)
- 영향받는 SP: SP-1(파이프라인 게이트 설계), SP-3(end-to-end 검증)
- 카피 vs 참고 vs 변형: **🔧 카피·수정** — 3단계 파이프라인 구조와 아티팩트 관리 패턴을 DRLLM 5단계에 맞게 확장

#### Caveats / Risks
- MCP 없음 → 외부 검색 도구 연동 시 MCP 별도 추가 필요 (DRLLM에서는 A카테고리 MCP와 조합 필요)
- 소프트웨어 개발 특화 → 연구/학습 도메인으로 변환 시 재설계 필요
- Apache 2.0 라이선스 — 상업적 사용 가능, 기여 필요

#### Recommendation
✅ 채택 (카피·수정) — 3단계 phase-gated 파이프라인과 GEMINI.md 파일 해석 프로토콜을 DRLLM 5스킬 체인의 직접 템플릿으로 채택

---

### [3] Maestro
**Score**: M4·A5·P4·F4·I3 = 20/25
**URL**: https://github.com/josstei/maestro-gemini
**Category**: D
**Type**: Gemini CLI Extension (Multi-Agent Orchestration Platform)

#### TL;DR
Maestro는 Gemini CLI, Claude Code, Codex를 모두 지원하는 22-agent 4-phase 오케스트레이션 플랫폼이다. 318 스타에 v1.6.1(2026-04-10 릴리즈)로 활성 개발 중이다. 핵심 설계는: GEMINI.md가 거대한 orchestrator 지침서 역할을 하며, MCP 서버(`maestro-server.js`)가 세션 상태 관리·phase 전환·아카이빙을 담당한다. 22개 specialist agent는 Engineering/Product/Design/Content 4개 도메인으로 분류되며, 8개 도메인 분석 프레임워크(Engineering, Product, Design, Content, SEO, Compliance, I18n, Analytics)로 태스크를 사전 분류한다. DRLLM의 S1(Research Planning)이 도메인 분석을 수행하는 패턴, MCP 서버가 상태를 관리하는 패턴, 환경변수 기반 설정(`MAESTRO_*`) 패턴이 모두 참고 가능하다.

#### Architecture
- **gemini-extension.json**: 완전한 구조 — `name`, `version`, `description`, `contextFileName`, `settings[7개]`, `mcpServers.maestro`
- **MCP Server**: `node ${extensionPath}/mcp/maestro-server.js` — `create_session`, `update_session`, `transition_phase`, `archive_session` 도구 제공
- **환경변수 설정**: `MAESTRO_DISABLED_AGENTS`, `MAESTRO_MAX_RETRIES`, `MAESTRO_AUTO_ARCHIVE`, `MAESTRO_VALIDATION_STRICTNESS`, `MAESTRO_STATE_DIR`, `MAESTRO_MAX_CONCURRENT`, `MAESTRO_EXECUTION_MODE`
- **GEMINI.md**: 22-agent 역할 정의, 4-phase 워크플로우, 도메인 분석 프레임워크, delegation rules, native parallel execution 가이드
- **State**: `docs/maestro/state/active-session.md` 경로에 세션 상태 파일
- **Hooks**: SessionStart, BeforeAgent, AfterAgent, SessionEnd

#### Patterns Worth Copying
- **MCP 상태 관리 패턴**: MCP 서버가 세션 생성/전환/아카이빙을 담당 → DRLLM의 연구 세션 상태를 MCP 서버로 관리하면 Gemini가 도구로 상태 조작 가능
- **gemini-extension.json settings 배열**: 7개 설정값을 환경변수로 외부화 → DRLLM도 learning depth, max research steps, LearnLM profile 등을 환경변수 설정으로 구성
- **Domain Analysis Framework**: 8개 도메인 사전 분류 → DRLLM S1의 연구 주제 사전 분류(학술/코드/커뮤니티/공식문서)에 동일 패턴 적용
- **Delegation Headers**: `Agent: <name>`, `Phase: <id>/<total>`, `Batch: <batch_id>`, `Session: <session_id>` — DRLLM의 스킬 간 핸드오프 프로토콜로 채택 가능
- **Express vs Standard Path**: 단순 태스크(Express 2-step)와 복잡 태스크(Standard 4-phase) 분기 → DRLLM S0 Launcher의 quick-mode vs deep-mode 분기 패턴

#### DRLLM Fit Analysis
- 매핑 스킬: S0(Express/Standard 분기), S1(Domain Analysis Framework), S3(agent 특화 역할)
- 영향받는 SP: SP-1(MCP 상태 관리 설계), SP-2(병렬 에이전트 dispatch)
- 카피 vs 참고 vs 변형: **🔧 카피·수정** — MCP 상태 관리 + 환경변수 설정 배열 패턴을 직접 채택

#### Caveats / Risks
- `experimental.enableAgents: true` 필요 — Gemini CLI 실험 기능 의존
- 22-agent 복잡도가 DRLLM 5-skill보다 과도 — 참고용, 전체 카피 불필요
- Apache-2.0

#### Recommendation
🔧 카피·수정 — MCP 세션 관리 패턴 + gemini-extension.json settings 구조만 선택적 채택

---

### [4] allenhutchison/gemini-cli-deep-research
**Score**: M3·A4·P4·F5·I4 = 20/25
**URL**: https://github.com/allenhutchison/gemini-cli-deep-research
**Category**: D
**Type**: Gemini CLI Extension (Research Workflow)

#### TL;DR
이 Extension은 DRLLM의 미션과 가장 직접적으로 겹치는 사례다. Gemini Interactions API(Deep Research)를 Gemini CLI Extension으로 래핑하여, 멀티-스텝 연구 계획 실행·파일 검색 데이터베이스 통합·출처 포함 보고서 생성을 수행한다. TypeScript로 구현된 MCP 서버이며, `commands/deep-research/` TOML 파일로 커맨드를 정의한다. 두 개의 GEMINI.md 파일(`GEMINI.md` + `deep-research-GEMINI.md`)을 분리 운영하는 패턴이 주목할 만하다 — 범용 개발 컨텍스트와 도메인 특화 연구 컨텍스트를 분리한 최초 사례. v0.2.10(2026-04-06)으로 활성 개발 중이며, 169 커밋에 5개 포크로 소규모지만 꾸준한 개발 이력을 보인다. DRLLM S1(Research Planning)과 S2(Research Execution) 스킬의 직접 참고 모델이다.

#### Architecture
- **gemini-extension.json**: MCP 서버 구성 포함 (TypeScript 빌드 결과 `dist/` 실행)
- **GEMINI.md**: 범용 프로젝트 컨텍스트 (TypeScript 컨벤션, 테스트, 린팅)
- **deep-research-GEMINI.md**: 도메인 특화 컨텍스트 (Deep Research API 사용 지침) — **다중 GEMINI.md 패턴**
- **commands/deep-research/*.toml**: 커맨드 정의
- **src/**: TypeScript 소스 (zod validation, @google/genai SDK)
- **로컬 상태**: `.gemini-research.json` — 연구 ID/매핑 캐시
- 환경변수: `GEMINI_DEEP_RESEARCH_API_KEY` (우선) 또는 `GEMINI_API_KEY`

#### Patterns Worth Copying
- **다중 GEMINI.md 패턴**: `GEMINI.md`(범용) + `deep-research-GEMINI.md`(도메인 특화) 분리 → DRLLM도 `GEMINI.md`(S0 진입점) + `research-GEMINI.md`(S1/S2용) + `learnlm-GEMINI.md`(S3용) 분리 가능
- **Zod Schema Validation**: 리서치 결과 구조 검증 → DRLLM의 환각 방지(B 카테고리) 메커니즘 보완
- **Local State Cache**: `.gemini-research.json` 파일로 연구 세션 지속 → DRLLM의 학습 세션 상태 관리 패턴
- **Gemini Deep Research API 직접 통합**: `gemini-deep-research-pro-preview-12-2025` 모델 — DRLLM S2에서 직접 활용 가능

#### DRLLM Fit Analysis
- 매핑 스킬: S1(Research Planning — Interactions API 래핑), S2(Research Execution — 실제 fetch 수행)
- 영향받는 SP: SP-2(출처 다양화, 환각 방지)
- 카피 vs 참고 vs 변형: **✅ 채택** — 다중 GEMINI.md 패턴 + Deep Research API 통합 방식을 DRLLM S1/S2에 직접 채택

#### Caveats / Risks
- Gemini Deep Research API 쿼터 별도 관리 필요 (표준 모델 쿼터와 분리)
- 66 스타 — 소규모, 커뮤니티 검증 제한적
- MIT 라이선스

#### Recommendation
✅ 채택 — 다중 GEMINI.md 분리 패턴 + TypeScript MCP + Zod 검증을 DRLLM S1/S2 구현의 직접 참고 템플릿으로 채택

---

### [5] gemini-cli-skillz (intellectronica)
**Score**: M3·A3·P3·F4·I5 = 18/25
**URL**: https://github.com/intellectronica/gemini-cli-skillz
**Category**: D
**Type**: Gemini CLI Extension (Skill Loading via MCP)

#### TL;DR
`gemini-cli-skillz`는 Anthropic 스타일의 Agent Skills를 Gemini CLI에서 실행하기 위한 MCP 서버 래퍼다. `uvx skillz@latest`로 PyPI에서 최신 버전을 자동 실행하며, `~/.skillz/` 디렉토리의 SKILL.md 파일을 로드한다. 92 스타를 보유했으며 v1.0.1(2025-11-21)로 안정 버전이다. 중요한 점은 **Claude.ai/Claude Code와 동일한 SKILL.md 포맷을 Gemini CLI에서도 사용**할 수 있게 해준다는 것 — 크로스 플랫폼 스킬 이식성을 실현한다. DRLLM이 Claude Code에서 개발한 skill을 Gemini CLI로 이식하거나, 반대로 Gemini CLI용 skill을 Claude Code에서도 재활용하는 경로가 된다. 5개 커밋이라 코드베이스가 작고 단순하다는 점이 장점이자 한계.

#### Architecture
- **gemini-extension.json**: `mcpServers: { skillz: { command: "uvx", args: ["skillz@latest"] } }` — 매우 단순
- **Skills 위치**: `~/.skillz/` 또는 workspace `.gemini/skills/`
- **SKILL.md 포맷**: YAML frontmatter(`name`, `description`) + markdown 본문
- **Progressive Disclosure**: 세션 시작 시 메타데이터만 로드, `activate_skill` 호출 시 전체 내용 로드

#### Patterns Worth Copying
- **Progressive Disclosure**: 스킬 메타데이터만 먼저 로드 → 컨텍스트 효율화 → DRLLM의 5개 스킬을 모두 세션 시작에 로드하지 않고 단계별 활성화
- **Cross-platform Skill 이식성**: 동일 SKILL.md가 Gemini CLI + Claude Code에서 모두 동작 → DRLLM 스킬을 플랫폼 독립적으로 설계
- **uvx 패키지 자동 실행**: 의존성 없이 최신 버전 실행 — DRLLM S3 LearnLM synthesis skill의 배포 방식 참고

#### DRLLM Fit Analysis
- 매핑 스킬: S0~S4 모두 (SKILL.md 포맷 표준으로)
- 영향받는 SP: SP-1(스킬 인터페이스 표준화)
- 카피 vs 참고 vs 변형: **참고** — SKILL.md 포맷 표준과 progressive disclosure 아키텍처를 DRLLM 전체 스킬 설계의 기반으로 채택

#### Caveats / Risks
- 5 커밋으로 코드베이스 소규모 — 복잡한 커스터마이징 어려울 수 있음
- `uv` 의존성 필요
- MIT 라이선스

#### Recommendation
✅ 채택 — SKILL.md 포맷을 DRLLM S0~S4의 표준 인터페이스로 채택, progressive disclosure 아키텍처 구현

---

### [6] MohamedHamed19m/Skill_GEMINI_Extension
**Score**: M2·A3·P3·F4·I4 = 16/25
**URL**: https://github.com/MohamedHamed19m/Skill_GEMINI_Extension
**Category**: D
**Type**: Gemini CLI Extension (Conditional Skill Loading)

#### TL;DR
이 Extension은 MCP 서버(`mcp_app/skills_server.py`)가 `list_skills()`, `search_skills()`, `load_skill()` 3개 도구를 제공하여, 에이전트가 컨텍스트 공간을 낭비하지 않고 on-demand로 스킬을 로드하는 조건부 로딩 시스템을 구현한다. 각 스킬은 `skills/<name>/SKILL.md`에 YAML frontmatter(description, keywords)를 가지며, `scripts/`, `templates/`, `resources/` 서브디렉토리를 가질 수 있다. 스타 수(1)는 낮지만, 코드 레벨에서 조건부 스킬 로딩의 구체적 구현 방법을 보여주는 드문 사례다. DRLLM의 S0 Launcher가 주제를 수신한 후 어떤 스킬(S1/S2/S3/S4)을 활성화할지 판단하는 라우팅 로직의 참고 모델이 된다.

#### Architecture
- **gemini-extension.json**: MCP 서버(`mcp_app/skills_server.py`), custom commands 디렉토리
- **MCP Tools**: `list_skills()`, `search_skills(query, limit=5)`, `load_skill(skill_name, force_reload=False)`
- **Skills 구조**: `skills/<name>/SKILL.md` (YAML frontmatter + markdown)
- **Selective Loading**: 키워드 매칭으로 관련 스킬 검색 후 필요한 것만 로드 → 컨텍스트 토큰 절약

#### Patterns Worth Copying
- **3-tool MCP Pattern**: list → search → load 순서의 점진적 스킬 탐색 → DRLLM S0에서 어떤 연구 접근법(S1 계획 유형)을 선택할지 탐색 프로세스
- **Keyword-based Routing**: 쿼리 키워드로 스킬 매칭 → DRLLM S0의 주제 → 스킬 라우팅에 활용
- **force_reload 옵션**: 캐싱된 스킬 강제 갱신 → DRLLM에서 research plan을 새로 생성할지 재사용할지 결정에 응용

#### DRLLM Fit Analysis
- 매핑 스킬: S0(스킬 라우팅 로직)
- 영향받는 SP: SP-1(스킬 호출 체인 설계)
- 카피 vs 참고 vs 변형: **참고** — 코드 레벨 조건부 로딩 패턴 참고

#### Caveats / Risks
- 스타 1개 — 검증 부족
- Python 의존성 (다른 Extension과 생태계 다름)
- 유지보수 불확실

#### Recommendation
🔧 카피·수정 — 3-tool MCP 스킬 라우팅 패턴을 DRLLM S0의 스킬 선택 로직으로 참고·변형

---

### [7] sanjay3290/ai-skills (deep-research skill)
**Score**: M3·A3·P4·F5·I4 = 19/25
**URL**: https://github.com/sanjay3290/ai-skills
**Category**: D
**Type**: Agent Skill (Cross-platform, Gemini CLI 특화)

#### TL;DR
이 레포지토리의 `deep-research` 스킬은 Gemini Deep Research Agent를 활용한 "autonomous multi-step research" 스킬로, Gemini CLI에서 직접 활성화된다. 202 스타를 보유하며, 비용은 쿼리당 $2~5, 소요 시간은 2~10분이다. Agent Skills 표준(SKILL.md + YAML frontmatter)을 따르며, `npx skills add sanjay3290/ai-skills --skill deep-research --agent gemini` 방식으로 설치한다. DRLLM S2(Research Execution) 스킬이 이 패턴을 따라 구현될 수 있으며, skills.sh 레지스트리를 통한 배포 경로도 확보된다. 특히 중요한 것은 이 스킬이 **research skill의 단독 완결 패키지**로 설계되어 있어, DRLLM에서 research 스킬을 독립 모듈로 분리하는 방식의 선례가 된다는 점이다.

#### Architecture
- **SKILL.md**: YAML frontmatter(name: deep-research, description, triggers) + 워크플로우 지침
- **설치**: `npx skills add` 패키지 매니저 사용
- **활성화 트리거**: "Research the competitive landscape of...", "Find information about..." 등 자연어 트리거
- **백엔드**: Gemini Deep Research Agent + `GEMINI_API_KEY` 환경변수

#### Patterns Worth Copying
- **Skill-as-Module 패턴**: research capability를 독립 스킬로 패키징 → DRLLM의 S1/S2도 독립 스킬로 배포 가능
- **Natural Language Trigger**: SKILL.md 설명이 자동 활성화 조건 역할 → S0 Launcher 없이도 자동 라우팅 가능
- **NPX 기반 배포**: 레포지토리 직접 설치보다 패키지 매니저 경유 배포 → DRLLM 배포 전략

#### DRLLM Fit Analysis
- 매핑 스킬: S1, S2 (research planning + execution 통합)
- 영향받는 SP: SP-1(스킬 패키징), SP-2(연구 실행 엔진)
- 카피 vs 참고 vs 변형: **변형** — DRLLM은 planning/execution을 S1/S2로 분리하므로 해당 스킬을 분리 재설계

#### Caveats / Risks
- $2~5/쿼리 비용 — 학습 세션 전체에 과도할 수 있음
- LearnLM 없음 — 리서치 결과가 학습 콘텐츠로 자동 변환되지 않음
- 단일 contributor

#### Recommendation
🔧 카피·수정 — SKILL.md 포맷과 Deep Research API 통합 방식 채택, S1/S2 분리 설계로 변형

---

### [8] Flutter Gemini CLI Extension (Official)
**Score**: M4·A4·P3·F3·I4 = 18/25
**URL**: https://github.com/flutter/gemini-cli-extension
**Category**: D
**Type**: Gemini CLI Extension (Multi-step Development Workflow)

#### TL;DR
Flutter 공식 Extension은 383 스타를 보유하며, `/create-app → /modify → /commit` 멀티-스텝 개발 파이프라인을 구현한다. 핵심 패턴은 **planning-then-approval**: 설계 문서(DESIGN.md) 생성 후 사용자 승인 대기, 승인 후 단계별 실행. MCP 서버(Dart Tooling Daemon)와 slash commands를 조합하는 패턴이 DRLLM의 참고 모델이 된다. 특히 `flutter.md`라는 코딩 규칙 파일을 별도로 두는 패턴 — GEMINI.md(오케스트레이션)와 domain-specific 컨텍스트 파일(규칙/정책)을 분리하는 설계 — 이 DRLLM의 LearnLM synthesis 규칙 파일 분리에 응용 가능하다.

#### Architecture
- **gemini-extension.json**: MCP 서버(Dart MCP) + 커맨드 디렉토리 등록
- **flutter.md**: 도메인 특화 코딩 규칙 (GEMINI.md와 별도)
- **commands/**: 4개 slash command 구현
- **MCP**: Dart Tooling Daemon 연동 (DTD URL 기반)

#### Patterns Worth Copying
- **Planning-then-approval 패턴**: 설계 문서 생성 → 사용자 승인 → 실행 → DRLLM S1의 research plan을 사용자에게 승인 받는 hard gate
- **도메인 규칙 파일 분리**: `flutter.md` ≠ `GEMINI.md` → DRLLM의 LearnLM pedagogy 규칙을 별도 파일로 분리

#### DRLLM Fit Analysis
- 매핑 스킬: S1(planning + approval gate), S3(domain-specific 규칙 파일)
- 영향받는 SP: SP-1(approval gate 설계)
- 카피 vs 참고 vs 변형: **참고** — planning-then-approval 패턴만 선택적 참고

#### Caveats / Risks
- Flutter/Dart 특화 → 도메인 변환 시 재설계 필요
- BSD-3-Clause

#### Recommendation
🔧 카피·수정 — planning-then-approval 패턴과 도메인 규칙 파일 분리 패턴만 선택적 채택

---

### [9] AsyncFuncAI/ralph-wiggum-extension
**Score**: M3·A3·P3·F4·I5 = 18/25
**URL**: https://github.com/AsyncFuncAI/ralph-wiggum-extension
**Category**: D
**Type**: Gemini CLI Extension (Iterative Loop Mechanism)

#### TL;DR
Ralph Wiggum Extension은 단순하지만 DRLLM에 중요한 패턴을 구현한다: "completion promise 기반 반복 루프". `/ralph-loop [task] --completion-promise '[phrase]' --max-iterations [n]` 커맨드로 에이전트가 완료 조건이 진정으로 충족될 때까지 반복 실행한다. 129 스타, Shell로 구현된 간단한 구조다. DRLLM S4(Adaptive Tutoring)의 P5 인출 기반 검증 루프 — "학습자가 개념을 진정으로 이해했는지 확인될 때까지 반복"하는 메커니즘의 직접 참고 모델이다. 특히 "Iteration > Perfection" 철학과 "failures as data" 접근이 S4의 메타인지 추적과 정렬된다.

#### Architecture
- **Shell 기반**: 상태 파일 `.gemini/ralph-loop.local.md` + 반복 카운터
- **Completion Promise**: 사용자 정의 완료 조건 문구를 에이전트가 진정으로 충족해야만 종료
- **Cancel Command**: `/cancel-ralph`로 언제든 중단 가능

#### Patterns Worth Copying
- **Completion Promise 패턴**: 완료 조건을 자연어로 정의 + 에이전트가 형식적 완료 아닌 실질적 완료 검증 → DRLLM S4의 "학습자 이해도 확인" 완료 조건으로 응용
- **Max Iterations 제한**: 무한 루프 방지 + 사용자 비용 제어 → DRLLM S4 대화 라운드 제한

#### DRLLM Fit Analysis
- 매핑 스킬: S4(Adaptive Tutoring — P5 인출 기반 루프)
- 영향받는 SP: SP-1(S4 루프 설계)
- 카피 vs 참고 vs 변형: **변형** — completion promise 패턴을 S4 "학습 완료 조건" 검증에 적용

#### Caveats / Risks
- Shell 구현 → 복잡한 상태 관리 어려움
- v0.0.1 초기 버전

#### Recommendation
🔧 카피·수정 — completion promise + max iterations 루프 패턴을 S4 tutoring 루프에 변형 적용

---

## Part 3: 멀티-스킬/다중 GEMINI.md 패턴 분석

### 3.1 발견된 패턴 분류

#### Pattern A: GEMINI.md 모듈화 (oh-my-gemini-cli)
```
GEMINI.md (stub, ~200 bytes)
  └── @./context/omg-core.md (핵심 로직)
```
**DRLLM 적용**: `GEMINI.md`는 S0 진입점 stub만 담고, 실제 스킬 로직은 `context/` 또는 `skills/` 하위에 위임. 세션 시작 컨텍스트 최소화.

#### Pattern B: 다중 도메인 GEMINI.md 분리 (gemini-cli-deep-research)
```
GEMINI.md                     (범용 개발 컨텍스트)
deep-research-GEMINI.md       (도메인 특화 컨텍스트)
```
**DRLLM 적용**:
```
GEMINI.md                     (S0 진입점 + 공통 정책)
research-planning-GEMINI.md   (S1 전용)
research-execution-GEMINI.md  (S2 전용)
learnlm-synthesis-GEMINI.md   (S3 전용)
adaptive-tutoring-GEMINI.md   (S4 전용)
```
각 스킬 활성화 시 해당 GEMINI.md만 로드 → 컨텍스트 효율화 + 스킬 분화 명확화.

#### Pattern C: Agents + Skills 이중 계층 (oh-my-gemini-cli, Maestro)
```
agents/
  omg-researcher.md    (역할 정의)
  omg-planner.md
skills/
  $research            (deep-work 패키지)
  $plan
```
**DRLLM 적용**:
```
agents/
  s1-research-planner.md   (S1 역할/책임 정의)
  s2-research-executor.md  (S2 역할/책임 정의)
  s3-learnlm-synthesizer.md
  s4-tutor.md
skills/
  research-planning/       (S1 skill 패키지)
  research-execution/      (S2 skill 패키지)
  learnlm-synthesis/       (S3 skill 패키지)
  adaptive-tutoring/       (S4 skill 패키지)
```

#### Pattern D: Phase-gated Artifact Pipeline (Conductor)
```
/conductor:setup → [product.md, tech-stack.md 생성]
     ↓ (artifact 존재 확인 후)
/conductor:newTrack → [spec.md, plan.md 생성]
     ↓ (artifact 존재 확인 후)
/conductor:implement → [실행]
```
**DRLLM 적용**:
```
/drllm:start [topic] → [research-plan.md 생성]
     ↓ (plan 파일 존재 gate)
/drllm:research → [research-results.md 생성]
     ↓ (results 파일 존재 gate)
/drllm:synthesize → [learnlm-prompt.md 생성]
     ↓ (synthesis 파일 존재 gate)
/drllm:tutor → [학습 대화 시작]
```

#### Pattern E: Completion Promise 루프 (Ralph Wiggum)
```
loop {
  execute(task)
  if completion_promise.satisfied: break
  if iterations >= max_iterations: break
}
```
**DRLLM S4 적용**:
```
loop {
  tutor(student)
  if retrieval_check.passed: break     // 인출 기반 검증 통과
  if session_rounds >= max_rounds: break
}
```

#### Pattern F: MCP 상태 관리 서버 (Maestro)
```
gemini-extension.json: mcpServers.maestro → maestro-server.js
MCP Tools: create_session, update_session, transition_phase, archive_session
State: docs/maestro/state/active-session.md
```
**DRLLM 적용**: `drllm-server.js` MCP 서버가 S0~S4 단계 전환과 세션 상태를 관리. Gemini가 도구 호출로 단계 전환을 명시적으로 수행.

### 3.2 DRLLM 5스킬 분화 권장 구조 (Extension 사례 종합)

```
# DRLLM Extension 권장 구조

GEMINI.md                           # S0: 진입점 stub + 공통 정책 (@import 활용)
gemini-extension.json               # Extension 메타데이터 + MCP 서버 등록 + settings[]
context/
  drllm-core.md                     # 핵심 오케스트레이션 정책 (hard gate 등)
  anti-hallucination-policy.md      # B 카테고리 환각 방지 정책
agents/
  s0-launcher.md                    # S0 역할: 주제 수신, 스킬 라우팅
  s1-research-planner.md            # S1 역할: research plan 생성
  s2-research-executor.md           # S2 역할: 계획 기반 검색 실행
  s3-learnlm-synthesizer.md         # S3 역할: LearnLM prompt 생성
  s4-tutor.md                       # S4 역할: 적응형 학습 대화
skills/
  research-planning/SKILL.md        # S1 deep-work skill
  research-execution/SKILL.md       # S2 deep-work skill
  learnlm-synthesis/SKILL.md        # S3 deep-work skill (생태계 최초!)
  adaptive-tutoring/SKILL.md        # S4 deep-work skill
commands/drllm/
  start.toml                        # /drllm:start [topic]
  research.toml                     # /drllm:research (gate: plan 파일 존재)
  synthesize.toml                   # /drllm:synthesize (gate: results 파일 존재)
  tutor.toml                        # /drllm:tutor (gate: synthesis 파일 존재)
  status.toml                       # /drllm:status
hooks/
  before-research.sh               # S1→S2 전환 전 검증
  after-synthesis.sh               # S3 완료 후 S4 자동 호출
mcp/
  drllm-server.js                  # 세션 상태 관리 MCP 서버 (optional, Maestro 패턴)
```

---

## 카테고리 종합 권장

### Top-3 모범 사례

| 순위 | Extension | 점수 | 카피 가치 |
|------|-----------|------|----------|
| 1 | **Conductor** | 21/25 | DRLLM 5단계 phase-gated pipeline의 직접 템플릿. GEMINI.md 파일 해석 프로토콜 + 아티팩트 관리 구조 |
| 2 | **Maestro** | 20/25 | MCP 상태 관리 서버 + gemini-extension.json settings 배열 + 환경변수 기반 설정의 완결 구현 |
| 3 | **gemini-cli-deep-research** | 20/25 | 다중 GEMINI.md 패턴 + Deep Research API 통합 + TypeScript/Zod 구조의 S1/S2 직접 참고 모델 |

(공동 3위: oh-my-gemini-cli 19/25 — hard gate + GEMINI.md 모듈화 + agents/skills 이중 계층)

### LearnLM Extension 참고도

**발견 없음.** LearnLM은 Gemini 2.5 통합 이후 별도 Extension 사례가 없다. DRLLM S3(LearnLM Prompt Synthesis)는 **생태계 공백 영역** — 선점 기회. LearnLM Prompting Guide(Google PDF, 2024) 참조 + S3 SKILL.md에 교수법 5원칙(P1~P5: active learning, managing cognitive load, adapting to learner, pushing sensemaking, shaping metacognition) 명시 권장.

### DRLLM 5스킬 분화 구조 권장안

Extension 사례 분석에서 추출한 핵심 설계 원칙:

1. **GEMINI.md 최소화 + @import 모듈화** (oh-my-gemini-cli 패턴): 메인 GEMINI.md는 stub, 스킬별 컨텍스트는 별도 파일로
2. **Phase-gated Artifact Flow** (Conductor 패턴): 각 스킬 전환에 아티팩트 존재 게이트
3. **Agents/Skills 이중 계층** (OmG/Maestro 패턴): 역할 정의(agents/)와 실행 패키지(skills/) 분리
4. **MCP 상태 서버** (Maestro 패턴): 선택적 — 복잡한 세션 관리가 필요하면 MCP 서버로
5. **Progressive Disclosure** (skillz 패턴): SKILL.md 메타데이터만 먼저, 활성화 시 전체 로드
6. **Completion Promise 루프** (Ralph Wiggum 패턴): S4 tutoring 루프의 완료 조건 검증

### 기각 리스트

| Extension | 점수 | 기각 사유 |
|-----------|------|----------|
| gemini-cli-prompt-library | <12 | 단순 프롬프트 컬렉션, 구조적 패턴 없음 |
| Pickle Rick | <12 | 페르소나 변경만, 워크플로우 없음 |
| gemini-notifier | <12 | 단일 알림 기능, DRLLM 미관련 |
| geminicli2api, gemini-cli-proxy 류 | <12 | API 브릿지, Extension 구조 없음 |
| buildatscale-tv/gemini-skills | <12 | 이미지 생성/UI 스킬, DRLLM 미관련 |

### Phase 2 심화 후보

1. **Conductor GEMINI.md + commands/** 코드 레벨 분석: GEMINI.md의 Universal File Resolution Protocol 전체 내용 + 각 slash command TOML 구조 상세 분석 → SP-1 직접 설계 입력
2. **Maestro mcp/maestro-server.js** 분석: MCP 상태 관리 서버의 구체적 구현 (transition_phase, archive_session 도구 시그니처) → SP-1/SP-2 MCP 설계
3. **oh-my-gemini-cli context/omg-core.md** 전체 내용 분석: hard gate 구현 방식, staged-execution 정책 코드 레벨 확인 → SP-1 hard gate 설계
4. **Agent Skills 표준 (SKILL.md)** 공식 스펙 상세 분석: progressive disclosure 메커니즘, `activate_skill` 도구 동작 방식 → SP-1 스킬 인터페이스 표준

---

*보고서 생성: 2026-04-12, Sub-agent Sonnet 4.6, Category D*
