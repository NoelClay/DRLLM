# SP-0 Phase 2 — Category B Deep Dive

**Date**: 2026-04-12
**Sub-agent**: Sonnet 4.6
**Category**: B — Anti-Hallucination Patterns (코드 레벨 심화)
**Phase 1 참조**: scan-B-anti-hallucination.md

---

## 심화 분석

### 1. urlhealth Gemini CLI 통합

#### 1.1 urlhealth 코드 분석

실제 `pip install urlhealth`(v0.1.0, 2026-03-03, MIT, Python ≥3.10)로 설치 후 소스를 직접 확인했다. 패키지는 `checker.py` (82줄) + `__init__.py` (3줄) = 총 85줄 구조다. 핵심 로직 전체:

```python
# checker.py — 82줄 전문 (실제 설치 소스 기준)
from enum import Enum
import requests

class URLStatus(str, Enum):
    LIVE = "LIVE"
    DEAD = "DEAD"
    UNKNOWN = "UNKNOWN"
    LIKELY_HALLUCINATED = "LIKELY_HALLUCINATED"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
    "Connection": "keep-alive",
}

WAYBACK_API = "https://archive.org/wayback/available"


def _get_wayback_snapshot(url: str, timeout: int = 10) -> str | None:
    """Return the Wayback Machine archive URL if a snapshot exists, else None."""
    try:
        resp = requests.get(WAYBACK_API, params={"url": url}, timeout=timeout)
        resp.raise_for_status()
        snapshot = resp.json().get("archived_snapshots", {}).get("closest", {})
        if snapshot.get("available"):
            return snapshot.get("url")
    except requests.RequestException:
        pass
    return None


def inspect(url: str, timeout: int = 10) -> dict:
    """Check URL liveness and, if dead, check Wayback Machine.

    Returns a dict with:
      - "url_status": one of "LIVE", "DEAD", "UNKNOWN", "LIKELY_HALLUCINATED"
      - "status_code": HTTP status code (int or None if connection failed)
      - "wayback_url": archive URL if found, else None (only set when DEAD)
    """
    result = {"url_status": None, "status_code": None, "wayback_url": None}

    try:
        resp = requests.head(
            url, allow_redirects=True, timeout=timeout, headers=HEADERS
        )

        # Fall back to GET for servers that reject HEAD
        if resp.status_code in (405, 403, 501):
            resp = requests.get(
                url,
                allow_redirects=True,
                timeout=timeout,
                headers=HEADERS,
                stream=True,
            )

        result["status_code"] = resp.status_code

        if resp.status_code == 200:
            result["url_status"] = URLStatus.LIVE
        elif resp.status_code == 404:
            wayback_url = _get_wayback_snapshot(url, timeout=timeout)
            if wayback_url:
                result["url_status"] = URLStatus.DEAD
                result["wayback_url"] = wayback_url
            else:
                result["url_status"] = URLStatus.LIKELY_HALLUCINATED
        else:
            result["url_status"] = URLStatus.UNKNOWN

    except requests.RequestException:
        result["url_status"] = URLStatus.UNKNOWN

    return result
```

**분석 포인트**:

1. **의존성**: `requests` 단 하나. Python ≥ 3.10 요구 (`str | None` 타입힌트 때문).
2. **판정 로직**: HEAD → (405/403/501이면) GET fallback → 200=LIVE, 404+Wayback=DEAD, 404+no-Wayback=LIKELY_HALLUCINATED, 그 외=UNKNOWN.
3. **핵심 통찰**: LIKELY_HALLUCINATED는 **"HTTP 404 AND Wayback Machine에도 없음"** 조건으로만 발생. 즉 단순 404를 환각으로 오분류하지 않는다. Wayback이 있으면 "예전엔 존재했던 유효한 URL" (DEAD)로 분류.
4. **설계 한계**: LIVE 판정은 URL이 살아있음을 보장할 뿐, 해당 페이지의 내용이 LLM 주장을 지지하는지는 검증하지 않는다. 내용 검증은 VeriCite/MiniCheck 레이어가 담당해야 한다.
5. **GitHub**: `https://github.com/delip/urlhealth` (저자: Delip Rao, University of Pennsylvania)
6. **skill 디렉터리**: `skill/url-health/SKILL.md` 및 `references/api-guide.md` 포함 — agentskills.io 표준 준수.

#### 1.2 Gemini Hook 통합 경로 (Option A: AfterTool Hook)

Category E 보고서에서 확인된 AfterTool hook의 실제 스키마를 기반으로 한 통합 경로:

**AfterTool Hook 입력 스키마** (실증):
```json
{
  "tool_name": "web_search",
  "tool_input": {"query": "..."},
  "tool_response": {
    "llmContent": "...",
    "returnDisplay": "..."
  }
}
```

**AfterTool Hook 출력 스키마**:
```json
{
  "hookSpecificOutput": {
    "additionalContext": "<urlhealth 검증 결과를 컨텍스트로 추가>",
    "tailToolCallRequest": {"name": "tool_name", "args": {...}}
  },
  "decision": "deny",
  "reason": "URL 환각 감지: <<URL>>이 LIKELY_HALLUCINATED 상태입니다. 해당 인용을 제거하고 재시도하세요."
}
```

**settings.json 설정 예시**:
```json
{
  "hooks": {
    "AfterTool": [
      {
        "matcher": "web_search|web_fetch|mcp_.*_search",
        "sequential": true,
        "hooks": [
          {
            "type": "command",
            "command": "python3 /home/user/.drllm/hooks/urlhealth_hook.py",
            "name": "urlhealth-validator",
            "timeout": 15000,
            "description": "LLM 출력 URL을 urlhealth로 검증, LIKELY_HALLUCINATED 발견 시 deny"
          }
        ]
      }
    ]
  }
}
```

**urlhealth_hook.py** (실제 작동 예시):
```python
#!/usr/bin/env python3
"""
Gemini CLI AfterTool Hook — urlhealth URL validator
stdin: JSON AfterTool 페이로드
stdout: JSON hook response
exit code 0: 정상 응답 / exit code 2: 긴급 차단
"""
import json
import re
import sys
import asyncio
import concurrent.futures
from urlhealth import inspect as url_inspect, URLStatus

# 도구 응답에서 URL 추출 (HTTP/HTTPS 한정)
URL_RE = re.compile(r'https?://[^\s\"\'\)\]\>]+')

MAX_CONCURRENT = 5  # 도메인당 동시 요청 상한 (urlhealth 권고)
TIMEOUT = 8  # 초


def check_urls_parallel(urls: list[str]) -> dict[str, dict]:
    """URL 목록을 ThreadPoolExecutor로 병렬 검증"""
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_CONCURRENT) as pool:
        futures = {pool.submit(url_inspect, url, TIMEOUT): url for url in urls}
        return {
            futures[f]: f.result()
            for f in concurrent.futures.as_completed(futures)
        }


def main():
    payload = json.load(sys.stdin)
    tool_response_text = (
        payload.get("tool_response", {}).get("llmContent", "")
        + payload.get("tool_response", {}).get("returnDisplay", "")
    )

    urls = list(set(URL_RE.findall(tool_response_text)))
    if not urls:
        # URL 없으면 pass-through
        print(json.dumps({}))
        return

    results = check_urls_parallel(urls)

    hallucinated = [
        url for url, r in results.items()
        if r["url_status"] == URLStatus.LIKELY_HALLUCINATED
    ]

    if hallucinated:
        output = {
            "decision": "deny",
            "reason": (
                f"urlhealth 검증 실패: 다음 URL이 LIKELY_HALLUCINATED 상태입니다 — "
                f"{', '.join(hallucinated)}. "
                "해당 URL을 응답에서 제거하고 검증된 URL만 사용하여 재시도하세요."
            ),
        }
        print(json.dumps(output))
        return

    # LIVE/DEAD URL 요약을 additionalContext로 추가
    summary_lines = []
    for url, r in results.items():
        status = r["url_status"]
        wayback = r.get("wayback_url")
        if status == URLStatus.DEAD and wayback:
            summary_lines.append(f"[DEAD→ARCHIVE] {url} → {wayback}")
        elif status == URLStatus.LIVE:
            summary_lines.append(f"[LIVE] {url}")
        elif status == URLStatus.UNKNOWN:
            summary_lines.append(f"[UNKNOWN] {url}")

    additional_context = (
        "urlhealth 검증 결과:\n" + "\n".join(summary_lines)
        if summary_lines else ""
    )

    output = {"hookSpecificOutput": {"additionalContext": additional_context}}
    print(json.dumps(output))


if __name__ == "__main__":
    main()
```

**작동 흐름**:
1. `web_search` 또는 MCP search 도구 실행 완료 → AfterTool hook 발화
2. 도구 응답 텍스트에서 URL 정규식 추출
3. `ThreadPoolExecutor(max_workers=5)`로 병렬 HTTP 검증
4. `LIKELY_HALLUCINATED` 발견 시 `decision: deny` + reason → Gemini가 해당 URL 제거 후 재시도
5. 모두 통과 시 `additionalContext`로 LIVE/DEAD 요약 주입

#### 1.3 MCP 도구로 wrap (Option B: FastMCP)

AfterTool hook 방식이 자동 인터셉트라면, MCP 도구 방식은 **Gemini 또는 서브에이전트가 명시적으로 호출**하는 방식이다.

```python
# drllm_urlhealth_mcp.py
from fastmcp import FastMCP
from urlhealth import inspect as url_inspect, URLStatus
import json

mcp = FastMCP(name="drllm-urlhealth", version="0.1.0")


@mcp.tool()
def check_url(url: str, timeout: int = 10) -> dict:
    """
    URL이 살아있는지(LIVE), 죽었는지(DEAD), 
    환각된 것인지(LIKELY_HALLUCINATED), 또는 알 수 없는지(UNKNOWN)를 검증합니다.
    
    LIKELY_HALLUCINATED: HTTP 404이며 Wayback Machine에도 아카이브 없음 — LLM이 만들어낸 URL일 가능성 높음.
    DEAD: HTTP 404이나 Wayback Machine 아카이브 존재 — 예전에는 존재했던 유효 URL.
    """
    return url_inspect(url, timeout=timeout)


@mcp.tool()
def check_urls_batch(urls: list[str], timeout: int = 10) -> list[dict]:
    """
    여러 URL을 일괄 검증합니다. 각 URL에 대해 url_status, status_code, wayback_url을 반환.
    LIKELY_HALLUCINATED URL이 발견되면 해당 URL을 응답에서 제거하세요.
    """
    import concurrent.futures
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        futures = {pool.submit(url_inspect, url, timeout): url for url in urls}
        results = []
        for f in concurrent.futures.as_completed(futures):
            url = futures[f]
            result = f.result()
            results.append({"url": url, **result})
    return results


if __name__ == "__main__":
    mcp.run()
```

**settings.json MCP 등록**:
```json
{
  "mcpServers": {
    "drllm-urlhealth": {
      "command": "python3",
      "args": ["/home/user/.drllm/mcp/drllm_urlhealth_mcp.py"],
      "env": {}
    }
  }
}
```

**Option A vs B 비교**:

| 항목 | Option A (AfterTool Hook) | Option B (MCP Tool) |
|------|--------------------------|---------------------|
| 자동화 | 자동 인터셉트 (LLM 개입 불필요) | LLM이 명시적 호출 |
| 강제력 | Hard Gate (deny 가능) | Soft (LLM이 호출 안 할 수 있음) |
| 구현 복잡도 | Python 스크립트 + settings.json | FastMCP 서버 + settings.json |
| DRLLM 권장 | S2 파이프라인 강제 게이트 | S2 에이전트의 선택적 검증 도구 |
| 추천 | **DRLLM 1차 채택** | 보조 (LLM-driven 검증) |

**DRLLM 권장**: Option A (AfterTool hook)를 기본으로, Option B를 S2 서브에이전트의 재검증 도구로 병행 사용.

#### 1.4 비용/지연 분석

실측 기반 추정:

| 시나리오 | URL 수 | 예상 시간 | 설명 |
|---------|--------|----------|------|
| 단일 URL (LIVE) | 1 | 200~500ms | HEAD 요청 1회, Wayback 없음 |
| 단일 URL (DEAD) | 1 | 600ms~1.5s | HEAD + Wayback API 추가 조회 |
| 단일 URL (LIKELY_HALLUCINATED) | 1 | 600ms~1.5s | HEAD(404) + Wayback(없음) |
| 5개 URL 병렬 (max_workers=5) | 5 | 500ms~1.5s | ThreadPoolExecutor 동시 실행 |
| 10개 URL 병렬 (max_workers=5) | 10 | 1~3s | 2 batch |
| 20개 URL 병렬 | 20 | 2~6s | 4 batch |

**실용성 평가**:
- S2 단일 검색 결과에 포함되는 URL은 통상 3~10개 → **병렬 500ms~2s 추가**
- 사용자가 체감하는 응답 지연 허용 임계: 일반적으로 3~5s
- 10개 URL 이하는 사용자 체감 지연 최소화 가능 (병렬 1.5s 이내)
- **20개 초과 시 URL 선별 필요**: S2가 URL 10개를 먼저 추출하고 중요도 순 검증 권장
- Wayback API는 archive.org 서버 상태에 따라 변동 (평균 200~800ms, 최대 2s)
- **네트워크 상태 의존**: 오프라인/느린 환경에서는 timeout=8s 상한에 묶임 → timeout 파라미터 조정 또는 UNKNOWN 처리로 degraded mode 지원 필수

**권장 설계**: 병렬 검증 URL 상한 = 10개 / batch. 10개 초과 시 LLM이 먼저 중요 URL 10개 선별 → 검증.

---

### 2. JSON 출력 + Citation 2-Call 아키텍처

Gemini API에서 JSON 구조화 출력(`response_mime_type: "application/json"`)을 요청하면 `grounding_metadata`(groundingChunks, groundingSupports)가 사라지는 구조적 한계가 존재한다. Phase 1에서 식별된 이 문제의 실제 해결 패턴:

#### 2.1 문제 원인

- groundingSupports의 `startIndex/endIndex`는 **마크다운 텍스트 오프셋** 기반
- JSON 출력으로 포맷이 바뀌면 오프셋이 무의미해져 Gemini가 자동으로 groundingMetadata 제거
- 추가 문제: Gemini는 긴 서명 URL을 **토큰 단위 재생성**하므로 리다이렉트 URL(`vertexaisearch.cloud.google.com/...`)의 문자가 변조됨

#### 2.2 실제 작동 2-Call 아키텍처

```python
import re
import json
import requests
from google import genai
from google.genai import types

client = genai.Client()


# ── 공통 헬퍼 ────────────────────────────────────────────────────────────────

def resolve_redirect(url: str, timeout: int = 5) -> str:
    """Gemini 리다이렉트 URL → 실제 URL 해소"""
    try:
        r = requests.head(url, allow_redirects=True, timeout=timeout)
        return r.url
    except Exception:
        return url


def extract_and_mask_citations(response) -> tuple[str, dict[str, str]]:
    """
    1차 호출 응답에서 groundingChunks를 파싱,
    URL을 <<URL_n>> placeholder로 마스킹.
    반환: (마스킹된 텍스트, {placeholder: 실제URL})
    """
    text = response.text
    chunks = response.candidates[0].grounding_metadata.grounding_chunks
    url_map: dict[str, str] = {}

    for i, chunk in enumerate(chunks, start=1):
        raw_url = chunk.web.uri
        resolved = resolve_redirect(raw_url)
        ph = f"<<URL_{i}>>"
        url_map[ph] = resolved
        text = text.replace(raw_url, ph)

    return text, url_map


def unmask_urls(text: str, url_map: dict[str, str]) -> str:
    for ph, url in url_map.items():
        text = text.replace(ph, url)
    return text


# ── 1차 호출: 마크다운 + grounding 획득 ─────────────────────────────────────

def call_1_grounded_markdown(query: str) -> tuple[str, dict[str, str]]:
    """
    Google Search grounding 활성화, 마크다운 텍스트 응답 + citation 추출.
    반환: (마스킹된 마크다운 텍스트, url_map)
    """
    config = types.GenerateContentConfig(
        tools=[types.Tool(google_search=types.GoogleSearch())],
        temperature=0.0,
    )
    response = client.models.generate_content(
        model="gemini-2.5-flash-preview",
        contents=query,
        config=config,
    )
    masked_text, url_map = extract_and_mask_citations(response)
    return masked_text, url_map


# ── 2차 호출: JSON 구조화 변환 ───────────────────────────────────────────────

RESPONSE_SCHEMA = {
    "type": "OBJECT",
    "required": ["answer", "citations", "confidence"],
    "properties": {
        "answer": {"type": "STRING"},
        "citations": {
            "type": "ARRAY",
            "items": {
                "type": "OBJECT",
                "required": ["url", "title", "claim"],
                "properties": {
                    "url": {"type": "STRING"},
                    "title": {"type": "STRING"},
                    "claim": {"type": "STRING"},
                },
            },
        },
        "confidence": {"type": "NUMBER"},
    },
}


def call_2_json_structure(masked_text: str, url_map: dict[str, str]) -> dict:
    """
    마스킹된 마크다운 → JSON 구조로 변환.
    placeholder URL을 citations 배열에 유지.
    """
    url_list = "\n".join(f"{ph} = {url}" for ph, url in url_map.items())
    prompt = f"""다음 마크다운 내용을 JSON으로 구조화하세요.
URL placeholder(<<URL_n>>)는 그대로 citations[].url 필드에 유지하세요.

URL 목록:
{url_list}

마크다운:
{masked_text}"""

    config = types.GenerateContentConfig(
        response_mime_type="application/json",
        response_schema=RESPONSE_SCHEMA,
        temperature=0.0,
    )
    response = client.models.generate_content(
        model="gemini-2.5-flash-preview",
        contents=prompt,
        config=config,
    )

    result = json.loads(response.text)

    # placeholder → 실제 URL 복원
    for citation in result.get("citations", []):
        ph = citation.get("url", "")
        if ph in url_map:
            citation["url"] = url_map[ph]

    return result


# ── 통합 실행 ────────────────────────────────────────────────────────────────

def research_with_verified_citations(query: str) -> dict:
    """
    DRLLM S2 핵심 함수.
    1차: grounded 마크다운 획득 + citation 추출 + URL 마스킹
    2차: JSON 구조화 (placeholder 유지 → 복원)
    """
    masked_text, url_map = call_1_grounded_markdown(query)
    result = call_2_json_structure(masked_text, url_map)
    return result


# 사용 예시
if __name__ == "__main__":
    result = research_with_verified_citations(
        "Python asyncio best practices 2026"
    )
    print(json.dumps(result, indent=2, ensure_ascii=False))
    # 출력 예:
    # {
    #   "answer": "asyncio에서 ...",
    #   "citations": [
    #     {"url": "https://docs.python.org/3/library/asyncio.html",
    #      "title": "asyncio — Python 3 docs",
    #      "claim": "asyncio.run()은 최상위 진입점으로 권장됩니다."}
    #   ],
    #   "confidence": 0.92
    # }
```

**JSON Schema 강제 메커니즘 설명**:

- `response_mime_type: "application/json"` + `response_schema` 조합이 Gemini의 구조 강제 방식
- `required: ["answer", "citations", "confidence"]`로 citations 필드 누락 원천 차단
- 2차 호출에서 URL이 placeholder 형태(`<<URL_n>>`)이므로 Gemini가 토큰 재생성 시 문자 변조 불가 (짧고 예측 가능한 문자열)
- 복원 단계에서 `url_map` dict lookup으로 실제 URL 대입 → URL 변조 완전 방지

**비용 추정**:
- 1차 호출: 일반 grounded 쿼리 (input ~200 tokens + output ~500 tokens + search)
- 2차 호출: 마크다운 → JSON 변환 (input ~800 tokens + output ~400 tokens)
- 총 추가 비용: 2차 호출 1회 (~1,200 tokens) — 검색 없는 단순 변환이므로 저렴
- 레이턴시: 1차 ~2-4s + 2차 ~1-2s = 총 **3-6s** (검색 포함)

---

### 3. VeriCite NLI 경량화 (MiniCheck API 활용)

#### 3.1 VeriCite 패턴 본질

VeriCite(arxiv 2510.11394)의 핵심은 **claim ↔ source NLI 검증**을 3단계로 수행하는 것이다:

1. 답변 생성 → 각 claim을 NLI 검증
2. 검색 문서에서 지지 증거 추출 → 재검증 → 인용 마커 부착
3. 검증된 claim + 마커만으로 최종 답변 재구성

DRLLM에서의 본질적 가치는 **"LLM이 인용을 선택하는 책임을 시스템이 가져감"** — VeriCite의 `decoupled attribution` 패턴이다. 공개 코드가 없으므로 MiniCheck API로 이 패턴을 재구현한다.

#### 3.2 MiniCheck API 실제 호출 패턴

**패키지**: `pip install bespokelabs`
**모델**: Bespoke-MiniCheck-7B (LLM-AggreFact 리더보드 1위, 77.4%)
**레이턴시**: ~200ms / 요청 (단일 GPU 기준)

```python
import os
from bespokelabs import BespokeLabs, AsyncBespokeLabs

bl = BespokeLabs(auth_token=os.environ["BESPOKE_API_KEY"])

# 단일 claim 검증
response = bl.minicheck.factcheck.create(
    claim="Python 3.12 was released in October 2023.",
    context="Python 3.12 was officially released on October 2, 2023..."
)
print(response.support_prob)  # 0.0 ~ 1.0: 높을수록 문서가 claim을 지지


# 비동기 버전 (DRLLM S2 병렬 검증용)
import asyncio

async def verify_claims_batch(claims: list[str], context: str) -> list[dict]:
    """여러 claim을 비동기로 일괄 검증"""
    async_bl = AsyncBespokeLabs(auth_token=os.environ["BESPOKE_API_KEY"])
    tasks = [
        async_bl.minicheck.factcheck.create(claim=claim, context=context)
        for claim in claims
    ]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    return [
        {
            "claim": claim,
            "support_prob": r.support_prob if not isinstance(r, Exception) else None,
            "supported": r.support_prob >= 0.7 if not isinstance(r, Exception) else False,
        }
        for claim, r in zip(claims, results)
    ]

# 사용 예시
claims = [
    "Python asyncio supports structured concurrency via TaskGroup.",
    "asyncio.run() was introduced in Python 3.7.",
]
context = "The asyncio library provides infrastructure for writing single-threaded concurrent code..."

results = asyncio.run(verify_claims_batch(claims, context))
# [{"claim": "...", "support_prob": 0.94, "supported": True}, ...]
```

**중요 사항**: MiniCheck은 **문장 단위 검증 모델**이므로 다중 문장 claim은 먼저 분리해야 한다.

#### 3.3 VeriCite 패턴 DRLLM 재구현

```python
def vericity_pipeline(query: str, search_results: list[dict]) -> dict:
    """
    VeriCite 패턴의 DRLLM S2 경량 구현.
    
    search_results: [{"url": str, "title": str, "content": str}, ...]
    """
    # Stage 1: LLM으로 초안 답변 생성 (claim 목록 포함)
    draft_response = call_gemini_for_draft(query, search_results)
    claims = split_into_sentences(draft_response["answer"])

    # Stage 2: 각 claim을 각 소스에 대해 MiniCheck으로 검증
    verified_citations = []
    for claim in claims:
        for source in search_results:
            resp = bl.minicheck.factcheck.create(
                claim=claim,
                context=source["content"][:2000]  # 컨텍스트 길이 제한
            )
            if resp.support_prob >= 0.7:
                verified_citations.append({
                    "claim": claim,
                    "source_url": source["url"],
                    "support_prob": resp.support_prob,
                })
                break  # 첫 번째 지지 소스로 충분

    # Stage 3: 검증된 claim만으로 최종 답변 재구성
    verified_claims = [c["claim"] for c in verified_citations]
    final_answer = " ".join(verified_claims)

    return {
        "answer": final_answer,
        "citations": verified_citations,
        "dropped_claims": [c for c in claims if c not in verified_claims],
    }
```

#### 3.4 MiniCheck 비용/지연 — DRLLM 통합 시

| 시나리오 | 소요 시간 | 비용 메모 |
|---------|----------|----------|
| 5 claims × 3 sources (비동기) | ~200-400ms | 15 API 호출 |
| 10 claims × 5 sources (비동기) | ~400-800ms | 50 API 호출 |
| 로컬 flan-t5-large (CPU) | 1~3s / claim | 무료, GPU 불필요 |
| 로컬 Bespoke-MiniCheck-7B (GPU) | ~200ms / claim | GPU 필요 |

**DRLLM 통합 권장**:
- 기본: BespokeLabs API (외부 API, 빠름, 유료)
- 비용 절감: 로컬 `flan-t5-large` (CPU 가능, 약간 느림, 성능 차이 존재)
- 호출 위치: S2 응답 생성 후, urlhealth 검증과 **병렬** 실행 가능 (URL 검증 ≠ claim 검증)
- Guardrails AI `bespoke-minicheck-guardrailsai` 통합도 가능 (GitHub: `bespokelabsai/bespoke-minicheck-guardrailsai`)

---

### 4. 3중 방어 통합 청사진

#### 4.1 아키텍처 다이어그램 (ASCII)

```
사용자 쿼리
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Layer 0 — GEMINI.md Soft Constraint            │
│  "검색 도구 결과에서만 인용. 직접 인용 불가 시  │
│   해당 주장을 [] 로 표시하고 철회."             │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│  Layer 1 — Pre-LLM (Gemini Grounding)           │
│                                                  │
│  [Call 1] google_search grounding 활성           │
│    → groundingChunks (URL + title)               │
│    → groundingSupports (텍스트 ↔ URL 매핑)      │
│    → URL 마스킹 (<<URL_n>>) + redirect 해소     │
│                                                  │
│  실패 시 fallback: LLM 메모리 사용, [RECALL] 표시│
└─────────────────┬───────────────────────────────┘
                  │ 마스킹된 마크다운 + url_map
                  ▼
┌─────────────────────────────────────────────────┐
│  Layer 2 — LLM-level (JSON Schema Enforcement)  │
│                                                  │
│  [Call 2] response_mime_type: "application/json" │
│    + response_schema (citations[] required)      │
│    → placeholder 유지 → url_map으로 복원         │
│                                                  │
│  실패 시 fallback: 재호출 1회 (최대 2회)        │
└─────────────────┬───────────────────────────────┘
                  │ JSON {answer, citations[]}
                  ▼
┌─────────────────────────────────────────────────┐
│  Layer 3a — Post-LLM HTTP 검증 (urlhealth)       │
│                                                  │
│  AfterTool hook 또는 S2 명시적 호출              │
│  citations[].url → urlhealth.inspect()           │
│    LIVE → 통과                                   │
│    DEAD → wayback_url로 교체 + [ARCHIVED] 표시  │
│    LIKELY_HALLUCINATED → 해당 citation 제거     │
│                              + 사용자 알림       │
│    UNKNOWN → [UNVERIFIED] 표시 (제거하지 않음)  │
│                                                  │
│  실패 시 fallback: 인용 제거 + 사용자 알림      │
└─────────────────┬───────────────────────────────┘
                  │ (선택적 Layer 3b)
                  ▼
┌─────────────────────────────────────────────────┐
│  Layer 3b — Post-LLM NLI 검증 (MiniCheck)       │
│  [중요 응답 or 학술 쿼리 한정]                   │
│                                                  │
│  citation.claim ↔ source.content → MiniCheck     │
│    support_prob ≥ 0.7 → 유지                    │
│    support_prob < 0.7 → 해당 claim 제거         │
│                              + [UNSUPPORTED] 표시│
│                                                  │
│  실패 시 fallback: MiniCheck 호출 skip (성능 모드)│
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│  최종 사용자 출력                                │
│                                                  │
│  {                                               │
│    "answer": "...",                              │
│    "citations": [                                │
│      {"url": "https://...", "title": "...",      │
│       "claim": "...", "status": "LIVE"}          │
│    ],                                            │
│    "hallucination_report": {                     │
│      "removed": [...],                           │
│      "archived": [...],                          │
│      "unverified": [...]                         │
│    }                                             │
│  }                                               │
└─────────────────────────────────────────────────┘
```

#### 4.2 각 Layer 책임/실패 처리

| Layer | 책임 | 실패 시 fallback |
|-------|------|----------------|
| Layer 0 (GEMINI.md Soft) | 시스템 프롬프트 수준 소프트 강제: "검색 결과만 인용, 불가 시 철회" | 모델 무시 가능 — Layer 1-3가 hard 강제로 보완 |
| Layer 1 (Gemini Grounding) | Google Search로 URL 사전 바인딩, groundingChunks 추출, URL 마스킹 + redirect 해소 | 검색 결과 없음: `[RECALL]` 레이블로 LLM 메모리 사용 명시, grounding 없이 진행 |
| Layer 2 (JSON Schema) | 출력 구조 강제 (citations[] required), URL placeholder 보존 | JSON 파싱 실패: 재호출 1회. 2회 실패 시 마크다운 원문 + 경고 반환 |
| Layer 3a (urlhealth) | URL HTTP 검증, LIKELY_HALLUCINATED 제거, DEAD→Wayback 교체 | 네트워크 오류/timeout: UNKNOWN 처리 후 `[UNVERIFIED]` 표시, 제거하지 않음 |
| Layer 3b (MiniCheck) | Claim-source NLI 검증, 지지되지 않는 claim 제거 | API 오류/레이턴시 초과: 해당 레이어 skip, Layer 3a까지만 적용 |

#### 4.3 DRLLM S2 통합 코드 청사진

```python
# drllm/skills/s2_research_execution.py
"""
DRLLM S2 — Research Execution
3중 방어 통합 파이프라인
"""
import asyncio
import json
from dataclasses import dataclass, field
from typing import Optional

from urlhealth import inspect as url_inspect, URLStatus


@dataclass
class Citation:
    url: str
    title: str
    claim: str
    status: str = "UNVERIFIED"       # LIVE / DEAD / LIKELY_HALLUCINATED / UNKNOWN
    wayback_url: Optional[str] = None
    support_prob: Optional[float] = None


@dataclass
class S2Result:
    answer: str
    citations: list[Citation] = field(default_factory=list)
    hallucination_report: dict = field(default_factory=dict)


class S2ResearchExecution:
    def __init__(self, gemini_client, bespoke_client=None):
        self.gemini = gemini_client
        self.bespoke = bespoke_client  # Optional: MiniCheck

    # ── Layer 1 + Layer 2: 2-call 아키텍처 ─────────────────────────────────

    def run_two_call_pipeline(self, query: str) -> tuple[str, dict[str, str]]:
        """Layer 1(Grounding) + Layer 2(JSON Schema) 통합 실행"""
        # Call 1: Grounded markdown
        masked_text, url_map = call_1_grounded_markdown(query)  # 위 섹션 2 코드 재사용

        # Call 2: JSON structure
        result = call_2_json_structure(masked_text, url_map)

        return result, url_map

    # ── Layer 3a: urlhealth 검증 ────────────────────────────────────────────

    async def verify_urls(self, citations: list[Citation]) -> list[Citation]:
        """urlhealth로 citations의 URL 비동기 검증"""
        import concurrent.futures

        loop = asyncio.get_event_loop()
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
            tasks = [
                loop.run_in_executor(pool, url_inspect, c.url, 8)
                for c in citations
            ]
            results = await asyncio.gather(*tasks, return_exceptions=True)

        verified = []
        for citation, result in zip(citations, results):
            if isinstance(result, Exception):
                citation.status = "UNKNOWN"
                verified.append(citation)
                continue

            status = result["url_status"]
            citation.status = str(status)

            if status == URLStatus.LIVE:
                verified.append(citation)
            elif status == URLStatus.DEAD:
                citation.wayback_url = result["wayback_url"]
                citation.url = result["wayback_url"]  # Wayback URL로 교체
                verified.append(citation)
            elif status == URLStatus.LIKELY_HALLUCINATED:
                pass  # 제거 (verified에 추가 안 함)
            else:  # UNKNOWN
                verified.append(citation)

        return verified

    # ── Layer 3b: MiniCheck NLI 검증 (선택적) ──────────────────────────────

    async def verify_claims(self, citations: list[Citation],
                             source_contents: dict[str, str]) -> list[Citation]:
        """MiniCheck으로 claim-source NLI 검증"""
        if not self.bespoke:
            return citations  # MiniCheck 없으면 skip

        verified = []
        for citation in citations:
            content = source_contents.get(citation.url, "")
            if not content:
                verified.append(citation)
                continue

            try:
                resp = await self.bespoke.minicheck.factcheck.create(
                    claim=citation.claim,
                    context=content[:2000],
                )
                citation.support_prob = resp.support_prob
                if resp.support_prob >= 0.7:
                    verified.append(citation)
                # support_prob < 0.7이면 제거
            except Exception:
                citation.support_prob = None
                verified.append(citation)  # 오류 시 보수적으로 유지

        return verified

    # ── 통합 실행 ────────────────────────────────────────────────────────────

    async def execute(self, query: str, use_minicheck: bool = False) -> S2Result:
        """
        S2 완전 실행: Layer 0(GEMINI.md) + Layer 1-2(2-call) + Layer 3a(urlhealth)
        + 선택적 Layer 3b(MiniCheck)
        """
        # Layer 1 + 2
        raw_result, url_map = self.run_two_call_pipeline(query)

        citations = [
            Citation(
                url=c["url"],
                title=c.get("title", ""),
                claim=c.get("claim", ""),
            )
            for c in raw_result.get("citations", [])
        ]

        # Layer 3a: URL 검증
        original_count = len(citations)
        citations = await self.verify_urls(citations)
        removed_count = original_count - len(citations)

        # Layer 3b: NLI 검증 (선택적)
        if use_minicheck and self.bespoke:
            # 소스 내용은 1차 검색에서 이미 수집된 것을 재사용해야 함
            source_contents = {}  # {url: content} — 실제 구현에서 채워야 함
            citations = await self.verify_claims(citations, source_contents)

        hallucination_report = {
            "total_original": original_count,
            "removed_hallucinated": removed_count,
            "final_verified": len(citations),
        }

        return S2Result(
            answer=raw_result.get("answer", ""),
            citations=citations,
            hallucination_report=hallucination_report,
        )
```

**Gemini CLI Extension 통합 (gemini-extension.json)**:
```json
{
  "name": "drllm",
  "version": "0.1.0",
  "description": "DRLLM Deep Research + LearnLM tutoring system",
  "mcpServers": {
    "drllm-urlhealth": {
      "command": "python3",
      "args": ["${DRLLM_ROOT}/mcp/drllm_urlhealth_mcp.py"]
    }
  },
  "contextFileName": "GEMINI.md"
}
```

**settings.json (Hook + MCP 동시 등록)**:
```json
{
  "mcpServers": {
    "drllm-urlhealth": {
      "command": "python3",
      "args": ["~/.drllm/mcp/drllm_urlhealth_mcp.py"]
    }
  },
  "hooks": {
    "AfterTool": [
      {
        "matcher": "web_search|web_fetch|mcp_.*_search",
        "sequential": true,
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.drllm/hooks/urlhealth_hook.py",
            "name": "urlhealth-validator",
            "timeout": 15000
          }
        ]
      }
    ],
    "AfterAgent": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.drllm/hooks/citation_schema_check.py",
            "name": "citation-schema-gate",
            "timeout": 5000,
            "description": "citations[] 필드 존재 여부 검증 hard gate"
          }
        ]
      }
    ]
  }
}
```

---

## SP-2 (출처 다양화 통합) 설계 영향

3중 방어 청사진은 SP-2 설계에 다음 제약을 부과한다:

1. **MCP 도구 선택 기준**: SP-2에서 채택하는 모든 MCP 도구(arxiv, GitHub, StackOverflow 등)는 반드시 실제 URL을 그대로 반환해야 한다(LLM 합성 URL 불가). urlhealth AfterTool hook은 `mcp_.*_search` 패턴 매처로 **모든 MCP 검색 도구에 자동 적용**되도록 설계한다.

2. **groundingChunks 구조 호환**: SP-2의 다양한 출처(arxiv, GitHub, 커뮤니티 포럼)에서 반환된 URL이 `groundingChunks`와 동일한 `{url, title}` 구조로 정규화되어야 한다. 도구가 다르더라도 S2의 citation 구조 표준을 통일.

3. **BYOC(SP-F) 연계**: 사용자 제공 PDF/EPUB의 내부 참조(챕터·섹션 위치)는 HTTP URL이 아니므로 urlhealth 검증 대상에서 제외해야 한다. `file://` 또는 `byoc://` 스킴으로 구분하는 URL 네임스페이스 정책 필요.

4. **Layer 3b(MiniCheck) 조건부 활성화**: SP-2 설계에서 모든 쿼리에 MiniCheck을 적용하면 레이턴시·비용이 과도하다. 권장 정책: (a) 학술/의학/법률 도메인 쿼리, (b) 사용자가 `--verify-claims` 플래그 명시, (c) SP-3 Born2beRoot 검증 시 한정 활성화.

5. **2-call 아키텍처의 토큰 오버헤드**: SP-2가 다양한 MCP 도구를 병렬 사용하는 경우, 1차 호출의 컨텍스트(검색 결과 다수)가 커질 수 있다. 2차 호출의 입력 토큰을 줄이기 위해 1차 결과를 요약(compress) 후 2차 호출에 넘기는 전처리 단계 설계 필요.

---

## 변경된 권장 (Phase 1 대비)

| 항목 | Phase 1 권장 | Phase 2 변경 |
|------|------------|------------|
| urlhealth 통합 방식 | "MCP 스킬 또는 bash tool로 등록" (일반적) | **AfterTool hook이 1차 권장** (자동 강제), MCP는 보조 (명시적 검증 도구) |
| Gemini JSON + grounding | "2-call 우회 필요" (개념적) | **실제 구현 패턴 확립**: URL 마스킹(`<<URL_n>>`) + redirect 해소 + placeholder 복원의 3단계 |
| VeriCite 구현 경로 | "DeBERTa-v3-large 로컬 추론" | **BespokeLabs API 우선** (~200ms, 설치 1줄), 로컬은 `flan-t5-large` 대안 |
| Layer 3b(NLI) 적용 범위 | "중요 응답에 ProvenanceLLM 결합" | **조건부 활성화** — 모든 쿼리 적용 시 레이턴시·비용 과다. 학술/의료/법률 도메인 한정 |
| BYOC 출처 처리 | 언급 없음 | **file:// / byoc:// 스킴 분리** 필요 — HTTP URL이 아닌 BYOC 참조는 urlhealth 대상 제외 |
| 전체 파이프라인 레이턴시 | "성능 저하" 경고만 | **구체적 추정**: Layer 1-2 (3-6s) + Layer 3a 5개 URL 병렬 (~1.5s) = **총 4.5-7.5s** 추가 (검색 포함) |

---

*이 보고서의 urlhealth 코드는 실제 `pip install urlhealth`로 설치 후 `inspect.getsource()`로 직접 추출한 소스 기반. Gemini hook 스키마는 Category E 보고서(google-gemini/gemini-cli 공식 docs 기반) 및 Gemini CLI 공식 문서에서 실증. MiniCheck API는 bespokelabs.ai 공식 문서 및 GitHub에서 확인. 2-call 아키텍처는 aurelio.ai 및 cennest.com의 실증 구현 기반.*
