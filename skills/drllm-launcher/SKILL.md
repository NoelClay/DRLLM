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

### 1. 주제 파싱

- slash command 경로: `{{args}}` 에서 주제 추출
- 자연어 경로: 사용자 메시지에서 "학습 시작 / 공부" 전후 문구에서 주제 추출
- 주제가 비어있으면 재입력 요청 후 종료 (아래 Hard Gate 참조)

### 2. slug 생성 (LLM 호출)

다음 규칙으로 topic → kebab-case 영어 slug 변환:

- 최대 영어 20자
- 주요 명사 2~3개로 축약 (예: "InnoDB Buffer Pool 왜 128MiB?" → `innodb-buffer-pool-default-size`)
- 한국어 주제면 영어로 번역 후 slug화
- 불용어(the, a, and, why, what 등) 제거
- 하이픈 구분, 소문자만

### 3. 세션 ID 생성

````bash
date_prefix=$(date +%Y%m%d)
session_id="${date_prefix}-${slug}"

# 충돌 처리
if [ -d ".drllm/sessions/${session_id}" ]; then
  for suffix in 2 3 4 5; do
    candidate="${session_id}-${suffix}"
    [ ! -d ".drllm/sessions/${candidate}" ] && session_id="${candidate}" && break
  done
fi
````

LLM은 위 로직을 shell 명령 혹은 Python으로 실행하여 최종 session_id 확정.

### 4. 디렉토리 생성

````bash
mkdir -p ".drllm/sessions/${session_id}"
````

### 5. metadata.json 작성

다음 schema 정확히 준수하여 `.drllm/sessions/${session_id}/metadata.json` 작성:

````json
{
  "session_id": "<session_id>",
  "topic": "<원본 주제, 한국어 OK>",
  "slug": "<slug>",
  "domain": "born2beroot",
  "started_at": "<ISO 8601 with KST offset, e.g. 2026-04-14T10:30:00+09:00>",
  "completed_at": null,
  "status": "research",
  "url_verify_total": 0,
  "url_verify_count": 0,
  "url_verify_ratio": 0.0
}
````

### 6. 사용자에게 알림 (한국어)

> "세션 `<session_id>` 시작. 주제: <topic>. 리서치 진행 중..."

### 7. Marker tool 호출

`save_memory("__drllm_s0_done_<session_id>")`

## Hard Gate

- 주제 없음/공백: 사용자에게 "학습하고 싶은 주제를 알려주세요 (예: 'InnoDB Buffer Pool의 기본값')" 요청 + 세션 미생성 + marker 미호출
- 디렉토리 생성 실패: stderr 에러 출력 + marker 미호출
- metadata.json 작성 실패: 방금 생성한 세션 디렉토리 rm -rf 후 에러 보고

## Outputs

- `.drllm/sessions/<session_id>/metadata.json`
- marker tool 호출 (후속 체인 트리거)

## See Also

- `@./context/drllm-core.md` 섹션 5 (세션 상태 파일)
- Command: `/drllm:launch`
