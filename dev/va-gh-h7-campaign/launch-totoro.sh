#!/usr/bin/env bash
set -euo pipefail

# Arc 2 Totoro launcher. Default is dry-run. This script does not connect to
# Totoro: run it inside the prepared checkout after runtime + timed preflight.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DRIVER="$SCRIPT_DIR/run-cell.R"
ACTION="${ACTION:-dry-run}"
OUTPUT_DIR="${OUTPUT_DIR:-${CAMPAIGN_PROJECT_ROOT:-}/results}"
PLAN="${PLAN:-$OUTPUT_DIR/plan.csv}"
CORES="${CORES:-100}"
SEEDS="${SEEDS:-1:30}"
HS="${HS:-5,7,9,15,61}"
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

gate_e() {
  [[ -n "${GATE_E_RECEIPT:-}" && -f "$GATE_E_RECEIPT" ]] || {
    echo "Set GATE_E_RECEIPT to a durable Gate-E receipt before plan/run." >&2; exit 3; }
  Rscript --vanilla "$DRIVER" --mode=verify-gate \
    --gate-receipt="$GATE_E_RECEIPT"
}

runtime_ready() {
  : "${VA_RUNTIME_MANIFEST:?Set VA_RUNTIME_MANIFEST to runtime.dcf}"
  : "${VA_PREFLIGHT_RECEIPT:?Set VA_PREFLIGHT_RECEIPT to preflight.dcf}"
  Rscript --vanilla "$DRIVER" --mode=verify-runtime \
    --gate-receipt="$GATE_E_RECEIPT" \
    --runtime-manifest="$VA_RUNTIME_MANIFEST" \
    --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
}

case "$ACTION" in
  dry-run)
    Rscript --vanilla "$DRIVER" --mode=dry-run --cells=binomial_logit \
      --seed=1 --H=7 --q=2 --n="$N" --p="$P" --estimator=va
    echo "Totoro dry-run only: CORES=$CORES (cap 150), BLAS threads=1"
    ;;
  plan)
    gate_e
    : "${CAMPAIGN_PROJECT_ROOT:?Set CAMPAIGN_PROJECT_ROOT to durable storage}"
    mkdir -p "$OUTPUT_DIR"
    Rscript --vanilla "$DRIVER" --mode=plan --plan="$PLAN" --output-dir="$OUTPUT_DIR" \
      --seeds="$SEEDS" --Hs="$HS" --qs="$QS" --estimators="$ESTIMATORS" --n="$N" --p="$P"
    ;;
  run)
    gate_e
    runtime_ready
    smoke_plan="$OUTPUT_DIR/smoke-plan.csv"
    [[ -f "$smoke_plan" ]] || {
      echo "Totoro smoke plan is missing; run ACTION=smoke first." >&2; exit 4; }
    Rscript --vanilla "$DRIVER" --mode=verify-task --plan="$smoke_plan" \
      --output-dir="$OUTPUT_DIR" --task-index=1 \
      --gate-receipt="$GATE_E_RECEIPT" \
      --runtime-manifest="$VA_RUNTIME_MANIFEST" \
      --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
    [[ -f "$PLAN" ]] || { echo "immutable plan missing: $PLAN" >&2; exit 4; }
    tasks="$(($(wc -l < "$PLAN") - 1))"
    (( tasks > 0 )) || { echo "plan has no tasks" >&2; exit 4; }
    cd "$REPO_ROOT"
    seq 1 "$tasks" | xargs -P "$CORES" -I TASK \
      Rscript --vanilla "$DRIVER" --mode=run --plan="$PLAN" \
        --output-dir="$OUTPUT_DIR" --task-index=TASK \
        --gate-receipt="$GATE_E_RECEIPT" \
        --runtime-manifest="$VA_RUNTIME_MANIFEST" \
        --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
    ;;
  smoke)
    gate_e
    runtime_ready
    : "${CAMPAIGN_PROJECT_ROOT:?Set CAMPAIGN_PROJECT_ROOT to durable storage}"
    smoke_plan="$OUTPUT_DIR/smoke-plan.csv"
    mkdir -p "$OUTPUT_DIR"
    Rscript --vanilla "$DRIVER" --mode=plan --plan="$smoke_plan" \
      --output-dir="$OUTPUT_DIR" --cells=binomial_logit --seeds=202608061 \
      --Hs=7 --qs=2 --estimators=va --n=120 --p=6 \
      --gate-receipt="$GATE_E_RECEIPT"
    Rscript --vanilla "$DRIVER" --mode=run --plan="$smoke_plan" \
      --output-dir="$OUTPUT_DIR" --task-index=1 \
      --gate-receipt="$GATE_E_RECEIPT" \
      --runtime-manifest="$VA_RUNTIME_MANIFEST" \
      --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
    Rscript --vanilla "$DRIVER" --mode=verify-task --plan="$smoke_plan" \
      --output-dir="$OUTPUT_DIR" --task-index=1 \
      --gate-receipt="$GATE_E_RECEIPT" \
      --runtime-manifest="$VA_RUNTIME_MANIFEST" \
      --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
    ;;
  summarise)
    Rscript --vanilla "$DRIVER" --mode=summarise --plan="$PLAN" \
      --output-dir="$OUTPUT_DIR"
    ;;
  *) echo "ACTION must be dry-run, plan, smoke, run, or summarise" >&2; exit 2 ;;
esac
