# SP-0 Phase 1 — Category E: Gemini CLI 본체 capability Scan Report

**Date**: 2026-04-12
**Sub-agent**: Sonnet 4.6
**Category**: E — Gemini CLI Core Capabilities (M·F축 최우선)
**Gemini CLI version 분석 시점**: v0.37.1 (latest stable, 2026-04-09 릴리즈) / 현재 nightly v0.39.0-nightly.20260411

---

## 카테고리 개요 (한 단락)

Gemini CLI(v0.37.1)는 단순 LLM 래퍼가 아니라 **Agent Skills, Custom Commands, Hooks, Subagents(Local+Remote), MCP 통합, GEMINI.md 계층 컨텍스트, Plan Mode, Policy Engine** 등 풍부한 메타-기능 레이어를 본체에 내장하고 있다. Claude Code의 핵심 기능 대부분에 직접 대응하는 메커니즘이 존재하며, 특히 Hooks는 11개 이벤트(BeforeTool, AfterTool, BeforeAgent, AfterAgent, BeforeModel, AfterModel, BeforeToolSelection, SessionStart, SessionEnd, PreCompress, Notification)를 커버하는 정식 지원 기능이다. DRLLM의 5개 스킬 분화는 Skills + Custom Commands 조합으로 구현 가능하며, Hard Gate는 AfterAgent Hook의 `decision: deny` 또는 Policy Engine으로 강제할 수 있다. Sub-agent dispatch는 `.gemini/agents/*.md`에 Markdown+YAML frontmatter 파일을 두는 것으로 정의 가능하고, 원격 Agent-to-Agent(A2A) 프로토콜도 지원한다. 가장 큰 격차는 **"다음 스킬을 자동 호출하는 강제 체인"** 으로, Gemini CLI Skills는 현재 세션 내 단일 활성화가 기본이므로 S0→S1→S2→S3→S4 강제 체인을 구현하려면 AfterAgent Hook 또는 Custom Command로 다음 스킬을 트리거하는 우회가 필요하다.

---

## Part 1: 본체 capability 매트릭스 (Claude Code와 비교)

| 기능 | Claude Code | Gemini CLI | 비고 |
|------|------------|-----------|------|
| Slash commands | ✅ `/skill`, `/commit` 등 | ✅ 정식 지원 | TOML 파일로 정의, 네임스페이스(`/git:commit`), `{{args}}`, `!{shell}`, `@{file}` 지원 |
| Sub-agent dispatch | ✅ Agent tool | ✅ 정식 지원 | `.gemini/agents/*.md` YAML frontmatter 정의, `@subagent_name` 강제 호출, 재귀 방지 내장 |
| Hooks (이벤트 자동화) | ✅ settings.json hooks | ✅ 정식 지원 | 11개 이벤트, settings.json 구성, 프로젝트/사용자/시스템 3계층 |
| Skill 시스템 | ✅ Skill tool | ✅ 정식 지원 | `SKILL.md` 기반 [Agent Skills](https://agentskills.io) 표준, `activate_skill` tool로 on-demand 로딩 |
| Conditional context loading | ✅ CLAUDE.md/MEMORY.md | ✅ 정식 지원 | GEMINI.md 계층(global→workspace→JIT), `@file.md` import, `context.fileName` 커스텀 가능 |
| MCP servers | ✅ | ✅ 정식 지원 | `settings.json`, extension, subagent frontmatter에서 선언, 표준 MCP 프로토콜 |
| Custom commands | ✅ | ✅ 정식 지원 | TOML 파일, 사용자/프로젝트 범위, 네임스페이스 지원 |
| TodoWrite/TaskCreate | ✅ | ✅ 정식 지원 | `write_todos` tool로 세션 내 작업 트래킹, Ctrl+T UI 토글 |
| File-based memory | ✅ | ✅ 정식 지원 | `save_memory` → `~/.gemini/GEMINI.md`에 append, `/memory` 슬래시 명령으로 관리 |
| Plan Mode (read-only) | ⚠️ 부분 | ✅ 정식 지원 | Plan Mode로 read-only 단계 강제, Pro/Flash 자동 모델 라우팅, 비대화형 시 YOLO 자동 전환 |
| Remote Agent (A2A) | ❌ | ✅ 정식 지원 | A2A(Agent-to-Agent) 프로토콜, OAuth/apiKey/Google ADC 인증 |
| Policy Engine | ⚠️ | ✅ 정식 지원 | TOML 룰 파일, 조건부 allow/deny/ask_user, subagent-specific 정책 가능 |
| Model Steering | ❌ | ⚠️ 실험 | 실행 중 실시간 가이드, `/settings`에서 활성화 |
| Headless/Non-TTY 모드 | ✅ | ✅ 정식 지원 | `-p` 플래그, JSON/JSONL 출력, 표준 exit code |
| Session 체크포인팅 | ✅ | ✅ 정식 지원 | `/resume save <tag>`, `--resume` 플래그, 30일 자동 보존 |

---

## Part 2: 핵심 기능별 상세

### 2.1 Extension 시스템

**레퍼런스**: `docs/extensions/reference.md`, `docs/extensions/writing-extensions.md`
**URL**: https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/reference.md

`gemini-extension.json` (manifest) 스키마:

```json
{
  "name": "my-extension",       // 필수: 소문자, 대시 사용
  "version": "1.0.0",           // 필수
  "description": "...",         // 갤러리 표시용
  "mcpServers": { ... },        // MCP 서버 선언 (settings.json와 동일 형식)
  "contextFileName": "GEMINI.md", // 생략 시 디렉터리의 GEMINI.md 자동 로드
  "excludeTools": ["run_shell_command(rm -rf)"], // 특정 도구/명령 차단
  "plan": { "directory": ".gemini/plans" },      // 플래닝 아티팩트 디렉터리
  "settings": [...]             // 사용자 설정 (API 키 등, 설치 시 입력 요청)
}
```

Extensions는 다음을 모두 패키징 가능:
- MCP 서버 (도구 추가)
- Custom Commands (`commands/` 하위 TOML)
- Context file (`GEMINI.md`)
- Agent Skills (`skills/` 하위)
- Hooks
- Sub-agents (`agents/` 하위 `.md`)
- Themes

**설치**: `gemini extensions install <github-url>`, 또는 `gemini extensions link <path>` (개발용)
**환경변수 지원**: `settings.json` 및 `gemini-extension.json` 내 `$VAR_NAME`, `${VAR:-DEFAULT}` 문법으로 env 주입
**`.env` 파일**: 각 extension 디렉터리에 `.env` 파일 자동 로딩

### 2.2 Commands (slash 또는 custom)

**레퍼런스**: `docs/cli/custom-commands.md`
**URL**: https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/custom-commands.md

Custom Commands 정의 방법:
- **위치**: `~/.gemini/commands/` (사용자), `<project>/.gemini/commands/` (프로젝트)
- **형식**: TOML 파일 (`.toml` 확장자 필수)
- **네임스페이스**: 디렉터리 구조 → `git/commit.toml` → `/git:commit` 명령
- **우선순위**: 프로젝트 > 사용자

매개변수 처리:
- `{{args}}`: 사용자 입력 직접 치환 (프롬프트 본문에서는 raw, `!{...}` 내에서는 shell-escaped)
- `!{shell-command}`: 셸 명령 실행 후 결과 주입 (실행 전 사용자 확인 프롬프트)
- `@{file-path}`: 파일 내용 또는 디렉터리 리스팅 주입 (처리 순서: `@{...}` → `!{...}` → `{{args}}`)
- args 없는 경우: 기본값은 원래 프롬프트 뒤에 사용자 입력 append

**Extension 내 명령**: `commands/` 폴더를 extension 디렉터리에 추가 → 자동 등록

### 2.3 Hooks (정식 지원)

**레퍼런스**: `docs/hooks/index.md`, `docs/hooks/reference.md`, `docs/hooks/writing-hooks.md`
**URL**: https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/

지원 이벤트 11개:

| 이벤트 | 발화 시점 | 가능한 동작 | DRLLM 활용 |
|--------|----------|------------|-----------|
| `SessionStart` | 세션 시작/재개/clear | 컨텍스트 주입 | S0 초기화, DRLLM 모드 로딩 |
| `SessionEnd` | 세션 종료 | 상태 저장 | 진행상황 저장 |
| `BeforeAgent` | 사용자 프롬프트 후, 계획 전 | 컨텍스트 추가/턴 차단 | 입력 검증, 스킬 전환 감지 |
| `AfterAgent` | 에이전트 응답 완료 후 | 재시도/중지 강제 | **Hard Gate 구현** (응답 검증, deny+retry) |
| `BeforeModel` | LLM 호출 전 | 프롬프트 수정/모델 교체/모킹 | 모델 선택 제어 |
| `AfterModel` | LLM 응답 후 | 응답 필터링/redact | 환각 URL 필터링 |
| `BeforeToolSelection` | 도구 선택 전 | 도구 목록 필터링 | 스킬별 도구 제한 |
| `BeforeTool` | 도구 실행 전 | 인수 검증/차단/재작성 | 파일 쓰기 검증, 보안 게이트 |
| `AfterTool` | 도구 실행 후 | 결과 처리/컨텍스트 추가 | **tail tool call**: 다음 도구 자동 연쇄 호출 |
| `PreCompress` | 컨텍스트 압축 전 | 상태 저장 | 세션 보존 |
| `Notification` | 시스템 알림 | 외부 로깅 | 모니터링 |

핵심 기능:
- **통신**: stdin(JSON 입력) / stdout(JSON 출력) / stderr(로그)
- **exit code 0**: 구조적 응답, `{"decision": "deny", "reason": "..."}` 형식
- **exit code 2**: 긴급 차단 (stderr → 에이전트에 오류 메시지)
- **`AfterTool`의 `tailToolCallRequest`**: `{"name": "tool_name", "args": {...}}` → 도구 완료 후 즉시 다른 도구 호출 → **S0→S1→S2 체인 구현의 핵심 후보**
- **`AfterAgent`의 `decision: deny` + `reason`**: LLM에 reason을 새 프롬프트로 전송 → 강제 재시도 → **Hard Gate 구현 기반**
- **설정 위치**: `settings.json`의 `hooks` 객체, 프로젝트/사용자/시스템 3계층
- **관리 명령**: `/hooks panel`, `/hooks enable/disable <name>`

### 2.4 Sub-agent / Worker

**레퍼런스**: `docs/core/subagents.md`, `docs/core/remote-agents.md`
**URL**: https://github.com/google-gemini/gemini-cli/blob/main/docs/core/subagents.md

**로컬 subagent 정의** (`.gemini/agents/<name>.md` 또는 `~/.gemini/agents/<name>.md`):

```yaml
---
name: research-executor       # 슬러그, 도구 이름으로 노출
description: |                # 메인 에이전트가 언제 호출할지 결정하는 설명
  S2 Research Execution specialist. Use when executing a research plan.
kind: local                   # 기본값
tools:                        # 명시적 도구 목록 (생략 시 전체 상속)
  - web_fetch
  - web_search
  - read_file
  - write_file
mcpServers:                   # 이 subagent에만 격리된 MCP 서버
  arxiv-search:
    command: npx
    args: [arxiv-mcp-server]
model: gemini-3-flash-preview  # 독립 모델 지정 가능
temperature: 0.3
max_turns: 30
timeout_mins: 10
---

You are a Research Execution specialist...
```

내장 Subagent:
- `codebase_investigator`: 코드베이스 분석
- `cli_help`: CLI 도움말 전문가
- `browser_agent`: 웹 자동화 (실험적, 기본 비활성)
- `generalist_agent`: 라우터 역할

**주요 제약**: Subagent는 다른 Subagent를 호출할 수 없음 (재귀 방지, `*` 도구 와일드카드로도 불가). 즉 DRLLM S1→S2→S3 체인은 **메인 에이전트가 각 subagent를 순차 호출**하는 구조가 필요.

**호출 방법**:
- 자동: 메인 에이전트가 description 기반으로 결정
- 강제: `@subagent_name` prefix 사용

**원격 subagent (A2A)**:
```yaml
---
kind: remote
name: my-remote-agent
agent_card_url: https://example.com/.well-known/agent.json
auth:
  type: apiKey
  key: $MY_API_KEY
---
```
A2A 프로토콜 준수, Google ADC/OAuth/Bearer 토큰 인증 지원

**관리**: `/agents list`, `/agents enable/disable <name>`, `/agents reload`
**비활성화**: `settings.json`의 `experimental.enableAgents: false`

### 2.5 MCP 서버 통합

**레퍼런스**: `docs/tools/mcp-server.md`
**URL**: https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md

등록 방식 (3가지):
1. `settings.json` → `mcpServers` 객체 (전역/프로젝트)
2. `gemini-extension.json` → `mcpServers` 객체 (extension 범위)
3. Subagent frontmatter → `mcpServers` 객체 (subagent 격리 범위)

**환경 처리**: `settings.json`과 extension `.env` 파일에서 `$VAR_NAME` 환경변수 주입 가능
**도구 이름 패턴**: `mcp_<server_name>_<tool_name>`
**Hooks 매처**: `mcp_<server_name>_<tool_name>` 패턴으로 Before/AfterTool에서 인터셉트 가능
**보안**: `excludeTools` 로 특정 MCP 도구 차단 가능, Policy Engine으로 MCP 도구에 세밀한 규칙 적용

### 2.6 컨텍스트 / Memory 시스템

**레퍼런스**: `docs/cli/gemini-md.md`, `docs/tools/memory.md`
**URL**: https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/gemini-md.md

**GEMINI.md 계층 로딩 (3단계)**:
1. 글로벌: `~/.gemini/GEMINI.md`
2. 워크스페이스: 설정된 워크스페이스 디렉터리 및 부모 디렉터리
3. JIT(Just-in-Time): 도구가 파일/디렉터리 접근 시 해당 경로 및 조상 디렉터리의 `GEMINI.md` 자동 스캔

**모듈화**: `@./components/instructions.md` 문법으로 GEMINI.md에서 다른 파일 import
**파일명 커스텀**: `settings.json`의 `context.fileName` 배열로 `["AGENTS.md", "CONTEXT.md", "GEMINI.md"]` 등 지정
**조건부 로딩**: JIT 메커니즘이 사실상 조건부 - 특정 디렉터리의 파일에 접근할 때만 해당 GEMINI.md 로딩

**영구 메모리**:
- `save_memory` 도구: `~/.gemini/GEMINI.md`의 `## Gemini Added Memories` 섹션에 append
- `/memory show`: 현재 로딩된 전체 컨텍스트 표시
- `/memory add <text>`: 즉시 글로벌 GEMINI.md에 추가
- `/memory reload`: 모든 GEMINI.md 파일 재스캔

**세션 간 지속성**: save_memory → 글로벌 GEMINI.md → 모든 세션에서 자동 로딩

---

## Part 3: DRLLM 적용 분석

| DRLLM 요구 | Gemini CLI 가능 | 구현 방법 / 우회 | 비고 |
|----------|---------------|----------------|------|
| 5개 스킬 분화 (S0~S4) | ✅ 가능 | Skills(`SKILL.md` per skill) + Custom Commands(`/skill-name`) 조합. S0=launcher custom command, S1~S4=각 SKILL.md 파일 | Extension 하나에 5개 skills + commands 모두 패키징 가능 |
| Hard Gate 강제 | ✅ 가능 (우회) | `AfterAgent` hook: `decision: deny` + `reason` → LLM에 교정 프롬프트 재전송. Policy Engine으로 특정 도구 차단 | 완전 "소프트웨어 레벨" 강제가 아닌 LLM 재시도 기반이므로 완벽하지는 않음 |
| 체크리스트 강제 | ✅ 가능 (우회) | SKILL.md에 체크리스트 절차 기술 + `AfterAgent` hook에서 응답에 체크리스트 완료 여부 검사 스크립트 | 검증 스크립트가 JSON 구조 응답을 파싱해야 하므로 응답 형식 약속 필요 |
| 다음 스킬 자동 호출 | ⚠️ 부분 가능 | **방법 1**: `AfterTool` hook의 `tailToolCallRequest`로 `activate_skill` 연쇄 호출. **방법 2**: `AfterAgent` hook에서 다음 스킬명 포함 프롬프트를 `reason`으로 전송. **방법 3**: 각 SKILL.md 마지막에 "완료 시 다음 명령 실행" 지시 | 완전 강제는 불가, LLM이 지시를 따라야 함. 가장 강한 방법은 방법 1 (AfterTool tailToolCallRequest) |
| Sub-agent 병렬 | ✅ 가능 | `.gemini/agents/` 에 S1, S2 각각의 agent 정의 → 메인 에이전트가 병렬 호출 결정 | Subagent 간 직접 통신 불가, 메인 에이전트 경유 필요. 강제 병렬은 어려움 |
| BYOC 처리 | ✅ 가능 | `web_fetch`/파일 도구로 로컬 파일 읽기 + GEMINI.md `@{file}` 임포트로 정적 컨텍스트 주입. 대용량은 Gemini 1M context window 활용 | 비디오/오디오는 Custom Command의 `@{...}` multimodal 지원으로 처리 가능 |
| 환각 URL 방지 | ⚠️ 부분 가능 | `AfterAgent` hook에서 URL 형식 검증 스크립트 실행, 실패 시 deny+reason. `BeforeModel` hook에서 강제 URL 제공 지시 injection | 완전 방지는 불가; MCP 도구의 실제 응답만 사용하도록 SKILL.md에 지시 필요 |
| 출처 라벨링 강제 | ⚠️ 부분 가능 | `AfterAgent` hook에서 응답 파싱, 출처 없는 응답 deny. SKILL.md에 출처 형식 강제 지시 | LLM 행동 지시 수준; 완전 검증은 외부 스크립트 필요 |

---

## Part 4: Roadmap / 가까운 미래

### 최근 30일 (2026-03-13 ~ 2026-04-12) 이슈/PR 발견

**활성 개발 영역** (이슈 및 changelog 분석):
- `exit_plan_mode` hook regression 수정 중 (이슈 #25054, priority/p1) → Plan Mode + Hooks 통합 안정화
- `agent` 관련 이슈 다수 (area/agent 라벨) → Subagent 기능 적극 개발 중
- `feat(skills)`: CI 스킬 추가 (PR #23720) → Skills 시스템 확장 진행
- `feat(core)`: 원격 에이전트 inline agentCardJson 지원 (PR #23743) → A2A 기능 강화
- `revert: chore(config): disable agents by default` (PR #23672) → Subagent 기본 활성화로 복귀 결정

**공식 v0.37.1 Highlights** (2026-04-09):
- Dynamic Sandbox Expansion
- Tool-Based Topic Grouping ("Chapters")
- Enhanced Browser Agent (persistent session, dynamic read-only tool discovery)
- Security & Permission Hardening

**Milestones**:
- `GCA - Preview June 23`: 완료 (대부분 closed)
- `Public OSS` (due 2025-06-25): 대부분 closed, 1개 open
- `Q3 '2025` (due 2025-09-30): 11개 open issues

**Model Steering**: `experimental` 플래그로 제공, 활발히 개발 중 → 중기적으로 정식 지원 예상

**ACP (Agent Client Protocol)**: IDE 통합을 위한 JSON-RPC over stdio 프로토콜 → IDE에서 Gemini CLI를 프로그래밍 방식으로 제어 가능, DRLLM의 자동화 시나리오에 활용 가능성 있음

**RFC/공식 Roadmap**: 별도 RFC 문서 발견되지 않음. GitHub Issues + Changelog + Milestones 기반으로만 진행 방향 파악 가능.

---

## 카테고리 종합 권장

### 본체 기능만으로 가능한 부분

- **Skills 시스템**: DRLLM의 5개 스킬을 각 `SKILL.md` 파일로 구현, `.gemini/skills/` 또는 Extension에 패키징 → **즉시 활용 가능**
- **Custom Commands**: `/drllm`, `/drllm:research`, `/drllm:learn` 등 네임스페이스 명령으로 스킬 진입점 구성 → **즉시 활용 가능**
- **GEMINI.md 계층**: Extension의 GEMINI.md로 DRLLM 기본 페르소나 및 정책 정의 → **즉시 활용 가능**
- **Hooks + Policy Engine**: AfterAgent hook으로 출처 검증/하드게이트, BeforeTool/AfterTool로 도구별 검증 → **즉시 활용 가능 (스크립트 개발 필요)**
- **Subagent**: S1(Research Planning), S2(Research Execution), S3(LearnLM Synthesis) 등을 독립 subagent로 분리 → **즉시 활용 가능**
- **`write_todos`**: 멀티스텝 작업 추적 UI → **즉시 활용 가능**
- **Plan Mode**: S1에서 Read-only 연구 단계 강제, Pro 모델 자동 라우팅 → **즉시 활용 가능**
- **Session + Memory**: `save_memory`로 학습 진행 상황 지속 저장 → **즉시 활용 가능**

### 외부 도구가 필요한 부분

- **강제 체인(S0→S1→S2→S3→S4)**: AfterAgent hook의 deny+reason 우회는 LLM 의존적. 완전 강제는 외부 오케스트레이터(Bash 스크립트나 MCP 서버를 통한 `gemini -p "..."` 순차 호출) 필요
- **환각 URL 완전 방지**: Hook에서 URL 검증 스크립트 + MCP-only 도구 사용 정책 병행 필요. Hook 자체만으로는 완전 차단 불가
- **병렬 Sub-agent 강제 실행**: Gemini CLI 자체는 병렬 강제 메커니즘 없음 → 외부 스크립트로 복수 gemini 프로세스 병렬 실행 후 결과 합산 필요
- **Subagent 간 직접 통신**: 재귀 방지로 불가 → 메인 에이전트 경유 강제, 대용량 데이터 전달 시 파일 기반 통신 필요

### 본체에 대한 의존도 평가

- **안정 기능 (즉시 의존 가능)**: Skills, Custom Commands, GEMINI.md, Hooks(11이벤트), Subagents, MCP, Plan Mode, Policy Engine, Memory, Sessions
- **실험 기능 (주의 필요)**: Model Steering (`experimental.modelSteering`), Browser Agent (기능은 안정적이나 실험 플래그), enableAgents 설정
- **버전 안정성**: v0.37.1 stable, nightly 릴리즈 매일 제공. `hooks` exit_plan_mode regression(#25054) 같은 버그도 빠르게 수정 중

### Phase 2 심화 필요 영역

1. **AfterAgent Hook + tailToolCallRequest 패턴**: 스킬 자동 체인 구현을 위한 실제 코드 레벨 확인 (SKILL.md에서 `activate_skill` 연쇄 호출 가능성 검증)
2. **SKILL.md 설계 최적화**: 5개 DRLLM 스킬 각각의 SKILL.md frontmatter 설계, Hard Gate 체크리스트 기술 방식 심화
3. **Policy Engine + Hooks 조합**: Hard Gate 구현을 위한 AfterAgent hook 스크립트 실제 작성 및 테스트
4. **A2A 원격 에이전트**: S3(LearnLM Synthesis)를 Vertex AI Agent Engine 또는 ADK 에이전트로 외부화할 경우의 통합 패턴
5. **`gemini -p` 파이프라인**: 비대화형 모드에서 S0→S1→...→S4 순차 실행 스크립트 설계

---

## 발견 항목 요약 (보고서 템플릿 형식)

---

# Gemini CLI Core Capabilities (Skills + Hooks + Subagents)
**Score**: M5·A5·P3·F4·I5 = 22/25
**URL**: https://github.com/google-gemini/gemini-cli
**Category**: E
**Type**: Extension Platform + Core CLI

## TL;DR (한 단락)
Gemini CLI v0.37.1은 Skills, Custom Commands, Hooks(11이벤트), Subagents(Local+Remote), MCP, Plan Mode, Policy Engine을 정식 지원하는 풍부한 에이전트 플랫폼이다. Claude Code 대비 대부분의 기능에 1:1 대응 메커니즘이 존재하며 일부(Skills, Plan Mode, Policy Engine)는 오히려 더 세밀하다. DRLLM의 5개 스킬 분화는 Skills + Custom Commands로 즉시 구현 가능하다. 가장 큰 격차는 "스킬 간 강제 자동 체인"으로, 본체 기능(AfterAgent hook deny+retry, tailToolCallRequest)으로 우회는 가능하지만 LLM 의존성이 남는다. 환각 URL 방지도 AfterAgent hook 스크립트+MCP-only 정책으로 강화는 가능하나 완전 차단은 불가하다.

## Found Tools / Capabilities
- **Skills**: `SKILL.md` 기반 on-demand 로딩, 3계층(Workspace/User/Extension), `/skills` 관리
- **Custom Commands**: TOML, 네임스페이스, `{{args}}`/`!{shell}`/`@{file}` 동적 치환
- **Hooks**: 11개 이벤트, stdin/stdout JSON, AfterTool `tailToolCallRequest`로 도구 체인
- **Subagents**: YAML frontmatter `.md` 파일, 도구 격리, 독립 MCP 서버, @강제 호출
- **Remote Agents (A2A)**: A2A 프로토콜, Google ADC/OAuth/Bearer 인증
- **Plan Mode**: Read-only 강제, Pro/Flash 자동 모델 라우팅, 비대화형 YOLO 자동화
- **Policy Engine**: TOML 룰, subagent-specific 정책, 조건부 allow/deny/ask_user
- **GEMINI.md JIT**: 파일 접근 시 자동 스캔, `@file` import, `context.fileName` 커스텀
- **Memory**: `save_memory` → `~/.gemini/GEMINI.md`, `/memory` 관리 명령
- **Headless/ACP**: `-p` 플래그, JSON/JSONL 출력, ACP JSON-RPC over stdio

## Patterns Worth Copying
- `AfterAgent` hook `decision: deny` + `reason` 패턴 → Hard Gate 구현
- `AfterTool` `tailToolCallRequest` 패턴 → 도구 완료 후 다음 도구 즉시 연쇄
- SKILL.md frontmatter `description` 에 "When to use" 예시 포함 → LLM이 자동 활성화하도록 유도
- Plan Mode `enter_plan_mode` / `exit_plan_mode` 도구 기반 전환 → DRLLM S1 연구 단계에 적용
- `BeforeToolSelection` hook으로 스킬별 허용 도구 화이트리스트 → S2에서 MCP 도구만 허용

## DRLLM Fit Analysis
- **매핑 스킬**: S0(Custom Command + SessionStart Hook), S1(SKILL.md + Plan Mode), S2(Subagent + MCP), S3(SKILL.md + 외부 LearnLM), S4(SKILL.md + Memory)
- **영향받는 SP**: SP-1(Skills 설계), SP-2(MCP+BYOC 통합), SP-3(end-to-end 검증)
- **교차 발견**: Category C(Superpowers 패턴 → Hooks/Skills로 포팅 가능), Category D(Extension 모범 사례 직접 적용)

## Caveats / Risks
- Subagent 재귀 방지 → S1→S2→S3 순차 체인은 메인 에이전트 경유 필수
- 스킬 자동 체인은 LLM 의존 (SKILL.md 지시를 LLM이 따르지 않을 수 있음)
- `experimental.enableAgents` 과거에 비활성화 시도 있었음(PR #23672 revert) → 향후 기본값 변경 리스크
- exit_plan_mode hook regression(#25054, 2026-04-09, priority/p1) → Plan Mode + Hooks 통합 여전히 안정화 중
- AfterAgent hook으로 hard gate 구현 시 무한 retry 루프 방지 필요 (`stop_hook_active` 필드 활용)

## Recommendation
- ✅ 채택: Gemini CLI 본체가 DRLLM의 핵심 요구를 대부분 만족하며, SP-1/2/3 설계의 기반 플랫폼으로 확정. Skills+Hooks+Subagents 조합이 핵심 구현 스택.

---

*이 보고서는 google-gemini/gemini-cli GitHub 레포지토리의 공식 문서(docs/ 폴더)와 GitHub API를 통한 직접 분석을 기반으로 작성됨. 모든 기능은 v0.37.1 stable 기준이며, 별도 표시된 경우에만 실험적 기능임.*
