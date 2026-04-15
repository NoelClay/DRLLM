# B3 — S2 uses GoogleSearch beyond plan scope (fetch-only)

**Severity**: Minor (v0.1) / Important (v0.5)
**Status**: open
**Scheduled**: SP-2 (tool allowlist policy via `BeforeToolSelection` hook)
**Filed**: 2026-04-15 (STEP 4 smoke, M1 2차 InnoDB 세션)

## Observed

Session: `20260415-innodb-buffer-pool-default-size`, S2 활성 turn 중 tool 호출 로그:

```
✓ fetch (fetch MCP Server) — URL 1
✓ fetch (fetch MCP Server) — URL 2
✓ GoogleSearch — "MySQL innodb_buffer_pool_size default 128MiB history reason"
✓ GoogleSearch — "MySQL 5.5 innodb_buffer_pool_size default 128MB change reason"
✓ fetch (fetch MCP Server) — URL 1 start_index=5000
✓ GoogleSearch — site:dev.mysql.com "..." "134217728 bytes"
```

S2 SKILL.md Protocol §3 및 SP-0 final report §1 규정:
- v0.1 MCP: **fetch 1개만** (github/paper-search 는 v0.5)
- 환각 방어 Layer 2: JSON schema 2-call + fetch MCP citation
- GoogleSearch 는 SP-0 에서 기각되지 않았지만 v0.1 **명시 채택 대상 아님**

S2 가 plan scope 를 넘어 GoogleSearch 를 자유롭게 호출했다. 결과 자체는 유용했으나 (대략 맥락 확인), 다음 문제를 야기:
- 출처 라벨이 `fetch::<url>` 만 허용인데 Google 결과는 어떻게 citation 으로 기록? (이번엔 table 에 Google 결과는 안 들어가서 운 좋게 ghost citation 없음)
- 환각 방어 Layer 2 가 fetch 응답 substring match 기반인데, GoogleSearch 결과는 이 검증 대상 밖 → 향후 GoogleSearch 결과가 citations 에 침투하면 ghost URL 경로 생김

## Root Cause Hypothesis

1. Gemini CLI 기본 built-in tools (GoogleSearch, ReadFile, Shell) 이 항상 활성 — DRLLM Extension 이 제한 메커니즘 부재.
2. SKILL.md Protocol 은 "fetch 를 쓰라" 만 강제하고 "GoogleSearch 를 쓰지 말라" 를 명시 안 함.
3. LLM 이 부족한 정보 (MySQL 5.5 변경 이유) 를 보완하려 자발적으로 GoogleSearch 호출.

## Fix Plan

### v0.1 (즉시, Minor)

S2 SKILL.md §3 에 명시 금지 추가:
> 본 v0.1 에서는 **`fetch` MCP 만 허용**. `GoogleSearch`, `WebFetch`, 기타 검색 도구 호출 금지. 필요 URL 을 알 수 없으면 domain profile (`context/domains/<domain>.md`) 의 version-pinned URL 을 base 로 사용하거나, Citations 에 `verified=false` 처리하여 skip.

`drllm-core.md` §6 HARD STOP 에 추가:
> 9. S2 는 `fetch` MCP 외의 검색/fetch 도구 호출 금지. `GoogleSearch`/`WebFetch`/`search`/외부 MCP 검색 도구가 S2 turn 안에서 호출되면 해당 citation 은 `verified=false` 강제 + aggregate 에서 `[EXTERNAL_TOOL_LEAK]` 이벤트 기록.

### v0.5 (SP-2, Important)

`.gemini/settings.json` 의 `BeforeToolSelection` hook 으로 S2 활성 상태일 때 `allowedTools` 를 `["fetch", "Shell", "SaveMemory", "ReadFile"]` 로 제한. GoogleSearch/WebFetch 는 tool memory 에서 삭제 (SP-0 §2.4 Policy Engine 패턴).

## Verification

v0.1 fix 후:
- 새 smoke 에서 S2 turn tool 로그에 `GoogleSearch` 없음
- 만약 실수로 호출되면 aggregate 에 `[EXTERNAL_TOOL_LEAK]` 기록
- M1 POC 3 시나리오 모두 fetch-only 로 완주

v0.5:
- `/tools` 로 S2 활성 시 GoogleSearch 가 tool memory 에서 사라짐 확인
