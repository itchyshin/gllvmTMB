#!/usr/bin/env bash
set -euo pipefail
ROOT=${1:?usage: prepare-runtime.sh <source-root> <R-library>}
LIB=${2:?usage: prepare-runtime.sh <source-root> <R-library>}
BASE_R_LIBS=${R_LIBS_USER:-}
export R_LIBS_USER="$LIB${BASE_R_LIBS:+:$BASE_R_LIBS}"
cd "$ROOT"
mkdir -p "$LIB"
R CMD INSTALL -l "$LIB" "$ROOT"
Rscript --vanilla dev/isdm-requalification/response-information/verify-contract.R
test -z "$(git status --porcelain)"
