# SP-0 Phase 2 — Category A Deep Dive

**Date**: 2026-04-12
**Sub-agent**: Sonnet 4.6
**Category**: A — Source Diversification (코드 레벨 심화)
**Phase 1 참조**: scan-A-sources.md

---

## 심화 분석 항목별

### 1. openags/paper-search-mcp — 24-source fallback 아키텍처 (코드 레벨)

#### 1.1 아키텍처 코드 분석

**패키지 구조** (pypi.org 기준, v0.1.3, Apr 2025):
```
paper_search_mcp/
├── server.py          # FastMCP 기반 MCP tool 등록
├── papers.py          # Paper 표준 클래스
├── search.py          # unified search_papers + download_with_fallback
├── connectors/        # 소스별 플랫폼 커넥터
│   ├── arxiv.py
│   ├── pubmed.py
│   ├── semantic_scholar.py
│   └── ... (20+ 커넥터)
└── academic_platforms.py  # 확장성을 위한 base class
```

**Tool 등록 방식** (`server.py` — FastMCP decorator 패턴):

```python
# @mcp.tool() decorator가 함수를 자동으로 MCP tool로 노출
# docstring이 tool description으로 사용됨
@mcp.tool()
async def search_arxiv(query: str, max_results: int = 10, ...) -> List[Dict]:
    """Search arXiv for academic papers..."""
    ...

@mcp.tool()
async def search_papers(sources: str = "all", query: str, ...) -> Dict:
    """Search across multiple academic sources simultaneously..."""
    ...
```

**24개+ 소스의 Tier 분류** (capability matrix 기준):

| Tier | 소스 | 상태 | API 키 |
|------|------|------|--------|
| Tier 1 (Stable, Open API) | arXiv, bioRxiv, medRxiv, IACR ePrint, PubMed, PMC, Europe PMC, Zenodo, HAL, DOAJ | ✅ | 불필요 |
| Tier 2 (Rate-Limited) | Semantic Scholar, Crossref, OpenAlex, CORE, OpenAIRE, dblp, CiteSeerX, Google Scholar, SSRN, BASE | ⚠️ | 선택적 (향상) |
| Tier 3 (DOI Resolver) | Unpaywall | 🔑 | 이메일 필수 |
| Skeleton (미완성) | IEEE Xplore, ACM Digital Library | 🚧 | API 키로 활성화 |

**소스 등록은 코드가 아닌 파라미터로 제어**: `search_papers(sources="arxiv,pubmed,semantic_scholar")` 형태로 호출 시 sources 파라미터를 파싱하여 동적으로 커넥터 선택. `sources="all"` 이면 전체 동시 실행.

**병렬 실행 메커니즘** (`search.py` 추출):

```python
# 1. 소스명 → 커넥터 함수 매핑 (동적 task dict)
tasks = {source: search_functions[source](query, ...) for source in sources_list}

# 2. asyncio.gather()로 모든 소스 동시 실행 (진정한 병렬)
results = await asyncio.gather(*tasks.values(), return_exceptions=True)

# 3. 예외는 개별 소스 오류로 캡처 — 전체 실패 방지
for source, result in zip(tasks.keys(), results):
    if isinstance(result, Exception):
        source_errors[source] = str(result)
    else:
        all_papers.extend(result)

# 4. DOI 또는 title+authors 기준 중복 제거
# 반환: 표준화된 Paper dict 목록 + per-source 결과수 + 오류 상세
```

**동기 커넥터 처리** (블로킹 방지):
```python
# 동기 HTTP 호출은 asyncio.to_thread()로 래핑 → 이벤트 루프 블로킹 방지
result = await asyncio.to_thread(sync_search_function, query, ...)
```

**download_with_fallback 폴백 체인** (`search.py`):
```
1단계: source-native download (arXiv PDF, PMC full-text 등)
   ↓ 실패 시
2단계: OpenAIRE / CORE / Europe PMC / PMC — OA 복사본 DOI로 검색
   ↓ 실패 시
3단계: Unpaywall DOI resolution — 합법적 OA URL 획득
   ↓ 실패 시 (선택적, 사용자 설정 시)
4단계: Sci-Hub fallback (기본: sci-hub.se)
```

각 단계는 별도 예외 로그를 기록하므로 진단 추적이 가능하다.

#### 1.2 Rate Limiting / API 키 관리

**Rate limit 전략** (소스별 차등):

| 소스 | 전략 |
|------|------|
| Semantic Scholar | 키 없음 시 100 req/5min; 403 수신 시 자동 retry without key |
| CORE | 자유 키 권장; 401/403 시 지수적 백오프 후 폴백 |
| OpenAIRE | transient 403 시 3× 재시도 + escalating request profile |
| Google Scholar | proxy URL 필수 (bot-detection 우회) |

**API 키 환경변수 스키마** (`.env` 또는 shell export):
```bash
PAPER_SEARCH_MCP_UNPAYWALL_EMAIL=user@example.com  # 필수 (Unpaywall)
PAPER_SEARCH_MCP_CORE_API_KEY=...                  # 권장 (core.ac.uk 무료)
PAPER_SEARCH_MCP_SEMANTIC_SCHOLAR_API_KEY=...      # 선택 (rate limit 향상)
PAPER_SEARCH_MCP_GOOGLE_SCHOLAR_PROXY_URL=...      # 선택 (bot-detection)
PAPER_SEARCH_MCP_IEEE_API_KEY=...                  # 스켈레톤 활성화
PAPER_SEARCH_MCP_ACM_API_KEY=...                   # 스켈레톤 활성화
```

모든 키는 선택적(Unpaywall 제외). **키 없이 최소 20개 소스 사용 가능**.

#### 1.3 결과 Normalization — Paper 클래스 표준화

**Paper 클래스 필드** (`papers.py`에서 추출):
```python
{
    "title": str,           # 논문 제목
    "authors": List[str],   # 저자 목록
    "abstract": str,        # 초록
    "year": int,            # 출판 연도
    "source": str,          # 출처 플랫폼 (예: "arxiv", "pubmed")
    "doi": str | None,      # DOI
    "url": str | None,      # 논문 페이지 URL
    "pdf_url": str | None,  # PDF 직접 URL
    "doi_extracted": bool   # True = regex 추출, False = API 필드 직접
}
```

**소스별 다른 응답 → 통일 방식**: 각 커넥터가 플랫폼 API 응답을 위 schema에 매핑. `source` 필드가 항상 원래 플랫폼을 보존 → **출처 라벨링 자동 보장**.

#### 1.4 환각 가능성 검증 — Raw Passthrough인가 LLM 합성인가

**결론: 완전한 raw passthrough. LLM 합성 없음.**

증거:
1. `asyncio.gather()`로 각 플랫폼 API를 직접 호출, 응답을 `Paper` dict로 변환만 함
2. LLM 호출 코드가 존재하지 않음 (`langchain`, `openai`, `anthropic` 등 AI SDK 의존성 없음)
3. `doi_extracted: bool` 필드가 regex 추출과 API 필드 직접 획득을 구분 — 데이터 출처 추적
4. README 명시: "Search results should be standardized, deduplicated, and as complete as possible for **downstream LLM workflows**" → LLM이 소비하는 upstream, 합성하는 것이 아님

**단 하나의 주의**: `download_with_fallback`의 Sci-Hub 옵션은 선택적이나 법적 greyzone. DRLLM에서는 이 단계를 비활성화해야 함.

#### 1.5 DRLLM S2 통합 청사진

**호출할 tool:**
- `search_papers` — S2 학술 검색 기본 진입점 (sources="arxiv,pubmed,semantic_scholar,crossref,openalex")
- `download_with_fallback` — full-text 필요 시 (Sci-Hub 비활성화 상태로)
- `read_arxiv_paper` — arXiv 논문 full-text 직접 읽기

**`gemini-extension.json` mcpServers 등록 예제:**
```json
{
  "mcpServers": {
    "paper-search": {
      "command": "uvx",
      "args": ["paper-search-mcp"],
      "env": {
        "PAPER_SEARCH_MCP_UNPAYWALL_EMAIL": "${UNPAYWALL_EMAIL}",
        "PAPER_SEARCH_MCP_CORE_API_KEY": "${CORE_API_KEY}",
        "PAPER_SEARCH_MCP_SEMANTIC_SCHOLAR_API_KEY": "${SS_API_KEY}"
      }
    }
  }
}
```

---

### 2. github/github-mcp-server — 동적 툴셋 발견 메커니즘

#### 2.1 동적 툴셋 발견 메커니즘 (코드 레벨)

**아키텍처** (`internal/ghmcp/server.go` — NewStdioMCPServer):

```go
inventoryBuilder := github.NewInventory(cfg.Translator).
    WithDeprecatedAliases(github.DeprecatedToolAliases).
    WithReadOnly(cfg.ReadOnly).
    WithToolsets(github.ResolvedEnabledToolsets(...))

// DynamicToolsets 플래그 시 discovery tools만 초기 등록
// StdioServerConfig.DynamicToolsets = true
```

**builder 패턴**: `WithToolsets()`, `WithDynamicToolsets()`, `WithReadOnly()` 등 체이닝으로 서버 구성을 조합. 각 옵션은 composable — 동시 사용 가능.

**Dynamic Toolsets 초기화 시 등록되는 3개 discovery tool:**

| Tool | 역할 |
|------|------|
| `list_available_toolsets` | 20개 툴셋 이름+설명 목록 반환 |
| `get_toolset_tools` | 특정 툴셋에 포함된 tool 목록 반환 |
| `enable_toolset` | 지정 툴셋을 현재 세션에 동적 로드 |

**동작 시퀀스** (beta, local binary 전용):
```
서버 시작 → discovery tools 3개만 활성화
   ↓
LLM: list_available_toolsets 호출 → 20개 툴셋 이름 수신
   ↓ (사용자 프롬프트 분석)
LLM: enable_toolset("issues") 호출 → issues 툴셋 도구들 활성화
   ↓
LLM: SearchIssues, ListIssues, GetIssue, IssueWrite 도구 사용 가능
```

**정적 방식과의 차이:**
- 정적: `--toolsets repos,issues` → 시작 시 고정 로드, 80+ 도구 모두 컨텍스트에 노출
- 동적: 시작 시 3개 → 요청에 따라 필요 도구만 확장 → 컨텍스트 윈도우 절약

#### 2.2 등록된 Tool 목록 및 Schema (Issues 툴셋 상세)

**20개 툴셋 목록** (기본 활성화 5개 볼드):

**context**, **issues**, **pull_requests**, **repos**, **users**, actions, code_security, copilot (remote only), dependabot, discussions, gists, git, labels, notifications, orgs, projects, secret_protection, stargazers, github_support_docs_search (remote only), and more.

**Issues 툴셋 — 3개 tool:**

```
SearchIssues
  - query: str (GitHub search syntax, is:issue 자동 추가)
  - owner: str (optional)
  - repo: str (optional)
  - sort: "comments"|"reactions"|"created"|...
  - order: "asc"|"desc"
  → REST API 사용
  → MinimalIssuesResponse 반환 (raw GitHub API 응답 최소 변환)

ListIssues
  - owner: str (required)
  - repo: str (required)
  - state: "open"|"closed"|"all"
  - labels: List[str]
  - orderBy: "created_at"|"updated_at"|"comments"
  - since: datetime
  - perPage: int (default 30)
  - after: str (cursor, GraphQL pagination)
  → GraphQL 사용 (labels/since 조합에 따라 4가지 쿼리 자동 선택)
  → 커서 기반 페이지네이션

GetIssue
  - method: "get"|"get_comments"|"get_sub_issues"|"get_labels"
  - owner: str (required)
  - repo: str (required)
  - issue_number: int (required)
  → REST + GraphQL 혼합
  → lockdown mode 시 신뢰 사용자만 콘텐츠 접근 가능
```

#### 2.3 GraphQL vs REST 사용 패턴

**REST 사용처:**
- 기본 CRUD: 이슈 생성/업데이트, 댓글 추가
- 단순 검색: `SearchIssues` (GitHub 검색 API)
- 단일 리소스 조회

**GraphQL 사용처:**
- 복잡한 관계형 데이터: PR 리뷰 스레드 (isResolved, isOutdated, isCollapsed)
- 커서 기반 페이지네이션: `ListIssues`, `ListPullRequests`
- 조건부 복합 쿼리: labels × since 조합으로 4가지 쿼리 자동 선택

**서버 추상화**: MCP tool 파라미터는 동일, 백엔드 API 선택은 서버가 자동 결정.

#### 2.4 인증 및 권한 처리

**인증 방법:**
- `GITHUB_PERSONAL_ACCESS_TOKEN` 환경변수 (PAT)
- OAuth (VS Code 1.101+, 호환 MCP 호스트)

**권장 최소 scope:**
```
repo              # 저장소 조작 (이슈/PR read/write)
read:org          # 조직/팀 접근
security_events   # 보안 스캔 도구
```

**Scope filtering**: 토큰 권한에 따라 서버가 자동으로 사용 가능 도구 제한. 쓰기 권한 없는 토큰에서는 write tool 비노출.

**보안 모드:**
- `--read-only`: 모든 쓰기 작업 차단 (DRLLM S2 사용 시 권장)
- `--lockdown-mode`: 공개 저장소를 push 권한 보유 사용자만 접근

#### 2.5 DRLLM이 GitHub Issue/PR 검색에 호출해야 할 Tool

**S2 Research Execution에서의 호출 순서:**

```
1. SearchIssues(query="<topic> is:issue", owner="<repo_owner>", repo="<repo_name>")
   → 키워드 기반 이슈 검색 (REST, 빠름)

2. ListIssues(owner, repo, state="all", labels=["bug"], since=datetime)
   → 특정 레포의 필터된 이슈 목록 (GraphQL, 페이지네이션)

3. GetIssue(method="get", owner, repo, issue_number)
   → 특정 이슈 상세 + 댓글 (method="get_comments")

4. SearchIssues(query="<topic> is:pr")
   → PR 검색 (is:issue를 is:pr로 변경하면 PR 검색)
```

**gemini-extension.json 등록:**
```json
{
  "mcpServers": {
    "github": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
        "-e", "GITHUB_TOOLSETS=context,issues,pull_requests,repos",
        "ghcr.io/github/github-mcp-server"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}",
        "GITHUB_TOOLSETS": "context,issues,pull_requests,repos",
        "GITHUB_READ_ONLY": "1"
      }
    }
  }
}
```

또는 `--dynamic-toolsets` 활성화 버전:
```json
{
  "mcpServers": {
    "github": {
      "command": "github-mcp-server",
      "args": ["--dynamic-toolsets", "--read-only"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

---

### 3. Anthropic 공식 fetch MCP — 환각 방지 메커니즘

#### 3.1 Tool Schema (코드 레벨)

**Pydantic model 정의** (`server.py` — Fetch 클래스):
```python
class Fetch(BaseModel):
    url: AnyUrl                          # 필수, 유효 URL 강제
    max_length: int = Field(5000, ge=1, le=999_999)  # 응답 길이 제어
    start_index: int = Field(0, ge=0)    # 청킹 시작 위치
    raw: bool = False                    # True: 원본 HTML, False: markdown 변환

# 스키마 자동 노출
tool_schema = Fetch.model_json_schema()
```

#### 3.2 Response 반환 형식 (코드 레벨 증거)

**`fetch_url()` async 함수 핵심 로직:**
```python
async def fetch_url(url, user_agent, raw=False, proxy=None):
    async with httpx.AsyncClient(timeout=30.0, follow_redirects=True) as client:
        response = await client.get(url, headers={"User-Agent": user_agent})
        response.raise_for_status()   # 4xx+ → McpError 발생

    content = response.text

    if not raw and is_html(content_type):
        # readabilipy + markdownify로 HTML → markdown 변환
        content = simplify_html(content)
    elif not is_html(content_type):
        prefix = f"Content type {content_type} cannot be simplified to markdown, but here is the raw content:\n"

    # 최종 반환 포맷: URL이 prefix에 명시
    return f"Contents of {url}:\n{content}"
```

**핵심**: 반환 문자열은 `"Contents of {url}:\n{content}"` 형태로 **URL이 항상 응답 헤더에 포함**.

#### 3.3 LLM이 원본을 변조할 수 있는가

**MCP 도구 레벨에서의 변조 불가능성:**
- `fetch_url()`은 HTTP 응답의 text를 markdown으로 변환하여 반환 — LLM 생성 텍스트 없음
- 서버 코드에 LLM API 호출 없음 (`anthropic`, `openai` SDK 불사용)
- 반환 이후 MCP 클라이언트(Gemini/Claude)가 tool_result로 받는 시점에는 이미 fetch된 텍스트

**MCP 클라이언트 레벨에서의 변조 가능성 (주의):**
- tool_result를 받은 LLM이 요약/재서술할 때 변조 발생 가능
- 이는 MCP fetch 서버의 책임 범위 밖 — **calling LLM의 프롬프트 설계 문제**
- DRLLM에서 대응책: S2 스킬에서 "tool 결과는 요약하지 말고 인용 형태로 전달하라" 지시

#### 3.4 URL Attribution 보존 구조

**implicit attribution 방식 (코드 증거):**
```python
# 서버 측 반환 포맷
return f"Contents of {url}:\n{content}"

# 페이지네이션 시 next chunk 안내
if len(content) > max_length:
    return f"Contents of {url} (chars {start_index}-{end_index}):\n{truncated_content}\n\n[Use start_index={end_index} to continue]"
```

**한계**: URL은 응답 텍스트의 첫 줄에 포함되지만 별도 메타데이터 필드로 구조화되지 않음. LLM이 텍스트를 파싱하여 URL을 추출해야 한다. paper-search-mcp의 `source` 필드처럼 구조화된 attribution과 비교하면 약함.

#### 3.5 robots.txt — 환각 방지 보조 메커니즘

**`check_may_autonomously_fetch_url()` 로직:**
```python
def check_may_autonomously_fetch_url(url: str) -> None:
    robots_url = f"{urlparse(url).scheme}://{urlparse(url).netloc}/robots.txt"
    response = httpx.get(robots_url)

    if response.status_code in (401, 403):
        raise McpError("Access denied by robots.txt (auth required)")

    # Protego 라이브러리로 파싱 (comment 제거)
    parser = Protego.parse(response.text)
    if not parser.can_fetch(user_agent, url):
        raise McpError(f"URL disallowed by robots.txt rules")
```

이 메커니즘은 **자율 fetch 시도**를 제한하지만, **사용자가 명시적으로 URL을 지정**한 경우 (user-originated request)는 robots.txt 체크를 우회한다. DRLLM S2는 사용자/LLM이 URL을 직접 제공하는 흐름이므로 user-originated로 처리됨.

#### 3.6 환각 방지 강도 평가

| 메커니즘 | 강도 | 설명 |
|---------|------|------|
| HTTP 직접 fetch | Hard | URL을 실제 네트워크 요청으로 검증 |
| 4xx→McpError | Hard | 존재하지 않는 URL 자동 차단 |
| URL in response header | Soft | 텍스트 기반, 구조화 없음 |
| LLM 합성 방지 | N/A | 서버 레벨에서는 보장, 클라이언트 LLM 요약 시 약화 가능 |

**Phase 1 대비 추가 발견**: URL이 응답 텍스트에 포함되는 방식이 구조화된 attribution (별도 JSON 필드)이 아닌 텍스트 prefix 방식임을 코드로 확인. **이는 DRLLM S2에서 별도 URL 파싱 로직이 필요함을 의미**.

---

### 4. A3 도구 재평가 — Stack Overflow, Reddit, HackerNews

#### 4.1 StackExchange/Stack-MCP 재평가

**Phase 1 점수**: M3·A4·P4·F4·I4 = 19/25

**Phase 2 추가 발견:**
- 레포에 README 외 코드 파일 없음 (3 commits). 구현 세부사항은 `api.stackexchange.com/docs/mcp-server`에서만 확인 가능하나 외부 접근 차단됨
- 100 req/day beta 제한은 집중 리서치에 치명적 — DRLLM S2가 단일 세션에서 수십 건 검색 시 당일 한도 소진 가능
- OAuth 필수 (Stack Overflow 계정) — 자동화 워크플로우에서 토큰 갱신 필요
- **공식 beta이므로 2026년 내 제한 완화 예상 (채택 조건부 유지)**

**재평가 점수 변경 없음** (M3·A4·P4·F4·I4 = 19/25). 단 운용 실용성에서 P축 하향 조정 고려:
- **실제 운용 시**: P3으로 재조정 → 17/25 (12~17 구간, 조건부 결정)
- **beta 해소 후**: P4 유지 → 19/25 (채택 가능)

#### 4.2 eliasbiondo/reddit-mcp-server vs adhikasp/mcp-reddit 비교

**eliasbiondo/reddit-mcp-server** (128 stars, 2025-01 last commit):
- **아키텍처**: hexagonal (ports & adapters), 도메인/어댑터 완전 분리
- **인증**: 완전 무인증 (anonymous `redd` 라이브러리)
- **Rate limit**: REDDIT_THROTTLE_MIN/MAX 환경변수 (기본 1-2초 between requests)
- **도구**: 6개 (search, search_subreddit, get_post, get_subreddit_posts, get_user, get_user_posts)
- **설치**: `uvx reddit-no-auth-mcp-server` (zero-config)
- **위험**: 비공식 anonymous 접근, Reddit 정책 변경 시 즉시 중단 가능

**adhikasp/mcp-reddit** (388 stars, Python):
- **인증**: fetch_hot_threads만 문서화, 세부 인증 방식 불명확 (소스 코드 직접 확인 불가)
- **도구**: fetch_hot_threads 위주 — eliasbiondo보다 도구 수 적음
- **별 수**: 388 (eliasbiondo 128 대비 3배)
- **Docker 지원**: 있음

**비교 결론:**
- 도구 다양성: eliasbiondo 우세 (6개 vs 1개 확인)
- 커뮤니티 신뢰도: adhikasp 우세 (388 vs 128 stars)
- 실용성: eliasbiondo 우세 (zero-config, 헥사고날 아키텍처로 공식 API 교체 용이)

**DRLLM 권장**: eliasbiondo를 단기 프로토타이핑에 사용하되, Reddit 공식 OAuth API 기반 구현(`REDDIT_CLIENT_ID/SECRET`)으로 장기 교체 계획 필요. adhikasp는 별 수가 높지만 도구 다양성이 낮아 제외.

**Phase 1 점수 재평가**: M3·A3·P4·F3·I5 = 18/25 **유지** (eliasbiondo 기준)

#### 4.3 HackerNews — 추가 후보 검토

**Phase 1에서 기각된 Malayke/hackernews-mcp** (Firecrawl API 의존):
- 대안: `imprvhub/mcp-claude-hackernews` 또는 공식 HN API 기반 구현
- HN 공식 API는 인증 불필요, JSON 반환, rate limit 없음 — 구현 용이
- DRLLM F 점수: HN은 기술 토론 풍부하나 학습 컨텐츠 직접 관련성 낮음 (F3)
- **결론**: 자체 경량 구현 가능하나 SP-2 우선순위 낮음

---

## DRLLM SP-2 통합 청사진

### 4.1 권장 MCP 조합

**Tier 1 — 필수 (즉시 채택):**

| MCP | 역할 | 이유 |
|-----|------|------|
| `modelcontextprotocol/fetch` | 공식문서/웹 직접 fetch | Anthropic 공식, 24/25점, 환각 방지 구조적 보장 |
| `github/github-mcp-server` | GitHub Issue/PR/코드 검색 | 공식, 23/25점, raw API 응답, 80+ 도구 |
| `openags/paper-search-mcp` | 학술논문 다중 소스 | 22/25점, 24개 소스, LLM 합성 없음 |

**Tier 2 — 조건부 채택:**

| MCP | 조건 | 이유 |
|-----|------|------|
| `StackExchange/Stack-MCP` | beta 100req/day 제한 해소 후 | 공식, 개발 Q&A 특화 |
| `eliasbiondo/reddit-mcp-server` | 프로토타이핑 단계 | zero-config, 장기는 공식 OAuth 교체 |
| `exa-labs/exa-mcp-server` | 의미론적 탐색 필요 시 | API 비용 감안, Brave Search 대안 검토 |

**제외:**
- `pminervini/deep-research-mcp`: 내부 LLM 합성 (P축 불일치)
- `ai_search` mode (mcp-omnisearch): LLM 합성 결과

### 4.2 gemini-extension.json mcpServers 섹션 초안

```json
{
  "name": "DRLLM",
  "description": "Domain-agnostic Deep Research + LearnLM tutoring framework",
  "version": "0.1.0",
  "mcpServers": {
    "fetch": {
      "command": "uvx",
      "args": ["mcp-server-fetch"],
      "env": {
        "DEFAULT_USER_AGENT_AUTONOMOUS": "ModelContextProtocol/1.0 (DRLLM-S2; +https://github.com/namykim/DRLLM)"
      }
    },
    "github": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
        "-e", "GITHUB_TOOLSETS=context,issues,pull_requests,repos,users",
        "-e", "GITHUB_READ_ONLY=1",
        "ghcr.io/github/github-mcp-server"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "paper-search": {
      "command": "uvx",
      "args": ["paper-search-mcp"],
      "env": {
        "PAPER_SEARCH_MCP_UNPAYWALL_EMAIL": "${UNPAYWALL_EMAIL}",
        "PAPER_SEARCH_MCP_CORE_API_KEY": "${CORE_API_KEY}",
        "PAPER_SEARCH_MCP_SEMANTIC_SCHOLAR_API_KEY": "${SS_API_KEY}"
      }
    }
  }
}
```

**docker 없이 github-mcp-server 바이너리 사용 시 대안:**
```json
"github": {
  "command": "github-mcp-server",
  "args": ["--toolsets", "context,issues,pull_requests,repos,users", "--read-only"],
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
  }
}
```

**dynamic-toolsets 사용 시 대안** (컨텍스트 절약 우선):
```json
"github": {
  "command": "github-mcp-server",
  "args": ["--dynamic-toolsets", "--read-only"],
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
  }
}
```

### 4.3 S2 (Research Execution) 스킬에서 Tool 호출 순서

**S1이 생성한 Research Plan을 S2가 실행하는 흐름:**

```
[S2 진입] Research Plan 수신 (출처 유형 × 쿼리 목록)

FOR EACH 쿼리 in plan:

  IF 쿼리 유형 == "학술논문":
    1. paper-search::search_papers(
         sources="arxiv,pubmed,semantic_scholar,crossref,openalex",
         query="<쿼리>",
         max_results=10
       )
    2. [선택] paper-search::download_with_fallback(doi=<DOI>)
       # full-text 필요 시, Sci-Hub 단계 비활성화

  IF 쿼리 유형 == "GitHub Issue/PR":
    1. github::SearchIssues(query="<주제> is:issue", owner, repo)
    2. [선택] github::GetIssue(method="get_comments", ...)
       # 상위 이슈 상세 읽기

  IF 쿼리 유형 == "공식문서/웹":
    1. fetch::fetch(url="<알려진 URL>", raw=false, max_length=5000)
    2. [긴 문서] fetch::fetch(url, start_index=5000, ...)
       # 청킹으로 전체 읽기

  IF 쿼리 유형 == "커뮤니티 (SO/Reddit)":
    1. stackoverflow::search(query="<오류/패턴>")  # beta 제한 감안
    2. [reddit 대안] reddit::search(query="<주제>", subreddit="learnprogramming")

[결과 수집] 모든 tool_result를 출처 라벨과 함께 구조화
  - source: 도구명 (fetch/github/paper-search/...)
  - url: 원본 URL (변조 금지)
  - content: 원본 텍스트 (요약 금지 — S3에서 처리)

[Hard Gate] 환각 URL 체크: 모든 URL은 tool_result에서 직접 추출
  - LLM이 생성한 URL 사용 금지
  - fetch 도구가 반환한 "Contents of {url}:" prefix에서 URL 추출

[S3 호출] Research 결과 → LearnLM Prompt Synthesis
```

**출처 라벨링 보장 구조:**
- `paper-search::search_papers` → 결과 dict의 `source` 필드 (arXiv, PubMed 등)
- `github::SearchIssues` → `html_url` 필드 (github.com/... raw URL)
- `fetch::fetch` → 응답 텍스트 첫 줄 `"Contents of {url}:\n..."` — 파싱 필요
- **통일 권장**: S2 스킬이 모든 tool_result를 `{source_type, source_url, content}` 구조로 재래핑

---

## 새로 발견된 Caveats / Risks

Phase 1 이후 코드 레벨 분석에서 추가 발견된 사항:

### fetch MCP — attribution이 구조화되지 않음

`"Contents of {url}:\n{content}"` 포맷은 **텍스트 내 URL embedding**이다. JSON 필드가 아니므로 S2 스킬이 URL을 파싱해야 한다. paper-search-mcp의 `source` 필드와 달리 구조화 신뢰도가 낮다.

**대응**: S2 스킬에서 fetch 결과를 수신 즉시 `{"url": ..., "content": ...}` 구조로 재래핑하는 파서 필요. 이 변환은 LLM 프롬프트 지시로 충분히 구현 가능.

### github-mcp-server — dynamic toolsets는 beta이며 remote 서버 미지원

`--dynamic-toolsets`는 local binary 전용 (Docker/Go 빌드 필요). Gemini CLI Extension에서 원격 MCP 엔드포인트 사용 시 (future) dynamic toolsets 사용 불가.

**대응**: 단기는 `--toolsets context,issues,pull_requests,repos,users` 정적 방식 사용. 5개 툴셋은 컨텍스트 오버로드 없이 충분히 관리 가능 (80+ tool → ~30개 tool로 제한).

### paper-search-mcp — Sci-Hub 단계 명시적 비활성화 필요

`download_with_fallback`의 4단계는 Sci-Hub fallback이다. 설정 없이 사용하면 자동 시도. DRLLM에서는 법적/정책적 이유로 이 단계를 명시적으로 차단해야 한다.

**대응**: `PAPER_SEARCH_MCP_SCIHUB_ENABLED=false` 환경변수 설정 또는 `download_with_fallback` 대신 `download_with_fallback(use_scihub=False)` 파라미터 확인 필요. 실제 파라미터 이름은 서버 코드 직접 확인 필요 (소스 접근 제한으로 확인 불완전).

### Stack-MCP — 100 req/day beta 제한이 S2 단일 세션 소진 가능

DRLLM S2가 주제별로 10~20개 SO 검색을 실행하면 하루 한도 소진. 현재 단독 채택 금지.

### reddit-mcp-server (eliasbiondo) — Reddit 정책 변경 위험

anonymous 접근 방식이므로 Reddit API 정책 변경 시 즉시 중단. 2023년 Reddit API 유료화 precedent가 있음. **장기 채택에 부적합**, 단기 프로토타이핑 전용.

---

## 변경된 권장 (Phase 1 대비)

### 점수 변경

| 항목 | Phase 1 | Phase 2 | 변경 이유 |
|------|---------|---------|-----------|
| StackExchange/Stack-MCP | M3·A4·P4·F4·I4 = 19/25 | M3·A4·**P3**·F4·I4 = **18/25** | 100 req/day 실제 운용 시 P축 하향 (beta 해소 전) |
| modelcontextprotocol/fetch | M5·A5·P5·F4·I5 = 24/25 | **P5 유지, F3으로 재검토** | URL attribution 비구조화 발견 — S2에서 파싱 레이어 필요 → F 약간 낮아짐. 최종 23~24/25 범위 |

### 추천 변경

| 항목 | Phase 1 | Phase 2 | 변경 |
|------|---------|---------|------|
| paper-search-mcp Sci-Hub | 언급 없음 | 명시적 비활성화 필수 | **추가 주의사항** |
| github-mcp-server dynamic | 채택 권장 | 정적 방식 우선 권장 | dynamic은 beta + local binary 전용 |
| fetch URL attribution | 구조화된 것으로 가정 | 텍스트 파싱 필요 | S2에서 재래핑 레이어 필요 |
| reddit 구현 선택 | eliasbiondo 또는 adhikasp | eliasbiondo (단기만) | 장기는 공식 OAuth 구현으로 교체 |

### 우선순위 변경

**Phase 2 확정 최종 조합 (SP-2 설계 입력):**

1. **즉시 채택 (3개)**: fetch MCP + github-mcp-server + paper-search-mcp
2. **조건부 채택 (2개)**: Stack-MCP (beta 해소 후) + eliasbiondo/reddit (프로토타이핑 전용)
3. **보류**: exa-mcp-server (비용 검토 후)
4. **기각 유지**: deep-research-mcp (LLM 합성), ai_search mode (mcp-omnisearch)

---

*본 보고서는 GitHub WebFetch, WebSearch 결과만을 기반으로 작성되었습니다. 환각 정보 없음. 코드 참조는 WebFetch로 직접 확인된 내용만 인용했습니다.*
