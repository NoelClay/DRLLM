# Task 08 — Code Review: `tests/manual/smoke-step2.md`

**Reviewer**: Senior Code Reviewer (Claude Opus 4.6)
**Date**: 2026-04-14
**Base SHA**: `aee59d0`  **Head SHA**: `d4903fe`
**Artifact**: `/home/namykim/workspace/DRLLM/tests/manual/smoke-step2.md` (23 lines)
**Plan reference**: `docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md` Task 8 (L623–669)
**Spec reference**: `docs/superpowers/specs/2026-04-14-sp1-tiny-drllm-design.md` §7.2 Commit Point 2

---

## TL;DR

**Status**: CHANGES REQUESTED

- **Critical**: 1  (checklist item 2 uses an invalid Gemini CLI slash-command syntax — the smoke would always fail at that step regardless of artifact correctness)
- **Important**: 2  (diagnostic for `/extensions list` missing DRLLM points at Task 1 only, but `gemini extensions link .` failure is a more common root cause; S2/S4 body-content assertion is too weak)
- **Minor**: 3  (nested fence hygiene, S0 body-quote exact-match fragility, template reusability hooks for smoke-step{3..6})

The artifact matches the plan literally (plan L632–656 = artifact L1–23), so the implementer faithfully executed Task 8 Step 1. However the **plan itself embeds an incorrect Gemini CLI invocation**, which propagates into the smoke checklist. This is a plan defect surfaced at implementation time; the fix must either (a) amend the plan + artifact together, or (b) document it as a known-bad rung in the plan and correct only the artifact.

---

## 1. Plan Alignment

Line-by-line comparison against plan Task 8 Step 1 (L632–656):

| Plan element | Artifact | Match? |
|---|---|---|
| Title `# Step 2 Smoke Test — 3 스킬 로딩 확인` | L1 | exact |
| Setup `cd … && gemini extensions link .` | L5–8 | exact |
| 6 checklist items | L12–17 | exact (order + wording) |
| 3 failure diagnostics | L21–23 | exact |
| File location `tests/manual/smoke-step2.md` | created | exact |
| Commit message `feat: 3 skills + 3 commands skeleton` | `d4903fe` | exact (matches spec §7.2 Commit Point 2) |

**Verdict**: perfect fidelity to the plan. No deviation. No unjustified addition. Task 8 Step 2 (human execution) and Step 3 (commit) are satisfied by `d4903fe`.

The **commit scope** (`d4903fe`) contains only `tests/manual/smoke-step2.md` (+23 lines). The commit message however labels the commit as "3 skills + 3 commands skeleton" per spec §7.2, which is technically the *milestone* label for STEP 2 — consistent with plan L666 and spec L466. No scope creep.

---

## 2. Correctness Review (the substantive part)

### 2.1 Setup command — CORRECT

`gemini extensions link .` is the canonical Gemini CLI command for local extension development per geminicli.com/docs/extensions/writing-extensions and the `/extensions` subcommand reference (`link` — "Link an extension from a local path"). Verified via Gemini CLI public docs. No issue.

### 2.2 Checklist item 1 — `/extensions` to list DRLLM — AMBIGUOUS

Line 12: `` `/extensions` 명령으로 DRLLM 표시 확인 ``

The `/extensions` slash command is a **command group**, not a lister. Per Gemini CLI reference, the lister subcommand is **`/extensions list`**. Bare `/extensions` likely prints subcommand help, not a list of installed extensions. The operator running this checklist will see the help screen and have to guess which subcommand to run.

**Recommendation** (Important): change line 12 to

```
- [ ] `gemini` 진입 후 `/extensions list` 로 DRLLM 표시 확인 (active 상태)
```

This matches the documented subcommand and makes the operator's job deterministic (§0-5 Fail loud — no guessing).

### 2.3 Checklist item 2 — `/extensions drllm` detail view — **CRITICAL / INVALID COMMAND**

Line 13: `` `/extensions drllm` 으로 버전 0.1.0, 3 skills, 3 commands 표시 ``

The `/extensions` command has subcommands `config | disable | enable | explore | install | link | list | restart | uninstall | update`. There is **no bare `<name>` form** — `/extensions drllm` is an invalid invocation and will either error or print help. The checklist as written can never pass.

**Likely intents**:
- (a) `/extensions list` — already gives name + version + state for all extensions; with DRLLM as the only extension this is sufficient evidence.
- (b) Inspect loaded artifacts directly: after link, the 3 skills and 3 commands manifest by their visibility to `activate_skill` and to `/drllm:` autocomplete — both already covered by items 3–6.
- (c) Filesystem assertion: `ls ~/.gemini/extensions/` should symlink to repo.

**Recommendation** (Critical): replace line 13 with, e.g.,

```
- [ ] `/extensions list` 출력에서 `DRLLM  0.1.0  active` 행 확인
- [ ] `ls ~/.gemini/extensions/` 에서 DRLLM → 본 repo 로의 symlink 확인
```

This reshapes the item into two deterministic sub-checks and removes the invalid command. Bonus: matches drllm-core v2 §0 robust-design principle 2 (Evidence-first — "파일 경로 … 도구 응답 필드" as the check medium).

Because this is a plan-literal import, the correction must be propagated to the plan as well (plan L645).

### 2.4 Checklist items 3–5 — `activate_skill(...)` manual calls — PARTIALLY VALID

Lines 14–16. Manually invoking `activate_skill("<skill-name>")` from the Gemini chat is a valid way to verify that the CLI discovered the SKILL.md files and indexed each `name:` frontmatter field. The expected-output assertion however varies by rigor:

- **L14 (S0)**: ``→ S0 본문("S0 — DRLLM Launcher") 반환 확인`` — the quoted string matches `skills/drllm-launcher/SKILL.md:6` exactly. Good.
- **L15 (S2)** and **L16 (S4)**: ``→ S2 본문 반환 확인`` / ``→ S4 본문 반환 확인`` — there is no exact quoted anchor, so "S2 본문" is under-specified. A pass/fail judgement requires the operator to know the heading.

**Recommendation** (Important): for symmetry and Fail-loud clarity, assert exact heading strings on all three items:

```
- [ ] activate_skill("drllm-research-execution") → "S2 — DRLLM Research Execution" 헤더 확인
- [ ] activate_skill("drllm-adaptive-tutoring")  → "S4 — DRLLM Adaptive Tutoring"  헤더 확인
```

These strings are grep-verified against the real SKILL.md files (`skills/*/SKILL.md:6`).

**Sub-concern (Minor)**: relying on exact body substring is fragile against future body edits (especially likely since plan Task 10–13 will expand S2/S4). If the smoke checklist is meant to outlive skeleton stage, anchor to something structural rather than prose — e.g. presence of `## Mission (한국어)` heading (invariant across all 3 skills by convention) + the `name:` frontmatter echo. For v0.1 skeleton, the current approach is adequate.

### 2.5 Checklist item 6 — `/drllm:` autocomplete — VALID BUT WEAK

Line 17: `/drllm:launch` 자동완성으로 3개 command 표시 확인.

Typing `/drllm:launch` already commits to the `launch` prefix; autocomplete on that prefix will not show `research`/`tutor`. The operator likely needs to type `/drllm:` (colon as trigger) to see all three.

**Recommendation** (Minor): change to `/drllm:` (trailing colon, no command). Also add description-string sanity — each command has a `description = "..."` field (verified in `commands/drllm/*.toml`) and autocomplete shows it; a pass-criterion like "3 항목 모두 description 노출 없이 비어 있지 않음" makes TOML-parse errors loud.

### 2.6 "실패 시" diagnostics — GOOD, WITH ONE GAP

L21–23 map three failure modes to backtrack targets. Assessment against §0-5 Fail loud:

- **L21 "DRLLM 미표시 → Task 1"**: strictly speaking Task 1 created the extension manifest; but the most common cause of "DRLLM 미표시" on a *fresh* smoke is forgetting `gemini extensions link .` (Setup step skipped) or the symlink landing in a wrong `~/.gemini/extensions` root. Plan/artifact routes the operator to re-examine `gemini-extension.json` first, which is the deeper cause but not the most likely one.

  **Recommendation** (Important): add a pre-Task-1 rung:
  ```
  - DRLLM 미표시:
    1) `~/.gemini/extensions/DRLLM` symlink 존재 확인 (없으면 `gemini extensions link .` 재실행)
    2) 존재하지만 inactive → `gemini extensions enable DRLLM`
    3) 그래도 안 되면 `gemini-extension.json` schema 오류 → Task 1 재확인
  ```

- **L22 "activate_skill 실패 → Task 5~7 name 확인"**: correctly maps symptom to the frontmatter-name contract. The `name:` fields are verified against the smoke checklist strings:

  | Skill | SKILL.md `name:` | checklist arg | match |
  |---|---|---|---|
  | S0 | `drllm-launcher` | `"drllm-launcher"` | ok |
  | S2 | `drllm-research-execution` | `"drllm-research-execution"` | ok |
  | S4 | `drllm-adaptive-tutoring` | `"drllm-adaptive-tutoring"` | ok |

  Strings match. Good.

- **L23 "command 미표시 → TOML `description` / `prompt` 필드 확인"**: correct. All three TOMLs (`launch.toml`, `research.toml`, `tutor.toml`) contain both fields (verified). No issue.

### 2.7 drllm-core v2 §0-5 contract alignment

The smoke checklist is a runtime verification for STEP 2 skeleton, not a contract enforcer. Still, two indirect touchpoints:

- **§5 schema**: not verifiable at skeleton stage (no session created yet). Correctly omitted.
- **§6 HARD STOPS**: not applicable until S4 body executes. Correctly omitted.
- **§0-5 Fail loud**: the "실패 시" block *is* the Fail-loud hook. The recommendation in 2.6 tightens adherence (explicit diagnosis order rather than single-cause mapping).

No contract violation.

---

## 3. Markdown / Rendering Hygiene

### 3.1 Nested fences — OK

The artifact uses a 3-backtick `bash` fence at L5–8. Since the *artifact itself* is the top-level markdown (not embedded in another fenced block), 3-backtick is correct. The plan (Task 8 Step 1, L632–656) wraps the artifact in a 3-backtick `markdown` block that contains a *nested* 3-backtick bash block — this is unusual in Markdown/CommonMark and will break rendering on GitHub unless the outer fence uses 4 backticks. Plan L632 opens with triple-backtick which means the inner triple-backtick on plan L637 closes the outer fence early.

**Status**: this is a **plan rendering defect**, not an artifact defect. The implementer correctly produced a well-formed standalone markdown file. But when the plan is rendered on GitHub, Task 8 instructions will visually fragment. The plan author should upgrade plan L632 / L656 fences to 4-backtick.

**Recommendation** (Minor, plan-side): promote plan L632 and L656 outer fences to 4-backtick to protect the inner `bash` block.

### 3.2 Hangul + em-dash

Title contains em-dash `—` (U+2014) between Korean words. Rendered fine on GitHub; fine in Gemini CLI terminal (UTF-8). No issue.

### 3.3 BOM / encoding

File is UTF-8 without BOM (verified via octal dump). No issue.

---

## 4. Template Reusability (for smoke-step{3,4,5,6}.md)

The file's three-section skeleton (`## Setup` → `## Checklist` → `## 실패 시`) is a solid template. Recommendations to harden before stamping 4 more copies:

1. **Lift a shared header convention** — e.g. always include `**Prereq**: previous smoke passed` to prevent operators running step-N smoke on a broken step-(N-1) base.
2. **Promote "Setup" to include a sanity pre-flight** — e.g. `git log -1 --oneline` to pin HEAD SHA into the smoke output log.
3. **Add an `## Evidence` section** — a one-line stdout/screenshot capture guidance so the smoke produces an audit trail (maps to drllm-core v2 §0 principle 2 Evidence-first and principle 3 No silent drop).
4. **Bind failure rungs to explicit task numbers** — the current format does this (Task 1 / Task 5~7). Keep this convention rigorously across step{3..6} files, mapping to the corresponding plan tasks.

Not a defect in Task 8 scope, but worth fixing the template now rather than copy-pasting the bugs 4×.

---

## 5. What Was Done Well

- **Literal plan fidelity**: no freelancing; the implementer did not "improve" the plan unilaterally. This makes the plan/artifact discrepancy (see 2.3) diagnosable at the plan level.
- **Commit message matches spec §7.2 verbatim** (`feat: 3 skills + 3 commands skeleton`) — the auditable milestone anchor is intact.
- **Scope discipline**: +23 lines, one new file. No stray edits.
- **Korean / English split**: user-facing checklist in Korean per drllm-core §2 language policy; TOML / JSON field names in English. Consistent.
- **Failure block is present** — many teams skip "what if it fails"; this artifact models it.

---

## 6. Recommended Action Items (prioritized)

### Critical (must fix before Task 9)
- [ ] **C1**: replace `` `/extensions drllm` `` (invalid) in artifact L13 with `/extensions list` + symlink check. Propagate the fix to plan L645.

### Important (should fix before stamping smoke-step{3..6})
- [ ] **I1**: `/extensions` → `/extensions list` in artifact L12 (and plan L644).
- [ ] **I2**: tighten S2 / S4 assertions to exact heading strings ("S2 — DRLLM Research Execution", "S4 — DRLLM Adaptive Tutoring") in artifact L15–16.
- [ ] **I3**: expand "DRLLM 미표시" diagnostic to 3-rung ladder (symlink → enable → manifest).

### Minor (nice to have)
- [ ] **M1**: change `/drllm:launch` → `/drllm:` in artifact L17 to trigger full autocomplete.
- [ ] **M2**: plan-side fence bump (L632 / L656) to 4-backtick for GitHub rendering.
- [ ] **M3**: define a shared `Setup / Checklist / Evidence / 실패 시` template header comment at the top of `tests/manual/` README before the next 4 smoke files land.

---

## 7. Confirmation Request to Implementer

Two items need decision before proceeding:

1. The `/extensions drllm` defect originates in the plan, not the implementer's work. Does the implementer want to (a) patch plan + artifact in a dedicated fix commit, or (b) open a plan errata note and fix only the artifact?
2. Are the Important recommendations (I1–I3) in scope for a post-STEP-2 fix commit, or should they be deferred to a "smoke-step2 revision" line item after the human operator actually runs the current checklist and observes the failures?

If the implementer can confirm either disposition, Task 8 can be marked **APPROVED with follow-ups**. As-is, the checklist cannot pass item 2, so I must return **CHANGES REQUESTED**.

---

## Appendix A — Evidence Sources

- Artifact: `/home/namykim/workspace/DRLLM/tests/manual/smoke-step2.md` (23 lines)
- Plan: plan Task 8 at L623–669
- Spec §7.2: `docs/superpowers/specs/2026-04-14-sp1-tiny-drllm-design.md` L462–472
- drllm-core v2 §0 principles: `context/drllm-core.md` L6–17
- Gemini CLI docs: `/extensions` subcommand list (config, disable, enable, explore, install, link, list, restart, uninstall, update) — geminicli.com/docs/reference/commands
- SKILL.md `name:` frontmatter verification: `skills/drllm-*/SKILL.md:2`
- Command TOML field verification: `commands/drllm/*.toml`
