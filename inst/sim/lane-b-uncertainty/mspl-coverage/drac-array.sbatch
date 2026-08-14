#!/usr/bin/env bash
#SBATCH --account=def-snakagaw_cpu
#SBATCH --job-name=msplcov_array
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
# Array bounds deliberately omitted: use only the runner-produced frozen array map.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mspl-coverage.sh
source "$SCRIPT_DIR/lib-mspl-coverage.sh"

mspl_validate_runtime_inputs
mspl_require_gate_receipt
mspl_load_modules
mspl_stage_runtime
IFS=$'\t' read -r CASE_ID SHARD_ID < <(mspl_array_task)
RUNNER="${MSPL_COVERAGE_RUNNER:-inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R}"
[[ "$RUNNER" == "inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R" ]] || mspl_die "Only the frozen Gate-0 coverage runner is accepted."
cd "$MSPL_COVERAGE_PACKAGE_DIR"
# Exact runner invocation: all task identity comes from the frozen array map.
Rscript --vanilla "$RUNNER" run-shard \
  --root "$MSPL_COVERAGE_LOCAL_ROOT" --case-id "$CASE_ID" --shard-id "$SHARD_ID" \
  --cluster "$MSPL_COVERAGE_CLUSTER"
mspl_publish_rds_shard "$CASE_ID" "$SHARD_ID" \
  "$MSPL_COVERAGE_LOCAL_ROOT/shards/$(printf '%s-shard-%03d.rds' "$CASE_ID" "$SHARD_ID")"
