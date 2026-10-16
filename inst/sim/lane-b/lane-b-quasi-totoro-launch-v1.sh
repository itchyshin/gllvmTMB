#!/usr/bin/env bash
set -euo pipefail

SOURCE=${GLLVMTMB_LANE_B_SOURCE:?set GLLVMTMB_LANE_B_SOURCE}
ROOT=${GLLVMTMB_LANE_B_CAMPAIGN:?set GLLVMTMB_LANE_B_CAMPAIGN}
export R_LIBS=${GLLVMTMB_LANE_B_RLIB:?set GLLVMTMB_LANE_B_RLIB}
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
