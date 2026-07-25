#!/bin/bash
#SBATCH --job-name=d103-gh61
#SBATCH --account=def-snakagaw
#SBATCH --time=00:20:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH --array=0-95%3
#SBATCH --output=/project/def-snakagaw/snakagaw/design103-20260724/array-%A_%a.out

set -euo pipefail
module load gcc/12.3 r/4.4.0
export R_LIBS="$HOME/.local/R/4.4.0"
export OPENBLAS_NUM_THREADS=1
root=/project/def-snakagaw/snakagaw/design103-20260724
read seed n regime method < <(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$root/code/gh61-tasks.tsv")
mkdir -p "$root/records"
Rscript --vanilla "$root/code/run-gh-method.R" \
  "$seed" "$n" "$regime" "$method" 61 80 0 \
  "$root/records/gh61-${seed}-${n}-${regime}-${method}.rds" \
  "$root/code/design103_gh.cpp"
