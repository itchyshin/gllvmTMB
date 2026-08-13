#!/usr/bin/env bash
set -euo pipefail

SOURCE="/home/snakagaw/gllvmtmb_lane_b_quasi_20260808_v1"
ROOT="/home/snakagaw/gllvmtmb_lane_b_b2_20260808_v1/quasi-v1"
export R_LIBS="/home/snakagaw/gllvmtmb_lane_b_b0_exact_20260808_v2/Rlib:/home/snakagaw/gllvmtmb_lane_b_20260808_v1/Rlib"
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

if [[ ! -f "${ROOT}/frozen/lane-b-quasi-frozen-v1.rds" ]]; then
  Rscript --vanilla "${SOURCE}/inst/sim/lane-b/5_run_lane_b_quasi.R" \
    prepare --root "${ROOT}"
fi

tail -n +2 "${ROOT}/queue/lane-b-quasi-queue-v1.csv" | cut -d, -f1 | tr -d '"' | \
  xargs -P30 -I{} Rscript --vanilla \
    "${SOURCE}/inst/sim/lane-b/5_run_lane_b_quasi.R" run \
    --root "${ROOT}" --shard-id '{}'

Rscript --vanilla "${SOURCE}/inst/sim/lane-b/5_run_lane_b_quasi.R" \
  aggregate --root "${ROOT}"
