#!/usr/bin/env bash
set -euo pipefail
ROOT=${1:?usage: prepare-runtime.sh <source-root> <R-library>}
LIB=${2:?usage: prepare-runtime.sh <source-root> <R-library>}
cd "$ROOT"
mkdir -p "$LIB"
R CMD INSTALL -l "$LIB" "$ROOT"
Rscript --vanilla dev/isdm-requalification/response-information/verify-contract.R
Rscript --vanilla dev/isdm-requalification/response-information/verify-tests.R
test -z "$(git status --porcelain)"
