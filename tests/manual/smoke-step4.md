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
- [ ] stderr 에서 hook 로그 확인:
  ```
  [drllm-hook] S0 done detected → chain to drllm-research-execution
  [drllm-hook] S2 done detected → chain to drllm-adaptive-tutoring
  ```

### 합격 조건

- `/drllm:launch <topic>` 한 번으로 S4 대화까지 도달
- 사용자가 "activate_skill" 수동 호출 안 함
- .drllm/sessions/ 에 metadata.json + research-results.md 모두 생성
- hook 무한 루프 없음 (세션이 정상 완료됨)

## 실패 시

- 자동 체인 안 됨: `/hooks` 로 등록 확인 → Task 18 재확인
- `${workspacePath}` 리터럴 그대로 표시됨: Gemini CLI 템플릿 키 변경 가능성. 절대경로로 하드코딩하여 재시도 후 Task 18 plan 재조정.
- 무한 루프: hook script의 stop_hook_active 체크 → Task 16
- tailToolCallRequest 오류: JSON schema 재확인 → Task 16 hook output
