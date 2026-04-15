#!/usr/bin/env bash
# L3 Aggregation test
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$0")/../.."  # repo root

# Sync fixture file mtimes to started_at so B2 detection doesn't false-positive.
for session_dir in "$DIR/fixtures/sessions"/*/; do
  meta="$session_dir/metadata.json"
  [ -f "$meta" ] || continue
  started=$(jq -r '.started_at' "$meta")
  [ -n "$started" ] && [ "$started" != "null" ] || continue
  touch -d "$started" "$session_dir"/* 2>/dev/null || true
done

actual=$("$PWD/tools/aggregate-metrics.sh" "$DIR/fixtures/sessions")
expected=$(cat "$DIR/expected-output.txt")

if [ "$actual" = "$expected" ]; then
    echo "L3 aggregation: PASS"
else
    echo "L3 aggregation: FAIL" >&2
    echo "--- Expected ---" >&2
    echo "$expected" >&2
    echo "--- Actual ---" >&2
    echo "$actual" >&2
    exit 1
fi
