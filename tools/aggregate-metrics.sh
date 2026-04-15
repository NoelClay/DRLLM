#!/usr/bin/env bash
# M1 POC aggregate metrics from .drllm/sessions/*/
set -euo pipefail

SESSIONS_DIR="${1:-.drllm/sessions}"

if [ ! -d "$SESSIONS_DIR" ]; then
    echo "No sessions directory: $SESSIONS_DIR" >&2
    exit 1
fi

total_checks=0
correct=0
partial=0
skip=0
missing=0
total_sources=0
verified_sources=0
completed=0
total_sessions=0
invalid_sessions=0

# B1/B2 invalid-session counters
invalid_citation_count_sessions=0
invalid_timestamp_sessions=0

# B3 EXTERNAL_TOOL_LEAK: preventive in Task 24 — no aggregate detection here.

for session in "$SESSIONS_DIR"/*/; do
    [ -d "$session" ] || continue
    total_sessions=$((total_sessions + 1))
    log="$session/learning-log.md"
    meta="$session/metadata.json"
    results="$session/research-results.md"
    session_id="$(basename "$session")"

    if [ -f "$log" ]; then
        cc=$(grep -c '^\[P5_CHECK\]' "$log" 2>/dev/null || true); cc=${cc:-0}
        co=$(grep '^\[P5_CHECK\]' "$log" 2>/dev/null | grep -c 'score=correct' || true); co=${co:-0}
        pa=$(grep '^\[P5_CHECK\]' "$log" 2>/dev/null | grep -c 'score=partial' || true); pa=${pa:-0}
        sk=$(grep -c '^\[P5_SKIP\]' "$log" 2>/dev/null || true); sk=${sk:-0}
        ms=$(grep -c '^\[P5_MISSING\]' "$log" 2>/dev/null || true); ms=${ms:-0}
        total_checks=$((total_checks + cc))
        correct=$((correct + co))
        partial=$((partial + pa))
        skip=$((skip + sk))
        missing=$((missing + ms))
        # Robust §0-3: [P5_MISSING] 발생 세션은 측정 무효 후보 (M1 POC 제외 권고)
        if [ "$ms" -gt 0 ]; then
            invalid_sessions=$((invalid_sessions + 1))
        fi
    fi

    if [ -f "$meta" ]; then
        t=$(jq -r '.url_verify_total // 0' "$meta")
        v=$(jq -r '.url_verify_count // 0' "$meta")
        total_sources=$((total_sources + t))
        verified_sources=$((verified_sources + v))
        [ "$(jq -r '.status' "$meta")" = "done" ] && completed=$((completed + 1))

        # ── B1: [INVALID_CITATION_COUNT] detection ──────────────────────────
        b1_flagged=0
        meta_status=$(jq -r '.status // "null"' "$meta")
        # If status == "research_failed", flag as invalid (S2 self-check blocked)
        if [ "$meta_status" = "research_failed" ]; then
            b1_flagged=1
            echo "[INVALID_CITATION_COUNT] session=${session_id} status=research_failed" >&2
        fi
        # If research-results.md exists, compare citation table rows vs url_verify_count
        if [ -f "$results" ]; then
            row_count=$(grep -c '^| [0-9]' "$results" 2>/dev/null || true)
            row_count=${row_count:-0}
            url_verify_count=$(jq -r '.url_verify_count // 0' "$meta")
            if [ "$row_count" != "$url_verify_count" ]; then
                b1_flagged=1
                echo "[INVALID_CITATION_COUNT] session=${session_id} table=${row_count} meta=${url_verify_count}" >&2
            fi
        fi
        if [ "$b1_flagged" -gt 0 ]; then
            invalid_citation_count_sessions=$((invalid_citation_count_sessions + 1))
        fi

        # ── B2: [INVALID_TIMESTAMP] detection ───────────────────────────────
        b2_flagged=0
        started_at=$(jq -r '.started_at // "null"' "$meta")
        completed_at=$(jq -r '.completed_at // "null"' "$meta")

        if [ "$started_at" != "null" ] && [ -n "$started_at" ]; then
            # Try to parse started_at as ISO8601 with GNU date
            started_epoch=$(date -d "$started_at" +%s 2>/dev/null || echo "")
            if [ -z "$started_epoch" ]; then
                # Unparseable ISO8601
                b2_flagged=1
                mtime=$(stat --format="%Y" "$meta" 2>/dev/null || echo "0")
                echo "[INVALID_TIMESTAMP] session=${session_id} started_at=${started_at} mtime=${mtime} reason=unparseable" >&2
            else
                # Compare started_at epoch vs file mtime (1 day tolerance)
                mtime=$(stat --format="%Y" "$meta" 2>/dev/null || echo "0")
                diff_sec=$(( started_epoch - mtime ))
                if [ "$diff_sec" -lt 0 ]; then
                    diff_sec=$(( -diff_sec ))
                fi
                if [ "$diff_sec" -gt 86400 ]; then
                    b2_flagged=1
                    echo "[INVALID_TIMESTAMP] session=${session_id} started_at=${started_at} mtime=${mtime} reason=mtime_divergence diff_sec=${diff_sec}" >&2
                fi

                # Duration sanity-check: if completed_at and duration_sec present
                if [ "$completed_at" != "null" ] && [ -n "$completed_at" ]; then
                    completed_epoch=$(date -d "$completed_at" +%s 2>/dev/null || echo "")
                    if [ -n "$completed_epoch" ]; then
                        # Get duration_sec from [COMPLETE] event in learning-log if available
                        duration_sec=""
                        if [ -f "$log" ]; then
                            duration_sec=$(grep '^\[COMPLETE\]' "$log" 2>/dev/null \
                                | grep -oP 'duration_sec=\K[0-9]+' | tail -1 || true)
                        fi
                        # If duration_sec absent or 0, skip duration check (defensible default)
                        if [ -n "$duration_sec" ] && [ "$duration_sec" -gt 0 ]; then
                            actual_duration=$(( completed_epoch - started_epoch ))
                            diff_duration=$(( actual_duration - duration_sec ))
                            if [ "$diff_duration" -lt 0 ]; then
                                diff_duration=$(( -diff_duration ))
                            fi
                            tolerance=$(awk "BEGIN { printf \"%d\", $duration_sec * 0.10 }")
                            if [ "$diff_duration" -gt "$tolerance" ]; then
                                b2_flagged=1
                                echo "[INVALID_TIMESTAMP] session=${session_id} started_at=${started_at} mtime=${mtime} reason=duration_mismatch actual=${actual_duration}s stated=${duration_sec}s diff=${diff_duration}s tolerance=${tolerance}s" >&2
                            fi
                        fi
                    fi
                fi
            fi
        fi

        if [ "$b2_flagged" -gt 0 ]; then
            invalid_timestamp_sessions=$((invalid_timestamp_sessions + 1))
        fi
    fi
done

# Safe division
p5_score="0.000"
if [ "$total_checks" -gt 0 ]; then
    p5_score=$(awk "BEGIN { printf \"%.3f\", ($correct + $partial * 0.5) / $total_checks }")
fi

url_verify="0.000"
if [ "$total_sources" -gt 0 ]; then
    url_verify=$(awk "BEGIN { printf \"%.3f\", $verified_sources / $total_sources }")
fi

skip_ratio="0.000"
total_triggers=$((total_checks + skip))
if [ "$total_triggers" -gt 0 ]; then
    skip_ratio=$(awk "BEGIN { printf \"%.3f\", $skip / $total_triggers }")
fi

complete_ratio="0.000"
if [ "$total_sessions" -gt 0 ]; then
    complete_ratio=$(awk "BEGIN { printf \"%.3f\", $completed / $total_sessions }")
fi

cat <<'METRICS_EOF'
=== DRLLM M1 POC Aggregate Metrics ===
METRICS_EOF
printf 'Sessions total:   %s\n' "$total_sessions"
printf 'Sessions done:    %s\n' "$completed"
printf 'Sessions invalid:\n'
printf '  [P5_MISSING]:             %s\n' "$invalid_sessions"
printf '  [INVALID_CITATION_COUNT]: %s\n' "$invalid_citation_count_sessions"
printf '  [INVALID_TIMESTAMP]:      %s\n' "$invalid_timestamp_sessions"
cat <<'METRICS_EOF'
--------------------------------------
METRICS_EOF
printf 'P5 score:         %s (필수 >= 0.700)\n' "$p5_score"
printf 'URL verify:       %s (필수 >= 0.950)\n' "$url_verify"
printf 'Skip ratio:       %s (기록만)\n' "$skip_ratio"
printf 'Complete ratio:   %s (기록만)\n' "$complete_ratio"
cat <<'METRICS_EOF'
--------------------------------------
Detail:
METRICS_EOF
printf '  P5 checks:      %s (correct=%s partial=%s)\n' "$total_checks" "$correct" "$partial"
printf '  P5 skips:       %s\n' "$skip"
printf '  P5 missing:     %s (§6-1 위반 기록)\n' "$missing"
printf '  Citations:      %s (verified=%s)\n' "$total_sources" "$verified_sources"
