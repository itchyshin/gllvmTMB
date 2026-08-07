#!/usr/bin/env bash
set -euo pipefail

# Totoro launcher for Arc S1 — binomials NARROW absolute-first.
# Cells: binomial_logit,binomial_probit,binomial_cloglog.
# Do NOT run until Shinichi says go. Never submits DRAC / GHA.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LANE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="${CHECKOUT:-$(cd "$LANE_ROOT/../.." && pwd)}"
DRIVER="$REPO_ROOT/dev/va-gh-h7-campaign/run-cell.R"

ACTION="${ACTION:-dry-run}"
CAMPAIGN_ROOT="${CAMPAIGN_PROJECT_ROOT:-}"
OUTPUT_DIR="${OUTPUT_DIR:-${CAMPAIGN_ROOT:+$CAMPAIGN_ROOT/results}}"
SMOKE_OUTPUT_DIR="${SMOKE_OUTPUT_DIR:-$OUTPUT_DIR/smoke}"
PLAN="${PLAN:-$OUTPUT_DIR/plan.csv}"
CORES="${CORES:-100}"

CELLS="${CELLS:-binomial_logit,binomial_probit,binomial_cloglog}"
SMOKE_CELL="${SMOKE_CELL:-binomial_logit}"
SEEDS="${SEEDS:-10601:10900}"
HS="${HS:-7}"
QS="${QS:-2,5}"
ESTIMATORS="${ESTIMATORS:-va,laplace}"
N="${N:-120}"
P="${P:-8}"

export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

if ! [[ "$CORES" =~ ^[0-9]+$ ]] || (( CORES < 1 || CORES > 150 )); then
  echo "CORES must be an integer in 1..150 (got $CORES)." >&2
  exit 2
fi

require_campaign_root() {
  [[ -n "$CAMPAIGN_ROOT" ]] || {
    echo "Set CAMPAIGN_PROJECT_ROOT to durable Totoro campaign storage." >&2
    exit 3
  }
}

gate_and_runtime() {
  : "${GATE_E_RECEIPT:?Set GATE_E_RECEIPT}"
  : "${VA_RUNTIME_MANIFEST:?Set VA_RUNTIME_MANIFEST}"
  : "${VA_PREFLIGHT_RECEIPT:?Set VA_PREFLIGHT_RECEIPT}"
  Rscript --vanilla "$DRIVER" --mode=verify-gate --gate-receipt="$GATE_E_RECEIPT"
  Rscript --vanilla "$DRIVER" --mode=verify-runtime \
    --gate-receipt="$GATE_E_RECEIPT" --runtime-manifest="$VA_RUNTIME_MANIFEST" \
    --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
}

run_plan() {
  local plan="$1" output="$2" tasks
  tasks="$(( $(wc -l < "$plan") - 1 ))"
  (( tasks > 0 )) || { echo "plan has no tasks" >&2; exit 4; }
  cd "$REPO_ROOT"
  seq 1 "$tasks" | xargs -P "$CORES" -I TASK \
    Rscript --vanilla "$DRIVER" --mode=run --plan="$plan" --output-dir="$output" \
      --task-index=TASK --gate-receipt="$GATE_E_RECEIPT" \
      --runtime-manifest="$VA_RUNTIME_MANIFEST" --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
}

case "$ACTION" in
  dry-run)
    Rscript --vanilla "$DRIVER" --mode=dry-run --cells="$SMOKE_CELL" \
      --seeds=10601 --Hs=7 --qs=2 --estimators=va --n=120 --p=8
    echo "S1 dry-run only: CELLS=$CELLS SEEDS=$SEEDS CORES=$CORES"
    echo "Say go for Totoro S1 before ACTION=smoke|full."
    ;;
  smoke)
    require_campaign_root; gate_and_runtime
    mkdir -p "$SMOKE_OUTPUT_DIR"
    smoke_plan="$SMOKE_OUTPUT_DIR/plan.csv"
    Rscript --vanilla "$DRIVER" --mode=plan --plan="$smoke_plan" \
      --output-dir="$SMOKE_OUTPUT_DIR" --cells="$SMOKE_CELL" --seeds=10601 \
      --Hs=7 --qs=2 --estimators=va --n=120 --p=8 --gate-receipt="$GATE_E_RECEIPT"
    Rscript --vanilla "$DRIVER" --mode=run --plan="$smoke_plan" \
      --output-dir="$SMOKE_OUTPUT_DIR" --task-index=1 \
      --gate-receipt="$GATE_E_RECEIPT" \
      --runtime-manifest="$VA_RUNTIME_MANIFEST" --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
    echo "S1 smoke done under $SMOKE_OUTPUT_DIR"
    ;;
  full)
    require_campaign_root; gate_and_runtime
    mkdir -p "$OUTPUT_DIR"
    Rscript --vanilla "$DRIVER" --mode=plan --plan="$PLAN" \
      --output-dir="$OUTPUT_DIR" --cells="$CELLS" --seeds="$SEEDS" \
      --Hs="$HS" --qs="$QS" --estimators="$ESTIMATORS" --n="$N" --p="$P" \
      --gate-receipt="$GATE_E_RECEIPT"
    run_plan "$PLAN" "$OUTPUT_DIR"
    echo "S1 full plan launched under $OUTPUT_DIR"
    ;;
  *)
    echo "ACTION must be dry-run|smoke|full (got $ACTION)" >&2
    exit 2
    ;;
esac
