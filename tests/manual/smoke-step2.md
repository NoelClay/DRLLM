# Step 2 Smoke Test — 3 스킬 로딩 확인

## Setup

```bash
cd /home/namykim/workspace/DRLLM
gemini extensions link .
```

## Checklist

- [ ] `gemini` 진입 후 `/extensions` 명령으로 DRLLM 표시 확인
- [ ] `/extensions drllm` 으로 버전 0.1.0, 3 skills, 3 commands 표시
- [ ] Gemini 대화창에서 `activate_skill("drllm-launcher")` 수동 호출 → S0 본문("S0 — DRLLM Launcher") 반환 확인
- [ ] `activate_skill("drllm-research-execution")` 수동 호출 → S2 본문 반환 확인
- [ ] `activate_skill("drllm-adaptive-tutoring")` 수동 호출 → S4 본문 반환 확인
- [ ] `/drllm:launch` 자동완성으로 3개 command 표시 확인 (launch, research, tutor)

## 실패 시

- DRLLM 미표시: `gemini-extension.json` 오류 → Task 1 재확인
- activate_skill 실패: SKILL.md frontmatter `name` 필드 문자열 mismatch → Task 5~7 name 확인
- command 미표시: TOML 오류 → 각 toml 파일 `description` / `prompt` 필드 확인
