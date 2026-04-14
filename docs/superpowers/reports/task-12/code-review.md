# Task 12 Code Review — S2 Protocol §5~§9 (Call 2 + research-results.md + marker)

- **Base SHA**: `6d17187`
- **Head SHA**: `44dfc39`
- **Scope**: `skills/drllm-research-execution/SKILL.md` (+65, -1)
- **Reviewer**: Senior Code Reviewer
- **Date**: 2026-04-14
- **Status**: APPROVED

---

## 1. Plan Alignment

Plan block at `docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md:836-923` specifies the verbatim markdown payload to append. Comparison table:

| Plan requirement (Task 12) | Implementation location | Status |
|---|---|---|
| §5 heading `Layer 2 Call 2 — 교차 검증` | SKILL.md:96 | OK |
| §5 opening sentence "Call 1의 citations 배열과 fetch 결과 raw text를 함께 LLM에 전달" | SKILL.md:98 | OK |
| §5 blockquote (a) url check | SKILL.md:103 | OK |
| §5 blockquote (b) quote substring with normalize 허용 | SKILL.md:104 | OK |
| §5 blockquote verified assignment rule + reason | SKILL.md:105 | OK |
| §5 blockquote schema preservation | SKILL.md:106 | OK |
| §6 heading `후처리 — research-results.md 작성` | SKILL.md:108 | OK |
| §6 verified=false 제거 rule | SKILL.md:110 | OK |
| §6 url_verify_total/count/ratio 정의 + 소수점 3자리 | SKILL.md:111-113 | OK |
| §6 frontmatter 4 fields | SKILL.md:118-122 | OK |
| §6 본문 순서 Summary → Key Points → Citations | SKILL.md:125-132 | OK |
| §6 Citations 테이블 5 컬럼 + ✅/❌ | SKILL.md:133-137 | OK |
| §7 metadata.json 갱신 JSON snippet | SKILL.md:142-149 | OK |
| §7 status="tutor" 전이 | SKILL.md:148 | OK |
| §8 한국어 blockquote 사용자 보고 | SKILL.md:154 | OK |
| §9 marker `save_memory("__drllm_s2_done_<session_id>")` | SKILL.md:158 | OK |
| §9 Hard Gate `url_verify_ratio < 0.5` 경고 + 사용자 질문 | SKILL.md:160 | OK |
| Commit message `feat: S2 Layer 2 Call 2 verification + research-results output` | `44dfc39` | OK |

**Verdict**: Byte-for-byte faithful append. No drift, no silent additions.

---

## 2. Cross-Reference Consistency with drllm-core v2

### 2.1 §4.1 Quote Normalization
SKILL.md:104 says "공백/개행 normalize는 허용" — this is a deliberate simplification of `context/drllm-core.md:117-124` (`[\s\u00A0\t\n\r]+ → 단일 space`, case-sensitive, 15-char min). Correct posture: drllm-core is authoritative (loaded via `@` import at SKILL.md:176), SKILL prose is the LLM-facing summary. `quote.minLength: 15` was already enforced at the Task 11 Call 1 schema, so the 15-char floor is structurally guaranteed before Call 2 ever runs.

### 2.2 §5.1 metadata.json
§7 block at SKILL.md:142-149 preserves `...` ellipsis for S0-written fields (session_id / topic / slug / domain / started_at / completed_at). This matches drllm-core §5.1 and honors **§0-6 Explicit state transitions** (no silent rewrite). `status="tutor"` is a valid value from the 5-state enum (`research | tutor | done | research_failed | abandoned`, drllm-core:147).

### 2.3 §5.2 research-results.md
SKILL.md frontmatter (118-122) is identical to drllm-core §5.2 frontmatter (drllm-core:153-159): 4 fields, same names, same KST format. 본문 섹션 순서 (Summary → Key Points → Citations) matches drllm-core:162 exactly.

### 2.4 §6-3/§6-4 HARD STOPS
- drllm-core §6-3 (citations 빈 → research_failed): covered by SKILL.md:165 Hard Gate bullet 2 (fetch 전부 실패) and bullet 3 (Call 2 전부 false).
- drllm-core §6-4 (verified=false 제거 + "❌ (제거됨)" 표시): covered by SKILL.md:110 (제거 rule) and SKILL.md:137 (table example row).

### 2.5 §0-3 No silent drop
Citations 테이블 keeps a "❌ (제거됨)" row for rejected items (SKILL.md:137). This is the exact pattern drllm-core §0-3 demands — log the drop even though the content is excluded. Good.

### 2.6 §0-5 Fail loud
§9 Hard Gate (ratio < 0.5) blocks auto-chain and asks the user instead of silently proceeding. Consistent with §0-5.

---

## 3. Internal Contract Gaps (Observations, not blockers)

### 3.1 Call 2 → §6 post-processing interface is implicit
The SKILL prose never spells out that "S2 parses Call 2 JSON, filters `verified=false`, then writes markdown." At skeleton level (LLM-as-runtime), this is acceptable because the LLM reading the SKILL will infer the pipeline. If Task 15 smoke exposes ambiguity (e.g., the agent inserting non-verified rows into the markdown), Task 21 concrete pass should add an explicit "parse → filter → render" enumeration.

### 3.2 Hard Gate vs. research_failed tension (partial failure range)
- ratio = 0 (citations all false after Call 2) → drllm-core §6-3 authoritative → `status="research_failed"`.
- 0 < ratio < 0.5 → §9 Hard Gate → 경고 + 사용자 질문, marker 금지.
- ratio ≥ 0.5 → marker + `status="tutor"`.

These are **complementary**, not contradictory. One gap: the "0 < ratio < 0.5" branch does not state what `status` value to write. Implicit answer is "status stays `research`" (§0-6 Explicit state transitions — no transition unless explicitly written). Task 15 smoke should confirm the agent does not accidentally transition to `tutor` in this branch. Flag for Task 21 concretization.

### 3.3 `url_verify_ratio` precision wiring to Task 22
§6 specifies 3-decimal rounding (0.800 form). §7 JSON example uses `<M/N>` placeholder — skeleton-level OK, but Task 22 aggregate-metrics.sh must use the same rounding rule to avoid M1 POC scoring drift. Add a test in Task 22 that round-trips metadata.json → aggregate.

### 3.4 `generated_at` format
SKILL.md:120 `<ISO 8601 KST>` matches drllm-core §5.1 `started_at` format (`+09:00` offset). Consistent.

### 3.5 Citations table markdown portability
Pipe-separated table with mixed 한글/영문/URL. GitHub flavored Markdown renders fine; Gemini CLI emits raw markdown (no rendering required). No portability risk.

---

## 4. Marker Prefix Contract

SKILL.md:158 writes `__drllm_s2_done_<session_id>`. Task 16 hook trigger (not yet implemented) is specified to grep for prefix `__drllm_s2_done_`. Prefix match is exact. When Task 16 lands, the contract check becomes: `save_memory` arg string begins with that 19-char literal prefix. No hyphen/underscore ambiguity.

---

## 5. Test Plan (what Task 15 smoke must verify)

Reproducing from prompt (explicit, for Task 15 authorship):

1. Call 2 LLM output actually contains `verified: boolean` field on every citation (schema passthrough works in practice, not just in prose).
2. `reason` field present when verified=false.
3. research-results.md generated with frontmatter, Summary, Key Points, Citations sections in that order.
4. Citations table contains "❌ (제거됨)" rows for rejected citations (not silently omitted).
5. metadata.json has `url_verify_total`, `url_verify_count`, `url_verify_ratio` as numbers (ratio to 3 decimals).
6. status transitions to `tutor` only when ratio ≥ 0.5.
7. `save_memory` invoked with correct prefix when ratio ≥ 0.5, **not** invoked when ratio < 0.5.
8. On ratio < 0.5, user is asked (prompt appears), markdown contains "⚠️ 출처 검증률 낮음".

---

## 6. Issues

**Critical**: none.

**Important**: none.

**Minor / Suggestions** (defer to Task 21 concretization, do not block Task 12):
- S1. SKILL.md §9 Hard Gate "0 < ratio < 0.5" branch does not specify `status` value explicitly. Recommend: "status 유지 (research)" phrase during concretization.
- S2. §6 post-processing pipeline (parse → filter → render) is implicit. Recommend: 3-bullet enumeration during concretization if Task 15 smoke shows agent confusion.
- S3. §5 blockquote could cite drllm-core §4.1 by reference ("§4.1 normalize 규칙 적용") to make authority chain explicit, but current prose is LLM-intelligible as is.

---

## 7. What Was Done Well

- Byte-for-byte plan fidelity — zero drift from plan lines 836-923.
- Cross-references to drllm-core v2 authoritative sections are tight: 4 frontmatter fields (§5.2), 5 status enum (§5.1), section ordering (§5.2), quote normalize delegation (§4.1).
- §0-3 No silent drop honored by keeping "❌ (제거됨)" rows in the Citations table even though content is excluded.
- §0-5 Fail loud honored by Hard Gate asking the user instead of auto-chaining on low ratio.
- §0-6 Explicit state transitions honored by ellipsis-preserving metadata update and explicit `status="tutor"` write.
- Marker prefix matches Task 16 hook pattern exactly.
- Commit message matches plan literally.

---

## 8. Recommendation

**APPROVED** for Task 12 skeleton. S2 Protocol §1~§9 is now end-to-end prose-complete and ready for Task 15 smoke (inline decomposition + Call 1 + Call 2 + post-processing + marker). Minor clarifications (items S1–S3) are concretization concerns to be handled during Task 21, not regressions of this task.

Proceed to Task 13 (S0 metadata.json creation logic concretization).
