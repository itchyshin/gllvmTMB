#!/usr/bin/env bash
#SBATCH --account=def-snakagaw_cpu
#SBATCH --job-name=laneB_q_keep
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --output=/dev/null

set -euo pipefail
# Pass sbatch --output explicitly to retain scheduler logs.
RUN_ROOT=${GLLVMTMB_LANE_B_RUN_ROOT:?set GLLVMTMB_LANE_B_RUN_ROOT}
KEEP=${GLLVMTMB_LANE_B_KEEP_ROOT:?set GLLVMTMB_LANE_B_KEEP_ROOT}
mkdir -p "${KEEP}"
tar -C "${RUN_ROOT}" -czf \
  "${KEEP}/lane-b-quasi-results-v3.tar.gz" results
sha256sum "${KEEP}/lane-b-quasi-results-v3.tar.gz" > \
  "${KEEP}/lane-b-quasi-results-v3.sha256"
cp "${RUN_ROOT}"/logs/aggregate-*.out "${KEEP}/"
