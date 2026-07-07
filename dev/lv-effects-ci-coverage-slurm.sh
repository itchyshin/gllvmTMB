#!/bin/bash
## ============================================================================
## SLURM array harness for the B_lv CI ADEMP coverage campaign (Model A).
## One seed block per array task; >= 500 reps/cell for production admission.
## Runs on DRAC (Fir/Nibi/Rorqual/Narval) or Totoro. Companion: lv-effects-ci-coverage.R
##
## Example (100 tasks x 5 reps = 500 reps/cell), for one cell:
##   sbatch --array=1-100%50 lv-effects-ci-coverage-slurm.sh gauss-S200-K1 5
## Then summarise (login node OK, it is cheap):
##   Rscript lv-effects-ci-coverage.R summarise results/lv-effects-ci-coverage
## ============================================================================
#SBATCH --job-name=blv-ci-cov
#SBATCH --account=def-YOURPI          # <-- set: def-<pi> (DRAC); omit on Totoro
#SBATCH --time=02:00:00               # right-size with `seff` after one run
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH --output=results/_slurm/%x-%A_%a.out
#SBATCH --error=results/_slurm/%x-%A_%a.err

set -euo pipefail
CELL_ID="${1:?usage: sbatch ... lv-effects-ci-coverage-slurm.sh <cell_id> <reps_per_task>}"
REPS_PER_TASK="${2:-5}"
TASK_ID="${SLURM_ARRAY_TASK_ID:-1}"

## Keep BLAS single-threaded (one core per task; parallelism is the array).
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
export NOT_CRAN=true

## Cluster module load (adjust to the site); the R library with gllvmTMB + TMB
## must live on /project (never /scratch). On Totoro, just use the local R.
module load r/4.5.0 2>/dev/null || true

mkdir -p results/_slurm
Rscript dev/lv-effects-ci-coverage.R run "${CELL_ID}" "${TASK_ID}" "${REPS_PER_TASK}"
