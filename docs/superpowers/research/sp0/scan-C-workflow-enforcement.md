# SP-0 Phase 1 — Category C: Workflow 강제 메커니즘 Scan Report

**Date**: 2026-04-12
**Sub-agent**: Sonnet 4.6
**Category**: C — Workflow Enforcement (F·I축 최우선)

---

## 카테고리 개요

Superpowers의 Workflow 강제는 4중 메커니즘으로 구성된다: (1) **스킬 분화** — SKILL.md 파일 단위로 역할이 명확히 분리된 14개 스킬, (2) **Hard Gate** — `<HARD-GATE>` XML 태그로 LLM 행동을 직접 차단하는 선언적 금지문, (3) **체크리스트 강제** — `TodoWrite` 도구와 연동하여 검증된 체크리스트를 순서대로 수행, (4) **다음 스킬 호출 강제** — 스킬 본문에서 "The terminal state is invoking writing-plans" 같은 명시적 지시와 `Skill` 도구 호출로 연쇄를 강제. 이 4중 메커니즘은 Claude Code의 독점 도구(`Task`, `Skill`, `TodoWrite`, `Stop` hook)에 깊이 의존하지만, Gemini CLI 0.26+ 에서 `activate_skill`, `write_todos`, Plan Mode(`enter_plan_mode`/`exit_plan_mode`), `ask_user`, `BeforeTool`/`AfterAgent`/`AfterTool` hooks로 3.5/4개 메커니즘을 근사 구현할 수 있다. 핵심 결손은 **병렬 subagent dispatch** — Gemini에는 Claude Code `Task` 도구 상당물이 없어 `subagent-driven-development` 패턴이 직접 불가능하다.

---

## Part 1: Superpowers 자체 분석 (코드 레벨)

### 1.1 스킬 분화 메커니즘

#### 구조

Superpowers 5.0.7의 `skills/` 디렉토리는 14개 스킬로 분화되어 있다:

```
brainstorming/            writing-plans/            test-driven-development/
executing-plans/          subagent-driven-development/  dispatching-parallel-agents/
systematic-debugging/     verification-before-completion/  writing-skills/
finishing-a-development-branch/  receiving-code-review/  requesting-code-review/
using-git-worktrees/      using-superpowers/
```

각 스킬은 `skills/<skill-name>/SKILL.md` 파일로 구현되며, 반드시 YAML frontmatter를 포함한다:

```yaml
---
name: brainstorming
description: "You MUST use this before any creative work - creating features, building
  components, adding functionality, or modifying behavior. Explores user intent,
  requirements and design before implementation."
---
```

**Frontmatter 설계 원칙 (writing-skills SKILL.md 기준):**
- `name`: 하이픈 구분 소문자 식별자, 슬래시 명령 이름과 동일
- `description`: "Use when..." 형식의 트리거 조건만 기술. **워크플로우 요약 절대 금지** — 설명에 워크플로우를 쓰면 LLM이 전문을 읽지 않고 설명만 따르는 CSO(Claude Search Optimization) 함정이 발생. 이는 실험으로 검증된 설계 원칙.
- Max 1024자 (frontmatter 전체)

**활성화 조건**: `using-superpowers` 스킬이 세션 시작 시 주입되어 "1% 가능성이라도 있으면 반드시 스킬 도구를 호출하라"는 강제 규칙을 설정. 이 규칙이 분화된 스킬 발견과 호출을 강제한다.

#### 스킬 타입 분류

| 타입 | 예시 | 동작 방식 |
|------|------|-----------|
| **Rigid** | TDD, systematic-debugging | "철자를 따르는 것이 정신을 따르는 것" — 예외 없이 순서대로 수행 |
| **Flexible** | requesting-code-review | 컨텍스트에 맞게 원칙을 적용 |
| **Process** | brainstorming, writing-plans | HOW를 정의 — 다른 스킬보다 먼저 적용 |
| **Implementation** | frontend-design | 실행 방식을 안내 |

---

### 1.2 Hard Gate 메커니즘

#### 구현 방식

Hard Gate는 SKILL.md 본문 안에 XML 형식 태그로 직접 삽입된다:

```xml
<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project,
or take any implementation action until you have presented a design and the user
has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>
```

또는:

```xml
<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing,
you ABSOLUTELY MUST invoke the skill.
IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.
This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>
```

또한:

```xml
<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>
```

#### Hard Gate의 실제 효력 원리

Hard Gate는 LLM의 **토큰 예측 편향**을 활용한다:
1. XML 태그가 시스템 프롬프트 안에서 high-attention 패턴으로 작동
2. 대문자 + 강조 어휘 ("DO NOT", "ABSOLUTELY MUST", "NOT NEGOTIABLE")가 컴플라이언스 확률을 높임
3. `writing-skills` SKILL.md는 이것이 실증 테스트 기반 설계임을 명시: "pressure scenarios with subagents"로 rationalization 목록을 수집하고 각각을 counter로 봉쇄

#### TDD-style Skill Development

`writing-skills` 스킬은 스킬 작성을 TDD 사이클로 정의한다:
- **RED**: 스킬 없이 서브에이전트에게 시나리오 실행 → 어떤 rationalization을 쓰는지 기록
- **GREEN**: 그 rationalization을 직접 반박하는 내용으로 스킬 작성
- **REFACTOR**: 새로운 rationalization 발견 시 counter 추가, 재테스트

이것이 brainstorming SKILL.md의 rationalization 봉쇄 패턴("Anti-Pattern: This Is Too Simple To Need A Design") 같은 섹션이 존재하는 이유.

---

### 1.3 체크리스트 강제 메커니즘

#### TodoWrite 연동

`using-superpowers` SKILL.md의 플로우차트:

```dot
"Has checklist?" -> "Create TodoWrite todo per item" [label="yes"];
"Create TodoWrite todo per item" -> "Follow skill exactly";
```

스킬에 체크리스트가 있으면 각 항목을 `TodoWrite` 도구로 즉시 생성하도록 강제한다.

#### brainstorming 스킬의 체크리스트 (실제):

```
1. Explore project context
2. Offer visual companion (if visual questions)
3. Ask clarifying questions (one at a time)
4. Propose 2-3 approaches
5. Present design (sections, get user approval after each)
6. Write design doc → docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md + git commit
7. Spec self-review (placeholder scan, consistency, scope, ambiguity)
8. User reviews written spec
9. Transition to implementation — invoke writing-plans skill
```

**강제 장치**:
- Step 3: "one at a time" — 한 번에 하나 질문만, 스킬 본문에 "Only one question per message" 반복 강조
- Step 6: 파일 경로까지 명시 (`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`)
- Step 7: "look at it with fresh eyes"로 재검토 의무화. 4가지 체크 항목(placeholder, consistency, scope, ambiguity) 명시
- Step 8: 사용자 응답 대기 — "Wait for the user's response"

#### writing-plans 스킬의 체크리스트

TodoWrite 생성 후 순서대로:
1. Scope check (독립 서브시스템이면 분해 요구)
2. File structure mapping (파일 책임 결정)
3. Task 단위 구분 (2~5분 단위)
4. 계획 문서 헤더 작성 (필수 형식 지정)
5. Self-review (spec coverage, placeholder scan, type consistency)
6. Execution Handoff (Subagent-Driven vs Inline Execution 선택)

---

### 1.4 다음 스킬 호출 강제 메커니즘

#### 코드 레벨 패턴

**brainstorming → writing-plans 연쇄 강제:**

```markdown
## Process Flow
...
"Invoke writing-plans skill" [shape=doublecircle];
"User reviews spec?" -> "Invoke writing-plans skill" [label="approved"];
...
**The terminal state is invoking writing-plans.** Do NOT invoke frontend-design,
mcp-builder, or any other implementation skill. The ONLY skill you invoke after
brainstorming is writing-plans.
```

3중 강제:
1. Graphviz dot 다이어그램에서 `doublecircle` shape로 시각화 (터미널 상태)
2. "The terminal state is invoking writing-plans" — 문장으로 재확인
3. "Do NOT invoke frontend-design... The ONLY skill..." — 금지/허용 목록 명시

**writing-plans → subagent-driven-development 또는 executing-plans:**

```markdown
## Execution Handoff
After saving the plan, offer execution choice:
...
**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:executing-plans
```

**executing-plans → finishing-a-development-branch:**

```markdown
### Step 3: Complete Development
After all tasks complete and verified:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch
```

**subagent-driven-development → test-driven-development (서브에이전트 내):**

```markdown
**Subagents should use:**
- **superpowers:test-driven-development** - Subagents follow TDD for each task
```

#### 연쇄 패턴 요약

```
brainstorming
  → writing-plans
      → subagent-driven-development (병렬, 태스크별 fresh context)
          [각 서브에이전트] → test-driven-development
          → finishing-a-development-branch
      → executing-plans (단일 세션, 배치)
          → finishing-a-development-branch
```

모든 연쇄는 **REQUIRED SUB-SKILL** 마커와 도구 호출(`Skill tool`)로 강제된다. LLM이 "기억"에 의존하지 않고 도구를 실제로 호출해야 스킬 내용이 로딩된다.

---

### 1.5 Superpowers 메커니즘의 본질적 의존성

#### Claude Code 전용 도구 의존성

| 메커니즘 | 의존 도구 | 도구 특성 |
|---------|---------|----------|
| 스킬 분화 | `Skill` tool — 스킬 내용 on-demand 로딩 | CC 전용 |
| Hard Gate | 없음 (프롬프트 텍스트만) | 플랫폼 무관 |
| 체크리스트 강제 | `TodoWrite` tool — 세션 내 작업 목록 | CC 전용 |
| 다음 스킬 호출 | `Skill` tool 재호출 | CC 전용 |
| 병렬 서브에이전트 | `Task` tool — 독립 컨텍스트 서브에이전트 생성 | CC 전용 |
| 세션 시작 주입 | `SessionStart` hook + bash script | CC hooks API |
| 루프 지속 | `Stop` hook + bash script | CC `Stop` hook |

#### 핵심 발견

`gemini-tools.md` (Superpowers 공식 매핑 파일)에서 직접 명시:

> `Task` tool (dispatch subagent) | No equivalent — Gemini CLI does not support subagents

그러나 이것은 **2026-01-07 이전 기준**이다. 현재(2026-04-12) Gemini CLI v0.36.0은 독자적인 subagent 시스템을 보유하나, Superpowers는 아직 이를 반영하지 않았다. 즉, Superpowers 공식 매핑은 현재 Gemini 현황보다 **뒤처진 상태**다.

---

## Part 2: Gemini CLI 측 가능성

### 2.1 Gemini CLI의 메타 기능 (현재, v0.36.0 기준)

#### Skills 시스템 (v0.23.0 이상, 기본 활성화 v0.26.0)

- `activate_skill` 도구로 on-demand 스킬 로딩
- SKILL.md frontmatter: `name`, `description` 두 필드 (Superpowers와 동일 형식)
- 세션 시작 시 모든 스킬 메타데이터 로딩 → 태스크 매치 시 `activate_skill` 호출
- 스킬 디렉토리 구조: Claude Code와 동일 (`skills/<name>/SKILL.md`)

#### Todos 시스템 (네이티브)

- `write_todos` 도구: Claude Code `TodoWrite`의 직접 상당물
- Schema: `{description: string, status: "pending"|"in_progress"|"completed"|"cancelled"|"blocked"}`
- **One-at-a-time 제약**: 동시에 하나만 `in_progress` — Superpowers의 순서 강제와 정합
- 세션 범위 (세션 간 미지속)
- Ctrl+T로 UI 표시/숨기기

#### Plan Mode (v0.29.0+, v0.34.0부터 기본 활성화)

- `enter_plan_mode` / `exit_plan_mode` 도구
- Read-only 허용 목록: `read_file`, `list_directory`, `glob`, `grep_search`, `google_web_search`, `web_fetch`, `ask_user` + `.md` 파일만 `write_file`/`replace`
- `ask_user` 도구: 사용자 입력을 명시적으로 요청, 실행 게이팅에 직접 활용 가능
- 플랜 승인 전 `ask_user`로 사용자 확인 대기 — Superpowers의 "User Review Gate"와 동등

#### Hooks 시스템 (v0.26.0+, 기본 활성화)

11개 hook 이벤트:
```
SessionStart, SessionEnd, BeforeAgent, AfterAgent,
BeforeModel, AfterModel, BeforeToolSelection,
BeforeTool, AfterTool, PreCompress, Notification
```

핵심 enforcement 이벤트:
- **BeforeTool**: 특정 도구 실행 전 차단/허용 결정. `matcher` 패턴으로 대상 도구 필터링
- **AfterAgent**: 에이전트 턴 종료 후 "최종 게이트키퍼" — 전체 테스트 스위트 실행, 워크플로우 다음 단계 강제 가능
- **AfterTool**: 도구 실행 직후 검증 (atomic verification)

설정 형식:
```json
{
  "hooks": {
    "BeforeTool": [{
      "matcher": "write_file|replace",
      "hooks": [{"name": "check", "type": "command", "command": ".gemini/hooks/check.sh"}]
    }],
    "AfterAgent": [{
      "hooks": [{"name": "post-check", "type": "command", "command": ".gemini/hooks/post-check.sh"}]
    }]
  }
}
```

Exit code에 따른 결정:
- Exit 0 + JSON `{"decision": "allow"}`: 계속
- Exit 0 + JSON `{"decision": "deny", "reason": "..."}`: 차단 + 에이전트 자기수정
- Exit 2: 강제 중단 + stderr 차단 사유

#### Subagents 시스템 (v0.12.0+)

- `.gemini/agents/` 또는 `~/.gemini/agents/`에 `.md` 파일로 정의
- Frontmatter: `name`, `description`, `tools`, `model`, `temperature`, `max_turns`
- **재귀 보호**: 서브에이전트는 다른 서브에이전트를 호출 불가 (와일드카드 권한도 마찬가지)
- 호출: `@subagent_name` 구문 또는 자동 위임
- **스킬 접근**: 현재 미지원 (GitHub issue #17760 — 진행 중, 0/30 완료)
- **병렬 실행**: Claude Code `Task` 도구처럼 병렬 dispatch는 불가 — 서브에이전트는 순차 실행

#### 추가 네이티브 도구 (Claude Code 상당물 없음)

| 도구 | 역할 | DRLLM 활용 가능성 |
|-----|------|------------------|
| `save_memory` | GEMINI.md에 사실 지속 저장 | 스킬 간 상태 공유 (체크리스트 진행 상태 등) |
| `tracker_create_task` | 리치 태스크 관리 (생성/업데이트/목록/시각화) | `write_todos` 대체 또는 보완 |
| `ask_user` | 구조화된 사용자 입력 요청 | Hard Gate 사용자 승인 게이트 |
| `enter_plan_mode` | 읽기 전용 리서치 모드 | S1(Research Planning) 진입 시 |

---

### 2.2 4중 메커니즘 중 Gemini에서 가능한 것

| 메커니즘 | Gemini 지원 | 구현 방법 | 비고 |
|---------|------------|-----------|------|
| **스킬 분화** | ✅ 완전 | `activate_skill` 도구, SKILL.md 동일 형식 | v0.26.0+ 기본 활성화 |
| **Hard Gate** | ✅ 완전 | 동일 `<HARD-GATE>` 태그 (프롬프트 텍스트) | 플랫폼 무관, 즉시 적용 가능 |
| **체크리스트 강제** | ✅ 근사 | `write_todos` (= `TodoWrite`) + `tracker_create_task` | 시맨틱 동일, Gemini 전용 `tracker_create_task`로 강화 가능 |
| **다음 스킬 호출 강제** | ⚠️ 부분 | `activate_skill` 지시문 + `ask_user` 게이트 | **병렬 subagent dispatch 불가** (순차 전용) |
| **병렬 서브에이전트** | ❌ 불가 | 없음 | 재귀 보호로 서브에이전트 간 호출 불가 |

#### 상세 분석

**스킬 분화 ✅**: Gemini CLI는 `activate_skill` 도구로 SKILL.md를 on-demand 로딩한다. Superpowers의 SKILL.md frontmatter 형식(`name`, `description`)이 Gemini에서도 동일하게 작동한다. `using-superpowers` 스킬이 세션 시작 시 전체 규칙을 주입하고, 이후 개별 스킬을 필요 시 호출하는 구조도 그대로 이식 가능하다. DRLLM의 S0~S4 스킬을 각각 독립 SKILL.md로 분화하는 것은 즉시 가능하다.

**Hard Gate ✅**: `<HARD-GATE>`, `<EXTREMELY-IMPORTANT>` 같은 XML 태그는 순수 프롬프트 텍스트다. 플랫폼과 무관하게 동일하게 작동한다. Gemini CLI에서 Superpowers SKILL.md를 그대로 로딩하면 Hard Gate도 그대로 적용된다. 단, Gemini는 Claude와 다른 모델이므로 rationalization counter의 **효율이 다를 수 있다** — 실증 테스트 필요.

**체크리스트 강제 ✅**: `write_todos`가 `TodoWrite`와 시맨틱 동일하다. 상태(pending/in_progress/completed/cancelled/blocked)도 동일 구조다. `using-superpowers` 스킬의 "Has checklist? → Create TodoWrite todo per item" 패턴을 `write_todos` 호출로 1:1 변환 가능하다. 추가로, Gemini 전용 `tracker_create_task`가 더 리치한 태스크 시각화를 제공한다.

**다음 스킬 호출 강제 ⚠️**: `activate_skill` 지시문으로 다음 스킬 호출을 강제하는 것은 가능하다. 그러나 **병렬 dispatch가 불가능**하다 — `subagent-driven-development` 스킬이 "fresh subagent per task + two-stage review"를 `Task` 도구로 구현하는데, Gemini에는 상당물이 없다. 순차 실행의 `executing-plans` 패턴은 이식 가능하다. `ask_user`로 단계 전환 시 사용자 승인 게이트를 구현할 수 있다.

**병렬 서브에이전트 ❌**: Gemini의 subagent는 재귀 보호가 있어 스킬 내에서 다른 서브에이전트를 호출할 수 없다. GitHub issue #17760 ("Subagent Configurability")이 진행 중이나 현재 0/30 완료다. DRLLM의 S2(Research Execution) 병렬화에 영향.

---

### 2.3 발견된 외부 패턴

#### Ralph Loop (Claude Code Stop Hook 활용)

**URL**: `/home/namykim/.claude/plugins/cache/claude-plugins-official/ralph-loop/`
**Score**: M3·A4·P3·F4·I4 = 18/25
**Type**: Plugin (Stop Hook)

```markdown
# Ralph Loop
**Score**: M3·A4·P3·F4·I4 = 18/25
**URL**: https://github.com/obra/ralph-loop (추정)
**Category**: C
**Type**: Plugin / Hook Pattern

## TL;DR
Ralph Loop는 Claude Code의 `Stop` hook을 활용하여 LLM 출력에 `<promise>completion_phrase</promise>` 태그가 나타날 때까지 동일 프롬프트를 반복 주입하는 자율 루프 메커니즘이다. State는 `.claude/ralph-loop.local.md` 파일의 YAML frontmatter로 관리한다(iteration, max_iterations, completion_promise, session_id). AfterAgent hook(`Stop` 이벤트)이 transcript를 파싱하고 완료 조건을 검증하며, 완료되지 않으면 `{"decision": "block", "reason": prompt_text}`를 반환한다. Gemini의 `AfterAgent` hook으로 유사한 루프를 구현할 수 있으나, Gemini에는 `Stop` 이벤트가 없고 `AfterAgent`는 매 턴 종료 시 실행된다는 차이가 있다.

## Patterns Worth Copying
- YAML frontmatter로 루프 상태 관리 (session isolation 포함)
- `<promise>` 태그 기반 LLM 출력 파싱으로 완료 조건 검증
- `{"decision": "block", "reason": prompt}` JSON으로 루프 지속
- transcript JSONL 파싱으로 마지막 어시스턴트 메시지 추출

## DRLLM Fit Analysis
- 매핑 스킬: S1(Research Planning) 반복 정제 루프, S4(Adaptive Tutoring) 학습 루프
- Gemini AfterAgent hook으로 근사 구현 가능

## Recommendation
- 🔧 카피·수정 — Stop hook → AfterAgent hook 변환 필요
```

#### Gemini CLI의 AfterAgent Hook 기반 "Ralph 패턴"

Gemini AfterAgent hook에서 `{"decision": "deny", "reason": next_prompt}`를 반환하면 에이전트가 자기수정 루프에 진입한다. 완료 조건(예: 특정 파일 생성, 특정 출력 패턴)을 shell script로 검증하여 체크리스트 강제와 다음 스킬 호출 강제를 **hook 레벨에서** 구현할 수 있다.

```json
// AfterAgent hook 응답 예시 — 다음 스킬 강제 호출 패턴
{
  "decision": "deny",
  "reason": "체크리스트 항목 3(design doc 작성)이 미완료. docs/superpowers/specs/ 에 파일을 생성하고 activate_skill writing-plans 를 호출하라.",
  "systemMessage": "Design doc missing — cannot proceed to writing-plans"
}
```

이 패턴은 Hard Gate를 **hook 레벨에서 확인**하여 LLM 판단에 의존하지 않고 결정론적으로 강제한다.

---

## Superpowers Workflow 메커니즘 상세 항목 스코어

### Superpowers 스킬 분화 패턴 (DRLLM S0~S4 분화에 직접 채택)

```markdown
# Superpowers Skill Differentiation Pattern
**Score**: M5·A5·P4·F5·I5 = 24/25
**URL**: /home/namykim/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/
**Category**: C
**Type**: Pattern

## TL;DR
SKILL.md frontmatter(`name`, `description`) + on-demand 로딩(`activate_skill`) + `using-superpowers` 메타스킬로 구성된 스킬 분화 패턴은 Gemini CLI에서 완전히 지원된다. 14개 스킬이 역할별로 분화되어 있고, `using-superpowers`가 세션 시작 시 스킬 사용 규칙을 강제한다. DRLLM의 S0~S4 스킬을 동일 형식으로 분화하면 즉시 적용 가능하다.

## Patterns Worth Copying
- SKILL.md frontmatter의 `description` CSO 원칙 (트리거 조건만, 워크플로우 요약 금지)
- `using-superpowers` 메타스킬의 "1% 규칙" + 세션 시작 주입
- 스킬 타입 분류 (Rigid vs Flexible, Process vs Implementation)
- Skill 발견 우선순위 ("Process skills first, Implementation skills second")

## Recommendation
- ✅ 채택 — DRLLM GEMINI.md에 `using-superpowers`와 동일한 메타스킬 주입 패턴 적용
```

### Superpowers Hard Gate 패턴

```markdown
# Superpowers Hard Gate Pattern
**Score**: M5·A5·P4·F5·I5 = 24/25
**URL**: /home/namykim/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/brainstorming/SKILL.md
**Category**: C
**Type**: Pattern

## TL;DR
`<HARD-GATE>`, `<EXTREMELY-IMPORTANT>` XML 태그 + 대문자 강제 언어 + rationalization counter 표가 LLM의 회피 시도를 체계적으로 봉쇄한다. TDD-style 스킬 작성 프로세스(RED: 기준선 위반 패턴 수집 → GREEN: 그 패턴 반박하는 스킬 작성 → REFACTOR: 새 rationalization 봉쇄)가 Hard Gate 효력의 기반이다. Gemini Gemma 기반 모델에서 동일 태그의 효력은 별도 테스트 필요.

## Patterns Worth Copying
- `<HARD-GATE>` 태그 패턴 (Gemini에서도 동일하게 삽입 가능)
- Rationalization counter 표 패턴
- "Violating the letter of the rules is violating the spirit of the rules" 원칙 삽입
- Red Flags 섹션 패턴 (자기 검열 메커니즘)

## DRLLM Fit Analysis
- S0→S1 전환: "주제 수신 전 Research Planning 스킬 반드시 호출" Hard Gate
- S1→S2 전환: "계획 없이 검색 실행 불가" Hard Gate
- S2→S3 전환: "출처 라벨링 미완료 시 LearnLM 변환 불가" Hard Gate

## Recommendation
- ✅ 채택 — 각 DRLLM 스킬의 전환 지점에 Hard Gate 삽입
```

### Gemini write_todos 기반 체크리스트 강제

```markdown
# Gemini write_todos Checklist Enforcement
**Score**: M4·A5·P4·F5·I5 = 23/25
**URL**: https://geminicli.com/docs/tools/todos/
**Category**: C
**Type**: Native Tool

## TL;DR
Gemini 네이티브 `write_todos` 도구는 Claude Code `TodoWrite`와 시맨틱 동일하며, One-at-a-time 제약(동시 1개만 in_progress)이 Superpowers의 순서 강제와 정합한다. 추가로 `tracker_create_task`가 더 리치한 태스크 관리를 제공한다. DRLLM 스킬 체크리스트를 `write_todos` 호출로 강제하는 것은 즉시 가능하다.

## Recommendation
- ✅ 채택 — Superpowers의 TodoWrite 패턴을 write_todos로 직접 이식
```

### Gemini AfterAgent Hook 기반 워크플로우 게이트

```markdown
# Gemini AfterAgent Hook Workflow Gate
**Score**: M3·A4·P4·F4·I4 = 19/25
**URL**: https://geminicli.com/docs/hooks/
**Category**: C
**Type**: Native Hook

## TL;DR
AfterAgent hook이 에이전트 턴 종료 후 `{"decision": "deny", "reason": "..."}` JSON을 반환하면 에이전트가 자기수정 루프에 진입한다. 이 메커니즘으로 스킬 체크리스트 항목 완료 여부를 shell script로 검증하고 미완료 시 다음 단계 진입을 차단할 수 있다. 현재 AfterAgent matcher가 `*`만 지원(모든 턴에 실행)되어 불필요한 hook 실행이 발생하는 제약이 있다.

## Patterns Worth Copying
- 파일 존재 여부/내용으로 체크리스트 완료 검증
- `{"decision": "deny", "reason": next_step_instructions}` 패턴
- `save_memory`와 결합하여 완료 상태 지속 저장

## DRLLM Fit Analysis
- S1→S2 게이트: 계획 파일(research_plan.md) 존재 확인
- S2→S3 게이트: 출처 라벨링 완료 확인
- Phase 전환 하드 검증

## Caveats
- AfterAgent는 매 턴 실행 (조건부 실행 불가) — 성능 부담
- hook이 skill을 직접 호출 불가 — 텍스트 지시로만 유도 가능

## Recommendation
- 🔧 카피·수정 — DRLLM 핵심 게이트(S1→S2, S2→S3)에만 선별 적용
```

### Gemini Plan Mode (enter_plan_mode + ask_user)

```markdown
# Gemini Plan Mode as Research Gate
**Score**: M4·A5·P4·F4·I5 = 22/25
**URL**: https://geminicli.com/docs/cli/plan-mode/
**Category**: C
**Type**: Native Feature

## TL;DR
Plan Mode는 읽기 전용 허용 목록으로 리서치 단계를 강제하고, `ask_user`로 사용자 승인 게이트를 구현한다. `enter_plan_mode` → 리서치/계획 → `ask_user` 승인 → `exit_plan_mode` → 실행 패턴이 Superpowers의 brainstorming → 사용자 승인 → writing-plans 흐름과 대응된다. v0.34.0부터 기본 활성화로 성숙도 높음.

## DRLLM Fit Analysis
- S1(Research Planning): enter_plan_mode로 리서치 모드 진입 강제
- S0→S1 전환: ask_user로 주제 확인 및 승인 게이트
- "계획 없이 실행 불가" Hard Gate의 기술적 구현체

## Recommendation
- ✅ 채택 — S1 진입 시 enter_plan_mode 강제, S0→S1 전환에 ask_user 게이트 적용
```

---

## 카테고리 종합 권장

### DRLLM이 채택할 메커니즘 조합 (현실적으로 가능한 것)

**즉시 적용 가능 (Superpowers 그대로 카피):**

1. **스킬 분화**: DRLLM S0~S4를 각각 독립 SKILL.md로 분화. GEMINI.md에서 `@./skills/using-drllm/SKILL.md` 주입으로 메타스킬 역할 수행. Superpowers `gemini-tools.md` 패턴으로 도구 이름 매핑 제공.

2. **Hard Gate**: 각 스킬 전환 지점에 `<HARD-GATE>` 태그 삽입. "S1 계획 없이 S2 실행 불가", "출처 라벨링 미완료 시 S3 전환 불가" 등의 금지문. Superpowers의 rationalization counter 패턴 적용.

3. **체크리스트 강제**: `write_todos`로 각 스킬 체크리스트 항목 즉시 생성. One-at-a-time 제약으로 순서 강제. `tracker_create_task`로 보강 가능.

4. **다음 스킬 호출 강제 (순차)**: SKILL.md 본문에 "The terminal state is invoking S2 skill" 패턴으로 다음 스킬 호출 명시. `activate_skill` 도구 호출로 강제.

**변형 필요:**

5. **AfterAgent Hook 게이트**: 핵심 전환점(S1→S2, S2→S3)에만 AfterAgent hook으로 파일 존재 검증. 매 턴 실행 비용을 감안해 선별 적용.

6. **Plan Mode 활용**: S1 스킬이 `enter_plan_mode`를 명시적으로 호출. `ask_user`로 계획 승인 게이트 구현.

**포기해야 하는 것:**

7. **병렬 서브에이전트 dispatch**: `subagent-driven-development` 패턴은 불가. S2(Research Execution)의 병렬 출처 검색이 제약을 받음. 대안: `executing-plans` 패턴으로 순차 실행, 또는 Gemini 공식 subagent 스킬 지원(#17760) 완료 대기.

### Superpowers 카피 가능 vs 변형 필요 vs 포기

| 항목 | 판단 | 이유 |
|------|------|------|
| SKILL.md 형식 | ✅ 그대로 카피 | 동일 frontmatter 스펙 |
| `<HARD-GATE>` 태그 | ✅ 그대로 카피 | 순수 프롬프트 텍스트 |
| TodoWrite 체크리스트 | ✅ `write_todos`로 1:1 대체 | 시맨틱 동일 |
| `using-superpowers` 메타스킬 | ✅ 그대로 카피 + GEMINI.md 주입 | 도구 이름 매핑만 수정 |
| Skill → Skill 호출 강제 패턴 | ✅ `activate_skill`로 변환 | 도구 이름만 다름 |
| SessionStart hook | 🔧 변형 (JSON 형식 차이) | Gemini hook 응답 형식 상이 |
| Stop hook 루프 | 🔧 AfterAgent로 근사 | Stop 이벤트 없음 |
| `subagent-driven-development` | ❌ 포기 | Task 도구 상당물 없음 |
| `dispatching-parallel-agents` | ❌ 포기 | 병렬 서브에이전트 불가 |
| Spec reviewer subagent | 🔧 순차 실행으로 변형 | 코드 리뷰는 가능하나 병렬 불가 |

### Gemini CLI 본체에 부족한 기능 → SP-2에서 우회/구현

1. **병렬 research execution**: S2에서 복수 출처를 병렬로 검색하는 능력이 없음. SP-2에서 MCP 도구 레벨 병렬화로 우회 (각 검색 도구 호출은 병렬 가능하나 서브에이전트 레벨이 아님).

2. **서브에이전트 내 스킬 접근**: #17760 완료 대기. SP-2 설계 시 subagent 권한에 스킬 접근 포함 여부 확인 필요.

3. **AfterAgent matcher 세분화**: 현재 매 턴 실행이 강제됨. SP-2에서 상태 파일 기반 조건부 실행 로직 구현.

### Phase 2 심화 후보

1. **Gemini subagent + skills 통합 (issue #17760)**: 완료 시 `subagent-driven-development` 패턴 부분 이식 가능성 — SP-2 설계에 핵심 영향.

2. **AfterAgent hook 기반 게이트 상세 구현**: DRLLM 핵심 전환점(S1→S2, S2→S3)에서의 hook 스크립트 설계. 체크리스트 완료 검증 로직.

3. **`save_memory` 기반 스킬 간 상태 공유**: 세션 간 체크리스트 진행 상태 지속 — Superpowers에 없는 Gemini 전용 기능.

4. **Plan Mode + Skills 통합 패턴**: `enter_plan_mode` 내에서 S1 스킬을 활성화하는 구체적 흐름 설계.

---

*보고서 작성 기준: Superpowers 5.0.7 코드 직접 분석 + Gemini CLI v0.36.0 공식 문서 + geminicli.com/docs/ + Google Developers Blog + DeepWiki*
