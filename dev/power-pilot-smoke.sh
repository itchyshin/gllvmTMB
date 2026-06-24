#!/usr/bin/env bash
# Local/Totoro smoke wrapper for the immutable power-pilot audit ladder.
#
# This script is intentionally small and conservative. The default `all`
# stage runs a one-rep, no-bootstrap local smoke through:
#   audit-mini manifest -> audit-mini-run -> chunk-audit -> chunk-aggregate
#   -> chunk-aggregate report
#
# DRAC login-node-safe use:
#   SMOKE_STAGE=manifest RESULTS_DIR=/scratch/$USER/gllvmtmb-audit-mini \
#     bash dev/power-pilot-smoke.sh
#
# Fit-running stages (`run` and `all`) are for local/Totoro or scheduled
# compute jobs, not DRAC login nodes. This wrapper does not submit SLURM jobs
# and does not start the production power campaign.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash dev/power-pilot-smoke.sh

Environment variables:
  SMOKE_STAGE   all | manifest | run | postrun   (default: all)
  RESULTS_DIR   output directory                 (default: mktemp under /tmp)
  SEED_BASE     integer seed base                (default: 171)
  N_SIM_STEP    reps per audit-mini chunk         (default: 1)
  N_SIM_CAP     per-cell cap for the smoke        (default: N_SIM_STEP)
  N_BOOT        bootstrap reps                    (default: 0)
  RSCRIPT       Rscript executable                (default: Rscript)

Examples:
  bash dev/power-pilot-smoke.sh

  SMOKE_STAGE=manifest RESULTS_DIR=/scratch/$USER/gllvmtmb-audit-mini \
    bash dev/power-pilot-smoke.sh

  RESULTS_DIR=/tmp/gllvmtmb-audit-mini-run SMOKE_STAGE=run \
    bash dev/power-pilot-smoke.sh

Boundaries:
  - manifest is the only DRAC-login-safe stage.
  - run/all fit tiny local chunks; use only on local/Totoro or compute jobs.
  - no SLURM submission, no GPU use, no production n_sim = 2000 campaign.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

SMOKE_STAGE="${SMOKE_STAGE:-all}"
SEED_BASE="${SEED_BASE:-171}"
N_SIM_STEP="${N_SIM_STEP:-1}"
N_SIM_CAP="${N_SIM_CAP:-$N_SIM_STEP}"
N_BOOT="${N_BOOT:-0}"
RSCRIPT="${RSCRIPT:-Rscript}"

if [[ -z "${RESULTS_DIR:-}" ]]; then
  RESULTS_DIR="$(mktemp -d /tmp/gllvmtmb-power-pilot-smoke.XXXXXX)"
fi

export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"

run_r() {
  echo "+ $RSCRIPT --vanilla $*"
  "$RSCRIPT" --vanilla "$@"
}

run_manifest() {
  run_r dev/power-pilot-run.R \
    --mode=audit-mini \
    --seed-base="$SEED_BASE" \
    --n-sim-step="$N_SIM_STEP" \
    --n-sim-cap="$N_SIM_CAP" \
    --n-boot="$N_BOOT" \
    --results-dir="$RESULTS_DIR"
}

run_chunks() {
  run_r dev/power-pilot-run.R \
    --mode=audit-mini-run \
    --seed-base="$SEED_BASE" \
    --n-sim-step="$N_SIM_STEP" \
    --n-sim-cap="$N_SIM_CAP" \
    --n-boot="$N_BOOT" \
    --results-dir="$RESULTS_DIR"
}

run_postrun() {
  run_r dev/power-pilot-run.R \
    --mode=chunk-audit \
    --results-dir="$RESULTS_DIR"
  run_r dev/power-pilot-run.R \
    --mode=chunk-aggregate \
    --results-dir="$RESULTS_DIR"
  run_r dev/m3-pilot-report.R \
    --emit-issues \
    --chunk-aggregate \
    --results-dir="$RESULTS_DIR"
}

echo "[power-pilot-smoke] stage=$SMOKE_STAGE"
echo "[power-pilot-smoke] results_dir=$RESULTS_DIR"
echo "[power-pilot-smoke] seed_base=$SEED_BASE n_sim_step=$N_SIM_STEP n_sim_cap=$N_SIM_CAP n_boot=$N_BOOT"
echo "[power-pilot-smoke] threads OMP=$OMP_NUM_THREADS OPENBLAS=$OPENBLAS_NUM_THREADS MKL=$MKL_NUM_THREADS"

case "$SMOKE_STAGE" in
  manifest)
    run_manifest
    ;;
  run)
    run_chunks
    ;;
  postrun)
    run_postrun
    ;;
  all)
    run_manifest
    run_chunks
    run_postrun
    ;;
  *)
    echo "Unknown SMOKE_STAGE: $SMOKE_STAGE" >&2
    usage >&2
    exit 2
    ;;
esac

echo "[power-pilot-smoke] done: $RESULTS_DIR"
