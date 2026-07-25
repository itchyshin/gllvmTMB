#!/bin/bash
#SBATCH --account=def-snakagaw_cpu
#SBATCH --job-name=d102
#SBATCH --time=0-02:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=3G
#SBATCH --array=1-192%48
#SBATCH --output=logs/d102_%A_%a.out
set -euo pipefail
module load gcc/12.3 r/4.4.0
export R_LIBS="$HOME/.local/R/4.4.0"
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
ROOT=${D102_ROOT:?}
line=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$ROOT/cells.tsv")
IFS=$'\t' read -r seed n regime <<< "$line"
out="$ROOT/records/${seed}-${n}-${regime}.rds"
test ! -e "$out"
cd "$ROOT/code"
Rscript --vanilla run-cell.R "$seed" "$n" "$regime" "$out" "$ROOT/code/src/design102_variational.cpp"
