#!/usr/bin/env bash
## arcG Totoro batch launcher — PREPARED ONLY; do not submit without "Totoro go".
## D-139: halt if measured fit cost exceeds ~5 core-h ceiling.
## D-143: cap at 150 cores.
## D-64: requires live ControlMaster socket (~/.ssh/cm-*).

set -euo pipefail

REPO="${GLLVMTMB_ROOT:-/Users/z3437171/local-scratch/lanes/gllvmTMB-gllvm-twin-20260904}"
OUT="${REPO}/dev/gapclose/arcG/results/raw"
LOG="${REPO}/dev/gapclose/arcG/results/totoro-run.log"
MAX_CORES=150
N_SEEDS=500

mkdir -p "$OUT"
echo "# arcG grid — NOT SUBMITTED $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$LOG"
echo "# HEAD: $(git -C "$REPO" rev-parse --short HEAD)" >> "$LOG"
echo "# 9 cells x ${N_SEEDS} seeds = $((9 * N_SEEDS)) jobs" >> "$LOG"

# Verify ControlMaster before dispatch
if ! ls ~/.ssh/cm-* >/dev/null 2>&1; then
  echo "ERROR: no ControlMaster socket (~/.ssh/cm-*). Attach first (D-64)." >&2
  exit 1
fi

# Example parallel dispatch (parent must approve):
# for cell_id in $(seq 1 9); do
#   for seed in $(seq 1 $N_SEEDS); do
#     echo "Rscript ${REPO}/dev/gapclose/arcG/campaign.R $cell_id $seed $OUT $REPO"
#   done
# done | parallel -j $MAX_CORES --joblog "${REPO}/dev/gapclose/arcG/results/parallel.log"

echo "Batch script prepared. Submit only after parent 'Totoro go'."
