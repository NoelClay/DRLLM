#!/usr/bin/env bash
# DRLLM AfterTool hook: save_memory marker → activate_skill chain
set -euo pipefail

input=$(cat)

# Infinite loop guard
if [ "$(echo "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
    echo '{}'
    exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // ""')
tool_input=$(echo "$input" | jq -r '.tool_input | tostring')

# S0 done → S2 chain
if [ "$tool_name" = "save_memory" ] && echo "$tool_input" | grep -q '__drllm_s0_done_'; then
    echo >&2 "[drllm-hook] S0 done detected → chain to drllm-research-execution"
    cat <<'EOF'
{"hookSpecificOutput":{"tailToolCallRequest":{"name":"activate_skill","args":{"skill_name":"drllm-research-execution"}}}}
EOF
    exit 0
fi

# S2 done → S4 chain
if [ "$tool_name" = "save_memory" ] && echo "$tool_input" | grep -q '__drllm_s2_done_'; then
    echo >&2 "[drllm-hook] S2 done detected → chain to drllm-adaptive-tutoring"
    cat <<'EOF'
{"hookSpecificOutput":{"tailToolCallRequest":{"name":"activate_skill","args":{"skill_name":"drllm-adaptive-tutoring"}}}}
EOF
    exit 0
fi

# Unrelated tool: pass-through
echo '{}'
