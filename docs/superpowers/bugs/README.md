# DRLLM Bug Tracker

**범위**: 실사용/smoke 에서 발견된 재현 가능한 결함. v0.1 M1 합격 지표에는 영향 없으나 측정 무결성 또는 robustness 를 해치므로 **반드시 고쳐야 하는** 항목.

## 규약

- 파일명: `B<번호>-<slug>.md` (예: `B1-citations-count-mismatch.md`)
- 상태: `open` / `scheduled` / `in_progress` / `fixed`
- 각 버그 파일 필수 섹션:
  - Severity (Critical/Important/Minor)
  - Observed (어디서, 언제, 어떻게 재현)
  - Root Cause Hypothesis
  - Fix Plan (어느 스킬/파일/task 에서 수정)
  - Verification (고쳤다면 어떻게 확인)
  - Status

## Index

| ID | Title | Severity | Status | Scheduled |
|----|-------|----------|--------|-----------|
| B1 | S2 citations count ≠ metadata url_verify_total | Important | in_progress | Task 21 |
| B2 | Timestamp hallucination (started_at / generated_at) | Important | in_progress | Task 20 + drllm-core; Task 22 detection |
| B3 | S2 uses GoogleSearch beyond plan scope (fetch-only) | Minor | in_progress | SP-2 (tool allowlist) |
| B4 | L3 fixtures cover only happy path (B1/B2 detection untested permanently) | Minor | open | SP-2 (negative fixtures) |
