# SP-0 Phase 2 — Category E Deep Dive

**Date**: 2026-04-12
**Sub-agent**: Sonnet 4.6
**Category**: E — Gemini CLI Internals (코드 레벨 심화)
**Phase 1 참조**: scan-E-gemini-cli-capabilities.md
**Gemini CLI version**: v0.37.1 (latest stable, 2026-04-09 릴리즈)
**Source**: google-gemini/gemini-cli GitHub repo — docs/ 직접 fetch (gh API)

---

## 심화 분석

### 1. AfterTool tailToolCallRequest 스킬 체인

#### 1.1 정확한 Schema (공식 reference.md 기준)

`AfterTool` hook의 `hookSpecificOutput.tailToolCallRequest` 필드:

```typescript
// AfterTool hook 출력 JSON에서:
{
  "hookSpecificOutput": {
    "tailToolCallRequest": {
      "name": string,    // 호출할 다음 도구의 정확한 이름
      "args": object     // 다음 도구에 전달할 인수 객체
    }
  }
}
```

공식 문서 설명: "A request to execute another tool immediately after this one. The result of this 'tail call' will **replace** the original tool's response. Ideal for programmatic tool routing."

중요 동작:
- `original_request_name` 입력 필드: "The original name of the tool being called, **if this is a tail tool call**." — 꼬리 호출 체인 추적 가능
- 꼬리 호출의 결과가 원래 도구 결과를 **대체(replace)** 함
- `BeforeTool` 입력에도 `original_request_name` 존재 → 꼬리 호출을 AfterTool/BeforeTool 둘 다에서 감지 가능

#### 1.2 실제 작동하는 Hook Script 예제

**시나리오**: S0 Launcher가 `activate_skill(drllm-launcher)` 완료 후 자동으로 `activate_skill(drllm-research-planning)` 연쇄 호출

`.gemini/hooks/skill-chain.sh`:

```bash
#!/usr/bin/env bash
# AfterTool hook: activate_skill 완료 시 다음 스킬 자동 체인
# 반드시 stdout에는 JSON만, 로그는 stderr만

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
skill_activated=$(echo "$input" | jq -r '.tool_input.skill_name // empty')

# 로그는 stderr
echo "[skill-chain] tool=$tool_name skill=$skill_activated" >&2

# S0 완료 → S1 자동 체인
if [[ "$tool_name" == "activate_skill" && "$skill_activated" == "drllm-launcher" ]]; then
  echo "[skill-chain] Chaining drllm-launcher -> drllm-research-planning" >&2
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "tailToolCallRequest": {
      "name": "activate_skill",
      "args": { "skill_name": "drllm-research-planning" }
    }
  },
  "systemMessage": "S0 Launcher 완료 → S1 Research Planning 자동 로딩"
}
EOF
  exit 0
fi

# 기본: 통과
echo '{}'
exit 0
```

`.gemini/settings.json` 등록:

```json
{
  "hooks": {
    "AfterTool": [
      {
        "matcher": "activate_skill",
        "hooks": [
          {
            "name": "drllm-skill-chain",
            "type": "command",
            "command": "$GEMINI_PROJECT_DIR/.gemini/hooks/skill-chain.sh",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

#### 1.3 "도구 완료 후 다음 도구 자동 호출" 패턴 — DRLLM 스킬 체인 설계

```
S0: activate_skill("drllm-launcher") 완료
  └── AfterTool hook: tailToolCallRequest → activate_skill("drllm-research-planning")
        └── S1 활성화됨
              └── (LLM이 S1 지시에 따라 연구 계획 실행)
                    └── S1 내부에서 write_file("research-plan.md") 호출
                          └── AfterTool hook: tailToolCallRequest → activate_skill("drllm-research-execution")
                                └── S2 활성화됨
```

#### 1.4 핵심 한계 분석

**tailToolCallRequest의 실용성 평가**:

| 항목 | 실제 동작 | 평가 |
|------|-----------|------|
| activate_skill 연쇄 | 가능 (검증됨) | S0→S1 체인에 적합 |
| 꼬리 호출 결과가 원본 대체 | 원본 도구 결과가 꼬리 호출 결과로 교체됨 | 체인 중간에 원본 출력이 사라지는 부작용 있음 |
| LLM 개입 없이 도구-to-도구 체인 | 가능 — hook은 Bash/Node 스크립트로 실행, LLM 경유 없음 | 핵심 강점 |
| S0→S1→S2 전체 체인 강제 | 각 스킬 내부 도구(예: write_file) 트리거를 식별해야 함 | 신뢰할 수 있는 트리거 포인트 설계 필요 |
| 무한 루프 방지 | `original_request_name`으로 꼬리 호출 여부 감지 가능, 스크립트에서 조건부 체인 필요 | 명시적 종료 조건 필수 |

**결론**: `tailToolCallRequest`는 LLM을 거치지 않고 도구를 직접 체인할 수 있다. 단, 꼬리 호출 결과가 원본 결과를 대체하므로 중간 단계 출력을 보존하려면 `additionalContext`와 조합해야 한다. S0→S1 진입점 체인에는 즉시 활용 가능.

---

### 2. Policy Engine + AfterAgent Hook Hard Gate 프로토타입

#### 2.1 Policy Engine 정확한 Schema (공식 policy-engine.md 기준)

**TOML 룰 전체 필드**:

```toml
[[rule]]
# 필수
toolName = "run_shell_command"      # string 또는 array. 와일드카드: *, mcp_*, mcp_server_*
decision = "deny"                   # "allow" | "deny" | "ask_user"

# 선택
subagent = "research-executor"      # 이 subagent가 호출할 때만 적용
mcpName = "my-server"               # MCP 서버 이름 (toolName과 조합)
toolAnnotations = { readOnlyHint = true }
argsPattern = '"command":"(git|npm)' # 인수 JSON에 대한 regex
commandPrefix = "rm -rf"            # run_shell_command 전용 prefix 매칭
commandRegex = "git (commit|push)"  # run_shell_command 전용 regex
priority = 100                      # 0~999, 높을수록 우선
denyMessage = "이유 설명"           # 거부 시 모델과 사용자에게 전달
modes = ["default", "autoEdit"]     # 적용 모드 제한 (없으면 전체)
interactive = true                  # true/false: 환경 제한
allowRedirection = true             # shell redirection 허용 여부
```

**우선순위 티어 (Tier 시스템)**:

| 티어 | Base | 위치 |
|------|------|------|
| Default | 1 | 내장 정책 |
| Extension | 2 | extension 내 정책 |
| Workspace | 3 | `.gemini/policies/*.toml` |
| User | 4 | `~/.gemini/policies/*.toml` |
| Admin | 5 | `/etc/gemini-cli/policies/` |

최종 우선순위 = `tier_base + (toml_priority / 1000)`

**중요 특성**: `deny` 결정이 적용된 글로벌 규칙(argsPattern 없는 경우)은 해당 도구를 **모델의 메모리에서 완전히 제거** — 모델이 그 도구의 존재 자체를 보지 못함. 단순 "차단"보다 강력.

#### 2.2 AfterAgent Hook deny + reason 패턴

공식 reference.md 기준 `AfterAgent` 입력/출력:

**입력 필드**:
- `prompt`: 사용자 원래 요청 (string)
- `prompt_response`: 에이전트 최종 응답 텍스트 (string)
- `stop_hook_active`: 현재 이미 retry 중인지 여부 (boolean) — **무한 루프 방지 핵심**

**출력 필드**:
- `decision: "deny"` → 응답 거부 + 자동 재시도 트리거
- `reason`: LLM에게 새 프롬프트로 전송되는 교정 요청 텍스트
- `continue: false` → 재시도 없이 세션 중단
- `hookSpecificOutput.clearContext: true` → LLM 히스토리 초기화 (UI는 유지)

**`decision: "block"`**: `"deny"`의 alias — 동일 동작.

#### 2.3 Hard Gate 결합 구현 — "메타인지 체크 통과 전 다음 단계 진입 차단"

**시나리오**: S1 Research Planning이 완료되었다고 주장하기 전에, 연구 계획 파일이 실제로 존재하고 체크리스트가 충족되는지 확인. 미충족 시 재시도 강제.

`.gemini/hooks/hard-gate.sh`:

```bash
#!/usr/bin/env bash
# AfterAgent hook: Hard Gate — S1 완료 조건 검증
# 무한 루프 방지: stop_hook_active 확인

input=$(cat)
prompt_response=$(echo "$input" | jq -r '.prompt_response')
stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')

echo "[hard-gate] stop_hook_active=$stop_hook_active" >&2

# 무한 루프 방지: 이미 retry 중이면 통과
if [[ "$stop_hook_active" == "true" ]]; then
  echo '[hard-gate] Already in retry loop, passing through' >&2
  echo '{"decision": "allow"}'
  exit 0
fi

# S1 완료 체크: 연구 계획 파일 존재 여부
PLAN_FILE="$GEMINI_PROJECT_DIR/.gemini/drllm-research-plan.md"
if [[ ! -f "$PLAN_FILE" ]]; then
  echo '[hard-gate] Research plan file missing — denying' >&2
  cat <<'EOF'
{
  "decision": "deny",
  "reason": "HARD GATE: Research Planning 단계가 완료되지 않았습니다. drllm-research-plan.md 파일을 생성하고 다음 섹션을 포함해야 합니다: ## Research Objectives, ## Search Strategy, ## Source Types. 파일 생성 후 완료를 보고하세요.",
  "systemMessage": "Hard Gate: S1 완료 조건 미충족"
}
EOF
  exit 0
fi

# 파일 내용 검증: 필수 섹션 존재 여부
if ! grep -q "## Research Objectives" "$PLAN_FILE" || \
   ! grep -q "## Search Strategy" "$PLAN_FILE" || \
   ! grep -q "## Source Types" "$PLAN_FILE"; then
  echo '[hard-gate] Research plan incomplete — denying' >&2
  cat <<'EOF'
{
  "decision": "deny",
  "reason": "HARD GATE: drllm-research-plan.md 파일이 존재하지만 필수 섹션이 누락되었습니다. ## Research Objectives, ## Search Strategy, ## Source Types 세 섹션이 모두 있어야 합니다.",
  "systemMessage": "Hard Gate: 연구 계획 불완전"
}
EOF
  exit 0
fi

# 검증 통과
echo '[hard-gate] S1 gate passed' >&2
cat <<'EOF'
{
  "decision": "allow",
  "systemMessage": "Hard Gate: S1 Research Planning 검증 통과"
}
EOF
exit 0
```

#### 2.4 Policy Engine + AfterAgent 결합 — 이중 Hard Gate

**1단계 (Policy Engine — 도구 레벨 차단)**: S2가 시작되기 전 특정 MCP 검색 도구를 차단

`.gemini/policies/drllm-gates.toml`:

```toml
# S1 완료 전 S2 MCP 도구 차단 게이트
# 이 파일은 S1이 완료되면 삭제되거나 비활성화됨
[[rule]]
name = "block-s2-before-s1-complete"
mcpName = "arxiv-search"
decision = "deny"
priority = 800
denyMessage = "DRLLM Hard Gate: S1 Research Planning이 완료되지 않았습니다. /drllm:planning 명령으로 연구 계획을 먼저 완성하세요."
modes = ["default", "autoEdit"]
```

**2단계 (AfterAgent Hook — 응답 레벨 검증)**: S1 완료 선언 검증 (위 스크립트)

**결합 패턴**:

```
[Policy Engine] → MCP 도구 레벨 차단 (S1 미완료 시 S2 도구 사용 불가)
[AfterAgent Hook] → 응답 내용 레벨 검증 (S1 완료 체크리스트 미충족 시 재시도)
```

두 레이어가 독립적으로 작동 → 어느 하나를 우회해도 다른 레이어가 차단.

#### 2.5 DRLLM "P5 메타인지 체크 통과 전 다음 단계 진입 차단" 구현 가능성

**평가**: 구현 가능, 단 완전한 하드웨어 레벨 차단이 아닌 소프트웨어 레벨 강제.

- Policy Engine의 `deny` → 도구 존재 자체를 모델에서 숨김 (강력)
- AfterAgent `decision: deny` → LLM이 retry 지시를 따르지 않을 경우 우회 가능성 존재
- `stop_hook_active` 무한 루프 방지 내장 → 최대 재시도 횟수 제어 필요 (스크립트에서 파일 기반 카운터 구현 가능)
- 두 레이어 결합 시 실용적인 Hard Gate 구현 가능

---

### 3. Skills 시스템 — SKILL.md 정확 Schema

#### 3.1 SKILL.md 공식 Schema (creating-skills.md 기준)

**필수 필드** (frontmatter):

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `name` | string | Yes | 고유 식별자. 디렉터리 이름과 일치 권장. lowercase, 하이픈 가능 |
| `description` | string | Yes | 언제 사용할지 기술. LLM이 activate_skill 호출 여부 결정에 사용 |

**선택 필드**: SKILL.md 공식 스키마에는 `name`과 `description` 두 필드만 지정됨. Superpowers가 추가 필드 없이 이 두 필드만 사용하는 것이 표준 패턴임을 확인.

**본문 구조**: 본문 전체가 스킬 활성화 시 에이전트에 주입되는 System Instructions. 마크다운 자유 형식.

**스킬 디렉터리 구조** (권장):

```text
my-skill/
├── SKILL.md          (필수) frontmatter + 지시사항
├── scripts/          (선택) 실행 가능 스크립트
├── references/       (선택) 정적 문서
└── assets/           (선택) 템플릿 및 기타 자료
```

#### 3.2 activate_skill 도구 동작 (공식 skills.md 기준)

1. **Discovery**: 세션 시작 시 모든 스킬의 name + description만 시스템 프롬프트에 주입 (컨텍스트 절약)
2. **Activation**: 태스크 매치 감지 시 LLM이 `activate_skill` 도구 호출
3. **Consent**: UI에 확인 프롬프트 표시 (스킬명, 목적, 디렉터리 경로)
4. **Injection**: 승인 후 SKILL.md 본문 + 디렉터리 구조 → 대화 히스토리에 추가, 디렉터리가 허용 파일 경로에 추가
5. **Persistence**: 활성화된 스킬은 세션 종료까지 활성 상태 유지

**중요**: activate_skill은 사용자 승인(consent)을 요구함. 완전 자동화 시나리오(headless/yolo 모드)에서는 Policy Engine으로 auto-approve 설정 필요.

#### 3.3 3계층 발견 메커니즘과 충돌 우선순위

| 계층 | 위치 | 우선순위 |
|------|------|----------|
| **Workspace** | `.gemini/skills/` 또는 `.agents/skills/` | 최고 |
| **User** | `~/.gemini/skills/` 또는 `~/.agents/skills/` | 중간 |
| **Extension** | 설치된 extension 내 skills/ | 최저 |

**동일 이름 충돌**: Workspace > User > Extension 순으로 override.

**별칭 우선순위 (동일 계층 내)**: `.agents/skills/` 가 `.gemini/skills/` 보다 우선. — 이 generic alias는 다른 AI 에이전트 도구와의 호환성을 위한 설계.

**DRLLM 배포 전략**: Extension으로 패키징 시 5개 DRLLM 스킬이 Extension 계층에 배치됨. 프로젝트별 커스터마이즈는 Workspace 계층(`.gemini/skills/`)에서 동명 파일로 override 가능.

---

### 4. Subagents (.gemini/agents/*.md)

#### 4.1 frontmatter Schema (공식 subagents.md 기준)

```yaml
---
name: string          # 필수. slug: lowercase, 숫자, 하이픈, 언더스코어만. 도구 이름으로 노출
description: string   # 필수. 메인 에이전트가 호출 여부 결정하는 설명 (example 포함 권장)
kind: string          # 선택. "local" (기본값) 또는 "remote"
tools:                # 선택. 허용 도구 목록. 생략 시 전체 상속
  - read_file         # built-in 도구 이름 직접 나열
  - grep_search
  - "mcp_*"           # MCP 전체 와일드카드
  - "mcp_server_*"    # 특정 서버 도구 전체
mcpServers:           # 선택. 이 subagent에만 격리된 MCP 서버 (inline 정의)
  my-server:
    command: node
    args: [./mcp-server.js]
model: string         # 선택. 기본값 "inherit" (메인 세션 모델 상속)
temperature: number   # 선택. 0.0~2.0, 기본값 1
max_turns: number     # 선택. 기본값 30
timeout_mins: number  # 선택. 기본값 10
---
System prompt (본문)
```

#### 4.2 도구 격리 메커니즘

- **명시적 목록**: `tools` 배열에 이름을 나열 → 해당 도구만 접근 가능
- **와일드카드**: `*` (전체), `mcp_*` (MCP 전체), `mcp_<서버명>_*` (특정 서버)
- **생략 시**: 부모 세션의 전체 도구 상속
- **재귀 방지**: `*` 와일드카드를 포함해도 **다른 subagent를 도구로 볼 수 없음** — 재귀 방지는 tools 설정과 무관하게 항상 적용됨

**Subagent-specific Policy 연동**:

```toml
[[rule]]
name = "research-exec-only-mcp"
subagent = "research-executor"      # 이 subagent에만 적용
toolName = "run_shell_command"
decision = "deny"
priority = 900
denyMessage = "Research Executor는 shell 명령을 사용할 수 없습니다."
```

#### 4.3 독립 MCP 서버 지정

**가능** — `mcpServers` 객체를 frontmatter에 직접 정의:

```yaml
---
name: research-executor
tools:
  - web_search
  - web_fetch
  - "mcp_arxiv_*"
mcpServers:
  arxiv:
    command: npx
    args: ["-y", "arxiv-mcp-server"]
  semantic-scholar:
    command: uvx
    args: ["mcp-server-fetch"]
---
```

이 MCP 서버들은 해당 subagent **에만 격리**됨. 메인 에이전트나 다른 subagent에 노출되지 않음.

#### 4.4 A2A 원격 에이전트 패턴

**Remote subagent 단일 정의**:

```yaml
---
kind: remote
name: learnlm-synthesizer
agent_card_url: https://example.com/.well-known/agent.json
auth:
  type: apiKey
  key: $LEARNLM_API_KEY
---
```

**멀티 remote subagent (단일 파일)** — remote 전용:

```yaml
---
- kind: remote
  name: learnlm-agent
  agent_card_url: https://learnlm.example.com/agent
- kind: remote
  name: tutoring-agent
  agent_card_url: https://tutoring.example.com/agent
---
```

인증 방식: `apiKey`, `oauth` (Bearer 토큰), Google ADC (`type: google-adc`).

#### 4.5 재귀 호출 불가의 정확한 정의

공식 문서 인용: "To prevent infinite loops and excessive token usage, subagents **cannot** call other subagents. If a subagent is granted the `*` tool wildcard, it will still be unable to see or invoke other agents."

**정확한 조건**: 재귀 방지는 **tools 설정과 무관하게 시스템 레벨에서 항상 적용**됨.
- Subagent가 `*` 와일드카드를 가져도 → 다른 subagent 도구 불가시
- `invoke_agent` 도구 또는 subagent 이름의 도구 → subagent 컨텍스트에서 존재 자체가 숨겨짐

**DRLLM 함의**: S1→S2→S3 체인은 메인 에이전트가 각 subagent를 순차 호출하는 구조 필수. Subagent가 다음 subagent를 직접 호출하는 패턴은 불가.

---

### 5. DRLLM 5스킬 SKILL.md Skeleton (실제 작성 가능 수준)

#### S0 — Launcher

`.gemini/skills/drllm-launcher/SKILL.md`:

```yaml
---
name: drllm-launcher
description: >
  Use when a user wants to start a deep research and learning session on any topic.
  Triggers when user says things like "I want to learn about X", "research Y for me",
  "start DRLLM for Z", or "teach me about W". This is the ENTRY POINT for all DRLLM
  workflows. Do NOT use any other DRLLM skill before activating this one first.
---
```

```markdown
# DRLLM Launcher — S0

당신은 DRLLM(Deep Research & Learning LLM) 시스템의 진입점입니다.
사용자가 특정 주제를 학습하거나 심층 조사하고 싶을 때 이 스킬이 활성화됩니다.

<HARD-GATE>
이 스킬이 활성화되면, 사용자가 명확한 주제를 제공할 때까지 다른 DRLLM 스킬을
절대 호출하지 마세요. 주제 확정이 이 스킬의 유일한 임무입니다.
</HARD-GATE>

## 체크리스트

다음을 순서대로 완료하세요:

1. **주제 수신**: 사용자가 제공한 주제를 파악
2. **주제 명확화**: 주제가 모호하면 한 번에 하나의 질문으로 명확화
   - 도메인 범위 (예: "Python 비동기"가 기초인지 고급인지)
   - 목표 (개념 이해 / 실무 적용 / 시험 준비)
   - 사전 지식 수준
3. **세션 초기화**: 다음 파일 생성: `.gemini/drllm-session.json`
   ```json
   {
     "topic": "<확정된 주제>",
     "goal": "<목표>",
     "prior_knowledge": "<사전 지식>",
     "phase": "planning",
     "created_at": "<ISO 8601 타임스탬프>"
   }
   ```
4. **S1 전환**: "주제가 확정되었습니다. Research Planning 단계로 진입합니다." 안내 후
   `activate_skill("drllm-research-planning")` 호출

## 완료 조건

- `.gemini/drllm-session.json` 파일 생성됨
- 주제, 목표, 사전 지식이 명확히 기록됨
- S1 스킬 활성화 요청됨

## 금지 사항

- 주제 확정 전 검색/조사 절대 금지
- 여러 질문 동시 제출 금지 (한 번에 하나)
- S2, S3, S4 직접 호출 금지
```

#### S1 — Research Planning

`.gemini/skills/drllm-research-planning/SKILL.md`:

```yaml
---
name: drllm-research-planning
description: >
  Use after DRLLM Launcher (S0) completes and a topic is confirmed. Creates a
  structured research plan specifying which sources to search, what to look for,
  and in what order. Do NOT use this skill directly — it is called by S0.
  Applies when: topic is confirmed in drllm-session.json, phase is "planning".
---
```

```markdown
# DRLLM Research Planning — S1

주제에 대한 체계적인 리서치 계획을 수립하는 스킬입니다.
`.gemini/drllm-session.json`의 주제를 기반으로 어떤 출처에서 무엇을 찾을지 계획합니다.

<HARD-GATE>
이 스킬이 완료되기 전까지 실제 검색(web_search, MCP 도구 등)을 절대 실행하지 마세요.
계획 수립이 먼저이고, 실행은 S2의 역할입니다.
</HARD-GATE>

## Plan Mode 진입

Plan Mode를 사용하여 read-only 환경에서 계획을 수립합니다:
`enter_plan_mode()` 호출 후 계획 수립, `exit_plan_mode()` 호출 후 파일 저장.

## 체크리스트

1. **세션 파일 확인**: `.gemini/drllm-session.json` 읽기
2. **출처 매핑**: 주제 특성에 맞는 출처 유형 선택
   - 학술 논문 (ArXiv, Semantic Scholar): 이론/최신 연구
   - GitHub Issues/PR: 실무 문제/해결책
   - 공식 문서: API/라이브러리 레퍼런스
   - StackOverflow/Reddit: 커뮤니티 지식
   - BYOC: 사용자 제공 자료 (최우선)
3. **검색 쿼리 설계**: 출처별 2~3개 핵심 쿼리 작성
4. **우선순위 결정**: 어떤 출처를 먼저, 어떤 키워드로 탐색할지
5. **계획 파일 저장**: `.gemini/drllm-research-plan.md` 생성 (필수 섹션 포함)
6. **세션 상태 업데이트**: `phase: "execution"` 으로 변경
7. **S2 전환**: `activate_skill("drllm-research-execution")` 호출

## 계획 파일 필수 섹션

`.gemini/drllm-research-plan.md` 는 다음 섹션을 반드시 포함해야 합니다:

```markdown
## Research Objectives
[무엇을 알아야 하는가]

## Search Strategy
[출처별 접근 순서와 이유]

## Source Types
[사용할 MCP/도구 목록과 각 목적]

## Key Queries
[출처별 검색 쿼리]
```

## 완료 조건

Hard Gate 검증 대상:
- `.gemini/drllm-research-plan.md` 파일 존재
- `## Research Objectives`, `## Search Strategy`, `## Source Types` 섹션 모두 포함
- `.gemini/drllm-session.json`의 `phase`가 "execution"으로 업데이트됨
```

#### S2 — Research Execution

`.gemini/skills/drllm-research-execution/SKILL.md`:

```yaml
---
name: drllm-research-execution
description: >
  Use after Research Planning (S1) completes. Executes the research plan by
  searching actual sources, retrieving real information, and labeling all sources.
  NEVER fabricate URLs or citations — only use actual tool responses.
  Applies when: drllm-research-plan.md exists, phase is "execution".
---
```

```markdown
# DRLLM Research Execution — S2

계획된 리서치를 실행하고, 실제 검색 결과만을 기반으로 정보를 수집합니다.

<HARD-GATE>
도구가 반환하지 않은 URL, 논문, 저자, 날짜를 절대 생성하지 마세요.
모든 사실 주장은 도구 응답에서 직접 인용되어야 합니다.
출처 없는 정보는 결과물에 포함하지 마세요.
</HARD-GATE>

## 출처 라벨링 규칙

모든 발견 사항은 다음 형식으로 라벨링:
- `[ARXIV:2024.12345]` — ArXiv 논문
- `[GITHUB:owner/repo#123]` — GitHub Issue/PR
- `[DOCS:url]` — 공식 문서
- `[SO:question-id]` — StackOverflow
- `[BYOC:filename#section]` — 사용자 제공 자료

## 체크리스트

1. **계획 파일 확인**: `.gemini/drllm-research-plan.md` 읽기
2. **BYOC 우선 처리**: 사용자 제공 자료가 있으면 먼저 처리
3. **계획 순서대로 검색**: 각 출처 유형을 계획 파일의 순서에 따라 검색
4. **도구 응답만 기록**: 각 검색 결과를 원문 그대로 기록 (요약 시 출처 명시)
5. **환각 URL 검증**: 도구가 반환한 URL만 사용, 추측 URL 절대 금지
6. **결과 파일 저장**: `.gemini/drllm-research-results.md` 생성
7. **커버리지 체크**: 모든 Research Objectives가 다뤄졌는지 확인
8. **S3 전환**: `activate_skill("drllm-learnlm-synthesis")` 호출

## 사용 도구 제한

이 스킬 실행 중에는 다음 도구만 사용:
- `web_search`, `web_fetch` — 웹 검색/페이지 읽기
- MCP 도구 (계획 파일에 명시된 것만)
- `read_file`, `write_file` — 결과 기록
- `write_todos` — 진행 상황 추적

쉘 명령(`run_shell_command`) 최소화, 파일 시스템 수정 금지.

## 완료 조건

- `.gemini/drllm-research-results.md` 존재
- 모든 항목에 출처 라벨 첨부
- Research Objectives 커버리지 100% (또는 미커버 항목 명시)
```

#### S3 — LearnLM Prompt Synthesis

`.gemini/skills/drllm-learnlm-synthesis/SKILL.md`:

```yaml
---
name: drllm-learnlm-synthesis
description: >
  Use after Research Execution (S2) completes. Transforms raw research results
  into a structured LearnLM-style teaching prompt. Creates adaptive learning
  content based on the learner's prior knowledge and goals.
  Applies when: drllm-research-results.md exists, phase is "synthesis".
---
```

```markdown
# DRLLM LearnLM Prompt Synthesis — S3

리서치 결과를 학습자 맞춤형 교수 전략으로 변환합니다.
LearnLM의 교육학적 원칙(인출 기반 학습, 간격 반복, 메타인지)을 적용합니다.

<HARD-GATE>
리서치 결과 없이 학습 컨텐츠를 생성하지 마세요.
모든 학습 내용은 S2에서 수집된 실제 출처 기반이어야 합니다.
</HARD-GATE>

## 교수 설계 원칙

1. **인출 기반 (Retrieval Practice)**: 설명 후 즉시 회상 질문
2. **간격 효과 (Spacing)**: 핵심 개념을 다른 맥락에서 재등장
3. **정교 질문 (Elaboration)**: "왜?", "어떻게?"로 연결 이해 촉진
4. **메타인지 (Metacognition)**: 학습자 스스로 이해도 평가

## 체크리스트

1. **세션 파일 확인**: 주제, 목표, 사전 지식 수준 확인
2. **리서치 결과 읽기**: `.gemini/drllm-research-results.md` 전체 분석
3. **학습 구조 설계**: 핵심 개념 → 지원 개념 → 응용 순서 결정
4. **레벨 조정**: 사전 지식 수준에 맞는 설명 깊이 설정
5. **LearnLM 프롬프트 생성**: `.gemini/drllm-learnlm-prompt.md` 저장
   - System persona: 교수자 역할 정의
   - Teaching sequence: 개념 도입 순서
   - Retrieval questions: 각 개념 후 검증 질문
   - Metacognition checks: P5 체크포인트
6. **세션 상태 업데이트**: `phase: "tutoring"` 으로 변경
7. **S4 전환**: `activate_skill("drllm-adaptive-tutoring")` 호출

## 출력 파일 구조

`.gemini/drllm-learnlm-prompt.md`:
```markdown
## Teaching Persona
[교수자 역할 및 스타일]

## Learning Objectives
[이 세션에서 달성할 구체적 목표]

## Concept Sequence
[개념 도입 순서와 각 개념의 핵심 설명]

## Retrieval Questions
[각 개념별 인출 연습 질문]

## P5 Metacognition Checkpoints
[이해도 자가 평가 시점과 방법]
```
```

#### S4 — Adaptive Tutoring

`.gemini/skills/drllm-adaptive-tutoring/SKILL.md`:

```yaml
---
name: drllm-adaptive-tutoring
description: >
  Use after LearnLM Synthesis (S3) completes. Conducts the actual learning
  dialogue with the user using retrieval-based practice and P5 metacognition
  tracking. Adapts difficulty based on user responses.
  Applies when: drllm-learnlm-prompt.md exists, phase is "tutoring".
---
```

```markdown
# DRLLM Adaptive Tutoring — S4

실제 학습 대화를 진행하는 스킬입니다. P5 인출 기반 검증과 메타인지 추적을 사용합니다.

<HARD-GATE>
학습자가 이해했다고 주장하더라도, P5 메타인지 체크포인트를 건너뛰지 마세요.
인출 질문 없이 다음 개념으로 진행하지 마세요.
</HARD-GATE>

## P5 메타인지 체크 절차

각 주요 개념 후:
1. **인출 질문 제시**: 개방형 질문으로 이해도 확인
2. **응답 평가**: 정확도, 깊이, 오개념 감지
3. **피드백**: 틀린 경우 힌트 제공 (답 직접 주지 않음)
4. **자기 평가 요청**: "이 개념을 0~10으로 자가 평가하면?"
5. **적응**: 자가 평가와 실제 응답 일치 여부 기반 다음 질문 난이도 조정

## 세션 추적

각 턴 후 `save_memory`로 진행 상황 저장:
```json
{
  "topic": "...",
  "concepts_covered": ["concept1", "concept2"],
  "p5_scores": {"concept1": 8, "concept2": 5},
  "misconceptions": ["..."],
  "session_date": "..."
}
```

## 체크리스트 (각 개념에 적용)

1. **개념 도입**: 리서치 기반 설명 제공 (출처 라벨 포함)
2. **예시 제시**: 구체적 예시 1~2개
3. **인출 질문**: 설명 후 즉시 인출 질문 1개
4. **응답 처리**: 평가 + 피드백
5. **P5 체크**: 자가 평가 요청 + 기록
6. **다음 개념**: P5 체크 완료 후에만 진행

## 세션 종료 조건

- 모든 핵심 개념 커버 완료 AND
- 각 개념 P5 점수 ≥ 7 OR 학습자가 종료 요청

세션 종료 시 `save_memory`로 전체 진행 상황 저장.
```

---

### 6. 본체 Capability 매트릭스 (Phase 1 대비 정밀화)

| 기능 | Phase 1 평가 | Phase 2 정밀화 | 변경 사항 |
|------|-------------|---------------|----------|
| **Skills 시스템** | "즉시 활용 가능" | frontmatter: `name` + `description` 2개 필드만 (공식 확인). activate_skill에 **사용자 consent 필요** — headless/yolo 모드에서 Policy Engine으로 auto-approve 설정 필요 | Consent 요건 명확화 |
| **AfterTool tailToolCallRequest** | "스킬 체인 핵심 후보" | **LLM 없이 도구-to-도구 직접 체인 가능** (검증됨). 꼬리 호출 결과가 원본 대체. original_request_name으로 체인 추적 가능 | 동작 방식 확인, "LLM 경유 없음" 확정 |
| **AfterAgent hard gate** | "stop_hook_active 활용 필요" | `stop_hook_active` 입력 필드 공식 확인. `clearContext: true` 옵션 추가 발견 (LLM 히스토리 초기화). `decision: "block"` = `"deny"` alias | clearContext 옵션 신규 발견 |
| **Policy Engine** | "subagent-specific 정책 가능" | `subagent` 필드로 특정 subagent 호출 시만 적용하는 규칙 가능. `deny` 결정 시 도구가 모델 메모리에서 완전 삭제 (단순 차단보다 강력) | 도구 메모리 삭제 동작 명확화 |
| **Subagent 재귀 방지** | "재귀 불가" | `*` 와일드카드 포함해도 다른 subagent 불가시 — tools 설정과 무관한 시스템 레벨 강제 확인 | 정확한 조건 확인 |
| **Subagent MCP 격리** | "독립 MCP 서버 지정 가능" | 공식 확인. `mcpServers` 객체를 frontmatter에 직접 정의 → 해당 subagent 격리 범위 | 공식 문서 확인 |
| **Remote subagent** | "A2A 지원" | **멀티 remote subagent 단일 파일 정의** 지원 (remote 전용). inline `agent_card_json`으로 엔드포인트 없이도 정의 가능 | 멀티 정의 + inline JSON 신규 발견 |
| **Skills 3계층 충돌** | "3계층 우선순위" | `.agents/skills/` > `.gemini/skills/` (동일 계층 내). cross-tier: Workspace > User > Extension | 동일 계층 내 alias 우선순위 명확화 |
| **BeforeToolSelection** | "허용 도구 화이트리스트" | 여러 hooks의 화이트리스트는 **합집합(union)**으로 합산. `"NONE"` 모드만 다른 hooks를 override하여 전체 차단 | Union 전략 명확화 |
| **Skill creator 내장** | 미발견 | **`skill-creator` 내장 스킬** 발견 — "create a new skill" 요청으로 자동 생성 가능 | 신규 발견 |

---

## SP-1 / SP-2 직접 영향

### SP-1 (Skill 시스템 설계) 직접 영향

1. **5스킬 SKILL.md skeleton 준비 완료**: S0~S4 각각의 frontmatter + 본문 구조 확정. SP-1에서 이 skeleton을 그대로 정제하여 사용 가능.

2. **스킬 체인 구현 패턴 확정**:
   - 기본 체인: 각 SKILL.md 마지막에 `activate_skill("다음 스킬")` 호출 지시 (LLM 의존)
   - 강화 체인: AfterTool hook의 `tailToolCallRequest` → 특정 도구 완료 시 다음 스킬 activate_skill 자동 호출 (LLM 불필요)
   - 두 패턴을 레이어로 결합 시 가장 강력한 체인 구현 가능

3. **Hard Gate 구현 방식 확정**:
   - Policy Engine (도구 레벨) + AfterAgent Hook (응답 레벨) 이중 레이어
   - `stop_hook_active` 무한 루프 방지 내장 활용
   - 파일 존재/내용 검증 패턴으로 실질적 게이팅 가능

4. **Subagent 설계 방향**: S1, S2 각각 독립 subagent로 분리 → 각자의 MCP 서버 격리 + Policy Engine으로 도구 범위 제한. 메인 에이전트가 순차 호출하는 구조.

5. **Consent 처리**: activate_skill은 사용자 승인 필요 → DRLLM을 headless/자동화 모드로 실행할 경우 `--approval-mode=yolo` 또는 Policy Engine으로 auto-approve 필요. **대화형 모드에서는 사용자가 각 스킬 활성화에 동의해야 함** — UX 설계에 반영 필요.

### SP-2 (출처 다양화 + BYOC) 직접 영향

1. **Subagent MCP 격리**: S2 Research Execution subagent에 ArXiv, Semantic Scholar, GitHub 등 MCP 서버를 frontmatter에서 직접 정의 → 다른 스킬에 MCP 도구 노출 방지. 검증된 도구만 사용하는 환각 방지 구조.

2. **Policy Engine MCP 제어**: `mcpName` 필드로 특정 MCP 서버의 특정 도구만 허용/차단하는 세밀한 정책 가능. S2에서 MCP 이외 도구(run_shell_command 등) 차단.

3. **BeforeToolSelection + AfterTool 조합**: MCP 도구 호출 전 화이트리스트 필터링 + 호출 후 URL 검증 → 환각 URL 2단계 방지.

---

## 변경된 권장 (Phase 1 대비)

### 신규 발견 (Phase 1 미포함)

1. **`skill-creator` 내장 스킬**: DRLLM 스킬 개발 시 "create a new skill called drllm-launcher" 명령으로 skeleton 자동 생성 가능 → SP-1 개발 속도 향상.

2. **Remote subagent 멀티 정의 + inline agent_card_json**: S3 (LearnLM)를 외부 ADK 에이전트로 분리할 경우, 단일 `.md` 파일에서 여러 remote subagent 정의 + 엔드포인트 없이 inline JSON으로 테스트 가능.

3. **AfterAgent `clearContext`**: Hard Gate deny 시 LLM 히스토리를 초기화하는 옵션. 오염된 컨텍스트로 인한 반복 실패 방지에 유용 — S1/S2 실패 후 재시작 시 적용 고려.

4. **BeforeToolSelection union 전략**: 여러 BeforeToolSelection hook의 화이트리스트가 합집합으로 합산 → 스킬별 도구 허용 목록을 분리된 hook에서 관리 가능. DRLLM 각 스킬(S1/S2/S3)별 도구 제한 정책을 독립적으로 정의 가능.

5. **Policy deny → 도구 모델 메모리 삭제**: `deny` 결정 적용 글로벌 규칙은 모델이 해당 도구의 존재를 인식하지 못하게 함. S2에서 허가된 MCP 도구만 존재하도록 "다른 모든 쓰기 도구 차단" 정책 적용 시 매우 강력한 환각 방지 효과.

### 수정된 권장

1. **Phase 1**: "AfterAgent deny+reason 우회로 스킬 체인 가능" → **수정**: AfterAgent보다 AfterTool `tailToolCallRequest`가 스킬 체인에 더 적합. AfterAgent는 Hard Gate용, tailToolCallRequest는 체인용으로 역할 분리 권장.

2. **Phase 1**: "완전 강제는 불가, LLM이 지시를 따라야 함" → **수정**: tailToolCallRequest는 LLM 경유 없이 직접 도구 체인 가능 (진정한 강제). 단, 스킬 내용 실행은 여전히 LLM 의존. "도구 실행 체인" vs "지시 준수" 두 레이어 구분 필요.

3. **신규 위험**: activate_skill의 사용자 consent 요건 — 자동화 시나리오에서 세션 흐름 끊김 위험. DRLLM이 완전 자동화를 목표로 하지 않는다면 consent가 오히려 사용자 신뢰 구축에 도움이 될 수 있음. UX 결정 필요.

---

*본 보고서는 google-gemini/gemini-cli GitHub 레포지토리 공식 문서(docs/ 폴더)를 gh API로 직접 fetch하여 작성됨. 버전: v0.37.1 stable (2026-04-09). 모든 schema 및 동작 설명은 공식 reference.md, subagents.md, skills.md, creating-skills.md, policy-engine.md 직접 인용 기반.*
