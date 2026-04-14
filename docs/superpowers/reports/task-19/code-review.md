# Task 19 Code Review — smoke-step4.md

**Verdict**: APPROVED WITH CONCERNS (doc quality)

**Base** `1f76bb5` → **Head** `7221ff2`
**Artifact**: `tests/manual/smoke-step4.md` (42 lines, pure markdown checklist)
**Plan reference**: `docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` lines 1472–1528

---

## 1. Plan alignment

Verbatim match against plan lines 1482–1523. All sections present and in order:
- Setup (uninstall-then-link + session cleanup) — matches post-`1f76bb5` revision
- 사전 검증 (Task 18 gate) — `/hooks` registration + `${workspacePath}` resolve check
- 단일 명령으로 end-to-end — launch + S0→S2→S4 chain observation + stderr log pattern
- 합격 조건 (4 items)
- 실패 시 (4 diagnostic paths)

No deviations, no missing items. Author followed the plan-sync amendments from commit `1f76bb5` (uninstall-before-link, workspacePath verify).

## 2. What's done well

- **Task 18 gate is explicit** (section header literally says "Task 18 gate"). A user who forgot about hook installation is caught before the end-to-end run, avoiding misdiagnosis.
- **workspacePath resolution check is actionable**: if the literal `${workspacePath}` string appears, the doc immediately points to "Gemini CLI v0.37.1 템플릿 키 미스매치 → plan 재확인". This is the single most likely failure mode for a declarative-hook approach, and it's front-loaded.
- **Failure paths route to specific tasks**: Task 18 (hook registration), Task 16 (stop_hook_active + JSON schema). Each is concretely addressable.
- **Setup is idempotent**: `gemini extensions uninstall DRLLM 2>/dev/null; gemini extensions link .` safely handles both first-run and re-link. `rm -rf .drllm/sessions/` ensures a clean artifact-diff surface.
- **Tone/format consistent** with smoke-step3.md (Korean headings, bracketed gates, 합격 조건 / 실패 시 structure).

## 3. Issues

### Important (should fix before STEP 5)

**I1. "정상 완료" in 합격 조건 #4 is undefined.**
> - hook 무한 루프 없음 (세션이 정상 완료됨)

What observable signal marks "정상 완료"? In step3, completion is implicit in "세 단계 모두 에러 없이 완료". Here, since chain is automatic, the reader needs a concrete terminal event — e.g., "Gemini TUI returns to prompt after S4 첫 응답 출력" or "hook log stops at `S2 done detected`, no further chain lines". Without a terminal signal, "무한 루프 없음" can't be distinguished from "long-running" by a returning reader. **Recommend**: add explicit terminal condition (e.g., "S4 첫 응답 이후 hook 로그에 추가 chain 라인 없음, `/hooks` stop_hook_active=false 상태 복귀").

**I2. stderr 관찰 위치 미지정.**
> - [ ] stderr 에서 hook 로그 확인: `[drllm-hook] S0 done detected → ...`

Where does a user see stderr inside the Gemini CLI TUI? v0.37.1 에서 hook stderr 는 TUI footer? log file (`~/.gemini/logs/`)? `/hooks` output? A new reader will not know where to look. **Recommend**: one line — e.g., "stderr 는 Gemini CLI 실행 터미널에 직접 출력됨 (TUI 하단 스크롤), 또는 `tail -f ~/.gemini/logs/...` ". This is a Task 16 contract question; if unclear, note it as a Task 20 measurement point.

**I3. 합격 조건 #3 의 검증 커맨드 부재 (step3 와 불일치).**
Step3 제공:
```bash
ls .drllm/sessions/
jq '.status, .url_verify_ratio' .drllm/sessions/*/metadata.json
```
Step4 합격 조건 #3 ("metadata.json + research-results.md 모두 생성") 은 커맨드가 없다. 일관성을 위해 동일한 `ls` / `jq` 한 줄씩 추가 권장.

**I4. 환경변수 전제조건 누락.**
step3 의 실패 시 마지막 항목("Settings [not set]: gemini extensions config DRLLM DRLLM_DOMAIN_PROFILE ...") 가 step4 에는 없다. 만약 `DRLLM_DOMAIN_PROFILE` / `DRLLM_RESEARCH_MAX_SUBQUERIES` 가 unset 인 상태로 smoke 를 실행하면, S2 가 실패하고 chain 이 S4 까지 안 간다. 증상은 "자동 체인 안 됨" 으로 보여 → "Task 18 재확인" 으로 오진단된다 (실제 원인은 환경 설정). **Recommend**: 실패 시 항목에 "환경변수 미설정 시: gemini extensions config ... (smoke-step3.md 참조)" 한 줄 추가.

### Suggestions (nice to have)

**S1. "research 진행 표시" 모호함.**
> 관찰: S0 실행 후 사용자 개입 없이 자동으로 S2 활성화 (Gemini 출력에 "S2 activate" 로그 또는 research 진행 표시)

"research 진행 표시" 가 무엇인지 — fetch tool_use 로그? subquery enumeration? — 명시하면 판정이 확실해진다. step3 의 "Layer 2 Call 1 → JSON 응답 확인" 수준 구체성.

**S2. `learning-log.md` 검증 부재에 대한 의도 표기.**
step3 는 `learning-log.md` 및 P5_CHECK 이벤트를 검증한다. step4 는 검증하지 않는다. 의도적(step4 = chain mechanics only, tutoring content 는 step3 에서 검증 완료) 이라면 한 줄 주석 권장 — 예: "> Note: S4 tutoring 내용 검증은 step3 에서 완료. 본 smoke 는 chain 전이(S2→S4)만 확인."

**S3. 실패 시 #4 의 용어 오탈자 가능성.**
> - tailToolCallRequest 오류: JSON schema 재확인 → Task 16 hook output

`tailToolCallRequest` 가 Gemini CLI 의 정확한 에러명인지 확인 필요. v0.37.1 hook 문서는 `ToolCallRequest` 페이로드를 사용. 오탈자라면 `ToolCallRequest` 로 교정 권장. (계획 문서와 1:1 이라 plan 쪽 수정이 필요할 수도 있음 — 먼저 Task 16 구현체의 실제 에러 문자열과 대조.)

### Critical

None. The artifact is non-executable documentation; no correctness risk, no security surface. All issues above are clarity/completeness concerns that improve smoke reliability but do not block STEP 4 milestone.

## 4. No findings

- No TBD / TODO / FIXME markers.
- No duplication with smoke-step3.md (different scope: step3 = manual chain, step4 = auto chain).
- Markdown structure is valid (no broken code-fences despite outer triple-backtick in plan — author correctly unwrapped the plan's embedded markdown).

## 5. Recommendation

Approve the commit as STEP 4 milestone. Address I1–I4 as a follow-up doc polish pass either:
- (a) before executing the smoke (to avoid mid-run ambiguity), or
- (b) as a Task 20 pre-work item — Task 20 introduces measurement/logging contracts which will anyway force I1 and I2 to be resolved with authoritative answers.

Path (b) is acceptable if the author commits to revisiting this doc alongside Task 20's logging spec.

## 6. Files referenced

- `/home/namykim/workspace/DRLLM/tests/manual/smoke-step4.md` — reviewed artifact
- `/home/namykim/workspace/DRLLM/tests/manual/smoke-step3.md` — format/tone precedent
- `/home/namykim/workspace/DRLLM/docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` lines 1472–1528 — plan source

---

## Re-Review After I1-I4 Fix

**Date**: 2026-04-14
**Range**: `7221ff2` → `66ff871`
**Verdict**: APPROVED

### Resolution status

| ID | Original concern | Fix location (smoke-step4.md) | Plan mirror | Status |
|----|------------------|-------------------------------|-------------|--------|
| I1 | "정상 완료" undefined | Line 40: "S4 첫 응답 출력 후 hook 로그에 추가 chain 라인 없음, Gemini TUI가 사용자 입력 대기 상태로 복귀" | Line 1521 ✓ | Resolved |
| I2 | stderr 관찰 위치 미지정 | Line 24: "Gemini CLI를 실행한 터미널의 stderr — TUI 외부 스크롤 영역 또는 `GEMINI_DEBUG=1` 로 재실행"; Line 29 fallback note | Line 1505, 1510 ✓ | Resolved (pragmatic) |
| I3 | 합격 조건 #3 검증 커맨드 부재 | Lines 36–39: `ls .drllm/sessions/*/` + `jq '.status, .url_verify_ratio'` | Lines 1517–1520 ✓ | Resolved |
| I4 | 환경변수 전제조건 누락 | Line 48: `DRLLM_DOMAIN_PROFILE` / `DRLLM_RESEARCH_MAX_SUBQUERIES` diagnostic with exact `gemini extensions config` commands | Line 1529 ✓ | Resolved |

All four Important issues resolved with observable-signal content (not hand-waves).

### Plan ↔ smoke doc parity

Plan section `Task 19 (lines 1472–1540)` now matches smoke doc verbatim. Diff structures are symmetric (identical +/- blocks at both files). Commit `66ff871` kept plan in sync as required.

### I2 fix nuance

The fix acknowledges stderr location uncertainty by offering (a) TUI outer scroll area, (b) `GEMINI_DEBUG=1` re-run, (c) fallback to Task 16's `echo >&2` verification. This is pragmatic — it doesn't claim authoritative knowledge of Gemini CLI v0.37.1's stderr routing but gives the smoke runner a deterministic escape hatch. Task 20's logging contract will eventually pin this down; acceptable as-is.

### Suggestions S1–S3 deferral

S1 (research 진행 표시 모호), S2 (learning-log intent note), S3 (`tailToolCallRequest` typo check) explicitly deferred per prior reviewer's own "path (b)" recommendation. Confirmed reasonable — S1/S2 are clarity polish, S3 requires cross-checking Task 16 implementation string which is out of scope for this doc-only task.

### New issues introduced

None. Markdown structure remains valid (nested code fences unwrap correctly), plan parity maintained, failure diagnostics remain internally consistent.

### Files referenced

- `/home/namykim/workspace/DRLLM/tests/manual/smoke-step4.md` — updated artifact (49 lines)
- `/home/namykim/workspace/DRLLM/docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` lines 1472–1540 — synced plan section
