# Task 6 Code Review — S2 drllm-research-execution skeleton + research command

**Scope:** Task 6 of `/home/namykim/workspace/DRLLM/docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md`
**Commit range:** `ff145ee` (HEAD~1, Task 5) → `88bd8ae` (HEAD, Task 6)
**Diff size:** 2 files, 55 insertions (skeleton scope as planned).

**Files under review:**
- `/home/namykim/workspace/DRLLM/skills/drllm-research-execution/SKILL.md` (new)
- `/home/namykim/workspace/DRLLM/commands/drllm/research.toml` (new)

## Status

APPROVED — skeleton faithfully implements Task 6 plan and aligns with drllm-core v2 contract for the declared scope.

## Plan Alignment

**Byte-for-byte match vs. plan text:**

- SKILL.md frontmatter `name` and `description`: identical to plan lines 453–454.
- Mission / Inputs / Protocol (9 steps) / Hard Gate (3 items) / Outputs / See Also: identical to plan lines 457–495.
- `research.toml` `description` + `prompt` body: identical to plan lines 503–513.
- Commit message `feat: S2 drllm-research-execution skeleton + research command`: matches plan line 525.
- Tests: `./tools/run-tests.sh` → `L1 schema: PASS` + `Automated tests: PASS`.

No scope creep, no unplanned additions.

## drllm-core v2 Contract Conformance (per review focus list)

### 1. Dual trigger expression — PASS

`description` contains both `__drllm_s0_done_*` and `/drllm:research`. The marker prefix `__drllm_s0_done_` exactly matches the Task 16 hook grep `grep -q '__drllm_s0_done_'` (plan line 1322). The absence of a natural-language Korean trigger is intentional per the description context — S0 is the user-facing entry point; S2 is reached via hook auto-chain or explicit slash command.

### 2. session_id discovery contract (drllm-core §1.1, S2 case) — MINOR

Skeleton Protocol step 1 says `metadata.json 로드, status=="research" 확인` without referencing §1.1's 3-step discovery order (args → `LATEST` file → mtime+status filter). The `research.toml` prompt collapses §1.1 into "If session_id is provided, target that session. Otherwise use the latest .drllm/sessions/ entry." This abbreviation drops the `LATEST` file intermediate step and the `status == "research"` filter on mtime resolution.

For skeleton scope this is acceptable — Task 10 will replace the Protocol body and can restore §1.1 precision there. Flagging as a Minor forward note: Task 10 Step 1 should either (a) inline the 3-step discovery from §1.1 or (b) add a pointer such as `session_id 해석은 drllm-core.md §1.1 (S2 절)` so downstream readers don't re-invent the precedence.

### 3. Protocol 9-step completeness vs. Tasks 10–12 expansion — PASS

Cross-checked each step against the expansion targets:

| Step | Skeleton title | Expands in | Anchor OK? |
|------|----------------|------------|-----------|
| 1 | metadata 로드 + status 확인 | Task 10 Step 1 | Yes |
| 2 | domain profile 로드 | Task 10 | Yes |
| 3 | 인라인 쿼리 분해 (2–4 서브쿼리) | Task 10 | Yes (env `DRLLM_RESEARCH_MAX_SUBQUERIES` already listed in Inputs) |
| 4 | fetch MCP 병렬 호출 | Task 11 | Yes |
| 5 | Layer 2 Call 1 (schema 강제) | Task 11 | Yes |
| 6 | Layer 2 Call 2 (substring verify) | Task 12 | Yes |
| 7 | research-results.md 작성 | Task 12 | Yes |
| 8 | metadata.json 갱신 | Task 12 + Task ~21 (ratio rounding) | Yes |
| 9 | marker save_memory | Task 12 | Yes |

One-to-one mapping holds. No orphan steps.

### 4. Hard Gate vs. drllm-core §6 HARD STOPS — PASS (S2 scope)

- §6-3 (empty citations → `status="research_failed"`): reflected in Hard Gate item 2 (fetch 전 실패 케이스). S2의 "모든 citations verified=false" 부분은 Hard Gate item 3. Literal §6-3 문구 ("citations 배열이 빈 채로 research-results.md 작성 금지") 는 Task 12 expansion 시 Protocol step 7의 전제조건으로 명시해야 함 — skeleton 단계에서는 Hard Gate 2(pre-fetch)+3(post-verify)로 양 끝을 커버하고 있어 기능적으로는 동등.
- §6-4 (`verified=false` 인용 금지): Protocol step 7 ("verified=false citation 제거 후 작성") + Hard Gate item 3 양쪽에 반영.
- §6-1, §6-2 (P5_MISSING/P5_SKIP): S4 전용, S2 범위 밖. 제외 정합.
- §6-5 (모호 시 중단): skeleton 범위 밖. Task 12에서 verified=false 처리 + 사용자 보고 로직으로 자연스럽게 포함 예정.
- §6-6 (explicit state transitions): Protocol step 8 `status="tutor"` 명시 갱신으로 충족.

### 5. metadata.json field names — PASS

Protocol step 8 lists `url_verify_total`, `url_verify_count`, `url_verify_ratio` — identical to drllm-core §5.1 schema and S0 launcher's initial values. Strict schema (§0-4) 준수.

### 6. Marker pattern — PASS

`__drllm_s2_done_<session_id>` (Protocol step 9) — prefix `__drllm_s2_done_` matches Task 16 hook grep pattern `grep -q '__drllm_s2_done_'` (plan line 1331). Test fixture `__drllm_s2_done_xxx` (plan line 1398) also prefix-matches.

### 7. See Also paths — PASS

Both paths use the established `@./context/...` convention used by the S0 launcher (`/home/namykim/workspace/DRLLM/skills/drllm-launcher/SKILL.md` line 58). Targets exist: `context/drllm-core.md` and `context/domains/born2beroot.md` confirmed present. Gemini `@import` relative-path form is valid for this repo convention.

Note: the `@./` prefix resolves relative to the importing skill's SKILL.md directory in strict Gemini semantics, but this repo (per S0 precedent) uses it relative to repo root. This is a project-wide convention question, not a Task 6 defect — the skill is consistent with its sibling.

### 8. research.toml `{{args}}` optional session_id — MINOR

`prompt` line 12 says "Otherwise use the latest .drllm/sessions/ entry." — it does not specify which "latest" (e.g., mtime? `LATEST` file? status-filtered?). drllm-core §1.1 S2 case defines a precise 3-step order. For a slash-command prompt this level of abbreviation is workable, but consider tightening when Task 10 lands — either defer selection entirely to the skill ("The skill will resolve session_id per drllm-core §1.1") or replicate the precedence succinctly.

## Code Quality Observations

### Strengths

- **Skeleton discipline:** nothing from Task 10/11/12 leaked in prematurely. The "상세는 Task 10~12에서 확장" annotation on the Protocol header makes the deferred scope explicit to any reviewer landing on this commit mid-stream.
- **Consistency with S0 launcher:** Mission-in-Korean, Inputs/Protocol/Hard Gate/Outputs/See Also section order, and YAML frontmatter structure all match the established pattern from `skills/drllm-launcher/SKILL.md`. Downstream reviewers can navigate both skills identically.
- **Trigger clarity:** the dual marker + slash-command phrasing in the description gives the hook-driver and the human-driver each a clear entry point, and keeps the skeleton free of ambiguous natural-language triggers that could compete with S0.
- **Env vars surfaced early:** `DRLLM_DOMAIN_PROFILE` and `DRLLM_RESEARCH_MAX_SUBQUERIES` are declared in Inputs even though the skeleton body does not consume them. This gives Task 10/11 a clear contract without retrofitting.
- **Hard Gate covers the three S2-owned §6 HARD STOPS** (status mismatch, fetch total failure, all-unverified) with short, checkable conditions — aligns with drllm-core §0-1 (결정적 조건) and §0-3 (no silent drop via `status="research_failed"` + user report).

### Minor / forward-looking notes (not blocking)

1. **§1.1 pointer:** Task 10 should add an explicit `drllm-core §1.1 (S2 절)` reference to Protocol step 1 so the 3-step session_id discovery precedence isn't rediscovered ad hoc.
2. **§6-3 literal text:** Task 12 expansion for Protocol step 7 should incorporate §6-3's exact phrasing ("citations 배열이 빈 채로 research-results.md 작성 금지") as a pre-write assertion, not only as a Hard Gate summary.
3. **`research.toml` "latest" wording:** once Task 10 defines §1.1 handling inside the skill, consider softening the toml prompt to "The skill resolves session_id per drllm-core §1.1" to avoid two diverging specifications of "latest."
4. **See Also `@./` semantics:** a one-line note in `drllm-core.md` on the intended resolution root (repo root vs. skill dir) would preempt future confusion, since strict Gemini `@import` and this repo's convention differ.

None of the above change behaviour of the skeleton; they are expansion guidance for Tasks 10–12 and documentation hygiene.

## Issue Summary

- **Critical:** 0
- **Important:** 0
- **Minor:** 4 (all forward-looking, deferred to Tasks 10–12 or cross-cutting doc hygiene)

## Recommendation

Proceed to Task 7. When Task 10 lands, explicitly cross-reference drllm-core §1.1 in the expanded Protocol step 1 and align the `research.toml` "latest" wording with whatever §1.1-compliant resolver the skill implements.
