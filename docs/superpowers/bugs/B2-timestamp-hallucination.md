# B2 — Timestamp hallucination (started_at / generated_at)

**Severity**: Important
**Status**: open
**Scheduled**: Task 20 + `drllm-core.md` §1 / §5 (timestamp 획득 계약 추가)
**Filed**: 2026-04-15 (STEP 4 smoke, M1 2차 InnoDB 세션)

## Observed

Session: `.drllm/sessions/20260415-innodb-buffer-pool-default-size/`

실제 파일 생성 시각: **2026-04-15 11:40 KST** (`ls -la` mtime).

`metadata.json`:
```json
"started_at": "2026-04-15T14:30:00+09:00"
```

`research-results.md` frontmatter:
```
generated_at: 2026-04-15T15:00:00+09:00
```

`learning-log.md` frontmatter:
```
started_at: 2026-04-15T14:30:00+09:00
```

**실제 시각 ≠ LLM 생성 시각**. LLM 이 현재 시각을 모르기 때문에 plausible 한 "오후 시간"을 hallucinate 한 것.

Duration 계산 (M1 §4 지표 `duration_sec`) 이 hallucinate 된 timestamp 에 의존하면 측정 무효화.

## 재현 경로

S0 Protocol §5 — `metadata.json` 작성 시 `started_at` 채움.
S2 Protocol §7 — `research-results.md` frontmatter 에 `generated_at` 채움.
S4 Protocol §2 — `learning-log.md` frontmatter 에 `started_at` 복사.

세 지점 모두 "ISO 8601 KST" 문자열을 **LLM 이 직접 생성** → 현재 시각 모름 → hallucination.

## Root Cause Hypothesis

`drllm-core.md` §1 (File Resolution) 와 §5 (Strict Schemas) 에 timestamp 획득 방법이 명시 안 됨. "ISO 8601 KST" 를 요구만 하고 `date -Iseconds` 등 shell 호출을 강제하지 않음.

LLM 은 약간의 training cutoff 정보 + 대화 문맥 (system prompt 의 "2026-04-15") 로 추측하여 오후 시간 생성. 결과: 날짜는 맞지만 시각은 임의.

## Fix Plan

### drllm-core.md 수정 (STEP 5 진입 전 즉시)

§1.2 Timestamp Acquisition Protocol (신설):

> 모든 `started_at` / `generated_at` / `completed_at` 필드는 **LLM 이 직접 작성 금지**. 반드시 아래 shell 명령의 stdout 을 그대로 삽입:
> ```bash
> date -Iseconds   # 예: 2026-04-15T11:40:23+09:00
> ```
> HARD STOP: 해당 필드를 shell 호출 없이 채우면 drllm-core §6 HARD STOP-8 위반.

§6 HARD STOPS 에 추가:

> 8. timestamp 필드 (`started_at`, `generated_at`, `completed_at`, `[SUBTOPIC]`/`[SOURCE]`/`[P5_CHECK]` 이벤트 tail) 는 `date -Iseconds` shell 호출로만 획득. LLM 직접 생성 금지.

### S0 / S2 / S4 SKILL.md 수정

Protocol 내 metadata/research-results/learning-log 작성 blocks 에서 `date -Iseconds` 를 heredoc/write_file 직전에 호출하도록 구체화.

예 (S0 §5 수정):
```bash
NOW=$(date -Iseconds)
cat > .drllm/sessions/<session_id>/metadata.json <<EOF
{
  ...
  "started_at": "${NOW}",
  ...
}
EOF
```

(v2.1 §0-8 Batch side effects 와 호환 — NOW 변수 한 번 capture 후 여러 파일에 주입)

### Task 20 검증 추가

L3 aggregation 스크립트에서:
- `started_at` 파싱 후 현실적 범위 (2025~ 미래) 검증
- `completed_at - started_at = duration_sec` 수식 일관성
- timestamp 가 file mtime 과 ±60초 이내

불일치 시 `[INVALID_TIMESTAMP]` 이벤트 기록 + session 은 aggregate 에서 제외.

## Verification

Fix 후:
- 새 smoke 실행 → `ls -la` mtime 과 metadata.json `started_at` ±60초 이내
- M1 POC 3 시나리오 (Task 25-27) 100% timestamp 현실성 검증
- `duration_sec` 필드가 실제 경과 시간과 일치 (이전 InnoDB 1차는 `duration_sec=3300` 즉 55분으로 기록됐는데 실제 세션 duration 이 그랬는지 재검토 필요)

## 연관 위험

이전 세션 `20260414-innodb-buffer-pool-default-size` 의 `[COMPLETE] duration_sec=3300` 도 LLM hallucination 일 가능성. 소급 검증 필요 (B2 fix 후 세션 내 event timestamp 일관성 확인).
