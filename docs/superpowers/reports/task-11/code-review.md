# Task 11 Code Review — S2 Protocol §4 Layer 2 Call 1 (schema 강제)

- **Base SHA**: `0943060`
- **Head SHA**: `6d17187`
- **Scope**: `skills/drllm-research-execution/SKILL.md` (+43, -1)
- **Reviewer**: Senior Code Reviewer
- **Date**: 2026-04-14
- **Status**: APPROVED

---

## 1. Plan Alignment

| Plan requirement (Task 11) | Implementation | Status |
|---|---|---|
| SKILL.md §4 추가 (Layer 2 Call 1) | Lines 54-96 inserted between §3 end and `## Hard Gate` | OK |
| Gemini `response_schema` 언급 | Line 56 `(Gemini response_schema)` | OK |
| JSON schema: summary/key_points/citations required | Lines 59-87, `required` at 82 and 86 | OK |
| `summary minLength: 50` | Line 62 | OK |
| `key_points minItems: 2`, items `minLength: 20` | Lines 64-66 | OK |
| `citations minItems: 1` | Line 70 | OK |
| `citations[].url` with `format: uri` + `pattern: ^https?://` | Line 74 | OK |
| `citations[].quote minLength: 15` | Line 75 | OK |
| `source_type` enum 5 values | Lines 77-78 | OK |
| `relevance_to_subquery` string | Line 80 | OK |
| 시스템 프롬프트 blockquote (추측 금지) | Lines 90-92 | OK |
| Retry-once-then-error fail-loud | Line 94 | OK |
| Task 12 확장 포인트 명시 | Line 96 `(나머지 §5~§9 는 Task 12 에서 확장)` | OK |
| Commit message `feat: S2 Layer 2 Call 1 schema enforcement` | `6d17187` commit msg | OK |

**Verdict**: Byte-for-byte faithful to the plan block (lines 783-824). No deviation, no over-engineering, no under-delivery.

---

## 2. Cross-Reference Consistency

### 2.1 drllm-core.md §4.1 alignment
- `quote.minLength: 15` at SKILL.md line 75 matches **`context/drllm-core.md:122`** — "minimum match length = 15 characters". This is load-bearing: Task 12 Call 2 `url_verify` does exact-substring match after normalize, and the schema minimum must be ≥ the match minimum. Exact equality (15 == 15) is the tight bound the plan specifies.
- `citations[].url` with `format: uri` + `pattern: "^https?://"` supports §4 "URL 수정·축약 금지, 원문 그대로 유지" and gates out `file://` / `byoc://` which are explicit v0.5 BYOC expansions (correct scope for v0.1).
- `citations minItems: 1` enforces §0-5 Fail loud + §4 "검증 실패 citation은 최종 응답에서 제외" — zero citations is structurally impossible at Call 1 output, so Call 2 (Task 12) will always have input to verify.

### 2.2 Hard Gate consistency
Existing line 102 ("Call 2 모든 citations verified=false → research-results.md에 경고 명시, marker tool 호출 금지") correctly presumes Call 1 produces citations. The schema enforces that presumption at the source. No contradiction.

### 2.3 Plan "Files" clause
Plan lists only `skills/drllm-research-execution/SKILL.md` as modified. Diff confirms only this file touched. No metadata.json schema changes needed at this task boundary (Task 12 will add `verified` and `score` to `citations[]`).

---

## 3. Schema Design Quality

| Constraint | Rationale | Assessment |
|---|---|---|
| `summary.minLength: 50` | ~20-30 한국어 chars; blocks trivial "OK" / "N/A" outputs | Reasonable. Not so strict as to cause retry storms on legitimately short topics. |
| `key_points.minItems: 2` | Single-point summary is usually a warning sign | Reasonable for v0.1. **Observation**: for genuinely simple subqueries LLM may pad. If Task 15 smoke reveals padding, consider making configurable per topic complexity in v0.5 (noted in commit description — already acknowledged). |
| `key_points.items.minLength: 20` | Blocks `"fast"`, `"good"` style trivial points | Reasonable. |
| `citations.minItems: 1` | Core anti-hallucination invariant | Correct hard floor. |
| `url.pattern: "^https?://"` + `format: uri` | Dual validation: format catches malformed URIs, pattern locks scheme whitelist | Belt-and-suspenders, appropriate for Layer 2. |
| `quote.minLength: 15` | Matches §4.1 normalize-match floor | Correct coupling. |
| `source_type` enum 5 vals | Matches domain profile hints; covers primary research territory | Reasonable. `forum` catches StackOverflow/Reddit generically — SP-2 can split if needed. |
| `relevance_to_subquery` free string, required | Audit/debug hook | Acceptable skeleton. **Suggestion (minor, defer)**: consider `{subquery_index: int, justification: string}` structured form in v0.5 — eases Call 2 cross-matching when multiple subqueries share fetch bundle. |
| `required` at object level (4/4 nested, 3/3 top) | §0-4 Strict schema — no nullables leak | Correct. |

### 3.1 Gemini response_schema compatibility
- Gemini 2.5 Pro/Flash supports JSON Schema draft-07 subset: `minLength`, `minItems`, `pattern`, `enum`, `format`, `required`, nested `object`/`array` — all features used here are within spec per SP-0 Phase 2 Category E.
- `format: uri` is advisory in many validators; `pattern` provides the actual hard guarantee — correct defensive pairing.
- No `additionalProperties: false` specified. Gemini typically ignores unknown-property rejection; adding `additionalProperties: false` could cause spurious failures if Gemini injects whitespace or extra metadata. Omission is pragmatic.

### 3.2 Markdown rendering
- Outer 4-backtick fence (```` ```` ````) with inner ` ```json ` 3-backtick block is the standard nested-fence pattern. Both GitHub and Gemini CLI handle this correctly. Verified visually via Read tool (lines 58-88).
- Blockquote `>` for system prompt at line 92 provides LLM-salient visual emphasis per the commit description's intent.

---

## 4. Risks and Observations (Non-blocking)

### 4.1 Gemini response_schema actual wiring (deferred to Task 15)
SKILL.md references `Gemini response_schema` but does not specify how the skill passes this schema at LLM call time. This is by design — the skill is a markdown-as-prompt artifact; the harness or downstream subagent mechanism handles the API call. **Task 15 smoke test is the verification gate**. If Gemini CLI does not expose response_schema plumbing, the fallback (schema embedded as prompt text + strict JSON parse) remains viable because the entire schema is already in the prompt.

### 4.2 `retry once then error` is prose, not enforceable code
Line 94 is a behavioral instruction to the skill-executing LLM. For v0.1 skeleton this is acceptable (the SKILL.md *is* the specification). Task 12 or later may need to make this a hard harness-level guarantee (counter + abort) if the LLM drifts into retry loops — monitor in Task 15 smoke.

### 4.3 `key_points.minItems: 2` padding risk
Acknowledged in commit description. Mitigation: Task 15 smoke must include at least one "simple" topic to exercise this edge. No action required now.

### 4.4 Schema does not yet include `verified` field on citations
Correct: Task 12 adds it. Current `required: [url, quote, source_type, relevance_to_subquery]` intentionally excludes `verified`. Downstream compatibility: Call 2 will enrich, not overwrite, each citation object — compatible.

### 4.5 No `additionalProperties: false`
Not set (see §3.1). Trade-off is deliberate. **Suggestion (defer to v0.5)**: once Gemini compatibility is empirically confirmed, tighten with `additionalProperties: false` at each object level to close the "LLM invents new keys" vector.

---

## 5. Strengths

1. **Exact coupling between `quote.minLength: 15` and §4.1 normalize floor** — shows careful reading of the core doc; avoids the common mistake of over- or under-constraining at the wrong layer.
2. **Dual URL validation** (`format: uri` + `pattern: ^https?://`) is the right defensive posture for hallucination-prone fields.
3. **Fail-loud prose** on line 94 aligns with §0-5 and does not leave retry semantics ambiguous.
4. **System prompt wording** ("fetch 결과들에서만 … 추측으로 … 생성하지 말라. fetch 결과에 없는 정보는 반드시 생략하라") directly encodes §4 출처 규율 as an operational directive — textbook Layer 2 design.
5. **Task 12 extension marker** at line 96 prevents append confusion in the next task.
6. **Plan fidelity**: exact match to plan text; trailing line was the only bridging edit needed, and it correctly replaces "Task 11~12에서 확장" with "Task 12 에서 확장" (scope narrowed because Task 11 now shipped the §4 portion).

---

## 6. Issues

- **Critical**: none
- **Important**: none
- **Minor / Suggestions (defer)**:
  1. Consider `additionalProperties: false` at each object level once Gemini compatibility confirmed (Task 15 smoke + v0.5).
  2. Consider structured `relevance_to_subquery: {subquery_index, justification}` in v0.5 to ease Call 2 cross-matching.
  3. Make `key_points.minItems` per-topic-complexity-configurable if Task 15 smoke reveals padding.
  4. Make retry counter harness-enforced rather than prose if drift observed in Task 15.

All four items are explicitly post-v0.1 scope and require empirical signal first. No action at Task 11.

---

## 7. Recommendation

**APPROVED** for merge to Task 12. Proceed to implement Call 2 (citation verification + `verified` / `score` enrichment) by appending §5 (and following §6-§9) at the marker on line 96.

Relevant files:
- `/home/namykim/workspace/DRLLM/skills/drllm-research-execution/SKILL.md` (lines 54-96)
- `/home/namykim/workspace/DRLLM/docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` (lines 774-833)
- `/home/namykim/workspace/DRLLM/context/drllm-core.md` (lines 108-124, §4 and §4.1)
