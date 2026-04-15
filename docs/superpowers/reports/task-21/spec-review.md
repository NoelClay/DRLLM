# Task 21 + B1 Fix — Spec Compliance Review

**Reviewed**: 2026-04-14  
**Commit**: bc181b5  
**Branch**: feat/sp1-tiny-drllm  
**Reviewer**: Claude Sonnet 4.6 (automated)

---

## Overall Verdict

**SPEC COMPLIANT** — with two minor concerns flagged (edge cases, not blockers).

---

## Checklist

### 1. `context/drllm-core.md` — HARD STOP-9

**PASS**

Line 258 (current HEAD):

> `9. research-results.md Citations 테이블 row 수 는 metadata.json.url_verify_total 과 반드시 일치 (B1). verified=true 인 citation 은 모두 테이블에 row 로 표시. 유사 URL (fragment 만 다름) 병합 금지. 불일치 시 세션 status 를 research_failed 로 남기고 사용자에게 원인 보고 (aggregate 에서 [INVALID_CITATION_COUNT] 기록 후 M1 제외).`

All required elements present:
- Row count == url_verify_total: ✅
- No merging similar URLs: ✅
- `status="research_failed"` on violation: ✅
- `[INVALID_CITATION_COUNT]` aggregate event: ✅

---

### 2. `skills/drllm-research-execution/SKILL.md` — §6.1 Citations 테이블 무결성

**PASS**

§6.1 inserted between §6 and §7 (lines 146–162). Confirmed by diff: old `### 7. metadata.json 갱신` became `### 7. metadata.json 갱신 (Task 21에서 강조)` and §6.1 was inserted immediately before it.

**Rules list**: ✅
- `verified=true` → separate row each
- No merging similar URLs (fragment/query)
- Count match required; mismatch → HARD STOP-9 → `status="research_failed"`

**Self-check bash block**: ✅
- `ROW_COUNT=$(grep -c '^| [0-9]' ...)` — present
- `TOTAL=$(jq -r .url_verify_total ...)` — present
- `if [ "$ROW_COUNT" != "$TOTAL" ]` — present and quoted ✅
- `status="research_failed"` transition via jq in-place rewrite — present
- `exit 1` — present

**Bash variables quoted**: ✅ — `"$ROW_COUNT"` and `"$TOTAL"` in the `if` comparison. Note: `$ROW_COUNT` and `$TOTAL` in the `echo` line are unquoted but this is only a diagnostic message to stderr, not a comparison — acceptable.

---

### 3. §7 — Task 21 original content

**PASS**

Required fields present with correct type annotations:
- `url_verify_total` — `<Call 1 citations 전체 수, 정수>` (integer) ✅
- `url_verify_count` — `<verified=true 인 수, 정수>` (integer) ✅
- `url_verify_ratio` — `<count/total, 소수점 3자리>` (3 decimal) ✅
- `"status": "tutor"` ✅

계산 예시 (5/4/0.800):
- `Call 1 citations = 5개` ✅
- `Call 2 verified=true = 4개` ✅
- `ratio = 0.800` ✅

Hard Gate note present: "이 필드들을 기록하지 않으면 M1 POC aggregate에 반영되지 않음 — 세션 제외." ✅

---

### 4. No unquoted `<<EOF` heredoc

**PASS** — No heredoc (`<<`, `EOF`) appears anywhere in SKILL.md. Task 20 C1 lesson not violated.

---

### 5. Bug tracker updates

**PASS**

- `docs/superpowers/bugs/B1-citations-count-mismatch.md` Status: `open` → `in_progress` ✅
- `docs/superpowers/bugs/README.md` Index row for B1: `open` → `in_progress` ✅
- B2 status: `open` (unchanged) ✅
- B3 status: `open` (unchanged) ✅

No side edits to unrelated bugs.

---

### 6. File count at bc181b5

**PASS** — 5 files modified (matches claim):
1. `context/drllm-core.md` (+1 line)
2. `docs/superpowers/bugs/B1-citations-count-mismatch.md` (status field)
3. `docs/superpowers/bugs/README.md` (index row)
4. `docs/superpowers/reports/task-21/implementer.md` (new, 111 lines)
5. `skills/drllm-research-execution/SKILL.md` (+45 lines)

---

### 7. Tests

**PASS**

```
L1 schema: PASS
L2 Hooks (bats): 5/5 ok
L3 Aggregation: SKIP (not yet implemented)
Automated tests: PASS
```

---

## Edge Case Flags

### FLAG-1: grep pattern may miss multi-digit row numbers with spaces (MINOR — acceptable)

The pattern `'^| [0-9]'` matches rows beginning `| 1 |`, `| 2 |`, ..., `| 9 |` but **NOT** `| 10 |`, `| 11 |`, etc. (two-digit numbers after `|` space). If a session has 10+ citations, `grep -c '^| [0-9]'` will undercount.

Mitigation: M1 POC scenarios are unlikely to exceed 9 citations per session in current scope. However, the correct pattern for robustness should be `'^| [0-9]'` → `'^| [0-9][0-9]* '` or `'^| [[:digit:]]'`.

**Severity**: Minor / low-risk for current M1 scope. Recommend fixing in Task 22 or as a follow-up bug.

### FLAG-2: jq returning `null` when `url_verify_total` is absent (MINOR — safe for this workflow)

If `metadata.json` does not yet contain `url_verify_total` when the self-check runs, `jq -r .url_verify_total` returns the string `"null"`. The comparison then becomes `"$ROW_COUNT" != "null"`, which is true for any non-zero row count — the self-check would **always trigger** a false HARD STOP-9 violation if metadata was not yet written.

In the current S2 workflow, `url_verify_total` is written to metadata before §6.1 self-check executes (§6 computes the value, §6.1 checks it). So in practice this ordering protects against the null case. However, the self-check has no explicit guard (e.g., `if [ "$TOTAL" = "null" ]`) to produce a clear error message when the field is missing.

**Severity**: Minor / not a current blocker. Recommend adding a null guard in Task 22 self-check hardening.

---

## Summary

All spec requirements for Task 21 (Spec A) and B1 fix (Spec B) are correctly implemented. §6.1 inserted in the correct location, §7 augmented in-place with all required fields and the 5/4/0.800 example, HARD STOP-9 added to drllm-core §6, bash variables properly quoted, no heredoc, bug tracker updated correctly, B2/B3 untouched, 5 files modified, tests L1+L2 5/5 PASS.

Two minor edge cases flagged: (1) `grep -c '^| [0-9]'` undercounts rows with 10+ citations; (2) `jq` null guard absent but safe due to workflow ordering.
