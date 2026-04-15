# Task 21 + B1 Fix — Code Review

**Reviewer**: Senior Code Reviewer (Opus 4.6, 1M ctx)
**Date**: 2026-04-14
**Base → Head**: `ced0984` → `bc181b5`
**Scope reviewed**: `context/drllm-core.md`, `skills/drllm-research-execution/SKILL.md`, B1 tracker files

---

## Verdict

**CHANGES REQUIRED** — one Critical semantic defect makes the self-check produce false positives in every expected non-100% verification run. The regex and atomic-update pattern are fine; the bug is in the quantity being compared.

---

## Critical

### C1 — Self-check compares ROW_COUNT to wrong metadata field (semantic mismatch)

**Location**: `skills/drllm-research-execution/SKILL.md` §6.1 line 156 and §6 line 111.

**Definitions currently in file**:

- §6 line 110: `citations.verified=false 인 항목 제거` (verified=false rows are removed from the table).
- §6 line 111: `url_verify_total = Call 1의 전체 citations 수` (includes both verified=true and verified=false).
- §6 line 112: `url_verify_count = verified=true 인 수`.
- §6.1 line 149: "`verified=true` 로 판정된 citation 은 빠짐없이 Citations 테이블에 **각각 별도 row** 로 기재" — verified-true-only rows.
- §6.1 line 151: "Citations 테이블 row 수 = `url_verify_total` 이어야 함."

**Contradiction**:

- If §6 line 110 is authoritative, the table contains only verified=true rows, so `ROW_COUNT` should equal `url_verify_count`, never `url_verify_total`.
- If §6.1 line 151 is authoritative, unverified rows must also be in the table, contradicting §6 line 110 and the example format on line 143 ("❌ (제거됨)" is shown but the rule says removed).

**Impact**: The example from the implementer report (`total=5, count=4`) would cause the self-check to fire `research_failed` even though the verification legitimately found 4/5 verified citations. Any session with fewer than 100% verification rate will be marked `research_failed` by HARD STOP-9. This inverts the intended semantic of B1 (which was about collapsed/merged rows under-counting against `count`, not against `total`).

**Recommended fix** (choose one):

- Option A (likely intent): change `TOTAL` in the self-check to pull `url_verify_count`, and amend §6.1 line 151 to "row 수 = `url_verify_count`".
- Option B: keep comparing against `url_verify_total` and redefine §6 line 110 so unverified rows stay in the table (marked ❌) and §6.1 line 149 counts both verified and unverified.

Option A aligns with the original B1 symptom ("verified citations collapsed into a single row") and with the "유사 URL 병합 금지" rule which applies to verified duplicates. Recommend A.

**Related**: §6 format example lines 142-143 shows both ✅ and ❌ rows which, combined with §6 line 110, is already inconsistent and should be tightened when fixing C1.

---

## Important

### I1 — Self-check guard clause against missing metadata field (E2)

**Location**: §6.1 line 156.

`jq -r .url_verify_total` returns the literal string `null` when the field is absent. The subsequent comparison `"$ROW_COUNT" != "$TOTAL"` evaluates `"0" != "null"` → true → `research_failed`. Today this is safe because §7 writes the fields before self-check, but any future Protocol reorder creates a silent class of false failures where the exit message reads `meta=null` and the debugger must know the cause.

**Recommended fix** — add an explicit guard that distinguishes "missing field" from "numeric mismatch":

    if [ -z "$TOTAL" ] || [ "$TOTAL" = "null" ]; then
      echo >&2 "[S2] HARD STOP-9: url_verify_total missing in metadata.json"
      exit 1
    fi

Different exit message guides future triage.

### I2 — Error message lacks HARD STOP / B1 reference

**Location**: §6.1 line 160.

`echo >&2 "[S2] Citations count mismatch: table=$ROW_COUNT meta=$TOTAL"` is correct mechanically but omits the ruleset pointer. Future debugger sees the log line without trail to the rule. Append `(drllm-core §6 HARD STOP-9, B1)` so the message is self-documenting and greppable.

### I3 — §6.1 conflates rule statement with enforcement

Single-responsibility concern. §6.1 currently:

1. Declares the rule (rows per verified citation, no merging).
2. Declares the enforcement mechanism (bash self-check).
3. Declares the transition on failure (`status="research_failed"` + `exit 1`).

For skill readability this is acceptable density, but consider splitting into `§6.1 Rules` + `§6.2 Self-check` if §6 continues growing. Not a blocker for Task 21.

---

## Minor

### M1 — `grep -c '^| [0-9]'` regex correctness — CLEAR (not flagged)

Verified empirically: `^| [0-9]` in BRE anchors at line start, matches literal `| `, then one digit from the class. Because BRE does not implicitly anchor the end, rows beginning with `| 1 `, `| 10 `, `| 100 ` all match. Header `| # |` and separator `|---|---|` do not match. The regex is correct; the concern raised in the task is inverted and this does not need to change.

One residual nit: header row `| # | URL | ...` is line-anchored out correctly, but if an author accidentally numbers a citation `| 0 | ...` (zero-indexed), it still counts, which is desired.

### M2 — Forward reference to Task 22 aggregate handler is acceptable

drllm-core §6 HARD STOP-9 references aggregate behavior `[INVALID_CITATION_COUNT]` which does not yet exist (Task 22 delivers aggregate). Pattern mirrors HARD STOP-8's `[INVALID_TIMESTAMP]` which was similarly forward-looking from Task 20. Acceptable; no change requested. Flag if Task 22 slips beyond SP-1.

### M3 — "유사 URL 병합 금지" is not mechanically enforceable

HARD STOP-9 prohibits merging fragment-differing URLs, but the bash self-check only counts rows, not URL distinctness. A collapsed table with `url_verify_total` also decreased to the collapsed value would pass the count check. The anti-merge rule thus relies on LLM discipline, not self-check. Acceptable (true mechanical enforcement would require a URL-uniqueness query against Call 2 JSON, which is out of Task 21 scope). Document the limitation so future readers understand self-check scope, possibly with one sentence in §6.1: "Self-check는 row 수만 검증; URL 중복 여부는 LLM 준수에 의존."

### M4 — §6 HARD STOPS readability approaching 9 items

At 9 items §6 is long but each item is single-paragraph and numbered. Not yet at readability limit; consider subsection headers (6-A Protocol hygiene, 6-B Data integrity, 6-C Session lifecycle) if it crosses 12. No action for Task 21.

### M5 — Atomic tmp-move pattern — CLEAR

Line 159 uses `jq '.status = "research_failed"' metadata.json > /tmp/m.$$ && mv /tmp/m.$$ metadata.json`. PID suffix prevents cross-process collision, `&&` chains prevent mv on jq failure, mv is atomic within the same filesystem (/tmp vs session dir may be different filesystem on some setups — if `.drllm/sessions/<id>/` is on a non-tmpfs mount this still works but isn't technically rename(2) atomic; for Task 21's scope this is fine, consider a session-local tmp path later).

Pattern differs from Task 20 which used `printf '%s'` directly without jq rewrite. Not inconsistent — Task 20 was a simple timestamp write, Task 21 is a field update. Both are correct for their context.

### M6 — Ordering question: "check first, write only if valid"

The self-check runs AFTER metadata.json and research-results.md are both written. On failure, it mutates metadata.json to `research_failed` as a rollback. An alternative "validate-then-persist" ordering would be cleaner, but would require staging the written artifacts in /tmp and moving them only after check passes — significantly more code. Current approach is acceptable and matches the existing "write then transition on error" pattern used elsewhere in the skill. No change.

---

## What was done well

- §7 expansion added explicit types (integer / 3-decimal), computed example, and Hard Gate note. This is a meaningful improvement over the pre-edit stub and directly addresses the Task 21 brief.
- B1 tracker state machine update (`open → in_progress`) is correctly partial — the bug is not closed until Task 22 delivers aggregate verification. Right call.
- Single atomic commit across 5 files (2 authoritative + 2 tracker + 1 report) keeps the contract-level and skill-level change coherent.
- `echo >&2` is used correctly for the mismatch message (stderr, not stdout), which will not pollute session transcript.
- Variables quoted in `[ "$ROW_COUNT" != "$TOTAL" ]` — would prevent word-splitting issues if either ever became empty.
- L1 + L2 bats 5/5 still pass; no regression introduced.

---

## Summary of Required Changes

1. **C1 (must fix before Task 22)**: decide authoritative semantics for Citations table row membership. Recommend Option A — compare `ROW_COUNT` against `url_verify_count`, not `url_verify_total`. Update §6.1 line 151, the self-check at line 156, and drllm-core §6 HARD STOP-9 to match.
2. **I1**: add `null`/empty guard for `$TOTAL` before numeric comparison.
3. **I2**: append HARD STOP-9 / B1 reference to the stderr mismatch message.

C1 is the blocker. I1 and I2 can ship in the same follow-up patch. Minors are advisory only.

---

## Re-Review After C1+I1 Fix

**Reviewer**: Senior Code Reviewer (Opus 4.6, 1M ctx)
**Date**: 2026-04-14
**Base → Head**: `bc181b5` → `589b23e`
**Fix commits**: `b560a07` (code/contract) + `589b23e` (report append)

### Verdict

**APPROVED** — both C1 (Critical) and I1 (Important) are fully resolved. I2 (stderr message hardening) is also resolved as part of the same patch even though not explicitly named in the change request. No new issues introduced. Tests PASS.

### C1 — Resolved (verified)

`skills/drllm-research-execution/SKILL.md`:
- §6.1 line 152: rule text now reads `Citations 테이블 row 수 = url_verify_count (verified-only 테이블, §6 규칙)` — matches §6 line 110 authoritative semantics.
- §6.1 lines 156-167: self-check renamed `TOTAL` → `COUNT`, sources `jq -r .url_verify_count`, and compares `ROW_COUNT != COUNT`. Comparison semantically aligned with verified-only table contract.
- §6 format example (lines 138-143): the `| 2 | ... | ❌ (제거됨) |` row is removed. Only the verified row template remains, plus an explicit advisory below the block: `verified=false 인 citation 은 테이블에 포함하지 않음 (§6 line 110 규칙).`

`context/drllm-core.md` §6 HARD STOP-9 (line 258):
- Now reads `metadata.json.url_verify_count` (was `url_verify_total`).
- Adds inline clarification `테이블은 verified=true citation 만 포함 (S2 §6 규칙)`.
- Retains `[INVALID_CITATION_COUNT]` aggregate event reference for Task 22 forward link (M2 from prior review still satisfied).

The original C1 test case (`total=5, count=4`) now produces table_rows=4, COUNT=4 → match → no false `research_failed`. Semantic mismatch closed.

### I1 — Resolved (verified)

§6.1 lines 158-161 add the null guard **before** the count comparison:

    if [ -z "$COUNT" ] || [ "$COUNT" = "null" ]; then
      echo >&2 "[S2] HARD STOP-9: url_verify_count field missing in metadata.json"
      exit 1
    fi

Ordering is correct: guard runs first, distinct exit message (`field missing` vs `count mismatch`) gives future triage a clear signal. Exits with `1` rather than mutating metadata to `research_failed` — appropriate because a missing field is a contract violation upstream of S2 §7, not a verification failure of S2's own work.

### I2 — Resolved (bonus)

Mismatch stderr message (line 165) now reads:

    [S2] HARD STOP-9: Citations count mismatch — table=$ROW_COUNT meta.url_verify_count=$COUNT

Includes both HARD STOP-9 ruleset reference and the precise field name. Greppable. Better than original recommendation (which suggested appending `(drllm-core §6 HARD STOP-9, B1)`).

### Edge cases verified

- §6 line 110 rule (`citations.verified=false 인 항목 제거`) is unchanged — still the authoritative rule source. Confirmed.
- §6 format example post-fix is internally consistent: shows only ✅ template row, advisory note clarifies verified=false handling. Citations counts and example align.
- drllm-core HARD STOP-9 still mentions `[INVALID_CITATION_COUNT]` aggregate event (line 258) → Task 22 forward reference preserved.
- §7 (metadata.json 갱신, lines 169-186) is unchanged — count-match enforcement remains in §6.1 only, no duplication. Single source of truth maintained.
- B1 bug file (`docs/superpowers/bugs/B1-citations-count-mismatch.md` lines 55) has appended `**Updated during Task 21 review (C1+I1 fix)**:` annotation explaining the semantic reconciliation. Bug status correctly stays `in_progress` pending Task 22 aggregate verification.

### No new issues introduced

- No `<<EOF` unquoted heredoc anywhere in the changed blocks (Task 20 C1 lesson respected — `<<'EOF'` is used consistently in drllm-core; SKILL.md self-check uses indented 4-space code block, no heredoc).
- All bash variables in self-check remain quoted (`"$COUNT"`, `"$ROW_COUNT"`).
- §7 stays focused on metadata field schema, count-match rule lives only in §6.1 — no duplication, no drift risk.
- L1 + L2 bats: 5/5 PASS, no regression.

### Commit hygiene

- `b560a07` — single atomic commit across 3 files (drllm-core + SKILL + B1 tracker), with clear subject line and explanatory body. Co-author trailer present.
- `589b23e` — separate report-append commit, correctly scoped to docs only. Good separation of concerns.

### Minors carried forward

- M3 (URL distinctness not mechanically enforced) — still applies, still acceptable for Task 21 scope. One-line documentation suggestion deferred to author discretion.
- M4 (§6 at 9 items) — unchanged, no action needed.

### Summary

Both blockers cleared. Task 21 is ready for downstream consumption (Task 22 aggregate handler can now rely on §6.1 self-check to filter out malformed sessions before aggregation, and `[INVALID_CITATION_COUNT]` forward reference gives Task 22 a clear contract to implement). No follow-up patch required.
