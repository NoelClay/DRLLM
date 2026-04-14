---
name: drllm-launcher
description: DRLLM session entry point. Parses user topic, generates session slug via LLM, initializes .drllm/sessions/ directory, and chains to research-execution. TRIGGER when user invokes `/drllm:launch <topic>` or says "DRLLM으로 ... 학습 시작" / "DRLLM으로 ...에 대해 공부하자" in Korean or equivalent in English.
---

# S0 — DRLLM Launcher

## Mission (한국어)

사용자가 제공한 주제로 DRLLM 학습 세션을 시작한다. 세션 디렉토리 초기화 + 메타데이터 기록 + 다음 스킬(`drllm-research-execution`) 자동 체인.

## Inputs

- `topic`: 사용자가 학습하고 싶은 주제 (한 문장)
- (optional) `domain`: 도메인 프로파일 이름 (v0.1 기본 `born2beroot`)

## Protocol

1. **주제 파싱**: 사용자 입력에서 topic 추출. 주제가 없거나 공백이면 재입력 요청 후 종료.
2. **slug 생성**: topic을 kebab-case 영어 slug로 변환 (예: "InnoDB Buffer Pool 왜 128MiB?" → `innodb-buffer-pool-default-size`). 규칙:
   - 영어 20자 이내
   - 주요 명사 중심, 불용어 제거
   - 하이픈 구분
3. **세션 ID 생성**: `$(date +%Y%m%d)-<slug>`. 디렉토리 존재 시 `-2`, `-3` 접미사 순환.
4. **디렉토리 생성**: `.drllm/sessions/<session_id>/`
5. **metadata.json 작성** (아래 schema):

```json
{
  "session_id": "<YYYYMMDD>-<slug>",
  "topic": "<원본 주제>",
  "slug": "<slug>",
  "domain": "born2beroot",
  "started_at": "<ISO 8601 KST>",
  "completed_at": null,
  "status": "research",
  "url_verify_total": 0,
  "url_verify_count": 0,
  "url_verify_ratio": 0.0
}
```

6. **사용자에게 세션 시작 알림** (한국어): "세션 `<session_id>` 시작. 리서치 진행..."
7. **Marker tool 호출**: `save_memory("__drllm_s0_done_<session_id>")` — AfterTool hook이 감지하여 `drllm-research-execution` 자동 활성화.

## Hard Gate

- 주제 없음 → 재입력 요청, 세션 미생성, marker tool 호출 금지
- metadata.json 작성 실패 → 사용자에게 에러 보고, marker tool 호출 금지

## Outputs

- `.drllm/sessions/<session_id>/metadata.json`
- marker tool 호출 (후속 체인 트리거)

## See Also

- `@./context/drllm-core.md` 섹션 5 (세션 상태 파일)
- Command: `/drllm:launch`
