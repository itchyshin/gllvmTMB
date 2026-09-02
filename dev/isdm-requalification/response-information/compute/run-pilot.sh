#!/usr/bin/env bash
set -euo pipefail
ROOT=${1:?usage: run-pilot.sh <source-root> <R-library> <array-index> <output-root>}
LIB=${2:?usage: run-pilot.sh <source-root> <R-library> <array-index> <output-root>}
INDEX=${3:?usage: run-pilot.sh <source-root> <R-library> <array-index> <output-root>}
OUT=${4:?usage: run-pilot.sh <source-root> <R-library> <array-index> <output-root>}
ID=$(Rscript --vanilla "$ROOT/dev/isdm-requalification/response-information/compute/pilot-task-id.R" "$ROOT/dev/isdm-requalification/response-information/compute-inputs/pilot-plan.rds" "$INDEX")
exec bash "$ROOT/dev/isdm-requalification/response-information/compute/run-retained.sh" "$ROOT" "$LIB" "$ID" "$OUT"
