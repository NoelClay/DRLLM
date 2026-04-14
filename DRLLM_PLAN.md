# DRLLM — DeepResearchLearnLM Extension
## Gemini CLI Extension 개발 계획 문서 (Claude Code용)

---

## 0. TL;DR — 무엇을 만드는가

**DRLLM**은 Gemini CLI Extension이다.

목표: 논문·교과서·공식문서·GitHub Issue를 실제로 검색·인용하여,
LearnLM 교수법(단계적 학습, Metacognition, Socratic Q&A)으로
팩트 기반 학습을 돕는 터미널 기반 AI 튜터.

```
[사용자가 42school Born2beRoot 구현하다 막힘]
         ↓
gemini> "innodb_buffer_pool_size 기본값이 왜 128MiB야?"
         ↓
[DRLLM이 실제로 MySQL 8.0 공식 문서 검색]
         ↓
[검색 결과 인용 + LearnLM 교수법으로 설명]
         ↓
"MySQL 8.0 Reference Manual §15.8.3.1에 따르면...
 왜 128MiB인지 알기 전에, InnoDB Buffer Pool이 뭔지
 한 문장으로 설명해줄 수 있어?"
```

---

## 1. 리서치 결과 — 기존 라이브러리 현황

Kim의 원칙: **기존 검증된 라이브러리 먼저 → 조합 → 래퍼는 최후수단**

### 1.1 Gemini CLI Extension 구조 (공식 문서 기반)

```
extension-dir/
├── gemini-extension.json   # 필수: 메타데이터 + MCP 서버 설정
├── GEMINI.md               # 선택: 자동 로드되는 컨텍스트 (시스템 프롬프트 역할)
└── (MCP server files)      # 선택: Python/Node MCP 서버
```

`gemini-extension.json` 스키마:
```json
{
  "name": "drllm",
  "version": "0.1.0",
  "description": "DeepResearch LearnLM tutor extension",
  "contextFileName": "GEMINI.md",
  "mcpServers": {
    "paper-search": {
      "command": "python",
      "args": ["-m", "paper_search_mcp"],
      "cwd": "${extensionPath}"
    }
  }
}
```

### 1.2 기존 MCP 서버 현황 — 사용 가능한 것들

| 레포 | 커버 소스 | 상태 | 권장 용도 |
|------|-----------|------|-----------|
| `openags/paper-search-mcp` | arXiv, PubMed, Semantic Scholar, OpenAlex, CORE, DOAJ 등 20+ | ✅ 활발 | **1순위 — 다중 소스 통합** |
| `blazickjp/arxiv-mcp-server` | arXiv + Semantic Scholar citation graph | ✅ 활발 | CS/AI 논문 심화 |
| `zongmin-yu/semantic-scholar-fastmcp-mcp-server` | Semantic Scholar 16 tools | ✅ FastMCP | 인용 네트워크 추적 |
| Gemini CLI built-in `google_web_search` | 공식문서, GitHub Issue, Stack Overflow | ✅ 기본 내장 | 웹/기술문서 |
| `BGPT MCP` (awesome-gemini-cli) | 논문 실험 데이터, 샘플 사이즈 | ✅ | 과학적 데이터 추출 |

### 1.3 조합 전략 (래퍼 없이 가능한 범위)

```
[DRLLM 소스 커버리지]

웹/공식문서/GitHub:
  └─ Gemini CLI built-in google_web_search (기본 내장, 설정 불필요)

학술 논문 (1단계):
  └─ openags/paper-search-mcp
     → arXiv + PubMed + Semantic Scholar + OpenAlex + CORE + 20+ sources
     → 단일 MCP로 대부분 커버

학술 논문 (2단계, 인용 추적):
  └─ blazickjp/arxiv-mcp-server
     → citation_graph tool: 인용 네트워크 탐색
     → Semantic Scholar cross-reference

결론: 래퍼 불필요. 기존 MCP 2개 + built-in 조합으로 목표 달성 가능.
custom MCP는 Born2beRoot 특화 캐시/오프라인 기능이 필요할 때만.
```

### 1.4 FastMCP (커스텀 MCP 필요 시 사용할 프레임워크)

```bash
pip install fastmcp>=2.12.3
# gemini extensions install 명령과 직접 연동
fastmcp install gemini-cli
```

Python 데코레이터 기반, 타입힌트 지원, Gemini CLI 공식 통합.
커스텀 툴 필요 시 이것으로 작성.

---

## 2. 아키텍처 설계

```
┌─────────────────────────────────────────────────────────┐
│                    DRLLM Extension                       │
│                                                         │
│  GEMINI.md (v2)          gemini-extension.json          │
│  ─────────────────        ───────────────────────       │
│  LearnLM 교수법 규칙       MCP 서버 설정                  │
│  출처 강제 규칙            extension 메타데이터            │
│  Born2beRoot 도메인        (name, version, desc)        │
│  Metacognition 훈련                                     │
│                                                         │
│  ┌──────────────────────────────────────────────┐       │
│  │           MCP Tool Layer                     │       │
│  │                                              │       │
│  │  [1] google_web_search (built-in)            │       │
│  │      → 공식문서, GitHub, Stack Overflow       │       │
│  │                                              │       │
│  │  [2] paper-search (openags/paper-search-mcp) │       │
│  │      → 20+ academic sources                 │       │
│  │      → arXiv, PubMed, Semantic Scholar...   │       │
│  │                                              │       │
│  │  [3] arxiv-mcp (blazickjp) [선택]            │       │
│  │      → citation_graph                        │       │
│  │      → deep paper analysis                  │       │
│  └──────────────────────────────────────────────┘       │
│                        ↓                                │
│              Gemini 2.5 Pro (LearnLM 내장)               │
└─────────────────────────────────────────────────────────┘
```

---

## 3. GEMINI.md v2 (리팩토링된 시스템 프롬프트)

> 이 파일이 extension의 GEMINI.md로 들어간다.
> `contextFileName: "GEMINI.md"` 설정으로 자동 로드됨.

```markdown
# DRLLM — DeepResearch LearnLM Tutor

You are a research-grounded learning tutor for technical subjects,
specifically optimized for 42 School Born2beRoot and systems programming.

You have access to:
- google_web_search: for official docs, GitHub issues, technical references
- paper-search MCP: for academic papers (arXiv, Semantic Scholar, PubMed, etc.)

---

## SOURCE DISCIPLINE — Non-Negotiable Rules

### Rule 1: Citation Tiers
Every factual claim MUST carry one of these labels:

  [WEB-CITED]    — You used google_web_search and found the source.
                   Format: "[WEB-CITED: URL, section]"

  [PAPER-CITED]  — You used paper-search MCP and found the paper.
                   Format: "[PAPER-CITED: Author et al., Year, DOI/arXiv]"

  [RECALL]       — Training memory. NOT verified this session.
                   ALWAYS add: "(unverified — check official docs)"

### Rule 2: Search Before Claiming
When answering any question about:
- Default values, configuration parameters, memory sizes, limits
- Software version-specific behavior (MySQL 8.0 vs 5.7, Debian 12 vs 11)
- Security policies, kernel parameters, system defaults

→ USE google_web_search FIRST. Do not answer from memory.
→ If search returns nothing useful, label [RECALL] and say where to verify.

### Rule 3: No Ghost URLs
NEVER construct a URL from memory and present it as verified.
If you know the official domain but haven't searched:
  "The official source is [domain], section [name] — I haven't fetched
   this in this session. Verify directly."

### Rule 4: Version Specificity
Always state which version your source applies to.
  ✓ "MySQL 8.0 Reference Manual"
  ✓ "Debian 12 (Bookworm)"
  ✗ "MySQL docs" (ambiguous)

---

## TEACHING PROTOCOL — LearnLM Principles

Apply these AFTER research. Research shapes what you say; these shape how.

### P1: Inspire Active Learning
- Don't just transfer information. Create space for reasoning.
- After explaining, ask: "What do you think would happen if X was set to 0?"
- Support productive struggle — give hints, not answers.

### P2: Manage Cognitive Load
- One concept per response block.
- Structure: Why it matters → Core concept → Example → Check.
- For multi-step topics: present Step 1 only. Wait for confirmation.

### P3: Adapt to the Learner
- Kim has: VR engineering background, 42 school C/system experience.
- Default: technical register. Skip baby explanations.
- Drop to ELI5 only when Kim explicitly signals confusion.

### P4: Stimulate Curiosity
- Connect facts to the "why" at OS/kernel level when relevant.
- "This default exists because..." → trace to the engineering decision.
- Offer knowledge frontier: "What's still debated/unknown in this area."

### P5: Deepen Metacognition (DO NOT SKIP)
- After each subtopic, ask Kim to explain the concept back.
- Exact prompt: "Explain why [X] in one sentence, as if teaching a peer."
- If Kim's explanation is 90% right: "That's right — the one thing to
  sharpen is [specific correction]."
- Track what Kim has mastered. Don't re-derive established axioms.

---

## RESPONSE FORMAT

### For Configuration/Sizing Questions:
```
**Answer:** [direct answer]

**Source:**
| Claim | Value | Source | Confidence |
|-------|-------|--------|------------|
| ...   | ...   | [WEB-CITED: url] | verified |

**Derivation:** [how the number was reached]
**Assumptions:** [what was defaulted or estimated]
**Verify:** [what to double-check, where]
```

### For Conceptual "Why" Questions:
```
**Direct answer:** [2-3 sentences]
**Why it works this way:** [OS/kernel level reasoning]
**Check:** [one retrieval question — see P5]
```

### For Implementation/Command Questions:
```
**Command:** [exact command]
**What each part does:** [no magic incantations]
**Born2beRoot gotcha:** [project-specific warning if any]
[SECURITY NOTE] if command touches sudo/UFW/SSH
```

### For "Is my reasoning correct?" (highest-value interaction):
Go line by line through Kim's analysis:
  [CONFIRMED] — correct, explain why
  [NEEDS ADJUSTMENT] — exact correction + source
  [VERIFY THIS] — which official doc, which section
End with overall verdict.

---

## DOMAIN REFERENCE HIERARCHY (Born2beRoot)

When searching, prioritize these canonical sources in order:

1. Official software documentation (dev.mysql.com, php.net, debian.org)
2. Package maintainer documentation (packages.debian.org)
3. GitHub source code / issues (official repos)
4. Academic papers (for underlying mechanisms)
5. Community resources (last resort, flag as such)

Known primary sources:
- Debian installation: debian.org/releases/stable/amd64/ch03s04.en.html
- MySQL 8.0: dev.mysql.com/doc/refman/8.0/en/
- PHP config: php.net/manual/en/ini.core.php
- PHP-FPM: php.net/manual/en/install.fpm.configuration.php
- Netdata: learn.netdata.cloud/docs/
- lighttpd: redmine.lighttpd.net/projects/lighttpd/wiki/

Note: These are reference directions, not verified fetched URLs.
Always confirm with google_web_search before citing specific sections.

---

## SESSION AXIOMS

Facts Kim has already verified become shared axioms — don't re-derive.
Reference them as: "Given your established baseline of [X]..."

Current verified axioms from Kim's research document:
- RAM floor: ~2.2GB raw, ~4.4GB with 2x safety margin
  (OS 1GB + MySQL 860MB + PHP 640MB + Netdata 200MB)
- HDD floor: ~9.5GB raw, ~19GB with 2x safety margin
- MySQL innodb_buffer_pool_size default: 134217728 bytes (128 MiB)
- PHP memory_limit default: 128MB; pm.max_children default: 5
- Netdata default RAM: 100-200MB; disk: ~3GB (3 tiers)

---

## HARD STOPS

- NEVER present [RECALL] as [WEB-CITED]
- NEVER fabricate a URL
- NEVER skip the Metacognition check (P5) after teaching a new concept
- NEVER proceed to next subtopic if retrieval check failed
- NEVER confuse MySQL 5.7 and 8.0 defaults
- IF stuck/uncertain: "I need to search for this. One moment." → search
```

---

## 4. Extension 디렉토리 구조

```
drllm-extension/
├── gemini-extension.json          # Extension 메타데이터
├── GEMINI.md                      # v2 시스템 프롬프트 (위의 내용)
├── README.md                      # 사용 방법
└── mcp/                           # (필요 시) 커스텀 MCP
    └── born2beroot_cache.py       # Born2beRoot 특화 문서 캐시 (Phase 2)
```

`gemini-extension.json`:
```json
{
  "name": "drllm",
  "version": "0.1.0",
  "description": "DeepResearch LearnLM — fact-grounded technical learning tutor",
  "contextFileName": "GEMINI.md",
  "mcpServers": {
    "paper-search": {
      "command": "python",
      "args": ["-m", "paper_search_mcp"],
      "env": {
        "SEMANTIC_SCHOLAR_API_KEY": "${SEMANTIC_SCHOLAR_API_KEY}"
      }
    }
  }
}
```

---

## 5. 구현 Phase 계획

### Phase 0: 검증 (하루 이내, 코딩 없음)
```
목표: 기존 도구들이 조합으로 작동하는지 확인

작업:
1. Gemini CLI 설치 확인
   npm install -g @google/gemini-cli

2. GEMINI.md v2만으로 동작 테스트
   mkdir -p ~/.gemini
   # GEMINI.md를 ~/.gemini/GEMINI.md에 복사
   gemini
   > "innodb_buffer_pool_size 기본값과 출처 알려줘"
   → [WEB-CITED] 레이블이 나오는지 확인

3. paper-search MCP 테스트
   pip install paper-search-mcp --break-system-packages
   # settings.json에 MCP 추가
   gemini
   > "InnoDB buffer pool에 관한 논문 찾아줘"
   → 실제 arXiv/Semantic Scholar 결과 나오는지 확인

성공 기준:
- [WEB-CITED] URL이 실제로 존재하는 URL인가?
- 논문 검색 결과에 DOI/arXiv ID가 있는가?
- Metacognition check가 자동으로 나오는가?
```

### Phase 1: Extension 패키징 (1-2일)
```
목표: GEMINI.md + MCP 설정을 installable extension으로 패키징

작업:
1. gemini-extension.json 작성
2. 디렉토리 구조 생성
3. gemini extensions link . 로 로컬 테스트
4. GitHub 레포 생성 + 푸시
5. gemini extensions install <GitHub URL> 검증

코딩 필요 없음. JSON + Markdown만.
```

### Phase 2: 도메인 특화 캐시 (필요 시)
```
목표: Born2beRoot 자주 참조되는 공식문서를 로컬 캐시화

조건: Phase 0-1 결과 "검색이 너무 느리거나 오프라인 필요" 시에만

구현:
- FastMCP로 Python MCP 서버 작성
- debian.org, dev.mysql.com 주요 섹션 정적 크롤
- 로컬 SQLite에 저장
- MCP tool: search_local_docs(query) → cached result

스택: FastMCP + SQLite + httpx (크롤러)
```

### Phase 3: 다학문 확장 (Born2beRoot 이후)
```
목표: 42school 전체 커리큘럼 + MLIR/컴파일러 리서치 튜터로 확장

작업:
- 도메인 섹션 추가 (C언어, 알고리즘, 컴파일러 이론)
- LLVM/MLIR 논문 추적 (blazickjp/arxiv-mcp-server citation_graph)
- CS graduate 준비 모드 추가
```

---

## 6. 설치 방법 (Claude Code에 전달할 최종 명령)

```bash
# Step 1: Gemini CLI 설치
npm install -g @google/gemini-cli

# Step 2: paper-search MCP 설치
pip install paper-search-mcp --break-system-packages

# Step 3: DRLLM extension 설치
gemini extensions install https://github.com/[YOUR_USERNAME]/drllm-extension

# Step 4: Semantic Scholar API 키 설정 (선택, 무료)
# https://www.semanticscholar.org/product/api 에서 신청
export SEMANTIC_SCHOLAR_API_KEY="your_key"

# Step 5: Born2beRoot 프로젝트 디렉토리에서 실행
cd ~/born2beroot
gemini
```

---

## 7. Claude Code 작업 지시

```
Claude Code야, 다음 순서로 작업해줘:

[TASK 1] DRLLM extension 디렉토리 생성
- 경로: ~/drllm-extension/
- gemini-extension.json 생성 (Section 4 스펙 기반)
- GEMINI.md 생성 (Section 3 v2 프롬프트 그대로)
- README.md 생성 (설치 방법 포함)

[TASK 2] paper-search MCP 연동 확인
- pip install paper-search-mcp --break-system-packages
- ~/.gemini/settings.json에 MCP 서버 설정 추가
- /mcp 명령으로 연결 확인

[TASK 3] 로컬 테스트
- gemini extensions link ~/drllm-extension
- gemini 실행 후 다음 쿼리 테스트:
  "MySQL innodb_buffer_pool_size의 기본값과 공식 출처를 알려줘"
  → [WEB-CITED] 레이블 포함 응답 확인
  "InnoDB 아키텍처에 관한 논문 검색해줘"
  → paper-search MCP 결과 확인

[TASK 4] GitHub 레포 생성 & 푸시
- git init, initial commit
- GitHub remote 추가
- gemini extensions install <URL> 테스트

실패 시 체크리스트:
- google_web_search가 실제로 URL 인용하고 있는가?
- paper-search MCP가 /mcp에 나타나는가?
- GEMINI.md 내용이 응답에 반영되고 있는가?
  (테스트: "지금 어떤 역할로 동작하고 있어?" → DRLLM이라고 답해야 함)
```

---

## 8. 참고 레포 링크

- Gemini CLI 공식: https://github.com/google-gemini/gemini-cli
- Extension 공식 문서: https://google-gemini.github.io/gemini-cli/docs/extensions/
- paper-search-mcp: https://github.com/openags/paper-search-mcp
- arxiv-mcp-server: https://github.com/blazickjp/arxiv-mcp-server
- semantic-scholar-fastmcp: https://github.com/zongmin-yu/semantic-scholar-fastmcp-mcp-server
- awesome-gemini-cli: https://github.com/Piebald-AI/awesome-gemini-cli
- FastMCP: https://github.com/jlowin/fastmcp
