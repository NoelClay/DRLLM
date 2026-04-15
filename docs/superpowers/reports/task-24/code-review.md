# Task 24 + B3 v0.1 Code Review

**Reviewer**: Senior Code Reviewer
**Date**: 2026-04-14
**Base SHA**: d0884f3
**Head SHA**: c832d78
**Branch**: feat/sp1-tiny-drllm
**Scope**: Task 24 (STEP 5 smoke) + B3 v0.1 preventive fix

## Verdict

**🟡 APPROVED WITH CONCERNS** — all implementation is substantively correct and aligns with plan + B3 fix plan. No changes blocking Commit Point 5. Two documentation-ergonomics concerns (Important) + three Suggestions to consider at SP-2 retrofit time.

---

## What Was Done Well

- **Plan-literal fidelity**: Scope A setup (uninstall-before-link), learning-log event list, metadata jq probe, and failure-triage section all match plan lines 1991-2080 word-for-word except for the two documented adaptations (uninstall precedent + 3-counter format).
- **Consistency with precedent**: `smoke-step5.md` follows the exact structure of `smoke-step3/4.md` — Setup → Scenario → 파일 검증 → 합격 조건 → 실패 시. No drift.
- **Defensive documentation**: §3.1 explicitly calls out `fetch → GoogleSearch` fallback as forbidden, addressing the actual observed drift mechanism from B3.md.
- **Proper forward-reference discipline**: HARD STOP-10 names v0.5 SP-2 BeforeToolSelection hook as the enforcement mechanism, so the v0.1/v0.5 split is explicit.
- **Aggregate code comment alignment**: `tools/aggregate-metrics.sh:33` already contains the pre-populated comment `# B3 EXTERNAL_TOOL_LEAK: preventive in Task 24 — no aggregate detection here.` — the contract and the script agree on the v0.1 scope.
- **Bug tracker state hygiene**: B3 status flipped in both bug file and README index — no split-brain.
- **Test gate**: L1+L2+L3 all PASS preserved (implementer.md lines 54-68).

---

## Findings by Severity

### Critical

None.

### Important

#### I-1. `[EXTERNAL_TOOL_LEAK]` is a specification-only event — reader may expect detection

**File**: `context/drllm-core.md:259` + `tests/manual/smoke-step5.md:45-52`

HARD STOP-10 states: "aggregate 에서 `[EXTERNAL_TOOL_LEAK] session=<id> tool=<name>` 이벤트 기록 후 세션 측정 무효화."

Reader workflow: (1) reads HARD STOP-10, (2) expects aggregate to emit `[EXTERNAL_TOOL_LEAK]`, (3) greps aggregate output and finds nothing, (4) assumes a bug.

The smoke doc (lines 48-52) does partly clarify with "현재 v0.1 — aggregate 에서는 미감지, preventive rule 만 적용". But HARD STOP-10 itself reads as present-tense detection. The aggregate script's comment at line 33 is also internal-only — users running `aggregate-metrics.sh` see no trace.

**Recommendation**: Add an inline v0.1 scope note inside HARD STOP-10 itself, e.g., append `[v0.1 note: preventive only — aggregate event `[EXTERNAL_TOOL_LEAK]` reserved for SP-2 retrofit]`. This keeps the spec forward-compatible while preventing reader confusion, and matches the discipline used in `§1.2 Timestamp Acquisition Protocol (v2.2 B2 fix)` which version-tags its introduction.

#### I-2. Smoke does not exercise the new HARD STOP-10 rule

**File**: `tests/manual/smoke-step5.md:45-52`

The B3 check is phrased negatively: "`GoogleSearch` / `WebFetch` 라인 없음" → pass. This is correct for v0.1 (no enforcement hook yet), but the **absence** of a positive-path test means: if a future regression causes S2 to call GoogleSearch, the smoke would only catch it via manual grep of stdout. Given that no Gemini session log is currently captured per-session (line 49 shows `<gemini-session-log>` placeholder), this is effectively untestable in CI-style automation.

This is not a Task 24 scope bug — plan did not require it — but it should be tracked:

**Recommendation**: Either (a) note explicitly in B3.md that "Verification in v0.1 is observational only; real verification deferred to SP-2 hook" (already implied in B3.md Fix Plan but not restated in smoke), or (b) add a log-capture step `GEMINI_DEBUG=1 gemini ... 2>gemini-run.log` in Setup so the grep target in line 49 is actually defined. Option (b) is cheap and removes the `<gemini-session-log>` placeholder ambiguity.

### Suggestions (nice to have)

#### S-1. HARD STOPS section is now 10 items — nearing readability limit

**File**: `context/drllm-core.md:244-259`

The section has grown organically: items 1-6 (v0.1 original) → 7 (v2.1 single-response) → 8 (v2.2 B2 timestamp) → 9 (v2.2 B1 citations) → 10 (v0.1 B3 fetch-only). The items now span categories: P5 flow (1,2), citations integrity (3,4,9), state transitions (5,6), response discipline (7), acquisition discipline (8), tool allowlist (10).

**Recommendation (defer to SP-2)**: When adding item 11+, reorganize into sub-groups like:
- §6.A Flow integrity (1,2,7)
- §6.B Evidence integrity (3,4,5,8)
- §6.C State machine (6)
- §6.D Tool discipline (9,10)

Do not refactor now — it would create unnecessary churn and break cross-references (e.g., SKILL.md §3.1 cites "§6-10" by number).

#### S-2. §3.1 introduces `start_index` without linking to fetch MCP docs

**File**: `skills/drllm-research-execution/SKILL.md:62`

`start_index` is a parameter of the `fetch` MCP tool but appears only here — no other place in the repo defines when/why `content_truncated` happens or what a valid `start_index` value range is. A reader would need to know `fetch` MCP spec externally.

**Recommendation**: Either link to fetch MCP README, or add a one-line example like `(e.g., start_index=5000 to continue after 5000-char prefix)`. Optional — the current audience (implementer + reviewer) likely knows this.

#### S-3. Aggregate expected-output block lacks "exact match" framing

**File**: `tests/manual/smoke-step5.md:64-83`

The block uses `<N>` placeholders but doesn't clarify whether the checker should match the **literal text surrounding** (column widths, colon alignment, dashes) or just the semantic presence of each line. Current aggregate-metrics.sh formatting is sensitive to column alignment (e.g., `[P5_MISSING]:             0` with padded spacing).

**Recommendation**: Add a note like "공백 정렬은 aggregate-metrics.sh printf 포맷에 의존 — 정확한 문자열 비교 대신 각 라벨 존재 여부로 판정" under the expected output block. Optional; the human runner can likely infer this.

---

## Plan Alignment Verification

| Plan element | Implementation | Status |
|--------------|----------------|--------|
| Setup `rm -rf .drllm/sessions/` + `gemini extensions link .` | Replaced with `uninstall 2>/dev/null; link` | ✅ Documented adaptation (smoke-step3/4 precedent) |
| `[SUBTOPIC]` / `[SOURCE]` / `[P5_CHECK]` / `[P5_SKIP]` / `[COMPLETE]` enumeration | All 5 present lines 27-31 | ✅ Exact |
| metadata.json jq probe: `url_verify_total, url_verify_count, url_verify_ratio, status, completed_at` | Line 35 | ✅ Exact |
| `status == "done"` assertion | Line 40 | ✅ Exact |
| `completed_at` non-null | Line 41 | ✅ Exact |
| Aggregate expected output | Updated to 3-counter format (plan-original was simpler) | ✅ Required adaptation — plan predated Task 22 Scope B |
| Failure triage lines (Task 20/21/22 refs) | Lines 97-99 preserved | ✅ Exact |
| B1/B2/B3 verification (NOT in plan literal) | Added lines 43-59 | ✅ Correct additive — matches Task 22 Scope B + B3.md fix |

**Scope B (B3) alignment with B3.md Fix Plan v0.1**:

| B3.md v0.1 requirement | Implementation | Status |
|------------------------|----------------|--------|
| `S2 SKILL.md §3 에 명시 금지 추가` | §3.1 added with fetch-only + prohibition list | ✅ |
| Domain profile URL fallback | Line 60 of SKILL.md | ✅ |
| `verified=false` skip on missing URL | Line 60 ("해당 citation 을 verified=false 로 표시") | ✅ |
| `drllm-core.md §6 HARD STOP 추가` | HARD STOP-10 added | ✅ |
| `[EXTERNAL_TOOL_LEAK]` event name | Matches B3.md text exactly | ✅ |
| Numbered as #9 in B3.md | Numbered as #10 (B3.md predated HARD STOP-9 B1 fix) | ✅ Correct — numbering adjusted for insertion order |

---

## Consistency Checks (from review request)

### Q1: Does HARD STOP-10 mislead with `[EXTERNAL_TOOL_LEAK]` reference?

**Answer**: Partially misleading. The text reads as present-tense enforcement but aggregate does not emit this event. Forward-reference discipline needs an inline version marker. See I-1.

### Q2: Does §3.1's `start_index` duplicate existing Protocol text?

**Answer**: No duplication. Verified via grep: `start_index` and `content_truncated` appear only in `SKILL.md:62`. §3.1 is the first (and only) place defining the retry allowance. No conflict.

### Q3: Does the "GoogleSearch 로 우회 금지" phrase imply a previously-encouraged fallback?

**Answer**: Protocol §3 line 49 contains the legacy text: `"hint_url 이 없거나 응답이 빈 경우: web 검색(google_web_search)을 hint_url 생성용으로 사용 후 top-3 fetch"`. §3.1 contradicts this by forbidding external search.

**This is a real ambiguity**: §3 says "if no hint_url, use google_web_search", §3.1 says "don't use GoogleSearch". The reader must infer that §3.1 overrides §3 (by being a later/narrower rule), but this is not stated.

**Recommendation**: At Task 24 close or in SP-1 cleanup, either (a) strike the google_web_search clause from §3, or (b) add a §3 footnote `(단, §3.1 v0.1 제한 참조 — GoogleSearch 우회 금지)`. Promoting this from suggestion to **Important** if the implementer hasn't considered it.

**Upgrading to I-3** — see below.

#### I-3. §3 line 49 and §3.1 line 60 contradict each other

**File**: `skills/drllm-research-execution/SKILL.md:49` vs `:54-62`

§3 line 49: `"hint_url 이 없거나 응답이 빈 경우: web 검색(google_web_search)을 hint_url 생성용으로 사용 후 top-3 fetch"`

§3.1 line 60: `"fetch 실패를 GoogleSearch 로 우회 금지"`

These are contradictory. A reader following §3 strictly would call `google_web_search`; a reader following §3.1 would not. Precedence is unstated.

**Recommendation**: Before Commit Point 5 land, either:
- (a) Strike the `google_web_search` clause in §3 line 49 and replace with "hint_url 이 없으면 domain profile URL 사용 (§3.1 참조). 부족하면 서브쿼리 skip."
- (b) Add `(단, §3.1 참조 — v0.1 에서는 GoogleSearch 금지)` inline at §3 line 49.

Option (a) is cleaner. Option (b) preserves history. Either is fine.

### Q4: Does smoke-step5 "나중에" match drllm-core §3 P5.4 skip pattern?

**Answer**: Yes — verified. drllm-core.md:156: `^(?i)(넘어가|다음|pass|skip|나중에|됐어|건너뛰|그냥 계속)`. "나중에" is an exact token. ✅

---

## Documentation Quality

- **Preventive vs detective distinction**: HARD STOP-10 itself mixes the two (preventive rule for LLM, detective event for aggregate). A first-time reader might not distinguish. Explicit v0.1/v0.5 tagging (see I-1) would solve this.
- **smoke-step5 structure vs smoke-step3/4**: Structurally consistent (Setup → Scenario → 파일 검증 → aggregate 실행 → 합격 조건 → 실패 시). smoke-step5 is longer (102 lines vs 80) due to B1/B2/B3 checks, but the additive structure is clean. ✅
- **HARD STOPS readability**: 10 items is the empirical threshold where flat lists start to hurt. Not yet broken. See S-1.

---

## Negative-space Check

- **Did smoke include `[EXTERNAL_TOOL_LEAK]` detection step?** No, and correctly so (aggregate doesn't detect it). The doc correctly says "현재 v0.1 — aggregate 에서는 미감지" (line 52). ✅
- **Did smoke ask user to trigger GoogleSearch to test STOP-10?** No, and correctly so (v0.1 is rule-only, no enforcement; user can't observe STOP firing). The smoke instead uses absence-of-GoogleSearch as the check, which is the right v0.1 approach. ✅
- **Did smoke cover all 6 event types from drllm-core §5.3?** Covered: `[SUBTOPIC]`, `[SOURCE]`, `[P5_CHECK]`, `[P5_SKIP]`, `[COMPLETE]`. Missing: `[P5_MISSING]` (intentional — healthy session should not have missing). Aggregate check line 58 validates `[P5_MISSING]: 0` which is the inverse assertion. ✅

---

## Architecture & Design

- **Separation of concerns**: Contract (drllm-core §6) vs skill rule (SKILL.md §3.1) vs runner (smoke-step5.md) vs detector (aggregate-metrics.sh). Each layer holds one responsibility. ✅
- **Forward-compatibility**: v0.5 SP-2 BeforeToolSelection hook is named in both HARD STOP-10 and B3.md Fix Plan, creating a clear retrofit path. ✅
- **Open/closed**: Adding item 11 to §6 later requires no refactor (see S-1).

---

## Plan Deviations Summary

| Deviation | Justified? | Disposition |
|-----------|-----------|-------------|
| Setup uninstall-before-link | Yes — smoke-step3/4 precedent | Keep as documented |
| 3-counter aggregate output | Yes — plan predated Task 22 Scope B | Keep |
| B1/B2/B3 verification sections (additive) | Yes — fills gaps the plan was silent on | Keep |
| B3 v0.1 preventive fix added in this task | Plan lines 1991-2080 did not include; separate Fix Plan in B3.md | Acceptable — reviewer should confirm scope creep is intentional |

**Scope creep note**: Task 24 plan was originally scoped to Scope A only (smoke-step5.md). Scope B (B3 fix) was added. This is fine because:
1. B3 is v0.1 preventive-only (documentation changes, no code behavior change beyond LLM instruction)
2. Without B3 preventive, the smoke's "B3 clean" check would be vacuous
3. B3.md explicitly plans v0.1 at SKILL.md + drllm-core edits, which match what was implemented

Recommend the coding agent confirm that the implementer.md "2 documented adaptations" count should really be "3" (adaptation #3 = Scope B addition).

---

## STEP 5 Milestone Readiness

**READY** to proceed to Commit Point 5 with the following follow-ups (non-blocking):

1. **Before commit** (strongly recommended): Resolve I-3 (§3 vs §3.1 contradiction) — a one-line edit. Leaving this creates a ticking bomb for the next S2 smoke run.
2. **At commit** (recommended): Add v0.1 note to HARD STOP-10 per I-1 — prevents reader confusion.
3. **Defer to SP-2**: S-1 (HARD STOPS reorganization), I-2 (log capture for smoke), aggregate `[EXTERNAL_TOOL_LEAK]` retrofit.

All L1+L2+L3 tests pass. Bug tracker state is consistent. smoke-step5.md is runnable end-to-end.

---

## Report Path

`/home/namykim/workspace/DRLLM/docs/superpowers/reports/task-24/code-review.md`

---

## Re-Review After I-1+I-3 Fix

**Date**: 2026-04-14
**Commit**: `a7812f6`
**Scope**: 2 files / 2 insertions / 2 deletions

### Verification Results

1. **S2 SKILL.md §3 line 49 (I-3)** — VERIFIED FIXED
   - `google_web_search` no longer referenced as a search-to-then-fetch fallback.
   - New fallback chain: `hint_url` → `context/domains/<domain>.md` version-pinned URL → skip + `verified=false`.
   - Explicit pointer to §3.1 + drllm-core §6-10 inline ("**web 검색(GoogleSearch/google_web_search) 호출 금지**").
   - §3.1 ban content unchanged.
   - Retry-once-then-research_failed path preserved (lines 51-52).

2. **drllm-core §6-10 line 259 (I-1)** — VERIFIED FIXED
   - `[EXTERNAL_TOOL_LEAK]` now tagged "**v0.5 retrofit 예정**" with parenthetical explanation that aggregate-metrics.sh does not collect per-session tool-call logs.
   - v0.1 enforcement clarified: "skill-level rule + 코드 리뷰로만 강제".
   - BeforeToolSelection hook still mentioned as SP-2 (v0.5) future work.

3. **Test suite (`./tools/run-tests.sh`)** — PASS
   - L1 schema PASS; L2 hooks 5/5 ok; L3 aggregation PASS.

4. **Commit hygiene (`git show --stat a7812f6`)** — CLEAN
   - Minimal diff (2 files, +2/-2), scope-matched commit message, I-1 and I-3 rationale documented.

5. **No regression in §3 fallback logic** — CONFIRMED
   - `hint_url` still tried first.
   - 1회 재시도 (line 51) and `status="research_failed"` termination (line 52) paths unchanged.
   - Domain profile version-pinning is consistent with §3.1 guidance (lines 58-60).

### Remaining Concerns

- **Informational only**: `[EXTERNAL_TOOL_LEAK]` detection deferred to SP-2 v0.5 is now explicit in the doc — this is a documentation-level honesty fix, not a capability gain. Enforcement in v0.1 relies on (a) the skill-level ban text and (b) human code review. Accepted as an intentional v0.1 scope boundary.
- No new issues introduced by the patch.

### Verdict

**APPROVED** — both I-1 and I-3 resolved; no regressions detected.

- I-1 status: RESOLVED (wording aligned with aggregate-metrics.sh capability; v0.5 retrofit path documented)
- I-3 status: RESOLVED (fallback chain no longer contradicts §3.1; domain profile URL is now the sole non-hint fallback)
- STEP 5 milestone readiness: READY (SP-1 Task 24 unblocked for STEP 5 smoke/demo)

