#!/usr/bin/env bash
# L1 Schema validation — gemini-extension.json + SKILL.md frontmatter
set -euo pipefail

fail() { echo "FAIL: $1" >&2; exit 1; }

# Require mikefarah yq v4 (apt yq = kislyuk python-yq wrapper, incompatible 문법).
# 다른 환경에서 조용히 mispass 하는 것 방지 (§0-5 Fail loud, §0-7 Environment contract).
if ! yq --version 2>&1 | grep -qi 'mikefarah'; then
  fail "yq mikefarah v4 required (found: $(yq --version 2>&1 || echo none)). Install: sudo snap install yq"
fi

# gemini-extension.json
jq -e '.name and .description and .version and .contextFileName' \
  gemini-extension.json > /dev/null \
  || fail "gemini-extension.json missing required fields"

# GEMINI.md must @import drllm-core — exact line or followed by space/tab only.
# 이전 패턴은 @./context/drllm-core.md-extra 같은 typo-mutation 을 silently pass 했음.
grep -Eq '^@\./context/drllm-core\.md([[:space:]]|$)' GEMINI.md \
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
