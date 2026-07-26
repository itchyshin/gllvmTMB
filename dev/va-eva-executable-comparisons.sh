#!/bin/sh
# Run one private VA/EVA comparison track in a fresh R process.  Do not replace
# the five documented invocations with a single R process: the two TMB
# prototype DLLs are intentionally compiled/loaded independently and their
# reload order is not part of evidence.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RUNNER="$ROOT/dev/va-eva-comparison-runner.R"
OUT="$ROOT/dev/va-eva-engine-spine/receipts/executable-run"
mkdir -p "$OUT"

TRACK=${1:-}
case "$TRACK" in
  multitrial|bernoulli|va_exact|eva_exact)
    VA_EVA_EXECUTABLE_TRACK="$TRACK" VA_EVA_RESULT_PATH="$OUT/$TRACK.rds" VA_EVA_RUNNER_ROOT="$ROOT" Rscript --vanilla "$RUNNER"
    ;;
  assemble)
    VA_EVA_EXECUTABLE_COMPARISONS=true Rscript --vanilla "$RUNNER"
    ;;
  *)
    echo "Usage: sh dev/va-eva-executable-comparisons.sh {multitrial|bernoulli|va_exact|eva_exact|assemble}" >&2
    exit 64
    ;;
esac
