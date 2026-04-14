# Tiny DRLLM v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 3스킬(S0/S2/S4) 기반 Tiny DRLLM v0.1 Gemini CLI Extension을 구현하고, Born2beRoot 주제 3개로 M1 POC 합격 검증.

**Architecture:** Gemini CLI Extension + 3 SKILL.md + fetch MCP + AfterTool hook auto-chain + Layer 2 JSON schema 2-call 환각 방어 + learning-log.md 파일 기반 측정.

**Tech Stack:** Gemini CLI v0.37.1, `modelcontextprotocol/fetch` MCP, bash + jq + yq, bats (hook unit test), Gemini 2.5 Pro (LearnLM 내장).

**Spec:** `docs/superpowers/specs/2026-04-14-sp1-tiny-drllm-design.md`

**Total estimate:** 15~19 hours (풀타임 2~3일). Step 간 commit 7개.

**M1 합격 기준 (Task 28에서 판정):**
- 3 세션 모두 `status=done`
- Aggregate P5 score ≥ 0.70 `(correct + partial*0.5) / total_checks`
- Aggregate URL verify ≥ 0.95 `verified / total_citations`

---

## File Structure

**프로젝트 루트**: `/home/namykim/workspace/DRLLM/` (기존 git repo, `drllm-extension/` 서브디렉토리 또는 루트 직접 — Task 1에서 결정)

**생성 파일**:
```
drllm-extension/   (또는 repo 루트)
├── gemini-extension.json
├── GEMINI.md
├── README.md
├── .gitignore
├── context/
│   ├── drllm-core.md
│   └── domains/born2beroot.md
├── commands/drllm/
│   ├── launch.toml
│   ├── research.toml
│   └── tutor.toml
├── skills/
│   ├── drllm-launcher/SKILL.md
│   ├── drllm-research-execution/SKILL.md
│   └── drllm-adaptive-tutoring/SKILL.md
├── hooks/
│   └── auto-chain-skills.sh
├── tests/
│   ├── schema/test-extension.sh
│   ├── hooks/auto-chain-skills.bats
│   ├── aggregation/
│   │   ├── fixtures/sessions/
│   │   ├── expected-output.txt
│   │   └── test.sh
│   └── manual/smoke-step{1..6}.md
└── tools/
    ├── run-tests.sh
    └── aggregate-metrics.sh
```

**.drllm/sessions/** 는 런타임 생성 (gitignore).

---

## 사전 체크 (Task 0)

- [ ] **Gemini CLI v0.37.1 설치 확인**: `gemini --version` → `v0.37.1` 이상
- [ ] **jq 설치 확인**: `jq --version` → `1.6` 이상
- [ ] **yq 설치 확인**: `yq --version` → `v4.x`
- [ ] **bats 설치 확인**: `bats --version` → `1.x` (없으면 `sudo apt install bats` 또는 `brew install bats-core`)
- [ ] **uvx 설치 확인 (fetch MCP용)**: `uvx --version`. 없으면 `curl -LsSf https://astral.sh/uv/install.sh | sh`
- [ ] **fetch MCP 사용 가능 확인**: `uvx mcp-server-fetch --help` (에러 없이 도움말 표시)

---

## STEP 1 — Extension Scaffold (Task 1~4)

### Task 1: 루트 구조 결정 및 gemini-extension.json 작성

**Files:**
- Create: `/home/namykim/workspace/DRLLM/gemini-extension.json`
- Create: `/home/namykim/workspace/DRLLM/.gitignore`
- Modify (prepend): `/home/namykim/workspace/DRLLM/.gitignore`

**결정**: 루트 직접 방식 채택 — 기존 git repo가 이미 DRLLM 프로젝트 전용이므로 서브디렉토리 불필요. 이후 모든 경로는 repo 루트 기준.

- [ ] **Step 1: gemini-extension.json 작성**

Create `/home/namykim/workspace/DRLLM/gemini-extension.json`:

```json
{
  "name": "DRLLM",
  "description": "Domain-agnostic Deep Research + LearnLM tutoring framework (v0.1 Tiny)",
  "version": "0.1.0",
  "contextFileName": "GEMINI.md",
  "settings": [
    {
      "name": "DRLLM_DOMAIN_PROFILE",
      "description": "Path to domain profile markdown (relative to extension root)",
      "default": "context/domains/born2beroot.md"
    },
    {
      "name": "DRLLM_RESEARCH_MAX_SUBQUERIES",
      "description": "Max subqueries S2 decomposes a topic into",
      "default": "4"
    }
  ],
  "mcpServers": {}
}
```

(`mcpServers`는 Task 9에서 fetch 등록 시 채움)

- [ ] **Step 2: .gitignore 업데이트**

Append to `/home/namykim/workspace/DRLLM/.gitignore`:

```
# DRLLM runtime state
.drllm/
```

- [ ] **Step 3: JSON validity 확인**

Run: `jq empty gemini-extension.json && echo OK`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add gemini-extension.json .gitignore
git commit -m "feat: DRLLM v0.1 extension manifest"
```

---

### Task 2: GEMINI.md + context/drllm-core.md

**Files:**
- Create: `GEMINI.md`
- Create: `context/drllm-core.md`

- [ ] **Step 1: GEMINI.md (stub) 작성**

Create `GEMINI.md`:

```markdown
# DRLLM v0.1

Domain-agnostic Deep Research + LearnLM tutoring framework.

@./context/drllm-core.md
```

- [ ] **Step 2: context/drllm-core.md 작성 (v2 Robust)**

> ⚠️ **Authoritative source**: `/home/namykim/workspace/DRLLM/context/drllm-core.md` (git HEAD).
> 본 plan 의 초기 literal block은 v2 로 대체되었음 (commit `91e8277`, 2026-04-14).
> Task 2 를 (재)실행하는 구현자는 본 plan 블록이 아닌 **HEAD 의 파일 내용** 을 사용한다.

v2 주요 변경사항 요약(검증용):

- **§0 Robust Design Principles** (신설, 7 원칙): LLM 판단 최소화 / Evidence-first / No silent drop / Strict schema / Fail loud / Explicit state transitions / Contracts in drllm-core.md
- **§1.1 `current_session_id` 발견 계약** (신설): 인자 → `.drllm/sessions/LATEST` → mtime 기반 status 필터링 → 에러. S0/S2/S4 각자 동작 명시.
- **§3 P5 Structural Trigger**: LLM 판단 제거. T1(새 용어 ≥2) / T2(key-point 경계 전환) / T3(간격 초과) / T4(사용자 명시 요청) 4 조건.
- **§3 P5.3 Rubric**: `%` 제거. key_point 용어 과반 + 논리 정합 기준으로 correct/partial/incorrect/skip 판정.
- **§3 P5.4 Skip 패턴**: 정규식 `^(?i)(넘어가|다음|pass|skip|나중에|됐어|건너뛰|그냥 계속)` + semantic 회피 reason 인용 기록 의무.
- **§4.1 Quote Normalization**: `[\s\u00A0\t\n\r]+ → 단일 space`, strip, case-sensitive, min 15자.
- **§5 Schemas**: metadata.json / research-results.md / learning-log.md strict schema. learning-log 이벤트 6종 (SUBTOPIC / SOURCE / P5_CHECK / P5_SKIP / **P5_MISSING 신규** / COMPLETE).
- **§6 HARD STOPS 6개로 확장**: P5_MISSING 미기록 = 세션 측정 무효.
- **§7 재실행·복구 원칙** (신설).

- [ ] **Step 3: @import resolution 확인**

Run: `cat GEMINI.md | grep '@./' && ls context/drllm-core.md`
Expected: `@./context/drllm-core.md` line 출력 + 파일 존재

- [ ] **Step 4: Commit**

```bash
git add GEMINI.md context/drllm-core.md
git commit -m "feat: GEMINI.md + drllm-core (P5 강제 + file resolution)"
```

---

### Task 3: Born2beRoot domain profile

**Files:**
- Create: `context/domains/born2beroot.md`

- [ ] **Step 1: Born2beRoot 프로파일 작성**

Create `context/domains/born2beroot.md`:

> ⚠️ **Authoritative source**: `/home/namykim/workspace/DRLLM/context/domains/born2beroot.md` (git HEAD).
> 초기 literal은 Task 3 code-quality reviewer에서 Critical 이슈(버전 모호 URL + PHP-FPM mislabel) 발견되어 수정됨. 재실행 구현자는 본 plan이 아닌 **HEAD 파일** 사용.

주요 수정사항:

- **URL version-pin**: `releases/stable/` → `releases/bookworm/` (파일 자체의 "버전 모호 금지" 원칙 준수)
- **MySQL URL 보강**: `innodb-parameters.html` + `innodb-buffer-pool-resize.html` 추가 (axioms fact-check 가능하게)
- **PHP manual URL**: `/manual/en/` → `/manual/en/ini.core.php` (memory_limit default fact 실재 페이지)
- **lighttpd URL**: wiki 루트 → `/wiki/TutorialConfiguration` (1.4 버전 pinned)
- **PHP-FPM relabel**: "default: 5" → "(Debian 12 www.conf 예시값; PHP-FPM 자체 default 없음 — mandatory)"
- **RAM floor**: 2.2GB → 2.7GB (arithmetic 보정: 1.0 + 0.86 + 0.64 + 0.2 = 2.7)
- **Axioms 각 항목에 source 파일 annotation** 추가

- [ ] **Step 2: Commit**

```bash
git add context/domains/born2beroot.md
git commit -m "feat: Born2beRoot domain profile"
```

---

### Task 4: L1 Schema 자동 테스트

**Files:**
- Create: `tests/schema/test-extension.sh`
- Create: `tools/run-tests.sh`

- [ ] **Step 1: Schema test script 작성**

> ⚠️ **Authoritative source**: `/home/namykim/workspace/DRLLM/tests/schema/test-extension.sh` (git HEAD). 초기 literal 은 Task 4 code-review 에서 2 Important 발견되어 수정됨(I1 regex anchoring, I2 yq mikefarah guard). 재실행 구현자는 HEAD 파일 사용.

Create `tests/schema/test-extension.sh`:

```bash
#!/usr/bin/env bash
# L1 Schema validation — gemini-extension.json + SKILL.md frontmatter
set -euo pipefail

fail() { echo "FAIL: $1" >&2; exit 1; }

# Require mikefarah yq v4 (apt yq = kislyuk python-yq wrapper, 문법 incompatible)
if ! yq --version 2>&1 | grep -qi 'mikefarah'; then
  fail "yq mikefarah v4 required (found: $(yq --version 2>&1 || echo none)). Install: sudo snap install yq"
fi

# gemini-extension.json
jq -e '.name and .description and .version and .contextFileName' \
  gemini-extension.json > /dev/null \
  || fail "gemini-extension.json missing required fields"

# GEMINI.md must @import drllm-core — exact line or followed by space/tab only
grep -Eq '^@\./context/drllm-core\.md([[:space:]]|$)' GEMINI.md \
  || fail "GEMINI.md must @import context/drllm-core.md"

# drllm-core.md exists
[ -f context/drllm-core.md ] \
  || fail "context/drllm-core.md missing"

# Domain profile exists
[ -f context/domains/born2beroot.md ] \
  || fail "context/domains/born2beroot.md missing"

# SKILL.md frontmatter check (only if skills/ exists with content)
if [ -d skills ] && [ "$(ls -A skills 2>/dev/null)" ]; then
  for skill in skills/*/SKILL.md; do
    [ -f "$skill" ] || continue
    # Extract frontmatter between first two '---' lines
    front=$(awk '/^---$/{c++; if (c==2) exit; next} c==1' "$skill")
    echo "$front" | yq -e '.name and .description' > /dev/null \
      || fail "$skill frontmatter missing name or description"
  done
fi

echo "L1 schema: PASS"
```

- [ ] **Step 2: 실행 권한 + 테스트**

Run:
```bash
chmod +x tests/schema/test-extension.sh
./tests/schema/test-extension.sh
```
Expected: `L1 schema: PASS`

- [ ] **Step 3: run-tests.sh entry point 작성**

Create `tools/run-tests.sh`:

```bash
#!/usr/bin/env bash
# DRLLM v0.1 test runner entry point
set -euo pipefail

echo "=== L1 Schema ==="
./tests/schema/test-extension.sh

if command -v bats >/dev/null 2>&1 && [ -d tests/hooks ] && ls tests/hooks/*.bats >/dev/null 2>&1; then
  echo "=== L2 Hooks (bats) ==="
  bats tests/hooks/
else
  echo "=== L2 Hooks: SKIP (bats not installed or no tests yet) ==="
fi

if [ -f tests/aggregation/test.sh ]; then
  echo "=== L3 Aggregation ==="
  ./tests/aggregation/test.sh
else
  echo "=== L3 Aggregation: SKIP (not yet implemented) ==="
fi

echo ""
echo "Automated tests: PASS"
echo "Manual smoke: see tests/manual/smoke-step*.md"
```

- [ ] **Step 4: run-tests.sh 실행**

Run:
```bash
chmod +x tools/run-tests.sh
./tools/run-tests.sh
```
Expected: `L1 schema: PASS` + `Automated tests: PASS`

- [ ] **Step 5: Commit — step 1 마일스톤**

```bash
git add tests/schema/test-extension.sh tools/run-tests.sh
git commit -m "feat: DRLLM v0.1 extension skeleton"
```

(Commit Point 1 per spec §7.2)

---

## STEP 2 — 3 Skills + 3 Commands Skeleton (Task 5~8)

### Task 5: S0 drllm-launcher SKILL.md + launch.toml

**Files:**
- Create: `skills/drllm-launcher/SKILL.md`
- Create: `commands/drllm/launch.toml`

- [ ] **Step 1: SKILL.md 작성 (frontmatter 영어, 본문 한국어)**

Create `skills/drllm-launcher/SKILL.md`:

```markdown
---
name: drllm-launcher
description: DRLLM session entry point. Parses user topic, generates session slug via LLM, initializes .drllm/sessions/ directory, and chains to research-execution. TRIGGER when user invokes `/drllm:launch <topic>` or says "DRLLM으로 ... 학습 시작" / "DRLLM으로 ...에 대해 공부하자" in Korean or equivalent in English.
---

# S0 — DRLLM Launcher

## Mission (한국어)

사용자가 제공한 주제로 DRLLM 학습 세션을 시작한다. 세션 디렉토리 초기화 + 메타데이터 기록 + 다음 스킬(`drllm-research-execution`) 자동 체인.

## Inputs

- `topic`: 사용자가 학습하고 싶은 주제 (한 문장)
- (optional) `domain`: 도메인 프로파일 이름 (v0.1 기본 `born2beroot`)

## Protocol

1. **주제 파싱**: 사용자 입력에서 topic 추출. 주제가 없거나 공백이면 재입력 요청 후 종료.
2. **slug 생성**: topic을 kebab-case 영어 slug로 변환 (예: "InnoDB Buffer Pool 왜 128MiB?" → `innodb-buffer-pool-default-size`). 규칙:
   - 영어 20자 이내
   - 주요 명사 중심, 불용어 제거
   - 하이픈 구분
3. **세션 ID 생성**: `$(date +%Y%m%d)-<slug>`. 디렉토리 존재 시 `-2`, `-3` 접미사 순환.
4. **디렉토리 생성**: `.drllm/sessions/<session_id>/`
5. **metadata.json 작성** (아래 schema):

```json
{
  "session_id": "<YYYYMMDD>-<slug>",
  "topic": "<원본 주제>",
  "slug": "<slug>",
  "domain": "born2beroot",
  "started_at": "<ISO 8601 KST>",
  "completed_at": null,
  "status": "research",
  "url_verify_total": 0,
  "url_verify_count": 0,
  "url_verify_ratio": 0.0
}
```

6. **사용자에게 세션 시작 알림** (한국어): "세션 `<session_id>` 시작. 리서치 진행..."
7. **Marker tool 호출**: `save_memory("__drllm_s0_done_<session_id>")` — AfterTool hook이 감지하여 `drllm-research-execution` 자동 활성화.

## Hard Gate

- 주제 없음 → 재입력 요청, 세션 미생성, marker tool 호출 금지
- metadata.json 작성 실패 → 사용자에게 에러 보고, marker tool 호출 금지

## Outputs

- `.drllm/sessions/<session_id>/metadata.json`
- marker tool 호출 (후속 체인 트리거)

## See Also

- `@./context/drllm-core.md` 섹션 5 (세션 상태 파일)
- Command: `/drllm:launch`
```

- [ ] **Step 2: launch.toml 작성**

Create `commands/drllm/launch.toml`:

```toml
description = "Start a DRLLM learning session for the given topic"

prompt = """
You are invoking the DRLLM Launcher (S0) skill.

User topic: {{args}}

Steps:
1. Activate the `drllm-launcher` skill using `activate_skill(skill_name="drllm-launcher")`.
2. After activation, the skill's instructions will guide you through session initialization.
3. Ensure the topic "{{args}}" is passed as the session topic.

If no topic is provided, ask the user for a topic and do not proceed.
"""
```

- [ ] **Step 3: Schema test 재실행**

Run: `./tests/schema/test-extension.sh`
Expected: `L1 schema: PASS` (이제 SKILL.md frontmatter도 검증됨)

- [ ] **Step 4: Commit**

```bash
git add skills/drllm-launcher/SKILL.md commands/drllm/launch.toml
git commit -m "feat: S0 drllm-launcher skill + launch command"
```

---

### Task 6: S2 drllm-research-execution SKILL.md + research.toml

**Files:**
- Create: `skills/drllm-research-execution/SKILL.md`
- Create: `commands/drllm/research.toml`

- [ ] **Step 1: SKILL.md 작성 (skeleton — 본문은 Task 10에서 확장)**

Create `skills/drllm-research-execution/SKILL.md`:

```markdown
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
```

- [ ] **Step 2: research.toml 작성**

Create `commands/drllm/research.toml`:

```toml
description = "Execute DRLLM research phase (S2) for the current session"

prompt = """
You are invoking the DRLLM Research Execution (S2) skill.

Session id (optional): {{args}}

Steps:
1. Activate the `drllm-research-execution` skill using `activate_skill(skill_name="drllm-research-execution")`.
2. If session_id is provided, target that session. Otherwise use the latest .drllm/sessions/ entry.
"""
```

- [ ] **Step 3: Schema test 재실행**

Run: `./tools/run-tests.sh`
Expected: `L1 schema: PASS` + `Automated tests: PASS`

- [ ] **Step 4: Commit**

```bash
git add skills/drllm-research-execution/SKILL.md commands/drllm/research.toml
git commit -m "feat: S2 drllm-research-execution skeleton + research command"
```

---

### Task 7: S4 drllm-adaptive-tutoring SKILL.md + tutor.toml

**Files:**
- Create: `skills/drllm-adaptive-tutoring/SKILL.md`
- Create: `commands/drllm/tutor.toml`

- [ ] **Step 1: SKILL.md 작성 (skeleton — 본문은 Task 14에서 확장)**

Create `skills/drllm-adaptive-tutoring/SKILL.md`:

```markdown
---
name: drllm-adaptive-tutoring
description: DRLLM tutoring phase. Loads research-results.md and starts an interactive learning dialog in Korean using LearnLM P1-P5 principles (P5 HARD enforced), detects subtopic completion, triggers metacognition retrieval check, logs events to learning-log.md. TRIGGER when drllm-research-execution marker `__drllm_s2_done_*` detected or user invokes `/drllm:tutor`.
---

# S4 — DRLLM Adaptive Tutoring

## Mission (한국어)

S2의 리서치 결과를 바탕으로 사용자와 한국어 학습 대화를 진행한다. LearnLM P1~P5 원칙 적용, 특히 **P5 메타인지 체크 강제**. 모든 대화 이벤트를 `learning-log.md`에 append-only 기록.

## Inputs

- `.drllm/sessions/<session_id>/metadata.json` (status=="tutor" 확인)
- `.drllm/sessions/<session_id>/research-results.md`
- `context/drllm-core.md` 섹션 3 (P5 강제 본문)

## Protocol (상세는 Task 14에서 확장)

1. metadata.json 로드, status=="tutor" 확인
2. research-results.md 로드
3. `learning-log.md` 초기화 (frontmatter + 빈 Events)
4. **대화 시작 (한국어)**:
   - 첫 응답: research 결과 기반 개념 소개
   - 새로운 subtopic 시작 시 `[SUBTOPIC]` 이벤트 기록
   - subtopic 완료 감지 시 (LLM 판단) → **P5 체크 강제**:
     "한 문장으로 [X]를 설명해줄 수 있어? 동료를 가르치듯."
   - 사용자 답변 평가 (correct/partial/incorrect/skip)
   - `[P5_CHECK]` 또는 `[P5_SKIP]` 이벤트 기록
5. **세션 종료** (사용자 종료 요청 또는 자연스러운 완료):
   - `[COMPLETE]` 이벤트 기록 (total_checks, correct, partial, skip, duration_sec)
   - metadata.json 갱신: `completed_at`, `status="done"`

## Hard Gate

- status != "tutor" → 에러 반환
- P5 체크 생략 절대 금지 (subtopic 완료 감지 시 반드시 발동)
- 출처 없는 주장 금지 — research-results.md의 citations만 참조

## Outputs

- `.drllm/sessions/<session_id>/learning-log.md` (append-only)
- metadata.json 갱신 (`completed_at`, `status`)

## See Also

- `@./context/drllm-core.md` 섹션 3 (LearnLM P5), 섹션 6 (HARD STOPS)
```

- [ ] **Step 2: tutor.toml 작성**

Create `commands/drllm/tutor.toml`:

```toml
description = "Start the DRLLM tutoring phase (S4) — interactive learning dialog"

prompt = """
You are invoking the DRLLM Adaptive Tutoring (S4) skill.

Session id (optional): {{args}}

Steps:
1. Activate the `drllm-adaptive-tutoring` skill using `activate_skill(skill_name="drllm-adaptive-tutoring")`.
2. If session_id provided, target that session. Otherwise use the latest .drllm/sessions/ entry with status=tutor.
3. Begin Korean-language learning dialog per P1-P5 principles, P5 strictly enforced.
"""
```

- [ ] **Step 3: Schema test 재실행**

Run: `./tools/run-tests.sh`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add skills/drllm-adaptive-tutoring/SKILL.md commands/drllm/tutor.toml
git commit -m "feat: S4 drllm-adaptive-tutoring skeleton + tutor command"
```

---

### Task 8: Step 2 Manual Smoke Test — 3 스킬 로딩 확인

**Files:**
- Create: `tests/manual/smoke-step2.md`

- [ ] **Step 1: smoke test 체크리스트 작성**

> ⚠️ **Authoritative source**: `/home/namykim/workspace/DRLLM/tests/manual/smoke-step2.md` (git HEAD). 초기 literal은 Task 8 code-review에서 Critical 1 (Gemini CLI 문법 오류 `/extensions drllm`) + Important 3 (`/extensions list` 사용, S2/S4 exact header assertion, 진단 3-rung ladder) + Minor 1 (`/drllm:` autocomplete trigger) 발견되어 수정됨. 재실행 구현자는 HEAD 파일 사용.

주요 수정사항:

- `/extensions` → `/extensions list` (실제 Gemini CLI lister subcommand)
- `/extensions drllm` (invalid syntax) 제거 → `/extensions list` 행 확인 + `~/.gemini/extensions/` symlink 존재 확인 2-rung으로 대체
- activate_skill 반환 assertion → exact header string 3종 (`S0 — DRLLM Launcher` / `S2 — DRLLM Research Execution` / `S4 — DRLLM Adaptive Tutoring`)
- `/drllm:launch` → `/drllm:` (colon trigger로 모든 subcommand autocomplete)
- 진단 섹션 "DRLLM 미표시" 를 3-rung ladder (symlink → enable → manifest schema) 로 확장
- 진단 섹션 전반에 `§0-5 Fail loud` anchor 추가

- [ ] **Step 2: 실제 manual smoke 실행**

(사용자/구현자가 직접 실행. 모든 체크박스 통과 확인)

- [ ] **Step 3: Commit — step 2 마일스톤**

```bash
git add tests/manual/smoke-step2.md
git commit -m "feat: 3 skills + 3 commands skeleton"
```

(Commit Point 2 per spec §7.2)

---

## STEP 3 — Core Logic + fetch MCP + Layer 2 (Task 9~15)

### Task 9: fetch MCP 등록 및 로컬 검증

**Files:**
- Modify: `gemini-extension.json`

- [ ] **Step 1: mcpServers에 fetch 추가**

Replace `"mcpServers": {}` in `gemini-extension.json` with:

```json
  "mcpServers": {
    "fetch": {
      "command": "uvx",
      "args": ["mcp-server-fetch"],
      "env": {
        "DEFAULT_USER_AGENT_AUTONOMOUS": "DRLLM/0.1 (+https://github.com/namykim/DRLLM)"
      }
    }
  }
```

- [ ] **Step 2: JSON validity 확인**

Run: `jq empty gemini-extension.json && jq '.mcpServers.fetch' gemini-extension.json`
Expected: 에러 없음 + fetch 설정 출력

- [ ] **Step 3: Gemini CLI에서 MCP 등록 확인**

Run inside `gemini`:
```
/mcp
```
Expected: fetch MCP가 status "connected" 표시

- [ ] **Step 4: fetch 도구 수동 호출 smoke**

Run inside `gemini`:
```
Use the fetch MCP to fetch https://dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool.html and show the first 500 chars.
```
Expected: 실제 MySQL 공식 docs 페이지 내용 일부 반환 (ghost URL 아님)

- [ ] **Step 5: Schema test 재실행 후 Commit**

```bash
./tools/run-tests.sh
git add gemini-extension.json
git commit -m "feat: register fetch MCP server"
```

---

### Task 10: S2 쿼리 분해 로직 (SKILL.md 본문 확장)

**Files:**
- Modify: `skills/drllm-research-execution/SKILL.md` — Protocol 섹션 확장

- [ ] **Step 1: SKILL.md Protocol 1~3 단계 확장**

In `skills/drllm-research-execution/SKILL.md`, replace the existing `## Protocol (상세는 Task 10~12에서 확장)` section with:

```markdown
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

(나머지 섹션 4~9는 Task 11~12에서 확장)
```

- [ ] **Step 2: Schema test 확인**

Run: `./tools/run-tests.sh`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add skills/drllm-research-execution/SKILL.md
git commit -m "feat: S2 inline query decomposition (steps 1-3)"
```

---

### Task 11: Layer 2 Call 1 (응답 생성 + schema 강제)

**Files:**
- Modify: `skills/drllm-research-execution/SKILL.md` — Protocol 4~5 추가

- [ ] **Step 1: SKILL.md에 Call 1 섹션 추가**

Append to Protocol section in `skills/drllm-research-execution/SKILL.md`:

```markdown
### 4. Layer 2 Call 1 — 응답 생성 (schema 강제)

fetch 결과들을 결합하여 다음 JSON schema로 강제 응답 생성 (Gemini `response_schema`):

```json
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
```

**시스템 프롬프트**:

> "아래 fetch 결과들에서만 `citations.url`과 `citations.quote`를 추출하라. 추측으로 URL/quote를 생성하지 말라. fetch 결과에 없는 정보는 반드시 생략하라."

Gemini response_schema 실패 시 1회 재시도, 그래도 실패 시 에러 보고 및 종료.
```

- [ ] **Step 2: Commit**

```bash
git add skills/drllm-research-execution/SKILL.md
git commit -m "feat: S2 Layer 2 Call 1 schema enforcement"
```

---

### Task 12: Layer 2 Call 2 (교차 검증 + research-results.md)

**Files:**
- Modify: `skills/drllm-research-execution/SKILL.md` — Protocol 6~9

- [ ] **Step 1: SKILL.md에 Call 2 + 후처리 섹션 추가**

Append to Protocol section:

```markdown
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

```markdown
---
session_id: <session_id>
generated_at: <ISO 8601 KST>
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
| 2 | <url> | "<quote>" | <source_type> | ❌ (제거됨) |
```

### 7. metadata.json 갱신

```json
{
  ...
  "url_verify_total": <N>,
  "url_verify_count": <M>,
  "url_verify_ratio": <M/N>,
  "status": "tutor"
}
```

### 8. 사용자에게 보고 (한국어)

> "리서치 완료. 출처 검증 비율: <M>/<N> (<ratio>). 학습 대화 시작 준비 완료."

### 9. Marker tool 호출

`save_memory("__drllm_s2_done_<session_id>")` — hook이 감지하여 S4 체인.

**Hard Gate**: `url_verify_ratio < 0.5` 인 경우 marker tool 호출 금지. research-results.md 에 "⚠️ 출처 검증률 낮음" 경고 + 사용자에게 S4 진입 계속 여부 질문.
```

- [ ] **Step 2: Schema test 재확인**

Run: `./tools/run-tests.sh`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add skills/drllm-research-execution/SKILL.md
git commit -m "feat: S2 Layer 2 Call 2 verification + research-results output"
```

---

### Task 13: S0 metadata.json 생성 로직 구체화

**Files:**
- Modify: `skills/drllm-launcher/SKILL.md`

- [ ] **Step 1: S0 Protocol 구체 지침 추가**

Replace the `## Protocol` section in `skills/drllm-launcher/SKILL.md` with:

```markdown
## Protocol

### 1. 주제 파싱

- slash command 경로: `{{args}}` 에서 주제 추출
- 자연어 경로: 사용자 메시지에서 "학습 시작 / 공부" 전후 문구에서 주제 추출
- 주제가 비어있으면 재입력 요청 후 종료 (아래 Hard Gate 참조)

### 2. slug 생성 (LLM 호출)

다음 규칙으로 topic → kebab-case 영어 slug 변환:

- 최대 영어 20자
- 주요 명사 2~3개로 축약 (예: "InnoDB Buffer Pool 왜 128MiB?" → `innodb-buffer-pool-default-size`)
- 한국어 주제면 영어로 번역 후 slug화
- 불용어(the, a, and, why, what 등) 제거
- 하이픈 구분, 소문자만

### 3. 세션 ID 생성

```bash
date_prefix=$(date +%Y%m%d)
session_id="${date_prefix}-${slug}"

# 충돌 처리
if [ -d ".drllm/sessions/${session_id}" ]; then
  for suffix in 2 3 4 5; do
    candidate="${session_id}-${suffix}"
    [ ! -d ".drllm/sessions/${candidate}" ] && session_id="${candidate}" && break
  done
fi
```

LLM은 위 로직을 shell 명령 혹은 Python으로 실행하여 최종 session_id 확정.

### 4. 디렉토리 생성

```bash
mkdir -p ".drllm/sessions/${session_id}"
```

### 5. metadata.json 작성

다음 schema 정확히 준수하여 `.drllm/sessions/${session_id}/metadata.json` 작성:

```json
{
  "session_id": "<session_id>",
  "topic": "<원본 주제, 한국어 OK>",
  "slug": "<slug>",
  "domain": "born2beroot",
  "started_at": "<ISO 8601 with KST offset, e.g. 2026-04-14T10:30:00+09:00>",
  "completed_at": null,
  "status": "research",
  "url_verify_total": 0,
  "url_verify_count": 0,
  "url_verify_ratio": 0.0
}
```

### 6. 사용자에게 알림 (한국어)

> "세션 `<session_id>` 시작. 주제: <topic>. 리서치 진행 중..."

### 7. Marker tool 호출

`save_memory("__drllm_s0_done_<session_id>")`

## Hard Gate

- 주제 없음/공백: 사용자에게 "학습하고 싶은 주제를 알려주세요 (예: 'InnoDB Buffer Pool의 기본값')" 요청 + 세션 미생성 + marker 미호출
- 디렉토리 생성 실패: stderr 에러 출력 + marker 미호출
- metadata.json 작성 실패: 방금 생성한 세션 디렉토리 rm -rf 후 에러 보고
```

- [ ] **Step 2: Schema test 재확인 후 Commit**

```bash
./tools/run-tests.sh
git add skills/drllm-launcher/SKILL.md
git commit -m "feat: S0 concrete metadata + slug generation"
```

---

### Task 14: S4 대화 + P5 체크 본문 구체화

**Files:**
- Modify: `skills/drllm-adaptive-tutoring/SKILL.md`

- [ ] **Step 1: S4 Protocol 구체 지침 추가**

Replace the `## Protocol (상세는 Task 14에서 확장)` section in `skills/drllm-adaptive-tutoring/SKILL.md` with:

```markdown
## Protocol

### 1. 세션 로드

- `session_id`는 호출 컨텍스트에서 주어진 값, 없으면 `.drllm/sessions/` 에서 `status=="tutor"` 인 가장 최근 항목 선택
- `metadata.json` 로드. `status != "tutor"` → 에러 ("S4는 tutor 상태 세션만 실행")
- `research-results.md` 로드 (필수, 없으면 에러)
- `context/drllm-core.md` 섹션 3 (P5) 재확인 — HARD 원칙 적용

### 2. learning-log.md 초기화

파일이 없으면 frontmatter와 빈 Events 섹션으로 생성:

```markdown
---
topic: <metadata.topic>
session_id: <session_id>
started_at: <metadata.started_at>
completed_at:
status: in_progress
---

## Events

```

### 3. 학습 대화 진행 (한국어)

#### 3.1 오프닝

- research-results.md의 Summary + Key Points를 바탕으로 주제의 **가장 근본적인 개념 하나** 소개 (P2 Manage Cognitive Load)
- 끝에 능동적 질문 1개 (P1 Inspire Active Learning):
  > "여기서 <X>가 0이면 무슨 일이 일어날까?" 같은 thought-experiment

#### 3.2 Subtopic 관리

- 새 subtopic 도입 시 **반드시** learning-log.md 에 다음 이벤트 append:

  ```
  [SUBTOPIC] <subtopic 이름> | <ISO 8601 KST>
  ```

- subtopic 경계 판단 기준:
  - 새 용어가 2개 이상 등장
  - research-results.md의 key_points 중 다른 항목으로 이동
  - 사용자의 질문이 이전 subtopic 범위를 벗어남

#### 3.3 Source 참조 기록

- research-results.md의 citation을 근거로 사용할 때마다 learning-log.md에 append:

  ```
  [SOURCE] fetch::<url> | verified=true
  ```

- 이미 검증된(verified=true) citations만 인용. verified=false는 인용 금지.

#### 3.4 P5 메타인지 체크 (HARD 강제) — v2 Robust

> **Authoritative contract**: `context/drllm-core.md` §3 (P5.1 trigger / P5.2 prompt / P5.3 rubric / P5.4 skip) + §5.3 (learning-log 이벤트 schema) + §6 (HARD STOPS).
> 아래는 S4 구현자가 컨텍스트 전환 없이 따라갈 수 있도록 *참조용 요약*. 해석이 충돌하면 **drllm-core.md 가 authoritative**.

**매 S4 turn 시작 시 (§3 P5.1)**: T1~T4 조건 4개를 learning-log.md + research-results.md 기반 단순 카운트로 평가. **LLM 판단 금지**.

- **T1** — 직전 턴 응답에서 "key_points 용어 중 세션 첫 등장" term 수 ≥ 2
- **T2** — 이번 턴 주제 key_points 인덱스 ≠ 직전 턴 인덱스
- **T3** — 직전 `[P5_CHECK]` 또는 `[P5_MISSING]` 이후 `[SUBTOPIC]` 이벤트 ≥ 2개
- **T4** — 사용자 입력이 `^(이해했어|확인해줘|맞아\?|체크해)` 매치

**하나라도 참 → P5 발동**. 모두 거짓 → P5 불필요(정상).
**하나 이상 참인데 발동 안 함 → `[P5_MISSING] triggers=<매치된 T> | reason="<왜>"` 이벤트 기록 필수** (§0-3, §6-1).

P5 prompt 문자열 (§3 P5.2, 변형 금지):

> "한 문장으로 [X]를 설명해줄 수 있어? 동료를 가르치듯."

`[X]` = research-results.md key_points 중 현재 대상 항목 이름.

평가 rubric (§3 P5.3, **% 금지**):

- **correct** — (a) 해당 key_point 핵심 용어의 **과반(≥ 50%)** 을 사용자 답변에 포함 **AND** (b) 해당 key_point 논리와 모순 없음
- **partial** — (a) 또는 (b) 중 하나만 충족
- **incorrect** — (a)와 (b) 모두 미충족
- **skip** — 사용자 입력이 `^(?i)(넘어가|다음|pass|skip|나중에|됐어|건너뛰|그냥 계속)` 매치, 또는 명확한 회피 의사 (reason 필드에 사용자 문장 인용 기록)

learning-log.md append (§5.3 이벤트 schema 준수):

```
[P5_CHECK] Q="<질문>" | A="<사용자 답변>" | score=<correct|partial|incorrect>
[P5_SKIP] reason="<사용자 문장 인용>"
[P5_MISSING] triggers=T1,T3 | reason="<왜 발동 안 했는지>"
```

평가별 후속 처리 (P3 Adapt to the Learner):

- correct → "맞아요. 그럼 다음 subtopic으로..."
- partial → "거의 맞아요. 다만 <구체적 수정>..."
- incorrect → "한 번 더 설명할게요. <재설명>" (재설명 후 재체크)
- skip → 학습 계속, `[P5_SKIP]` 기록
- missing (구현자가 발동 실패) → 직전 턴 응답 종료 직전에 `[P5_MISSING]` append + 이번 턴에서 즉시 P5 재발동 시도

### 4. 세션 종료

다음 조건 중 하나 발생 시 종료:

- 사용자가 명시적 종료 요청 ("끝내자", "여기까지", "다음에")
- research-results.md의 모든 key_points가 최소 1회 P5_CHECK 통과
- 사용자 비활성 30분 (v0.1에서는 timeout 감지 없음, v0.5+)

종료 절차:

1. learning-log.md append:

   ```
   [COMPLETE] total_checks=<N> correct=<C> partial=<P> skip=<S> missing=<M> duration_sec=<D>
   ```

2. metadata.json 갱신:

   ```json
   {
     "completed_at": "<ISO 8601 KST>",
     "status": "done"
   }
   ```

3. 사용자에게 요약 (한국어):

   > "학습 완료. 인출 체크 <N>회 중 <C> correct + <P> partial. 수고하셨어요."

## Hard Gate

- status != "tutor" → 에러 반환
- research-results.md 부재 → 에러 반환 (S2 재실행 안내)
- P5 체크 발동 시점 도달했는데 생략 → **절대 금지**. 생략하면 측정 지표 무효.
- verified=false citation 인용 → **절대 금지**
```

- [ ] **Step 2: Schema test 재확인 후 Commit**

```bash
./tools/run-tests.sh
git add skills/drllm-adaptive-tutoring/SKILL.md
git commit -m "feat: S4 dialog + P5 enforcement (concrete)"
```

---

### Task 15: Step 3 Manual Smoke — InnoDB end-to-end (수동 체인)

**Files:**
- Create: `tests/manual/smoke-step3.md`

- [ ] **Step 1: smoke 체크리스트 작성**

Create `tests/manual/smoke-step3.md`:

```markdown
# Step 3 Smoke Test — InnoDB end-to-end (수동 체인, hook 없음)

## Setup

```bash
cd /home/namykim/workspace/DRLLM
gemini extensions link .
rm -rf .drllm/sessions/  # 깨끗한 상태
```

## Scenario: InnoDB Buffer Pool 왜 128MiB?

### 단계 A — S0 수동 호출

- [ ] Gemini 진입 후: `activate_skill("drllm-launcher")`
- [ ] 주제 입력: "InnoDB Buffer Pool 왜 128MiB?"
- [ ] 세션 디렉토리 생성 확인:
  ```bash
  ls .drllm/sessions/
  # 예: 20260414-innodb-buffer-pool-default-size/
  ```
- [ ] metadata.json 검증:
  ```bash
  jq '.' .drllm/sessions/*/metadata.json
  # status=="research", slug, started_at 필드 확인
  ```

### 단계 B — S2 수동 호출

- [ ] `activate_skill("drllm-research-execution")`
- [ ] S2가 주제 로드, 2~4 서브쿼리 분해 확인 (LLM 출력에 서브쿼리 표시)
- [ ] fetch MCP 호출 확인 (Gemini 출력에 tool_use 로그)
- [ ] Layer 2 Call 1 → JSON 응답 확인
- [ ] Layer 2 Call 2 → verified 필드 확인
- [ ] research-results.md 생성 확인:
  ```bash
  cat .drllm/sessions/*/research-results.md
  # Summary, Key Points, Citations 테이블 존재
  # verified 컬럼 확인
  ```
- [ ] metadata.json 갱신 확인:
  ```bash
  jq '.status, .url_verify_ratio' .drllm/sessions/*/metadata.json
  # status=="tutor", ratio >= 0.0
  ```

### 단계 C — S4 수동 호출

- [ ] `activate_skill("drllm-adaptive-tutoring")`
- [ ] 첫 응답이 한국어로 개념 소개 (Buffer Pool 정의)
- [ ] thought-experiment 질문 포함 (P1)
- [ ] 사용자로서 답변 제공 (예: "MySQL이 메모리에 데이터를 캐시하는 영역")
- [ ] subtopic 완료 감지 후 P5 체크 발동 확인
- [ ] 답변 후 correct/partial 평가 표시
- [ ] learning-log.md 확인 (아직 기록 안 됨 — Task 20 이후부터 자동화)

### 합격 조건

- 세 단계 모두 에러 없이 완료
- research-results.md 생성됨
- Citations 중 최소 1개 verified=true
- P5 체크가 1회 이상 발동됨 (Task 14 HARD 강제)

## 실패 시 진단 (spec §7.4 Rollback Trigger 참조)

- S0 실패: metadata.json 작성 에러 → Task 13 확인
- S2 fetch 실패: MCP 연결 또는 URL 문제 → Task 9 재확인
- Layer 2 Call 1 실패: response_schema 미지원 또는 스키마 오류 → Task 11
- Call 2 모든 verified=false: fetch 결과 파싱 또는 substring match 이슈 → Task 12
- S4 P5 미발동: drllm-core.md + SKILL.md HARD 지침 재확인 → Task 2, 14
```

- [ ] **Step 2: 실제 manual smoke 실행 (구현자 수행)**

체크리스트 모든 항목 수행 후 통과 확인. 실패 시 해당 Task로 rollback.

- [ ] **Step 3: Commit — STEP 3 마일스톤 (M1 micro-POC 1차)**

```bash
git add tests/manual/smoke-step3.md
git commit -m "feat: S0/S2/S4 minimal + fetch MCP + Layer 2"
```

(Commit Point 3 per spec §7.2 — M1 micro-POC 1차 마일스톤)

---

## STEP 4 — Auto-Chain Hook (Task 16~19)

### Task 16: auto-chain-skills.sh hook 작성

**Files:**
- Create: `hooks/auto-chain-skills.sh`

- [ ] **Step 1: hook script 작성**

Create `hooks/auto-chain-skills.sh`:

```bash
#!/usr/bin/env bash
# DRLLM AfterTool hook: save_memory marker → activate_skill chain
set -euo pipefail

input=$(cat)

# Infinite loop guard
if [ "$(echo "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
    echo '{}'
    exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // ""')
tool_input=$(echo "$input" | jq -r '.tool_input | tostring')

# S0 done → S2 chain
if [ "$tool_name" = "save_memory" ] && echo "$tool_input" | grep -q '__drllm_s0_done_'; then
    echo >&2 "[drllm-hook] S0 done detected → chain to drllm-research-execution"
    cat <<'EOF'
{"hookSpecificOutput":{"tailToolCallRequest":{"name":"activate_skill","args":{"skill_name":"drllm-research-execution"}}}}
EOF
    exit 0
fi

# S2 done → S4 chain
if [ "$tool_name" = "save_memory" ] && echo "$tool_input" | grep -q '__drllm_s2_done_'; then
    echo >&2 "[drllm-hook] S2 done detected → chain to drllm-adaptive-tutoring"
    cat <<'EOF'
{"hookSpecificOutput":{"tailToolCallRequest":{"name":"activate_skill","args":{"skill_name":"drllm-adaptive-tutoring"}}}}
EOF
    exit 0
fi

# Unrelated tool: pass-through
echo '{}'
```

- [ ] **Step 2: 실행 권한 부여**

Run: `chmod +x hooks/auto-chain-skills.sh`

- [ ] **Step 3: Manual 입력으로 smoke**

Run:
```bash
echo '{"tool_name":"save_memory","tool_input":"__drllm_s0_done_20260414-test","stop_hook_active":false}' \
  | ./hooks/auto-chain-skills.sh | jq .
```
Expected: JSON output with `tailToolCallRequest.args.skill_name == "drllm-research-execution"`

- [ ] **Step 4: stop_hook_active=true 테스트**

Run:
```bash
echo '{"tool_name":"save_memory","tool_input":"__drllm_s0_done_x","stop_hook_active":true}' \
  | ./hooks/auto-chain-skills.sh
```
Expected: `{}` (empty object — 무한 루프 방지)

- [ ] **Step 5: Commit**

```bash
git add hooks/auto-chain-skills.sh
git commit -m "feat: auto-chain-skills.sh AfterTool hook"
```

---

### Task 17: L2 Hook Unit Tests (bats)

**Files:**
- Create: `tests/hooks/auto-chain-skills.bats`

- [ ] **Step 1: bats test 작성 (failing test first)**

Create `tests/hooks/auto-chain-skills.bats`:

```bash
#!/usr/bin/env bats

setup() {
  HOOK="./hooks/auto-chain-skills.sh"
}

@test "S0 완료 → S2 체인" {
  run bash -c 'echo "{\"tool_name\":\"save_memory\",\"tool_input\":\"__drllm_s0_done_xxx\",\"stop_hook_active\":false}" | '"$HOOK"
  [ "$status" -eq 0 ]
  # bats 1.x `run` merges stderr into $output; hook emits stderr log before JSON.
  # tail -1 extracts the JSON line (last line) for jq parsing.
  skill=$(echo "$output" | tail -1 | jq -r '.hookSpecificOutput.tailToolCallRequest.args.skill_name')
  [ "$skill" = "drllm-research-execution" ]
}

@test "S2 완료 → S4 체인" {
  run bash -c 'echo "{\"tool_name\":\"save_memory\",\"tool_input\":\"__drllm_s2_done_xxx\",\"stop_hook_active\":false}" | '"$HOOK"
  [ "$status" -eq 0 ]
  skill=$(echo "$output" | tail -1 | jq -r '.hookSpecificOutput.tailToolCallRequest.args.skill_name')
  [ "$skill" = "drllm-adaptive-tutoring" ]
}

@test "stop_hook_active=true → 조용히 통과" {
  run bash -c 'echo "{\"tool_name\":\"save_memory\",\"tool_input\":\"__drllm_s0_done_xxx\",\"stop_hook_active\":true}" | '"$HOOK"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "관련 없는 tool → 조용히 통과" {
  run bash -c 'echo "{\"tool_name\":\"read_file\",\"tool_input\":\"foo.txt\",\"stop_hook_active\":false}" | '"$HOOK"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "save_memory지만 drllm marker 아님 → pass-through" {
  run bash -c 'echo "{\"tool_name\":\"save_memory\",\"tool_input\":\"unrelated\",\"stop_hook_active\":false}" | '"$HOOK"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}
```

- [ ] **Step 2: 테스트 실행 (초기 통과 확인 — 이미 hook 구현됨)**

Run: `bats tests/hooks/auto-chain-skills.bats`
Expected: 5 tests passed

- [ ] **Step 3: run-tests.sh 통합 확인**

Run: `./tools/run-tests.sh`
Expected: L1 schema + L2 hooks 모두 PASS

- [ ] **Step 4: Commit**

```bash
git add tests/hooks/auto-chain-skills.bats
git commit -m "test: L2 hook unit tests (bats)"
```

---

### Task 18: Hook을 Gemini CLI settings.json에 등록

**Files:**
- Create: `.gemini/settings.json` (workspace-level) — 참고용 예시

- [ ] **Step 1: .gemini/settings.json 작성**

Create `.gemini/settings.json`:

```json
{
  "hooks": {
    "AfterTool": [
      {
        "match": {
          "tool_name": "save_memory"
        },
        "hook": {
          "command": "${workspacePath}/hooks/auto-chain-skills.sh"
        }
      }
    ]
  }
}
```

(참고: v0.37.1 hook 설정 형식. 실제 작동 안 하면 Gemini CLI 공식 docs 재확인: https://google-gemini.github.io/gemini-cli/docs/hooks/)

- [ ] **Step 2: Hook 등록 확인 (Gemini CLI 진입 후)**

Inside `gemini`:
```
/hooks
```
Expected: AfterTool hook with match save_memory 등록 확인

- [ ] **Step 3: Commit**

```bash
git add .gemini/settings.json
git commit -m "feat: register auto-chain hook in workspace settings"
```

---

### Task 19: Step 4 Manual Smoke — 자동 체인 검증

**Files:**
- Create: `tests/manual/smoke-step4.md`

- [ ] **Step 1: smoke 체크리스트 작성**

Create `tests/manual/smoke-step4.md`:

```markdown
# Step 4 Smoke Test — 자동 체인 검증

## Setup

```bash
cd /home/namykim/workspace/DRLLM
gemini extensions uninstall DRLLM 2>/dev/null; gemini extensions link .
rm -rf .drllm/sessions/
```

## Scenario: InnoDB Buffer Pool (hook 자동 체인)

### 사전 검증 (Task 18 gate)

Gemini 진입 후 먼저:
- [ ] `/hooks` — AfterTool match `save_memory` hook 등록 확인
- [ ] Hook `command` 필드가 **절대경로로 resolve** 되어 표시되는지 확인 (`${workspacePath}` 이 `/home/namykim/workspace/DRLLM` 으로 치환). 리터럴 문자열 그대로면 v0.37.1 템플릿 키 미스매치 → plan 재확인.

### 단일 명령으로 end-to-end

- [ ] Gemini 진입 후: `/drllm:launch InnoDB Buffer Pool 왜 128MiB?`
- [ ] 관찰: S0 실행 후 사용자 개입 없이 자동으로 S2 활성화 (Gemini 출력에 "S2 activate" 로그 또는 research 진행 표시)
- [ ] 관찰: S2 완료 후 자동으로 S4 활성화 (학습 대화 시작)
- [ ] stderr 에서 hook 로그 확인:
  ```
  [drllm-hook] S0 done detected → chain to drllm-research-execution
  [drllm-hook] S2 done detected → chain to drllm-adaptive-tutoring
  ```

### 합격 조건

- `/drllm:launch <topic>` 한 번으로 S4 대화까지 도달
- 사용자가 "activate_skill" 수동 호출 안 함
- .drllm/sessions/ 에 metadata.json + research-results.md 모두 생성
- hook 무한 루프 없음 (세션이 정상 완료됨)

## 실패 시

- 자동 체인 안 됨: `/hooks` 로 등록 확인 → Task 18 재확인
- `${workspacePath}` 리터럴 그대로 표시됨: Gemini CLI 템플릿 키 변경 가능성. 절대경로로 하드코딩하여 재시도 후 Task 18 plan 재조정.
- 무한 루프: hook script의 stop_hook_active 체크 → Task 16
- tailToolCallRequest 오류: JSON schema 재확인 → Task 16 hook output
```

- [ ] **Step 2: 실제 smoke 실행 후**

- [ ] **Step 3: Commit — STEP 4 마일스톤**

```bash
git add tests/manual/smoke-step4.md
git commit -m "feat: auto-chain hook"
```

(Commit Point 4 per spec §7.2)

---

## STEP 5 — Measurement (Task 20~24)

### Task 20: S4 learning-log.md 기록 로직 강화

**Files:**
- Modify: `skills/drllm-adaptive-tutoring/SKILL.md`

- [ ] **Step 1: Protocol 섹션 3.2~3.4에 명시적 기록 지침 재강조**

In `skills/drllm-adaptive-tutoring/SKILL.md`, ensure Protocol section contains explicit append commands. Add a dedicated section after Protocol:

```markdown
## Event Recording — MUST DO (v2 Robust)

**Authoritative schema**: `context/drllm-core.md` §5.3 (이벤트 6종 포맷) + §6 (HARD STOPS).

매 turn 종료 전 다음을 확인하여 learning-log.md 에 append (append-only, §0-3 No silent drop):

1. **[SUBTOPIC]**: 새 subtopic 도입 (키포인트 전환) 시
2. **[SOURCE]**: research-results.md verified citation 인용 시
3. **[P5_CHECK]**: P5 발동 + 사용자 답변 + score 평가 완료 시
4. **[P5_SKIP]**: 사용자 응답이 skip 정규식 매치 또는 회피 의사 표명 시 (reason 필수)
5. **[P5_MISSING]**: §3 P5.1 T1~T4 조건 중 하나 이상 참이었으나 P5 발동하지 않은 턴 — **반드시 기록**. triggers 필드에 매치된 T 열거.
6. **[COMPLETE]**: 세션 종료 시 (집계: total_checks, correct, partial, skip, **missing**, duration_sec)

파일 쓰기는 내부 tool(예: `edit_file` 또는 `write_file`)로 append-only.

**형식 예시**:

```
[SUBTOPIC] Buffer Pool 정의 | 2026-04-14T10:31:00+09:00
[SOURCE] fetch::dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool.html | verified=true
[P5_CHECK] Q="Buffer Pool을 한 문장으로" | A="MySQL이 디스크 대신 메모리에 데이터 페이지를 캐시" | score=correct
[P5_SKIP] reason="user_requested_skip"
[P5_MISSING] triggers=T1,T3 | reason="implementer failed to evaluate triggers"
[COMPLETE] total_checks=3 correct=2 partial=1 skip=0 missing=0 duration_sec=1247
```

Hard Gate: 이벤트 기록 생략 → 측정 지표 무효 → 세션 M1 POC 제외 (§6-1).
```

- [ ] **Step 2: Schema test 재확인 후 Commit**

```bash
./tools/run-tests.sh
git add skills/drllm-adaptive-tutoring/SKILL.md
git commit -m "feat: S4 explicit event recording contract"
```

---

### Task 21: S2 metadata.json url_verify 필드 기록 강화

**Files:**
- Modify: `skills/drllm-research-execution/SKILL.md`

- [ ] **Step 1: Protocol 섹션 6~7에 필드 쓰기 지침 재강조**

In `skills/drllm-research-execution/SKILL.md`, ensure Protocol section 7 explicitly shows the metadata update including url_verify_ratio rounded to 3 decimal places:

```markdown
### 7. metadata.json 갱신 (Task 21에서 강조)

S2 종료 전 다음 필드 반드시 갱신:

```json
{
  ...
  "url_verify_total": <Call 1 citations 전체 수, 정수>,
  "url_verify_count": <verified=true 인 수, 정수>,
  "url_verify_ratio": <count/total, 소수점 3자리>,
  "status": "tutor"
}
```

**계산 예시**:
- Call 1 citations = 5개
- Call 2 verified=true = 4개
- ratio = 0.800

**Hard Gate**: 이 필드들을 기록하지 않으면 M1 POC aggregate에 반영되지 않음 — 세션 제외.
```

- [ ] **Step 2: Commit**

```bash
git add skills/drllm-research-execution/SKILL.md
git commit -m "feat: S2 metadata url_verify fields contract"
```

---

### Task 22: tools/aggregate-metrics.sh

**Files:**
- Create: `tools/aggregate-metrics.sh`

- [ ] **Step 1: aggregate 스크립트 작성**

Create `tools/aggregate-metrics.sh`:

```bash
#!/usr/bin/env bash
# M1 POC aggregate metrics from .drllm/sessions/*/
set -euo pipefail

SESSIONS_DIR="${1:-.drllm/sessions}"

if [ ! -d "$SESSIONS_DIR" ]; then
    echo "No sessions directory: $SESSIONS_DIR" >&2
    exit 1
fi

total_checks=0
correct=0
partial=0
skip=0
missing=0
total_sources=0
verified_sources=0
completed=0
total_sessions=0
invalid_sessions=0

for session in "$SESSIONS_DIR"/*/; do
    [ -d "$session" ] || continue
    total_sessions=$((total_sessions + 1))
    log="$session/learning-log.md"
    meta="$session/metadata.json"

    if [ -f "$log" ]; then
        cc=$(grep -c '^\[P5_CHECK\]' "$log" 2>/dev/null || true); cc=${cc:-0}
        co=$(grep '^\[P5_CHECK\]' "$log" 2>/dev/null | grep -c 'score=correct' || true); co=${co:-0}
        pa=$(grep '^\[P5_CHECK\]' "$log" 2>/dev/null | grep -c 'score=partial' || true); pa=${pa:-0}
        sk=$(grep -c '^\[P5_SKIP\]' "$log" 2>/dev/null || true); sk=${sk:-0}
        ms=$(grep -c '^\[P5_MISSING\]' "$log" 2>/dev/null || true); ms=${ms:-0}
        total_checks=$((total_checks + cc))
        correct=$((correct + co))
        partial=$((partial + pa))
        skip=$((skip + sk))
        missing=$((missing + ms))
        # Robust §0-3: [P5_MISSING] 발생 세션은 측정 무효 후보 (M1 POC 제외 권고)
        if [ "$ms" -gt 0 ]; then
            invalid_sessions=$((invalid_sessions + 1))
        fi
    fi

    if [ -f "$meta" ]; then
        t=$(jq -r '.url_verify_total // 0' "$meta")
        v=$(jq -r '.url_verify_count // 0' "$meta")
        total_sources=$((total_sources + t))
        verified_sources=$((verified_sources + v))
        [ "$(jq -r '.status' "$meta")" = "done" ] && completed=$((completed + 1))
    fi
done

# Safe division
p5_score="0.000"
if [ "$total_checks" -gt 0 ]; then
    p5_score=$(awk "BEGIN { printf \"%.3f\", ($correct + $partial * 0.5) / $total_checks }")
fi

url_verify="0.000"
if [ "$total_sources" -gt 0 ]; then
    url_verify=$(awk "BEGIN { printf \"%.3f\", $verified_sources / $total_sources }")
fi

skip_ratio="0.000"
total_triggers=$((total_checks + skip))
if [ "$total_triggers" -gt 0 ]; then
    skip_ratio=$(awk "BEGIN { printf \"%.3f\", $skip / $total_triggers }")
fi

complete_ratio="0.000"
if [ "$total_sessions" -gt 0 ]; then
    complete_ratio=$(awk "BEGIN { printf \"%.3f\", $completed / $total_sessions }")
fi

cat <<EOF
=== DRLLM M1 POC Aggregate Metrics ===
Sessions total:   $total_sessions
Sessions done:    $completed
Sessions invalid: $invalid_sessions (contain [P5_MISSING] — §0-3 측정 무효 후보)
--------------------------------------
P5 score:         $p5_score (필수 ≥ 0.700)
URL verify:       $url_verify (필수 ≥ 0.950)
Skip ratio:       $skip_ratio (기록만)
Complete ratio:   $complete_ratio (기록만)
--------------------------------------
Detail:
  P5 checks:      $total_checks (correct=$correct partial=$partial)
  P5 skips:       $skip
  P5 missing:     $missing (§6-1 위반 기록)
  Citations:      $total_sources (verified=$verified_sources)
EOF
```

- [ ] **Step 2: 실행 권한 부여 + 빈 상태 테스트**

Run:
```bash
chmod +x tools/aggregate-metrics.sh
./tools/aggregate-metrics.sh /nonexistent 2>&1 || true
```
Expected: stderr "No sessions directory" + exit 1

- [ ] **Step 3: 빈 sessions 디렉토리 테스트**

Run:
```bash
mkdir -p /tmp/test-sessions
./tools/aggregate-metrics.sh /tmp/test-sessions
```
Expected: 모든 지표 `0.000`, Sessions total: 0

- [ ] **Step 4: Commit**

```bash
git add tools/aggregate-metrics.sh
git commit -m "feat: aggregate-metrics.sh for M1 POC"
```

---

### Task 23: L3 Aggregation Fixture Tests

**Files:**
- Create: `tests/aggregation/fixtures/sessions/session-A/metadata.json`
- Create: `tests/aggregation/fixtures/sessions/session-A/learning-log.md`
- Create: `tests/aggregation/fixtures/sessions/session-B/metadata.json`
- Create: `tests/aggregation/fixtures/sessions/session-B/learning-log.md`
- Create: `tests/aggregation/fixtures/sessions/session-C/metadata.json`
- Create: `tests/aggregation/fixtures/sessions/session-C/learning-log.md`
- Create: `tests/aggregation/expected-output.txt`
- Create: `tests/aggregation/test.sh`

- [ ] **Step 1: Session A (완벽) 생성**

Create `tests/aggregation/fixtures/sessions/session-A/metadata.json`:

```json
{
  "session_id": "fixture-A",
  "topic": "test A",
  "slug": "a",
  "domain": "born2beroot",
  "started_at": "2026-04-14T10:00:00+09:00",
  "completed_at": "2026-04-14T10:20:00+09:00",
  "status": "done",
  "url_verify_total": 5,
  "url_verify_count": 5,
  "url_verify_ratio": 1.000
}
```

Create `tests/aggregation/fixtures/sessions/session-A/learning-log.md`:

```markdown
---
topic: test A
session_id: fixture-A
started_at: 2026-04-14T10:00:00+09:00
completed_at: 2026-04-14T10:20:00+09:00
status: done
---

## Events

[SUBTOPIC] first
[P5_CHECK] Q="?" | A="!" | score=correct
[SUBTOPIC] second
[P5_CHECK] Q="?" | A="!" | score=correct
[SUBTOPIC] third
[P5_CHECK] Q="?" | A="!" | score=correct
[COMPLETE] total_checks=3 correct=3 partial=0 skip=0 duration_sec=1200
```

- [ ] **Step 2: Session B (부분 partial)**

Create `tests/aggregation/fixtures/sessions/session-B/metadata.json`:

```json
{
  "session_id": "fixture-B",
  "topic": "test B",
  "slug": "b",
  "domain": "born2beroot",
  "started_at": "2026-04-14T11:00:00+09:00",
  "completed_at": "2026-04-14T11:15:00+09:00",
  "status": "done",
  "url_verify_total": 10,
  "url_verify_count": 9,
  "url_verify_ratio": 0.900
}
```

Create `tests/aggregation/fixtures/sessions/session-B/learning-log.md`:

```markdown
---
topic: test B
session_id: fixture-B
started_at: 2026-04-14T11:00:00+09:00
completed_at: 2026-04-14T11:15:00+09:00
status: done
---

## Events

[P5_CHECK] Q="?" | A="!" | score=correct
[P5_CHECK] Q="?" | A="!" | score=correct
[P5_CHECK] Q="?" | A="!" | score=partial
[COMPLETE] total_checks=3 correct=2 partial=1 skip=0 duration_sec=900
```

- [ ] **Step 3: Session C (skip + 미완주)**

Create `tests/aggregation/fixtures/sessions/session-C/metadata.json`:

```json
{
  "session_id": "fixture-C",
  "topic": "test C",
  "slug": "c",
  "domain": "born2beroot",
  "started_at": "2026-04-14T12:00:00+09:00",
  "completed_at": null,
  "status": "tutor",
  "url_verify_total": 4,
  "url_verify_count": 2,
  "url_verify_ratio": 0.500
}
```

Create `tests/aggregation/fixtures/sessions/session-C/learning-log.md`:

```markdown
---
topic: test C
session_id: fixture-C
started_at: 2026-04-14T12:00:00+09:00
completed_at:
status: in_progress
---

## Events

[P5_CHECK] Q="?" | A="!" | score=correct
[P5_SKIP] reason="user_requested_skip"
```

- [ ] **Step 4: Expected output 계산 + 작성**

**Aggregate 수동 계산**:
- Sessions total: 3, done: 2
- P5 checks: 3 (A) + 3 (B) + 1 (C) = 7
- correct: 3 (A) + 2 (B) + 1 (C) = 6
- partial: 0 + 1 + 0 = 1
- skip: 0 + 0 + 1 = 1
- P5 score: (6 + 1×0.5) / 7 = 6.5/7 = 0.929
- Citations total: 5 + 10 + 4 = 19
- Verified: 5 + 9 + 2 = 16
- URL verify: 16/19 = 0.842
- Skip ratio: 1 / (7+1) = 0.125
- Complete ratio: 2/3 = 0.667

Create `tests/aggregation/expected-output.txt`:

```
=== DRLLM M1 POC Aggregate Metrics ===
Sessions total:   3
Sessions done:    2
Sessions invalid: 0 (contain [P5_MISSING] — §0-3 측정 무효 후보)
--------------------------------------
P5 score:         0.929 (필수 ≥ 0.700)
URL verify:       0.842 (필수 ≥ 0.950)
Skip ratio:       0.125 (기록만)
Complete ratio:   0.667 (기록만)
--------------------------------------
Detail:
  P5 checks:      7 (correct=6 partial=1)
  P5 skips:       1
  P5 missing:     0 (§6-1 위반 기록)
  Citations:      19 (verified=16)
```

> **v2 Note**: 현재 fixture 3개 세션은 모두 `[P5_MISSING]` 없음 (happy-path).
> Task 23 구현자는 **v0.5 (또는 M1 미달 postmortem 단계)** 에서 4번째 fixture session-D
> (`[P5_MISSING] triggers=T1,T2` 1건 포함) 를 추가하여 `invalid_sessions=1` + `missing=1`
> 경로가 expected-output에 반영되는지 검증할 것. v0.1 에서는 불필요.

- [ ] **Step 5: test.sh 작성**

Create `tests/aggregation/test.sh`:

```bash
#!/usr/bin/env bash
# L3 Aggregation test
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$0")/../.."  # repo root

actual=$("$PWD/tools/aggregate-metrics.sh" "$DIR/fixtures/sessions")
expected=$(cat "$DIR/expected-output.txt")

if [ "$actual" = "$expected" ]; then
    echo "L3 aggregation: PASS"
else
    echo "L3 aggregation: FAIL" >&2
    echo "--- Expected ---" >&2
    echo "$expected" >&2
    echo "--- Actual ---" >&2
    echo "$actual" >&2
    exit 1
fi
```

- [ ] **Step 6: 실행**

Run:
```bash
chmod +x tests/aggregation/test.sh
./tests/aggregation/test.sh
```
Expected: `L3 aggregation: PASS`

만약 FAIL이면:
- actual vs expected diff 확인
- `aggregate-metrics.sh` 의 awk 포맷, grep 패턴 재검토
- fixture 파일 내용 (`[P5_CHECK] Q="?" | A="!" | score=...`) 형식 정확 일치 확인

- [ ] **Step 7: run-tests.sh 통합 확인**

Run: `./tools/run-tests.sh`
Expected: L1 + L2 + L3 모두 PASS

- [ ] **Step 8: Commit**

```bash
git add tests/aggregation/
git commit -m "test: L3 aggregation fixtures + test harness"
```

---

### Task 24: Step 5 Manual Smoke — 측정 로직 end-to-end

**Files:**
- Create: `tests/manual/smoke-step5.md`

- [ ] **Step 1: smoke 체크리스트 작성**

Create `tests/manual/smoke-step5.md`:

```markdown
# Step 5 Smoke Test — 측정 로직 end-to-end

## Setup

```bash
cd /home/namykim/workspace/DRLLM
rm -rf .drllm/sessions/
gemini extensions link .
```

## Scenario: InnoDB 세션 + 측정 확인

### 전체 플로우

- [ ] `/drllm:launch InnoDB Buffer Pool 왜 128MiB?`
- [ ] 자동 체인으로 S2/S4 도달 (Task 19 smoke 재확인)
- [ ] S4 학습 대화 진행하며 최소 2회 P5 체크 발동 확인
- [ ] 사용자 답변 후 평가 (correct/partial) 응답 확인
- [ ] 1회는 의도적으로 "나중에" 입력하여 skip 테스트

### 파일 검증

- [ ] `learning-log.md` 확인:
  ```bash
  cat .drllm/sessions/*/learning-log.md
  ```
  - `[SUBTOPIC]` 1개 이상
  - `[SOURCE]` 1개 이상
  - `[P5_CHECK]` 2개 이상 (score 포함)
  - `[P5_SKIP]` 1개
  - `[COMPLETE]` 1개 (세션 완료 시)

- [ ] `metadata.json` 확인:
  ```bash
  jq '.url_verify_total, .url_verify_count, .url_verify_ratio, .status, .completed_at' .drllm/sessions/*/metadata.json
  ```
  - `url_verify_total >= 1`
  - `url_verify_count >= 1`
  - `url_verify_ratio >= 0.0`
  - `status == "done"`
  - `completed_at` 존재 (non-null)

### aggregate 실행

- [ ] `./tools/aggregate-metrics.sh` 실행:
  ```
  Sessions total:   1
  Sessions done:    1
  ...
  ```
- [ ] P5 score, URL verify 모두 유효 숫자 (0.000 이상)

### 합격 조건

- learning-log.md 모든 이벤트 타입 최소 1개 이상
- metadata.json url_verify 필드 3개 모두 채워짐
- aggregate 스크립트 에러 없이 실행

## 실패 시

- learning-log 빈 채로: Task 20 S4 이벤트 기록 지침 재확인
- url_verify 필드 0 채로: Task 21 S2 metadata 갱신 지침 재확인
- aggregate NaN 또는 0/0: 스크립트 safe division 재확인 (Task 22)
```

- [ ] **Step 2: 실제 smoke 실행 (구현자 수행)**

- [ ] **Step 3: Commit — STEP 5 마일스톤**

```bash
git add tests/manual/smoke-step5.md
git commit -m "feat: measurement (learning-log + metadata)"
```

(Commit Point 5 per spec §7.2)

---

## STEP 6 — M1 POC 3 Scenarios (Task 25~27)

### Task 25: Scenario 2 — PHP memory_limit

**Files:**
- (실행만, 파일 수정 없음 — 결과는 `.drllm/sessions/` 에 자동 생성)

- [ ] **Step 1: InnoDB 세션은 이미 Task 24에서 생성됨, 보존 확인**

Run: `ls .drllm/sessions/` — 1개 세션 존재 확인

- [ ] **Step 2: Gemini 진입 후 PHP 세션 실행**

```
/drllm:launch PHP memory_limit의 의미와 default 128M의 근거
```

- [ ] **Step 3: 자동 체인으로 S4 도달, 학습 진행**

체크포인트:
- [ ] fetch MCP가 php.net/manual/en/ini.core.php 등 공식 URL 접근
- [ ] Citations verified 비율 확인 (최소 0.8 이상 권장)
- [ ] P5 체크 최소 2회 발동
- [ ] 사용자 답변 시도 (correct 또는 partial)
- [ ] 세션 완료 (`status=done`)

- [ ] **Step 4: 세션 결과 확인**

Run:
```bash
jq '.status, .url_verify_ratio' .drllm/sessions/*/metadata.json
cat .drllm/sessions/<php_session>/learning-log.md
```

Expected: status=done, 최소 2 P5_CHECK 이벤트

- [ ] **Step 5 (Commit 없음 — 세션 데이터는 gitignore)**

진행만 확인. 다음 시나리오로.

---

### Task 26: Scenario 3 — Debian partition

- [ ] **Step 1: Gemini에서 Debian 세션 실행**

```
/drllm:launch Debian partition 분리 이유 (/boot, /, /home)
```

- [ ] **Step 2: 자동 체인 + 학습**

체크포인트:
- [ ] fetch이 debian.org 공식 설치 가이드 접근
- [ ] Citations verified 최소 0.8 이상
- [ ] P5 체크 최소 2회 (개념이 복잡하므로 더 많을 수 있음)
- [ ] 세션 완료

- [ ] **Step 3: 세션 결과 확인**

Run:
```bash
ls .drllm/sessions/
# 3개 디렉토리 존재 확인 (InnoDB, PHP, Debian)
for s in .drllm/sessions/*/; do
  jq -r '.slug + " | " + .status + " | verify=" + (.url_verify_ratio | tostring)' "$s/metadata.json"
done
```

Expected: 3 세션 모두 status=done, verify ratio 표시

---

### Task 27: aggregate 실행 + M1 POC 결과 기록

**Files:**
- Create: `docs/superpowers/reports/m1-poc-results.md`

- [ ] **Step 1: aggregate 실행하여 결과 확보**

Run:
```bash
./tools/aggregate-metrics.sh | tee /tmp/m1-aggregate.txt
```

Expected 출력 예시 (실제 값은 세션에 따라 다름):
```
Sessions total:   3
Sessions done:    3
P5 score:         0.750
URL verify:       0.967
Skip ratio:       0.100
Complete ratio:   1.000
```

- [ ] **Step 2: 결과 문서 작성**

Create `docs/superpowers/reports/m1-poc-results.md`:

```markdown
# M1 POC Results — DRLLM v0.1

**Date**: <YYYY-MM-DD>
**Sessions**: 3
**Aggregate 결과**: (위 aggregate 출력을 여기에 붙여넣기)

---

## Session Details

### Session 1: InnoDB Buffer Pool 왜 128MiB?
- session_id: `<id>`
- status: done
- P5 checks: <N> (correct=<C> partial=<P> skip=<S>)
- URL verify: <count>/<total> (<ratio>)
- duration: <sec>s
- 학습 소감: <수동 관찰 — 응답 품질, P5 체크 자연스러움 등>

### Session 2: PHP memory_limit 의미와 default(128M)
- (위 형식 동일)

### Session 3: Debian partition 분리 이유
- (위 형식 동일)

---

## 합격 판정

| 지표 | 값 | 목표 | 판정 |
|------|----|----|------|
| P5 score | <X> | ≥ 0.700 | ✅ 또는 ❌ |
| URL verify | <X> | ≥ 0.950 | ✅ 또는 ❌ |
| Sessions done | 3 | 3 | ✅ |

**결론**: 합격 / 미달

---

## Baseline (기록만)

- Skip ratio: <X> (v0.1 최초 측정값)
- Complete ratio: <X> (v0.1 최초 측정값)

v0.5에서 위 baseline 기반으로 목표치 설정.

---

## 수동 관찰 요약

- 3 세션 평균 소요 시간: <min>
- 가장 효과적이었던 P5 체크: <사례>
- 개선 필요 사항: <사례>
- 환각 감지 이벤트 (있다면): <사례>
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/reports/m1-poc-results.md
git commit -m "test: M1 POC 3 scenarios"
```

(Commit Point 6 per spec §7.2)

---

## STEP 7 — 판정 (Task 28)

### Task 28: 합격/미달 판정 및 분기

- [ ] **Step 1: aggregate 결과와 목표 대비**

```bash
./tools/aggregate-metrics.sh
```

다음 조건 모두 만족 시 **합격**:
1. Sessions done == 3
2. P5 score ≥ 0.700
3. URL verify ≥ 0.950

- [ ] **Step 2-A: 합격 시 — v0.1-ga 태그**

```bash
git tag -a v0.1-ga -m "DRLLM v0.1 GA — M1 POC passed"
git log --oneline -10  # 태그 확인
```

`docs/superpowers/reports/m1-poc-results.md` 의 "결론"을 `합격`으로 최종 수정.

Commit:
```bash
git add docs/superpowers/reports/m1-poc-results.md
git commit -m "test: M1 POC PASS — v0.1-ga tagged"
```

**다음 단계**: SP-2 brainstorming 진입 (Full DRLLM v0.5 설계). Spec `docs/superpowers/specs/2026-04-14-sp1-tiny-drllm-design.md` §1.3 차이표 기반으로 증분.

- [ ] **Step 2-B: 미달 시 — postmortem + 조치**

Create `docs/superpowers/reports/m1-postmortem.md`:

```markdown
# M1 Postmortem — DRLLM v0.1

**Date**: <YYYY-MM-DD>
**Status**: 미달

## 미달 지표

- P5 score: <actual> (목표 0.700)
- URL verify: <actual> (목표 0.950)

## 원인 분석

### P5 score 원인 (미달 시)
- [ ] drllm-core.md 섹션 3 P5 본문이 모호한가?
- [ ] S4 SKILL.md 의 subtopic 감지 지침 부족?
- [ ] 평가 기준(correct/partial/incorrect)이 LLM에게 불명확?

### URL verify 원인 (미달 시)
- [ ] Call 1 프롬프트가 fetch 결과만 참조를 충분히 강제하지 않는가?
- [ ] Call 2 exact substring match 지침이 불명확?
- [ ] fetch 결과 parsing 이슈 (URL 추출 오류)?

## 조치 방안

### Option A: P5 튜닝 (추정 2~4시간)
- drllm-core.md §3 P5 본문 강화 (실패 사례 수집 후 반영)
- S4 Event Recording 섹션에 구체 예시 추가

### Option B: URL verify 조치 (추정 4~8시간)
- Layer 3a (urlhealth) 조기 도입 — v0.5 범위 일부 선행
- hook 추가: `post-fetch-urlhealth.sh` (AfterTool for fetch MCP)

### Option C: 둘 다 미달 시 재설계 (추정 1~2일)
- 접근법 A (Top-down) 또는 B (Bottom-up) pivot 검토
- spec 섹션 재검토 후 SP-1 v2 작성

## 재실행 정책

- 조치 후 Task 25~27 재실행
- 최대 2회 추가 시도 (총 3회째 미달 시 spec 재설계)
```

Commit:
```bash
git add docs/superpowers/reports/m1-postmortem.md
git commit -m "test: M1 POC FAIL — postmortem + action items"
```

실행할 조치 선택 후 해당 Task로 돌아가 수정 → Task 25~27 재실행.

(Commit Point 7 per spec §7.2)

---

## 사후 작업 (v0.1-ga 이후)

- [ ] README.md 작성 (사용법, 설치, 예시)
- [ ] GitHub 레포 생성 + 푸시 (optional — 개인 사용 시 skip)
- [ ] SP-2 brainstorming 진입 — `superpowers:brainstorming` 스킬 재호출로 Full v0.5 설계

---

## Appendix A — Commit Points 요약

| # | 마일스톤 | Task | 메시지 |
|---|---------|------|--------|
| 1 | Extension skeleton | 1~4 | "feat: DRLLM v0.1 extension skeleton" |
| 2 | 3 skills + 3 commands skeleton | 5~8 | "feat: 3 skills + 3 commands skeleton" |
| 3 | **M1 micro-POC 1차** | 9~15 | "feat: S0/S2/S4 minimal + fetch MCP + Layer 2" |
| 4 | Auto-chain hook | 16~19 | "feat: auto-chain hook" |
| 5 | Measurement | 20~24 | "feat: measurement (learning-log + metadata)" |
| 6 | M1 POC 3 scenarios | 25~27 | "test: M1 POC 3 scenarios" |
| 7 | 판정 | 28 | "test: M1 POC PASS/FAIL + (tag or postmortem)" |

## Appendix B — 실패 시 참조 (Spec §7.4 Rollback Trigger)

spec 문서 `docs/superpowers/specs/2026-04-14-sp1-tiny-drllm-design.md` §7.4 Rollback Trigger 표 참조.

## Appendix C — 관련 문서

- SP-1 Spec: `docs/superpowers/specs/2026-04-14-sp1-tiny-drllm-design.md`
- SP-0 Final Report: `docs/superpowers/research/2026-04-12-sp0-final-report.md`
- Gemini CLI Docs: https://google-gemini.github.io/gemini-cli/docs/
