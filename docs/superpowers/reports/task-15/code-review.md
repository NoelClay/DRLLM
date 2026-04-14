# Task 15 Code Review — Step 3 Manual Smoke Checklist

- **Base SHA**: `f9361d3`
- **Head SHA**: `8ae8464`
- **Artifact**: `/home/namykim/workspace/DRLLM/tests/manual/smoke-step3.md`
- **Plan reference**: `/home/namykim/workspace/DRLLM/docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` (Task 15, lines 1180-1260)
- **Authoritative spec**: `context/drllm-core.md` §3 (P5.1), §5.1/§5.2 schemas, §6 HARD STOPS

## Status

**CHANGES REQUESTED** (1 Important + 2 Minor; no Critical).

The checklist is fundamentally sound and reflects the v0.1 manual chain accurately. All 5 intentional enhancements over the plan are correctly applied and traceable. Acceptance criteria correctly references drllm-core §3 P5.1. The only material concern is one outdated assumption inherited from the plan (Stage C L7) that contradicts the current S4 protocol that already mandates learning-log writes from Task 14 onward.

---

## Plan Alignment Analysis

### Match against plan (lines 1180-1260)
- Setup, Scenario, Stages A/B/C structure: matches.
- 4 합격 조건 + 5 (now 7) 실패 진단: enhanced per the planned deviations.

### Intentional enhancements (verified)
| # | Enhancement | Location | Justification | Verdict |
|---|---|---|---|---|
| a | `gemini extensions uninstall DRLLM 2>/dev/null;` before `link .` | Setup L7 | Task 8 smoke-step2 review lesson — `link` fails if already linked | Beneficial, keep |
| b | "`unlink` 명령 없음" Note | L11 | Gemini CLI v0.37.1 reality | Beneficial, keep |
| c | "T1~T4 structural trigger" wording in Stage C | L55 | drllm-core v2 §3 P5.1 (replaces old "subtopic 완료 감지") | Beneficial, keep |
| d | 합격 조건에 drllm-core §3 P5.1 reference | L64 | Authoritative source pointer | Beneficial, keep |
| e | 진단 5→7 (재link, Settings) | L68, L74 | User-experienced failure modes | Beneficial, keep |

All deviations are improvements and correctly aligned with drllm-core v2 / Task 8 / Task 14.

---

## Code Quality Assessment

### Strengths
1. **Evidence-first verification commands**. Stage A/B verify state by reading files (`ls`, `jq`, `cat`) rather than asking the operator to "trust the chat output". Aligns with §0-2.
2. **Schema-grounded field assertions**. `status`, `slug`, `started_at`, `url_verify_ratio` match `drllm-core.md` §5.1 metadata schema; `Summary / Key Points / Citations (verified column)` matches §5.2 research-results.md schema.
3. **Rollback routing**. Each 실패 진단 line points to a concrete Task number. Operator can locate the implementation locus without re-reading the spec.
4. **Test isolation**. `rm -rf .drllm/sessions/` is safe — `.gitignore` line 142 covers `.drllm/`. No risk of repo pollution.
5. **Acceptance threshold realism**. "≥ 1 verified=true" and "≥ 1 P5 발동" are minimum-viable bars appropriate for v0.1 first end-to-end smoke.

### Issues

#### Important (should fix before running smoke)

**I-1. Stage C L57 `learning-log.md 확인 (이벤트 기록 여부 — Task 20 에서 explicit contract 추가될 예정)` is stale.**
- File: `/home/namykim/workspace/DRLLM/tests/manual/smoke-step3.md` line 57
- Reality: The current `skills/drllm-adaptive-tutoring/SKILL.md` (Task 14) already mandates `learning-log.md` writes — see SKILL.md §2 (initialize), §3.2 `[SUBTOPIC]`, §3.3 `[SOURCE]`, §3.4 `[P5_CHECK] / [P5_SKIP] / [P5_MISSING]`, §4 `[COMPLETE]`. Task 14 makes S4 the authoring agent of `learning-log.md`; Task 20 only adds the **hook-based** event-recording automation around it.
- Effect on operator: If they treat "아직 기록 안 됨" as the expected outcome, an actually-empty `learning-log.md` will pass the checklist when it should fail (P5 발동했는데 기록 안 됨 = §6-1 위반).
- Recommended replacement:
  > `learning-log.md` 존재 확인 + 다음 이벤트 중 최소 1종 기록 확인:
  > `[SUBTOPIC]`, `[SOURCE]`, `[P5_CHECK] / [P5_SKIP] / [P5_MISSING]` (drllm-core §5.3).
  > 자동 hook 기록은 Task 20 부터; v0.1 에서는 S4 LLM 이 직접 append.
- This is the single largest risk to the smoke being meaningful.

#### Minor

**M-1. Stage B L33 "서브쿼리 표시" assumption may be false in current S2 protocol.**
- The plan-level wording was inherited verbatim. drllm-research-execution `SKILL.md` §2 specifies the subquery list is internal JSON and **not necessarily user-visible**.
- Suggested phrasing: change "(LLM 출력에 서브쿼리 표시)" to "(직접 출력 또는 fetch tool_use 로그의 다중 URL 호출로 간접 확인)".
- Acceptable to ship as-is for v0.1 since the next bullet (fetch tool_use 로그) provides the secondary signal.

**M-2. No explicit `[COMPLETE]` line check.**
- Stage C does not verify the `[COMPLETE] total_checks=<N> correct=<C> partial=<P> skip=<S> missing=<M> duration_sec=<D>` event format that drllm-core §5.3 mandates. Coverage will arrive in Task 20/22 aggregation tests, so omitting from v0.1 skeleton is acceptable. Flag for follow-up only.

### Suggestions (optional, no action required)

- Adding a final "Cleanup / Reset" section (e.g., `gemini extensions uninstall DRLLM`) would help operators avoid leaking link state across smoke runs. v0.5+ candidate.
- Stage B L36 "Layer 2 Call 2 → verified 필드 확인" could specify the exact JSON key name (`verified: true|false`) and where it appears (Citations table column). Cosmetic.

---

## Architecture / Design

- **Separation of concerns**: Checklist correctly delegates "how" to per-Task implementation; it only asserts observable outputs. Good test-isolation property.
- **Traceability**: Every assertion maps to a spec section or Task number. Reviewer/operator can recover full context from the checklist alone.
- **Scalability**: When Task 20 hook lands, only Stage C L57 needs to flip from "manual append" to "hook-driven append" verification. The current text (after I-1 fix) is forward-compatible.

---

## Documentation / Standards

- Korean usage is consistent with rest of `tests/manual/` (smoke-step2 idiom).
- Markdown checkbox counts: Stage A 4 / Stage B 7 / Stage C 7 = 18. Matches description.
- 합격 조건 4 + 실패 진단 7. Matches description.
- File header says "수동 체인, hook 없음" which matches v0.1 scope.

---

## Recommendations Summary

| Priority | Action |
|---|---|
| Important | Fix Stage C L57 to reflect Task 14's S4 → `learning-log.md` write contract (drllm-core §5.3). |
| Minor | Soften Stage B L33 subquery-visibility wording; mention indirect signal via fetch logs. |
| Minor | Add a follow-up note (or backlog item) for `[COMPLETE]` event verification — defer to Task 20/22. |
| Suggestion | Add Cleanup section for future re-runs (v0.5+). |

After the I-1 edit, the checklist is ready for execution as the M1 micro-POC milestone smoke.
