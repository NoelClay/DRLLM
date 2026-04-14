# Step 4 Smoke Test — 자동 체인 검증

## Setup

```bash
cd /home/namykim/workspace/DRLLM
gemini extensions uninstall DRLLM 2>/dev/null; gemini extensions link .
rm -rf .drllm/sessions/
```

## Scenario: InnoDB Buffer Pool (hook 자동 체인)

### 사전 검증 (Task 18 gate)

Gemini 진입 후 먼저:
- [ ] `/hooks` — AfterTool match `save_memory` hook 등록 확인
- [ ] Hook `command` 필드가 **절대경로로 resolve** 되어 표시되는지 확인 (`${workspacePath}` 이 `/home/namykim/workspace/DRLLM` 으로 치환). 리터럴 문자열 그대로면 v0.37.1 템플릿 키 미스매치 → plan 재확인.

### 단일 명령으로 end-to-end

- [ ] Gemini 진입 후: `/drllm:launch InnoDB Buffer Pool 왜 128MiB?`
- [ ] 관찰: S0 실행 후 사용자 개입 없이 자동으로 S2 활성화 (Gemini 출력에 "S2 activate" 로그 또는 research 진행 표시)
- [ ] 관찰: S2 완료 후 자동으로 S4 활성화 (학습 대화 시작)
- [ ] Hook stderr 로그 확인 (Gemini CLI를 실행한 터미널의 stderr — TUI 외부 스크롤 영역 또는 `GEMINI_DEBUG=1` 로 재실행하여 확인):
  ```
  [drllm-hook] S0 done detected → chain to drllm-research-execution
  [drllm-hook] S2 done detected → chain to drllm-adaptive-tutoring
  ```
  (stderr 가 TUI 로 숨겨지는 경우 Task 16 의 `echo >&2` 동작 재확인 필요)

### 합격 조건

- `/drllm:launch <topic>` 한 번으로 S4 대화까지 도달
- 사용자가 "activate_skill" 수동 호출 안 함
- .drllm/sessions/ 에 metadata.json + research-results.md 모두 생성:
  ```bash
  ls .drllm/sessions/*/ | grep -E 'metadata.json|research-results.md'
  jq '.status, .url_verify_ratio' .drllm/sessions/*/metadata.json
  ```
- hook 무한 루프 없음. 정상 완료 신호: S4 첫 응답 출력 후 hook 로그에 추가 chain 라인 없음, Gemini TUI가 사용자 입력 대기 상태로 복귀

## 실패 시

- 자동 체인 안 됨: `/hooks` 로 등록 확인 → Task 18 재확인
- `${workspacePath}` 리터럴 그대로 표시됨: Gemini CLI 템플릿 키 변경 가능성. 절대경로로 하드코딩하여 재시도 후 Task 18 plan 재조정.
- 무한 루프: hook script의 stop_hook_active 체크 → Task 16
- tailToolCallRequest 오류: JSON schema 재확인 → Task 16 hook output
- S2 단계에서 체인 끊김 (S0→S2 는 성공, S2→S4 안 됨): `DRLLM_DOMAIN_PROFILE` / `DRLLM_RESEARCH_MAX_SUBQUERIES` 환경변수 미설정 가능성. `gemini extensions config DRLLM DRLLM_DOMAIN_PROFILE context/domains/born2beroot.md` + `gemini extensions config DRLLM DRLLM_RESEARCH_MAX_SUBQUERIES 4` 로 설정 후 재시도 (smoke-step3.md 참조).
