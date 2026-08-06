#!/usr/bin/env bash
#SBATCH --job-name=va-gh-h7
#SBATCH --array=1-10800%100
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=6G
#SBATCH --output=va-gh-h7-%A-%a.out
#SBATCH --error=va-gh-h7-%A-%a.err

# Submit only after Gate E, from a DRAC login node. One array task is one plan
# row and therefore one seed. Adjust --array to exactly nrow(plan), and always
# provide --account at submission.

set -euo pipefail

: "${REPO_DIR:?Set REPO_DIR to the gllvmTMB checkout on /project}"
: "${CAMPAIGN_PROJECT_ROOT:?Set CAMPAIGN_PROJECT_ROOT under /project}"
: "${GATE_E_RECEIPT:?Set GATE_E_RECEIPT to a durable Gate-E receipt}"
: "${SLURM_ARRAY_TASK_ID:?This template must run as a SLURM array task}"

case "$REPO_DIR" in /project/*) ;; *) echo "REPO_DIR must be under /project" >&2; exit 2;; esac
case "$CAMPAIGN_PROJECT_ROOT" in /project/*) ;; *) echo "CAMPAIGN_PROJECT_ROOT must be under /project" >&2; exit 2;; esac
[[ -f "$GATE_E_RECEIPT" ]] && grep -qx 'PASS' "$GATE_E_RECEIPT" || {
  echo "Gate-E receipt missing or not PASS" >&2; exit 3; }

module load "${R_MODULE:-r/4.5.0}"

export R_LIBS_USER="$CAMPAIGN_PROJECT_ROOT/R/library"
export R_LIBS="$R_LIBS_USER${R_LIBS:+:$R_LIBS}"
export R_USER_CACHE_DIR="$CAMPAIGN_PROJECT_ROOT/R/cache"
export RENV_PATHS_CACHE="$CAMPAIGN_PROJECT_ROOT/R/renv-cache"
export JULIA_DEPOT_PATH="$CAMPAIGN_PROJECT_ROOT/julia-depot"
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

PLAN="${PLAN:-$CAMPAIGN_PROJECT_ROOT/plan.csv}"
OUTPUT_DIR="${OUTPUT_DIR:-$CAMPAIGN_PROJECT_ROOT/results}"
case "$PLAN" in /project/*) ;; *) echo "PLAN must be under /project" >&2; exit 2;; esac
case "$OUTPUT_DIR" in /project/*) ;; *) echo "OUTPUT_DIR must be under /project" >&2; exit 2;; esac
[[ -f "$PLAN" ]] || { echo "immutable plan missing: $PLAN" >&2; exit 4; }

mkdir -p "$R_LIBS_USER" "$R_USER_CACHE_DIR" "$RENV_PATHS_CACHE" \
  "$JULIA_DEPOT_PATH" "$OUTPUT_DIR"
cd "$REPO_DIR"

Rscript --vanilla dev/va-gh-h7-campaign/run-cell.R \
  --mode=run --plan="$PLAN" --output-dir="$OUTPUT_DIR" \
  --task-index="$SLURM_ARRAY_TASK_ID"
