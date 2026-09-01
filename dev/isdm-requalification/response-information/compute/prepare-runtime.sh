#!/usr/bin/env bash
set -euo pipefail
ROOT=${1:?usage: prepare-runtime.sh <source-root> <R-library>}
LIB=${2:?usage: prepare-runtime.sh <source-root> <R-library>}
cd "$ROOT"
mkdir -p "$LIB"
rm -f gllvmTMB_*.tar.gz
R CMD build .
R CMD INSTALL -l "$LIB" gllvmTMB_*.tar.gz
Rscript --vanilla dev/isdm-requalification/response-information/verify-contract.R
Rscript --vanilla dev/isdm-requalification/response-information/verify-tests.R
