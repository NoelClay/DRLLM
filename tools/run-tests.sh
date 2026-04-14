#!/usr/bin/env bash
# DRLLM v0.1 test runner entry point
set -euo pipefail

echo "=== L1 Schema ==="
./tests/schema/test-extension.sh

if command -v bats >/dev/null 2>&1 && [ -d tests/hooks ] && ls tests/hooks/*.bats >/dev/null 2>&1; then
  echo "=== L2 Hooks (bats) ==="
  bats tests/hooks/
else
  echo "=== L2 Hooks: SKIP (bats not installed or no tests yet) ==="
fi

if [ -f tests/aggregation/test.sh ]; then
  echo "=== L3 Aggregation ==="
  ./tests/aggregation/test.sh
else
  echo "=== L3 Aggregation: SKIP (not yet implemented) ==="
fi

echo ""
echo "Automated tests: PASS"
echo "Manual smoke: see tests/manual/smoke-step*.md"
