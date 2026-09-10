#!/usr/bin/env bash
#SBATCH --account=def-snakagaw_cpu
#SBATCH --job-name=laneB_q_aggr
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=12G
#SBATCH --output=/scratch/snakagaw/lane_b_quasi_20260808_v3/logs/aggregate-%j.out

set -euo pipefail
module load StdEnv/2023 gcc/12.3 r/4.5.0
module load gdal/3.9.1 geos/3.12.0 proj/9.4.1 udunits/2.2.28
export R_LIBS_USER=/home/snakagaw/R/lane_b_4.5
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

cd /scratch/snakagaw/lane_b_quasi_20260808_v3/source/gllvmTMB
Rscript --vanilla inst/sim/lane-b/5_run_lane_b_quasi.R aggregate \
  --root /scratch/snakagaw/lane_b_quasi_20260808_v3/results
