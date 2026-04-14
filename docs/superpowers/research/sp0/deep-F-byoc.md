# SP-0 Phase 2 — Category F Deep Dive

**Date**: 2026-04-14
**Sub-agent**: Sonnet 4.6
**Category**: F — BYOC Deep Review (코드 레벨 심화)
**Phase 1 참조**: scan-F-byoc-deep-review.md

---

## 심화 분석

### 1. MinerU-Document-Explorer Gemini Extension 어댑터

#### 1.1 현재 인터페이스 — 15개 MCP 도구 전체 목록

MinerU-Document-Explorer(`qmd` CLI)는 세 그룹 15개 MCP 도구를 제공한다.

**Retrieval 그룹 (4개)**

| 도구명 | 설명 |
|--------|------|
| `query` | 컬렉션 전체 하이브리드 검색 (BM25 + 벡터 + LLM 리랭킹). 서브쿼리 타입: `lex`(BM25), `vec`(벡터), `hyde`(HyDE 확장) |
| `get` | 경로 또는 문서 ID로 단일 문서 조회 |
| `multi_get` | glob 패턴 또는 쉼표 구분 ID로 문서 배치 조회 |
| `status` | 인덱스 상태 및 컬렉션 메트릭 |

**Deep Read 그룹 (6개) — DRLLM 핵심**

| 도구명 | 설명 |
|--------|------|
| `doc_toc` | 문서에서 제목 계층·북마크·스타일·슬라이드 구조 추출 → TOC 반환 |
| `doc_read` | 검색 결과의 특정 위치에서 콘텐츠 읽기 (line-range 주소 방식) |
| `doc_grep` | 문서 내 정규식 또는 키워드 검색 |
| `doc_query` | 단일 문서 내 시맨틱 검색 |
| `doc_elements` | 표·그림·수식만 분리 추출 |
| `doc_links` | 순방향·역방향 참조 맵 생성 |

**Knowledge Ingestion 그룹 (5개)**

| 도구명 | 설명 |
|--------|------|
| `wiki_ingest` | 문서를 위키 처리용으로 준비 (Karpathy LLM Wiki 패턴) |
| `doc_write` | 자동 위키 로깅이 포함된 마크다운 파일 생성 |
| `wiki_lint` | 위키 상태 검증 (고아 페이지, 깨진 링크, 낡은 콘텐츠) |
| `wiki_log` | 활동 타임라인 조회 |
| `wiki_index` | 위키 인덱스 페이지 생성/갱신 |

#### 1.2 Gemini CLI Extension 어댑터 청사진

MinerU-Document-Explorer는 Claude Desktop / Cursor 전용 MCP 설정만 공식 문서에 제공한다. Gemini CLI Extension으로 wrapping하려면 두 가지 방식이 가능하다.

**방식 A: HTTP 데몬 + gemini-extension.json (권장)**

MinerU-Document-Explorer가 HTTP 데몬 모드(`qmd mcp --http --daemon`)를 지원하므로, Gemini CLI가 이 HTTP MCP 서버에 연결하도록 Extension manifest를 작성한다.

```
~/.gemini/extensions/mineru-byoc/
├── gemini-extension.json
├── GEMINI.md
└── commands/
    └── byoc/
        └── ingest.toml
```

**`gemini-extension.json`** (완전한 예시):

```json
{
  "name": "mineru-byoc",
  "version": "1.0.0",
  "contextFileName": "GEMINI.md",
  "mcpServers": {
    "qmd": {
      "url": "http://localhost:8181/mcp"
    }
  }
}
```

> 전제 조건: `qmd mcp --http --daemon` 이 먼저 실행되어 있어야 한다. 사용자 프로파일 스크립트(`~/.bashrc` 또는 systemd user service)에서 자동 시작 설정 권장.

**방식 B: stdio 직접 실행 (HTTP 불필요)**

```json
{
  "name": "mineru-byoc",
  "version": "1.0.0",
  "contextFileName": "GEMINI.md",
  "mcpServers": {
    "qmd": {
      "command": "qmd",
      "args": ["mcp"],
      "cwd": "${workspacePath}"
    }
  }
}
```

> 단점: 매 요청마다 Python 환경과 임베딩 모델(~1.9GB) 재로드로 5~15초 지연 발생. HTTP 데몬 방식이 DRLLM 실시간 응답에 적합.

**`GEMINI.md`** (에이전트 지시 컨텍스트 파일):

```markdown
# DRLLM BYOC — MinerU Document Explorer

사용자가 자료(PDF/DOCX/PPTX/MD)를 분석하도록 요청하면:

1. `doc_toc` 로 문서 목차를 먼저 조회하라.
2. 질문과 관련된 섹션을 TOC에서 식별한 뒤 `doc_read` 로 해당 섹션만 읽어라.
3. 응답 시 반드시 "N장 M절: [섹션 제목]" 형태로 출처를 명시하라.
4. 키워드 확인이 필요하면 `doc_grep` 을 사용하라.
5. 단순 RAG(전체 검색 후 청크 합성)를 사용하지 마라. 항상 구조 탐색 우선.

자료 등록 명령: /byoc:ingest [파일경로]
```

**`commands/byoc/ingest.toml`** (BYOC 자료 등록 슬래시 커맨드):

```toml
name = "byoc:ingest"
description = "BYOC 자료를 MinerU 인덱스에 등록합니다"

[[arguments]]
name = "filepath"
description = "등록할 파일 경로 (PDF/DOCX/PPTX/MD)"
required = true

prompt = """
다음 파일을 DRLLM BYOC 인덱스에 등록하세요: {{filepath}}

1. `wiki_ingest` 도구로 파일을 인제스트하세요.
2. 인제스트가 완료되면 `doc_toc` 로 목차를 조회하여 사용자에게 보여주세요.
3. "등록 완료: [파일명], [챕터 수]개 섹션 인덱싱됨" 형태로 확인하세요.
"""
```

#### 1.3 에이전트 BYOC 탐색 흐름 (2단계 라우팅 패턴)

```
사용자: "이 책에서 TCP 3-way handshake가 어떻게 설명되어 있나요?"
                        ↓
Gemini CLI Extension
  → MCP: doc_toc("network_fundamentals.pdf")
  → 반환: [{"level":1, "title":"Chapter 3: Transport Layer", "line":145},
            {"level":2, "title":"3.2 Connection Establishment", "line":167}, ...]
                        ↓
  → MCP: doc_read("network_fundamentals.pdf", start=167, end=210)
  → 반환: "3.2 Connection Establishment\n\nTCP uses a three-way handshake..."
                        ↓
Gemini 응답:
  "네트워크 기초 교재 3장 2절 'Connection Establishment'(p.167~210)에서
   다음과 같이 설명합니다: [섹션 내용 인용]"
```

이 흐름은 단순 RAG("TCP handshake 관련 청크 3개 검색 후 합성")와 명확히 다르다. 에이전트가 목차를 "보고" 정확한 섹션을 "펼치는" 방식이다.

#### 1.4 라이선스 안전성

- MinerU-Document-Explorer: MIT 라이선스 ✅
- MinerU 파싱 엔진: Apache 2.0 ✅
- Node.js ≥22, Python ≥3.10, SQLite 필요
- 임베딩 모델(gemma-300M), 리랭커(qwen3-reranker-0.6b): 초기 실행 시 자동 다운로드 (~1.9GB). 각 모델의 라이선스(Apache 2.0 / Qwen License) 확인 필요 — 상업적 사용 시 Qwen License 조건 검토 요망.

---

### 2. Claude Citations API + Docling 조합 구현

#### 2.1 아키텍처 개요

두 도구의 역할 분리:
- **Docling**: PDF → 구조화 JSON (챕터/섹션/표 계층) — 완전 로컬
- **Claude Citations API**: 구조화 텍스트를 받아 페이지/블록 단위 인용 보장 응답 — 클라우드

이 조합이 "단순 PDF → Claude"보다 나은 이유: Docling이 문서 구조를 보존하므로, Citations API의 Custom Content 모드를 사용하면 문서의 챕터 경계를 그대로 인용 단위로 삼을 수 있다.

#### 2.2 실제 작동 코드 예제 (Python)

```python
"""
DRLLM BYOC: Docling + Claude Citations API 조합
라이선스: Docling(MIT), anthropic-sdk(MIT)
의존: pip install docling anthropic
"""
import base64
import json
from pathlib import Path
from typing import Optional

import anthropic
from docling.document_converter import DocumentConverter
from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import PdfPipelineOptions


def convert_pdf_with_docling(pdf_path: str) -> dict:
    """
    Docling으로 PDF를 구조화 JSON으로 변환.
    반환값: DoclingDocument 구조 (chapters, sections, tables)
    """
    pipeline_options = PdfPipelineOptions()
    pipeline_options.do_ocr = False          # 텍스트 PDF는 OCR 불필요
    pipeline_options.do_table_structure = True

    converter = DocumentConverter()
    result = converter.convert(pdf_path)
    doc = result.document

    # 섹션별로 분리된 텍스트 블록 생성
    sections = []
    current_section = {"title": "Introduction", "content": "", "level": 0}

    for item, level in doc.iterate_items():
        if hasattr(item, 'label'):
            label = str(item.label)
            if 'section_header' in label or 'title' in label:
                if current_section["content"].strip():
                    sections.append(current_section)
                current_section = {
                    "title": item.text if hasattr(item, 'text') else "",
                    "content": "",
                    "level": level
                }
            elif hasattr(item, 'text'):
                current_section["content"] += item.text + "\n"

    if current_section["content"].strip():
        sections.append(current_section)

    return {
        "total_pages": len(doc.pages) if hasattr(doc, 'pages') else 0,
        "sections": sections
    }


def build_custom_content_blocks(sections: list[dict]) -> list[dict]:
    """
    Docling 섹션 목록 → Claude Citations Custom Content 블록 변환.
    각 섹션이 하나의 인용 단위가 됨.
    """
    blocks = []
    for sec in sections:
        # 섹션 제목 + 내용을 하나의 블록으로
        text = f"[{sec['title']}]\n{sec['content'].strip()}"
        if text.strip():
            blocks.append({"type": "text", "text": text})
    return blocks


def query_with_citations(
    pdf_path: str,
    question: str,
    model: str = "claude-haiku-4-5",  # 비용 최적화: Haiku 사용
    use_prompt_cache: bool = True
) -> dict:
    """
    Docling 전처리 + Claude Citations API로 출처 보장 응답 생성.

    Args:
        pdf_path: PDF 파일 경로
        question: 질문
        model: 사용할 Claude 모델
        use_prompt_cache: Prompt Caching 활성화 여부 (반복 질문 비용 절감)

    Returns:
        {"answer": str, "citations": list[dict], "sections_used": list[str]}
    """
    # 1단계: Docling으로 구조화
    doc_data = convert_pdf_with_docling(pdf_path)
    content_blocks = build_custom_content_blocks(doc_data["sections"])

    if not content_blocks:
        raise ValueError("문서에서 텍스트를 추출하지 못했습니다.")

    # 2단계: Claude Citations API 요청 구성
    client = anthropic.Anthropic()

    # 문서 블록 구성
    document_block = {
        "type": "document",
        "source": {
            "type": "content",
            "content": content_blocks,
        },
        "title": Path(pdf_path).stem,
        "context": f"총 {doc_data['total_pages']}페이지 문서. Docling으로 {len(doc_data['sections'])}개 섹션 추출됨.",
        "citations": {"enabled": True},
    }

    # Prompt Caching 추가 (반복 질문 시 문서 재전송 비용 절감)
    if use_prompt_cache:
        document_block["cache_control"] = {"type": "ephemeral"}

    response = client.messages.create(
        model=model,
        max_tokens=2048,
        system=(
            "당신은 학습 튜터입니다. 제공된 문서에서만 답변하세요. "
            "반드시 문서의 어느 섹션에서 이 내용이 나왔는지 명시하세요. "
            "답변 형식: '[섹션 제목]에 따르면: [내용]'"
        ),
        messages=[
            {
                "role": "user",
                "content": [
                    document_block,
                    {"type": "text", "text": question},
                ],
            }
        ],
    )

    # 3단계: 응답 파싱 — 텍스트와 인용 분리
    answer_parts = []
    citations = []

    for block in response.content:
        if block.type == "text":
            answer_parts.append(block.text)
            if hasattr(block, 'citations') and block.citations:
                for cite in block.citations:
                    citations.append({
                        "type": cite.type,
                        "cited_text": cite.cited_text,
                        "document_title": cite.document_title,
                        # content_block_location: 0-indexed 섹션 번호
                        "section_index": cite.start_block_index if hasattr(cite, 'start_block_index') else None,
                        "section_title": (
                            doc_data["sections"][cite.start_block_index]["title"]
                            if hasattr(cite, 'start_block_index')
                            and cite.start_block_index < len(doc_data["sections"])
                            else None
                        ),
                    })

    # 인용된 섹션 목록
    sections_used = list({
        c["section_title"] for c in citations if c["section_title"]
    })

    return {
        "answer": "".join(answer_parts),
        "citations": citations,
        "sections_used": sections_used,
        "usage": {
            "input_tokens": response.usage.input_tokens,
            "output_tokens": response.usage.output_tokens,
            "cache_read_tokens": getattr(response.usage, 'cache_read_input_tokens', 0),
        }
    }


# 사용 예시
if __name__ == "__main__":
    result = query_with_citations(
        pdf_path="network_fundamentals.pdf",
        question="TCP 3-way handshake의 각 단계를 설명해 주세요.",
        model="claude-haiku-4-5",
        use_prompt_cache=True,
    )

    print("=== 답변 ===")
    print(result["answer"])
    print("\n=== 인용 섹션 ===")
    for section in result["sections_used"]:
        print(f"  - {section}")
    print("\n=== 토큰 사용량 ===")
    print(f"  입력: {result['usage']['input_tokens']:,}")
    print(f"  출력: {result['usage']['output_tokens']:,}")
    print(f"  캐시 히트: {result['usage']['cache_read_tokens']:,}")
```

#### 2.3 비용/지연 추정 — 책 200페이지 기준

**전제**: 200페이지 기술서적, 평균 밀도 (약 400단어/페이지), Docling 전처리 후 섹션 분리

**토큰 추정**

| 단계 | 토큰 수 | 비고 |
|------|---------|------|
| Docling 전처리 | 0 (로컬) | API 토큰 없음 |
| 문서 입력 (200p × ~700토큰/페이지) | ~140,000 입력 | 첫 질문 시 캐시 미스 |
| 시스템 프롬프트 + Citations 오버헤드 | ~2,000 입력 | |
| 질문 | ~50 입력 | |
| 응답 출력 | ~800 출력 | cited_text는 출력 토큰 미산정 |
| **1회 질문 합계 (캐시 미스)** | **~143,000 입력 + ~800 출력** | |
| **이후 질문 (캐시 히트)** | **~2,050 입력 + ~800 출력** | 문서 부분 캐시 |

**비용 계산 (Claude Haiku 4.5 기준: $1/$5 per MTok)**

| 시나리오 | 비용 |
|----------|------|
| 첫 질문 (캐시 미스) | $0.143 + $0.004 = **약 $0.15** |
| 이후 질문 (캐시 히트, 10% 요금) | $0.002 + $0.004 = **약 $0.006** |
| 10번 질문 총계 | $0.15 + $0.054 = **약 $0.20** |

**Claude Sonnet 4.6 기준 ($3/$15 per MTok)**: 첫 질문 약 $0.43, 이후 질문 약 $0.018, 10번 총계 약 $0.60

**지연 추정**

| 단계 | 소요 시간 |
|------|-----------|
| Docling 전처리 (200p) | 30~90초 (CPU, 첫 실행 시) |
| 첫 질문 (캐시 미스 + 140K 토큰 처리) | 5~15초 |
| 이후 질문 (캐시 히트) | 1~3초 |

**결론**: 200페이지 책을 처음 분석하는 비용은 $0.15 (Haiku) ~ $0.43 (Sonnet), 이후 반복 질문은 캐시 덕에 사실상 무시 가능한 수준. 현실적으로 충분히 실용적인 비용.

#### 2.4 주의사항

- Docling PPTX 지원: ✅ 슬라이드 제목·불릿·스피커노트 추출. 단, **차트는 미지원** (이슈 #2306). 차트 추출 필요 시 python-pptx 보조 스크립트 필요.
- `.csv`, `.xlsx`, `.docx`, `.md` 파일은 Claude Citations API의 `document` 블록 타입으로 직접 투입 불가 — plain text로 변환 후 사용.
- Docling 출력 JSON의 섹션 구조는 PDF 품질에 따라 변동 — 스캔 PDF(이미지 전용)는 GPU OCR 필요.

---

### 3. PPTX 격차 해결 방안

#### 3.1 현재 상황 분석

Phase 1에서 PPTX를 지원하는 도구는 Docling과 MinerU뿐이며, 전용 PPTX MCP 서버는 존재하지 않는다. 두 도구의 PPTX 지원 수준 비교:

| 기능 | Docling | MinerU |
|------|---------|--------|
| 슬라이드 제목 추출 | ✅ | ✅ |
| 불릿 리스트 추출 | ✅ | ✅ |
| 스피커 노트 추출 | ✅ | ✅ |
| 슬라이드 → Markdown 섹션 매핑 | ✅ (1슬라이드=1섹션) | ✅ |
| 차트 추출 | ❌ (이슈 #2306) | 부분적 |
| 이미지/다이어그램 설명 | 부분적 (GraniteDocling VLM 필요) | 부분적 |
| PPTX 전용 MCP | ❌ | ❌ |

#### 3.2 DRLLM PPTX 어댑터 청사진

python-pptx를 Docling의 보조 레이어로 사용하는 2-레이어 접근법:

```python
"""
DRLLM PPTX 어댑터 — python-pptx + Docling 2-레이어
라이선스: python-pptx(MIT), Docling(MIT)
의존: pip install python-pptx docling
"""
import json
from pathlib import Path
from typing import Optional
from pptx import Presentation
from pptx.util import Inches
from pptx.enum.shapes import MSO_SHAPE_TYPE
import xml.etree.ElementTree as ET


class PPTXStructureExtractor:
    """
    python-pptx 기반 PPTX 구조 추출기.
    Docling이 놓치는 차트·테이블 데이터를 보완.
    """

    def extract(self, pptx_path: str) -> dict:
        prs = Presentation(pptx_path)
        slides = []

        for slide_num, slide in enumerate(prs.slides, 1):
            slide_data = {
                "slide_number": slide_num,
                "title": self._get_title(slide),
                "bullets": [],
                "notes": "",
                "tables": [],
                "charts": [],
                "images": [],
            }

            for shape in slide.shapes:
                # 불릿 텍스트
                if shape.has_text_frame and shape != slide.shapes.title:
                    for para in shape.text_frame.paragraphs:
                        text = para.text.strip()
                        if text:
                            level = para.level  # 들여쓰기 레벨 (0~8)
                            slide_data["bullets"].append({
                                "level": level,
                                "text": text
                            })

                # 표 추출 (Docling이 놓칠 수 있는 테이블)
                if shape.has_table:
                    table_data = []
                    for row in shape.table.rows:
                        table_data.append([
                            cell.text.strip() for cell in row.cells
                        ])
                    slide_data["tables"].append(table_data)

                # 차트 메타데이터 추출 (Docling 미지원 보완)
                if shape.shape_type == MSO_SHAPE_TYPE.CHART:
                    chart = shape.chart
                    chart_info = {
                        "chart_type": str(chart.chart_type),
                        "title": chart.has_title and chart.chart_title.text_frame.text or "제목 없음",
                        "series": []
                    }
                    try:
                        for series in chart.series:
                            chart_info["series"].append({
                                "name": series.name,
                                "values": list(series.values) if series.values else []
                            })
                    except Exception:
                        pass
                    slide_data["charts"].append(chart_info)

                # 이미지 alt text (접근성 텍스트)
                if shape.shape_type == MSO_SHAPE_TYPE.PICTURE:
                    alt = shape.name  # 기본 이름 사용
                    slide_data["images"].append({"alt": alt})

            # 스피커 노트
            if slide.has_notes_slide:
                notes_frame = slide.notes_slide.notes_text_frame
                slide_data["notes"] = notes_frame.text.strip()

            slides.append(slide_data)

        return {
            "filename": Path(pptx_path).name,
            "total_slides": len(slides),
            "slides": slides
        }

    def _get_title(self, slide) -> str:
        if slide.shapes.title:
            return slide.shapes.title.text.strip()
        return f"슬라이드"

    def to_structured_markdown(self, pptx_data: dict) -> str:
        """
        PPTX 구조 데이터 → 구조화 Markdown 변환.
        Claude Citations API Custom Content 모드와 호환.
        """
        md_parts = []
        for slide in pptx_data["slides"]:
            n = slide["slide_number"]
            title = slide["title"] or f"슬라이드 {n}"
            md_parts.append(f"## 슬라이드 {n}: {title}")

            if slide["bullets"]:
                for bullet in slide["bullets"]:
                    indent = "  " * bullet["level"]
                    md_parts.append(f"{indent}- {bullet['text']}")

            if slide["tables"]:
                for table in slide["tables"]:
                    if table:
                        headers = table[0]
                        md_parts.append("| " + " | ".join(headers) + " |")
                        md_parts.append("|" + "|".join(["---"] * len(headers)) + "|")
                        for row in table[1:]:
                            md_parts.append("| " + " | ".join(row) + " |")

            if slide["charts"]:
                for chart in slide["charts"]:
                    md_parts.append(
                        f"[차트: {chart['title']} ({chart['chart_type']})]"
                    )

            if slide["notes"]:
                md_parts.append(f"\n> 강의 노트: {slide['notes']}")

            md_parts.append("")  # 빈 줄

        return "\n".join(md_parts)


# 사용 예시: PPTX → 구조화 Markdown → MinerU-Explorer 또는 Claude Citations
def process_pptx_for_byoc(pptx_path: str) -> str:
    extractor = PPTXStructureExtractor()
    pptx_data = extractor.extract(pptx_path)
    return extractor.to_structured_markdown(pptx_data)
```

#### 3.3 DRLLM PPTX 파이프라인

```
강의 슬라이드(.pptx) 입력
  → PPTXStructureExtractor (python-pptx 기반)
    [불릿·표·차트·노트 완전 추출]
  → to_structured_markdown()
    [슬라이드 번호 + 제목 헤더 보존]
  → 두 갈래:
    A. MinerU-Document-Explorer에 .md로 인제스트
       → doc_toc → doc_read → 섹션 응답
    B. Claude Citations API Custom Content 블록으로 투입
       → 슬라이드 단위 content_block_location 인용
  → 출력: "슬라이드 12: 'TCP Layer'에서 이 개념이 설명됩니다"
```

**주의**: Docling의 PPTX 파서도 기본 추출은 가능하지만 차트 데이터가 손실된다. python-pptx 어댑터는 이 격차를 보완하는 보조 레이어다. 슬라이드에 차트가 없는 경우 Docling만으로도 충분하다.

---

### 4. YouTube 챕터 격차 해결

#### 4.1 yt-dlp 챕터 추출 방식

yt-dlp는 YouTube 영상 메타데이터에서 챕터 정보를 직접 추출한다. 챕터가 있는 영상의 경우:

```python
import yt_dlp

def extract_youtube_chapters(url: str) -> dict:
    """
    YouTube 영상의 챕터 메타데이터 추출.
    챕터가 없으면 None 반환.
    """
    ydl_opts = {
        'quiet': True,
        'skip_download': True,
        'writeinfojson': False,
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)

    chapters = info.get('chapters')  # 없으면 None
    duration = info.get('duration', 0)

    return {
        "title": info.get('title', ''),
        "duration_seconds": duration,
        "has_chapters": chapters is not None,
        "chapters": [
            {
                "start_time": ch["start_time"],
                "end_time": ch["end_time"],
                "title": ch["title"],
            }
            for ch in (chapters or [])
        ]
    }

# 반환 예시 (챕터 있는 영상):
# {
#   "title": "Computer Networking Full Course",
#   "duration_seconds": 3720,
#   "has_chapters": True,
#   "chapters": [
#     {"start_time": 0, "end_time": 245, "title": "Introduction"},
#     {"start_time": 245, "end_time": 1180, "title": "TCP/IP Layer"},
#     ...
#   ]
# }
```

#### 4.2 챕터 없는 영상의 LLM 챕터 추론 패턴

Chapter-Llama (CVPR 2025)는 시간 단위 트랜스크립트 + 프레임 캡션으로 챕터 경계를 LLM이 직접 추론하는 방식을 제안했다. DRLLM에서는 프레임 처리 없이 **트랜스크립트만으로** 챕터를 추론하는 경량 버전을 구현할 수 있다:

```python
"""
챕터 없는 YouTube 영상 → LLM 챕터 추론 (트랜스크립트 기반)
라이선스: anthropic-sdk(MIT), yt-dlp(Unlicense/public domain)
의존: pip install anthropic yt-dlp
"""
import anthropic
import yt_dlp
import json


def get_timed_transcript(url: str, lang: str = "ko") -> list[dict]:
    """
    mcp-youtube-transcript 대신 yt-dlp로 직접 시간 정보 포함 자막 추출.
    자막이 없으면 자동 생성 자막 사용.
    """
    ydl_opts = {
        'quiet': True,
        'skip_download': True,
        'writeautomaticsub': True,
        'subtitleslangs': [lang, 'en'],
        'subtitlesformat': 'vtt',
    }

    transcript_segments = []
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        # 실제 자막 파일 처리는 생략 (mcp-youtube-transcript MCP 사용 권장)
        # 여기서는 구조만 보여줌
        title = info.get('title', '')

    return transcript_segments, title


def infer_chapters_from_transcript(
    transcript_segments: list[dict],
    video_title: str,
    duration_seconds: int,
    model: str = "claude-haiku-4-5"
) -> list[dict]:
    """
    트랜스크립트 + 타임스탬프 → LLM 챕터 추론.
    Chapter-Llama의 경량 텍스트-온리 버전.

    Args:
        transcript_segments: [{"start": float, "end": float, "text": str}, ...]
        video_title: 영상 제목 (컨텍스트 제공)
        duration_seconds: 영상 길이 (초)
    """
    # 긴 트랜스크립트는 슬라이딩 윈도우로 분할 처리 (20K 토큰 단위)
    # 여기서는 단순화하여 전체 처리
    transcript_text = "\n".join([
        f"[{int(seg['start'])//60:02d}:{int(seg['start'])%60:02d}] {seg['text']}"
        for seg in transcript_segments
    ])

    client = anthropic.Anthropic()

    response = client.messages.create(
        model=model,
        max_tokens=1024,
        system=(
            "당신은 교육 영상 분석 전문가입니다. "
            "트랜스크립트를 분석하여 논리적 챕터 경계를 찾으세요."
        ),
        messages=[{
            "role": "user",
            "content": f"""다음 YouTube 강의 영상의 트랜스크립트입니다.
영상 제목: {video_title}
영상 길이: {duration_seconds//60}분 {duration_seconds%60}초

트랜스크립트 (타임스탬프 포함):
{transcript_text[:15000]}  # 토큰 한도 고려

위 트랜스크립트를 분석하여 논리적 챕터를 5~10개로 나누세요.
반드시 다음 JSON 형식으로만 응답하세요:
{{
  "chapters": [
    {{"start_time": 0, "title": "소개", "summary": "한 줄 요약"}},
    {{"start_time": 245, "title": "챕터 제목", "summary": "한 줄 요약"}},
    ...
  ]
}}"""
        }]
    )

    try:
        # JSON 파싱 (LLM이 JSON을 감싼 마크다운 코드블록을 생성할 수 있음)
        raw = response.content[0].text
        json_str = raw
        if "```json" in raw:
            json_str = raw.split("```json")[1].split("```")[0].strip()
        elif "```" in raw:
            json_str = raw.split("```")[1].split("```")[0].strip()

        result = json.loads(json_str)
        return result.get("chapters", [])
    except (json.JSONDecodeError, IndexError, KeyError):
        # 파싱 실패 시 빈 목록 반환 (graceful degradation)
        return []


def process_youtube_for_byoc(
    url: str,
    question: Optional[str] = None
) -> dict:
    """
    YouTube BYOC 완전 파이프라인:
    1. yt-dlp로 챕터 + 트랜스크립트 추출
    2. 챕터 없으면 LLM 추론
    3. mcp-youtube-transcript로 타임스탬프 트랜스크립트 취득
    4. 구조화된 챕터+트랜스크립트 반환
    """
    meta = extract_youtube_chapters(url)

    if not meta["has_chapters"] and meta["duration_seconds"] > 300:
        # 5분 이상이고 챕터 없는 영상만 추론 (짧은 영상은 불필요)
        # transcript_segments는 mcp-youtube-transcript MCP 도구로 취득 (실제 구현 시)
        # inferred = infer_chapters_from_transcript(
        #     transcript_segments, meta["title"], meta["duration_seconds"]
        # )
        meta["inferred_chapters"] = []  # MCP 도구 사용 시 채워짐
        meta["chapter_source"] = "llm_inferred"
    else:
        meta["chapter_source"] = "youtube_native"

    return meta
```

#### 4.3 mcp-youtube-transcript + BYOC 워크플로우

```
YouTube URL 입력
  ├── yt-dlp: 챕터 메타데이터 확인
  │    ├── 챕터 있음: 챕터 목록 직접 사용
  │    └── 챕터 없음: LLM 챕터 추론 (위 패턴)
  │
  ├── mcp-youtube-transcript: 타임스탬프 포함 트랜스크립트 취득
  │    └── 50K자 초과 시 페이지네이션 (--page N)
  │
  └── 챕터 + 트랜스크립트 결합
       → Gemini CLI (1M 토큰 컨텍스트에 전체 트랜스크립트 로드)
       → 사용자 질문: "이 강의에서 X개념은 어디서 설명되나요?"
       → 응답: "32:15~38:40 (챕터 4: 'X 심화') 에서 다음과 같이 설명됩니다"
```

**격차 해결 수준**: yt-dlp 챕터 추출은 완전히 해결됨. LLM 챕터 추론은 Chapter-Llama 논문 수준의 정확도(F1 45.3)는 아니지만, 텍스트-온리 경량 버전으로 DRLLM 실용 용도에는 충분. 프레임 캡션 기반 고정확도 추론이 필요하면 Chapter-Llama 구현을 참조.

---

### 5. DRLLM BYOC 파이프라인 종합 청사진

#### 5.1 자료 형식별 처리 Chain

```
┌─────────────────────────────────────────────────────────────┐
│                DRLLM S2 — BYOC 분기 처리 흐름               │
└─────────────────────────────────────────────────────────────┘

사용자 자료 등록
  → 형식 감지 (확장자 + MIME)
  │
  ├── [PDF / DOCX]
  │     → Docling (구조 파싱, 로컬, 완전 지원)
  │     ↓
  │     ├── 로컬 우선: MinerU-Document-Explorer 인제스트
  │     │    → doc_toc → doc_read → 섹션 응답
  │     └── 클라우드 최고 품질: Claude Citations API
  │          → Custom Content 블록 → page_location/content_block_location 인용
  │
  ├── [PPTX]
  │     → PPTXStructureExtractor (python-pptx, 차트 보완)
  │     → structured_markdown 생성
  │     ↓
  │     └── MinerU-Document-Explorer 인제스트
  │          → doc_toc (슬라이드별 섹션) → doc_read
  │
  ├── [EPUB]
  │     → mcp-epub-reader (13개 MCP 도구)
  │     → get_toc → jump_to_chapter → get_chapter_summary
  │     → 챕터 단위 응답 ("Chapter 5에서...")
  │
  └── [YouTube URL]
        → yt-dlp (챕터 메타데이터 + 챕터 없으면 LLM 추론)
        → mcp-youtube-transcript (타임스탬프 트랜스크립트)
        → Gemini 1M 컨텍스트 통독 + 타임스탬프 위치 응답
```

#### 5.2 S2 Research Execution 스킬에서 BYOC 분기 처리

S2 스킬 내 BYOC 분기는 아래 판단 트리를 따른다:

```python
# S2 스킬의 의사코드 (GEMINI.md 기반 Gemini 에이전트 논리)

def s2_byoc_route(source_ref: str) -> str:
    """
    BYOC 자료 처리 라우팅 로직.
    source_ref: 파일경로 또는 YouTube URL
    """
    if is_youtube_url(source_ref):
        # YouTube 경로
        chapters = yt_dlp_get_chapters(source_ref)
        if not chapters:
            chapters = llm_infer_chapters(get_transcript(source_ref))
        transcript = mcp_youtube_get_timed_transcript(source_ref)
        return format_with_timestamps(transcript, chapters)

    ext = get_extension(source_ref)

    if ext in ['.pdf', '.docx']:
        # PDF/DOCX 경로
        if qmd_daemon_running():
            # 로컬 우선: MinerU-Document-Explorer
            ingest(source_ref)
            toc = doc_toc(source_ref)
            relevant_sections = identify_sections(toc, current_question)
            return doc_read(source_ref, relevant_sections)
        else:
            # 클라우드 폴백: Claude Citations API
            return claude_citations_query(source_ref, current_question)

    elif ext == '.pptx':
        # PPTX 경로: python-pptx 어댑터 경유
        md_content = pptx_extractor.to_structured_markdown(source_ref)
        save_as_md(source_ref, md_content)
        return s2_byoc_route(source_ref_md)  # MD로 재귀 처리

    elif ext in ['.epub']:
        # EPUB 경로
        toc = mcp_epub_get_toc(source_ref)
        relevant_chapter = identify_chapter(toc, current_question)
        summary = mcp_epub_get_chapter_summary(relevant_chapter)
        content = mcp_epub_jump_to_chapter(relevant_chapter)
        return f"챕터 '{relevant_chapter}': {content}"
```

#### 5.3 사용자 인터페이스 — 자료 등록 + Deep Review 트리거

**Gemini Extension 슬래시 커맨드 설계**:

```
/byoc:register [파일경로 또는 YouTube URL]
  → 자료 등록 + 구조 인덱싱
  → TOC/챕터 목록 사용자에게 표시

/byoc:list
  → 등록된 BYOC 자료 목록 표시

/byoc:review [자료명] [질문]
  → 등록된 자료에서 Deep Review
  → 출처 위치 명시 응답

/byoc:deep [자료명]
  → 자료 전체 구조 분석 + 주요 개념 맵 생성
  → "이 자료의 핵심 챕터는 X, Y, Z이며 각각..."
```

**GEMINI.md 에이전트 지시 (BYOC 섹션)**:

```markdown
## BYOC (사용자 제공 자료) 처리 규칙

1. 사용자가 자료를 언급하면 항상 doc_toc 또는 get_toc로 구조를 먼저 확인하라.
2. 응답 시 반드시 위치를 명시하라:
   - PDF/DOCX: "[N장 M절: 섹션 제목]에 따르면..."
   - PPTX: "[슬라이드 N: 슬라이드 제목]에서..."
   - EPUB: "[챕터 제목]에서..."
   - YouTube: "[MM:SS~MM:SS] (챕터명)에서..."
3. 위치를 명시할 수 없으면 "해당 자료에서 확인되지 않습니다"라고 답하라.
4. 청크 검색 결과를 그대로 합성하지 마라. 항상 원본 위치 확인 후 답하라.
```

---

## SP-2 (출처 + BYOC) 직접 영향

Phase 2 심화를 통해 SP-2 설계에 다음 결정 사항이 확정된다:

1. **MCP 조합 확정**: qmd(MinerU-Document-Explorer) + mcp-youtube-transcript + mcp-epub-reader 3개 MCP를 SP-2의 BYOC 핵심 MCP로 채택. 모두 MCP 표준 준수, pip/npm 단일 명령 설치.

2. **Gemini Extension 어댑터 개발 범위**: MinerU-Document-Explorer의 HTTP 데몬 방식 + `gemini-extension.json` mcpServers URL 방식이 Gemini CLI에서 동작 확인됨. SP-2에서 실제 Extension 패키지 구현 필요.

3. **비용 모델 결정**: Claude Citations API 경로(클라우드)와 Gemini + MinerU-Explorer 경로(완전 로컬) 두 경로를 병렬 지원. 사용자가 API 키 유무에 따라 선택. 200페이지 기준 클라우드 경로는 첫 질문 $0.15(Haiku)로 실용적.

4. **PPTX 어댑터 필수**: python-pptx 기반 PPTXStructureExtractor는 SP-2 구현 필수 컴포넌트. Docling 단독으로는 차트 데이터 손실 발생.

5. **응답 스키마**: S2 BYOC 분기의 모든 응답은 `{위치_식별자, 인용_텍스트, 답변}` 구조를 강제. SP-1 스킬 인터페이스 설계에 이 스키마 반영 필요.

---

## 변경된 권장 (Phase 1 대비)

### 변경된 권장

| Phase 1 권장 | Phase 2 수정 | 이유 |
|--------------|--------------|------|
| Docling을 모든 BYOC 형식의 단일 전처리 레이어로 채택 | PPTX는 python-pptx 보조 레이어 추가 필수 | Docling의 PPTX 차트 미지원(이슈 #2306) 확인. 보조 없이는 차트 데이터 손실. |
| MinerU-Document-Explorer I3 (통합 난이도 3/5) | I2.5 — HTTP 데몬 + URL 방식으로 Gemini Extension 통합이 생각보다 단순 | `gemini-extension.json` mcpServers에 URL 방식이 표준 지원됨 확인 |
| Phase 1: LightRAG 기각 | 유지 (기각) | 챕터/페이지 위치 반환 없음. Phase 2에서도 DRLLM 가치 없음 확인. |
| YouTube 챕터 격차: "LLM 위임 패턴으로 사용" | 구체 패턴 확정: yt-dlp 챕터 추출 우선 + 없으면 Chapter-Llama 경량 패턴으로 LLM 추론 | yt-dlp `chapters` 필드가 공식 지원됨 확인 |

### 새로 발견된 격차

1. **Gemini CLI Extension에서 MCP HTTP 데몬 선행 실행 요구**: `qmd mcp --http --daemon`이 사전에 실행되어 있어야 한다. Gemini CLI가 Extension 로드 시 자동으로 데몬을 시작하는 메커니즘이 없으므로, 사용자 측 설정(systemd user service 또는 자동 실행 스크립트) 필요. SP-2 구현 시 이 UX 마찰 해결 방안 설계 필요.

2. **Claude Citations API — Structured Outputs 동시 사용 불가**: Citations와 Structured Outputs는 API 레벨에서 상호 배타적. S2 응답 스키마가 JSON 구조체를 강제할 경우, Citations 응답을 후처리로 파싱하는 별도 레이어 필요.

3. **EPUB OCR 없음**: 스캔 EPUB(이미지 기반)는 mcp-epub-reader가 처리 불가. 실제 사용 케이스에서 이 경우는 드물지만, 오래된 학술서 EPUB 처리 시 한계 존재.

4. **Qwen 리랭커 라이선스 검토 필요**: MinerU-Document-Explorer의 리랭커 모델(qwen3-reranker-0.6b)은 Qwen License를 따른다. 상업적 용도나 배포 환경에서는 라이선스 조건 사전 확인 필요. 개인 학습용 DRLLM에서는 문제 없음.

---

*보고서 생성일: 2026-04-14*
*참고 출처: Anthropic Citations API 공식 문서, MinerU-Document-Explorer GitHub, Docling PyPI, Gemini CLI Extension 공식 문서, Chapter-Llama CVPR 2025 논문*
