#!/usr/bin/env bash
#SBATCH --account=def-snakagaw_cpu
#SBATCH --job-name=laneB_quasi
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --array=1-600%30
#SBATCH --output=/dev/null

set -euo pipefail
# Pass sbatch --output explicitly to retain scheduler logs.
RUN_ROOT=${GLLVMTMB_LANE_B_RUN_ROOT:?set GLLVMTMB_LANE_B_RUN_ROOT}
module load StdEnv/2023 gcc/12.3 r/4.5.0
module load gdal/3.9.1 geos/3.12.0 proj/9.4.1 udunits/2.2.28
export R_LIBS_USER=${GLLVMTMB_LANE_B_RLIB:?set GLLVMTMB_LANE_B_RLIB}
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

SOURCE="${RUN_ROOT}/source/gllvmTMB"
ROOT="${RUN_ROOT}/results"
QUEUE="${ROOT}/queue/lane-b-quasi-queue-v1.csv"
LINE_NUMBER=$((SLURM_ARRAY_TASK_ID + 1))
SHARD_ID=$(sed -n "${LINE_NUMBER}p" "${QUEUE}" | cut -d, -f1 | tr -d '"')
if [[ -z "${SHARD_ID}" ]]; then
  echo "No shard for array index ${SLURM_ARRAY_TASK_ID}" >&2
  exit 2
fi

cd "${SOURCE}"
Rscript --vanilla inst/sim/lane-b/5_run_lane_b_quasi.R run \
  --root "${ROOT}" --shard-id "${SHARD_ID}"
