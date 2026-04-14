# Task 5 Code Review — S0 drllm-launcher Skill + /drllm:launch Command

**Reviewer**: Senior Code Reviewer (Claude Opus 4.6)
**Date**: 2026-04-14
**Base SHA**: 168f8ad
**HEAD SHA**: current HEAD (Task 5 commit)
**Scope**:
- `/home/namykim/workspace/DRLLM/skills/drllm-launcher/SKILL.md`
- `/home/namykim/workspace/DRLLM/commands/drllm/launch.toml`

---

## 0. Verdict

**APPROVED** — minor observations only. All plan requirements implemented verbatim; drllm-core v2 contracts upheld; L1 schema test passes.

---

## 1. Plan Alignment

Compared implementation against plan §Task 5 (lines 332-438 of
`/home/namykim/workspace/DRLLM/docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md`).

| Plan Requirement | Implementation | Status |
|------------------|----------------|--------|
| Frontmatter `name: drllm-launcher` | Present (line 2) | OK |
| Frontmatter `description` with dual trigger (slash + Korean NL) | Present (line 3), both paths named | OK |
| `# S0 — DRLLM Launcher` H1 | Present (line 6) | OK |
| Mission (Korean) | Present (lines 8-10) | OK |
| Inputs section with topic + optional domain | Present (lines 12-15) | OK |
| Protocol 7 steps | All present (lines 17-44) | OK |
| `metadata.json` JSON block with 9 fields | Exact match (lines 28-41) | OK |
| Hard Gate 2 items | Present (lines 46-49) | OK |
| Outputs | Present (lines 51-54) | OK |
| See Also with `@./context/drllm-core.md` + command ref | Present (lines 56-59) | OK |
| `launch.toml` description + prompt + `{{args}}` interpolation | Present (all 14 lines) | OK |
| Schema test `L1 schema: PASS` | Verified: `bash tests/schema/test-extension.sh` → PASS | OK |

No deviations from the plan text. The implementation is a byte-faithful transcription of the plan's specimen, which is appropriate for a skeleton whose concrete logic lands in Task 13.

---

## 2. Gemini CLI Skill Format Validity

### 2.1 Frontmatter YAML

- Extracted frontmatter (awk between the two `---` fences) and piped through `yq -e '.name and .description'` — passes.
- `tests/schema/test-extension.sh` iterates `skills/*/SKILL.md`, runs the same awk + yq pipeline, returns `L1 schema: PASS`. Verified live.
- Note: running `yq -e '.name and .description' skills/drllm-launcher/SKILL.md` directly on the full file errors because the YAML parser sees markdown body. This is expected — the test script's awk-extraction pattern is the correct approach and works.

### 2.2 Description Field — Dual Trigger Discoverability

```
DRLLM session entry point. Parses user topic, generates session slug via LLM,
initializes .drllm/sessions/ directory, and chains to research-execution.
TRIGGER when user invokes `/drllm:launch <topic>` or says "DRLLM으로 ... 학습 시작"
/ "DRLLM으로 ...에 대해 공부하자" in Korean or equivalent in English.
```

- Path 1 (slash): `/drllm:launch` literal appears in description — dispatcher can exact-match when a command routes through skill registry.
- Path 2 (Korean NL): Literal keywords `"DRLLM으로 ... 학습 시작"`, `"DRLLM으로 ...에 대해 공부하자"` — gives the dispatcher concrete substring anchors rather than relying on semantic drift. Good.
- Uses the `TRIGGER when ...` convention consistent with other skills in this workspace (e.g., `claude-api`, `superpowers:using-superpowers`). Consistent.
- Length is comfortable for prompt-embedding skill discovery.

### 2.3 launch.toml Prompt Interpolation

- Uses standard Gemini CLI `{{args}}` template variable. Present at both the topic line and a confirmation line (line 11) — the duplication is defensive (makes the topic survive an intermediate activate_skill round-trip) and not harmful.
- `activate_skill(skill_name="drllm-launcher")` follows the documented Gemini skill activation syntax.
- Hard gate mirror at line 13 ("If no topic is provided, ask the user for a topic and do not proceed.") properly echoes SKILL.md's Hard Gate 1.

---

## 3. drllm-core v2 Contract Compliance

Verified against `/home/namykim/workspace/DRLLM/context/drllm-core.md`.

### 3.1 §0-1 LLM 판단 최소화 — Step 2 slug generation

Slug generation is an LLM transformation (topic → kebab-case). Is this in tension with §0-1?

**Assessment: acceptable, with one soft recommendation.**

- §0-1 targets _decision_ branches ("subtopic 끝났다고 판단", "중요해 보이는 경우"). Slug generation is a *string shaping* operation, not a control-flow decision. No branch/assertion hangs off the slug's content.
- Non-determinism is bounded: session-ID collision handling at Step 3 (`-2`, `-3` suffix) makes the flow robust to different slugs for the same topic.
- Rules are explicit: ≤20 chars, noun-focused, hyphen separator — these are decidable post-conditions the LLM can self-check.

Soft recommendation (**Minor**): Task 13 should add a deterministic fallback: if LLM slug generation returns empty/invalid (regex `^[a-z0-9]+(-[a-z0-9]+){0,N}$` fails), fall back to `topic-<sha1(topic)[:8]>` or `session-<timestamp>`. Prevents §0-5 Fail loud violation on LLM output corruption. Not required in skeleton.

### 3.2 §0-3 No silent drop — Hard Gate coverage

Two Hard Gates (topic missing, metadata.json write failure) both explicitly forbid marker tool call. No silent drop.

Gap (**Minor**, defer to Task 13): mkdir failure at Step 4 is not an explicit Hard Gate. Plan line 1025 ("디렉토리 생성 실패: stderr 에러 출력 + marker 미호출") does call this out. The skeleton's two-gate list is plan-conformant, so this is a plan-level omission from Task 5 rather than an implementation miss. Task 13 should add a third Hard Gate for mkdir failure. Raised here so it isn't forgotten.

### 3.3 §0-4 Strict schema — metadata.json

Schema in SKILL.md (lines 28-41) matches drllm-core §5.1 field-for-field:

| Field | drllm-core §5.1 | SKILL.md | Match |
|-------|-----------------|----------|-------|
| session_id | `"<YYYYMMDD>-<slug>"` | `"<YYYYMMDD>-<slug>"` | OK |
| topic | `"<사용자 원본 주제, 한국어 OK>"` | `"<원본 주제>"` | OK (semantic equivalent; "한국어 OK" is a policy note, not a field literal) |
| slug | `"<kebab-case english slug>"` | `"<slug>"` | OK |
| domain | `"<domain profile name, e.g. born2beroot>"` | `"born2beroot"` | OK (hard-coded v0.1 default is plan-conformant per spec Q1) |
| started_at | `"<ISO 8601 with KST offset>"` | `"<ISO 8601 KST>"` | OK (semantically identical; Task 13 must enforce `+09:00` suffix) |
| completed_at | `null` | `null` | OK |
| status | `"research"` | `"research"` | OK |
| url_verify_total | `0` | `0` | OK |
| url_verify_count | `0` | `0` | OK |
| url_verify_ratio | `0.0` | `0.0` | OK |

No field rename, no additional fields, no missing fields. §0-4 satisfied.

### 3.4 §0-6 Explicit state transitions

Initial `status="research"` set at creation. No implicit transitions in S0. OK.

### 3.5 §0-7 Contracts in drllm-core

SKILL.md's See Also correctly references `@./context/drllm-core.md` §5 rather than duplicating schema reasoning. The metadata.json block in SKILL.md is a specimen, not a competing definition. OK.

### 3.6 §1.1 `.drllm/sessions/LATEST` — expected gap

drllm-core §1.1 requires S0 to update `.drllm/sessions/LATEST` so S2/S4 can rediscover the session. Task 5 skeleton does not mention this.

**Assessment: expected gap.** Context for this review explicitly notes "skeleton 에서 언급 없는 것 OK, Task 13 에서 추가." Plan lines 995-1020 (Task 13 body) are the correct home for this. Raised here only so Task 13 review can check it off.

---

## 4. Marker Tool & Hook Integration

### 4.1 Marker pattern match

- Skeleton emits: `save_memory("__drllm_s0_done_<session_id>")`
- Task 16 hook matcher (plan line 1322): `[ "$tool_name" = "save_memory" ] && echo "$tool_input" | grep -q '__drllm_s0_done_'`
- Hook test fixtures (plan lines 1351, 1391): `"__drllm_s0_done_20260414-test"`, `"__drllm_s0_done_xxx"`

The hook uses an un-anchored grep for `__drllm_s0_done_`. The skeleton's literal prefix matches this pattern unambiguously. A session_id like `20260414-<slug>` contains hyphens and digits only — no collision with `__drllm_s2_done_`. OK.

**Minor observation**: `save_memory` is a Gemini-side tool (note: context surfaces `save_memory` as a known tool, not a repo-local one). The hook observes it via the AfterTool JSON payload. Skeleton is consistent with this integration contract.

### 4.2 AfterTool sequencing

Marker is Step 7 (final). Hard Gates short-circuit before Step 7. This is the correct ordering — no marker if initialization failed. §0-3 upheld.

---

## 5. Documentation & Conventions

- Frontmatter in English (per plan convention), body in Korean (per plan Step 1 header "frontmatter 영어, 본문 한국어"). Consistent.
- Backticks used for all file paths and tool names. Consistent with other DRLLM docs.
- Korean honorifics/tone in Mission and user-facing notifications match drllm-core §2 ("사용자 대면 응답 / 학습 대화: 한국어").
- launch.toml prompt is in English (internal orchestration) — §2 says internal logging/metadata is English; the prompt is neither strictly user-facing text nor logging. Current placement is acceptable; no change needed.

---

## 6. Issue Summary

### Critical
_(none)_

### Important
_(none)_

### Minor / Suggestions (all deferrable to Task 13)

1. **Slug fallback**: add deterministic regex-validated fallback for LLM slug generation failure. (§0-5 Fail loud hardening.)
2. **mkdir Hard Gate**: add a third Hard Gate for `.drllm/sessions/<session_id>/` mkdir failure. Plan line 1025 already specifies this — just ensure Task 13 implementation adds it to SKILL.md's Hard Gate section.
3. **LATEST file contract**: Task 13 must add the `.drllm/sessions/LATEST` write step required by drllm-core §1.1.
4. **ISO 8601 KST literal**: Task 13 must enforce `+09:00` offset (not just `KST` abbreviation) in `started_at` to satisfy §5.1 "ISO 8601 with KST offset".

---

## 7. What Went Well

- Byte-for-byte fidelity to the plan's specimen — no invention, no drift, reviewer can diff and move on.
- Dual-trigger description includes literal Korean anchor phrases rather than vague semantic hints, which gives the dispatcher something concrete to match.
- Marker pattern `__drllm_s0_done_<session_id>` is already Task 16-compatible (verified against hook grep pattern).
- Hard Gate list correctly couples failure modes to marker-tool suppression (§0-3).
- See Also uses `@import` reference rather than duplicating schema (§0-7).
- L1 schema test updated and passing in the same Task; no regression risk carried forward.

---

## 8. Files Referenced

- `/home/namykim/workspace/DRLLM/skills/drllm-launcher/SKILL.md`
- `/home/namykim/workspace/DRLLM/commands/drllm/launch.toml`
- `/home/namykim/workspace/DRLLM/docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` (Task 5 at lines 332-438; Task 13 at ~941-1033; Task 16 at ~1307-1416)
- `/home/namykim/workspace/DRLLM/context/drllm-core.md` (§0, §1.1, §2, §5.1)
- `/home/namykim/workspace/DRLLM/tests/schema/test-extension.sh`
