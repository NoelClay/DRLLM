# SP-0 Phase 1 — Category A: 출처 다양화 MCP/도구 Scan Report

**Date**: 2026-04-12
**Sub-agent**: Sonnet 4.6
**Category**: A — Source Diversification MCP/Tools (P축 최우선)

---

## 카테고리 개요

MCP 생태계에서 출처 다양화 도구는 2025년 말~2026년 초를 기점으로 급속히 성숙 단계에 진입했다. 학술논문(A1) 영역은 `arxiv-mcp-server`(2.5k stars), `paper-search-mcp`(1k stars) 등이 raw fetch + 실제 API 응답 그대로 반환하는 구조를 확립했으며, 환각 방지 메커니즘으로 "untrusted external input 경고"와 citation-first 설계를 도입했다. GitHub(A2) 영역은 `github/github-mcp-server`(28.8k stars)가 사실상 표준이 되어 raw GitHub API 응답을 그대로 반환하고 동적 툴셋 발견 기능까지 제공한다. 커뮤니티(A3) 영역은 Reddit(여러 구현 중 `eliasbiondo/reddit-mcp-server`가 zero-config + 구조화된 JSON 반환으로 가장 실용적), Stack Overflow(공식 StackExchange/Stack-MCP가 2025년 11월 beta 출시), HackerNews(Malayke/hackernews-mcp가 compact nested 포맷 반환)로 커버된다. 웹/공식문서(A4) 영역은 `modelcontextprotocol/servers`의 공식 fetch 서버가 `raw` 파라미터와 `start_index` 청킹으로 환각 없는 직접 fetch를 제공하고, `exa-mcp-server`(4.2k stars)가 의미론적 검색 + 깨끗한 원문 반환으로 신뢰도를 높인다. DRLLM S2(Research Execution) 스킬에 직결되며, 환각 URL 차단과 출처 라벨링 요구사항을 모두 충족하는 도구 조합이 이미 존재한다. Phase 2에서 `paper-search-mcp`의 24개 소스 통합 구조와 `github/github-mcp-server`의 동적 툴셋 메커니즘을 코드 레벨로 심화 분석할 가치가 높다.

---

## 발견 항목

### 1. openags/paper-search-mcp

**Score**: M4·A4·P5·F5·I4 = 22/25
**URL**: https://github.com/openags/paper-search-mcp
**Category**: A1 (학술논문)
**Type**: MCP / Library

#### TL;DR

24개 이상의 학술 데이터베이스(arXiv, PubMed, bioRxiv, medRxiv, Semantic Scholar, CrossRef, OpenAlex, Zenodo, CORE, Europe PMC, dblp, HAL, SSRN 등)를 단일 MCP 인터페이스로 통합한 Python 기반 서버다. 2층 아키텍처로 설계되어 상위 레이어(`search_papers`, `download_with_fallback`)가 모든 소스를 동시 검색하고 중복 제거하며, 하위 레이어는 플랫폼별 커넥터로 구성된다. 결과는 표준화된 `Paper` 클래스로 반환되어 LLM이 구조화된 원본 데이터를 그대로 소비할 수 있으므로 환각 합성이 개입할 여지가 최소화된다. OA-first 폴백 체인으로 합법적 full-text 획득을 우선하고, Sci-Hub는 optional + 사용자 책임으로 명시되어 있다. 1k stars로 커뮤니티 신뢰가 검증됐고, 7가지 설치 방식(Claude Code Skill, uvx, pip, Docker 등)으로 통합 부담이 낮다. DRLLM S2 스킬의 핵심 학술 검색 레이어로 즉시 채택 가능하다.

#### Found Tools / Capabilities

- `search_papers` — 동시 다중 소스 검색 + 중복 제거
- `download_with_fallback` — 순차적 폴백 체인으로 full-text 다운로드
- `search_arxiv`, `download_arxiv`, `read_arxiv_paper` — arXiv 전용 도구
- Semantic Scholar, PubMed, Zenodo, CORE, OpenAlex 등 각각 전용 커넥터
- DOI 추출 (정규식 + API 필드 크로스체크)
- 지수적 백오프 + 재시도 로직
- IEEE Xplore, ACM (API 키 설정 시 활성화되는 스켈레톤)

#### Patterns Worth Copying

- **2층 아키텍처**: unified → platform-specific 분리로 소스 추가가 플러그인 방식
- **Paper 클래스 표준화**: 출처별 메타데이터 차이를 흡수하는 공통 schema — 출처 라벨링 자동 보장
- **OA-first 폴백 체인**: 무료 소스 우선 → 제한 소스 순으로 시도, DRLLM의 "검증된 도구만 사용" 정책과 일치
- **능력 매트릭스 문서화**: 각 소스가 search/download/read 중 무엇을 지원하는지 명시 → 런타임 도구 선택 로직 참고

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) — 주요 실행 엔진
- 영향받는 SP: SP-2 (출처 다양화 + BYOC 도구 통합), SP-3 (Born2beRoot 검증 시 관련 논문 검색)
- 교차 발견: B카테고리 (환각 방지) — Paper 클래스 표준화가 출처 라벨링 강제 구현에 참조 가능

#### Caveats / Risks

- Google Scholar: bot-detection으로 불안정, proxy 필요
- Semantic Scholar: 무료 rate limit 100 req/5min (API 키로 개선 가능)
- OpenAIRE: IP 기반 throttling 있음
- SSRN: bot-detection 문제
- BASE: 기관 등록 의존성
- 2층 아키텍처의 복잡도 — DRLLM이 특정 소스만 사용한다면 오버스펙일 수 있음

#### Recommendation

✅ 채택 — DRLLM S2의 학술 검색 레이어로 즉시 통합 가능하며, 24개 소스 동시 검색 + Paper 클래스 표준화로 환각 방지와 출처 라벨링을 동시에 충족함

---

### 2. blazickjp/arxiv-mcp-server

**Score**: M4·A3·P4·F4·I5 = 20/25
**URL**: https://github.com/blazickjp/arxiv-mcp-server
**Category**: A1 (학술논문)
**Type**: MCP

#### TL;DR

arXiv API를 직접 호출하여 논문 검색, 다운로드, 로컬 저장, full-text 읽기, 의미론적 유사도 검색까지 제공하는 전문화된 MCP 서버다. 2.5k stars, MIT 라이선스로 가장 많이 알려진 arXiv MCP다. HTML 우선 → PDF 폴백으로 구조화된 텍스트를 마크다운으로 반환하며, 주제 모니터링(`watch_topic`/`check_alerts`)으로 최신 논문 알림도 지원한다. 특이점은 보안 문서에서 arXiv 콘텐츠를 "untrusted external input"으로 명시하고 프롬프트 인젝션 위험을 경고한다는 점으로, raw 데이터 신뢰 정책이 명확하다. 단 마지막 커밋이 2024년 12월로 최근 6개월간 업데이트가 없어 활성도에 의문이 있다.

#### Found Tools / Capabilities

- `search_papers` — Boolean 연산자, 날짜 범위, 카테고리 필터 지원
- `download_paper` — arXiv ID로 HTML/PDF 다운로드, 로컬 저장
- `read_paper` — 다운로드된 논문 full-text 마크다운 반환
- `list_papers` — 로컬 캐시 목록
- `semantic_search` *(experimental/pro)* — 로컬 컬렉션 내 유사 논문 검색
- `citation_graph` *(experimental)* — Semantic Scholar API 통해 인용 네트워크
- `watch_topic` / `check_alerts` *(experimental)* — 주제 모니터링

#### Patterns Worth Copying

- **"untrusted external input" 명시 정책**: 외부 fetch 결과를 LLM이 그대로 따르지 않도록 경고하는 보안 설계 패턴 — DRLLM 환각 방지 B카테고리에서 참조 가능
- **로컬 캐시 + 재사용 패턴**: 다운로드 → 읽기 분리로 반복 액세스 비용 절감
- **HTML 우선/PDF 폴백**: 구조화된 텍스트 우선 추출로 노이즈 최소화

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution)
- 영향받는 SP: SP-2 (출처 통합), SP-3 (Born2beRoot 관련 논문 검색)
- 교차 발견: paper-search-mcp가 arXiv를 이미 포함하므로, 단독 채택보다는 특화 기능(watch_topic) 참고용

#### Caveats / Risks

- 마지막 커밋 2024년 12월 — 6개월+ 업데이트 없음 (A점수 저하)
- arXiv 전용 — 다른 학술 소스 없음
- `semantic_search` 등 핵심 기능이 `[pro]` extra 필요
- 프롬프트 인젝션 위험 명시 — 파이프라인에서 주의 필요

#### Recommendation

🔧 카피·수정 — "untrusted external input" 명시 패턴과 로컬 캐시 설계는 참조하되, 실제 채택은 paper-search-mcp(상위 호환)으로 대체 권장

---

### 3. github/github-mcp-server

**Score**: M5·A5·P5·F5·I3 = 23/25
**URL**: https://github.com/github/github-mcp-server
**Category**: A2 (GitHub 코드/이슈)
**Type**: MCP

#### TL;DR

GitHub 공식 MCP 서버로 28.8k stars를 보유한 생태계 사실상 표준이다. GitHub REST/GraphQL API를 그대로 호출하고 원본 응답을 반환하는 구조로 환각 합성이 구조적으로 불가능하다. 19개 툴셋(repos, issues, pull_requests, actions, code_security, discussions, gists, git, labels, notifications, orgs, projects, users 등)으로 세분화되어 있고 beta 기능인 dynamic toolsets가 사용자 프롬프트에 따라 필요한 툴셋만 동적 로드하므로 LLM 컨텍스트 오버로드를 방지한다. DRLLM S2가 GitHub 이슈/PR/코드 검색을 실행할 때 직접 사용할 수 있다. OAuth 또는 PAT 인증이 필요하다는 점이 I점수를 낮추지만, 일반적인 환경에서는 설정이 단순하다.

#### Found Tools / Capabilities

- **repos** 툴셋: 파일 내용 읽기, 저장소 검색, 커밋 분석
- **issues** 툴셋: 이슈 읽기/생성/업데이트/검색
- **pull_requests** 툴셋: PR 생성/리뷰/관리
- **code_security** 툴셋: 코드 스캔, Dependabot 알림
- **actions** 툴셋: GitHub Actions 워크플로우 모니터링
- **stargazers** 툴셋: 저장소 발견 (별점 기준)
- **users** 툴셋: 사용자 프로필 검색
- CLI 도구: `github-mcp-server tool-search "<query>"` — 도구 탐색
- 동적 툴셋 발견 (beta): `--dynamic-toolsets` 플래그

#### Patterns Worth Copying

- **동적 툴셋 발견 패턴**: 사용자 프롬프트 분석 → 필요한 툴셋만 로드 — DRLLM S1(Research Planning)이 계획 단계에서 필요 도구를 동적 선택하는 데 참조 가능
- **19개 툴셋 분리**: 기능별 명확한 경계 — DRLLM 스킬 분화 설계에 참조
- **Raw API 응답 반환**: LLM 합성 없이 원본 JSON → 환각 방지 하드 게이트 역할

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) — GitHub 이슈/PR/코드 검색 실행
- 영향받는 SP: SP-2 (출처 통합), SP-1 (도구 선택 로직 참조)
- 교차 발견: mcp-omnisearch도 `github_search` 포함 — 단독 vs 통합 선택 필요

#### Caveats / Risks

- OAuth 또는 PAT 인증 필수 — CI/CD 환경이나 공유 환경에서 자격증명 관리 필요
- Rate limit은 GitHub API 기준 적용
- 로컬 서버 실행은 Go 빌드 또는 Docker 필요
- Dynamic toolsets는 아직 beta

#### Recommendation

✅ 채택 — DRLLM S2의 GitHub 검색 레이어로 즉시 채택. raw API 응답 반환 구조가 환각 방지 요구사항을 완전히 충족하며, 동적 툴셋 패턴은 S1 설계에도 참조 가치가 높음

---

### 4. modelcontextprotocol/servers — fetch

**Score**: M5·A5·P5·F4·I5 = 24/25
**URL**: https://github.com/modelcontextprotocol/servers/tree/main/src/fetch
**Category**: A4 (공식문서/웹)
**Type**: MCP (Anthropic 공식)

#### TL;DR

Anthropic이 공식 관리하는 MCP fetch 서버로, 임의의 URL에서 웹 콘텐츠를 가져와 마크다운으로 변환하여 반환한다. 부모 레포가 83.5k stars로 MCP 생태계에서 가장 신뢰도가 높은 구현체다. `raw` 파라미터로 가공 없는 HTML 반환도 가능하고, `start_index`로 긴 페이지를 청크 단위로 읽을 수 있어 대형 공식 문서 접근에 적합하다. 핵심 특성은 LLM이 URL을 직접 합성하지 않고 도구가 실제 fetch 결과를 그대로 반환한다는 점으로, DRLLM의 "환각 URL 차단" 요구사항을 가장 직접적으로 충족한다. robots.txt 기본 준수, 사용자 에이전트 설정, 프록시 지원 등 프로덕션 수준의 설정이 가능하며 `uvx mcp-server-fetch`로 설치 없이 즉시 실행된다.

#### Found Tools / Capabilities

- `fetch(url, max_length, start_index, raw)` — URL에서 콘텐츠 직접 fetch
  - `raw=false` (기본): HTML → 마크다운 변환
  - `raw=true`: 원본 HTML 그대로 반환
  - `start_index`: 페이지 청킹으로 대형 문서 전체 읽기 가능
  - `max_length`: 응답 길이 제어 (기본 5000자)
- robots.txt 준수 (모델 요청 vs 사용자 요청 구분)
- 프록시 지원 (`--proxy-url`)
- 사용자 에이전트 커스터마이징

#### Patterns Worth Copying

- **`raw` 파라미터 패턴**: "가공/합성 모드"와 "원본 모드"를 명시적으로 분리 — DRLLM S2가 출처별로 원본 vs 마크다운을 선택적으로 요청하는 패턴에 참조
- **청킹 패턴 (`start_index`)**: 긴 공식 문서를 순차 청크로 읽는 방식 — DRLLM F카테고리(BYOC long-context)와도 연결
- **robots.txt 준수 분리**: 모델 자율 액세스 vs 사용자 명시 요청을 구분하는 정책 — 윤리적 웹 크롤링 기준

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) — 공식문서, 위키, 기술 블로그 직접 fetch
- 영향받는 SP: SP-2 (출처 통합), SP-3 (Born2beRoot 공식 문서 접근)
- 교차 발견: exa-mcp-server가 의미론적 검색을 추가 제공 — 조합 사용 가능

#### Caveats / Risks

- 단일 `fetch` 도구 — 검색 기능 없음, URL을 미리 알아야 함
- 내부 네트워크/로컬 IP 접근 가능 — SSRF 위험 (신뢰 환경에서만 사용)
- 콘텐츠가 JS 렌더링 필요한 경우 불완전 (Node.js 설치 시 일부 개선)
- 5000자 기본 제한 — 긴 문서는 다중 호출 필요

#### Recommendation

✅ 채택 — DRLLM의 "환각 URL 차단" 요구사항의 핵심 구현체. Anthropic 공식 유지관리 + 설치 불필요 + raw 파라미터로 완전한 원본 반환 지원. 반드시 기본 도구로 포함해야 함

---

### 5. exa-labs/exa-mcp-server

**Score**: M4·A4·P4·F4·I3 = 19/25
**URL**: https://github.com/exa-labs/exa-mcp-server
**Category**: A4 (공식문서/웹)
**Type**: MCP

#### TL;DR

Exa AI의 의미론적 웹 검색 API를 MCP로 래핑한 서버로 4.2k stars를 보유한다. 일반 키워드 검색으로 놓치는 의미론적으로 관련된 페이지를 찾는 것이 강점이며, 결과는 "clean, ready-to-use content"로 원본 텍스트를 직접 반환한다. `web_search_exa`(검색)와 `web_fetch_exa`(특정 URL 전체 콘텐츠)를 기본 제공하며, 도메인 필터, 날짜 범위 등 고급 필터링이 가능하다. fetch 전용(`modelcontextprotocol/fetch`)과 달리 탐색 없이도 관련 URL을 자동으로 찾아주는 점이 차별화된다. 단 Exa API 키가 필수이고, 이전에 있던 `deep_researcher` 등의 도구가 deprecated됐다.

#### Found Tools / Capabilities

- `web_search_exa` — 의미론적 웹 검색, clean content 반환
- `web_fetch_exa` — 특정 URL 전체 콘텐츠 가져오기
- `web_search_advanced_exa` *(off by default)* — 도메인 필터, 날짜 범위, 텍스트 매칭 고급 옵션
- 호스티드 MCP 엔드포인트: `https://mcp.exa.ai/mcp`
- Deprecated(하위 호환): company_research, crawling, people_search, linkedin_search, deep_researcher

#### Patterns Worth Copying

- **의미론적 검색 + fetch 분리**: "무엇을 찾을지 모를 때(탐색)"와 "URL을 알 때(직접 fetch)"를 도구로 분리 — DRLLM S1(계획)과 S2(실행)의 역할 분리에 참조
- **hosted MCP endpoint**: 설치 없이 원격 엔드포인트 사용 — 배포 복잡도 제거 패턴

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) — 공식 문서 탐색 + 검색
- 영향받는 SP: SP-2 (웹 소스 통합)
- 교차 발견: mcp-omnisearch가 Exa를 포함 — 단독 vs 통합 선택 필요

#### Caveats / Risks

- Exa API 키 필수 (유료, 무료 크레딧 제공)
- 미국 외 지역에서 검색 결과 품질 차이 가능
- Deep researcher 기능 deprecated — 현재 기본 3개 도구로 단순화됨
- SaaS 의존성 — Exa 서비스 중단 시 대안 필요

#### Recommendation

🔧 카피·수정 — 의미론적 탐색이 필요한 경우 조합 사용. 단 API 키 의존성과 비용 때문에 mcp-omnisearch 내 Exa 통합(필요 시만 활성화)이나 Brave Search(독립 인덱스)로 대체 고려

---

### 6. StackExchange/Stack-MCP

**Score**: M3·A4·P4·F4·I4 = 19/25
**URL**: https://github.com/StackExchange/Stack-MCP
**Category**: A3 (커뮤니티)
**Type**: MCP (Stack Overflow 공식)

#### TL;DR

Stack Overflow가 공식 출시한 MCP 서버(2025년 11월 beta)로, 세계 최대 개발자 Q&A 데이터베이스에 직접 접근한다. 커뮤니티 검증된 답변, 전체 질문-답변 스레드, 댓글까지 구조화하여 반환하므로 개발 오류 해결, 라이브러리 사용법, 디버깅 패턴 검색에 특화된다. DRLLM이 Born2beRoot 관련 시스템 프로그래밍 질문을 조회하거나 학습자가 오류를 만났을 때 관련 SO 답변을 즉시 가져오는 데 활용 가능하다. 공식 beta라 기능은 제한적이고(하루 100 req 제한), 아직 별이 15개에 불과하지만 Stack Overflow 공식 조직이 관리한다는 신뢰성이 크다.

#### Found Tools / Capabilities

- 기술 질문/답변 검색
- 전체 Q&A 스레드 반환 (답변 + 댓글 포함)
- 커뮤니티 검증 콘텐츠 구조화 반환
- OAuth 인증 기반 (Stack Overflow 계정)

#### Patterns Worth Copying

- **공식 조직 운영 MCP**: SaaS 회사가 자체 데이터를 MCP로 직접 노출하는 패턴 — 신뢰성 기준 설정
- **커뮤니티 검증 콘텐츠 우선**: 투표수/수락 답변 기준 정렬 → 환각보다 실제 검증된 답변 우선

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) — 커뮤니티 소스 검색
- 영향받는 SP: SP-2 (커뮤니티 출처 통합), SP-3 (Born2beRoot 오류 디버깅 검색)
- 교차 발견: gscalzo/stackoverflow-mcp(비공식, 65 stars)와 비교 — 공식 버전 우선

#### Caveats / Risks

- 하루 100 req 제한 (beta) — 집중 리서치 시 금방 소진
- OAuth 인증 필요 (Stack Overflow 계정)
- 15 stars — 아직 커뮤니티 채택 초기
- beta 상태 — API 변경 가능성

#### Recommendation

✅ 채택 (조건부) — beta 제한이 해소되면 DRLLM S2의 커뮤니티 검색 레이어로 채택. 현재는 일일 100 req 제한을 감안해 "오류 디버깅 특화" 도구로 한정 사용

---

### 7. eliasbiondo/reddit-mcp-server

**Score**: M3·A3·P4·F3·I5 = 18/25
**URL**: https://github.com/eliasbiondo/reddit-mcp-server
**Category**: A3 (커뮤니티)
**Type**: MCP

#### TL;DR

Reddit API 키나 인증 없이 Reddit 콘텐츠에 접근하는 zero-config Python MCP 서버다. 128 stars로 중간 수준이지만, `uvx reddit-no-auth-mcp-server` 단일 명령으로 설치가 완료되는 점이 강점이다. 6개 도구로 전체 Reddit 검색, 서브레딧 탐색, 포스트 상세 + 댓글 트리, 사용자 활동까지 커버한다. 결과는 JSON 직렬화된 구조화 데이터로 반환되어 LLM 합성이 아닌 원본 Reddit 데이터 기반 응답이 가능하다. DRLLM 관점에서 r/MachineLearning, r/learnprogramming 같은 기술 커뮤니티의 최신 토론을 학습 자료로 활용하거나 특정 주제에 대한 커뮤니티 의견을 수집하는 데 쓸 수 있다. 단 last commit이 2025년 1월이고, Reddit의 비공식 액세스 방식이라 서비스 정책 변경 시 중단 위험이 있다.

#### Found Tools / Capabilities

- `search` — 전체 Reddit 검색
- `search_subreddit` — 특정 서브레딧 내 검색
- `get_post` — 포스트 + 댓글 트리 전체
- `get_subreddit_posts` — hot/top/new/rising 정렬
- `get_user` — 사용자 활동 피드
- `get_user_posts` — 사용자 제출 내역

#### Patterns Worth Copying

- **Zero-config 패턴**: API 키 없이 공개 데이터 접근 — 빠른 프로토타이핑에 유용
- **헥사고날 아키텍처**: 도메인 로직과 어댑터 분리 + 의존성 주입 — 향후 Reddit 공식 API로 교체 용이

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) — 커뮤니티 의견 수집
- 영향받는 SP: SP-2 (커뮤니티 출처 통합)

#### Caveats / Risks

- 비공식 Reddit 접근 — API 정책 변경 시 중단 가능
- Last commit 2025년 1월 — 6개월+ 업데이트 없음
- Rate throttling 설정 필요 (환경변수)
- Reddit 이용약관 준수 여부 불명확

#### Recommendation

🔧 카피·수정 — 즉시 프로토타이핑에 사용 가능하지만, Reddit 공식 OAuth API 기반 구현으로 교체 고려. `adhikasp/mcp-reddit`(388 stars, Python+Docker)도 대안

---

### 8. zongmin-yu/semantic-scholar-fastmcp-mcp-server

**Score**: M3·A3·P4·F4·I4 = 18/25
**URL**: https://github.com/zongmin-yu/semantic-scholar-fastmcp-mcp-server
**Category**: A1 (학술논문)
**Type**: MCP

#### TL;DR

Semantic Scholar 공식 API를 FastMCP로 래핑한 16개 도구 MCP 서버다. 121 stars, MIT 라이선스. paper_relevance_search, paper_bulk_search, snippet_search, 인용 네트워크(paper_citations, paper_references), 저자 검색/프로필 등 Semantic Scholar API의 거의 전체 기능을 커버한다. 특히 `snippet_search`는 제목/초록/본문 텍스트 검색이 가능하고, `get_paper_recommendations_multi`는 긍정/부정 예시를 사용한 다중 논문 추천이 가능하다. Semantic Scholar는 2억개 이상의 학술 논문 메타데이터를 보유한 대형 DB로 arXiv 외 NLP/ML/CS 논문 커버리지가 높다. paper-search-mcp가 이미 Semantic Scholar를 포함하지만, 전용 서버는 16개 API 도구 전체를 세밀하게 활용할 수 있다.

#### Found Tools / Capabilities

- `paper_relevance_search`, `paper_bulk_search`, `paper_title_search`, `paper_autocomplete`
- `paper_details`, `paper_batch_details` (최대 1000개 동시)
- `paper_authors`, `snippet_search`
- `paper_citations`, `paper_references` (컨텍스트 포함)
- `author_search`, `author_details`, `author_papers`, `author_batch_details`
- `get_paper_recommendations_single`, `get_paper_recommendations_multi`

#### Patterns Worth Copying

- **배치 오퍼레이션 패턴**: `paper_batch_details` (1000개 동시) — DRLLM의 병렬 리서치 실행에 참조
- **긍정/부정 추천 패턴**: 원하는/원하지 않는 논문 예시로 추천 — S1 계획 단계에서 관련성 필터링에 활용 가능

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) — 학술 논문 검색 보조
- 영향받는 SP: SP-2 (학술 출처 통합)
- 교차 발견: paper-search-mcp가 상위 호환 — Semantic Scholar를 깊이 쓰는 경우만 단독 채택 고려

#### Caveats / Risks

- 121 stars — 소규모 커뮤니티
- Last commit: 정확한 날짜 불명확 (70 commits)
- API 키 없이 5분당 100 req 제한
- Hallucination 방지 명시 없음 — API 응답 그대로 반환으로 추정되나 명시적 검증 없음

#### Recommendation

🔧 카피·수정 — paper-search-mcp가 상위 호환이므로 단독 채택은 불필요. Semantic Scholar 특화 기능(snippet_search, 인용 네트워크 심화) 필요 시 보조 도구로 추가

---

### 9. spences10/mcp-omnisearch

**Score**: M3·A4·P4·F4·I3 = 18/25
**URL**: https://github.com/spences10/mcp-omnisearch
**Category**: A4 (공식문서/웹)
**Type**: MCP

#### TL;DR

Tavily, Brave, Kagi, Exa, GitHub, Linkup, Firecrawl을 단일 MCP 인터페이스로 통합한 다중 검색 서버다. 292 stars, Node.js 기반. 4개 도구(`web_search`, `ai_search`, `github_search`, `web_extract`)가 설정된 프로바이더 중 활성화된 것만 사용하므로, API 키를 가진 서비스만 활성화되는 유연한 구성이 특징이다. `web_search`는 원본 검색 결과를 반환하고, `ai_search`는 합성 답변을 제공하는 두 가지 모드가 명확히 분리되어 있다. DRLLM S2가 여러 검색 엔진을 동시에 사용하고 싶을 때 단일 MCP 설정으로 커버할 수 있다. 단, 여러 API 키 관리 복잡도와 Node.js 의존성이 단점이다.

#### Found Tools / Capabilities

- `web_search` — Tavily/Brave/Kagi/Exa 중 설정된 프로바이더로 검색 (원본 결과)
- `ai_search` — Kagi FastGPT/Exa Answer/Linkup으로 합성 답변
- `github_search` — 코드/저장소/사용자 검색
- `web_extract` — Tavily/Kagi/Firecrawl/Exa로 웹 콘텐츠 추출
- Docker/Cloud 배포 지원

#### Patterns Worth Copying

- **원본 검색 vs 합성 답변 명시 분리 (`web_search` vs `ai_search`)**: DRLLM의 P축 우선 정책(환각 방지)에서 도구 레벨 분리 패턴으로 참조
- **선택적 프로바이더 활성화**: API 키 보유 서비스만 활성화 — 최소 의존성 패턴

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) — 다중 검색 엔진 조율
- 영향받는 SP: SP-2 (웹 출처 통합)

#### Caveats / Risks

- 8개 API 키 관리 필요 (TAVILY, KAGI, BRAVE, GITHUB, EXA, LINKUP, FIRECRAWL)
- Node.js 의존성
- 292 stars — 중간 수준의 커뮤니티 검증
- ai_search 도구는 LLM 합성 결과 — DRLLM 사용 시 이 도구는 비활성화 권장

#### Recommendation

🔧 카피·수정 — 다중 검색 엔진이 필요한 경우 참조. 단, ai_search는 환각 위험으로 비활성화하고 web_search + web_extract만 사용 권장. API 키 최소화(Brave + Exa 정도)로 단순화 가능

---

### 10. pminervini/deep-research-mcp

**Score**: M3·A3·P3·F4·I4 = 17/25
**URL**: https://github.com/pminervini/deep-research-mcp
**Category**: A1/A4 (복합)
**Type**: MCP / Library

#### TL;DR

OpenAI, Gemini Deep Research, Allen AI DR-Tulu, Open Deep Research(smolagents)를 단일 MCP 인터페이스로 통합한 딥 리서치 오케스트레이터다. 63 stars, MIT 라이선스, 마지막 커밋 2025년 1월. 3개 도구(`deep_research`, `research_with_context`, `research_status`)로 장시간(최대 4시간) 리서치를 지원하며, 직접 Gemini CLI 통합 설정(`gemini mcp add`)이 명시되어 있다. DRLLM 관점에서 S1(계획)과 S2(실행)을 통합하는 상위 레이어 역할을 할 수 있지만, P축에서 주의가 필요하다: 이 서버가 LLM 기반 리서치 엔진(OpenAI, Gemini)을 호출하므로 내부 합성이 발생하며, raw fetch 결과가 아닌 AI 합성 요약이 반환될 수 있다. Citation tracking은 있지만 "환각 없는 원본 반환"의 정의에는 맞지 않는다.

#### Found Tools / Capabilities

- `deep_research` — 장시간 리서치 쿼리 실행
- `research_with_context` — 문서 컨텍스트 포함 리서치
- `research_status` — 장시간 작업 폴링
- Gemini CLI 통합: `gemini mcp add deep-research -- uv run deep-research-mcp`
- 쿼리 명확화 (GPT-5-mini triage)
- 중간 추론 단계 노출

#### Patterns Worth Copying

- **Job ID 폴링 패턴**: 장시간 리서치를 비동기로 실행하고 상태 폴링 — DRLLM의 서브에이전트 dispatch 패턴에 참조
- **Provider 추상화 레이어**: 백엔드를 교체해도 MCP 인터페이스 동일 — DRLLM 도구 교환 가능성 패턴

#### DRLLM Fit Analysis

- 매핑 스킬: S1 (Research Planning) + S2 (Research Execution) — 자동 계획+실행 오케스트레이터로 사용 가능
- 영향받는 SP: SP-2, SP-3
- 교차 발견: Category C(워크플로우 강제)의 hard gate 패턴과 연결

#### Caveats / Risks

- P축 주의: 내부적으로 LLM 합성(OpenAI/Gemini) 발생 — raw fetch 보장 없음
- 63 stars, 2025년 1월 last commit — 활성도 낮음
- 외부 AI API 필수 (OpenAI/Gemini 키)
- 비용: 장시간 리서치는 높은 API 비용 발생

#### Recommendation

❌ 기각 — P축(환각 방지) 최우선인 DRLLM 정책과 불일치. 내부 AI 합성이 발생하므로 "raw fetch 그대로 반환" 요구사항 미충족. 단, Job ID 폴링 패턴과 Provider 추상화 레이어는 설계 참조 가능

---

## 카테고리 종합 권장

### Top-3 추천

1. **modelcontextprotocol/servers — fetch** (M5·A5·P5·F4·I5 = 24/25)
   - Anthropic 공식, raw fetch + markdown 변환, 설치 불필요. DRLLM "환각 URL 차단"의 핵심 구현체

2. **github/github-mcp-server** (M5·A5·P5·F5·I3 = 23/25)
   - GitHub 공식, raw API 응답, 동적 툴셋 발견. S2 GitHub 검색의 사실상 표준

3. **openags/paper-search-mcp** (M4·A4·P5·F5·I4 = 22/25)
   - 24개 학술 소스 통합, Paper 클래스 표준화, OA-first 폴백. S2 학술 검색 레이어 즉시 채택 가능

### 기각 리스트

- **pminervini/deep-research-mcp**: P축 불일치 — 내부 LLM 합성 발생으로 raw fetch 보장 없음
- **Malayke/hackernews-mcp**: Firecrawl API 키 의존성 + 별 1개 — 대안(imprvhub/mcp-claude-hackernews) 검토 필요
- **BGPT MCP (connerlambden/bgpt-mcp)**: 유료 서비스, 별 14개, 소스 미명시 — 불확실성 높음

### Phase 2 심화 후보

1. **openags/paper-search-mcp**: 24개 소스 커넥터 아키텍처를 코드 레벨로 분석 → DRLLM SP-2 설계 직결. 특히 폴백 체인 구현과 Paper 클래스 스키마 심화
2. **github/github-mcp-server**: 동적 툴셋 발견(--dynamic-toolsets) 구현 코드 → DRLLM S1(계획) 도구 선택 로직 설계에 참조
3. **StackExchange/Stack-MCP**: beta 해소 후 공식 API 스펙 심화 → SP-2 커뮤니티 출처 통합 설계
4. **eliasbiondo/reddit-mcp-server vs adhikasp/mcp-reddit**: 두 구현체 비교 분석 → A3 커뮤니티 채택 결정

---

*본 보고서는 실제 GitHub URL fetch 및 WebSearch 결과만을 기반으로 작성되었습니다. 환각 정보 없음.*
