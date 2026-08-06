#!/usr/bin/env bash
set -euo pipefail

# Arc 2 Totoro launcher. Default is dry-run; execution needs a Gate-E PASS
# receipt. This script does not connect to Totoro: run it inside the prepared
# checkout on Totoro after Gate E.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DRIVER="$SCRIPT_DIR/run-cell.R"
ACTION="${ACTION:-dry-run}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/results}"
PLAN="${PLAN:-$OUTPUT_DIR/plan.csv}"
CORES="${CORES:-100}"
SEEDS="${SEEDS:-1:30}"
HS="${HS:-5,7,9,15,61}"
QS="${QS:-2,5}"
ESTIMATORS="${ESTIMATORS:-va,laplace}"
N="${N:-60}"
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
  grep -qx 'PASS' "$GATE_E_RECEIPT" || {
    echo "Gate-E receipt does not contain exactly PASS." >&2; exit 3; }
}

case "$ACTION" in
  dry-run)
    Rscript --vanilla "$DRIVER" --mode=dry-run --cell=binomial_logit \
      --seed=1 --H=7 --q=2 --n="$N" --p="$P" --estimator=va
    echo "Totoro dry-run only: CORES=$CORES (cap 150), BLAS threads=1"
    ;;
  plan)
    gate_e
    mkdir -p "$OUTPUT_DIR"
    Rscript --vanilla "$DRIVER" --mode=plan --plan="$PLAN" --output-dir="$OUTPUT_DIR" \
      --seeds="$SEEDS" --Hs="$HS" --qs="$QS" --estimators="$ESTIMATORS" --n="$N" --p="$P"
    ;;
  run)
    gate_e
    [[ -f "$PLAN" ]] || { echo "immutable plan missing: $PLAN" >&2; exit 4; }
    tasks="$(($(wc -l < "$PLAN") - 1))"
    (( tasks > 0 )) || { echo "plan has no tasks" >&2; exit 4; }
    cd "$REPO_ROOT"
    seq 1 "$tasks" | xargs -P "$CORES" -I TASK \
      Rscript --vanilla "$DRIVER" --mode=run --plan="$PLAN" \
        --output-dir="$OUTPUT_DIR" --task-index=TASK
    ;;
  summarise)
    Rscript --vanilla "$DRIVER" --mode=summarise --output-dir="$OUTPUT_DIR"
    ;;
  *) echo "ACTION must be dry-run, plan, run, or summarise" >&2; exit 2 ;;
esac
