#!/usr/bin/env bash
set -euo pipefail

# Exact sequential Totoro launcher for the corrected Phase C G1--G6 campaign.
# This script reads receipts and structural state only. Scientific trends are
# not opened until all six blocks have completed.

if [[ $# -ne 4 ]]; then
  printf 'Usage: %s ARTIFACT_ROOT PREFLIGHT_RECEIPT PILOT_DECISION_RECEIPT G1_SEEDS\n' "$0" >&2
  exit 2
fi

artifact_root=$1
preflight_receipt=$2
pilot_decision_receipt=$3
g1_seeds=$4
phase_c_cores=${PHASE_C_CORES:-96}

[[ $g1_seeds == 100 || $g1_seeds == 200 ]] || { printf 'G1_SEEDS must be 100 or 200\n' >&2; exit 2; }
[[ $phase_c_cores =~ ^[0-9]+$ ]] || { printf 'PHASE_C_CORES must be an integer\n' >&2; exit 2; }
(( phase_c_cores >= 1 && phase_c_cores <= 150 )) || { printf 'PHASE_C_CORES must be in 1..150\n' >&2; exit 2; }
[[ -f $preflight_receipt && -f $pilot_decision_receipt ]] || { printf 'Required predecessor receipt missing\n' >&2; exit 2; }

export NOT_CRAN=true
export OPENBLAS_NUM_THREADS=1
mkdir -p "$artifact_root"

verify_complete() {
  local stage=$1 receipt=$2
  Rscript --vanilla -e \
    'source("dev/isdm-bias-campaign.R"); a <- commandArgs(TRUE); .require_receipt_c(a[[1]], paste0(a[[2]], "_compute")); cat("PASS\n")' \
    "$receipt" "$stage" >/dev/null
}

run_one() {
  local stage=$1
  local output="$artifact_root/${stage}-results.rds"
  local receipt="$artifact_root/${stage}-compute.receipt"
  local log="$artifact_root/${stage}.log"
  if [[ -f $output && -f $receipt ]]; then
    verify_complete "$stage" "$receipt"
    return 0
  fi
  local args=(
    "$stage" "--cores=$phase_c_cores" "--chunk-size=$phase_c_cores"
    "--preflight-receipt=$preflight_receipt"
    "--pilot-receipt=$pilot_decision_receipt"
    "--output=$output" "--receipt=$receipt"
  )
  if [[ $stage == g1 ]]; then
    args+=("--g1-seeds=$g1_seeds")
  elif [[ $stage == g6 ]]; then
    args+=("--g1-receipt=$artifact_root/g1-compute.receipt")
  fi
  Rscript --vanilla dev/isdm-bias-campaign.R "${args[@]}" >"$log" 2>&1
}

for stage in g1 g2 g3 g4 g5 g6; do
  run_one "$stage"
done

printf 'Phase C G1--G6 structural campaign complete: %s\n' "$artifact_root"
