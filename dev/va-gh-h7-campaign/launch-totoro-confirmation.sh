#!/usr/bin/env bash
set -euo pipefail

# Direct-process Totoro confirmation launcher.  It is intentionally separate
# from the DRAC array scripts and never submits a scheduler job.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DRIVER="$SCRIPT_DIR/run-cell.R"
ACTION="${ACTION:-dry-run}"
CAMPAIGN_ROOT="${CAMPAIGN_PROJECT_ROOT:-}"
SMOKE_OUTPUT_DIR="${SMOKE_OUTPUT_DIR:-${CAMPAIGN_ROOT:+$CAMPAIGN_ROOT/smoke}}"
SENTINEL_OUTPUT_DIR="${SENTINEL_OUTPUT_DIR:-${CAMPAIGN_ROOT:+$CAMPAIGN_ROOT/sentinel}}"
CONFIRMATION_OUTPUT_DIR="${CONFIRMATION_OUTPUT_DIR:-${CAMPAIGN_ROOT:+$CAMPAIGN_ROOT/confirmation}}"
SMOKE_PLAN="${SMOKE_PLAN:-${SMOKE_OUTPUT_DIR:+$SMOKE_OUTPUT_DIR/plan.csv}}"
SENTINEL_PLAN="${SENTINEL_PLAN:-${SENTINEL_OUTPUT_DIR:+$SENTINEL_OUTPUT_DIR/plan.csv}}"
PLAN="${PLAN:-${CONFIRMATION_OUTPUT_DIR:+$CONFIRMATION_OUTPUT_DIR/plan.csv}}"
SENTINEL_RECEIPT="${SENTINEL_RECEIPT:-${SENTINEL_OUTPUT_DIR:+$SENTINEL_OUTPUT_DIR/sentinel.dcf}}"
CORES="${CORES:-100}"
CONFIRMATION_SEEDS="1:500"
CONFIRMATION_HS="7"
CONFIRMATION_QS="2,5"
CONFIRMATION_ESTIMATORS="va,laplace"
CONFIRMATION_N="120"
CONFIRMATION_P="8"

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
  : "${GATE_E_RECEIPT:?Set GATE_E_RECEIPT to a durable Gate-E receipt}"
  : "${VA_RUNTIME_MANIFEST:?Set VA_RUNTIME_MANIFEST to runtime.dcf}"
  : "${VA_PREFLIGHT_RECEIPT:?Set VA_PREFLIGHT_RECEIPT to preflight.dcf}"
  Rscript --vanilla "$DRIVER" --mode=verify-gate --gate-receipt="$GATE_E_RECEIPT"
  Rscript --vanilla "$DRIVER" --mode=verify-runtime \
    --gate-receipt="$GATE_E_RECEIPT" --runtime-manifest="$VA_RUNTIME_MANIFEST" \
    --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
}

verify_smoke() {
  [[ -f "$SMOKE_PLAN" ]] || { echo "smoke plan is missing" >&2; exit 4; }
  Rscript --vanilla "$DRIVER" --mode=verify-healthy-task --plan="$SMOKE_PLAN" \
    --output-dir="$SMOKE_OUTPUT_DIR" --task-index=1 \
    --gate-receipt="$GATE_E_RECEIPT" --runtime-manifest="$VA_RUNTIME_MANIFEST" \
    --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
}

verify_sentinel() {
  [[ -f "$SENTINEL_PLAN" && -f "$SENTINEL_RECEIPT" ]] || {
    echo "immutable sentinel plan or receipt is missing" >&2; exit 4; }
  Rscript --vanilla "$DRIVER" --mode=verify-sentinel --plan="$SENTINEL_PLAN" \
    --sentinel-receipt="$SENTINEL_RECEIPT" --gate-receipt="$GATE_E_RECEIPT" \
    --runtime-manifest="$VA_RUNTIME_MANIFEST" --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
}

verify_confirmation_plan() {
  [[ -f "$PLAN" ]] || { echo "immutable confirmation plan is missing" >&2; exit 4; }
  Rscript --vanilla "$DRIVER" --mode=verify-confirmation-plan --plan="$PLAN"
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
    Rscript --vanilla "$DRIVER" --mode=dry-run --cells=binomial_logit \
      --seeds=1 --Hs=7 --qs=2 --estimators=va --n=120 --p=8
    echo "Totoro confirmation dry-run only: CORES=$CORES, BLAS/OMP/MKL threads=1"
    ;;
  smoke)
    require_campaign_root; gate_and_runtime
    mkdir -p "$SMOKE_OUTPUT_DIR"
    Rscript --vanilla "$DRIVER" --mode=plan --plan="$SMOKE_PLAN" \
      --output-dir="$SMOKE_OUTPUT_DIR" --cells=binomial_logit --seeds=1 \
      --Hs=7 --qs=2 --estimators=va --n=120 --p=8 --gate-receipt="$GATE_E_RECEIPT"
    run_plan "$SMOKE_PLAN" "$SMOKE_OUTPUT_DIR"
    verify_smoke
    ;;
  sentinel)
    require_campaign_root; gate_and_runtime; verify_smoke
    mkdir -p "$SENTINEL_OUTPUT_DIR"
    Rscript --vanilla "$DRIVER" --mode=plan --plan="$SENTINEL_PLAN" \
      --output-dir="$SENTINEL_OUTPUT_DIR" --cells=binomial_logit --seeds=1:25 \
      --Hs=7 --qs=2,5 --estimators=va,laplace --n=120 --p=8 --gate-receipt="$GATE_E_RECEIPT"
    if ! run_plan "$SENTINEL_PLAN" "$SENTINEL_OUTPUT_DIR"; then
      echo "sentinel worker command failures retained for receipt adjudication" >&2
    fi
    Rscript --vanilla "$DRIVER" --mode=sentinel-receipt --plan="$SENTINEL_PLAN" \
      --output-dir="$SENTINEL_OUTPUT_DIR" --sentinel-receipt="$SENTINEL_RECEIPT" \
      --gate-receipt="$GATE_E_RECEIPT" --runtime-manifest="$VA_RUNTIME_MANIFEST" \
      --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
    ;;
  plan)
    require_campaign_root; gate_and_runtime; verify_smoke; verify_sentinel
    mkdir -p "$CONFIRMATION_OUTPUT_DIR"
    Rscript --vanilla "$DRIVER" --mode=plan --plan="$PLAN" \
      --output-dir="$CONFIRMATION_OUTPUT_DIR" --seeds="$CONFIRMATION_SEEDS" \
      --Hs="$CONFIRMATION_HS" --qs="$CONFIRMATION_QS" \
      --estimators="$CONFIRMATION_ESTIMATORS" --n="$CONFIRMATION_N" \
      --p="$CONFIRMATION_P" \
      --gate-receipt="$GATE_E_RECEIPT"
    verify_confirmation_plan
    ;;
  run)
    require_campaign_root; gate_and_runtime; verify_smoke; verify_sentinel
    verify_confirmation_plan
    run_plan "$PLAN" "$CONFIRMATION_OUTPUT_DIR"
    ;;
  summarise)
    [[ -f "$PLAN" ]] || { echo "immutable confirmation plan is missing" >&2; exit 4; }
    Rscript --vanilla "$DRIVER" --mode=summarise --plan="$PLAN" \
      --output-dir="$CONFIRMATION_OUTPUT_DIR"
    ;;
  *) echo "ACTION must be dry-run, smoke, sentinel, plan, run, or summarise" >&2; exit 2 ;;
esac
