# Task 20 + B2 Code Review

**Reviewer**: Senior Code Reviewer (review agent)
**Date**: 2026-04-14
**Base SHA**: `98bacd8`
**Head SHA**: `cf78ede`
**Branch**: `feat/sp1-tiny-drllm`
**Scope**: Task 20 (SP-1) + B2 timestamp-hallucination fix, atomic commit.

---

## Verdict

**CHANGES REQUIRED** (before merge to `main` / STEP 5 entry)

One Critical issue (heredoc variable-expansion injection / corruption risk on user-controlled strings) and one Important issue (duplicate list-number `3.` in S4 §4 + stale JSON block now inert) must be addressed. Everything else is solid — plan alignment is strong, tests pass, no functional regressions.

---

## Files Reviewed

| File | Lines | Δ | Role |
|------|-------|---|------|
| `context/drllm-core.md` | 261 | +35 | Authoritative contract (v2.2 bump) |
| `skills/drllm-launcher/SKILL.md` | 104 | +10/-5 | S0 metadata.json writer |
| `skills/drllm-research-execution/SKILL.md` | 183 | +7/-1 | S2 research-results.md writer |
| `skills/drllm-adaptive-tutoring/SKILL.md` | 217 | +52/-8 | S4 event batch writer + session close |
| `docs/superpowers/reports/task-20/implementer.md` | 154 | +154 | Provenance (non-authoritative) |

---

## Strengths

1. **Authoritative contract first, consumers second**. §1.2 in drllm-core.md is the normative source; skill files reference §1.2 + §6-8. The mental model ("core defines, skills implement") is preserved. No drift between core and skills detected.
2. **Exhaustive field list**. §1.2 enumerates all five timestamp carriers (metadata.json ×2, research-results.md frontmatter, learning-log.md frontmatter ×2, event tails). Nothing was left in LLM-generation territory.
3. **Batch-side-effects compatibility** (v2.1 §0-8). `NOW=$(date -Iseconds)` is captured *once* per turn and reused across multiple event lines in a single heredoc — no extra tool round-trips introduced, so the v2.1 latency property holds.
4. **HARD STOP integration**. §6-8 uses existing enforcement idiom (`세션 측정 무효화`, `aggregate 에서 [INVALID_TIMESTAMP] 기록 후 제외`) — consistent with items 1–2 wording. No new enforcement mechanism invented; reuses measurement-invalidation lever.
5. **Test discipline**. L1 schema + L2 bats 5/5 still PASS after contract bump. No false "we changed tests so they pass" move; no test was touched.
6. **Atomic commit**. Single SHA `cf78ede` carries all four authoritative files + report. Rollback is trivial.
7. **Self-review transparency** (implementer.md §Ambiguities resolved): the implementer explicitly flagged the `<<'EOF'` → `<<EOF` change as a deliberate trade-off, which made this review much faster.

---

## Issues

### [CRITICAL] C1 — Unquoted heredoc expands user-controlled strings in S4 §3.4

**Location**: `skills/drllm-adaptive-tutoring/SKILL.md:109-116` and `context/drllm-core.md:77-84`

**Change**: `<<'EOF'` → `<<EOF`. The single quotes *disabled* shell expansion; removing them enables expansion of `${NOW}` **and every other `$`/`` ` ``/`\` sequence that appears between EOF markers**.

**Concrete failure mode**:

The heredoc template (per §3.4):

```bash
NOW=$(date -Iseconds)
cat >> .drllm/sessions/<id>/learning-log.md <<EOF
[SUBTOPIC] <이름> | ${NOW}
[SOURCE] fetch::<url> | verified=true
[P5_CHECK] Q="<질문>" | A="<사용자 답변>" | score=<correct|partial|incorrect>
EOF
```

The `<질문>`, `<사용자 답변>`, `<url>`, `<이름>` slots are filled by the S4 agent from **user input and upstream S2 research output**. If any substitute contains:

| Substring | Effect under `<<EOF` |
|-----------|----------------------|
| `$HOME`, `$PATH`, `$USER` | Expanded silently → event records shell state, not user content |
| `$(cmd)` or `` `cmd` `` | **Arbitrary command execution** at event-write time |
| Trailing `\` before newline | Line continuation → next event line is merged |
| Unmatched `"` in user answer | Breaks the `Q="..."` quoting at read time (pre-existing — not caused by this change, but more dangerous now) |

Example P5_CHECK where user answered a question about shell:

- User types: `` What is `$(whoami)` ``
- S4 builds: `[P5_CHECK] Q="bash substitution 설명" | A="What is \`$(whoami)\`" | score=correct`
- Heredoc expands `$(whoami)` → writes `[P5_CHECK] ... A="What is namykim" ...`
- User's literal answer is lost; shell-injection primitive is present.

Even absent malice, real MySQL/InnoDB documentation quotes (a likely `[SOURCE]` verified citation body) contain `$` in SQL snippets (e.g., `SET @var := $FOO`), which will corrupt the log.

**Severity justification**: This is a **regression introduced by the B2 fix**. Pre-fix, the heredoc was `<<'EOF'` → user strings were preserved verbatim (at the cost of LLM having to inline-type a fake timestamp). Post-fix, timestamps are correct but user content integrity is compromised. In POC usage risk is low (single-user, trusted content), but the contract is normative for all future sessions and any citation containing `$` corrupts measurement.

**Recommended fix** (pick one, in order of preference):

1. **Keep `<<'EOF'` quoted heredoc, substitute `$NOW` literally via `sed` after the write**:
   ```bash
   NOW=$(date -Iseconds)
   cat >> log <<'EOF' | sed "s/__NOW__/${NOW}/g"
   [SUBTOPIC] <이름> | __NOW__
   ...
   EOF
   ```
   Actually simpler: write to tmp, sed-substitute, append. Preserves all `$` in user content.

2. **`printf` per-event instead of heredoc**:
   ```bash
   {
     printf '[SUBTOPIC] %s | %s\n' "$SUBTOPIC" "$NOW"
     printf '[SOURCE] fetch::%s | verified=true\n' "$URL"
     printf '[P5_CHECK] Q=%q | A=%q | score=%s\n' "$Q" "$A" "$SCORE"
   } >> log
   ```
   `%q` via `printf` provides shell-safe quoting for the answer field. This is the idiomatic bash fix and preserves v2.1 batch-side-effects (still a single `{ ... } >> log` redirection).

3. **Write timestamp placeholder, then in-place substitute**:
   Too brittle for POC; skip.

**Option 2 is the recommended fix.** Update §1.2 core template + S4 §3.4 together.

---

### [IMPORTANT] I1 — Duplicate list marker `3.` in S4 §4 session-종료 block

**Location**: `skills/drllm-adaptive-tutoring/SKILL.md:160` and `:173`

The numbered list in §4 reads: `1.` (shell capture) → `2.` (COMPLETE event append) → `3.` (metadata.json 갱신) → `3.` (사용자에게 요약). Two items labeled `3.` — second should be `4.`.

Additionally: the `3. metadata.json 갱신` block now contains an **inert artifact**:

```bash
# NOW, DURATION already captured above
```

followed by a JSON code fence `{ "completed_at": "${NOW}", ... }`. The bash comment block is vestigial (contains no command) and the JSON block uses `${NOW}` notation inside a fence labeled `json` — a reader could reasonably mistake this for "write this JSON verbatim" (with `${NOW}` as a literal string).

**Recommended fix**:

1. Renumber the second `3.` → `4.`.
2. Drop the empty bash block (`# NOW, DURATION already captured above`).
3. Either (a) change the JSON fence to a bash block that does the substitution:
   ```bash
   jq --arg now "$NOW" '.completed_at=$now | .status="done"' \
     ".drllm/sessions/${session_id}/metadata.json" > tmp && \
     mv tmp ".drllm/sessions/${session_id}/metadata.json"
   ```
   or (b) add a prose line above the JSON: "아래 `${NOW}` 는 위에서 capture 한 변수로 치환 후 기록" so a reader doesn't serialize the literal `${NOW}` into metadata.json.

Risk if left unfixed: first re-reader (future implementer or even Claude on rerun) types `${NOW}` literally into metadata.json, breaking Task 21 url_verify downstream parsers that do timestamp arithmetic.

---

### [IMPORTANT] I2 — Epoch-diff portability undocumented (BSD vs GNU date)

**Location**: `context/drllm-core.md:87-91`, `skills/drllm-adaptive-tutoring/SKILL.md:145-150`

```bash
START_EPOCH=$(date -d "$(jq -r .started_at metadata.json)" +%s)
```

`date -d "ISO8601"` is a GNU coreutils extension. BSD `date(1)` (macOS default) uses `-j -f "%FT%T%z"`. The repo targets Linux per sp0 plan (42school Born2beroot, Ubuntu/Debian VM), but the drllm-core.md contract is silent on this assumption.

**Consequence**: If a contributor runs smoke tests on macOS (without GNU date / coreutils from brew), the session-close shell block fails silently, `${DURATION}` becomes empty, `[COMPLETE] duration_sec=` is malformed → L3 aggregation regex mismatches → the session is counted as incomplete in M1.

**Recommended fix**: Add a one-line assumption note in §1.2:

> Linux/GNU coreutils 전제 (`date -d` 파싱). macOS 에서 구동 시 `brew install coreutils` 후 `gdate` 로 치환.

Or: use a portable alternative — `python3 -c 'import datetime,sys; print(int(datetime.datetime.fromisoformat(sys.argv[1]).timestamp()))' "$TS"`. Python3 is already a hard dep (Task 21 L3 aggregator).

Severity is Important (not Critical) because the project is declared Linux-target and M1 POC runs on a single VM.

---

### [IMPORTANT] I3 — Duplication between S4 §3.4 and new "Event Recording — MUST DO" section

**Location**: `skills/drllm-adaptive-tutoring/SKILL.md` §3.4 (:103-131) vs new §"Event Recording — MUST DO (v2 Robust)" (:177-201)

Both sections enumerate the same six events (`SUBTOPIC`, `SOURCE`, `P5_CHECK`, `P5_SKIP`, `P5_MISSING`, `COMPLETE`). §3.4 gives implementation mechanics (heredoc, variable capture, skip regex), new section gives a checklist + format example.

**What the implementer says** (implementer.md §"Duplication analysis"):
> "§3.4 retains implementation mechanics. No content was removed from §3.4; the two sections are complementary (checklist vs. implementation detail)."

This is a defensible design, but the reader-experience risk is real: **when the two diverge in a future edit, which is authoritative?** There is no explicit pointer.

**Recommended fix** (choose one):

1. **Add an authority header to the new section**:
   > "### Event Recording — MUST DO (v2 Robust) — Checklist layer
   > **Normative format**: `drllm-core.md` §5.3. **Implementation mechanics**: §3.4 above. This section is a pre-flight checklist only."

2. **Merge the checklist into §3.4** as an opening bullet list, then keep the code examples below. Reduces file by ~25 lines.

Option 1 is lower-risk (preserves Task 20 plan alignment verbatim). The plan (lines 1554-1584) specifies this section as a standalone addition after Protocol, so option 1 respects plan intent.

Severity is Important because this is an explicit concern the user flagged ("does the reader know which is authoritative when they diverge?"). The answer is currently "no, they'd have to read both and infer" — which is the exact ambiguity Task 20 was meant to eliminate.

---

### [MINOR] M1 — §1.2 inline comment shows a specific clock time as example

**Location**: `context/drllm-core.md:66`

```bash
NOW=$(date -Iseconds)   # 예: 2026-04-15T11:40:23+09:00
```

Then `SKILL.md:194`:
```
[SUBTOPIC] Buffer Pool 정의 | 2026-04-14T10:31:00+09:00
```

Both are example/illustration timestamps embedded in the contract. They look identical in shape to real ones. A future LLM reading the contract may cargo-cult the exact literal (B2 was *exactly* this failure mode — LLM latching on to contextually plausible strings).

**Recommended fix** (low priority, ideally bundle with C1 refactor):

Use obviously-fake tokens in examples:
```bash
NOW=$(date -Iseconds)   # 출력 형태 예: YYYY-MM-DDTHH:MM:SS±HH:MM
```

And:
```
[SUBTOPIC] Buffer Pool 정의 | <ISO8601+offset>
```

Keeps the schema pedagogical without providing a literal "plausible target" for LLM imitation. B2 root cause was precisely LLM matching plausible strings — eliminating any plausible literal in the contract removes that gradient.

Severity: Minor, because §6-8 HARD STOP + the surrounding `NOW=$(date ...)` mechanics already redirect the LLM to shell, so in practice the risk is small. But principled defense-in-depth says remove the bait.

---

### [MINOR] M2 — S2 SKILL.md shell block and markdown block are disjoint

**Location**: `skills/drllm-research-execution/SKILL.md:117-129`

```bash
NOW=$(date -Iseconds)
```

...then immediately, an unrelated markdown fence:

```markdown
---
session_id: <session_id>
generated_at: ${NOW}
...
```

The reader must infer that `${NOW}` inside the markdown fence is to be shell-substituted by the preceding bash command. Same ambiguity as I1 item (b), but not numbered-list-broken like §4.

**Recommended fix**: Wrap both in a single bash-heredoc (same pattern as S0):

```bash
NOW=$(date -Iseconds)
cat > ".drllm/sessions/${session_id}/research-results.md" <<EOF
---
session_id: ${session_id}
generated_at: ${NOW}
subqueries_count: ${N}
citations_verified: ${M}/${T}
---
...
EOF
```

Consistency with S0 launcher. But: this reintroduces the C1 issue for research-results.md body (which may contain citation quotes with `$`). So the fix to M2 depends on how C1 is resolved — use `printf` / sed-substitute pattern throughout.

Severity: Minor because the S2 body is *mostly* LLM-assembled markdown (summary, key points) rather than literal user echo, so `$`-injection risk is smaller than S4. But coupling the fixes is cleaner.

---

### [MINOR] M3 — §6-8 wording does not explicitly forbid omission

**Location**: `context/drllm-core.md:255`

> "LLM 이 직접 생성한 timestamp 는 세션 측정 무효화"

This penalizes hallucinated timestamps but doesn't clearly state what happens if the LLM **omits** `started_at` entirely (empty string / null). A reader could interpret "only hallucination is banned; blank is a gray zone."

**Recommended fix**: Add a second sentence:

> "누락 (빈 문자열 / null) 또한 동일하게 무효화. §0-3 No silent drop 과 호환."

Aligns with §0-3 "No silent drop" principle the user flagged. Severity: Minor because §5 strict schema already requires the field, so omission fails upstream — but belt-and-suspenders is cheap.

---

## File-size check

| File | Lines now | Growth factor | Assessment |
|------|-----------|--------------|------------|
| drllm-core.md | 261 | +15% | Healthy for a contract file. Under 300 LOC target. |
| adaptive-tutoring/SKILL.md | 217 | +37% | Largest growth. Still readable single-screen-scroll. The I3 duplication is the main inflation driver — merging per I3 option 2 would trim ~25 lines. |
| launcher/SKILL.md | 104 | +10% | Fine. |
| research-execution/SKILL.md | 183 | +4% | Fine. |

No file is near a threshold where it becomes unmaintainable.

---

## Plan Alignment

Task 20 plan (lines 1547-1592) requires **only** the S4 "Event Recording — MUST DO" section. Expansion to include B2 fix across all four files is **controller-authorized** (per task description) and is the correct scope — fixing B2 in isolation would have created merge-conflict risk with the upcoming Task 21 L3 aggregator.

**Deviation**: Scope expanded beyond plan by ~4× LOC. This is a **justified improvement** because:
1. B2 was filed in the same session as Task 20 kickoff.
2. The timestamp contract needs to be atomic — partial fix (only S4, missing S0) would have been worse than no fix.
3. Implementer explicitly documented the expansion in the report.

No problematic departures. All Task 20 Step 1 requirements are literally present in S4 SKILL.md.

---

## Documentation & Standards

- File-header comments: drllm-core §1.2 has a version tag `(v2.2 B2 fix)` — good traceability.
- Cross-references: §1.2 ↔ §6-8 ↔ skill files all correctly labeled.
- Korean/English language policy (§2) respected: contract prose Korean, shell literals English.
- No new emoji, no unnecessary markdown headings. Clean.

---

## Recommendation Summary

Before merge:
1. **C1 (Critical)**: Replace `<<EOF` heredoc with `printf` pattern (option 2) in drllm-core §1.2 example **and** S4 §3.4. Keep S0/S2 heredocs too, since their content (JSON/frontmatter) is LLM-authored not user-echoed — lower risk there, but same `printf > file` idiom is cleaner.
2. **I1**: Renumber §4 list, drop inert `# NOW, DURATION already captured above` block, clarify the JSON block (prose line or convert to `jq` invocation).

After merge (defer to STEP 5 cleanup):
3. **I2**: Add Linux/GNU-date assumption note OR switch to python3 epoch conversion.
4. **I3**: Add authority header to "Event Recording — MUST DO" section.
5. **M1/M2/M3**: Cleanup pass.

Once C1 + I1 are resolved, this is **APPROVED**. The design direction (shell-acquired timestamps, HARD STOP integration, v2.1 batch compatibility) is correct and well-executed.

---

## Open Questions for Implementer

1. **Did you consider `printf '%q'` at implementation time?** If yes and rejected, what was the rationale? (Asking for C1 — if there's a reason to keep heredoc, I want to understand it before mandating `printf`.)
2. **macOS dev-loop**: Does any current contributor run the smoke on macOS? If strictly Linux-only, I2 is doc-only; if macOS is supported, we need the python3 path.
3. **Is the duplicate `3.` in S4 §4 a merge artifact** (two edits overlapping) or intentional? Want to confirm root cause before renumbering.

---

## Re-Review After C1+I1 Fix

**Commit**: `ced0984` — `fix(sp1): Task 20 C1 + I1 — printf pattern + §4 list cleanup`
**Scope**: 3 files (`context/drllm-core.md` +12/-?, `skills/drllm-adaptive-tutoring/SKILL.md` +?/-? net 39 lines, `docs/superpowers/reports/task-20/fix-c1-i1.md` +174 new) — matches expected scope.

### Verification Results

**C1 (Critical — heredoc → printf '%s')**
- `context/drllm-core.md §1.2` (lines 75–86): `<<EOF` removed, replaced with `{ printf '[SUBTOPIC] %s | %s\n' "$SUBTOPIC_NAME" "$NOW"; printf '[SOURCE] fetch::%s | verified=true\n' "$URL"; printf '[P5_CHECK] Q="%s" | A="%s" | score=%s\n' "$Q" "$A" "$SCORE"; } >> learning-log.md`. Single-redirect batch semantics (§0-8) preserved. Explanatory note added: `%s 는 literal 치환 — shell metachar 재해석 없음`. **VERIFIED**.
- `skills/drllm-adaptive-tutoring/SKILL.md §3.4` (lines 109–116, 120–124, 128–132): Three printf blocks (batch, skip-only, missing-only), all `%s` literal substitution, all `{ ... } >> path` single-redirect. **VERIFIED**.
- **Format string user-content test**: `printf '[P5_CHECK] Q="%s" | A="%s" | score=%s\n' "$Q" "$A" "$SCORE"` with `A='he said "hi"'` produces `A="he said "hi""` — downstream parser ambiguity at the literal `"` boundaries. This is **pre-existing** (the `Q="..."` delimiter is specified verbatim in `drllm-core.md §5.3` event schema, not introduced by this fix). Not a regression. Filed as latent concern for STEP 5 (consider JSON-encode or pipe-escape for Q/A fields when user-content allowed).
- **Remaining unquoted `<<EOF` in S4 §4 step 2** (line 164): `cat >> learning-log.md <<EOF` for the `[COMPLETE]` event still present. Content: `[COMPLETE] total_checks=<N> correct=<C> partial=<P> skip=<S> missing=<M> duration_sec=${DURATION}`. The `<N>/<C>/<P>/<S>/<M>` placeholders are LLM-computed integer aggregates (not user content), and `${DURATION}` is an intended shell expansion — so strict-security risk is low. However, this is **asymmetric with the fix's stated philosophy** ("heredoc replaced with printf pattern") and inconsistent within the same SKILL.md file. Recommend following-up with either (a) migrate to `{ printf '[COMPLETE] total_checks=%s correct=%s ... duration_sec=%s\n' "$N" "$C" "$P" "$S" "$M" "$DURATION"; } >> log` for consistency, or (b) explicitly document why [COMPLETE] stays as heredoc. **Severity: I (Important) — not blocking**.

**I1 (Important — duplicate `3.`, vestigial bash, literal `${NOW}` JSON)**
- `skills/drllm-adaptive-tutoring/SKILL.md §4` (lines 142–180): Numbering now **1 → 2 → 3 → 4** (verified line 152, 161, 169, 178). Duplicate `3.` eliminated. **RESOLVED**.
- Vestigial `# NOW, DURATION already captured above` bash block: **REMOVED** (not present in current file). **RESOLVED**.
- Literal `${NOW}` JSON fence: **REPLACED** with `jq --arg now "$NOW" --argjson dur "$DURATION" '.completed_at = $now | .status = "done" | .duration_sec = $dur' meta.json > /tmp/meta.$$.json && mv /tmp/meta.$$.json meta.json` (lines 171–176). Uses `--arg` for string field (safe JSON-string encode), `--argjson` for integer field (safe JSON-number encode), atomic tmp-move via `/tmp/meta.$$.json`. **VERIFIED SAFE**. **RESOLVED**.

**S0/S2 scope guard**
- `skills/drllm-launcher/SKILL.md` line 66 (`cat > metadata.json <<EOF`): unchanged from commit `67c3c28` (pre-Task-20). Pre-existing heredoc for LLM-authored metadata.json creation — **out of scope** per fix-author's framing and prior reviewer note. Noted for STEP 5 cleanup consideration (metadata.json creation could migrate to `jq -n '{...}'` construction for symmetry).
- `skills/drllm-research-execution/SKILL.md`: no EOF heredoc present. **CLEAN**.

**Test suite** (`./tools/run-tests.sh`):
- L1 Schema: PASS
- L2 Hooks (bats): 5/5 PASS
- L3 Aggregation: SKIP (not yet implemented — pre-existing state)
- Overall: **PASS**.

**Commit scope** (`git show --stat ced0984`):
- `context/drllm-core.md`: +?/- (12 lines touched)
- `docs/superpowers/reports/task-20/fix-c1-i1.md`: +174 (new)
- `skills/drllm-adaptive-tutoring/SKILL.md`: 39 lines touched
- **3 files, matches expected scope** (2 authoritative + 1 report).

### New Issues Introduced by Fix

None introduced. The printf `%s` pattern is strictly safer than the unquoted heredoc it replaced. The jq `--arg`/`--argjson` + atomic tmp-move pattern is strictly safer than the literal `${NOW}` JSON that preceded it.

### Residual Concerns (not blocking)

1. **Asymmetric heredoc usage within S4**: §3.4 uses printf pattern, §4 step 2 still uses `<<EOF` for `[COMPLETE]`. Low practical risk (integer aggregates + intended `${DURATION}` expansion), but inconsistent with fix philosophy. **Recommend: STEP 5 apply printf pattern to §4 step 2 for consistency, or document the exception.**
2. **`Q="%s"` format ambiguity with embedded `"`** (pre-existing): specified in `drllm-core.md §5.3` event schema. Not caused by this fix but surfaced by the review test case. Recommend: STEP 5 consider JSON-encode (`jq -Rn --arg q "$Q" '$q'`) or `|` escape for Q/A fields.
3. **S0 `drllm-launcher/SKILL.md` line 66 `<<EOF`** (pre-existing, out of scope): LLM-authored metadata.json via unquoted heredoc. Low practical risk (fields are LLM-computed), but architectural inconsistency with post-fix S4 jq pattern. Recommend: STEP 5 migrate to `jq -n '{...}'` for symmetry.

### Verdict

**APPROVED WITH CONCERNS** — C1 fully resolved for the specified scope (§1.2 + §3.4). I1 fully resolved (numbering 1-2-3-4, vestigial block gone, jq-safe metadata update). One residual asymmetry (S4 §4 step 2 `<<EOF` still present) is non-blocking because its fields are not user-controlled, but flagged for STEP 5 consistency pass. Tests pass, commit scope correct, no new issues introduced.

The fix is **safe to merge** and Task 20 can proceed to STEP 5 with the residual concerns tracked.
