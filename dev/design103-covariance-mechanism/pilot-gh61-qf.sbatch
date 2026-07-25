#!/bin/bash
#SBATCH --job-name=d103-gh61-qf
#SBATCH --account=def-snakagaw
#SBATCH --time=00:45:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH --output=/project/def-snakagaw/snakagaw/design103-20260724/pilot-gh61-qf-%j.out

set -euo pipefail
module load gcc/12.3 r/4.4.0
export R_LIBS="$HOME/.local/R/4.4.0"
export OPENBLAS_NUM_THREADS=1
root=/project/def-snakagaw/snakagaw/design103-20260724
mkdir -p "$root/records"
Rscript --vanilla "$root/code/run-gh-method.R" \
  102001 240 correlated QF 61 80 0 \
  "$root/records/pilot-gh61-qf.rds" \
  "$root/code/design103_gh.cpp"
