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

## Protocol (상세는 Task 14에서 확장)

1. metadata.json 로드, status=="tutor" 확인
2. research-results.md 로드
3. `learning-log.md` 초기화 (frontmatter + 빈 Events)
4. **대화 시작 (한국어)**:
   - 첫 응답: research 결과 기반 개념 소개
   - 새로운 subtopic 시작 시 `[SUBTOPIC]` 이벤트 기록
   - subtopic 완료 감지 시 (LLM 판단) → **P5 체크 강제**:
     "한 문장으로 [X]를 설명해줄 수 있어?"
   - 사용자 답변 평가 (correct/partial/incorrect/skip)
   - `[P5_CHECK]` 또는 `[P5_SKIP]` 이벤트 기록
5. **세션 종료** (사용자 종료 요청 또는 자연스러운 완료):
   - `[COMPLETE]` 이벤트 기록 (total_checks, correct, partial, skip, duration_sec)
   - metadata.json 갱신: `completed_at`, `status="done"`

## Hard Gate

- status != "tutor" → 에러 반환
- research-results.md 부재 → 에러 반환 (S2 재실행 안내)
- P5 체크 생략 절대 금지 (subtopic 완료 감지 시 반드시 발동)
- verified=false citation 인용 → **절대 금지**

## Outputs

- `.drllm/sessions/<session_id>/learning-log.md` (append-only)
- metadata.json 갱신 (`completed_at`, `status`)

## See Also

- `@./context/drllm-core.md` 섹션 3 (LearnLM P5), 섹션 6 (HARD STOPS)
