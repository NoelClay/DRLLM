# SP-1 Progress & Session Resume Guide

**Branch**: `feat/sp1-tiny-drllm`
**Last updated**: 2026-04-15 (STEP 5 code-complete)
**Completed**: 24 / 28 Tasks (86%)
**M1 micro-POC 1차**: ✅ PASS (2026-04-14)
**STEP 4 smoke (chain-only)**: ✅ PASS (2026-04-15)
**STEP 5 code**: ✅ complete — drllm-core v2.2 + aggregate-metrics.sh + L3 fixtures/test + bug fixes B1/B2/B3 통합
**Bugs**: B1/B2/B3 in_progress (v0.5 SP-2 에서 closure), B4 open (SP-2 negative fixtures)
**STEP 5 smoke**: ⏳ pending user run (`tests/manual/smoke-step5.md`)
**Next**: STEP 6 (Task 25~27) — M1 POC 3 시나리오 실행

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

### STEP 4 (Task 16~19) — Auto-chain hook

| Task | 산출물 | Commit |
|------|--------|--------|
| 16 | `hooks/auto-chain-skills.sh` | `8458d97` |
| 17 | `tests/hooks/auto-chain-skills.bats` (5 tests) + plan `tail -1` sync | `d53d3ed` + `4258c33` + `7f05563` |
| 18 | `.gemini/settings.json` (AfterTool save_memory → hook) | `b1dcaad` |
| 19 | `tests/manual/smoke-step4.md` + plan sync + I1~I4 fix | `1f76bb5` + `7221ff2` + `66ff871` |

**STEP 4 milestone** (Commit Point 4 = code-complete): `7221ff2 feat: auto-chain hook`

**STEP 4 code 결과**:
- L1 schema + L2 bats 5/5 통과, `./tools/run-tests.sh` 전체 PASS
- hook 5 시나리오 검증 완료 (S0→S2 chain / S2→S4 chain / stop_hook_active guard / 관련 없는 tool / save_memory 비-marker)
- 코드 리뷰 4건 모두 APPROVED (최종 2건은 APPROVED WITH CONCERNS — 모두 plan-level 또는 live smoke 로 검증 예정 항목)

**STEP 4 smoke 결과** (2026-04-15, chain-only, InnoDB Buffer Pool 주제):
- `/drllm:launch` 1회 실행으로 S0→S2→S4 자동 체인 ✅
- 사용자 개입 없이 `save_memory` marker 감지 후 hook tailToolCallRequest 로 다음 skill 활성화 2회 성공
- Session artifacts: `metadata.json` (status=tutor, url_verify_ratio=1.0) + `research-results.md` + `learning-log.md` 모두 생성
- **발견된 3 bugs (B1/B2/B3)** — STEP 5 에서 fix 통합 완료 (아래 STEP 5 참조)

### STEP 5 (Task 20~24) — Measurement + B1/B2/B3 통합 fix

| Task | 산출물 | Commit(s) |
|------|--------|-----------|
| 20 | drllm-core §1.2 Timestamp Protocol + §6-8 HARD STOP + S0/S2/S4 shell timestamp | `cf78ede` + `ced0984` (C1+I1 fix) |
| 21 | S2 §7 url_verify contract + §6.1 Citations row count + drllm-core §6-9 | `bc181b5` + `b560a07` (C1+I1 fix) + `589b23e` (report) |
| 22 | `tools/aggregate-metrics.sh` + B1/B2 detection + 3-counter invalid block | `4f56b40` + `79932c7` (I1/I5/I3 fix) |
| 23 | L3 fixtures (3 sessions) + `tests/aggregation/test.sh` | `a55112b` + `4b650bd` (I1+I2 fix) |
| 24 | smoke-step5.md + drllm-core §6-10 B3 HARD STOP + S2 §3.1 fetch-only | `c832d78` + `a7812f6` (I-1+I-3 fix) |
| — | B4 coverage-gap bug + STEP 5 reports archive | `d0884f3` + `a635891` |

**STEP 5 milestone** (Commit Point 5): `c832d78 feat(sp1): Task 24 + B3 v0.1 fix`

**STEP 5 code 결과**:
- drllm-core v2.2 (§1.2 Timestamp Protocol + HARD STOPS 8/9/10 신설)
- aggregate-metrics.sh 작동 중 (실세션 2개에 대해 `[INVALID_TIMESTAMP]` 정확히 감지 확인 — B2 fix 가 통한 증거)
- L3 자동 테스트 활성화 (happy-path 3 fixtures, 합계 P5 score=0.929 / URL verify=0.842 시연)
- 총 12 commits + 10 review report archives
- Review loop 에서 Critical 1건 (Task 20 heredoc command injection), Important 7건 발견 — 전부 fix 후 APPROVED

**STEP 5 smoke 대기**: `tests/manual/smoke-step5.md` — 사용자 interactive Gemini CLI 로 end-to-end 측정 로직 검증 필요.

---

## 3. 남은 Task (9개)

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

M1 1차 smoke 에서 수집된 이슈:

### 5.1 v2.1 Performance Fix — 적용 완료 (2026-04-14 session break)

**Issue #1 — S4 turn 당 평균 5분 지연**:
- 원인: 이벤트당 개별 `echo >> log` shell 호출 (턴당 3~5회) × Gemini CLI confirm round.
- Fix: `drllm-core.md` **§0-8 Batch side effects** 신설 — heredoc/write_file 단일 호출 의무화. S4 SKILL.md §3.4 에 구체 예시 반영.

**Issue #2 — 같은 응답 2번 반복**:
- 원인: SKILL.md §3.4 "평가별 후속 처리" 의 literal template 문구 (`"맞아요. 그럼..."` 등) 가 LLM 에게 "pre-tool 응답 → tool → post-tool 응답 재출력" 패턴 유도.
- Fix: `drllm-core.md` **§6-7 Hard Stop** 신설 — "한 turn 의 사용자 대면 응답은 정확히 한 번만". S4 §3.4 의 template 문구를 *톤 가이드* 로 약화.

**Model routing 적용**:
- 세션 default `gemini-3-pro` 권장 (instruction-following 품질 ↑ → Issue #2 간접 해소).
- `/model gemini-3-pro` 또는 `~/.gemini/settings.json` 에 `"defaultModel": "gemini-3-pro"`.
- Flash/Lite 에 자동 routing 은 Gemini CLI 내부 오케스트레이션에 위임 (현재 smoke 관찰: `gemini-2.5-flash-lite` 4 req + `gemini-3-flash-preview` 7 req).

**재link 필수**: v2.1 적용 후 Gemini CLI 에서 반드시:
```bash
gemini extensions uninstall DRLLM 2>/dev/null
gemini extensions link .
```

### 5.2 v0.5 Refinement 후보 (defer)

1. **Empty-A P5_CHECK invalidation**: S4 가 P5 prompt 발화 직후 `[P5_CHECK] Q=... A="" score=` 를 먼저 append → 사용자 skip → `[P5_SKIP]` 추가. 첫 P5_CHECK (empty A) 가 aggregate count 에 포함되어 total_checks 를 부풀림. **Task 22 aggregate-metrics.sh 에 `A="" 인 P5_CHECK 제외` rule 추가 권고**. (v2.1 §6-7 batch append 로 자연 해소 기대 — M1 2차 smoke 에서 재확인 후 필요 시 rule 추가)
2. **외부 MCP citation 인용 (Open Aware 등)**: S4 가 대화 중 "Open Aware 리서치 결과에 따르면" 처럼 research-results.md 에 없는 외부 MCP citation 인용 가능성. drllm-core §4 + §6-4 정책 강화 (+ BeforeToolSelection hook 으로 외부 MCP 차단) 필요. **v0.5 SP-2 범위**.
3. **중복 SUBTOPIC 이벤트**: 같은 subtopic 이름이 재발동으로 `[SUBTOPIC]` 2회 기록. Task 20+ 에서 dedup rule 검토.
4. **Gemini CLI settings default auto-apply 안됨**: Enter 만으로 default 값 자동 적용 안 됨. `gemini extensions config` 명령으로 명시 설정 필수. README 에 명시.
5. **Long shell command display truncation**: `cat <<EOF` 류 긴 shell 명령이 Gemini UI 에 truncated 표시. 실제 파일은 정상 작성. v0.5 에서는 `write_file` tool 사용 선호.
6. **Subagent 기반 재설계 (model routing B 옵션)**: skill → `.gemini/agents/*.md` 전환하여 skill 별 독립 model 지정 (S2 는 Flash, S0/S4 는 Pro/inherit). Gemini CLI 재귀 subagent 제한 + hook auto-chain 호환성 재검토 필요. **v0.5 SP-2 brainstorming 범위**.

---

## 6. 다음 세션 진입 순서

1. 본 파일 Read (특히 §5.1 v2.1 Performance Fix + §2 STEP 4 결과 확인)
2. **Gemini CLI 재link + hook 등록** (STEP 4 `.gemini/settings.json` 반영):
   ```bash
   cd /home/namykim/workspace/DRLLM && git pull origin feat/sp1-tiny-drllm
   gemini extensions uninstall DRLLM 2>/dev/null; gemini extensions link .
   gemini extensions config DRLLM DRLLM_DOMAIN_PROFILE context/domains/born2beroot.md
   gemini extensions config DRLLM DRLLM_RESEARCH_MAX_SUBQUERIES 4
   ```
3. 세션 모델 고정 (권장): `/model gemini-3-pro`
4. **STEP 4 smoke 실행** (`tests/manual/smoke-step4.md`):
   - `/hooks` 로 AfterTool save_memory hook 등록 + `${workspacePath}` 절대경로 resolve 확인
   - `/drllm:launch "InnoDB Buffer Pool 왜 128MiB?"` 1회로 S0→S2→S4 자동 체인 관찰
   - stderr 에서 `[drllm-hook] S0 done detected` / `S2 done detected` 로그 2줄 확인
   - 합격 조건 4개 검증 (smoke-step4.md 참조)
5. smoke 합격 → Task 20 (STEP 5 Measurement) 진입
6. smoke 실패 → smoke-step4.md 실패 시 섹션 diagnostic path 확인 + `${workspacePath}` 템플릿 키 이슈면 `.gemini/settings.json` 을 절대경로로 교체 (Task 18 plan 재조정)
7. (이하 STEP 5~7 진행은 plan.md 참조)

---

## 7. 핵심 파일 참조

- **Spec**: `docs/superpowers/specs/2026-04-14-sp1-tiny-drllm-design.md`
- **Plan**: `docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` (2400+ lines)
- **Authoritative contract**: `context/drllm-core.md` v2 Robust (§0 Design Principles)
- **SP-0 Final Report**: `docs/superpowers/research/2026-04-12-sp0-final-report.md`
- **Session archive** (M1 1차): `.drllm/sessions/20260414-innodb-buffer-pool-default-size/`
- **Task review archive**: `docs/superpowers/reports/task-{01..15}/`
