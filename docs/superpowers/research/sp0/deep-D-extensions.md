# SP-0 Phase 2 — Category D Deep Dive

**Date**: 2026-04-14
**Sub-agent**: Sonnet 4.6
**Category**: D — Extension Ecosystem (코드 레벨 심화)
**Phase 1 참조**: scan-D-gemini-extensions.md

---

## 심화 분석

### 1. conductor 분석

**레포**: https://github.com/gemini-cli-extensions/conductor (v0.4.1, Apache-2.0)

#### 1.1 gemini-extension.json 전문

```json
{
  "name": "conductor",
  "version": "0.4.1",
  "contextFileName": "GEMINI.md",
  "plan": {
    "directory": "conductor"
  }
}
```

주목할 점: `mcpServers` 없음. `settings[]` 없음. **순수 GEMINI.md + commands/ TOML만으로 복잡한 3단계 파이프라인을 구현**한다. MCP 없이도 phase-gated workflow가 가능함을 증명하는 최소주의 사례.

#### 1.2 commands/ TOML 디렉토리 전수

6개 파일 존재:

| 파일 | 크기(bytes) | 역할 |
|------|-------------|------|
| `setup.toml` | 44,818 | Phase A: 프로젝트 초기화, 컨텍스트 아티팩트 생성 |
| `newTrack.toml` | 15,240 | Phase B: 피처/버그 트랙 생성 (spec.md + plan.md) |
| `implement.toml` | 16,736 | Phase C: 트랙 구현 실행 |
| `review.toml` | 13,129 | Phase 선택: 코드 리뷰 |
| `revert.toml` | 9,479 | Phase 선택: 변경 되돌리기 |
| `status.toml` | 3,171 | 언제든: 프로젝트 현황 조회 |

#### 1.3 TOML 스키마 분석

각 TOML 파일은 2-field 스키마:

```toml
description = "<한 줄 설명>"
prompt = """
<멀티라인 시스템 프롬프트>
"""
```

`prompt` 필드가 곧 슬래시 커맨드 실행 시 주입되는 시스템 프롬프트다. 별도 args, output_schema, tooling 필드 없음 — **모든 로직이 자연어 프롬프트 안에 인코딩**된다.

#### 1.4 phase-gated pipeline 구현 메커니즘

**Phase A → B 강제**: `newTrack.toml`의 Section 1.1:

```
PROTOCOL: Verify that the Conductor environment is properly set up.
1. Verify Core Context: resolve and verify the existence of:
   - Product Definition
   - Tech Stack
   - Workflow documentation
2. If ANY of these files are missing, you MUST halt the operation immediately.
   Announce: "Conductor is not set up. Please run `/conductor:setup`."
```

**Phase B → C 강제**: `implement.toml`의 Section 1.1:

```
Verify that the Conductor environment is properly set up...
resolve and verify the existence of: Product Definition, Tech Stack, Workflow
If missing, halt: "Conductor is not set up. Please run `/conductor:setup`."
```

**구현 메커니즘의 본질**: 소프트웨어적 잠금이 아닌 **프롬프트 레벨 강제**다. 에이전트에게 "파일이 없으면 즉시 중단하고 앞 커맨드를 실행하라"는 지시를 TOML prompt 안에 인코딩한다. 이것이 Gemini CLI Extension 환경에서 hard gate를 구현하는 표준 방식이다.

**status.toml의 gate 재확인**:

```
CRITICAL: If ANY of these files are missing, you MUST halt the operation immediately.
Announce: "Conductor is not set up. Please run `/conductor:setup`."
```

모든 커맨드가 동일한 gate 로직을 반복 포함한다. DRY 원칙 위반처럼 보이지만, 각 TOML이 독립적으로 실행되므로 중앙 gate 모듈이 없다는 Extension 아키텍처의 제약에서 오는 의도적 설계다.

#### 1.5 Universal File Resolution Protocol

GEMINI.md에 정의된 5단계 파일 찾기 프로토콜:

```
1. Identify the relevant index file (project-level or track-specific)
2. Consult the index for links matching your target file
3. Resolve paths relative to the index file's directory
4. Apply fallback defaults if the index lacks the needed link
   - Product Definition  → conductor/product.md
   - Tech Stack         → conductor/tech-stack.md
   - Workflow           → conductor/workflow.md
   - Tracks Registry    → conductor/tracks.md
   - Spec (per track)   → conductor/tracks/<id>/spec.md
   - Plan (per track)   → conductor/tracks/<id>/plan.md
5. Verify file existence on disk
```

이 프로토콜의 의의: 에이전트가 파일을 찾는 방법을 **일관된 절차**로 표준화한다. 에이전트가 임의 경로를 추측하거나 hallucination하지 않도록 명시적 lookup 경로를 제공한다.

#### 1.6 아티팩트 구조

```
conductor/
├── index.md              # 프로젝트 레벨 인덱스 (파일 링크 맵)
├── product.md            # 제품 정의
├── product-guidelines.md # 제품 가이드라인
├── tech-stack.md         # 기술 스택
├── workflow.md           # 작업 절차 (단일 소스 of truth)
├── tracks.md             # 트랙 레지스트리 (전체 목록)
└── tracks/
    └── <track_id>/
        ├── index.md      # 트랙 레벨 인덱스
        ├── spec.md       # 명세 (요구사항 + 수용 기준)
        ├── plan.md       # 구현 계획 (체크박스 태스크)
        └── metadata.json # 상태, 타임스탬프, ID
```

#### 1.7 DRLLM 직접 적용 가능 부분

- **TOML 2-field 스키마** (`description` + `prompt`): DRLLM 5스킬의 slash command 정의에 그대로 채택
- **Phase gate 프롬프트 패턴**: "S1 plan 파일 없으면 즉시 중단, `/drllm:plan` 실행 요청" 패턴으로 카피
- **Universal File Resolution Protocol**: DRLLM의 research artifacts 탐색에 직접 채택
- **metadata.json per-session**: 연구 세션별 상태 파일 구조로 응용
- **conductor/ 디렉토리 네임스페이스**: `.drllm/` 또는 `drllm/` 디렉토리로 대응

---

### 2. maestro-gemini 분석

**레포**: https://github.com/josstei/maestro-gemini (v1.6.1, Apache-2.0, 2026-04-10 릴리즈)

#### 2.1 gemini-extension.json 전문

```json
{
  "name": "maestro",
  "version": "1.6.1",
  "description": "Multi-agent development orchestration platform — 22 specialists, 4-phase orchestration, native parallel subagents, persistent sessions, and standalone review/debug/security/perf/seo/a11y/compliance commands",
  "contextFileName": "GEMINI.md",
  "settings": [
    {
      "name": "Disabled Agents",
      "description": "Comma-separated list of agent names to exclude from implementation planning.",
      "envVar": "MAESTRO_DISABLED_AGENTS"
    },
    {
      "name": "Max Retries",
      "description": "Maximum retry attempts per phase before escalating to user.",
      "envVar": "MAESTRO_MAX_RETRIES"
    },
    {
      "name": "Auto Archive",
      "description": "Automatically archive session state on successful completion (true/false).",
      "envVar": "MAESTRO_AUTO_ARCHIVE"
    },
    {
      "name": "Validation",
      "description": "Post-phase validation strictness level (strict/normal/lenient).",
      "envVar": "MAESTRO_VALIDATION_STRICTNESS"
    },
    {
      "name": "State Directory",
      "description": "Base directory for session state and plans (default: docs/maestro).",
      "envVar": "MAESTRO_STATE_DIR"
    },
    {
      "name": "Max Concurrent",
      "description": "Maximum subagents emitted in one native parallel batch turn (0 = dispatch the entire ready batch).",
      "envVar": "MAESTRO_MAX_CONCURRENT"
    },
    {
      "name": "Execution Mode",
      "description": "Phase 3 execution mode: 'parallel' (native concurrent subagents), 'sequential' (one at a time), or 'ask' (prompt each time). Default: ask.",
      "envVar": "MAESTRO_EXECUTION_MODE"
    }
  ],
  "mcpServers": {
    "maestro": {
      "command": "node",
      "args": ["${extensionPath}/mcp/maestro-server.js"],
      "cwd": "${extensionPath}",
      "env": {
        "MAESTRO_WORKSPACE_PATH": "${workspacePath}"
      }
    }
  }
}
```

#### 2.2 22-agent 4-phase 시스템 코드 구조

**에이전트 로스터** (GEMINI.md에서 추출):

| 도메인 | 에이전트 목록 |
|--------|-------------|
| Engineering Core (12) | `architect`, `api_designer`, `coder`, `code_reviewer`, `debugger`, `devops_engineer`, `performance_engineer`, `refactor`, `security_engineer`, `tester`, `technical_writer`, `data_engineer` |
| Product & Design (4) | `product_manager`, `ux_designer`, `accessibility_specialist`, `design_system_engineer` |
| Content & Strategy (6) | `copywriter`, `content_strategist`, `seo_specialist`, `analytics_engineer`, `i18n_specialist`, `compliance_reviewer` |

**4-phase Standard Workflow**:
```
Phase 1: Design   — 아키텍처/요구사항 수렴
Phase 2: Plan     — 종속성 포함 태스크 분해
Phase 3: Execute  — 단계 실행, 재시도 처리
Phase 4: Complete — 검증, 아카이브, 결과 보고
```

**Express Path** (단순 태스크): 4-phase 생략, inline 실행

**Domain Analysis Framework** (사전 분류):

```
8개 도메인 평가:
Engineering, Product, Design, Content, SEO, Compliance, I18n, Analytics

Simple 태스크 → 비Engineering 도메인 스킵
Medium/Complex → 해당 도메인 에이전트 호출
```

#### 2.3 MCP 상태 관리 서버 — protocol/payload

**파일 구조**: `src/mcp/tool-packs/session/` 디렉토리

**5개 MCP tool 정의**:

```javascript
// Tool 1: create_session
{
  name: "create_session",
  description: "Instantiate a new orchestration session",
  inputSchema: {
    required: ["session_id", "task", "phases"],
    optional: [
      "design_document",        // 설계 문서 경로
      "implementation_plan",     // 구현 계획 경로
      "task_complexity",         // simple | medium | complex
      "execution_mode",          // parallel | sequential | ask
      "workflow_mode"            // express | standard (default: standard)
    ]
  }
}

// Tool 2: get_session_status
{
  name: "get_session_status",
  description: "Read current session status including workflow_mode",
  inputSchema: { required: ["session_id"] },
  // Returns: { exists: false } OR { exists: true, ...status }
}

// Tool 3: update_session
{
  name: "update_session",
  description: "Update session metadata after session creation",
  inputSchema: {
    required: ["session_id"],
    optional: ["execution_mode", "execution_backend", "current_batch"]
  }
}

// Tool 4: transition_phase
{
  name: "transition_phase",
  description: "Atomically mark a phase completed and start the next phase(s)",
  inputSchema: {
    required: ["session_id", "completed_phase_id"],
    optional: ["next_phase_id", "next_phase_ids", "batch_id", "downstream_context", "file_tracking"]
  }
}

// Tool 5: archive_session
{
  name: "archive_session",
  description: "Move active session to archive. Also moves design document and implementation plan to plans/archive/",
  inputSchema: { required: ["session_id"] }
}
```

**Delegation Headers Protocol** (에이전트 디스패치 표준):

```
Agent: <agent_name>
Phase: <id>/<total>
Batch: <batch_id|single>
Session: <session_id>
```

모든 subagent 디스패치 앞에 이 4-field 헤더를 필수 포함. Gemini CLI의 generalist tool이 아닌 각 에이전트의 registered tool을 직접 호출해야 한다 (`coder(query: "...")`).

#### 2.4 settings[] 배열 활용 패턴

`gemini-extension.json`의 `settings` 배열은 Gemini CLI UI에서 설정 가능한 환경변수를 노출한다. 각 항목:
- `name`: UI 표시 이름
- `description`: 설명 텍스트
- `envVar`: 연결되는 환경변수 이름
- (optional) `sensitive: true`: 비밀값 처리

Extension 실행 시 `${envVar}` 형태로 프롬프트/MCP 서버에서 참조한다. **사용자 구성을 코드 수정 없이 환경변수로 외부화**하는 표준 패턴.

---

### 3. oh-my-gemini-cli 분석

**레포**: https://github.com/Joonghyun-Lee-Frieren/oh-my-gemini-cli (v0.7.5, MIT)

#### 3.1 gemini-extension.json

```json
{
  "$schema": "https://raw.githubusercontent.com/google-gemini/gemini-cli/main/packages/cli/schemas/gemini-extension.json",
  "name": "oh-my-gemini-cli",
  "version": "0.7.5",
  "description": "Context engineering and multi-agent workflow extension for Gemini CLI.",
  "author": "Joonghyun-Lee-Frieren",
  "license": "MIT",
  "contextFileName": "GEMINI.md",
  "settings": []
}
```

conductor와 유사하게 MCP 없음, settings 빈 배열. 순수 GEMINI.md + 51개 TOML commands + agents/ + context/ 구조.

#### 3.2 GEMINI.md @import 모듈화 메커니즘

```markdown
# OmG Extension Context
Keep it minimal. Use /omg:* commands as the primary control mechanism.
Deep-work capabilities only when they provide distinctive value.

@./context/omg-core.md
```

**GEMINI.md는 206바이트 stub**이다. 실질적 로직은 전부 `@./context/omg-core.md`에 위임한다. 이 `@`-import 패턴은:
1. GEMINI.md를 진입점 stub으로 유지 → 가독성·버전 관리 분리
2. 실질 오케스트레이션 로직을 `context/` 서브디렉토리에 격리
3. 필요 시 다수의 `@import`로 모듈 조합 가능

#### 3.3 hard gate 텍스트 패턴

`omg-core.md`에서 추출한 hard gate 구현:

**Stage Gate (team-exec용)**:
```
require a dependency-aware task graph (team-plan output) and accepted criteria (team-prd output)
if either is missing → stop this slice as `blocked` → route to /omg:team-plan or /omg:team-prd first
```

**Interviewing State Lock**:
```
When depth keywords trigger the interviewing workflow,
all automated implementation pipelines are blocked while in this state.
```

**Baseline Integrity Check**:
```
Before multi-lane execution or resume handoffs,
verify branch/commit anchors.
Treat drift as a workflow risk that halts progress until resolved.
```

**team-exec.toml의 실제 gate 구현** (코드 인용):
```
Protocol step 2:
- if team-plan artifact missing → termination_status = "blocked", route to /omg:team-plan
- if team-prd artifact missing  → termination_status = "blocked", route to /omg:team-prd
```

**termination 상태 필드**를 output format에 포함함으로써, 후속 에이전트/사용자가 blocked 상태를 명시적으로 파악 가능.

**추가 safety gate (team-exec)**:
1. Baseline drift detection: HEAD가 기록된 baseline에서 벗어나면 중단
2. Lane health assessment: workspace cleanliness/trust 확인
3. Fallback routing: 재시도 전략 제한 (무한루프 방지)

#### 3.4 agents/ vs skills/ 이중 계층

**agents/ 디렉토리** (14개 파일, 역할 정의):

```
director.md     — 팀 오케스트레이터 (목표 설정, 블로커 분류, 태스크 배분)
planner.md      — 태스크 그래프 생성, 의존성 분해
architect.md    — 아키텍처 결정, 기술적 제약
executor.md     — 계획된 작업 실행, scope creep 방지
reviewer.md     — 코드/결과 검토
verifier.md     — 완료 기준 검증
debugger.md     — 버그/장애 조사
editor.md       — 파일 편집 전문
researcher.md   — 정보 수집
consultant.md   — 도메인 전문 자문
product.md      — PRD/수용 기준 정의
interview.md    — Socratic 질문으로 요구사항 명료화 (2,427바이트로 최대 파일)
quick.md        — 단순 태스크용 빠른 경로
consensus.md    — 에이전트 간 의견 충돌 중재
```

**skills/ 디렉토리** (8개 deep-work 패키지):

```
$plan       — 복잡한 계획 수립 전용 심화 스킬
$execute    — 복잡한 실행 전용 심화 스킬
$research   — 심화 리서치 스킬
...등
```

**이중 계층의 의미**:
- **agents**: 역할 정의 (누가 무엇을 담당하는가)
- **skills**: 심화 패키지 (어떤 방법으로 수행하는가)

에이전트가 기본 역할을 수행하다가 복잡한 태스크를 만나면 `$plan`, `$execute` 등 심화 스킬을 on-demand로 로드한다. **진입 비용(컨텍스트 토큰)을 최소화하면서 필요 시 전문화된 역량을 활성화**하는 Progressive Disclosure 패턴의 구현이다.

#### 3.5 상태 파일 관리

`.omg/state/` 디렉토리:
```
workspace.json          — 워크스페이스/레인 상태 (canonical, cache-stable)
taskboard.md            — 태스크 현황 (인간 가독성 + 에이전트 참조)
interview-context.json  — 인터뷰 상태 (단일 소스 of truth)
intent.md               — 의도 분류 결과
```

**workspace.json 구조**:
```json
{
  "primary_workspace_root": "<경로>",
  "lane_registry": {
    "<lane_id>": {
      "owner": "<에이전트>",
      "purpose": "<설명>",
      "branch": "<브랜치명>",
      "health": "clean|dirty|unknown",
      "trust": "<수준>",
      "handoff_ready": true|false,
      "baseline": {
        "branch": "<브랜치>",
        "commit": "<SHA>"
      }
    }
  }
}
```

**설계 원칙**: "use canonical relative paths when possible; avoid volatile timestamps, counters, or shell/session metadata" — 안정적·재현 가능한 상태 파일을 위해 휘발성 데이터 배제.

#### 3.6 51개 commands 분류

```
진입점/오케스트레이션: intent, launch, deep-init, ultrawork
팀 파이프라인:         team, team-assemble, team-plan, team-prd, team-exec, team-fix, team-verify
상태관리:              workspace, taskboard, status, recall, memory
실행제어:              loop, autopilot, stop, cancel, checkpoint
HUD:                   hud, hud-on, hud-off, hud-compact
설정:                  mode, model, reasoning, intent
훅관리:                hooks, hooks-init, hooks-test, hooks-validate
기타:                  approval, consensus, interview, notify, ralph, rules, doctor, optimize
```

---

### 4. gemini-cli-deep-research 분석

**레포**: https://github.com/allenhutchison/gemini-cli-deep-research (v0.2.10, MIT)

#### 4.1 gemini-extension.json

```json
{
  "name": "gemini-deep-research",
  "version": "0.2.10",
  "contextFileName": "deep-research-GEMINI.md",
  "settings": [
    {
      "name": "API Key",
      "description": "Google AI API key for Deep Research. A paid key is required",
      "envVar": "GEMINI_DEEP_RESEARCH_API_KEY",
      "sensitive": true
    },
    {
      "name": "Model",
      "description": "Model to use for file search queries (default: models/gemini-flash-latest)",
      "envVar": "GEMINI_DEEP_RESEARCH_MODEL"
    }
  ],
  "mcpServers": {
    "gemini-deep-research": {
      "command": "node",
      "args": ["scripts/start.cjs"],
      "cwd": "${extensionPath}"
    }
  }
}
```

**핵심 관찰**: `contextFileName`이 `"deep-research-GEMINI.md"` — 범용 `GEMINI.md`가 아닌 **도메인 특화 파일**을 직접 지정한다.

#### 4.2 다중 GEMINI.md 패턴

**파일 분리 메커니즘**:

```
GEMINI.md              — 범용 개발 컨텍스트
  내용: TypeScript 컨벤션, npm 스크립트, 테스트 절차, 린팅 설정
  용도: Extension 개발자용 (기여자 온보딩)

deep-research-GEMINI.md — 도메인 특화 런타임 컨텍스트
  내용: Deep Research API 사용 지침, 3단계 워크플로우, 파일 스토어 관리, grounding 제약
  용도: Extension 사용자용 (런타임 에이전트 지침)
```

`gemini-extension.json`의 `contextFileName: "deep-research-GEMINI.md"`가 **런타임에서는 도메인 파일만 로드**하도록 지정한다. 개발 컨텍스트(`GEMINI.md`)는 런타임에서 완전히 격리된다.

**3단계 워크플로우 강제** (deep-research-GEMINI.md에서 추출):

```
Phase 1: Preparation
  - file_search_create_store (스토어 생성)
  - file_search_upload (파일 업로드)

Phase 2: Execution  
  - research_start (Deep Research 시작, 비동기)
  - OR file_search_query (직접 쿼리)

Phase 3: Completion
  - research_status (완료 확인, 폴링)
  - research_save_report (마크다운 보고서 생성)
```

**Critical constraint**: "Grounding only works on files that have been successfully uploaded to a store" — 파일 없이 research_start 호출 불가.

**Tool interdependencies**: `file_search_list_stores`의 전체 리소스 이름을 먼저 가져와야 `storeName` 파라미터를 downstream에 전달 가능.

#### 4.3 TypeScript/Zod 사용 패턴

**MCP Tool 정의** (src/index.ts 추출):

```typescript
// 6개 MCP 도구 등록
const tools = [
  "file_search_create_store",   // RAG grounding 스토어 생성
  "file_search_list_stores",    // 스토어 목록 조회
  "file_search_upload",         // 비동기 파일 업로드 (smart sync 옵션)
  "file_search_query",          // 스토어 기반 grounded 쿼리
  "file_search_delete_store",   // 스토어 삭제
  "research_start",             // Deep Research 세션 시작 (비동기)
  "research_status",            // 완료 상태 조회 (폴링)
  "research_save_report"        // 완료된 세션 → 마크다운 보고서
];
```

**Zod 스키마 패턴**:

```typescript
// 입력 검증 예시
const ResearchStartInput = z.object({
  query: z.string().describe("Research query"),
  outputFormat: z.string().optional().describe("Preferred output format"),
  storeNames: z.array(z.string()).optional().describe("File search stores for grounding"),
});

// 선택값 기본값 패턴
smartSync: z.boolean().default(false).optional()
```

**Lazy 초기화 패턴**:
```typescript
// 싱글턴 관리자 - 첫 tool 호출 시 초기화
let _client: GoogleAI | null = null;
let _fileSearchManager: FileSearchManager | null = null;
let _researchManager: ResearchManager | null = null;
```

API 키 가용성을 첫 호출 시점에 검증하고, 컨텍스트 오류를 제공한다.

#### 4.4 commands/ TOML 구조

8개 파일:

```
start.toml      (1,779 bytes) — Deep Research 세션 시작 (가장 복잡)
report.toml     (298 bytes)   — 보고서 생성
status.toml     (340 bytes)   — 완료 상태 확인
store-create.toml (172 bytes) — 스토어 생성
store-delete.toml (240 bytes) — 스토어 삭제
store-list.toml (143 bytes)   — 스토어 목록
store-query.toml (383 bytes)  — 스토어 쿼리
store-upload.toml (355 bytes) — 파일 업로드
```

**start.toml의 3단계 사용자 가이드** (코드 인용):

```toml
description = "Refines and starts a Deep Research session with structured output."
prompt = """
## Step 1: Analyze & Refine
If the user input is vague (e.g., "research batteries"), DO NOT start immediately.
Ask clarifying questions:
- What is the specific goal? (Investment, technical, academic?)
- What is the target audience?
- Are there specific constraints?

## Step 2: Suggest a Format (Steerability)
Options: Executive Brief / Technical Deep Dive / Market Analysis / Comprehensive Report

## Step 3: Execute
Once confirmed:
1. Check available stores: file_search_list_stores
2. Ask about grounding stores
3. Call research_start with refined prompt + formatting instructions
"""
```

**DRLLM S1/S2 직접 참고 지점**: "먼저 명료화 → 포맷 확정 → 실행" 3단계가 DRLLM의 Research Planning(S1) 흐름과 동형.

---

### 5. 4개 사례 비교 매트릭스

| 항목 | conductor | maestro-gemini | oh-my-gemini-cli | gemini-cli-deep-research |
|------|-----------|----------------|------------------|--------------------------|
| **Stars** | 3,400+ | 318 | 118 | 66 |
| **Version** | 0.4.1 | 1.6.1 | 0.7.5 | 0.2.10 |
| **MCP 서버** | 없음 | 있음 (Node.js) | 없음 | 있음 (Node.js/CJS) |
| **settings[]** | 없음 | 7개 (환경변수) | 없음 (빈 배열) | 2개 (API키+모델) |
| **GEMINI.md 패턴** | 단일 (5단계 프로토콜 포함) | 단일 (거대 orchestrator) | stub + @import | 분리 (범용/도메인 특화) |
| **commands/ TOML** | 6개 | 없음 (GEMINI.md 지배) | 51개 | 8개 |
| **agents/ 디렉토리** | 없음 | 없음 (GEMINI.md 내 정의) | 14개 역할 파일 | 없음 |
| **skills/ 디렉토리** | 있음 (내용 미공개) | 없음 | 8개 deep-work | 없음 |
| **Phase gate 방식** | 프롬프트 인코딩 (아티팩트 존재 확인) | MCP transition_phase + 프롬프트 | 프롬프트 blocked 상태 | 암묵적 (API 의존성) |
| **상태 관리** | metadata.json per-track | MCP 서버 (create/update/archive) | .omg/state/*.json | .gemini-research.json |
| **언어** | 자연어 프롬프트만 | JS + 자연어 | 자연어 프롬프트만 | TypeScript + Zod |
| **Phase 수** | 3 (setup/newTrack/implement) | 4 (design/plan/execute/complete) | 5 (intent/plan/prd/exec/verify) | 3 (prep/execute/complete) |
| **DRLLM 유사도** | S1→S2 파이프라인 아키텍처 | MCP 상태관리 + 설정 외부화 | S0~S4 역할/스킬 분화 | S2 연구 실행 패턴 |

**Gate 강도 비교**:
- conductor: 소프트 (프롬프트 "MUST halt" 지시, 에이전트가 따름)
- maestro: 하드 (MCP transition_phase가 상태 전환을 직접 제어)
- oh-my-gemini-cli: 소프트+표현적 (blocked 상태 명시, route 지시)
- deep-research: 암묵적 (API 파라미터 의존성이 강제)

**컨텍스트 효율 비교**:
- conductor: GEMINI.md 경량 + 각 TOML이 독립 로드 (세션당 한 커맨드 컨텍스트)
- maestro: 거대 GEMINI.md (22-agent 전체 상시 로드) → 컨텍스트 압박
- oh-my-gemini-cli: @import 모듈화 + Progressive Disclosure (필요 시 skills 로드)
- deep-research: 도메인 특화 파일만 로드 (최고 효율)

---

### 6. DRLLM 디렉토리 구조 권장안

Phase 1 발견을 Phase 2에서 확인한 코드 레벨 증거로 검증하여 도출한 DRLLM 디렉토리 구조:

```
drllm/                                    # Extension 루트 (GitHub 레포)
├── gemini-extension.json                 # Extension 메타데이터
├── GEMINI.md                             # Stub + @import (conductor + omg 패턴)
│
├── context/
│   └── drllm-core.md                     # 핵심 오케스트레이션 규칙 (omg-core.md 패턴)
│                                         # - 5스킬 체인 정의 (S0→S1→S2→S3→S4)
│                                         # - Universal Artifact Resolution Protocol
│                                         # - 환각 방지 hard gate
│                                         # - 세션 상태 파일 경로 정의
│
├── commands/drllm/
│   ├── launch.toml                       # S0: 진입점, 주제 수신, 도메인 분류
│   ├── plan.toml                         # S1: 리서치 계획 생성 (research-plan.md 산출)
│   ├── research.toml                     # S2: 리서치 실행 (출처 fetch + 라벨링)
│   ├── synthesize.toml                   # S3: LearnLM 프롬프트 합성
│   ├── tutor.toml                        # S4: 적응형 튜터링 세션
│   └── status.toml                       # 세션 현황 조회
│
├── skills/
│   ├── $research-planning.md             # S1 심화 스킬 (복잡한 주제용)
│   ├── $research-execution.md            # S2 심화 스킬 (다출처 병렬 fetch)
│   ├── $learnlm-synthesis.md             # S3 심화 스킬 (LearnLM 프롬프트 엔지니어링)
│   └── $adaptive-tutoring.md             # S4 심화 스킬 (P5 인출 기반 루프)
│
├── agents/
│   ├── planner.md                        # S1 역할: 어떤 출처에서 무엇을 찾을지 계획
│   ├── researcher.md                     # S2 역할: 실제 fetch, 환각 URL 차단
│   ├── synthesizer.md                    # S3 역할: 리서치 → LearnLM 교수법 변환
│   └── tutor.md                          # S4 역할: 인출 기반 학습 대화
│
├── mcp/
│   └── drllm-server.js                   # (선택) 세션 상태 관리 MCP 서버
│                                         # create_session, transition_skill,
│                                         # update_session, archive_session
│
└── .drllm/                               # 런타임 아티팩트 (gitignore)
    ├── sessions/
    │   └── <session_id>/
    │       ├── metadata.json             # 세션 ID, 주제, 상태, 타임스탬프
    │       ├── research-plan.md          # S1 산출물 (S2 gate 조건)
    │       ├── research-results.md       # S2 산출물 (S3 gate 조건)
    │       ├── learnlm-prompt.md         # S3 산출물 (S4 gate 조건)
    │       └── session-state.json        # S4 학습 진행 상태
    └── active-session.json               # 현재 세션 포인터
```

**gemini-extension.json 권장 구조**:

```json
{
  "$schema": "https://raw.githubusercontent.com/google-gemini/gemini-cli/main/packages/cli/schemas/gemini-extension.json",
  "name": "drllm",
  "version": "0.1.0",
  "description": "Domain-agnostic Deep Research → LearnLM tutoring framework",
  "contextFileName": "GEMINI.md",
  "settings": [
    {
      "name": "Research Depth",
      "description": "Research depth level: quick (1-2 sources), standard (3-5), deep (5-10)",
      "envVar": "DRLLM_RESEARCH_DEPTH"
    },
    {
      "name": "Learning Mode",
      "description": "Tutoring mode: socratic, direct, mixed",
      "envVar": "DRLLM_LEARNING_MODE"
    },
    {
      "name": "Max Research Steps",
      "description": "Maximum number of research iterations before synthesis",
      "envVar": "DRLLM_MAX_RESEARCH_STEPS"
    },
    {
      "name": "LearnLM Profile",
      "description": "Target learner profile: beginner, intermediate, advanced, expert",
      "envVar": "DRLLM_LEARNER_PROFILE"
    }
  ],
  "mcpServers": {
    "drllm": {
      "command": "node",
      "args": ["${extensionPath}/mcp/drllm-server.js"],
      "cwd": "${extensionPath}",
      "env": {
        "DRLLM_WORKSPACE_PATH": "${workspacePath}"
      }
    }
  }
}
```

**GEMINI.md 권장 구조** (omg 패턴):

```markdown
# DRLLM Extension

Keep this stub minimal. Core orchestration logic is in context/drllm-core.md.
Use /drllm:* commands as primary control mechanism.

@./context/drllm-core.md
```

**plan.toml 예시** (S1 gate 인코딩):

```toml
description = "Generates a structured research plan for a given topic"
prompt = """
## GATE CHECK (실행 전 필수)
Check for active session in .drllm/active-session.json.
If not found: "No active session. Please run /drllm:launch first."
Do NOT proceed without an active session.

## S1: Research Planning
Given topic: {{args}}

1. Classify domain type: academic / code / community / official-docs / BYOC
2. Identify 3-7 specific research questions
3. For each question, specify:
   - Source type (arxiv / GitHub / StackOverflow / Reddit / official docs)
   - Search query (exact, not hallucinated)
   - Expected output format
4. Generate research-plan.md in .drllm/sessions/<session_id>/
5. Update metadata.json: status → "research_planned"

NEXT: Run /drllm:research to execute the plan.
"""
```

**research.toml 예시** (S2 gate 인코딩):

```toml
description = "Executes the research plan and fetches real sources"
prompt = """
## GATE CHECK (실행 전 필수)
Read .drllm/sessions/<session_id>/research-plan.md
If not found: "No research plan found. Please run /drllm:plan first."
HALT if missing.

## S2: Research Execution
For each item in research-plan.md:
1. Use ONLY MCP tools to fetch (no hallucinated URLs)
2. Label each result: [SOURCE_TYPE: arxiv/github/stackoverflow/...]
3. If fetch fails → mark as [FETCH_FAILED], do NOT substitute with generated content
4. Record raw results in .drllm/sessions/<session_id>/research-results.md
5. Update metadata.json: status → "research_complete"

NEXT: Run /drllm:synthesize to convert results to LearnLM format.
"""
```

---

## SP-1 (Skill 시스템 설계) 직접 영향

### 영향 1: TOML-based slash command가 Gemini Extension의 표준 스킬 구현체

conductor(6개), oh-my-gemini-cli(51개), deep-research(8개) 모두 `commands/<namespace>/*.toml` 구조를 사용한다. SP-1은 DRLLM 5스킬을 5개 TOML 파일(`launch.toml`, `plan.toml`, `research.toml`, `synthesize.toml`, `tutor.toml`)로 구현하는 방향으로 설계해야 한다.

### 영향 2: Hard Gate는 프롬프트 레벨 강제로 구현 (도구 레벨 잠금 불필요)

모든 사례에서 gate 로직이 TOML prompt 안의 "파일 존재 확인 → 없으면 HALT + 앞 커맨드 안내" 패턴으로 구현된다. SP-1 설계에서 별도 validation 도구나 코드가 필요 없다. Gemini 에이전트의 instruction-following 능력에 의존하는 소프트 gate로 충분하다.

### 영향 3: agents/ vs skills/ 이중 계층을 DRLLM에 채택

oh-my-gemini-cli의 agents(역할) vs skills(심화 패키지) 분리가 DRLLM의 S0~S4 역할 파일과 `$learnlm-synthesis` 같은 심화 스킬 분리에 직접 적용 가능하다. SP-1은 이 두 계층을 명시적으로 정의해야 한다.

### 영향 4: MCP 상태 관리는 선택적 — 초기 MVP는 파일 기반으로 충분

maestro의 MCP 세션 관리(create_session, transition_phase 등)는 강력하지만 구현 비용이 높다. conductor와 oh-my-gemini-cli가 순수 파일 기반(metadata.json, .omg/state/)으로도 유효한 상태 관리를 실현함을 확인했다. SP-1 MVP는 `.drllm/sessions/<id>/metadata.json` 파일 기반으로 구현하고, 이후 복잡도가 필요할 때 MCP 서버로 업그레이드한다.

### 영향 5: 다중 GEMINI.md 패턴 — S3 LearnLM을 독립 컨텍스트 파일로 분리

deep-research의 `deep-research-GEMINI.md` 분리 패턴을 채택하면, `context/learnlm-synthesis.md`가 LearnLM 교수법 규칙을 독립적으로 정의하고 S3 스킬에서만 @import할 수 있다. 이로써 LearnLM 프롬프트 엔지니어링 규칙이 연구 로직(S1/S2)과 섞이지 않는다.

---

## 변경된 권장 (Phase 1 대비)

### Phase 1 → Phase 2 변경 사항

**1. Phase Gate 구현 신뢰도 상향**
Phase 1: "phase-gating 가능성 있음" → Phase 2: **코드 레벨 확인 완료**. conductor, oh-my-gemini-cli 두 레포 모두 동일한 "아티팩트 파일 존재 확인 → HALT" 프롬프트 패턴을 사용. DRLLM에 즉시 카피 가능.

**2. MCP 서버 필요성 재평가 — 하향**
Phase 1: "MCP 상태 관리 서버 필요" → Phase 2: **파일 기반도 충분**. conductor(3,400 stars)가 MCP 없이 production 수준 phase-gated workflow를 구현. MVP는 MCP 없이 시작.

**3. @import 모듈화 패턴 — 강력 권장으로 상향**
Phase 1: "모듈화 패턴 존재" → Phase 2: **oh-my-gemini-cli가 GEMINI.md 206바이트 stub + @import 패턴을 실증**. DRLLM의 GEMINI.md도 동일하게 초경량 stub으로 설계.

**4. 다중 GEMINI.md 패턴 — DRLLM 적용 권장**
Phase 1: 언급됨 → Phase 2: **deep-research-GEMINI.md 분리 메커니즘 코드 레벨 확인**. `contextFileName` 필드가 도메인 파일을 직접 지정함으로써 개발 컨텍스트와 런타임 컨텍스트를 완전 격리. DRLLM도 `contextFileName: "drllm-core-GEMINI.md"` 방식 채택 권장.

**5. settings[] 배열 활용 — 구체 필드 정의**
Phase 1: "환경변수 설정 가능" → Phase 2: **4개 DRLLM 전용 설정 필드 도출** (DRLLM_RESEARCH_DEPTH, DRLLM_LEARNING_MODE, DRLLM_MAX_RESEARCH_STEPS, DRLLM_LEARNER_PROFILE).

**6. Delegation Headers — SP-1 스킬 핸드오프 프로토콜로 채택**
Phase 1: 없음 → Phase 2: maestro의 `Agent:/Phase:/Batch:/Session:` 4-field 헤더 발견. DRLLM 스킬 간 핸드오프 메시지에 `Skill: S2/S1→S2/Session: <id>` 형태로 적용 권장.
