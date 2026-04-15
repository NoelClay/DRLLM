---
name: drllm-adaptive-tutoring
description: DRLLM tutoring phase. Loads research-results.md and starts an interactive learning dialog in Korean using LearnLM P1-P5 principles (P5 HARD enforced), detects subtopic completion, triggers metacognition retrieval check, logs events to learning-log.md. TRIGGER when drllm-research-execution marker `__drllm_s2_done_*` detected or user invokes `/drllm:tutor`.
---

# S4 — DRLLM Adaptive Tutoring

## Mission (한국어)

S2의 리서치 결과를 바탕으로 사용자와 한국어 학습 대화를 진행한다. LearnLM P1~P5 원칙 적용, 특히 **P5 메타인지 체크 강제**. 모든 대화 이벤트를 `learning-log.md`에 append-only 기록.

## Inputs

- `.drllm/sessions/<session_id>/metadata.json` (status=="tutor" 확인)
- `.drllm/sessions/<session_id>/research-results.md`
- `context/drllm-core.md` 섹션 3 (P5 강제 본문)

## Protocol

### 1. 세션 로드

- `session_id`는 호출 컨텍스트에서 주어진 값, 없으면 `.drllm/sessions/` 에서 `status=="tutor"` 인 가장 최근 항목 선택
- `metadata.json` 로드. `status != "tutor"` → 에러 ("S4는 tutor 상태 세션만 실행")
- `research-results.md` 로드 (필수, 없으면 에러)
- `context/drllm-core.md` 섹션 3 (P5) 재확인 — HARD 원칙 적용

### 2. learning-log.md 초기화

파일이 없으면 frontmatter와 빈 Events 섹션으로 생성:

```markdown
---
topic: <metadata.topic>
session_id: <session_id>
started_at: <metadata.started_at>
completed_at:
status: in_progress
---

## Events

```

### 3. 학습 대화 진행 (한국어)

#### 3.1 오프닝

- research-results.md의 Summary + Key Points를 바탕으로 주제의 **가장 근본적인 개념 하나** 소개 (P2 Manage Cognitive Load)
- 끝에 능동적 질문 1개 (P1 Inspire Active Learning):
  > "여기서 <X>가 0이면 무슨 일이 일어날까?" 같은 thought-experiment

#### 3.2 Subtopic 관리

- 새 subtopic 도입 시 **반드시** learning-log.md 에 다음 이벤트 append:

  ```
  [SUBTOPIC] <subtopic 이름> | <ISO 8601 KST>
  ```

- subtopic 경계 판단 기준:
  - 새 용어가 2개 이상 등장
  - research-results.md의 key_points 중 다른 항목으로 이동
  - 사용자의 질문이 이전 subtopic 범위를 벗어남

#### 3.3 Source 참조 기록

- research-results.md의 citation을 근거로 사용할 때마다 learning-log.md에 append:

  ```
  [SOURCE] fetch::<url> | verified=true
  ```

- 이미 검증된(verified=true) citations만 인용. verified=false는 인용 금지.

#### 3.4 P5 메타인지 체크 (HARD 강제) — v2 Robust

> **Authoritative contract**: `context/drllm-core.md` §3 (P5.1 trigger / P5.2 prompt / P5.3 rubric / P5.4 skip) + §5.3 (learning-log 이벤트 schema) + §6 (HARD STOPS).
> 아래는 S4 구현자가 컨텍스트 전환 없이 따라갈 수 있도록 *참조용 요약*. 해석이 충돌하면 **drllm-core.md 가 authoritative**.

**매 S4 turn 시작 시 (§3 P5.1)**: T1~T4 조건 4개를 learning-log.md + research-results.md 기반 단순 카운트로 평가. **LLM 판단 금지**.

- **T1** — 직전 턴 응답에서 "key_points 용어 중 세션 첫 등장" term 수 ≥ 2
- **T2** — 이번 턴 주제 key_points 인덱스 ≠ 직전 턴 인덱스
- **T3** — 직전 `[P5_CHECK]` 또는 `[P5_MISSING]` 이후 `[SUBTOPIC]` 이벤트 ≥ 2개
- **T4** — 사용자 입력이 `^(이해했어|확인해줘|맞아\?|체크해)` 매치

**하나라도 참 → P5 발동**. 모두 거짓 → P5 불필요(정상).
**하나 이상 참인데 발동 안 함 → `[P5_MISSING] triggers=<매치된 T> | reason="<왜>"` 이벤트 기록 필수** (§0-3, §6-1).

P5 prompt 문자열 (§3 P5.2, 변형 금지):

> "한 문장으로 [X]를 설명해줄 수 있어? 동료를 가르치듯."

`[X]` = research-results.md key_points 중 현재 대상 항목 이름.

평가 rubric (§3 P5.3, **% 금지**):

- **correct** — (a) 해당 key_point 핵심 용어의 **과반(≥ 50%)** 을 사용자 답변에 포함 **AND** (b) 해당 key_point 논리와 모순 없음
- **partial** — (a) 또는 (b) 중 하나만 충족
- **incorrect** — (a)와 (b) 모두 미충족
- **skip** — 사용자 입력이 `^(?i)(넘어가|다음|pass|skip|나중에|됐어|건너뛰|그냥 계속)` 매치, 또는 명확한 회피 의사 (reason 필드에 사용자 문장 인용 기록)

learning-log.md append (§5.3 이벤트 schema + §0-8 Batch side effects + §1.2 Timestamp Acquisition Protocol 준수):

매 turn 종료 직전에 **단일 tool 호출** 로 이벤트 batch append.
이벤트당 개별 `echo >> log` 금지 (turn latency 폭증).
timestamp 는 LLM 직접 생성 금지 — `NOW=$(date -Iseconds)` 로 한 번 capture 후 모든 이벤트에 주입 (§6-8):

```bash
NOW=$(date -Iseconds)
cat >> .drllm/sessions/<session_id>/learning-log.md <<EOF
[SUBTOPIC] <이름> | ${NOW}
[SOURCE] fetch::<url> | verified=true
[P5_CHECK] Q="<질문>" | A="<사용자 답변>" | score=<correct|partial|incorrect>
EOF
```

또는 skip / missing 시 해당 이벤트만 포함:

```
[P5_SKIP] reason="<사용자 문장 인용>"
[P5_MISSING] triggers=T1,T3 | reason="<왜 발동 안 했는지>"
```

평가별 후속 처리 (**톤 가이드** — §6-7 에 따라 literal 응답 이중 출력 금지. 아래 문구를 그대로 쓰지 말고 자연스러운 한국어 응답 **한 번** 에 녹여 넣는다):

- correct → 긍정 확인 + 다음 subtopic 으로 전환 제안
- partial → 부분 인정 + 구체적 수정 또는 추가 설명
- incorrect → 재설명 후 재체크
- skip → `[P5_SKIP]` 기록 후 다음 주제로 자연 전환
- missing (구현자가 발동 실패) → 이벤트 append 에 `[P5_MISSING]` 포함 + 다음 turn 에서 P5 재발동

### 4. 세션 종료

다음 조건 중 하나 발생 시 종료:

- 사용자가 명시적 종료 요청 ("끝내자", "여기까지", "다음에")
- research-results.md의 모든 key_points가 최소 1회 P5_CHECK 통과
- 사용자 비활성 30분 (v0.1에서는 timeout 감지 없음, v0.5+)

종료 절차:

1. `completed_at` 과 `duration_sec` 은 shell 호출로 획득 (§1.2, §6-8). LLM 직접 생성 금지:

   ```bash
   NOW=$(date -Iseconds)
   START_EPOCH=$(date -d "$(jq -r .started_at ".drllm/sessions/${session_id}/metadata.json")" +%s)
   END_EPOCH=$(date +%s)
   DURATION=$((END_EPOCH - START_EPOCH))
   ```

2. learning-log.md append (drllm-core §5.3 [COMPLETE] 이벤트 schema 그대로 — missing 필드 포함):

   ```bash
   cat >> ".drllm/sessions/${session_id}/learning-log.md" <<EOF
   [COMPLETE] total_checks=<N> correct=<C> partial=<P> skip=<S> missing=<M> duration_sec=${DURATION}
   EOF
   ```

3. metadata.json 갱신:

   ```bash
   # NOW, DURATION already captured above
   ```

   ```json
   {
     "completed_at": "${NOW}",
     "status": "done"
   }
   ```

3. 사용자에게 요약 (한국어):

   > "학습 완료. 인출 체크 <N>회 중 <C> correct + <P> partial. 수고하셨어요."

## Event Recording — MUST DO (v2 Robust)

**Authoritative schema**: `context/drllm-core.md` §5.3 (이벤트 6종 포맷) + §6 (HARD STOPS).

매 turn 종료 전 다음을 확인하여 learning-log.md 에 append (append-only, §0-3 No silent drop):

1. **[SUBTOPIC]**: 새 subtopic 도입 (키포인트 전환) 시
2. **[SOURCE]**: research-results.md verified citation 인용 시
3. **[P5_CHECK]**: P5 발동 + 사용자 답변 + score 평가 완료 시
4. **[P5_SKIP]**: 사용자 응답이 skip 정규식 매치 또는 회피 의사 표명 시 (reason 필수)
5. **[P5_MISSING]**: §3 P5.1 T1~T4 조건 중 하나 이상 참이었으나 P5 발동하지 않은 턴 — **반드시 기록**. triggers 필드에 매치된 T 열거.
6. **[COMPLETE]**: 세션 종료 시 (집계: total_checks, correct, partial, skip, **missing**, duration_sec)

파일 쓰기는 내부 tool(예: `edit_file` 또는 `write_file`)로 append-only.

**형식 예시**:

    [SUBTOPIC] Buffer Pool 정의 | 2026-04-14T10:31:00+09:00
    [SOURCE] fetch::dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool.html | verified=true
    [P5_CHECK] Q="Buffer Pool을 한 문장으로" | A="MySQL이 디스크 대신 메모리에 데이터 페이지를 캐시" | score=correct
    [P5_SKIP] reason="user_requested_skip"
    [P5_MISSING] triggers=T1,T3 | reason="implementer failed to evaluate triggers"
    [COMPLETE] total_checks=3 correct=2 partial=1 skip=0 missing=0 duration_sec=1247

Hard Gate: 이벤트 기록 생략 → 측정 지표 무효 → 세션 M1 POC 제외 (§6-1).

## Hard Gate

- status != "tutor" → 에러 반환
- research-results.md 부재 → 에러 반환 (S2 재실행 안내)
- P5 체크 발동 시점 도달했는데 생략 → **절대 금지**. 생략하면 측정 지표 무효 (§0-3 No silent drop, §6-1). `[P5_MISSING]` 이벤트 기록 필수.
- verified=false citation 인용 → **절대 금지** (§6-4)

## Outputs

- `.drllm/sessions/<session_id>/learning-log.md` (append-only)
- metadata.json 갱신 (`completed_at`, `status`)

## See Also

- `@./context/drllm-core.md` 섹션 3 (LearnLM P5), 섹션 6 (HARD STOPS)
