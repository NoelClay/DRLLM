# SP-1 Design — Tiny DRLLM v0.1

**Date**: 2026-04-14
**Scope**: SP-1 (Skill 시스템 설계 + M1 micro-POC 계획) — Tiny DRLLM v0.1
**Status**: Draft → Pending User Review
**Approach**: POC-driven (inside-out, 단일 시나리오 end-to-end 우선)
**상위 문서**:
- `docs/superpowers/specs/2026-04-12-sp0-research-plan.md`
- `docs/superpowers/research/2026-04-12-sp0-final-report.md`

---

## 1. Context

### 1.1 목적

Tiny DRLLM v0.1은 **3스킬(S0/S2/S4) 최소 구성**으로 "LearnLM 교수법이 실제 학습 효과를 내는가"를 **최단 경로로 검증**한다. SP-0 전사 리뷰에서 확인된 W1(학습 효과 미검증)·W2(검증 후순위)에 대응한다.

### 1.2 v0.1 성공 정의 (M1 합격)

- 3 시나리오 세션 **모두 완료** (`metadata.json.status == "done"`)
- **P5 Retrieval 정답률 ≥ 0.70** (correct + partial×0.5) / total_checks
- **URL Verify 비율 ≥ 0.95** (verified / total_citations)

미달 시 §7.7 조치 절차 실행.

### 1.3 v0.5와의 명시적 차이

| 항목 | v0.1 Tiny | v0.5 Full |
|------|-----------|-----------|
| 스킬 수 | 3 (S0/S2/S4) | 5 (+S1/S3) |
| MCP 서버 | 1 (fetch) | 3 (+github, paper-search) |
| 환각 방어 | Layer 2 (JSON schema 2-call) | Layer 1+2+3a + 3b 조건부 |
| Hook | 1 (auto-chain-skills) | 4 (+gate-s1-s2, gate-s2-s3, inject-state) |
| BYOC | ❌ | PDF 우선 파이프라인 |
| 도메인 프로파일 | 1 (Born2beRoot 고정) | 다도메인 switch |

**파일 이름/디렉토리 구조는 v0.5와 동일** → v0.5 진화 시 파일 추가만 필요 (리팩토링 없음).

---

## 2. 결정사항 요약 (브레인스토밍 Q1~Q8)

| Q | 주제 | 선택 | 설계 반영 위치 |
|---|------|------|---------------|
| Q1 | Launcher 트리거 | (C) slash + 자연어 둘 다 | `launch.toml` + `drllm-launcher/SKILL.md` description 이중 트리거 |
| Q2 | 세션 ID 스킴 | (C) `YYYYMMDD-<slug>`, 충돌 시 `-2/-3` | S0이 `date +%Y%m%d` + LLM slug 변환으로 생성 |
| Q3 | 도메인 프로파일 형식 | (B) Markdown 파일 + settings[] 경로 | `context/domains/born2beroot.md` + `DRLLM_DOMAIN_PROFILE` setting |
| Q4 | 언어 정책 | (C) 이중 언어 레이어 분리 | frontmatter/description/hook = 영어, 본문·사용자 응답 = 한국어 |
| Q5 | 오프라인 모드 | skip (v1.0+) | 해당 없음 |
| Q6 | S2 쿼리 분해 방식 | (B) S2 내부 인라인 분해 | S2 SKILL.md 첫 단계: LLM 주제 분해 (2~4 서브쿼리) |
| Q7 | P5 메타인지 체크 트리거 | (B) LLM 판단 (subtopic 완료 감지) | S4 SKILL.md: subtopic 경계 인지 시 P5 강제 |
| Q8 | M1 POC 합격 기준 | (C) Mixed: Manual + P5≥0.70 + URL verify≥0.95 | §1.2 + §6 |

---

## 3. 아키텍처

### 3.1 디렉토리 구조

```
drllm-extension/
├── gemini-extension.json          # name/description/version/settings[]/mcpServers
├── GEMINI.md                      # ~200byte stub + @./context/drllm-core.md
├── context/
│   ├── drllm-core.md              # Universal File Resolution + P5 강제 본문 (한국어)
│   └── domains/
│       └── born2beroot.md         # 도메인 프로파일 (v0.1 기본)
├── commands/drllm/                # 3개 slash command TOML
│   ├── launch.toml                # /drllm:launch (S0 진입)
│   ├── research.toml              # /drllm:research (S2)
│   └── tutor.toml                 # /drllm:tutor (S4)
├── skills/                        # 3개 SKILL.md 심화 패키지
│   ├── drllm-launcher/SKILL.md
│   ├── drllm-research-execution/SKILL.md
│   └── drllm-adaptive-tutoring/SKILL.md
├── hooks/
│   └── auto-chain-skills.sh       # AfterTool tailToolCallRequest
├── tests/
│   ├── schema/test-extension.sh
│   ├── hooks/auto-chain-skills.bats
│   ├── aggregation/
│   │   ├── fixtures/sessions/
│   │   ├── expected-output.txt
│   │   └── test.sh
│   └── manual/smoke-step{1..6}.md
├── tools/
│   ├── run-tests.sh
│   └── aggregate-metrics.sh
├── .drllm/                        # gitignore
│   └── sessions/<YYYYMMDD>-<slug>/
│       ├── metadata.json
│       ├── research-results.md
│       └── learning-log.md
└── README.md
```

### 3.2 gemini-extension.json (v0.1 초안)

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
  "mcpServers": {
    "fetch": {
      "command": "uvx",
      "args": ["mcp-server-fetch"],
      "env": {
        "DEFAULT_USER_AGENT_AUTONOMOUS": "DRLLM/0.1 (+https://github.com/namykim/DRLLM)"
      }
    }
  }
}
```

### 3.3 GEMINI.md (stub)

```markdown
# DRLLM v0.1

Domain-agnostic Deep Research + LearnLM tutoring framework.

@./context/drllm-core.md
```

---

## 4. 데이터 플로우

### 4.1 전체 흐름

```
[사용자] "/drllm:launch InnoDB Buffer Pool 왜 128MiB?"
  또는 자연어: "DRLLM으로 InnoDB 학습"
      ↓
[S0 drllm-launcher]
  1. 주제 파싱
  2. LLM 호출 → slug 생성 ("innodb-buffer-pool-default-size")
  3. 세션 디렉토리 생성: .drllm/sessions/20260414-<slug>/
  4. metadata.json 작성: { topic, slug, started_at, domain, status: "research" }
  5. marker tool 호출: save_memory("__drllm_s0_done_<session_id>")
      ↓ [hook: auto-chain-skills.sh]
      ↓ tailToolCallRequest → activate_skill("drllm-research-execution")
      ↓
[S2 drllm-research-execution]
  1. metadata.json 로드 → 주제 수신
  2. 인라인 쿼리 분해 (LLM) → 2~4 서브쿼리
  3. domain.md 로드 → 우선 참조 URL 힌트
  4. fetch MCP 병렬 호출 (서브쿼리별)
  5. Layer 2 JSON schema 2-call (§5)
  6. research-results.md 작성
  7. metadata.json 갱신: url_verify_ratio, status = "tutor"
  8. marker tool 호출: save_memory("__drllm_s2_done_<session_id>")
      ↓ [hook: auto-chain-skills.sh]
      ↓ tailToolCallRequest → activate_skill("drllm-adaptive-tutoring")
      ↓
[S4 drllm-adaptive-tutoring]
  1. metadata.json + research-results.md + drllm-core.md 로드
  2. learning-log.md 초기화 (frontmatter + 빈 Events)
  3. 대화 시작 (한국어):
     - 개념 소개 (research 결과 기반)
     - [SUBTOPIC] 이벤트 기록 시 subtopic 경계
     - subtopic 완료 감지 시 (LLM 판단) → P5 체크 강제
       "한 문장으로 [X]를 설명해줄 수 있어?"
     - 사용자 답변 평가 (LLM: correct/partial/incorrect/skip)
     - [P5_CHECK] 또는 [P5_SKIP] 이벤트 기록
  4. 세션 완료 시:
     - metadata.json 갱신: completed_at, status = "done"
     - [COMPLETE] 이벤트 기록
```

### 4.2 상태 파일 명세

**metadata.json**:
```json
{
  "session_id": "20260414-innodb-buffer-pool-default-size",
  "topic": "InnoDB Buffer Pool 왜 128MiB?",
  "slug": "innodb-buffer-pool-default-size",
  "domain": "born2beroot",
  "started_at": "2026-04-14T10:30:00+09:00",
  "completed_at": null,
  "status": "research",
  "url_verify_total": 0,
  "url_verify_count": 0,
  "url_verify_ratio": 0.0
}
```

`status` 전이: `research` → `tutor` → `done` (또는 `research_failed` / `abandoned`)

**research-results.md** (S2 산출물):
```markdown
---
session_id: 20260414-innodb-buffer-pool-default-size
generated_at: 2026-04-14T10:31:45+09:00
subqueries_count: 3
citations_verified: 5/5
---

## Summary
[3~5 문장, 한국어]

## Key Points
- [Point 1, 한국어]
- [Point 2, 한국어]
...

## Citations
| # | URL | Quote | Source Type | Verified |
|---|-----|-------|-------------|----------|
| 1 | https://dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool.html | "..." | official_docs | ✅ |
...
```

**learning-log.md** (S4 산출물, §6.1 포맷):
`[SUBTOPIC]` / `[SOURCE]` / `[P5_CHECK]` / `[P5_SKIP]` / `[COMPLETE]` 이벤트 append-only.

### 4.3 Hook 동작 (auto-chain-skills.sh)

```bash
#!/bin/bash
# AfterTool hook: DRLLM marker tool 호출 시 다음 스킬 체인
set -e
input=$(cat)

# 무한 루프 방지
if [ "$(echo "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
    echo '{}'; exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input | tostring')

# S0 완료 → S2
if [[ "$tool_name" == "save_memory" && "$tool_input" == *"__drllm_s0_done_"* ]]; then
    echo >&2 "[drllm-hook] S0 → S2 chain"
    cat <<'EOF'
{"hookSpecificOutput":{"tailToolCallRequest":{
  "name":"activate_skill",
  "args":{"skill_name":"drllm-research-execution"}
}}}
EOF
    exit 0
fi

# S2 완료 → S4
if [[ "$tool_name" == "save_memory" && "$tool_input" == *"__drllm_s2_done_"* ]]; then
    echo >&2 "[drllm-hook] S2 → S4 chain"
    cat <<'EOF'
{"hookSpecificOutput":{"tailToolCallRequest":{
  "name":"activate_skill",
  "args":{"skill_name":"drllm-adaptive-tutoring"}
}}}
EOF
    exit 0
fi

# 관련 없는 tool: pass-through
echo '{}'
```

### 4.4 에러 처리 매트릭스

| 실패 지점 | 처리 |
|----------|------|
| 주제 파싱 실패 (빈 입력) | S0이 재입력 요청, 세션 미생성 |
| fetch MCP 실패 | S2가 대안 서브쿼리로 1회 재시도 → 실패 시 `status = research_failed` + 사용자 보고 |
| Call 1 schema 실패 | Gemini structured output 자동 재시도 1회 → 실패 시 "schema 생성 실패" |
| Call 2 모든 verified=false | research-results.md에 경고 + S4 진입 차단 |
| Call 2 일부 verified=false | verified=true만 유지, ratio<0.5 시 S4 진입 전 사용자 경고 |
| P5 skip | [P5_SKIP] 이벤트 기록, 학습 계속 |
| Hook 실패 | stderr 로그 + LLM에 fallback 지시 ("수동으로 activate_skill 호출") |
| stop_hook_active 루프 | hook에서 `{}` 반환하여 안전 종료 (§4.3) |

---

## 5. 환각 방어 Layer 2 (JSON Schema 2-call)

### 5.1 Citations Schema

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
          "relevance_to_subquery": { "type": "string" },
          "verified": { "type": "boolean" }
        },
        "required": ["url", "quote", "source_type", "relevance_to_subquery"]
      }
    }
  },
  "required": ["summary", "key_points", "citations"]
}
```

### 5.2 2-call 흐름

**Call 1 — 응답 생성**:
- 입력: 사용자 주제 + fetch 결과 raw text + schema
- 지시: "fetch 결과에서만 citations.url과 citations.quote를 추출. 추측 URL/quote 생성 금지."
- 출력: schema 강제 JSON (Gemini `response_schema`)

**Call 2 — 교차 검증**:
- 입력: Call 1 결과 + fetch 결과 raw text + 검증 지시
- 지시: "각 citation에 대해 (a) url이 fetch 결과에 실제로 등장하는가, (b) quote가 fetch 결과 본문에 exact substring으로 포함되는가 확인. 둘 다 만족 시 verified=true, 아니면 false."
- 출력: 동일 schema + `verified` 필드 채워짐

**후처리**: S2가 verified=false citation 제거 후 research-results.md 작성. `url_verify_ratio = verified_count / total_citations_count` metadata.json에 기록.

### 5.3 Exact Substring Match 규칙 (Call 2 검증)

- 공백·개행 normalize: `\s+` → 단일 공백
- 대소문자: 유지 (변조 감지)
- 최소 매치 길이: 15자 (schema minLength와 동일)
- 매치 실패 시 verified=false, reason에 구체 이유

### 5.4 v0.1 한계 및 v0.5 진화

| 한계 | v0.5 조치 |
|------|----------|
| URL HTTP 실재 여부 검증 불가 | Layer 3a (urlhealth AfterTool hook) |
| claim↔source NLI 검증 불가 | Layer 3b (MiniCheck, 조건부) |
| Pre-LLM URL 마스킹 없음 | Layer 1 (Gemini Grounding API) |

---

## 6. 측정 + M1 POC 합격 기준

### 6.1 learning-log.md 포맷

```markdown
---
topic: InnoDB Buffer Pool 왜 128MiB?
session_id: 20260414-innodb-buffer-pool-default-size
started_at: 2026-04-14T10:30:00+09:00
completed_at:
status: in_progress
---

## Events

[SUBTOPIC] Buffer Pool 정의 | 2026-04-14T10:31:00+09:00
[SOURCE] fetch::dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool.html | verified=true
[P5_CHECK] Q="Buffer Pool을 한 문장으로" | A="MySQL이 디스크 대신 메모리에 데이터 페이지를 캐시" | score=correct
[SUBTOPIC] 128MiB default 기원
[P5_SKIP] reason="user_requested_skip"
[COMPLETE] total_checks=2 correct=1 partial=0 skip=1 duration_sec=847
```

### 6.2 이벤트 기록 책임

| 이벤트 | 기록자 | 근거 |
|--------|-------|------|
| `[SUBTOPIC]` | S4 LLM | Q7 B (LLM이 subtopic 경계 판단) |
| `[SOURCE]` | S2 batch append (v0.1) | v0.5에서 post-fetch hook 분리 |
| `[P5_CHECK]` | S4 LLM | score 평가 포함 |
| `[P5_SKIP]` | S4 LLM | 사용자 의도 해석 |
| `[COMPLETE]` | S4 LLM 또는 세션 종료 | 세션 end marker |

### 6.3 Aggregate 집계 스크립트

`tools/aggregate-metrics.sh` 입력: `.drllm/sessions/*/`. 출력:
```
P5 score:       0.75 (필수 ≥ 0.70)
URL verify:     0.98 (필수 ≥ 0.95)
Skip ratio:     0.15 (기록만)
Complete ratio: 1.00 (기록만)
```

`partial` 점수는 0.5로 계산: `(correct + partial*0.5) / total_checks`.

### 6.4 M1 POC 시나리오 3개

| # | 주제 | 선택 이유 | 난이도 | 실행 순서 |
|---|------|----------|--------|----------|
| 1 | MySQL `innodb_buffer_pool_size` 왜 128MiB? | Axiom 확립, 출처 URL 명확 | 쉬움 | 1번 (baseline) |
| 2 | PHP `memory_limit` 의미와 default(128M) | 공식+배포판 기본값 차이 | 중간 | 2번 |
| 3 | Debian partition 분리 이유 (`/boot`, `/`, `/home`) | 개념 복잡, 공식+커뮤니티 혼합 | 어려움 | 3번 |

### 6.5 합격/미달 처리

```
[M1 합격]
  ├→ docs/superpowers/reports/m1-poc-results.md 작성 (결과 요약)
  ├→ v0.1-ga 태그
  └→ SP-2 brainstorming 진입

[M1 미달]
  ├→ docs/superpowers/reports/m1-postmortem.md 작성 (원인 분석)
  ├→ 조치:
  │   - P5 score 미달 → drllm-core.md P5 템플릿 + S4 dialogue 튜닝 (2~4시간)
  │   - URL verify 미달 → Layer 3a (urlhealth) 조기 도입
  │   - 둘 다 미달 → SP-1 재설계 (접근법 A/B pivot 고려)
  └→ 조치 후 step 6 재실행
```

---

## 7. 구현 순서 (POC-driven 7단계)

### 7.1 전체 표

| Step | 산출물 | 검증 | 롤백 대상 | 예상 시간 |
|------|--------|------|-----------|----------|
| 1 | `gemini-extension.json` + `GEMINI.md` stub + `drllm-core.md` + `born2beroot.md` | `gemini extensions link .` → `/extensions`에 DRLLM 표시 | — | 1h |
| 2 | 3 SKILL.md skeleton + 3 TOML command | `activate_skill("drllm-launcher")` 수동 호출 → SKILL 본문 로딩 | step 1 | 2h |
| 3 | S0/S2/S4 최소 로직 + fetch MCP + Layer 2 | InnoDB 주제로 수동 end-to-end 성공 | step 2 | 4~6h |
| 4 | `auto-chain-skills.sh` + hook 등록 | 같은 주제 재실행, `/drllm:launch`만으로 자동 체인 | step 3 | 2h |
| 5 | learning-log 기록 + metadata.json url_verify + aggregate-metrics.sh | 세션 재실행 후 learning-log 이벤트 + 집계 가능 | step 4 | 2h |
| 6 | PHP memory_limit + Debian partition 2 세션 + m1-poc-results.md | 3 세션 aggregate P5≥0.70 AND URL verify≥0.95 | step 3~5 | 3~5h |
| 7 | 판정 (합격: v0.1-ga / 미달: m1-postmortem.md + 조치) | Q8 C 기준 | 필요시 Layer 3a 조기 도입 | 1h + α |

**전체 추정**: 15~19시간 (풀타임 2~3일).

### 7.2 Commit Points

```
step 1 → "feat: DRLLM v0.1 extension skeleton"
step 2 → "feat: 3 skills + 3 commands skeleton"
step 3 → "feat: S0/S2/S4 minimal + fetch MCP + Layer 2"  # M1 1차 마일스톤
step 4 → "feat: auto-chain hook"
step 5 → "feat: measurement (learning-log + metadata)"
step 6 → "test: M1 POC 3 scenarios"
step 7 → git tag v0.1-ga (합격 시) 또는 rollback branch
```

### 7.3 Step 3 중요성

처음으로 S0+S2+S4 + MCP 등록 + Layer 2가 동시에 작동해야 하는 지점. 실패 시 구조적 재검토까지 내려갈 수 있음. **수동 호출 + 빈번한 로그 확인 권장**.

### 7.4 Rollback Trigger 세부

| Step에서 실패 | 증상 | 진단 | 롤백 범위 |
|--------------|------|------|----------|
| step 1 | `/extensions`에 DRLLM 미표시 | gemini-extension.json schema 오류 | step 1 내 수정 |
| step 2 | `activate_skill` 실패 | SKILL.md frontmatter `name` mismatch 또는 3계층 발견 실패 | step 2 내 수정 |
| step 3 | S0→S2 수동 연결 안 됨 | SKILL 상호 참조 또는 marker tool 호출 누락 | step 2~3 경계 검토 |
| step 3 | Layer 2 schema 강제 실패 | Gemini `response_schema` 미지원 버전 또는 schema 오류 | 2-call 구조 재검토 |
| step 4 | hook 체인 무한 루프 | `stop_hook_active` 체크 누락 | hook script 수정 |
| step 4 | hook이 `activate_skill` 호출 안 함 | `tailToolCallRequest` JSON 구조 오류 | hook 출력 schema 확인 |
| step 5 | learning-log 빈 채로 | S4 log-append 로직 누락 | S4 SKILL.md 본문 수정 |
| step 5 | URL verify ratio 0 | S2 citations에 verified 필드 누락 | step 3 Layer 2 재확인 |
| step 6 | P5 score < 0.70 | P5 프롬프트 또는 dialogue 전략 이슈 | `drllm-core.md` P5 템플릿 개선 |
| step 6 | URL verify < 0.95 | fetch 결과 파싱 또는 Call 2 검증 완성도 | Layer 3a (urlhealth) 조기 도입 |

### 7.5 Post-M1 분기 (재확인)

- **합격**: v0.1-ga 태그 → SP-2 brainstorming 진입
- **P5 미달**: drllm-core.md P5 템플릿 개선 후 재실행
- **URL verify 미달**: Layer 3a (urlhealth) 조기 도입 = v0.5 범위 일부 선행
- **둘 다 미달**: 접근법 A (Top-down) 또는 B (Bottom-up) pivot 검토

### 7.6 재실행 정책 (M1 미달 시)

- 조치 후 step 6만 재실행 (step 1~5 retain)
- 최대 재시도 2회 (3회 째 미달 시 SP-1 재설계 권고)

---

## 8. 테스트 전략

### 8.1 5계층 테스트

| L | 대상 | 도구 | 자동 | 시점 |
|---|------|------|------|------|
| L1 Schema | gemini-extension.json, SKILL.md frontmatter, metadata.json | `jq`, `yq` | ✅ | 각 step 종료 |
| L2 Hook unit | auto-chain-skills.sh | `bats` | ✅ | step 4+ commit 시 |
| L3 Aggregation | aggregate-metrics.sh | fixture sessions | ✅ | step 5+ |
| L4 Smoke (manual) | 각 step 체크리스트 | human | ❌ | 각 step 종료 |
| L5 Acceptance | M1 POC 3 시나리오 | human + aggregate | ❌ manual + ✅ 집계 | step 6 (1회) |

### 8.2 L1 Schema 테스트 (sample)

```bash
# tests/schema/test-extension.sh
set -e
jq -e '.name and .description and .version and .contextFileName' \
  gemini-extension.json > /dev/null
for skill in skills/*/SKILL.md; do
  front=$(awk '/^---$/{c++; next} c==1' "$skill")
  echo "$front" | yq -e '.name and .description' > /dev/null \
    || { echo "FAIL: $skill"; exit 1; }
done
echo "L1 schema: PASS"
```

### 8.3 L2 Hook unit (bats, sample)

```bash
# tests/hooks/auto-chain-skills.bats
setup() { HOOK=./hooks/auto-chain-skills.sh; }

@test "S0 완료 → S2 체인" {
  result=$(echo '{"tool_name":"save_memory","tool_input":"__drllm_s0_done_xxx","stop_hook_active":false}' | "$HOOK")
  [[ "$(echo "$result" | jq -r '.hookSpecificOutput.tailToolCallRequest.args.skill_name')" == "drllm-research-execution" ]]
}

@test "stop_hook_active → 조용히 통과" {
  result=$(echo '{"tool_name":"save_memory","tool_input":"__drllm_s0_done_xxx","stop_hook_active":true}' | "$HOOK")
  [[ "$result" == "{}" ]]
}
```

### 8.4 L3 Aggregation

`tests/aggregation/fixtures/sessions/` 에 3개 샘플 세션 (A: 완벽, B: 부분 partial, C: skip 많음). `aggregate-metrics.sh` 실행 결과와 `expected-output.txt` 비교.

### 8.5 L4 Manual Smoke

`tests/manual/smoke-step{1..6}.md` — step별 체크리스트. 예시 (step 3):

```markdown
# tests/manual/smoke-step3.md

- [ ] `gemini` 진입 후 `/extensions`에 DRLLM 표시
- [ ] `activate_skill("drllm-launcher")` 수동 호출 → S0 본문 응답
- [ ] InnoDB 주제로 S0 실행 → `.drllm/sessions/<id>/metadata.json` 생성
- [ ] S2 수동 호출 → `research-results.md` 생성됨
- [ ] S4 수동 호출 → 한국어 학습 대화 시작됨
- [ ] Citations URL 최소 1개 이상 verified=true 표시
```

### 8.6 L5 Acceptance = M1 POC

step 6 자체가 통합 시스템 테스트. 결과는 `docs/superpowers/reports/m1-poc-results.md`.

### 8.7 테스트 엔트리포인트

```bash
# tools/run-tests.sh
set -e
./tests/schema/test-extension.sh
bats tests/hooks/
./tests/aggregation/test.sh
echo "Automated tests: PASS"
echo "Manual smoke: see tests/manual/smoke-step*.md"
```

### 8.8 v0.1 의도적 비포함

- CI/CD (GitHub Actions) — v1.0
- LLM 응답 regression test (snapshot diff) — v0.5
- Load/stress test — v1.0
- Cross-platform test — v0.5

---

## 9. v0.1 의도적 비포함 (YAGNI) + v0.5 진화 경로

| v0.1 미포함 | v0.5 추가 | 트리거 |
|-------------|-----------|--------|
| S1 Research Planning (인라인화) | 독립 스킬 + gate-s1-s2 hook | v0.1 M1 합격 후 |
| S3 LearnLM Prompt Synthesis (고정 템플릿) | 동적 생성 + gate-s2-s3 hook | v0.1 M1 합격 후 |
| github / paper-search MCP | mcpServers[] 추가 | v0.5 SP-2 진입 |
| Layer 1 Grounding API | S2 fetch 전처리 | v0.5 SP-2 |
| Layer 3a urlhealth | AfterTool hook 추가 | v0.1 URL verify 미달 or v0.5 기본 |
| Layer 3b MiniCheck (조건부) | S4 학술 도메인만 | v1.0+ |
| BYOC (PDF 등) | SP-2 파이프라인 | v0.5 |
| 다도메인 switch (`--domain`) | settings[] 동적 교체 | v0.5 |
| LLM response regression | snapshot 테스트 | v0.5 |
| CI/CD | GitHub Actions | v1.0 |

---

## 10. Open Questions (SP-2 brainstorming에서 결정)

1. S1이 독립 스킬이 될 때 인라인 분해 로직(v0.1 S2 첫 단계)을 어떻게 S1으로 이관할지?
2. S3 동적 LearnLM 프롬프트 합성의 입력 크기 관리 (research-results.md가 길어질 경우)
3. 다도메인 switch 시 `domain.md` 간 공통 axiom을 어떻게 공유할지 (상속? import? 단순 복붙?)
4. urlhealth hook을 v0.5에서 추가할 때 기존 Layer 2 Call 2와의 역할 분리 명확화
5. BYOC 시 `file://` / `byoc://` 스킴과 기존 `https://` citations 구조 통합

---

## 11. 남은 위험

| 위험 | 심각도 | 완화 |
|------|--------|------|
| Gemini response_schema가 v0.1 구현 시점에 스펙 변동 | 🟡 MID | step 3에서 최우선 검증, 실패 시 JSON instruction fallback |
| save_memory marker tool이 글로벌 오염 | 🟡 MID | `__drllm_<session_id>_` 네임스페이스로 격리, v0.5에서 파일 기반 marker 교체 고려 |
| LLM이 한국어 응답 생성 중 citation URL 변조 | 🟡 MID | Layer 2 Call 2 exact substring match로 1차 차단 (URL 변조는 잡힘) |
| M1 3 세션이 도메인 bias(모두 Born2beRoot) | 🟢 LOW | v0.5에서 교차 도메인 검증 (예: 컴파일러 이론 1 세션) 추가 |
| hook이 activate_skill 실패 시 체인 끊김 | 🟡 MID | stderr 로그 + LLM fallback 지시 (사용자에게 수동 호출 요청) |

---

## 12. Appendix A — 전체 파일 트리 (재확인)

§3.1 참조.

## Appendix B — 참고 (SP-0 문서)

- SP-0 research plan: `docs/superpowers/specs/2026-04-12-sp0-research-plan.md`
- SP-0 final report: `docs/superpowers/research/2026-04-12-sp0-final-report.md`
- Phase 2 Category E (Gemini CLI 본체): `docs/superpowers/research/sp0/deep-E-gemini-cli-internals.md`
- Phase 2 Category C (Workflow 강제): `docs/superpowers/research/sp0/deep-C-workflow-enforcement.md`
- Phase 2 Category D (Extension 생태계): `docs/superpowers/research/sp0/deep-D-extensions.md`
