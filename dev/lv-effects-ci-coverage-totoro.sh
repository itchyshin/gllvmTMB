#!/usr/bin/env bash
## Totoro launcher for the B_lv coverage campaign (no SLURM; direct xargs -P).
## Courtesy rule: keep our own usage <= 100 cores (default 80 here). Each task
## writes its own CSV and the runner skips existing ones, so this is resume-safe
## -- re-run the same command to fill gaps after an interruption.
##
## Usage: ./lv-effects-ci-coverage-totoro.sh <cell_id> [total_reps] [reps_per_task] [parallel_width]
##   e.g. ./lv-effects-ci-coverage-totoro.sh gauss-S200-K1 500 5 80
set -euo pipefail

CELL="${1:?cell_id required}"
TOTAL="${2:-500}"
PER="${3:-5}"
WIDTH="${4:-80}"
RUNNER="dev/lv-effects-ci-coverage.R"

export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1

NTASK=$(( (TOTAL + PER - 1) / PER ))
echo "[$(date '+%H:%M:%S')] cell=$CELL total=$TOTAL per_task=$PER tasks=$NTASK width=$WIDTH"
echo "  (our cores <= $WIDTH; check load with: cut -d' ' -f1-3 /proc/loadavg)"

seq 1 "$NTASK" | xargs -P "$WIDTH" -I {} \
  Rscript "$RUNNER" run "$CELL" {} "$PER" >/dev/null 2>&1 || true

echo "[$(date '+%H:%M:%S')] $CELL done -- summarising"
Rscript "$RUNNER" summarise results/lv-effects-ci-coverage
