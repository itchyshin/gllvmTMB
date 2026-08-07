#!/usr/bin/env bash
set -euo pipefail

# Totoro launcher for Arc S0a — Gaussian absolute-first fresh seeds only.
# Does not mutate package campaign scripts. Never submits DRAC / GHA.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LANE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Prefer CHECKOUT if set (Totoro detached campaign checkout); else worktree root.
REPO_ROOT="${CHECKOUT:-$(cd "$LANE_ROOT/../.." && pwd)}"
DRIVER="$REPO_ROOT/dev/va-gh-h7-campaign/run-cell.R"

ACTION="${ACTION:-dry-run}"
CAMPAIGN_ROOT="${CAMPAIGN_PROJECT_ROOT:-}"
OUTPUT_DIR="${OUTPUT_DIR:-${CAMPAIGN_ROOT:+$CAMPAIGN_ROOT/results}}"
SMOKE_OUTPUT_DIR="${SMOKE_OUTPUT_DIR:-$OUTPUT_DIR/smoke}"
PLAN="${PLAN:-$OUTPUT_DIR/plan.csv}"
CORES="${CORES:-100}"

CELL="${CELL:-gaussian_identity}"
SEEDS="${SEEDS:-10001:10300}"
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
    Rscript --vanilla "$DRIVER" --mode=dry-run --cells="$CELL" \
      --seeds=10001 --Hs=7 --qs=2 --estimators=va --n=120 --p=8
    echo "S0a dry-run only: CELL=$CELL SEEDS=$SEEDS CORES=$CORES"
    ;;
  smoke)
    require_campaign_root; gate_and_runtime
    mkdir -p "$SMOKE_OUTPUT_DIR"
    smoke_plan="$SMOKE_OUTPUT_DIR/plan.csv"
    Rscript --vanilla "$DRIVER" --mode=plan --plan="$smoke_plan" \
      --output-dir="$SMOKE_OUTPUT_DIR" --cells="$CELL" --seeds=10001 \
      --Hs=7 --qs=2 --estimators=va --n=120 --p=8 --gate-receipt="$GATE_E_RECEIPT"
    Rscript --vanilla "$DRIVER" --mode=run --plan="$smoke_plan" \
      --output-dir="$SMOKE_OUTPUT_DIR" --task-index=1 \
      --gate-receipt="$GATE_E_RECEIPT" \
      --runtime-manifest="$VA_RUNTIME_MANIFEST" \
      --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
    Rscript --vanilla "$DRIVER" --mode=verify-healthy-task --plan="$smoke_plan" \
      --output-dir="$SMOKE_OUTPUT_DIR" --task-index=1 \
      --gate-receipt="$GATE_E_RECEIPT" \
      --runtime-manifest="$VA_RUNTIME_MANIFEST" \
      --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
    ;;
  plan)
    require_campaign_root; gate_and_runtime
    smoke_plan="$SMOKE_OUTPUT_DIR/plan.csv"
    [[ -f "$smoke_plan" ]] || { echo "run ACTION=smoke first" >&2; exit 4; }
    mkdir -p "$OUTPUT_DIR"
    Rscript --vanilla "$DRIVER" --mode=plan --plan="$PLAN" \
      --output-dir="$OUTPUT_DIR" --cells="$CELL" --seeds="$SEEDS" \
      --Hs="$HS" --qs="$QS" --estimators="$ESTIMATORS" --n="$N" --p="$P" \
      --gate-receipt="$GATE_E_RECEIPT"
    tasks="$(( $(wc -l < "$PLAN") - 1 ))"
    echo "S0a plan rows: $tasks (expect 1200 for 300×2×2)"
    ;;
  run)
    require_campaign_root; gate_and_runtime
    [[ -f "$PLAN" ]] || { echo "immutable plan missing: $PLAN" >&2; exit 4; }
    run_plan "$PLAN" "$OUTPUT_DIR"
    ;;
  summarise)
    [[ -f "$PLAN" ]] || { echo "plan missing" >&2; exit 4; }
    Rscript --vanilla "$DRIVER" --mode=summarise --plan="$PLAN" \
      --output-dir="$OUTPUT_DIR"
    ;;
  export)
    require_campaign_root; gate_and_runtime
    : "${EXPORT_OUTPUT:?Set EXPORT_OUTPUT}"
    Rscript --vanilla "$DRIVER" --mode=export \
      --plan="$PLAN" --output-dir="$OUTPUT_DIR" \
      --gate-receipt="$GATE_E_RECEIPT" \
      --runtime-manifest="$VA_RUNTIME_MANIFEST" \
      --preflight-receipt="$VA_PREFLIGHT_RECEIPT" \
      --export-output="$EXPORT_OUTPUT"
    ;;
  *)
    echo "ACTION must be dry-run|smoke|plan|run|summarise|export" >&2
    exit 2
    ;;
esac
