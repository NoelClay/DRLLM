# Step 2 Smoke Test — 3 스킬 로딩 확인

## Setup

```bash
cd /home/namykim/workspace/DRLLM
gemini extensions link .
```

## Checklist

- [ ] `gemini` 진입 후 `/extensions list` 에서 `DRLLM 0.1.0 active` 행 확인
- [ ] `ls ~/.gemini/extensions/` 에서 DRLLM → 본 repo 로의 symlink 존재 확인
- [ ] Gemini 대화창에서 `activate_skill("drllm-launcher")` 수동 호출 → `S0 — DRLLM Launcher` 헤더 반환 확인
- [ ] `activate_skill("drllm-research-execution")` 수동 호출 → `S2 — DRLLM Research Execution` 헤더 반환 확인
- [ ] `activate_skill("drllm-adaptive-tutoring")` 수동 호출 → `S4 — DRLLM Adaptive Tutoring` 헤더 반환 확인
- [ ] `/drllm:` 자동완성으로 3개 command (launch, research, tutor) 모두 표시 + 각각 description 비어있지 않음 확인

## 실패 시 (진단 래더 — §0-5 Fail loud)

- **DRLLM 미표시** (`/extensions list` 결과에 없음):
  1. `~/.gemini/extensions/DRLLM` symlink 존재 확인 — 없으면 Setup 의 `gemini extensions link .` 재실행
  2. 존재하지만 inactive → `gemini extensions enable DRLLM`
  3. 그래도 안 되면 `gemini-extension.json` schema 오류 → Task 1 재확인 (`jq empty gemini-extension.json`)
- **activate_skill 실패**: SKILL.md frontmatter `name` 필드 문자열 mismatch → Tasks 5/6/7 각각의 `name:` 값 확인 (`drllm-launcher` / `drllm-research-execution` / `drllm-adaptive-tutoring`)
- **command 미표시 또는 description 빈 채**: TOML 파싱 오류 → `commands/drllm/{launch,research,tutor}.toml` 각각의 `description =` / `prompt =` 필드 존재 + quote 짝 확인
