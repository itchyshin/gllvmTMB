#!/usr/bin/env bash
set -euo pipefail
ROOT=${1:?usage: run-retained.sh <source-root> <R-library> <task-id> <output-root>}
LIB=${2:?usage: run-retained.sh <source-root> <R-library> <task-id> <output-root>}
ID=${3:?usage: run-retained.sh <source-root> <R-library> <task-id> <output-root>}
OUT=${4:?usage: run-retained.sh <source-root> <R-library> <task-id> <output-root>}
BASE_R_LIBS=${R_LIBS_USER:-}
export R_LIBS_USER="$LIB${BASE_R_LIBS:+:$BASE_R_LIBS}" OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
cd "$ROOT"
Rscript --vanilla dev/isdm-requalification/response-information/run-retained.R dev/isdm-requalification/response-information/compute-inputs/scientific-plan.rds "$ID" "$OUT" "$OUT/runtime-identity.rds"
