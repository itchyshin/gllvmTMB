#!/usr/bin/env bash
# Read-only DRAC campaign monitor. It never submits, cancels, or edits jobs.

set -euo pipefail

die() { echo "[mspl-coverage-monitor] $*" >&2; exit 2; }
ROOT="${MSPL_COVERAGE_ROOT:-}"
[[ "$ROOT" == /project/* ]] || die "Set MSPL_COVERAGE_ROOT to the explicit /project campaign root."
MAP="${MSPL_COVERAGE_ARRAY_MAP:-$ROOT/array-map.tsv}"
[[ -f "$MAP" ]] || die "Missing runner-produced array map: $MAP"
EXPECTED="$(awk 'NR > 1 && NF {n += 1} END {print n + 0}' "$MAP")"
COMPLETED=0
while IFS=$'\t' read -r index case_id shard_id; do
  [[ "$index" == "array_index" ]] && continue
  name="$(printf '%s-shard-%03d.rds' "$case_id" "$shard_id")"
  [[ -s "$ROOT/shards/$name" ]] && COMPLETED=$((COMPLETED + 1))
done < "$MAP"

JOB_ID="${MSPL_COVERAGE_JOB_ID:-}"
RUNNING=0 PENDING=0 FAILED=0
if [[ -n "$JOB_ID" ]] && command -v squeue >/dev/null 2>&1; then
  while IFS= read -r state; do
    case "$state" in RUNNING|COMPLETING) RUNNING=$((RUNNING + 1)) ;; PENDING|CONFIGURING) PENDING=$((PENDING + 1)) ;; esac
  done < <(squeue -h -j "$JOB_ID" -o '%T' 2>/dev/null || true)
fi
if [[ -n "$JOB_ID" ]] && command -v sacct >/dev/null 2>&1; then
  FAILED="$(sacct -n -X -j "$JOB_ID" --format=State 2>/dev/null | awk '$1 ~ /^(FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY|NODE_FAIL|BOOT_FAIL)/ {n += 1} END {print n + 0}')"
fi

shopt -s nullglob
receipts=("$ROOT"/receipts/*.receipt)
NEWEST_RECEIPT="none"
if ((${#receipts[@]})); then NEWEST_RECEIPT="$(ls -1t "${receipts[@]}" | head -n 1)"; fi
printf 'expected=%s\ncompleted=%s\nrunning=%s\npending=%s\nfailed=%s\nnewest_receipt=%s\n' \
  "$EXPECTED" "$COMPLETED" "$RUNNING" "$PENDING" "$FAILED" "$NEWEST_RECEIPT"
