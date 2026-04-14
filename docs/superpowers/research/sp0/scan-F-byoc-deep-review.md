# SP-0 Phase 1 — Category F: BYOC Deep Review Scan Report

**Date**: 2026-04-12
**Sub-agent**: Sonnet 4.6
**Category**: F — BYOC Deep Review (P·F축 최우선)

---

## 카테고리 개요

BYOC(Bring Your Own Content) 생태계는 2025~2026년을 거치며 단순 RAG(Top-k chunk retrieval + 합성)에서 벗어나 두 갈래로 진화하고 있다. 첫째, **장문 컨텍스트 LLM 직접 활용** 방향 — Gemini 2.0 Flash(1M 토큰), Claude 3.5+(200K 토큰)가 충분히 커져 PDF 수백 쪽을 통째로 컨텍스트에 올려 "한 권 통독" 수준이 가능해졌다. Anthropic Citations API는 이 흐름에 페이지/문자 단위 출처 고정을 더했다. 둘째, **구조 매핑 + 의미 계층 인덱싱** 방향 — Docling(IBM, 57.6K★), MinerU(59.4K★)처럼 문서를 제목·단락·표·수식 계층으로 파싱한 뒤 MCP로 노출하거나, MinerU-Document-Explorer처럼 "TOC 조회 → 섹션 단위 읽기"를 에이전트에게 제공하는 도구군이 등장했다. EPUB 영역에서는 `ebook-mcp`(356★), `mcp-epub-reader`(13개 탐색 도구) 등 챕터 네비게이션 전용 MCP가 성숙했고, 영상 처리는 `yt-dlp-mcp`(490★) + `mcp-youtube-transcript`(369★) 조합이 표준화됐다. 단순 RAG 도구는 외부 vector DB에 청크를 올리고 유사도 검색만 하므로 "이 책 X챕터 Y섹션이 답을 준다"는 위치 인지가 불가능하지만, 본 카테고리에서 발굴된 도구들은 구조 파싱·통독·위치 고정 중 하나 이상을 갖춘다. DRLLM의 S2(Research Execution) BYOC 분기에 이 도구들을 chain하면, 사용자가 가져온 자료로부터 "이 챕터의 이 논리가 당신의 질문에 답한다"는 형태의 출처-위치 응답이 처음으로 가능해진다.

---

## Part 1: 자료 형식별 발견

---

### 1. MinerU-Document-Explorer (MCP)

**Score**: M2·A3·P5·F5·I3 = **18/25**
**URL**: https://github.com/OpenDataLab/MinerU-Document-Explorer
**Category**: F
**Type**: MCP Server + CLI
**자료 형식**: PDF / DOCX / PPTX / Markdown (Mixed)

#### TL;DR

MinerU-Document-Explorer는 MinerU 파싱 엔진 위에 구축된 에이전트 네이티브 지식 엔진으로, 15개 MCP 도구를 3그룹(Retrieve / Deep Read / Ingest)으로 제공한다. 단순 RAG와 결정적으로 다른 것은 Deep Read 그룹이다 — `doc-toc`으로 문서 목차를 조회하고, `doc-read`로 `"line:45-120"` 같은 주소 문법으로 특정 섹션만 읽고, `doc-grep`으로 문서 내 인라인 검색이 가능하다. 즉 에이전트가 전체 파일을 로드하지 않고도 "어느 챕터에 답이 있는지" TOC를 먼저 확인 후 정확한 섹션만 읽는 2단계 라우팅이 가능하다. Ingest 그룹은 Karpathy LLM Wiki 패턴을 따라 원문서로부터 인터링크된 마크다운 위키를 자동 생성하며, 이것이 장기 학습 컨텍스트 유지에 활용될 수 있다. 전체 100% 로컬 실행이며, 임베딩·리랭커 모델 총 ~1.9GB를 자동 다운로드한다. 2026-03-26 생성된 신생 프로젝트(242★, 23 커밋)라 성숙도는 아직 낮지만, DRLLM BYOC 파이프라인의 핵심 조각이 될 잠재력이 가장 높다.

#### Deep Review 메커니즘

- **통독 방식**: 전체 파일을 컨텍스트에 올리지 않음. TOC 조회 후 필요한 섹션만 line-range로 선택적 읽기 — 사실상 에이전트가 사람처럼 목차를 보고 해당 절을 펼치는 구조.
- **구조 매핑 방식**: MinerU 파싱 엔진이 PDF/DOCX/PPTX의 제목 계층·단락·표·수식을 인식하여 구조화 Markdown + JSON으로 변환. TOC는 이 계층 정보로부터 자동 추출됨.
- **질문 라우팅 방식**: 에이전트가 `doc-toc` → `doc-read(섹션)` → `doc-grep(키워드)` 체인으로 질문에 관련된 섹션을 특정. BM25 + 벡터 + LLM 리랭킹 하이브리드 검색도 지원.
- **RAG와의 차별 포인트**: chunk 단위가 아니라 문서 구조(섹션·절) 단위 접근. "X챕터 Y섹션" 위치 식별 가능. LLM Wiki 자동 생성으로 지식 지도화.

#### Found Tools / Capabilities

- `doc-toc`: 문서 목차(계층 구조) 조회
- `doc-read`: line-range 주소로 특정 섹션 읽기
- `doc-grep`: 문서 내 키워드 인라인 검색
- 하이브리드 검색 (BM25 + 벡터 + qwen3-reranker-0.6b + gemma-300M 임베딩)
- LLM Wiki Ingest: Karpathy 패턴 기반 위키 자동 생성
- 지원 형식: PDF, DOCX, PPTX, Markdown

#### License / Privacy

- 로컬 처리 가능: ✅ 100% 로컬 (PyMuPDF fallback 포함)
- 데이터 외부 송신: 스캔 PDF의 경우 MinerU Cloud API 선택적 사용 (기본 비활성화)
- 사용자 자료 안전성: ✅ 기본적으로 로컬 처리. 유료 콘텐츠 안전

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) BYOC 분기의 핵심 — TOC 확인 후 섹션 라우팅
- 영향받는 SP: SP-2 (출처 다양화 + BYOC 통합), 일부 SP-1 (스킬 분화 패턴 참고)
- 통합 난이도: I3 — Node.js ≥22 + Python ≥3.10 + SQLite 필요. MCP 표준 준수로 Claude/Cursor 연동은 단순하나 Gemini CLI Extension은 별도 어댑터 필요

#### Caveats / Risks

- 신생 프로젝트(2026-03-26 생성, 242★). 장기 유지보수 불확실
- 스캔 PDF는 클라우드 API 필요 (오프라인 fallback은 품질 저하)
- Gemini CLI 직접 연동 문서 없음 — MCP → Gemini Extension 변환 작업 필요
- Node.js ≥22 의존성은 일부 환경에서 충돌 가능

#### Recommendation

✅ **채택 (Phase 2 심화 후보)** — "TOC 조회 → 섹션 읽기" 2단계 라우팅은 DRLLM BYOC의 차별 기능을 구현하는 유일한 도구군. Gemini CLI 어댑터 개발이 Phase 2 과제.

---

### 2. Anthropic Claude Citations API + PDF Support (Pattern)

**Score**: M5·A5·P5·F5·I3 = **23/25**
**URL**: https://platform.claude.com/docs/en/build-with-claude/citations
**Category**: F
**Type**: Pattern (API Feature)
**자료 형식**: PDF / Plain Text / Custom Content

#### TL;DR

Anthropic의 Citations API는 2025년 1월 정식 출시된 기능으로, Claude가 문서에 응답할 때 답변의 각 클레임에 대해 정확한 출처 위치(PDF의 경우 페이지 번호, 텍스트의 경우 문자 인덱스)를 자동으로 첨부한다. 단순 RAG와 달리 "청크에서 찾은 텍스트"가 아니라 원문 어느 페이지, 어느 위치에서 이 내용이 나왔는지를 API 레벨에서 보장하며, Anthropic 내부 평가에서 순수 프롬프트 기반 citation보다 recall 정확도 15% 향상을 달성했다. PDF는 최대 600페이지(200K 토큰 모델은 100페이지), 전체를 컨텍스트에 올려 "통독 후 위치 고정" 방식으로 작동한다. DRLLM에서는 Claude API를 LLM 백엔드로 사용할 경우 즉시 사용 가능한 핵심 패턴으로, "이 책 X챕터 Y페이지가 답을 준다" 응답 형식의 기술적 토대가 된다. 비용 측면에서 `cited_text`는 출력 토큰 미산정이어서 효율적이며, Prompt Caching과 결합하면 반복 질문 비용이 대폭 감소한다.

#### Deep Review 메커니즘

- **통독 방식**: PDF 전체를 컨텍스트에 로드 (page-as-image + text 이중 처리). 600페이지까지 단일 요청 가능.
- **구조 매핑 방식**: 문서를 문장 단위로 자동 청킹. Custom Content 모드에서는 사용자 정의 블록 단위 사용 가능 (TOC 섹션별 분리 등).
- **질문 라우팅 방식**: LLM이 질문과 문서를 모두 컨텍스트에 보유한 채 답변 생성 → 각 클레임에 `page_location` 또는 `char_location` 자동 첨부.
- **RAG와의 차별 포인트**: 검색 단계 없음. 전체 통독 후 위치 반환. API가 인용 위치의 유효성을 보장 (phantom citation 불가).

#### Found Tools / Capabilities

- `citations.enabled: true` 플래그로 활성화
- 반환 형식: `page_location` (PDF, 1-indexed 페이지 범위), `char_location` (텍스트, 문자 인덱스), `content_block_location` (커스텀 블록 인덱스)
- Files API를 통한 반복 사용 PDF 사전 업로드 (재전송 오버헤드 제거)
- Prompt Caching과 결합 가능 (문서 캐시 후 다중 질문)
- Amazon Bedrock / Vertex AI에서도 사용 가능

#### License / Privacy

- 로컬 처리 가능: ❌ Anthropic API 필수 (클라우드)
- 데이터 외부 송신: ⚠️ PDF/텍스트가 Anthropic 서버로 전송됨
- 사용자 자료 안전성: Zero Data Retention (ZDR) 계약 시 응답 후 데이터 즉시 삭제. 기본 계약은 30일 보관 정책 확인 필요. 유료 콘텐츠 저작권 위험 별도 검토 필요.

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) BYOC 분기, S3 (LearnLM Prompt Synthesis)에서 출처 명시 응답 생성
- 영향받는 SP: SP-2 (BYOC 통합의 핵심 패턴), SP-1 (응답 스키마 설계)
- 통합 난이도: I3 — API 키 필요, `citations` 필드 파라미터 추가만으로 사용 가능. Gemini CLI Extension에서 Claude API 호출 패턴 필요.

#### Caveats / Risks

- 클라우드 의존 — 완전 로컬 운영 불가
- 스캔 PDF(이미지 전용)의 경우 이미지 citation 미지원 (텍스트 추출 불가 시 인용 불가)
- Structured Outputs와 동시 사용 불가 (API 제약)
- 토큰 비용: 600페이지 PDF ≒ ~900K 토큰 (많은 비용)

#### Recommendation

✅ **채택** — DRLLM의 Claude API 백엔드 경로에서 즉시 사용 가능한 최고 성숙도 패턴. 로컬 처리가 필요한 경우 MinerU-Document-Explorer와 조합.

---

### 3. Docling (IBM, MCP + Library)

**Score**: M4·A5·P5·F4·I4 = **22/25**
**URL**: https://github.com/docling-project/docling
**Category**: F
**Type**: Library + MCP Server
**자료 형식**: PDF / DOCX / PPTX / XLSX / HTML / 이미지 / LaTeX / 텍스트

#### TL;DR

Docling은 IBM Research Zurich에서 시작된 문서 변환 라이브러리로 57.6K★의 압도적 커뮤니티를 보유하며 v2.86.0 (2026-04)까지 165회 릴리즈를 거친 매우 성숙한 프로젝트다. 핵심 차별점은 PDF를 단순히 텍스트로 추출하는 게 아니라 "제목 계층 → 단락 → 표 → 수식 → 이미지" 계층 구조를 인식하여 DoclingDocument라는 통합 내부 표현으로 변환하고, 이를 Markdown/HTML/JSON 등으로 내보낸다는 점이다. TableFormer 모델이 복잡한 표 구조(멀티헤더, 중첩 셀)를 인식하고, GraniteDocling VLM이 차트/다이어그램을 설명 텍스트로 변환한다. MCP 서버도 제공하여 Claude Desktop, LM Studio와 바로 연동된다. LangChain, LlamaIndex, CrewAI, Haystack 플러그인도 준비되어 있다. DRLLM에서는 모든 BYOC 자료를 Docling으로 전처리하여 구조화 Markdown을 만든 후 LLM에게 제공하는 "전처리 레이어"로 사용하는 것이 가장 적합하다.

#### Deep Review 메커니즘

- **통독 방식**: 문서 전체를 한 번 파싱하여 계층 구조 인식. 페이지 레이아웃·읽기 순서·표 구조를 동시에 처리.
- **구조 매핑 방식**: DoclingDocument 포맷 — 제목 수준(H1~Hx), 단락, 표(행·열·헤더), 수식(LaTeX), 이미지(설명), 각주, 코드 블록을 계층 트리로 구성. 읽기 순서 자동 복원.
- **질문 라우팅 방식**: Docling 자체는 직접 라우팅 불가 — LlamaIndex/LangChain 플러그인과 결합하거나 MinerU-Explorer의 Deep Read와 연계해야 함.
- **RAG와의 차별 포인트**: 청킹 전 단계 — 의미 구조를 보존한 청크를 생성하는 전처리 기반. 구조 인식 없는 청크는 챕터 경계를 무시하나, Docling 기반 청크는 섹션 단위.

#### Found Tools / Capabilities

- MCP Server: Claude Desktop, LM Studio 연동 (`uvx docling-mcp-server`)
- LlamaIndex, LangChain, CrewAI, Haystack 플러그인
- REST API, Python SDK
- Markdown, HTML, WebVTT, DocTags, JSON 내보내기
- 109개 언어 지원, 스캔 문서 자동 감지
- 멀티쓰레드 병렬 처리

#### License / Privacy

- 로컬 처리 가능: ✅ 완전 로컬 (air-gapped 환경 지원 명시)
- 데이터 외부 송신: ❌ 없음 (로컬 모델 사용)
- 사용자 자료 안전성: ✅ 최우수. 유료 콘텐츠, 민감 자료 안전.

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) 전처리 레이어 — BYOC 자료를 구조화 Markdown으로 변환 후 LLM 투입
- 영향받는 SP: SP-2 (BYOC 통합), SP-1 (파이프라인 설계)
- 통합 난이도: I4 — MCP 표준 준수, `uvx` 단 명령어로 설치. Python/Node.js 의존성 없음.

#### Caveats / Risks

- TOC 라우팅 자체 기능 없음 — 변환 후 별도 라우팅 레이어 필요
- 스캔 PDF에서 수식 인식 품질은 GPU 필요
- MCP 도구 목록이 공개 문서에 구체적으로 명시되지 않음 (GitHub 세부 문서 필요)

#### Recommendation

✅ **채택** — 모든 BYOC 형식(PDF/DOCX/PPTX)의 구조 인식 전처리 레이어로 채택. MinerU-Explorer의 파싱 엔진 대안으로도 사용 가능.

---

### 4. MinerU (Document Parser, MCP Server 포함)

**Score**: M4·A5·P5·F4·I4 = **22/25**
**URL**: https://github.com/opendatalab/MinerU
**Category**: F
**Type**: Library + MCP Server
**자료 형식**: PDF / DOCX / PPTX / 이미지 / 웹페이지

#### TL;DR

MinerU는 59.4K★(2026-04 기준)의 최대 규모 문서 파싱 엔진으로, v3.0.0(2026-03-29)에서 대규모 개선이 이루어졌다. 세 가지 엔진 모드를 제공한다 — Pipeline(CPU 지원, 정확도 86.2점), VLM-engine(고정확도 90+), Hybrid-engine(네이티브 텍스트 추출, 낮은 환각). PDF의 수식을 LaTeX로, 표를 HTML로 변환하며 읽기 순서를 복원한다. MCP 서버가 내장되어 있어 Cursor, Claude Desktop과 직접 연동된다. 109개 언어 지원 및 멀티GPU/멀티쓰레드 처리로 대규모 문서 배치 처리에도 적합하다. Docling과 비교하면 MinerU는 더 강력한 레이아웃 복원과 수식 처리에 강점이 있으며 스타 수가 더 많다. DRLLM에서는 MinerU-Document-Explorer와 함께 "파싱 엔진 + 에이전트 탐색" 조합으로 사용하는 것이 자연스럽다.

#### Deep Review 메커니즘

- **통독 방식**: 전체 문서 한 번 파싱 — 멀티페이지 표 병합, 헤더/푸터 자동 제거, 스캔 문서 자동 감지.
- **구조 매핑 방식**: 제목·단락·표·수식·이미지 계층을 Markdown + JSON으로 출력. 읽기 순서 자동 복원.
- **질문 라우팅 방식**: MinerU 단독으로는 불가 — MinerU-Document-Explorer와 결합 시 TOC/섹션 라우팅 가능.
- **RAG와의 차별 포인트**: 구조 보존 파싱 → LLM-ready Markdown 생성. 단순 텍스트 덤프 대비 의미 계층 유지.

#### Found Tools / Capabilities

- MCP Server: Cursor, Claude Desktop 연동
- Python/Go/TypeScript SDK, REST API, Docker
- LangChain, LlamaIndex, Dify, FastGPT 통합
- 세 가지 엔진 모드 (Pipeline/VLM/Hybrid)
- 배치 처리, 멀티쓰레드 병렬화

#### License / Privacy

- 로컬 처리 가능: ✅ 완전 로컬
- 데이터 외부 송신: ❌ 없음
- 사용자 자료 안전성: ✅ 최우수.

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) 전처리 레이어
- 영향받는 SP: SP-2 (BYOC 통합)
- 통합 난이도: I4 — MCP 내장, pip install로 설치 간단

#### Caveats / Risks

- GPU 없이 VLM 모드 사용 불가 (CPU 모드는 정확도 저하)
- 스캔 문서의 수식 처리는 GPU 필요
- MinerU-Document-Explorer와 별개 — 함께 사용 시 버전 호환성 관리 필요

#### Recommendation

✅ **채택** — Docling과 함께 BYOC 전처리 레이어 이중화 전략. MinerU-Document-Explorer의 파싱 백엔드로 사용.

---

### 5. ebook-mcp (onebirdrocks)

**Score**: M3·A3·P3·F4·I4 = **17/25**
**URL**: https://github.com/onebirdrocks/ebook-mcp
**Category**: F
**Type**: MCP Server
**자료 형식**: EPUB / PDF

#### TL;DR

ebook-mcp는 EPUB과 PDF 파일을 MCP를 통해 LLM에게 제공하는 서버로 356★, 50 포크를 보유한 중간 성숙도 프로젝트다. EPUB의 경우 챕터 ID 기반으로 목차를 추출하고 챕터 단위 Markdown 콘텐츠를 반환하며, PDF는 내장 목차(TOC)가 있는 경우 챕터 단위 접근이 가능하다. 데모에서는 LLM을 이용한 퀴즈 생성, 설명 생성, 개인화 학습 피드백 등 교육적 활용을 보여준다 — 이는 DRLLM의 BYOC 교육 튜터 시나리오에 직접 부합한다. 단순 RAG보다 나은 점은 챕터 단위 구조 인식이지만, 목차 없는 PDF는 지원이 제한적이고 통독 수준의 깊이 분석은 부족하다. EPUB 형식에 특화된 가장 가벼운 MCP 옵션이다.

#### Deep Review 메커니즘

- **통독 방식**: 챕터 단위 선택적 읽기. EPUB은 챕터 ID 기반, PDF는 TOC 내장 필요.
- **구조 매핑 방식**: EPUB TOC 추출, PDF TOC 추출 (있는 경우만). 계층 구조는 EPUB에서 더 신뢰적.
- **질문 라우팅 방식**: 도구 수준에서는 미지원 — LLM이 먼저 TOC를 조회하여 어느 챕터를 읽을지 결정하는 패턴 필요.
- **RAG와의 차별 포인트**: 챕터 단위 구조 인식. 단 임베딩 검색 없이 챕터 직접 접근.

#### Found Tools / Capabilities

- EPUB: 메타데이터, TOC, 챕터 콘텐츠(Markdown)
- PDF: 메타데이터, TOC, 페이지/챕터 추출(텍스트/Markdown)
- 배치 파일 처리, 디렉토리 내 파일 탐색
- PyPI 패키지: `ebook-mcp`

#### License / Privacy

- 로컬 처리 가능: ✅ 완전 로컬
- 데이터 외부 송신: ❌ 없음
- 사용자 자료 안전성: ✅ 우수

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) BYOC 분기 — EPUB 특화 경로
- 영향받는 SP: SP-2 (BYOC 통합)
- 통합 난이도: I4 — `pip install ebook-mcp`, MCP 표준 준수

#### Caveats / Risks

- TOC 없는 PDF는 기능 제한 ("Some features may not work")
- 통독 깊이 분석 없음 — 챕터 텍스트 반환 후 LLM 분석 위임
- 활성도 낮음 (103 커밋, 마지막 커밋 날짜 불명확)

#### Recommendation

🔧 **카피·수정** — EPUB 전용 MCP 레이어로 채택. TOC-기반 라우팅 로직을 S2 스킬에서 구현 시 참고 패턴.

---

### 6. mcp-epub-reader (donghch)

**Score**: M2·A2·P4·F5·I4 = **17/25**
**URL**: https://glama.ai/mcp/servers/donghch/mcp-epub-reader
**Category**: F
**Type**: MCP Server
**자료 형식**: EPUB

#### TL;DR

mcp-epub-reader는 "AI 에이전트용 Kindle"이라는 컨셉으로 EPUB 파일에 대한 13개 MCP 도구를 제공하는 서버다. `ebook/get_toc`으로 계층적 목차(제목·중첩 레벨·페이지 번호·자식 요소)를 조회하고, `ebook/jump_to_chapter`로 제목 부분 일치 또는 인덱스로 챕터에 직접 점프하며, `ebook/get_chapter_summary`로 핵심 문장 추출 기반 챕터 요약을 얻을 수 있다. 세션 기반 페이지네이션으로 대용량 EPUB도 전체 로드 없이 상태 유지 탐색이 가능하다. F축(튜터 컨텍스트 적합성)이 높은 이유는 "이 챕터의 핵심은 무엇인가"를 도구 레벨에서 답할 수 있기 때문이다. 성숙도와 활성도는 낮지만 도구 설계 자체가 DRLLM BYOC에 가장 잘 맞는 EPUB 전용 MCP다.

#### Deep Review 메커니즘

- **통독 방식**: 세션 기반 상태 유지 탐색. `sessionId`로 큰 EPUB을 전체 로드 없이 탐색.
- **구조 매핑 방식**: `ebook/get_toc` — 계층적 TOC (제목, 중첩 레벨, 페이지 번호, 자식 요소 포함).
- **질문 라우팅 방식**: TOC 조회 → 챕터 점프 → 챕터 요약 → 전문 읽기의 4단계 에이전트 흐름이 도구 수준에서 완성됨.
- **RAG와의 차별 포인트**: 임베딩 없음, 챕터 구조 직접 탐색. 챕터 요약으로 "어느 챕터에 답이 있는지" 빠른 판단 가능.

#### Found Tools / Capabilities

- 13개 MCP 도구: open, close, list_open_books, navigate_next, navigate_previous, jump_to_page, jump_to_chapter, get_toc, get_metadata, get_position, search, get_footnote, get_chapter_summary
- 부분 일치 챕터 제목 검색 (대소문자 무관)
- 전체 텍스트 검색 (컨텍스트 윈도우 50단어 설정 가능)
- 각주 해석 도구

#### License / Privacy

- 로컬 처리 가능: ✅ 완전 로컬
- 데이터 외부 송신: ❌ 없음
- 사용자 자료 안전성: ✅ 우수

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) BYOC EPUB 경로
- 영향받는 SP: SP-2 (BYOC 통합)
- 통합 난이도: I4 — MCP 표준 준수

#### Caveats / Risks

- 성숙도 낮음 (신생 프로젝트, 스타 수 미확인)
- EPUB 전용 — PDF 미지원
- `get_chapter_summary`는 키 문장 추출 방식 (LLM 기반 아님) — 품질 제한

#### Recommendation

🔧 **카피·수정** — 13개 도구 설계 패턴은 DRLLM BYOC EPUB 레이어 구현 시 그대로 참고 가능. 특히 TOC+챕터점프+요약 3조합이 핵심.

---

### 7. yt-dlp-mcp + mcp-youtube-transcript (Video Pipeline)

**Score (조합)**: M3·A4·P3·F4·I4 = **18/25**
**URL 1**: https://github.com/kevinwatt/yt-dlp-mcp
**URL 2**: https://github.com/jkawamoto/mcp-youtube-transcript
**Category**: F
**Type**: MCP Server (조합)
**자료 형식**: YouTube 영상 / 강의 비디오

#### TL;DR

YouTube 영상 처리에는 두 도구의 조합이 현재 생태계에서 가장 완성도가 높다. `yt-dlp-mcp`(kevinwatt, 228★)는 yt-dlp 기반으로 영상 메타데이터·자막·트랜스크립트·오디오 다운로드를 MCP 도구 9개로 제공한다. `mcp-youtube-transcript`(jkawamoto, 369★, 215 커밋, v0.6.1 2026-04-09 최신)는 시간 정보 포함 트랜스크립트, 50,000자 초과 시 페이지네이션, 26개 릴리즈의 안정성을 갖춘다. 두 도구 모두 챕터 감지는 지원하지 않으나, 트랜스크립트를 얻은 후 Gemini/Claude의 장문 컨텍스트에 올려 "이 강의에서 X개념이 몇 분대에 등장하고 어떤 논리로 설명되는가"를 물을 수 있다 — 이것이 단순 RAG 대비 차별점이다. yt-transcript(kiuckhuang)는 yt-dlp + Whisper + Ollama 완전 로컬 파이프라인을 제공하지만 인지도가 거의 없는 초기 프로젝트다.

#### Deep Review 메커니즘

- **통독 방식**: 트랜스크립트 전체를 LLM 컨텍스트에 올림 (장문 LLM 필요). 50K자 초과 시 페이지네이션.
- **구조 매핑 방식**: 타임스탬프 기반 VTT 형식 자막 — 구조 매핑은 없음. YouTube 챕터가 있는 영상은 챕터 메타데이터 조회 가능.
- **질문 라우팅 방식**: 트랜스크립트 전체를 컨텍스트에 올린 후 LLM에게 "이 내용이 어느 시간대에 나왔는가" 질문 → 타임스탬프 포함 응답.
- **RAG와의 차별 포인트**: 청킹 없이 전체 트랜스크립트 통독. 타임스탬프를 위치 식별자로 사용.

#### Found Tools / Capabilities

- `yt-dlp-mcp`: ytdlp_search, ytdlp_get_video_metadata, ytdlp_download_transcript, ytdlp_list_subtitle_languages, ytdlp_download_audio 등 9개 도구
- `mcp-youtube-transcript`: get_transcript, get_timed_transcript, get_video_info, get_available_languages
- 다국어 지원, proxy 설정 지원
- 로컬 처리 (yt-dlp 로컬 실행)

#### License / Privacy

- 로컬 처리 가능: ✅ 트랜스크립트 다운로드 및 오디오 처리 로컬
- 데이터 외부 송신: YouTube API 접근 필요 (YouTube 서버). 트랜스크립트 자체는 로컬 저장.
- 사용자 자료 안전성: ✅ 다운로드 후 로컬 처리. 단, YouTube ToS 확인 필요.

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) BYOC 영상 경로
- 영향받는 SP: SP-2 (BYOC 통합)
- 통합 난이도: I4 — pip install, MCP 표준 준수

#### Caveats / Risks

- 챕터 자동 감지 없음 — 영상 챕터 메타데이터가 있는 경우에만 구조화 가능
- YouTube ToS: 자막 다운로드는 허용, 영상 다운로드는 저작권 확인 필요
- 유료/비공개 영상 처리 불가
- 50K자 이상 강의 트랜스크립트는 LLM 컨텍스트 한계 고려 필요

#### Recommendation

✅ **채택** — YouTube 강의 트랜스크립트 처리의 표준 MCP 조합. 챕터 구조는 LLM에게 위임하는 패턴으로 사용.

---

### 8. open-notebook (lfnovo, NotebookLM OSS Clone)

**Score**: M3·A4·P3·F4·I2 = **16/25**
**URL**: https://github.com/lfnovo/open-notebook
**Category**: F
**Type**: Application (Library + Frontend)
**자료 형식**: PDF / 비디오 / 오디오 / 웹페이지 / Office 문서 (Mixed)

#### TL;DR

open-notebook은 22.1K★, 2.5K 포크의 가장 인기 있는 NotebookLM OSS 클론으로, Python FastAPI + Next.js + SurrealDB 아키텍처로 완전 자체 호스팅이 가능하다. 18개+ AI 프로바이더(Ollama 포함 로컬 LLM)를 지원하며, 팟캐스트 자동 생성, 멀티 노트북 조직화, 소스 인용 기능을 갖는다. 단순 RAG 대비 강점은 "콘텐츠 변환" 파이프라인 — 업로드 문서로부터 요약·인사이트·팟캐스트를 자동 생성하는 것이다. 다만 NotebookLM 수준의 세밀한 소스 인용(페이지/섹션 위치)은 아직 "basic references (will improve)"로 표시되어 있어 Deep Review 메커니즘은 미성숙하다. DRLLM에서 직접 사용하기보다는 NotebookLM 패턴의 참고 모델로 사용하고, 핵심 인사이트(소스-그라운딩 + 멀티-노트북)를 S2/S3 설계에 반영하는 것이 적합하다.

#### Deep Review 메커니즘

- **통독 방식**: 멀티-소스 업로드 후 벡터+전문 검색으로 컨텍스트 구성.
- **구조 매핑 방식**: 형식별 핸들러를 통한 시맨틱 임베딩. 명시적 챕터/섹션 구조 인식은 없음.
- **질문 라우팅 방식**: 벡터 유사도 + BM25 혼합. 정확한 소스 위치(페이지/섹션) 반환은 불완전.
- **RAG와의 차별 포인트**: 멀티-모달 입력, 팟캐스트 생성, 노트북 단위 컨텍스트 격리.

#### Found Tools / Capabilities

- REST API, 18+ LLM 프로바이더
- 팟캐스트 자동 생성 (1~4 스피커)
- 멀티 노트북 조직화
- 소스 인용 (기본 수준)
- Docker Compose 단일 명령 배포

#### License / Privacy

- 로컬 처리 가능: ✅ Ollama + 자체 호스팅으로 완전 로컬 가능
- 데이터 외부 송신: 선택적 (Ollama 로컬 시 없음)
- 사용자 자료 안전성: ✅ 자체 호스팅 시 우수

#### DRLLM Fit Analysis

- 매핑 스킬: 직접 매핑 어려움 — 패턴 참고용
- 영향받는 SP: SP-2 (BYOC 통합 패턴 참고), SP-3 (end-to-end 검증)
- 통합 난이도: I2 — 독립 서비스로 DRLLM Extension에 통합하기 복잡

#### Caveats / Risks

- 소스 위치 인용 미완성 ("basic references")
- 독립 서비스 형태 — MCP/Extension 직접 통합 어려움
- 116개 오픈 이슈

#### Recommendation

🔧 **카피·수정** — 직접 채택보다 NotebookLM 패턴 학습용. 소스-그라운딩과 노트북 격리 패턴을 S2 설계에 추출 적용.

---

### 9. Gemini Long-Context PDF Pattern (Pattern)

**Score**: M4·A5·P4·F4·I4 = **21/25**
**URL**: https://ai.google.dev/gemini-api/docs/document-processing
**Category**: F
**Type**: Pattern (API Feature)
**자료 형식**: PDF / 이미지 (최대 1000페이지 / 50MB)

#### TL;DR

Gemini 2.0 Flash의 1M 토큰 컨텍스트를 활용하면 수백 페이지 PDF를 통째로 올려 질문할 수 있다. 전통적 RAG 파이프라인 없이 "PDF를 통으로 올리고 질문"하는 것이 기술적으로 가능해진 것이다. 공식 문서에 따르면 각 페이지는 약 258 토큰 처리되며, 레이아웃·이미지·차트·표를 native vision으로 이해한다. 구조적 제약은 있다 — Gemini는 문서 구조(TOC, 챕터 경계)를 자동으로 반환하지 않고, 인용도 직접적 위치 반환이 아닌 시스템 프롬프트 지시에 의존한다. DRLLM에서는 Gemini CLI Extension의 네이티브 LLM이므로, 작은 문서(100페이지 이하)는 Gemini에 직접 PDF를 올려 통독 질문하는 가장 단순한 BYOC 경로가 가능하다. 대형 문서는 Docling/MinerU로 전처리 후 Gemini에 구조화 Markdown을 투입하는 패턴이 더 효율적이다.

#### Deep Review 메커니즘

- **통독 방식**: 1M 토큰 컨텍스트에 PDF 전체 로드 (1000페이지 한도). Native vision으로 이미지·표·차트 처리.
- **구조 매핑 방식**: 자동 구조 출력 없음. LLM이 프롬프트 지시에 따라 TOC 추출, 섹션 분류 가능.
- **질문 라우팅 방식**: 전체 문서가 컨텍스트에 있으므로 "이 내용이 어느 섹션에 있는지"는 LLM이 자연어로 답함. 공식 위치 인덱스 반환은 없음.
- **RAG와의 차별 포인트**: 검색 단계 완전 제거 — 문서 전체가 컨텍스트. 단, 위치 인덱스 미반환.

#### Found Tools / Capabilities

- `Part.from_data(mime_type="application/pdf")` — PDF를 직접 파트로 투입
- 멀티 문서 요청 (`"Document 1: filename"` 레이블)
- 구조화 출력 (JSON schema 설정)
- Context Caching (`CachedContent.create()`) — 동일 PDF 반복 질문 비용 절감
- Stateful chat session으로 대화형 문서 탐색

#### License / Privacy

- 로컬 처리 가능: ❌ Google API 필수
- 데이터 외부 송신: ⚠️ PDF가 Google 서버로 전송
- 사용자 자료 안전성: Google API 정책에 따름. 유료 콘텐츠 저작권 검토 필요.

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) BYOC 분기 — Gemini 네이티브 경로
- 영향받는 SP: SP-2 (BYOC 통합), SP-3 (Gemini CLI 검증)
- 통합 난이도: I4 — Gemini CLI의 네이티브 LLM이므로 가장 쉬운 통합 경로

#### Caveats / Risks

- 클라우드 의존 — 유료 콘텐츠 개인정보 위험
- 공식 위치 인덱스(페이지 번호) 반환 없음 — "X페이지에 있다" 보장 불가
- 1000페이지 한도 (50MB)
- 비용: 1페이지 ≒ 258 토큰. 300페이지 책 ≒ ~77K 토큰/질문

#### Recommendation

✅ **채택** — Gemini CLI Extension의 기본 BYOC 경로로 사용. 소형 문서(~100p)에 적합. 대형 문서는 Docling 전처리 후 사용.

---

### 10. LightRAG (구조 매핑 부분만)

**Score**: M4·A5·P3·F3·I3 = **18/25**
**URL**: https://github.com/HKUDS/LightRAG
**Category**: F
**Type**: Library (RAG 프레임워크 — 구조화 부분만 참고)
**자료 형식**: 텍스트 문서 (PDF 전처리 후)

#### TL;DR

LightRAG는 33,000★의 EMNLP 2025 발표 논문 기반 RAG 프레임워크로, 단순 벡터 검색 대비 지식 그래프 구조를 추가한다. 문서 인제스트 시 LLM이 엔티티·관계를 추출하여 경량 지식 그래프를 자동 구성하고, 쿼리 시 "low-level(구체 사실)" + "high-level(개념 관계)" 이중 레벨 검색을 제공한다. DRLLM 관점에서 순수 RAG 도구로 채택하기보다는 "지식 그래프 구조화" 패턴을 BYOC 파이프라인에 차용하는 것이 가치 있다 — 예를 들어 책 전체를 인제스트한 후 LightRAG의 엔티티 그래프를 "책의 지식 지도"로 사용하는 패턴. 기본 RAG 대비 쿼리 지연 ~30% 단축, 업데이트 ~50% 단축. 완전 로컬 배포 가능.

#### Deep Review 메커니즘

- **통독 방식**: 문서 전체 인제스트 → 청크별 엔티티·관계 추출 → 그래프 구성 (통독에 가깝지만 일회성 인제스트).
- **구조 매핑 방식**: LLM 기반 엔티티·관계 자동 추출 → 지식 그래프. 중복 엔티티 병합. 이것이 "책의 개념 지도" 역할.
- **질문 라우팅 방식**: 쿼리 → 그래프 내 관련 엔티티 + 벡터 검색 이중 경로 → 컨텍스트 조합.
- **RAG와의 차별 포인트**: 청크 유사도만이 아닌 개념 관계 그래프 탐색. 단, 위치 정보(챕터/페이지)는 반환하지 않음.

#### Found Tools / Capabilities

- Python 라이브러리
- LLM 백엔드 자유 선택 (OpenAI, Ollama 등)
- Docker 로컬 배포
- OpenSearch 통합 (2026-03 추가)
- 증분 업데이트 지원

#### License / Privacy

- 로컬 처리 가능: ✅ Docker + Ollama로 완전 로컬
- 데이터 외부 송신: ❌ 없음
- 사용자 자료 안전성: ✅ 우수

#### DRLLM Fit Analysis

- 매핑 스킬: S2 (Research Execution) 고급 인덱싱 레이어 (선택적)
- 영향받는 SP: SP-2 (BYOC 통합 심화)
- 통합 난이도: I3 — 단독으로는 단순하나 기존 파이프라인과 통합 시 복잡도 증가

#### Caveats / Risks

- 인제스트 시 LLM 토큰 비용 큼 (엔티티 추출 반복 호출)
- 챕터/페이지 위치 정보 반환 없음 — "X챕터" 위치 식별 불가
- 순수 RAG 프레임워크이므로 채택 시 "구조화 인덱싱" 부분만 분리해야 함
- DRLLM 메인 파이프라인에 포함하면 복잡도 과도 증가

#### Recommendation

❌ **기각** (Phase 2 관심 항목) — 단순 RAG의 개선판이지 "통독 → 위치 고정" 패턴이 아님. 단, 엔티티 그래프 기반 "개념 지도" 패턴은 Phase 2에서 심화 검토 가치 있음.

---

## Part 2: 자료 형식 커버리지 매트릭스

| 형식 | 발견된 도구 수 | Top 추천 | 격차 |
|------|--------------|----------|------|
| PDF | 6 (Docling, MinerU, MinerU-Explorer, Claude Citations, Gemini Pattern, MinerU MCP) | Claude Citations API + Docling 조합 | 완전 로컬 + 위치 고정의 조합이 한 도구에 없음 |
| EPUB | 2 (ebook-mcp, mcp-epub-reader) | mcp-epub-reader (13개 도구) | 통독 수준 분석 미비. Whisper 없이 오디오북 처리 불가 |
| YouTube transcript | 3 (yt-dlp-mcp, mcp-youtube-transcript, yt-transcript) | yt-dlp-mcp + mcp-youtube-transcript 조합 | 챕터 자동 감지 없음. 강의 영상 구조 인식 불가 |
| Lecture slides (PPTX) | 2 (Docling, MinerU) | Docling (PPTX 지원, 구조 인식) | PPTX 전용 MCP 없음. 슬라이드-챕터 매핑 수동 |
| 일반 텍스트 (논문/포스트) | 4 (Claude Citations, Gemini Pattern, Docling, MinerU) | Claude Citations API (문장 단위 인용) | 논문 수식/그림 위치 인용 미지원 |

---

## Part 3: NotebookLM 패턴 분석

### NotebookLM의 핵심 차별점

Google NotebookLM은 Gemini 2.0 Flash의 2M 토큰 컨텍스트 위에서 동작하며, 세 가지 차별 메커니즘으로 DRLLM의 벤치마크가 된다.

**1. 소스 그라운딩 (Source Grounding)**

모든 응답은 업로드된 소스에서만 생성된다 — 인터넷 검색 없음, LLM 사전 지식 없음. 각 응답에 인라인 인용 칩이 포함되고, 클릭하면 소스 뷰어가 해당 단락으로 스크롤된다. 이것이 "이 책 어디에서 답이 왔는지" 명시의 가장 직접적 구현이다.

**2. 멀티-소스 동시 처리**

하나의 노트북에 PDF, 웹페이지, YouTube 영상, Google Docs 등 여러 소스를 올리고 "어느 소스의 어느 부분이 관련 있는지"를 LLM이 판단한다. DRLLM의 BYOC 파이프라인이 도달해야 할 목표 수준.

**3. 팟캐스트/오디오 오버뷰 (Audio Overview)**

소스를 2인 토론 팟캐스트로 자동 변환 — 이것은 S3 (LearnLM Prompt Synthesis)의 "강의 형식 변환"과 개념적으로 유사하며, open-notebook의 팟캐스트 생성이 클론을 시도하고 있다.

### DRLLM에서의 적용 방향

NotebookLM 패턴을 완전 오픈소스로 구현하려면 세 레이어가 필요하다:

1. **파싱 레이어**: Docling 또는 MinerU → 구조화 문서 생성
2. **통독 레이어**: Claude Citations API (클라우드) 또는 Gemini PDF 직접 (Gemini CLI 네이티브) → 소스 위치 고정
3. **탐색 레이어**: MinerU-Document-Explorer (로컬) → TOC 조회 + 섹션 라우팅

NotebookLM의 한 가지 한계를 DRLLM이 극복할 수 있는 지점: NotebookLM은 사용자가 직접 소스를 업로드해야 하지만, DRLLM의 S2는 연구 실행 중에 BYOC 소스를 동적으로 분석 계획에 통합할 수 있다.

---

## 카테고리 종합 권장

### Top-3 도구/패턴

| 순위 | 이름 | 점수 | 1줄 이유 |
|------|------|------|----------|
| 1 | **Anthropic Claude Citations API** | 23/25 | 페이지 단위 위치 보장 + 즉시 사용 가능. DRLLM의 "어디서 답이 오는지" 명시의 기술적 토대 |
| 2 | **Docling (IBM)** | 22/25 | 57.6K★ 성숙도, 완전 로컬, 모든 BYOC 형식(PDF/DOCX/PPTX)의 구조 인식 전처리 레이어 |
| 3 | **MinerU-Document-Explorer** | 18/25 | TOC 조회 → 섹션 읽기 2단계 라우팅이 가능한 유일한 완전 로컬 MCP — DRLLM의 에이전트 BYOC 탐색 패턴 구현 |

### DRLLM BYOC 파이프라인 권장 조합

**PDF 경로 (권장 조합 A — 로컬 우선)**
```
사용자 PDF 입력
  → Docling/MinerU (구조 파싱, 로컬)
  → MinerU-Document-Explorer (TOC 조회 → 섹션 라우팅, 로컬 MCP)
  → Gemini CLI (구조화 Markdown + 섹션 컨텍스트로 응답)
  → 출력: "이 책 3장 2절에서 다음 논리로 답이 나옵니다"
```

**PDF 경로 (권장 조합 B — 클라우드, 최고 품질)**
```
사용자 PDF 입력
  → Claude Citations API (전체 통독 + 페이지 단위 인용)
  → 출력: "p.47 (Chapter 3.2)에 따르면..."
```

**EPUB 경로**
```
사용자 EPUB 입력
  → mcp-epub-reader (TOC + 챕터 점프 + 챕터 요약)
  → Gemini CLI (챕터 내용 + 질문 응답)
  → 출력: "챕터 5 '고급 포트 스캐닝'에서 이 논리가 설명됩니다"
```

**YouTube/강의 영상 경로**
```
YouTube URL 입력
  → yt-dlp-mcp + mcp-youtube-transcript (트랜스크립트 + 타임스탬프)
  → Gemini CLI (트랜스크립트 전체 컨텍스트 + 질문 응답)
  → 출력: "이 내용은 영상 32:15~38:40 구간에서 설명됩니다"
```

**PPTX/강의 슬라이드 경로**
```
슬라이드 파일 입력
  → Docling (구조 인식 + Markdown 변환)
  → Gemini CLI (슬라이드 구조화 Markdown + 질문)
  → 출력: "슬라이드 12-15 (세션 3: 네트워크 스캐닝)에서 이 개념이 다루어집니다"
```

### 단순 RAG와 명확히 다른 도구만 채택 확인

- ✅ Claude Citations API — 위치 보장 통독
- ✅ Docling / MinerU — 구조 인식 전처리 (청크 이전 단계)
- ✅ MinerU-Document-Explorer — TOC+섹션 에이전트 라우팅
- ✅ mcp-epub-reader / ebook-mcp — 챕터 구조 직접 탐색
- ✅ yt-dlp-mcp + mcp-youtube-transcript — 타임스탬프 위치 식별
- ✅ Gemini Long-Context Pattern — 검색 단계 제거, 전체 통독

### 기각 리스트

| 도구 | 기각 이유 |
|------|----------|
| LightRAG | 청크 벡터 검색의 개선판. 위치 반환(챕터/페이지) 없음. 복잡도 추가 대비 DRLLM 가치 낮음 |
| 일반 RAG 프레임워크 (LangChain, LlamaIndex 직접 사용) | Top-k chunk retrieval 패턴 — 구조 인식 없음. 전처리로만 활용 |
| yt-transcript (kiuckhuang) | 0★, 완성도 미달. yt-dlp-mcp+mcp-youtube-transcript 조합이 대체 |
| PDF2Audio / NotebookLlaMa (run-llama) | 오디오 생성 특화 — DRLLM 튜터 응답 패턴과 부합하지 않음 |
| open-notebook | 소스 인용 미완성. 독립 서비스로 DRLLM Extension 통합 복잡 |

### Phase 2 심화 후보

1. **MinerU-Document-Explorer** — 15개 MCP 도구 상세 코드 분석, Gemini CLI Extension 어댑터 개발 방법, "TOC→섹션→위키" 3단계 DRLLM 통합 설계
2. **Claude Citations API + Docling 조합 패턴** — BYOC 파이프라인 실제 구현 코드, 비용 최적화 (Prompt Caching + 배치), 로컬 대안 (Claude 없이 동일 패턴 구현 가능성)
3. **Gemini Long-Context PDF Pattern** — Gemini CLI Extension에서 PDF 직접 처리 구현 방법, Context Caching 비용 최적화, 위치 정보 프롬프트 패턴 개발

---

*보고서 생성일: 2026-04-12*
*참고 URL 목록: GitHub 각 항목 URL 및 공식 문서는 본문 내 명시됨*
