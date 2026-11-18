#!/usr/bin/env bash
#SBATCH --account=def-snakagaw_cpu
#SBATCH --job-name=g2k-ijssm
#SBATCH --time=00:20:00
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --array=1-150%50
#SBATCH --output=logs/g2k_%A_%a.out
#SBATCH --error=logs/g2k_%A_%a.err

# Scheduler wrapper for the immutable G2k recovery fixture.  This script does
# not initialise or summarise a campaign: the caller must do those actions
# once, before and after the array, with run-g2k-calibration.R.
set -euo pipefail

: "${G2K_ROOT:?Set G2K_ROOT to the initialized private campaign root}"
: "${G2K_PKG:?Set G2K_PKG to the checked-out package source}"
: "${G2K_SHA:?Set G2K_SHA to the exact package commit}"
: "${G2I_PRIVATE_R_LIB:?Set G2I_PRIVATE_R_LIB to the private R library}"

module load StdEnv/2023 gcc r/4.4.0
export R_LIBS_USER="${G2I_PRIVATE_R_LIB}"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1

mkdir -p "${G2K_ROOT}/logs"
seed="$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "${G2K_ROOT}/seed-grid.csv" | cut -d, -f1)"
if [[ ! "${seed}" =~ ^[1-9][0-9]*$ ]]; then
  echo "No seed for array task ${SLURM_ARRAY_TASK_ID}" >&2
  exit 2
fi

exec bash "${G2K_PKG}/dev/isdm-package-recovery/run-g2k-calibration-worker.sh" \
  "${seed}" "${G2K_ROOT}" "${G2K_PKG}" "${G2K_SHA}"
