#!/usr/bin/env bash
# SLURM wrapper for the Design 73 ordinary Gaussian LV Wald coverage campaign.
#
# Run this from a checked-out gllvmTMB repository on a DRAC login node.
# The default action validates the generated sbatch file with
# `sbatch --test-only`; it does not submit fit-running work unless
# `SLURM_ACTION=submit` is set.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash dev/lv-wald-coverage-slurm.sh

Environment variables:
  SLURM_ACTION          write | test | submit | summarise (default: test)
  RESULTS_DIR           durable output directory          (default: $PROJECT/$USER/gllvmtmb-lv-wald-coverage, else /tmp/$USER/gllvmtmb-lv-wald-coverage)
  N_REPS                reps per coverage cell            (default: 500)
  SEED_BASE             integer seed base                 (default: 20260628)
  INTERVAL_METHODS      comma-separated interval methods  (default: wald_z,wald_t_unit)
  SLURM_TIME            walltime per array task           (default: 00:30:00)
  SLURM_MEM             memory per array task             (default: 4G)
  SLURM_CPUS_PER_TASK   CPU threads per array task        (default: 1)
  SLURM_JOB_NAME        SLURM job name                    (default: gllvmtmb-lv-wald)
  SLURM_ACCOUNT         optional account                  (default: unset)
  SLURM_PARTITION       optional partition                (default: unset)
  SLURM_ARRAY_LIMIT     optional array concurrency cap    (default: unset)
  R_MODULE              R module to load                  (default: r/4.5.0)
  JULIA_MODULE          Julia module to load              (default: unset)
  DRAC_EXTRA_MODULES    optional modules to load first    (default: unset)
  R_LIBS_USER_DIR       user R library for the job         (default: $PROJECT/$USER/R/<R>, else $HOME/.local/R/<R>)
  SBATCH                sbatch executable                 (default: sbatch)

Examples:
  # Login-node-safe validation only; no submitted jobs.
  bash dev/lv-wald-coverage-slurm.sh

  # Write the sbatch file and plan without calling sbatch.
  SLURM_ACTION=write RESULTS_DIR=/project/$USER/gllvmtmb-lv-wald \
    bash dev/lv-wald-coverage-slurm.sh

  # Submit the full 4 x 500-rep campaign, capped at 40 concurrent tasks.
  SLURM_ACTION=submit SLURM_ACCOUNT=def-yourpi SLURM_ARRAY_LIMIT=40 \
    RESULTS_DIR=/project/$USER/gllvmtmb-lv-wald bash dev/lv-wald-coverage-slurm.sh

  # Collect after the array finishes.
  SLURM_ACTION=summarise RESULTS_DIR=/project/$USER/gllvmtmb-lv-wald \
    bash dev/lv-wald-coverage-slurm.sh

Boundaries:
  - Submit only from a DRAC login node; fits run inside SLURM array tasks.
  - One array task equals one seed/replicate from dev/lv-wald-coverage.R.
  - Totoro/local use is for staging or small pilots, not a substitute for
    DRAC production coverage evidence when the claim says DRAC.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

SLURM_ACTION="${SLURM_ACTION:-test}"
N_REPS="${N_REPS:-500}"
SEED_BASE="${SEED_BASE:-20260628}"
INTERVAL_METHODS="${INTERVAL_METHODS:-wald_z,wald_t_unit}"
SLURM_TIME="${SLURM_TIME:-00:30:00}"
SLURM_MEM="${SLURM_MEM:-4G}"
SLURM_CPUS_PER_TASK="${SLURM_CPUS_PER_TASK:-1}"
SLURM_JOB_NAME="${SLURM_JOB_NAME:-gllvmtmb-lv-wald}"
R_MODULE="${R_MODULE:-r/4.5.0}"
JULIA_MODULE="${JULIA_MODULE:-}"
DRAC_EXTRA_MODULES="${DRAC_EXTRA_MODULES:-}"
SBATCH="${SBATCH:-sbatch}"
R_MODULE_VERSION="${R_MODULE##*/}"

if [[ -z "${RESULTS_DIR:-}" ]]; then
  if [[ -n "${PROJECT:-}" ]]; then
    RESULTS_DIR="$PROJECT/$USER/gllvmtmb-lv-wald-coverage"
  else
    RESULTS_DIR="/tmp/$USER/gllvmtmb-lv-wald-coverage"
  fi
fi

if [[ -z "${R_LIBS_USER_DIR:-}" ]]; then
  if [[ -n "${PROJECT:-}" ]]; then
    R_LIBS_USER_DIR="$PROJECT/$USER/R/$R_MODULE_VERSION"
  elif [[ -n "${HOME:-}" ]]; then
    R_LIBS_USER_DIR="$HOME/.local/R/$R_MODULE_VERSION"
  else
    echo "Set R_LIBS_USER_DIR, PROJECT, or HOME before running this wrapper." >&2
    exit 2
  fi
fi

SBATCH_DIR="$RESULTS_DIR/_slurm"
SBATCH_FILE="$SBATCH_DIR/lv-wald-coverage.sbatch"
mkdir -p "$SBATCH_DIR"

task_count() {
  N_REPS="$N_REPS" SEED_BASE="$SEED_BASE" Rscript --vanilla - <<'RS'
source("dev/lv-wald-coverage.R")
plan <- lv_wald_coverage_grid(
  n_reps = as.integer(Sys.getenv("N_REPS")),
  seed_base = as.integer(Sys.getenv("SEED_BASE"))
)
cat(nrow(plan))
RS
}

TOTAL_TASKS="$(task_count)"
if ! [[ "$TOTAL_TASKS" =~ ^[0-9]+$ ]] || [[ "$TOTAL_TASKS" -lt 1 ]]; then
  echo "Could not determine a positive task count; got '$TOTAL_TASKS'." >&2
  exit 2
fi

array_spec="1-${TOTAL_TASKS}"
if [[ -n "${SLURM_ARRAY_LIMIT:-}" ]]; then
  array_spec="${array_spec}%${SLURM_ARRAY_LIMIT}"
fi

run_preflight() {
  GLLVMTMB_LV_WALD_COVERAGE_CLI=true \
    Rscript --vanilla dev/lv-wald-coverage.R \
      --mode=preflight \
      --n-reps="$N_REPS" \
      --seed-base="$SEED_BASE" \
      --interval-methods="$INTERVAL_METHODS" \
      --results-dir="$RESULTS_DIR"
}

write_sbatch() {
  {
    printf '#!/usr/bin/env bash\n'
    printf '#SBATCH --job-name=%s\n' "$SLURM_JOB_NAME"
    printf '#SBATCH --array=%s\n' "$array_spec"
    printf '#SBATCH --time=%s\n' "$SLURM_TIME"
    printf '#SBATCH --cpus-per-task=%s\n' "$SLURM_CPUS_PER_TASK"
    printf '#SBATCH --mem=%s\n' "$SLURM_MEM"
    printf '#SBATCH --output=%s/%%x-%%A-%%a.out\n' "$SBATCH_DIR"
    printf '#SBATCH --error=%s/%%x-%%A-%%a.err\n' "$SBATCH_DIR"
    if [[ -n "${SLURM_ACCOUNT:-}" ]]; then
      printf '#SBATCH --account=%s\n' "$SLURM_ACCOUNT"
    fi
    if [[ -n "${SLURM_PARTITION:-}" ]]; then
      printf '#SBATCH --partition=%s\n' "$SLURM_PARTITION"
    fi
    cat <<JOB

set -euo pipefail

if command -v module >/dev/null 2>&1; then
JOB
    if [[ -n "$DRAC_EXTRA_MODULES" ]]; then
      printf '  module load %s\n' "$DRAC_EXTRA_MODULES"
    fi
    printf '  module load "%s"\n' "$R_MODULE"
    if [[ -n "$JULIA_MODULE" ]]; then
      printf '  module load "%s"\n' "$JULIA_MODULE"
    fi
    cat <<JOB
fi

mkdir -p "$R_LIBS_USER_DIR"
export R_LIBS_USER="$R_LIBS_USER_DIR"
if [[ -n "\${R_LIBS:-}" ]]; then
  export R_LIBS="\$R_LIBS_USER:\$R_LIBS"
else
  export R_LIBS="\$R_LIBS_USER"
fi

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1

cd "$REPO_ROOT"

GLLVMTMB_LV_WALD_COVERAGE_CLI=true \\
  Rscript --vanilla dev/lv-wald-coverage.R \\
    --mode=task \\
    --task-id="\${SLURM_ARRAY_TASK_ID}" \\
    --n-reps="$N_REPS" \\
    --seed-base="$SEED_BASE" \\
    --interval-methods="$INTERVAL_METHODS" \\
    --results-dir="$RESULTS_DIR"
JOB
  } > "$SBATCH_FILE"
}

write_sbatch

echo "[lv-wald-slurm] action=$SLURM_ACTION"
echo "[lv-wald-slurm] results_dir=$RESULTS_DIR"
echo "[lv-wald-slurm] n_reps=$N_REPS total_tasks=$TOTAL_TASKS array=$array_spec"
echo "[lv-wald-slurm] interval_methods=$INTERVAL_METHODS"
echo "[lv-wald-slurm] sbatch_file=$SBATCH_FILE"
echo "[lv-wald-slurm] modules R=$R_MODULE Julia=${JULIA_MODULE:-none}"
if [[ -n "$DRAC_EXTRA_MODULES" ]]; then
  echo "[lv-wald-slurm] extra_modules=$DRAC_EXTRA_MODULES"
fi
echo "[lv-wald-slurm] r_libs_user_dir=$R_LIBS_USER_DIR"

case "$SLURM_ACTION" in
  write)
    run_preflight
    echo "[lv-wald-slurm] wrote sbatch file only"
    ;;
  test)
    run_preflight
    "$SBATCH" --test-only "$SBATCH_FILE"
    ;;
  submit)
    run_preflight
    "$SBATCH" "$SBATCH_FILE"
    ;;
  summarise)
    GLLVMTMB_LV_WALD_COVERAGE_CLI=true \
      Rscript --vanilla dev/lv-wald-coverage.R \
        --mode=summarise \
        --results-dir="$RESULTS_DIR"
    ;;
  *)
    echo "Unknown SLURM_ACTION: $SLURM_ACTION" >&2
    usage >&2
    exit 2
    ;;
esac
