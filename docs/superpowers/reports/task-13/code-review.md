# Task 13 Code Review — S0 drllm-launcher Protocol concrete

- **Status**: APPROVED
- **Base SHA**: `44dfc39` (Task 12)
- **Head SHA**: `67c3c28` (Task 13)
- **Files changed**: `skills/drllm-launcher/SKILL.md` (+58 / -18)
- **Schema test**: `./tools/run-tests.sh` → `L1 schema: PASS`
- **Date**: 2026-04-14

---

## 1. Plan Alignment

The replaced `## Protocol` / `## Hard Gate` block in `/home/namykim/workspace/DRLLM/skills/drllm-launcher/SKILL.md`
(lines 17-89) is a verbatim match to the plan literal at
`/home/namykim/workspace/DRLLM/docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md`
lines 937-1009. No deviations.

The only visible difference is fence syntax: the plan's literal was embedded inside a triple-backtick
markdown block, so the implementer correctly escalated inner fences to quad-backticks (`` ```` ``) to
avoid prematurely closing the outer block. This is a *rendering-correctness* change, not a semantic
deviation. Markdown renderers treat quad-backticks identically.

Pre-existing frontmatter (`name`, `description`), `## Mission`, `## Inputs`, `## Outputs`, `## See Also`
sections are untouched — consistent with the plan's "Replace the `## Protocol` section" scope.

---

## 2. Contract Consistency (drllm-core v2)

### 2.1 metadata.json schema (§5.1)

Verified field-by-field against `/home/namykim/workspace/DRLLM/context/drllm-core.md` lines 130-147:

| # | Field | drllm-core §5.1 | SKILL.md §5 | Match |
|---|---|---|---|---|
| 1 | `session_id` | `<YYYYMMDD>-<slug>` | `<session_id>` | OK (same value, template form) |
| 2 | `topic` | `<사용자 원본 주제, 한국어 OK>` | `<원본 주제, 한국어 OK>` | OK |
| 3 | `slug` | `<kebab-case english slug>` | `<slug>` | OK |
| 4 | `domain` | `<domain profile name, e.g. born2beroot>` | `"born2beroot"` (literal) | OK for v0.1 (see §3 below) |
| 5 | `started_at` | `<ISO 8601 with KST offset>` | `<ISO 8601 with KST offset, e.g. 2026-04-14T10:30:00+09:00>` | OK (example is clarifying) |
| 6 | `completed_at` | `null` | `null` | OK |
| 7 | `status` | `"research"` (allowed values listed) | `"research"` | OK |
| 8 | `url_verify_total` | `0` | `0` | OK |
| 9 | `url_verify_count` | `0` | `0` | OK |
| 10 | `url_verify_ratio` | `0.0` | `0.0` | OK |

Field order matches. No renames, no additions, no omissions. §0-4 (Strict schema everywhere) satisfied.

### 2.2 §1.1 session_id discovery contract — **LATEST file not written**

drllm-core §1.1 step 2 specifies:
> `.drllm/sessions/LATEST` 파일이 존재하면 그 안의 한 줄 텍스트를 `session_id`로 사용(S0가 갱신)

The parenthetical explicitly assigns LATEST-file update responsibility to S0.
Task 13's Protocol §§1-7 does NOT write `.drllm/sessions/LATEST`.

**Impact analysis**:
- S2 / S4 still discover the session via step 3 (mtime + status filter), so single-session flows
  work correctly in Task 15 smoke.
- Multi-session case (two S0 sessions created before S2 runs on either) becomes ambiguous:
  mtime on the directory could be overwritten by any file write inside either session, and
  status="research" matches both. S2 would pick the most-recently-touched — probabilistically
  correct but not deterministic.
- Hook auto-chain (Task 16) fires immediately after S0 marker, so in practice the race window is
  small. Not a v0.1 blocker.

**Recommendation**: Acceptable as-is for v0.1 because (a) the plan scope of Task 13 explicitly
ends at marker call, (b) §1.1 step 3 fallback is designed to cover exactly this case, and
(c) single-session smoke (Task 15) will exercise the happy path. Suggest adding a Task 16
addendum: hook can update `.drllm/sessions/LATEST` by extracting `session_id` from the
`__drllm_s0_done_<session_id>` marker prefix before invoking S2 — keeping S0 skeleton untouched
and centralizing LATEST-file lifecycle in the hook layer.

### 2.3 §0 Robust principles

| Principle | Evidence in SKILL.md | Status |
|---|---|---|
| §0-1 LLM judgement minimization | §3 session_id is pure deterministic bash; §2 slug rules are explicit (5 rules, 20-char cap, suffix loop `2 3 4 5`). | OK |
| §0-3 No silent drop | Hard Gate explicitly forbids marker call on empty topic / mkdir fail / metadata fail; hook therefore never auto-chains on failure. | OK |
| §0-4 Strict schema | §5 matches §5.1 field-for-field (see 2.1). | OK |
| §0-5 Fail loud + rollback | Hard Gate 3: `rm -rf` on metadata failure → no partial session directory stays behind. | OK |
| §0-6 Explicit state transitions | `status: "research"` hardcoded at creation — single well-defined entry state; downstream transitions live in S2 / S4. | OK |

---

## 3. Quality Observations

### 3.1 Slug generation (§2)

Five explicit rules + a concrete example. §0-1-compliant (LLM follows rules, not judgement).
The example `innodb-buffer-pool-default-size` is 33 characters, violating the "최대 영어 20자"
rule in the rules list immediately above it. This is a **minor internal inconsistency** in the
literal the user drafted; downstream impact is zero (the slug is only a filename segment),
and the LLM may anyway produce a shorter variant. Not worth fixing — the plan literal is
load-bearing for repeatability and the example value is pedagogical. Flagged for awareness.

### 3.2 Shell safety of `rm -rf`

Hard Gate 3 calls `rm -rf .drllm/sessions/${session_id}`. `session_id` is produced by §§2-3,
which constrain it to `[a-z0-9-]` (kebab-case lowercase) concatenated with a numeric date
prefix. No path separators, no shell metacharacters, no variable expansion from user input.
Safe. Worth noting that §3's bash also uses `[ -d ".drllm/sessions/${session_id}" ]` — same
variable, same safety basis.

### 3.3 Tool naming in §3

"LLM은 위 로직을 shell 명령 혹은 Python으로 실행하여 최종 session_id 확정."
Gemini CLI exposes `run_shell_command`; this is left implicit. Acceptable for skeleton because
(a) Task 15 smoke will exercise the actual tool, (b) cross-runtime portability is a stated v0.5
goal, and (c) skill authors should not hard-code one runtime's tool name into Protocol text.

### 3.4 Hardcoded `domain: "born2beroot"`

Matches plan literal. v0.5 scope will replace with `DRLLM_DOMAIN_PROFILE`-derived value
(per user brief). Acceptable for v0.1.

### 3.5 Korean blockquote format (§6)

`> "세션 \`<session_id>\` 시작. 주제: <topic>. 리서치 진행 중..."`
Matches plan. Backtick-delimited session_id renders as inline code in markdown-aware clients.
No conflict with drllm-core §2 language policy (user-facing → Korean).

### 3.6 Marker prefix alignment

`save_memory("__drllm_s0_done_<session_id>")` — the `__drllm_s0_done_` prefix is stable; Task 16
hook grep pattern will prefix-match this literal. No collision risk with other markers (S2:
`__drllm_s2_done_`, etc.). OK.

---

## 4. Issues

| Severity | Item | Location | Notes |
|---|---|---|---|
| Critical | (none) | — | — |
| Important | (none within Task 13 scope) | — | LATEST-file update (§2.2) is deferred to Task 16 hook addendum by design; not a Task 13 defect. |
| Minor | slug rule vs example length mismatch | SKILL.md §2 | `innodb-buffer-pool-default-size` = 33 chars vs "최대 영어 20자" rule. Plan-literal, no impact. |

---

## 5. What was done well

- Exact plan-literal reproduction including quad-backtick escape for nested fences.
- All 9 metadata fields in the schema block match drllm-core §5.1 field-for-field, in order.
- Hard Gate adds `rm -rf` rollback on metadata failure — strict improvement over the prior skeleton (which only had 2 gates without rollback).
- §3 suffix loop bound `2 3 4 5` gives a deterministic max of 5 sessions/day/slug — small, bounded, no infinite loop risk.
- Marker prefix (`__drllm_s0_done_`) is consistent with the hook-dispatch pattern established in Tasks 11-12.
- L1 schema test green.

---

## 6. Follow-up (not blocking Task 13)

- Task 16 (hook implementation) should pick one of: (a) S0 writes `.drllm/sessions/LATEST`
  before marker, or (b) hook extracts `session_id` from marker and writes LATEST before
  chaining to S2. Preference: (b) — centralizes LATEST lifecycle in the hook layer and
  keeps S0 skeleton untouched.
- Task 15 smoke should explicitly verify: (i) `mkdir -p` success case, (ii) metadata.json
  contains exactly 9 fields with correct values, (iii) `save_memory` marker fires with
  correct prefix, (iv) empty-topic path does NOT create a session directory.
- v0.5 planning should budget replacement of `domain: "born2beroot"` literal with
  profile-driven value.
