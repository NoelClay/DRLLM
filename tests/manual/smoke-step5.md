# Step 5 Smoke Test — 측정 로직 end-to-end

## Setup

```bash
cd /home/namykim/workspace/DRLLM
gemini extensions uninstall DRLLM 2>/dev/null; gemini extensions link .
rm -rf .drllm/sessions/
```

## Scenario: InnoDB 세션 + 측정 확인

### 전체 플로우

- [ ] `/drllm:launch InnoDB Buffer Pool 왜 128MiB?`
- [ ] 자동 체인으로 S2/S4 도달 (Task 19 smoke 재확인)
- [ ] S4 학습 대화 진행하며 최소 2회 P5 체크 발동 확인
- [ ] 사용자 답변 후 평가 (correct/partial) 응답 확인
- [ ] 1회는 의도적으로 "나중에" 입력하여 skip 테스트

### 파일 검증

- [ ] `learning-log.md` 확인:
  ```bash
  cat .drllm/sessions/*/learning-log.md
  ```
  - `[SUBTOPIC]` 1개 이상
  - `[SOURCE]` 1개 이상
  - `[P5_CHECK]` 2개 이상 (score 포함)
  - `[P5_SKIP]` 1개
  - `[COMPLETE]` 1개 (세션 완료 시)

- [ ] `metadata.json` 확인:
  ```bash
  jq '.url_verify_total, .url_verify_count, .url_verify_ratio, .status, .completed_at' .drllm/sessions/*/metadata.json
  ```
  - `url_verify_total >= 1`
  - `url_verify_count >= 1`
  - `url_verify_ratio >= 0.0`
  - `status == "done"`
  - `completed_at` 존재 (non-null)

### B3 fetch-only 검증 (v0.1 예방적 체크)

- [ ] S2 활성 turn 중 tool 호출 로그에 `GoogleSearch` / `WebFetch` 없음 확인:
  ```bash
  # Gemini CLI 실행 터미널 출력에서 검색
  # 아래 패턴이 나오면 B3 위반 — §6-10 HARD STOP 발동 대상
  grep -i 'GoogleSearch\|WebFetch\|search_web' <gemini-session-log> || echo "B3 clean"
  ```
  - `GoogleSearch` / `WebFetch` 라인 없음 → B3 clean (합격)
  - 만약 출현 시: aggregate stderr 에 `[EXTERNAL_TOOL_LEAK]` 기록 여부 확인 (현재 v0.1 — aggregate 에서는 미감지, preventive rule 만 적용. SP-2 BeforeToolSelection hook 에서 차단 예정)

### B1/B2 invalid-counter 검증

- [ ] aggregate 실행 후 healthy session 에서 3개 카운터 모두 0:
  - `[P5_MISSING]: 0` — P5 trigger 발동 시 모두 기록됨
  - `[INVALID_CITATION_COUNT]: 0` — Citations 테이블 row == url_verify_count
  - `[INVALID_TIMESTAMP]: 0` — started_at / completed_at shell 획득 (§1.2)

### aggregate 실행

- [ ] `./tools/aggregate-metrics.sh` 실행:
  ```
  === DRLLM M1 POC Aggregate Metrics ===
  Sessions total:   1
  Sessions done:    1
  Sessions invalid:
    [P5_MISSING]:             0
    [INVALID_CITATION_COUNT]: 0
    [INVALID_TIMESTAMP]:      0
  --------------------------------------
  P5 score:         <N> (필수 >= 0.700)
  URL verify:       <N> (필수 >= 0.950)
  Skip ratio:       <N> (기록만)
  Complete ratio:   <N> (기록만)
  --------------------------------------
  Detail:
    P5 checks:      <N> (correct=<N> partial=<N>)
    P5 skips:       <N>
    P5 missing:     <N> (§6-1 위반 기록)
    Citations:      <N> (verified=<N>)
  ```
- [ ] P5 score, URL verify 모두 유효 숫자 (0.000 이상)
- [ ] 3개 invalid 카운터 모두 0 (healthy session 조건)

### 합격 조건

- learning-log.md 모든 이벤트 타입 최소 1개 이상
- metadata.json url_verify 필드 3개 모두 채워짐
- aggregate 스크립트 에러 없이 실행
- aggregate 출력에서 `[P5_MISSING]: 0`, `[INVALID_CITATION_COUNT]: 0`, `[INVALID_TIMESTAMP]: 0`
- S2 turn 에 `GoogleSearch` / `WebFetch` 호출 없음 (B3 v0.1 예방 규칙 준수)

## 실패 시

- learning-log 빈 채로: Task 20 S4 이벤트 기록 지침 재확인
- url_verify 필드 0 채로: Task 21 S2 metadata 갱신 지침 재확인
- aggregate NaN 또는 0/0: 스크립트 safe division 재확인 (Task 22)
- `[INVALID_CITATION_COUNT]: 1` 이상: S2 §6.1 Citations 테이블 self-check (B1) 재확인
- `[INVALID_TIMESTAMP]: 1` 이상: drllm-core §1.2 shell 획득 여부 확인 (B2)
- S2 turn 에 `GoogleSearch` 출현: S2 SKILL.md §3.1 + drllm-core §6-10 규칙 지침 재확인 (B3)
