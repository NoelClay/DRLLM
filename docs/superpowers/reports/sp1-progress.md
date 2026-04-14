# SP-1 Progress & Session Resume Guide

**Branch**: `feat/sp1-tiny-drllm`
**Last updated**: 2026-04-14 (session break)
**Completed**: 15 / 28 Tasks (54%)
**M1 micro-POC 1차**: ✅ PASS
**Next**: STEP 4 (Task 16~19) — auto-chain hook

---

## 1. Resume 빠른 시작

다음 세션에서:

```bash
cd /home/namykim/workspace/DRLLM
git fetch origin
git checkout feat/sp1-tiny-drllm
git pull origin feat/sp1-tiny-drllm

# 도구 확인 (이미 설치되어 있으면 skip)
yq --version   # v4.x (mikefarah)
bats --version # 1.x
uvx --version  # 0.x

# 현재 상태 검증
./tools/run-tests.sh    # L1 schema + (L2 SKIP) + (L3 SKIP) = PASS
git log --oneline | head -5
```

Claude Code 세션에서:
- 본 파일을 먼저 읽기: `docs/superpowers/reports/sp1-progress.md`
- 이어서: `docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` §Task 16
- 전 세션 맥락: 이 문서의 §3 진행 내역 + §5 관찰된 이슈

---

## 2. 완료 요약

### STEP 1 (Task 1~4) — Extension Scaffold

| Task | 산출물 | Commit |
|------|--------|--------|
| 1 | `gemini-extension.json` + `.gitignore` | `3e0219f` |
| 2 | `GEMINI.md` + `context/drllm-core.md` v2 Robust | `519495c` + `91e8277` + `7361b79` |
| 3 | `context/domains/born2beroot.md` | `87c8088` + `ef58e93` |
| 4 | `tests/schema/test-extension.sh` + `tools/run-tests.sh` | `f87073b` + `168f8ad` |

**STEP 1 milestone** (Commit Point 1): `f87073b feat: DRLLM v0.1 extension skeleton`

### STEP 2 (Task 5~8) — 3 Skills + 3 Commands Skeleton

| Task | 산출물 | Commit |
|------|--------|--------|
| 5 | S0 `drllm-launcher/SKILL.md` + `launch.toml` | `c6f3127` |
| 6 | S2 `drllm-research-execution/SKILL.md` + `research.toml` | `88bd8ae` |
| 7 | S4 `drllm-adaptive-tutoring/SKILL.md` + `tutor.toml` | `0c9efcd` + `aee59d0` |
| 8 | `tests/manual/smoke-step2.md` | `d4903fe` + `aefddd4` |

**STEP 2 milestone** (Commit Point 2): `d4903fe feat: 3 skills + 3 commands skeleton`

**사용자 smoke PASS**: Extension linked, 3 skills 인식, 3 commands autocomplete.

### STEP 3 (Task 9~15) — Core Logic + fetch MCP + Layer 2

| Task | 산출물 | Commit |
|------|--------|--------|
| 9 | `mcpServers.fetch` 등록 | `6c13af5` |
| 10 | S2 Protocol §1~§3 (세션 로드 + 쿼리 분해 + fetch) | `0943060` |
| 11 | S2 Protocol §4 Layer 2 Call 1 (JSON schema 강제) | `6d17187` |
| 12 | S2 Protocol §5~§9 Call 2 + 후처리 + marker | `44dfc39` |
| 13 | S0 Protocol concrete (slug/세션ID/metadata/marker) | `67c3c28` |
| 14 | S4 Protocol concrete (T1~T4 + P5 rubric + [COMPLETE] missing 필드) | `a71d06e` + `f9361d3` |
| 15 | `tests/manual/smoke-step3.md` | `8ae8464` + `b9b78be` |

**STEP 3 milestone** (Commit Point 3 = M1 micro-POC 1차): `8ae8464 feat: S0/S2/S4 minimal + fetch MCP + Layer 2`

**M1 micro-POC 1차 smoke 결과** (InnoDB Buffer Pool 세션):
- Session: `.drllm/sessions/20260414-innodb-buffer-pool-default-size/`
- URL verify ratio: **1.000** (2/2 citations verified) ✓ M1 기준 ≥ 0.95 충족
- P5 checks: 2 (1 correct + 1 skip)
- `[COMPLETE]` recorded: `total_checks=2 correct=1 partial=0 skip=1 missing=0 duration_sec=3300`
- Session status: `done`

합격 조건 4/4 ✅ **PASS**.

---

## 3. 남은 Task (13개)

### STEP 4 (Task 16~19) — Auto-chain hook

| Task | 범위 |
|------|------|
| 16 | `hooks/auto-chain-skills.sh` 작성 (bash + jq, save_memory marker 감지) |
| 17 | `tests/hooks/auto-chain-skills.bats` (5 bats 테스트) |
| 18 | `.gemini/settings.json` hook 등록 |
| 19 | `tests/manual/smoke-step4.md` + 자동 체인 검증 smoke |

**STEP 4 milestone** (Commit Point 4): "feat: auto-chain hook"

### STEP 5 (Task 20~24) — Measurement

| Task | 범위 |
|------|------|
| 20 | S4 learning-log 기록 로직 강화 (이미 Task 14 concrete 로 반영됨, 재검증) |
| 21 | S2 metadata `url_verify_*` 필드 기록 강화 (이미 Task 12 concrete 로 반영됨) |
| 22 | `tools/aggregate-metrics.sh` (6 이벤트 집계 + P5_MISSING) |
| 23 | L3 aggregation fixtures + `tests/aggregation/test.sh` |
| 24 | `tests/manual/smoke-step5.md` |

**STEP 5 milestone** (Commit Point 5): "feat: measurement (learning-log + metadata)"

### STEP 6 (Task 25~27) — M1 POC 3 시나리오

| Task | 범위 |
|------|------|
| 25 | Scenario 2 — PHP `memory_limit` 실행 |
| 26 | Scenario 3 — Debian partition 실행 |
| 27 | aggregate 실행 + `docs/superpowers/reports/m1-poc-results.md` 작성 |

**STEP 6 milestone** (Commit Point 6): "test: M1 POC 3 scenarios"

### STEP 7 (Task 28) — 판정

- Aggregate P5 score ≥ 0.70 AND URL verify ≥ 0.95
- 합격 → `v0.1-ga` tag + SP-2 brainstorming 진입
- 미달 → `m1-postmortem.md` + 조치 (Layer 3a urlhealth 조기 도입 등)

---

## 4. 확인 필요한 설정 (다음 세션 시작 시)

Gemini CLI extension settings 는 사용자가 명시 설정해야 함:

```bash
gemini extensions config DRLLM DRLLM_DOMAIN_PROFILE context/domains/born2beroot.md
gemini extensions config DRLLM DRLLM_RESEARCH_MAX_SUBQUERIES 4
```

Manifest 변경 시 재link 필요:

```bash
gemini extensions uninstall DRLLM 2>/dev/null; gemini extensions link .
```

---

## 5. 관찰된 이슈 / v0.5 Refinement 후보

M1 1차 smoke 에서 수집된 이슈 (v0.5 또는 Task 20+ 에서 해결 권고):

1. **Empty-A P5_CHECK invalidation**: S4 가 P5 prompt 발화 직후 `[P5_CHECK] Q=... A="" score=` 를 먼저 append → 사용자 skip → `[P5_SKIP]` 추가. 첫 P5_CHECK (empty A) 가 aggregate count 에 포함되어 total_checks 를 부풀림. **Task 22 aggregate-metrics.sh 에 `A="" 인 P5_CHECK 제외` rule 추가 권고**.
2. **외부 MCP citation 인용 (Open Aware 등)**: S4 가 대화 중 "Open Aware 리서치 결과에 따르면" 처럼 research-results.md 에 없는 외부 MCP citation 인용 가능성. drllm-core v2 §4 "도구 호출 결과에서만 추출" 과 §6-4 "verified=false citation 인용 금지" 에 해당. **v0.5 에서 drllm-core §4 reinforcement + S4 Hard Gate 강화 권고**.
3. **중복 SUBTOPIC 이벤트**: 같은 subtopic 이름이 재발동으로 `[SUBTOPIC]` 2회 기록. 자연스러운 graceful recovery 이지만 aggregate 에서 새 subtopic 수 오산 가능. **Task 20+ 에서 dedup rule 검토**.
4. **Gemini CLI settings default auto-apply 안됨**: Enter 만으로 default 값 자동 적용 안 됨. `gemini extensions config` 명령으로 명시 설정 필수. 사용자 교육 / README 에 명시 필요.
5. **Long shell command display truncation**: `cat <<EOF` 류 긴 shell 명령이 Gemini UI 에 truncated 표시. 실제 파일은 정상 작성. 단 debug 시 혼란 소지 — v0.5 에서는 `write_file` tool 사용 선호 권고.

---

## 6. 다음 세션 진입 순서

1. 본 파일 Read
2. `docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` Task 16 섹션 Read
3. Task 16 implementer subagent dispatch (reports convention 적용)
4. → Task 17/18/19 순차 진행
5. STEP 4 milestone commit (auto-chain hook)
6. STEP 4 사용자 smoke (smoke-step4.md — `/drllm:launch` 1회로 S0→S2→S4 자동 체인 확인)
7. STEP 5 (measurement) 진입

---

## 7. 핵심 파일 참조

- **Spec**: `docs/superpowers/specs/2026-04-14-sp1-tiny-drllm-design.md`
- **Plan**: `docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` (2400+ lines)
- **Authoritative contract**: `context/drllm-core.md` v2 Robust (§0 Design Principles)
- **SP-0 Final Report**: `docs/superpowers/research/2026-04-12-sp0-final-report.md`
- **Session archive** (M1 1차): `.drllm/sessions/20260414-innodb-buffer-pool-default-size/`
- **Task review archive**: `docs/superpowers/reports/task-{01..15}/`
