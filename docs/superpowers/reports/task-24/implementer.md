# Task 24 Implementer Report

**Date**: 2026-04-14
**Branch**: feat/sp1-tiny-drllm
**Plan ref**: docs/superpowers/plans/2026-04-14-sp1-tiny-drllm-implementation.md lines 1991-2080

## Scope A — smoke-step5.md

Created `tests/manual/smoke-step5.md`.

**Adaptations vs plan literal:**

1. Setup changed from `gemini extensions link .` to `gemini extensions uninstall DRLLM 2>/dev/null; gemini extensions link .` (smoke-step3/4 precedent, avoids re-link conflict).
2. aggregate expected output updated to 3-invalid-counter format from Task 22 Scope B:
   - `[P5_MISSING]: 0`
   - `[INVALID_CITATION_COUNT]: 0`
   - `[INVALID_TIMESTAMP]: 0`
3. Added B1/B2/B3 verification sections (B3 noted as preventive-only, no aggregate detection in v0.1).

## Scope B — B3 v0.1 preventive fix

### B3.1 — drllm-core.md §6 HARD STOP-10

Added after existing item 9:

```
10. S2 는 `fetch` MCP 외의 검색/fetch 도구 호출 금지 (v0.1). `GoogleSearch`/`WebFetch`/`search_web` 등 built-in 검색 도구 또는 외부 MCP 검색 도구가 S2 turn 안에서 호출되면: (a) 해당 결과는 citation 으로 기록 금지, (b) aggregate 에서 `[EXTERNAL_TOOL_LEAK] session=<id> tool=<name>` 이벤트 기록 후 세션 측정 무효화. v0.5 SP-2 에서 BeforeToolSelection hook 으로 tool memory 차단 예정.
```

Note: aggregate-metrics.sh already contains a comment `# B3 EXTERNAL_TOOL_LEAK: preventive in Task 24 — no aggregate detection here.` — this was pre-populated in Task 22 and correctly reflects the v0.1 preventive-only stance.

### B3.2 — skills/drllm-research-execution/SKILL.md §3.1 (new subsection)

Inserted `### 3.1 도구 제한 (v0.1 B3 fix, §6-10 참조)` after the existing §3 bullet list. Content: explicit prohibition of GoogleSearch/WebFetch/external-MCP tools, domain profile URL fallback guidance, content_truncated start_index retry clarification.

### B3.3 — Bug tracker updates

- `docs/superpowers/bugs/B3-s2-googlesearch-drift.md`: `open` → `in_progress`
- `docs/superpowers/bugs/README.md` index row B3: `open` → `in_progress`

## File diffs summary

| File | Change |
|------|--------|
| `context/drllm-core.md` | Added HARD STOP-10 after item 9 |
| `skills/drllm-research-execution/SKILL.md` | Added §3.1 fetch-only prohibition subsection |
| `tests/manual/smoke-step5.md` | Created (new) |
| `docs/superpowers/bugs/B3-s2-googlesearch-drift.md` | Status open → in_progress |
| `docs/superpowers/bugs/README.md` | Index row B3 open → in_progress |

## run-tests.sh output

```
=== L1 Schema ===
L1 schema: PASS
=== L2 Hooks (bats) ===
1..5
ok 1 S0 완료 → S2 체인
ok 2 S2 완료 → S4 체인
ok 3 stop_hook_active=true → 조용히 통과
ok 4 관련 없는 tool → 조용히 통과
ok 5 save_memory지만 drllm marker 아님 → pass-through
=== L3 Aggregation ===
L3 aggregation: PASS

Automated tests: PASS
Manual smoke: see tests/manual/smoke-step*.md
```

## Self-review checklist

- [x] Plan literal followed except 2 documented adaptations (uninstall-before-link + 3-counter format)
- [x] drllm-core §6-10 numbered correctly (not 9 or 11)
- [x] S2 §3.1 inserted after §3 bullets, does not conflict with existing §3 content
- [x] B3 status updated in both bug file and README
- [x] All tests L1+L2+L3 PASS
