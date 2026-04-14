#!/usr/bin/env bats

setup() {
  HOOK="./hooks/auto-chain-skills.sh"
}

@test "S0 완료 → S2 체인" {
  run bash -c 'echo "{\"tool_name\":\"save_memory\",\"tool_input\":\"__drllm_s0_done_xxx\",\"stop_hook_active\":false}" | '"$HOOK"
  [ "$status" -eq 0 ]
  skill=$(echo "$output" | tail -1 | jq -r '.hookSpecificOutput.tailToolCallRequest.args.skill_name')
  [ "$skill" = "drllm-research-execution" ]
}

@test "S2 완료 → S4 체인" {
  run bash -c 'echo "{\"tool_name\":\"save_memory\",\"tool_input\":\"__drllm_s2_done_xxx\",\"stop_hook_active\":false}" | '"$HOOK"
  [ "$status" -eq 0 ]
  skill=$(echo "$output" | tail -1 | jq -r '.hookSpecificOutput.tailToolCallRequest.args.skill_name')
  [ "$skill" = "drllm-adaptive-tutoring" ]
}

@test "stop_hook_active=true → 조용히 통과" {
  run bash -c 'echo "{\"tool_name\":\"save_memory\",\"tool_input\":\"__drllm_s0_done_xxx\",\"stop_hook_active\":true}" | '"$HOOK"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "관련 없는 tool → 조용히 통과" {
  run bash -c 'echo "{\"tool_name\":\"read_file\",\"tool_input\":\"foo.txt\",\"stop_hook_active\":false}" | '"$HOOK"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "save_memory지만 drllm marker 아님 → pass-through" {
  run bash -c 'echo "{\"tool_name\":\"save_memory\",\"tool_input\":\"unrelated\",\"stop_hook_active\":false}" | '"$HOOK"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}
