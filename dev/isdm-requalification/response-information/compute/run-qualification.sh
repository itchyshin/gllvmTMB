#!/usr/bin/env bash
set -euo pipefail
ROOT=${1:?usage: run-qualification.sh <source-root> <R-library> <qualification-id> <output-root>}
LIB=${2:?usage: run-qualification.sh <source-root> <R-library> <qualification-id> <output-root>}
ID=${3:?usage: run-qualification.sh <source-root> <R-library> <qualification-id> <output-root>}
OUT=${4:?usage: run-qualification.sh <source-root> <R-library> <qualification-id> <output-root>}
BASE_R_LIBS=${R_LIBS_USER:-}
export R_LIBS_USER="$LIB${BASE_R_LIBS:+:$BASE_R_LIBS}" OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
cd "$ROOT"
Rscript --vanilla dev/isdm-requalification/response-information/qualify.R dev/isdm-requalification/response-information/compute-inputs/qualification-plan.rds "$ID" "$OUT"
