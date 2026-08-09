#!/usr/bin/env bash
#SBATCH --account=def-snakagaw_cpu
#SBATCH --job-name=laneB_q_keep
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --output=/scratch/snakagaw/lane_b_quasi_20260808_v3/logs/keeper-%j.out

set -euo pipefail
KEEP=/home/snakagaw/lane_b_quasi_20260808_v3_keep
mkdir -p "${KEEP}"
tar -C /scratch/snakagaw/lane_b_quasi_20260808_v3 -czf \
  "${KEEP}/lane-b-quasi-results-v3.tar.gz" results
sha256sum "${KEEP}/lane-b-quasi-results-v3.tar.gz" > \
  "${KEEP}/lane-b-quasi-results-v3.sha256"
cp /scratch/snakagaw/lane_b_quasi_20260808_v3/logs/aggregate-*.out "${KEEP}/"
