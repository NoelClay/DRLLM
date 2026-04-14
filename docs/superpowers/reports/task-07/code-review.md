# Task 7 Code Review — S4 drllm-adaptive-tutoring skeleton

- **Base:** `88bd8ae` (Task 6) → **Head:** `aee59d0` (Task 7 fix — plan literal restored)
- **Files:** `skills/drllm-adaptive-tutoring/SKILL.md` (+47), `commands/drllm/tutor.toml` (+12)
- **Schema test (`./tools/run-tests.sh`):** PASS (L1)
- **Status:** APPROVED (skeleton scope)

---

## 1. Plan Alignment

| Item | Plan literal (lines 540-598) | Implementation | Verdict |
|------|------------------------------|----------------|---------|
| Frontmatter `name` | `drllm-adaptive-tutoring` | identical | OK |
| Frontmatter `description` (TRIGGER dual: marker + slash) | full string with `__drllm_s2_done_*` and `/drllm:tutor` | identical | OK |
| Mission (Korean) | P5 메타인지 체크 강제, append-only | identical | OK |
| Inputs (3 bullets) | metadata / research-results / drllm-core §3 | identical | OK |
| Protocol 5 steps | metadata load → research load → log init → 대화 → 종료 | identical | OK |
| Hard Gate (3 items) | status / P5 skip / 출처 | identical | OK |
| Outputs | learning-log.md + metadata 갱신 | identical | OK |
| See Also | `@./context/drllm-core.md` 섹션 3 + 6 | identical | OK |
| `tutor.toml` description + prompt | activate skill, P5 strictly enforced | identical | OK |

**Diff vs plan:** zero deviation. Fix commit `aee59d0` correctly restored the plan literal.

---

## 2. drllm-core v2 Contract Verification

### 2.1 P5.2 prompt string (§3 line 83) — char-by-char check

- core line 83: `"한 문장으로 [X]를 설명해줄 수 있어? 동료를 가르치듯."`
- SKILL.md Step 4: `"한 문장으로 [X]를 설명해줄 수 있어? 동료를 가르치듯."`

Identical (including space before `동료를`, full-stop, question mark spacing). PASS.

### 2.2 See Also section anchors

- `섹션 3 (LearnLM P5)` → core §3 (line 50) "LearnLM 교수법 (v0.1: P5 강제)" — match.
- `섹션 6 (HARD STOPS)` → core §6 (line 191) "HARD STOPS (위반 시 응답 중단)" — match.
- `@./context/drllm-core.md` — Gemini @import path is repo-root-relative; the project lives at `/home/namykim/workspace/DRLLM/context/drllm-core.md`. Path syntax matches the convention used elsewhere in the codebase. OK.

### 2.3 TRIGGER marker contract (Task 16 alignment)

- SKILL.md: `__drllm_s2_done_*` (prefix glob).
- Future hook (Task 16): `grep __drllm_s2_done_` will match this prefix.
- Consistency: PASS for skeleton; concrete hook script will be reviewed in Task 16.

### 2.4 §6 HARD STOPS coverage (skeleton scope)

| §6 stop | Reflected in skeleton? | Note |
|---------|------------------------|------|
| §6-1 P5_MISSING required when T1~T4 true | Implicit only | Will be made explicit in Task 14 expansion (Hard Gate item or Protocol Step 4 sub-bullet). Acceptable for skeleton because T1~T4 evaluation itself is deferred. |
| §6-2 P5_SKIP required on skip pattern | Reflected via "P5 체크 생략 절대 금지" Hard Gate | Coverage adequate; literal `[P5_SKIP]` event semantics added in Task 14. |
| §6-3 empty citations → research_failed | Out of scope (S2 responsibility) | OK |
| §6-4 verified=false citation 인용 금지 | Reflected via "출처 없는 주장 금지 — citations만 참조" | Adequate at skeleton level; explicit `verified=true` filter recommended for Task 14. |
| §6-5 불확실 정보 → 출처 확인 필요 명시 후 중단 | Implicit via 출처 규율 Gate | OK |
| §6-6 status 전이는 metadata.json 갱신만 | Reflected via Step 5 metadata 갱신 | OK |

---

## 3. Skeleton Scope (intentionally deferred to Task 14 / Task 20)

The following items are **plan-literal placeholders** and are correctly absent from this skeleton:

1. Structural T1~T4 trigger evaluation logic (§3 P5.1) — currently expressed as "subtopic 완료 감지 시 (LLM 판단)".
2. `[P5_MISSING]` event recording when triggers are true but P5 not fired (§6-1).
3. `[SUBTOPIC]` / `[SOURCE]` event timing detail (§5.3).
4. P5.3 evaluation rubric (key_point term majority + logical consistency, no %).
5. P5.4 skip regex (`^(?i)(넘어가|다음|pass|skip|나중에|됐어|건너뛰|그냥 계속)`).

These are explicitly scoped to Task 14 ("structural T1~T4 P5 trigger + [P5_MISSING] 기록 요건") and Task 20 (event schema enforcement). The skeleton's job is to (a) lock the file path / frontmatter / TRIGGER contract for hook integration in Task 16 and (b) preserve the canonical P5.2 prompt string. Both are achieved.

---

## 4. Issues by Severity

### Critical: 0
None. Implementation is plan-literal, schema test passes, P5.2 string matches core spec character-for-character.

### Important: 0 (current task scope)
The "LLM 판단" wording in Step 4 is a known skeleton placeholder, not a defect. Task 14 will replace it with structural T1~T4 evaluation per §0-1 ("LLM 판단 최소화") and §3 P5.1 line 77 ("LLM 추론 금지").

### Minor / Suggestions (for Task 14 expansion, not for this commit)

1. **Step 4 should explicitly enumerate `[P5_MISSING]`** when expanding from skeleton — currently only `[P5_CHECK]` / `[P5_SKIP]` are mentioned. §6-1 makes `[P5_MISSING]` mandatory when any T1~T4 is true and P5 is not fired; this is the primary anti-silent-drop mechanism (§0-3).
2. **Hard Gate may add an explicit `verified=true` filter** for §6-4 reinforcement (e.g., "research-results.md citations 중 `verified=true` 만 인용") — currently subsumed under "출처 없는 주장 금지" but Task 14 should make the filter mechanical.
3. **`tutor.toml` `activate_skill` call syntax** (`activate_skill(skill_name="drllm-adaptive-tutoring")`) is plan-literal; verify in Task 16 / smoke tests that this matches Gemini CLI's actual skill activation API. Out of scope for this review.

---

## 5. Things Done Well

- Fix commit `aee59d0` correctly restored the plan literal after an earlier drift; commit history shows discipline (initial commit `0c9efcd` → fix `aee59d0`).
- P5.2 prompt string preserved character-for-character — this is the most contract-sensitive line in the entire skill and it is correct.
- Frontmatter TRIGGER dual-channel (marker + slash) matches the hook integration plan for Task 16.
- See Also uses `@./context/drllm-core.md` (Gemini @import) per §0-7 ("Contracts in drllm-core.md … 스킬 SKILL.md 에 중복 정의 금지(본 문서 참조만)") — no contract duplication.
- `tutor.toml` `{{args}}` for optional session_id is the right shape for Gemini command templates.
- L1 schema test passes; no regression introduced.

---

## 6. Verdict

**APPROVED** as a Task 7 skeleton. The implementation is a faithful plan literal, preserves the most contract-sensitive string (P5.2 prompt) exactly, and locks the TRIGGER / file-path contract that downstream tasks (14, 16, 20) depend on. Deferred items are correctly scoped; no critical or important issues for this task's scope.
