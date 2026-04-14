# Task 7 Spec Review

**Date**: 2026-04-14
**Reviewer**: Spec Review Agent
**Overall Status**: ❌ FAIL

---

## 1. Files Created

| File | Exists |
|------|--------|
| `skills/drllm-adaptive-tutoring/SKILL.md` | ✅ |
| `commands/drllm/tutor.toml` | ✅ |

---

## 2. SKILL.md Frontmatter (yq parse)

yq binary present (`/snap/bin/yq` v4.49.2) but produces no output in this shell environment (snap confinement issue with non-home paths). Validated via Python yaml:

- `name: drllm-adaptive-tutoring` ✅
- `description` present ✅
- Dual trigger: `__drllm_s2_done_*` ✅, `/drllm:tutor` ✅

---

## 3. SKILL.md Byte-Diff vs Plan Literal

**Two divergences found:**

### 3a. Protocol Step 4 — P5 prompt text truncated

Plan (line 567):
```
     "한 문장으로 [X]를 설명해줄 수 있어? 동료를 가르치듯."
```
Actual:
```
     "한 문장으로 [X]를 설명해줄 수 있어?"
```
**Verdict: ❌ FAIL** — tail `" 동료를 가르치듯."` missing.

### 3b. Hard Gate — item count and wording changed

Plan literal has **3** Hard Gate items:
1. `status != "tutor" → 에러 반환`
2. `P5 체크 생략 절대 금지 (subtopic 완료 감지 시 반드시 발동)`
3. `출처 없는 주장 금지 — research-results.md의 citations만 참조`

Actual has **4** Hard Gate items:
1. `status != "tutor" → 에러 반환` ✅ (match)
2. `research-results.md 부재 → 에러 반환 (S2 재실행 안내)` ← **added (not in plan)**
3. `P5 체크 생략 절대 금지 (subtopic 완료 감지 시 반드시 발동)` ✅ (match)
4. `verified=false citation 인용 → **절대 금지**` ← **replaced plan item 3 with different wording**

**Verdict: ❌ FAIL** — plan literal has 3 items; actual has 4 (1 added, 1 rewording).

**Note**: The review task description says "Hard Gate 4 items" while the plan literal defines 3. The implementer added a 4th item (`research-results.md 부재`) not in the plan spec and changed the wording of item 3. This is a deviation from plan literal regardless of the count expectation.

### 3c. Protocol 5 steps

Steps 1–5 present and structurally matching. ✅

### 3d. See Also

Single bullet: `@./context/drllm-core.md` 섹션 3 (LearnLM P5), 섹션 6 (HARD STOPS) ✅  
Plan also specifies single bullet (same content). ✅

---

## 4. tutor.toml

- `description` present ✅
- `{{args}}` in prompt ✅
- "P1-P5 principles, P5 strictly enforced" ✅
- **IDENTICAL to plan spec** ✅

---

## 5. L1 Schema Test

```
=== L1 Schema ===
L1 schema: PASS
=== L2 Hooks: SKIP (bats not installed or no tests yet) ===
=== L3 Aggregation: SKIP (not yet implemented) ===

Automated tests: PASS
```
✅ PASS — all 3 SKILL.md files (S0+S2+S4) validated.

---

## 6. Commit

```
commit 0c9efcd2cc6e74be12bac332a6fc30e7e9ea12d4
Author: NoelClay <asdf1578@naver.com>
Date:   Tue Apr 14 17:03:03 2026 +0900

    feat: S4 drllm-adaptive-tutoring skeleton + tutor command

    Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

 commands/drllm/tutor.toml               | 12 +++++++++
 skills/drllm-adaptive-tutoring/SKILL.md | 48 +++++++++++++++++++++++++++++++++
 2 files changed, 60 insertions(+)
```

- Commit message exact match ✅
- Exactly 2 files ✅
- Co-Author present ✅
- No out-of-scope files ✅

---

## 7. Summary of Findings

| Check | Result |
|-------|--------|
| Files created (2) | ✅ |
| Frontmatter name + description | ✅ |
| Dual trigger in description | ✅ |
| Protocol 5 steps | ✅ |
| Protocol Step 4 P5 prompt exact text | ❌ Missing `" 동료를 가르치듯."` |
| Hard Gate item count (plan=3) | ❌ Actual=4 (1 added, 1 reworded) |
| See Also (1 bullet matching plan) | ✅ |
| tutor.toml identical to plan | ✅ |
| L1 schema PASS (3 skills) | ✅ |
| Commit message, 2 files, co-author | ✅ |

**Overall: ❌ FAIL** — 2 deviations from plan literal in SKILL.md body.

### Required Fixes

1. Restore Protocol Step 4 P5 prompt to exact plan text:  
   `"한 문장으로 [X]를 설명해줄 수 있어? 동료를 가르치듯."`

2. Hard Gate must match plan literal exactly (3 items):
   - Remove: `- research-results.md 부재 → 에러 반환 (S2 재실행 안내)`
   - Restore item 3 to: `- 출처 없는 주장 금지 — research-results.md의 citations만 참조`

---

## Re-review after fix aee59d0

**Date**: 2026-04-14  
**Fix commit**: `aee59d085f48efc51ae8343e561661cbc2a2d737`  
**Reviewer**: Spec Review Agent

### Commit Scope

- Message: `fix(sp1): S4 SKILL.md skeleton — restore plan literal` ✅
- Files changed: 1 (`skills/drllm-adaptive-tutoring/SKILL.md`) ✅ — surgical, no out-of-scope changes
- Diff: 2 insertions(+), 3 deletions(-) ✅

### Fix 1 — Protocol Step 4 P5 prompt

Plan literal (line 567):
```
     "한 문장으로 [X]를 설명해줄 수 있어? 동료를 가르치듯."
```
SKILL.md after fix (line 27):
```
     "한 문장으로 [X]를 설명해줄 수 있어? 동료를 가르치듯."
```
**Verdict: ✅ PASS** — exact match restored.

### Fix 2 — Hard Gate (3 items)

Plan literal (lines 576–578):
```
- status != "tutor" → 에러 반환
- P5 체크 생략 절대 금지 (subtopic 완료 감지 시 반드시 발동)
- 출처 없는 주장 금지 — research-results.md의 citations만 참조
```
SKILL.md after fix (lines 36–38):
```
- status != "tutor" → 에러 반환
- P5 체크 생략 절대 금지 (subtopic 완료 감지 시 반드시 발동)
- 출처 없는 주장 금지 — research-results.md의 citations만 참조
```
**Verdict: ✅ PASS** — exactly 3 items, correct order, exact wording restored.  
Spurious 4th item (`research-results.md 부재`) and reworded item 3 (`verified=false citation`) both removed.

### Tests

```
=== L1 Schema ===
L1 schema: PASS
=== L2 Hooks: SKIP (bats not installed or no tests yet) ===
=== L3 Aggregation: SKIP (not yet implemented) ===

Automated tests: PASS
```
✅ PASS — L1 schema still passing after fix.

### Re-review Summary

| Check | Result |
|-------|--------|
| Protocol Step 4 P5 prompt exact text | ✅ Restored |
| Hard Gate exactly 3 items (correct order + wording) | ✅ Restored |
| No other file changes (1 file only) | ✅ Surgical fix |
| Automated tests PASS | ✅ |

**Overall Re-review: ✅ PASS** — both deviations from plan literal fully restored by commit `aee59d0`.
