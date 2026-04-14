# Step 3 Smoke Test — InnoDB end-to-end (수동 체인, hook 없음)

## Setup

```bash
cd /home/namykim/workspace/DRLLM
gemini extensions uninstall DRLLM 2>/dev/null; gemini extensions link .
rm -rf .drllm/sessions/  # 깨끗한 상태
```

> **Note**: 이미 link 된 상태라면 `gemini extensions uninstall DRLLM` 먼저. `unlink` 명령은 Gemini CLI v0.37.1 에 없음.

## Scenario: InnoDB Buffer Pool 왜 128MiB?

### 단계 A — S0 수동 호출

- [ ] Gemini 진입 후: `activate_skill("drllm-launcher")`
- [ ] 주제 입력: "InnoDB Buffer Pool 왜 128MiB?"
- [ ] 세션 디렉토리 생성 확인:
  ```bash
  ls .drllm/sessions/
  # 예: 20260414-innodb-buffer-pool-default-size/
  ```
- [ ] metadata.json 검증:
  ```bash
  jq '.' .drllm/sessions/*/metadata.json
  # status=="research", slug, started_at 필드 확인
  ```

### 단계 B — S2 수동 호출

- [ ] `activate_skill("drllm-research-execution")`
- [ ] S2가 주제 로드, 2~4 서브쿼리 분해 확인 (LLM 출력에 서브쿼리 표시)
- [ ] fetch MCP 호출 확인 (Gemini 출력에 tool_use 로그)
- [ ] Layer 2 Call 1 → JSON 응답 확인
- [ ] Layer 2 Call 2 → verified 필드 확인
- [ ] research-results.md 생성 확인:
  ```bash
  cat .drllm/sessions/*/research-results.md
  # Summary, Key Points, Citations 테이블 존재
  # verified 컬럼 확인
  ```
- [ ] metadata.json 갱신 확인:
  ```bash
  jq '.status, .url_verify_ratio' .drllm/sessions/*/metadata.json
  # status=="tutor", ratio >= 0.0
  ```

### 단계 C — S4 수동 호출

- [ ] `activate_skill("drllm-adaptive-tutoring")`
- [ ] 첫 응답이 한국어로 개념 소개 (Buffer Pool 정의)
- [ ] thought-experiment 질문 포함 (P1)
- [ ] 사용자로서 답변 제공 (예: "MySQL이 메모리에 데이터를 캐시하는 영역")
- [ ] T1~T4 structural trigger 중 하나 이상 참 시 P5 체크 발동 확인
- [ ] 답변 후 correct/partial 평가 표시
- [ ] learning-log.md 확인 (이벤트 기록 여부 — Task 20 에서 explicit contract 추가될 예정)

### 합격 조건

- 세 단계 모두 에러 없이 완료
- research-results.md 생성됨
- Citations 중 최소 1개 verified=true
- P5 체크가 1회 이상 발동됨 (drllm-core §3 P5.1 T1~T4 중 하나 이상 참인 상황에서)

## 실패 시 진단 (spec §7.4 Rollback Trigger 참조)

- **DRLLM 재link 실패**: `gemini extensions unlink` 명령 없음. `uninstall` 사용 (Setup 참조).
- **S0 실패**: metadata.json 작성 에러 → Task 13 확인
- **S2 fetch 실패**: MCP 연결 또는 URL 문제 → Task 9 재확인 (`/mcp` 로 fetch 상태 확인)
- **Layer 2 Call 1 실패**: response_schema 미지원 또는 스키마 오류 → Task 11
- **Call 2 모든 verified=false**: fetch 결과 파싱 또는 substring match 이슈 (§4.1 normalize 규칙) → Task 12
- **S4 P5 미발동**: drllm-core §3 P5.1 T1~T4 조건 체크 불가 → Task 14 + drllm-core.md 재확인
- **Settings [not set]**: `gemini extensions config DRLLM DRLLM_DOMAIN_PROFILE context/domains/born2beroot.md` + `DRLLM_RESEARCH_MAX_SUBQUERIES 4`
