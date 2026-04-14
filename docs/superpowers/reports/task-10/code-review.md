# Task 10 Code Review — S2 Protocol Inline Decomposition (Steps 1~3)

- Base SHA: `6c13af5` (feat: register fetch MCP server)
- Head SHA: `0943060` (feat: S2 inline query decomposition (steps 1-3))
- Scope: `skills/drllm-research-execution/SKILL.md` Protocol section expansion (+38 / -11)
- Status: APPROVED (with Minor observations for Task 11/12 follow-up)

---

## 1. Plan Alignment

Literal comparison of `skills/drllm-research-execution/SKILL.md` lines 17–54 against plan Task 10 Step 1 block (lines 719–758 of
`docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md`):

- Protocol header changed from `## Protocol (상세는 Task 10~12에서 확장)` to `## Protocol`: matches.
- `### 1. 세션 로드` 3 bullets: matches verbatim.
- `### 2. 인라인 쿼리 분해 (LLM 호출 1회)` 4-rule list + example subqueries + internal JSON schema block: matches verbatim.
- `### 3. fetch MCP 병렬 호출` 5 bullets (hint_url priority, google_web_search fallback, raw text preservation, single retry,
  research_failed terminal): matches verbatim.
- Trailing "(나머지 섹션 4~9는 Task 11~12에서 확장)" preserved: matches.
- Other sections (`Mission`, `Inputs`, `Hard Gate`, `Outputs`, `See Also`) untouched: confirmed via diff stat (only the Protocol
  block changed).

Step 2 (`./tools/run-tests.sh`) was executed during review and returns PASS (`L1 schema: PASS`, L2/L3 SKIP as expected for
pre-Task-11 state). Step 3 commit message `feat: S2 inline query decomposition (steps 1-3)` matches plan.

**Verdict:** 100% plan-literal implementation. No deviation.

---

## 2. Contract Alignment (drllm-core v2 + spec §2 Q6 B)

### 2.1 §1 세션 로드 vs drllm-core v2 §1.1 `session_id` discovery contract

drllm-core v2 §1.1 specifies a 4-step resolution: (1) explicit argument → (2) `.drllm/sessions/LATEST` pointer file → (3) mtime
descending filter on `status=="research"` → (4) error. The SKILL.md currently encodes only steps (1) + (3) + (4) in a single
sentence ("인자 또는 `status=="research"` 인 가장 최근 항목"). `LATEST` pointer check is omitted.

This is flagged by the submitter as an accepted skeleton-level simplification, with drllm-core being authoritative for the
full contract. That framing is consistent with how spec §2 Q3 B pointer-fixes are handled elsewhere in the repo. Accept as-is;
track as a Task 11/12 or cleanup-phase enhancement: **insert `LATEST` pointer check between steps 1 and 3** when SKILL.md gets
its concrete bash/tool call pattern. Not blocking for Task 10.

### 2.2 §2 LLM call vs §0-1 "LLM 판단 최소화" principle

Query decomposition is a generative task that cannot be made decidable without regressing into template-matching, so invoking
the LLM once here is correct. The containment strategy — emitting a fixed-schema JSON `{subqueries:[{query,hint_url,
source_type_expected}]}` — keeps everything downstream deterministic, which is the right application of the §0-1 principle
(constrain *outputs*, not *presence*, of LLM calls).

The three field names are well-chosen:
- `query` — input to fetch/search.
- `hint_url` — optional first-priority URL; domain profile feeds this.
- `source_type_expected` — enables §4 source discipline downstream (official_docs vs community vs historical).

### 2.3 §2 "메타 질문 금지" boundary

The rule `"X는 무엇인가?" OK / "X의 모든 것" 금지` is LLM-judgment territory but bounded by two concrete examples. Acceptable
for skeleton-grade guidance. Consider adding a third example in Task 11/12 once the Call-1 schema is concrete, e.g.,
`"X의 best practice 전부" → 금지`, so the LLM has at least one borderline case.

### 2.4 §3 fetch fallback: `google_web_search`

`google_web_search` is a Gemini CLI built-in tool per SP-0 research findings; no registration needed in gemini-extension.json.
This matches Task 9 scope (only `fetch` MCP registered). The abstraction `google_web_search` as a symbol is acceptable at
skeleton grade; Task 11/12 or the first integration smoke should verify the exact tool name resolves in Gemini CLI runtime.

### 2.5 §3 failure semantics

- Per-subquery: single retry with an alternative query, then failure recorded. Matches §0-3 "no silent drop".
- Global: all-fail → `status="research_failed"` then terminate. Matches §6-3 HARD STOP (no marker tool emission, which is
  explicitly re-stated in the existing `## Hard Gate` section unchanged below). Consistent.

---

## 3. Code Quality / Document Quality

### 3.1 Nested code-fence rendering

The internal JSON schema is wrapped in ` ```json ` inside a document that Task 10 plan embedded with 4-backtick outer fences.
The committed SKILL.md file itself uses standard 3-backtick fences (the outer fence was a plan-literal artifact), so GitHub
rendering is safe. Confirmed via direct read of SKILL.md lines 36–42.

### 3.2 Terminology: `fetch MCP` vs `mcp_fetch_fetch`

SKILL.md refers to "fetch MCP" abstractly. In the Gemini CLI runtime Task 9 registered it as `mcp_fetch_fetch`. At skeleton
grade the abstract reference is fine — Gemini CLI's MCP router resolves tool calls by capability matching. Task 11/12, when
adding concrete call examples, should use the exact tool ID at least once so the LLM has a disambiguation anchor. Logged as
Minor; non-blocking.

### 3.3 `DRLLM_RESEARCH_MAX_SUBQUERIES` type

§2 references `DRLLM_RESEARCH_MAX_SUBQUERIES` (default 4) without specifying type coercion. Environment variables are strings;
downstream comparison (`subqueries.length <= DRLLM_RESEARCH_MAX_SUBQUERIES`) will need `parseInt` or numeric coercion when Task
13 produces concrete code. This was already noted in Task 1 code review. Acceptable to defer.

### 3.4 APPEND compatibility with Task 11/12

The trailing `(나머지 섹션 4~9는 Task 11~12에서 확장)` line is the only seam Task 11 will need to remove. Nothing in steps
1–3 locks the schema for Call 1 or Call 2. The internal `subqueries[]` JSON will feed Call 1 input cleanly. Structure is
append-friendly.

---

## 4. Issue Summary

### Critical (must fix)
- None.

### Important (should fix)
- None.

### Minor / Follow-up (Task 11/12 or cleanup)
1. Add `.drllm/sessions/LATEST` pointer check as resolution step 2 in §1 once concrete code is written (drllm-core v2 §1.1
   compliance).
2. Verify `google_web_search` tool name resolution in Gemini CLI runtime during the first integration smoke.
3. Replace abstract `fetch MCP` with `mcp_fetch_fetch` in at least one concrete call example when Task 11/12 lands.
4. Specify `parseInt(DRLLM_RESEARCH_MAX_SUBQUERIES || "4", 10)` when Task 13 produces concrete code.
5. Optional: add a third boundary example for the "메타 질문 금지" rule in Task 11/12.

---

## 5. What Was Done Well

- Plan-literal implementation, no drift.
- Tests executed (L1 schema PASS), commit message matches plan prescription.
- Section boundaries respect Task 11/12 append pattern — no forced rewrites downstream.
- Internal JSON schema fields are minimal and purposeful (query / hint_url / source_type_expected), serving both §4 source
  discipline and Call-1 input hand-off.
- Failure semantics (per-subquery retry + global `research_failed` + HARD STOP) consistent with §0-3 and §6-3 without
  re-stating them inline — leverages existing `## Hard Gate` section.
- Concrete InnoDB Buffer Pool example triplet grounds the "단일 정답 구체 질문" rule.

---

## 6. Verification Evidence

- Diff inspected: `skills/drllm-research-execution/SKILL.md` +38 / -11, exactly the Protocol block.
- Plan literal match: lines 719–758 of the plan vs lines 17–54 of SKILL.md — identical text.
- Tests: `./tools/run-tests.sh` → `L1 schema: PASS`, overall `Automated tests: PASS`.
- Commit lineage: `6c13af5` → `0943060`, single commit, message matches.

## 7. Final Recommendation

**APPROVED.** Task 10 faithfully implements the plan, respects spec §2 Q6 B and drllm-core v2 contracts at the appropriate
skeleton grade, and leaves clean seams for Task 11/12. The five Minor items are all follow-up concerns for later tasks, not
defects in Task 10.
