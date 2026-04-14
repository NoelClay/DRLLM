#!/usr/bin/env bash
# L1 Schema validation — gemini-extension.json + SKILL.md frontmatter
set -euo pipefail

fail() { echo "FAIL: $1" >&2; exit 1; }

# gemini-extension.json
jq -e '.name and .description and .version and .contextFileName' \
  gemini-extension.json > /dev/null \
  || fail "gemini-extension.json missing required fields"

# GEMINI.md must @import drllm-core
grep -q '^@\./context/drllm-core\.md' GEMINI.md \
  || fail "GEMINI.md must @import context/drllm-core.md"

# drllm-core.md exists
[ -f context/drllm-core.md ] \
  || fail "context/drllm-core.md missing"

# Domain profile exists
[ -f context/domains/born2beroot.md ] \
  || fail "context/domains/born2beroot.md missing"

# SKILL.md frontmatter check (only if skills/ exists with content)
if [ -d skills ] && [ "$(ls -A skills 2>/dev/null)" ]; then
  for skill in skills/*/SKILL.md; do
    [ -f "$skill" ] || continue
    # Extract frontmatter between first two '---' lines
    front=$(awk '/^---$/{c++; if (c==2) exit; next} c==1' "$skill")
    echo "$front" | yq -e '.name and .description' > /dev/null \
      || fail "$skill frontmatter missing name or description"
  done
fi

echo "L1 schema: PASS"
