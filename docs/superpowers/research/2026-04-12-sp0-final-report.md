# SP-0 Final Report — DRLLM 설계 종합 및 로드맵

**Date**: 2026-04-14
**Scope**: SP-0 (Phase 1 광범위 스캔 + Phase 2 심화 + 전사 리뷰) 종합
**다음 단계**: SP-1 (Skill 시스템 설계) brainstorming
**상위 문서**: `docs/superpowers/specs/2026-04-12-sp0-research-plan.md`

---

## 0. Executive Summary

DRLLM은 **임의 도메인 → Deep Research → LearnLM 교수법 변환 → 인출 기반 학습 대화**를 수행하는 메타-프레임워크이며, Gemini CLI Extension으로 패키징된다. Born2beRoot는 최초 검증 도메인일 뿐 시스템 자체는 도메인-agnostic이다.

SP-0(GitHub Deep Research)는 6개 카테고리 × 2단계(광범위 → 심화) = **12회 sub-agent dispatch**로 수행되었고, 다음을 확정하였다:

1. **Gemini CLI v0.37.1은 DRLLM 요구를 사실상 충족한다** — Skills / Hooks(11이벤트) / Subagents / Policy Engine / Plan Mode 모두 정식 지원. Superpowers 4중 메커니즘 중 3.5개 매핑 완료. 유일한 실질적 격차는 **병렬 subagent dispatch 불가**.
2. **MVP는 MCP 서버 없이 시작 가능**하다 — conductor(3,400★)가 파일 기반 phase-gate로 production 달성 실증. 이는 Phase 1 예상을 뒤집는 발견.
3. **환각 방지는 3중 방어로 해결 가능** — Grounding API(pre-LLM URL 마스킹) + JSON schema(2-call) + urlhealth AfterTool hook + MiniCheck NLI(조건부).
4. **BYOC는 형식별 4개 파이프라인으로 구현 가능** — PDF(Docling+MinerU/Citations), PPTX(python-pptx), EPUB(mcp-epub-reader), YouTube(yt-dlp+Chapter-Llama).
5. **LearnLM 특화 Extension은 생태계 부재** — DRLLM S3는 생태계 최초 사례가 된다.

전사 리뷰 결과, 초기 계획의 MVP가 과대했음을 발견하였고, **"Tiny DRLLM v0.1 (3스킬) → Full DRLLM v0.5 (5스킬+BYOC)"** 2단계 로드맵으로 수정한다.

---

## 1. DRLLM 최종 아키텍처 (SP-0 종합)

### 1.1 디렉토리 구조 (확정)

```
drllm-extension/
├── gemini-extension.json          # name/description/version/settings[]
├── GEMINI.md                      # ~200byte stub + @./context/drllm-core.md
├── context/
│   └── drllm-core.md              # Universal File Resolution Protocol (Conductor 패턴 카피)
├── commands/drllm/                # 5개 TOML 슬래시 커맨드 (Phase 2 D 패턴)
│   ├── launch.toml                # /drllm:launch (S0 진입점)
│   ├── plan.toml                  # /drllm:plan (S1)
│   ├── research.toml              # /drllm:research (S2)
│   ├── synthesize.toml            # /drllm:synthesize (S3)
│   └── tutor.toml                 # /drllm:tutor (S4)
├── skills/                        # 5개 SKILL.md 심화 패키지
│   ├── using-drllm/SKILL.md       # 메타스킬 (Superpowers using-superpowers 카피)
│   ├── drllm-launcher/SKILL.md
│   ├── drllm-research-planning/SKILL.md
│   ├── drllm-research-execution/SKILL.md
│   ├── drllm-learnlm-synthesis/SKILL.md
│   └── drllm-adaptive-tutoring/SKILL.md
├── agents/                        # 4개 역할 subagent
│   ├── planner.md
│   ├── researcher.md
│   ├── synthesizer.md
│   └── tutor.md
├── hooks/                         # 4개 강제 메커니즘
│   ├── gate-s1-to-s2.sh           # AfterAgent deny+reason
│   ├── gate-s2-to-s3.sh           # AfterAgent deny+reason
│   ├── inject-state.sh            # BeforeAgent 상태 주입
│   └── auto-chain-skills.sh       # AfterTool tailToolCallRequest
└── .drllm/sessions/<id>/          # 런타임 상태 (git ignored)
    ├── metadata.json              # 세션 메타
    ├── research-plan.md           # S1 산출물
    ├── research-results.md        # S2 산출물
    ├── learnlm-prompt.md          # S3 산출물
    └── learning-log.md            # S4 메타인지 진행 로그
```

### 1.2 5 스킬 워크플로우

```
User: /drllm:launch "InnoDB Buffer Pool 왜 128MiB?"
  ↓ [S0 Launcher]
  └→ 주제 파싱, 세션 ID 생성, .drllm/sessions/<id>/ 초기화
  ↓ [AfterTool tailToolCallRequest → S1]
[S1 Research Planning]
  └→ 주제 분해: 개념/공식문서/관련논문/GitHub이슈 각각의 쿼리 생성
  └→ research-plan.md 작성
  ↓ [gate-s1-to-s2.sh: plan 파일 존재 확인]
[S2 Research Execution]
  └→ MCP 3종 병렬 호출 (도구 레벨 병렬): fetch + github + paper-search
  └→ 3중 환각 방어 (Grounding → JSON schema → urlhealth)
  └→ research-results.md 작성 (출처 라벨 + 원본 URL)
  ↓ [gate-s2-to-s3.sh: results + 모든 URL verified 확인]
[S3 LearnLM Prompt Synthesis]
  └→ 리서치 결과 + 주제 → 맞춤 LearnLM 교수법 프롬프트 동적 생성
  └→ learnlm-prompt.md 작성 (P1~P5 principle 주입)
  ↓
[S4 Adaptive Tutoring]
  └→ learnlm-prompt 로딩 → 인출 기반 대화 시작
  └→ P5 메타인지 체크마다 learning-log.md 업데이트
  └→ 학습 지표 추적 (§4 참조)
```

---

## 2. 카테고리별 최종 권장 (채택·카피수정·기각)

### Category A — 출처 다양화 MCP/도구

| 도구 | 결정 | 이유 |
|------|------|------|
| `modelcontextprotocol/fetch` | ✅ **채택** | Anthropic 공식, P5 환각 방지, 공식문서/웹 |
| `github/github-mcp-server` | ✅ **채택** | 공식, 80+ 도구, `--read-only --toolsets context,issues,pull_requests,repos,users` 정적 구성 |
| `openags/paper-search-mcp` | ✅ **채택** | 24 소스, asyncio.gather 병렬, `SCIHUB_ENABLED=false` 필수 |
| `StackExchange/Stack-MCP` | 🔧 **조건부** | 100 req/day beta 해소 후, v0.2에서 |
| `eliasbiondo/reddit-mcp-server` | 🔧 **조건부** | 프로토타이핑용, 장기는 OAuth 구현으로 교체 |
| `pminervini/deep-research-mcp` | ❌ **기각** | 내부 LLM 합성 → 환각 위험 |

**gemini-extension.json mcpServers** (v0.1 Tier 1 3개):

```json
{
  "mcpServers": {
    "fetch": {
      "command": "uvx",
      "args": ["mcp-server-fetch"],
      "env": {
        "DEFAULT_USER_AGENT_AUTONOMOUS": "DRLLM/0.1 (+https://github.com/namykim/DRLLM)"
      }
    },
    "github": {
      "command": "github-mcp-server",
      "args": ["--toolsets", "context,issues,pull_requests,repos,users", "--read-only"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}" }
    },
    "paper-search": {
      "command": "uvx",
      "args": ["paper-search-mcp"],
      "env": {
        "PAPER_SEARCH_MCP_SCIHUB_ENABLED": "false",
        "PAPER_SEARCH_MCP_UNPAYWALL_EMAIL": "${UNPAYWALL_EMAIL}",
        "PAPER_SEARCH_MCP_SEMANTIC_SCHOLAR_API_KEY": "${SS_API_KEY}"
      }
    }
  }
}
```

### Category B — 환각 방지 (3중 방어)

| Layer | 메커니즘 | 언제 | 비용 |
|-------|---------|------|------|
| **Layer 1 (Pre-LLM)** | Gemini Grounding API — URL 마스킹(`<<URL_n>>`) + redirect 해소 + placeholder 복원 | 검색 결과 수신 직후 | 무시 |
| **Layer 2 (LLM)** | JSON schema 강제 — 2-call 아키텍처 (1차 검색+인용, 2차 검증+최종) | S2 출력 생성 시 | +1 LLM call |
| **Layer 3a (Post-LLM)** | `urlhealth` AfterTool hook — 모든 `mcp_.*_search` 결과 URL에 HEAD/GET 검증 | 도구 호출 완료 후 자동 | ~500ms/URL (병렬) |
| **Layer 3b (NLI)** | MiniCheck (BespokeLabs API) — claim↔source NLI 검증 | **조건부 활성화**: 학술/의료/법률 도메인 또는 `--verify-claims` 플래그 | ~200ms/claim |

**총 레이턴시 추가**: 4.5~7.5초 (Layer 1+2+3a). **Layer 3b 활성화 시 +1~3초**.

**BYOC 예외**: `file://` / `byoc://` 스킴의 출처는 urlhealth 대상 제외.

### Category C — Workflow 강제 메커니즘

**Superpowers 4중 메커니즘 → Gemini 매핑**:

| Superpowers | Gemini CLI 구현 | 상태 |
|-------------|----------------|------|
| 스킬 분화 (skill 파일) | `skills/*/SKILL.md` 3계층 (Workspace/User/Extension) | ✅ 완전 가능 |
| Hard Gate (`<HARD-GATE>`) | SKILL.md 본문 + `AfterAgent` hook `decision: deny + reason` | ✅ 완전 가능 |
| 체크리스트 강제 (TodoWrite) | `save_memory` + BeforeAgent 상태 주입 | ✅ 완전 가능 |
| 다음 스킬 자동 호출 | `AfterTool tailToolCallRequest` (LLM 경유 없이 직접 체인) | ⚠️ 순차만 가능, 병렬 불가 |

**유일한 격차**: 병렬 subagent dispatch. 우회: MCP 도구 레벨 병렬화 (예: S2에서 fetch+github+paper-search 동시 호출).

**새로 발견된 위험 대응**:
- **무한 retry 루프**: 모든 hook에 `stop_hook_active=true 시 allow 반환` 필수
- **Plan Mode + activate_skill 순서**: `exit_plan_mode` 먼저, 그 후 `activate_skill`
- **save_memory 네임스페이스 오염**: 프로젝트 로컬 `.drllm/sessions/` 우선, `save_memory`는 사용자 선호+학습 요약만

**PR 추적**:
- `#17760` (Subagent Configurability): OPEN, 병렬 dispatch 미해결. 단기 해결 기대 X.
- `#25033` (`agent_name` 필드): 머지 대기. 머지되면 hook 정밀도 향상.
- `#25148` (skill patching): 머지 대기. SP-3 단계 활용 후보.

### Category D — Extension 생태계 패턴

**카피할 핵심 패턴**:

| 패턴 | 원본 | DRLLM 적용 |
|------|------|-----------|
| Phase Gate 프롬프트 | conductor | TOML prompt 내 "아티팩트 파일 확인 → 없으면 HALT" 텍스트 인코딩 |
| Universal File Resolution Protocol | conductor | `context/drllm-core.md` 에 5단계 파일 탐색 절차 박기 |
| GEMINI.md stub + @import | oh-my-gemini-cli | ~200byte 엔트리 + `@./context/drllm-core.md` 단일 import |
| Delegation Headers | maestro-gemini | `Agent:/Phase:/Batch:/Session:` 4-field 표준 |
| settings[] 외부화 | maestro-gemini | `DRLLM_RESEARCH_DEPTH`, `DRLLM_LEARNING_MODE`, `DRLLM_LEARNER_PROFILE` 등 |
| 다중 GEMINI.md 분리 | gemini-cli-deep-research | Runtime용 / 개발용 격리 |

### Category E — Gemini CLI 본체 capability

**5스킬 SKILL.md skeleton** (Phase 2 E에서 완성):

```yaml
# skills/drllm-launcher/SKILL.md
---
name: drllm-launcher
description: DRLLM 세션 진입점. 사용자 주제 수신, 세션 ID 생성, 다음 스킬 체인 활성화. TRIGGER when `/drllm:launch` 호출되거나 사용자가 "DRLLM으로 학습 시작" 류 요청.
---

## Mission
주제 파싱 → `.drllm/sessions/<uuid>/metadata.json` 생성 → S1 활성화

## Protocol
1. 주제와 도메인 파라미터 파싱
2. 세션 디렉토리 초기화
3. `activate_skill(drllm-research-planning)` 호출 (또는 AfterTool hook 체인)

## Hard Gate
- 주제가 없으면 사용자에게 요청. 임의 생성 금지.
```

(나머지 S1~S4 skeleton은 `docs/superpowers/research/sp0/deep-E-gemini-cli-internals.md` 참조)

**활용할 본체 기능**:
- `AfterTool.tailToolCallRequest` (스킬 체인 자동 — LLM 경유 없음)
- `AfterAgent.decision:deny+reason` (Hard Gate)
- `BeforeToolSelection` union (스킬별 도구 허용 목록 독립 정의)
- `Policy Engine` `deny` → **도구 메모리 삭제** (환각 방지 최강 — LLM이 도구 존재 자체 인식 못 함)
- `skill-creator` 내장 스킬 (DRLLM 스킬 개발 가속화)
- `AfterAgent.clearContext` (Hard Gate deny 시 오염 컨텍스트 초기화)

### Category F — BYOC Deep Review (v0.2 이후)

**자료 형식별 파이프라인**:

| 형식 | 전처리 | Deep Review | 출력 |
|------|--------|-------------|------|
| PDF/DOCX | Docling (로컬, 57.6K★) | MinerU-Document-Explorer (TOC→섹션 라우팅 MCP) **또는** Claude Citations API | 페이지 번호 + 논리 흐름 |
| PPTX | python-pptx PPTXStructureExtractor (차트/노트 전체) | MinerU-Explorer 또는 Citations API | 슬라이드 + 노트 |
| EPUB | mcp-epub-reader (13 도구 체인) | (직접) | 챕터 + 구절 |
| YouTube | yt-dlp chapters (없으면 Chapter-Llama) + whisper | mcp-youtube-transcript | 타임스탬프 + 요약 |

**비용** (200쪽 기술서적 기준):
- Docling 전처리: CPU 30~90초 (1회)
- Claude Citations API: 첫 질문 $0.15(Haiku)/$0.43(Sonnet), 캐시 히트 시 질문당 $0.006~0.018
- 10 Q&A 세션: ~$0.20 (Haiku)
- 완전 로컬 경로 (MinerU-Explorer): API 비용 0, ~2GB 모델 pre-download 필요

**라이선스 정책 (확정)**:
- 로컬 처리 우선 (Docling, MinerU, python-pptx)
- 외부 API 전송 시 **사용자 명시 동의 필수** (`--api-review` 플래그 등)
- Qwen 리랭커 등 상업용 라이선스 주의 도구는 문서 경고

---

## 3. 수정된 로드맵 (전사 리뷰 반영)

초기 spec의 MVP가 과대했음을 인정하고, 2단계 로드맵으로 분해한다.

### 3.1 Tiny DRLLM v0.1 — "학습 효과 우선 검증"

**범위**:

| 컴포넌트 | v0.1 포함 |
|---------|----------|
| 스킬 | S0 Launcher + S2 Research Execution + S4 Adaptive Tutoring (**3스킬만**) |
| MCP | `fetch` 1개만 |
| 환각 방어 | Layer 2 (JSON schema 2-call) 하나만 |
| BYOC | ❌ (v0.2로 연기) |
| Hooks | `auto-chain-skills.sh` 하나만 |
| 측정 | P5 retrieval 정답률 + 메타인지 skip 비율 (§4 참조) |

**S1/S3 생략 이유**:
- S1(Research Planning)은 S2 안에 인라인으로 대체 가능 (간단한 쿼리 분해)
- S3(LearnLM Prompt Synthesis)는 v0.1에서는 고정 템플릿 사용, 동적 생성은 v0.5에서

**검증 목표**: Born2beRoot 주제 5개에 대해 Tiny DRLLM으로 실제 학습 세션 수행 → 학습 효과 측정.

### 3.2 Full DRLLM v0.5 — "완전체"

v0.1 검증 후 결정:
- S1(Research Planning) + S3(LearnLM Prompt Synthesis) 스킬 추가 (5스킬 완성)
- MCP 3개 완전 통합 (fetch + github + paper-search)
- 3중 환각 방어 완성 (Layer 1+2+3a, 3b 조건부)
- BYOC 4 파이프라인 추가 (PDF 우선)
- Hooks 4개 완성

### 3.3 SP-1 중간 Micro-POC (W2 대응)

SP-1 구현 중간 마일스톤:
- **M1 체크포인트**: S0 + S2(fetch only) + S4 스킬이 첫 주제로 end-to-end 작동
- Born2beRoot 질문 3개 (MySQL innodb_buffer_pool_size, PHP memory_limit, Debian partition) 로 실제 테스트
- **실패 시**: SP-1 설계 재조정 (Full v0.5 전에)
- **성공 시**: 나머지 스킬 추가 진행

### 3.4 Sub-project 재정의

| SP | 원래 범위 | 수정된 범위 |
|----|----------|-----------|
| SP-0 | GitHub Deep Research | ✅ 완료 (본 문서) |
| **SP-1** | Skill 시스템 설계 (5스킬) | **Tiny DRLLM v0.1 설계 (3스킬) + M1 POC** |
| **SP-2** | 출처 다양화 + BYOC 통합 | **Full DRLLM v0.5로 확장** (5스킬 + 3 MCP + 3중 방어) |
| **SP-3** | Born2beRoot 검증 | **v0.1 M1에서 일부 선행** → v0.5 완성 후 full 검증 |

---

## 4. 학습 효과 측정 지표 (신규 — W1 대응)

DRLLM이 "검색 QA"가 아닌 "학습 튜터"로 작동하는지 정량 측정한다.

### 4.1 Core 지표 (v0.1부터 수집)

| 지표 | 정의 | 측정 방법 | 목표 |
|------|------|----------|------|
| **P5 Retrieval 정답률** | LearnLM P5 메타인지 체크에서 사용자가 정확히 설명한 비율 | 체크 횟수 중 ≥90% 정확으로 평가된 답변 비율 (평가는 LLM 자동) | ≥ 70% |
| **메타인지 Skip 비율** | P5 체크 요청을 사용자가 무시/건너뛰기 한 비율 | `learning-log.md` 에 skip 이벤트 기록 | ≤ 20% |
| **출처 Verify 비율** | S2 응답의 인용 URL 중 urlhealth 통과 비율 | AfterTool hook log | ≥ 95% |
| **세션 완주율** | launch → tutor 완료까지 도달한 세션 비율 | metadata.json의 `completed_at` 존재 여부 | ≥ 60% |

### 4.2 구현 위치

`.drllm/sessions/<id>/learning-log.md` 포맷:

```markdown
# Learning Log — session <id>
**Topic**: InnoDB Buffer Pool
**Started**: 2026-04-20T10:30:00Z
**Status**: in_progress

## Events
- 10:31:05 [P5_CHECK] Q="InnoDB Buffer Pool을 한 문장으로"
  - User: "MySQL이 디스크 대신 메모리에 데이터를 캐시하는 영역"
  - Score: 90% (keyword hit: MySQL, memory, cache)
- 10:32:18 [SOURCE] fetch::dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool.html (verified)
- 10:35:00 [P5_SKIP] User skipped retrieval check at subtopic "buffer pool instances"
```

간단한 regex 기반 집계 스크립트로 Core 지표 4개 추출. v0.5에서 대시보드 개선.

### 4.3 지표 채택/재조정 시점

- **M1 POC 후**: 3개 주제 × 세션 기록으로 지표 정의 현실성 검토
- **v0.5 초기**: baseline 수립, 목표치 재조정
- **장기**: 사용자별 personalized baseline

---

## 5. 남은 위험 및 Open Questions

| 위험 | 심각도 | 완화책 |
|------|--------|--------|
| LearnLM 효과 미검증 | 🔴 HIGH | §3.3 M1 POC + §4 지표로 early detection |
| Gemini CLI API 변동 | 🟡 MID | v0.37.1 pin, breaking change 시 재설계 비용 수용 |
| MCP 서버 유지보수 중단 | 🟡 MID | Tier 1 3개는 공식/활발. Tier 2/BYOC는 v0.5에서 재평가 |
| 비용 scaling (BYOC API) | 🟡 MID | 로컬 처리 우선 정책. 외부 API는 명시 동의 |
| 병렬 dispatch 대체의 실효성 | 🟢 LOW | MCP 도구 레벨 병렬화로 충분할 것. v0.1에서 확인 |

### Open Questions (SP-1 brainstorming에서 결정)

1. **Q1**: S0 Launcher는 slash command(`/drllm:launch`)만 트리거할지, 자연어(`"DRLLM으로 학습 시작해줘"`)도 트리거할지?
2. **Q2**: 세션 ID 스킴 — UUID vs timestamp vs slug? 사용자 재방문 UX 고려.
3. **Q3**: Born2beRoot 등 도메인 프로파일을 어떻게 표현? (JSON? Markdown? TOML `settings[]`?)
4. **Q4**: 다국어 지원 — GEMINI.md / SKILL.md 본문을 한국어로 할지, 영어로 할지, 이중 언어로 할지?
5. **Q5**: 오프라인 모드 — 네트워크 없을 때 BYOC만으로 작동 가능한 모드 제공?

---

## 6. 최종 권장 조합 요약

### 6.1 Tier 1 (v0.1 즉시 채택)

- **MCP**: `fetch`
- **환각 방어**: Layer 2 (JSON schema 2-call)
- **워크플로우**: `commands/drllm/*.toml` 3개 + `skills/*` 3개 + `hooks/auto-chain-skills.sh` 1개
- **측정**: `learning-log.md` + 4개 Core 지표

### 6.2 Tier 2 (v0.5 채택)

- **MCP**: `github-mcp-server` + `paper-search-mcp`
- **환각 방어**: Layer 1 (Grounding) + Layer 3a (urlhealth)
- **워크플로우**: S1 + S3 스킬 추가, 4 hook 완성
- **BYOC**: PDF 파이프라인 (Docling + Citations API 또는 MinerU)

### 6.3 Tier 3 (v1.0 이상 조건부)

- **MCP**: Stack-MCP (beta 해소 후), Reddit OAuth 구현
- **환각 방어**: Layer 3b (MiniCheck) — 학술/의료/법률 한정
- **BYOC**: EPUB / YouTube / PPTX 파이프라인
- **확장**: 42school 전체 커리큘럼, MLIR/컴파일러 도메인 프로파일

### 6.4 명시적 기각

- ❌ `pminervini/deep-research-mcp` — LLM 합성 → 환각 위험
- ❌ `ai_search` mode of mcp-omnisearch — LLM 합성 결과
- ❌ Sci-Hub fallback in paper-search-mcp — 명시적 비활성화
- ❌ 단순 RAG chunk-and-retrieve 도구 — Deep Review 철학 불일치

---

## 7. 다음 단계

1. **(즉시)** 본 final-report 사용자 리뷰 — **Gate G4**
2. 승인 시 → **SP-1 brainstorming 시작** (Tiny DRLLM v0.1 설계 + M1 POC 계획)
   - `superpowers:brainstorming` 스킬 재호출
   - Open Questions Q1~Q5 결정
3. SP-1 완료 후 → `superpowers:writing-plans` 스킬로 구현 plan 작성
4. SP-1 구현 → M1 POC → 결과에 따라 SP-2 진입 또는 재설계

---

## Appendix A — SP-0 산출물 전체 목록

### Spec / Plan
- `docs/superpowers/specs/2026-04-12-sp0-research-plan.md` — SP-0 실행 계획

### Phase 1 광범위 스캔 (6개 × ~30KB)
- `docs/superpowers/research/sp0/scan-A-sources.md`
- `docs/superpowers/research/sp0/scan-B-anti-hallucination.md`
- `docs/superpowers/research/sp0/scan-C-workflow-enforcement.md`
- `docs/superpowers/research/sp0/scan-D-gemini-extensions.md`
- `docs/superpowers/research/sp0/scan-E-gemini-cli-capabilities.md`
- `docs/superpowers/research/sp0/scan-F-byoc-deep-review.md`

### Phase 2 심화 딥리서치 (6개 × ~35KB)
- `docs/superpowers/research/sp0/deep-A-source-tools.md`
- `docs/superpowers/research/sp0/deep-B-anti-hallucination.md`
- `docs/superpowers/research/sp0/deep-C-workflow-enforcement.md`
- `docs/superpowers/research/sp0/deep-D-extensions.md`
- `docs/superpowers/research/sp0/deep-E-gemini-cli-internals.md`
- `docs/superpowers/research/sp0/deep-F-byoc.md`

### Phase 3 종합 (본 문서)
- `docs/superpowers/research/2026-04-12-sp0-final-report.md`

---

## Appendix B — 리서치 통계

- **Sub-agent 총 dispatch**: 14회 (Phase 1: 6, Phase 2: 6+2 재시도)
- **총 sub-agent duration**: ~45분 (평균 각 ~5분)
- **총 sub-agent token 사용**: ~600K (모델: Sonnet 4.6)
- **생성된 보고서 총 용량**: ~395KB (12개 마크다운)
- **메인 컨텍스트에 들어온 요약**: ~2400단어 (12개 × 200단어)
- **압축비**: ~160:1 (디스크:메인컨텍스트)
- **Rate limit hit**: 1회 (Phase 2 1차 dispatch) — 복구 성공 (side-effect-first 설계)

---

*본 문서는 SP-0 Phase 1+Phase 2 12개 보고서 + 전사 리뷰를 통합한 설계 결정 문서입니다. SP-1 brainstorming의 direct input으로 사용됩니다.*
