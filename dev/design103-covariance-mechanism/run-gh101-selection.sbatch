#!/bin/bash
#SBATCH --job-name=d103-gh101-select
#SBATCH --account=def-snakagaw
#SBATCH --time=00:10:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=1
#SBATCH --array=0-1%1
#SBATCH --output=/project/def-snakagaw/snakagaw/design103-20260724/select-%A_%a.out

set -euo pipefail
module load gcc/12.3 r/4.4.0
export R_LIBS="$HOME/.local/R/4.4.0"
export OPENBLAS_NUM_THREADS=1
root=/project/def-snakagaw/snakagaw/design103-20260724
regime=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$root/code/gh101-selection-regimes.txt")
mkdir -p "$root/records"
Rscript --vanilla "$root/code/run-gh101-selection.R" \
  102001 240 "$regime" \
  "$root/records/gh101-selection-102001-240-${regime}.rds" \
  "$root/code/design103_gh.cpp"
