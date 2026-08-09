#!/usr/bin/env bash
#SBATCH --account=def-snakagaw_cpu
#SBATCH --job-name=laneB_q_setup
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=/scratch/snakagaw/lane_b_quasi_20260808_v3/logs/setup-%j.out

set -euo pipefail
module load StdEnv/2023 gcc/12.3 r/4.5.0
module load gdal/3.9.1 geos/3.12.0 proj/9.4.1 udunits/2.2.28
export R_LIBS_USER=/home/snakagaw/R/lane_b_4.5
export MAKEFLAGS=-j4
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export GLLVMTMB_LANE_B_TARBALL_SHA256
GLLVMTMB_LANE_B_TARBALL_SHA256=$(sha256sum \
  /scratch/snakagaw/lane_b_quasi_20260808_v3/source/gllvmTMB_0.6.0.tar.gz | awk '{print $1}')

Rscript --vanilla -e 'install.packages(c("assertthat", "BH", "cli", "detectseparation", "fmesher", "generics", "lifecycle", "RcppEigen", "rlang", "TMB", "tidyselect"), repos="https://cloud.r-project.org", lib=Sys.getenv("R_LIBS_USER"), dependencies=c("Depends", "Imports", "LinkingTo"), Ncpus=4L)'
R CMD INSTALL --preclean --library="${R_LIBS_USER}" \
  /scratch/snakagaw/lane_b_quasi_20260808_v3/source/gllvmTMB_0.6.0.tar.gz

cd /scratch/snakagaw/lane_b_quasi_20260808_v3/source/gllvmTMB
Rscript --vanilla -e 'stopifnot(packageVersion("detectseparation") >= "0.4.0", requireNamespace("gllvmTMB", quietly=TRUE)); cat("setup verified\n")'
Rscript --vanilla inst/sim/lane-b/5_run_lane_b_quasi.R prepare \
  --root /scratch/snakagaw/lane_b_quasi_20260808_v3/results
