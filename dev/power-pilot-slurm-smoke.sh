#!/usr/bin/env bash
# SLURM wrapper for the power-pilot audit-mini smoke ladder.
#
# This script is meant to be run from a DRAC login node inside a checked-out
# gllvmTMB repository. By default it writes an sbatch file and asks SLURM to
# validate it with `sbatch --test-only`; it does not submit work unless
# `SLURM_ACTION=submit` is set.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash dev/power-pilot-slurm-smoke.sh

Environment variables:
  SLURM_ACTION          write | test | submit       (default: test)
  RESULTS_DIR           durable output directory    (default: /scratch/$USER/gllvmtmb-power-pilot-smoke)
  SLURM_STAGE           manifest | all | run | postrun (default: manifest)
  SLURM_TIME            walltime                    (default: 00:20:00)
  SLURM_MEM             memory per task             (default: 4G)
  SLURM_CPUS_PER_TASK   CPU threads                 (default: 1)
  SLURM_JOB_NAME        SLURM job name              (default: gllvmtmb-smoke)
  SLURM_ACCOUNT         optional account            (default: unset)
  SLURM_PARTITION       optional partition          (default: unset)
  R_MODULE              R module to load            (default: r/4.5.0)
  JULIA_MODULE          Julia module to load        (default: julia/1.12.5)
  SEED_BASE             integer seed base           (default: 181)
  N_SIM_STEP            reps per audit-mini chunk   (default: 1)
  N_SIM_CAP             per-cell cap                (default: N_SIM_STEP)
  N_BOOT                bootstrap reps              (default: 0)

Examples:
  # Login-node-safe validation only; no submitted job.
  bash dev/power-pilot-slurm-smoke.sh

  # Submit the first DRAC smoke: manifest parse only, no fits.
  SLURM_ACTION=submit bash dev/power-pilot-slurm-smoke.sh

  # Submit the second DRAC smoke from a login node: scheduled tiny fits.
  SLURM_ACTION=submit SLURM_STAGE=all SLURM_TIME=01:00:00 \
    bash dev/power-pilot-slurm-smoke.sh

Boundaries:
  - Default stage is manifest, which launches no fits.
  - Fit-running stages must run as scheduled SLURM jobs, not on login nodes.
  - No GPU use and no production n_sim = 2000 campaign.
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
SLURM_STAGE="${SLURM_STAGE:-manifest}"
SLURM_TIME="${SLURM_TIME:-00:20:00}"
SLURM_MEM="${SLURM_MEM:-4G}"
SLURM_CPUS_PER_TASK="${SLURM_CPUS_PER_TASK:-1}"
SLURM_JOB_NAME="${SLURM_JOB_NAME:-gllvmtmb-smoke}"
R_MODULE="${R_MODULE:-r/4.5.0}"
JULIA_MODULE="${JULIA_MODULE:-julia/1.12.5}"
SEED_BASE="${SEED_BASE:-181}"
N_SIM_STEP="${N_SIM_STEP:-1}"
N_SIM_CAP="${N_SIM_CAP:-$N_SIM_STEP}"
N_BOOT="${N_BOOT:-0}"
SBATCH="${SBATCH:-sbatch}"

if [[ -z "${RESULTS_DIR:-}" ]]; then
  if [[ -n "${SCRATCH:-}" ]]; then
    RESULTS_DIR="$SCRATCH/gllvmtmb-power-pilot-smoke"
  else
    RESULTS_DIR="/tmp/$USER/gllvmtmb-power-pilot-smoke"
  fi
fi

SBATCH_DIR="$RESULTS_DIR/_slurm"
SBATCH_FILE="$SBATCH_DIR/power-pilot-smoke.sbatch"
mkdir -p "$SBATCH_DIR"

write_sbatch() {
  {
    printf '#!/usr/bin/env bash\n'
    printf '#SBATCH --job-name=%s\n' "$SLURM_JOB_NAME"
    printf '#SBATCH --time=%s\n' "$SLURM_TIME"
    printf '#SBATCH --cpus-per-task=%s\n' "$SLURM_CPUS_PER_TASK"
    printf '#SBATCH --mem=%s\n' "$SLURM_MEM"
    printf '#SBATCH --output=%s/%%x-%%j.out\n' "$SBATCH_DIR"
    printf '#SBATCH --error=%s/%%x-%%j.err\n' "$SBATCH_DIR"
    if [[ -n "${SLURM_ACCOUNT:-}" ]]; then
      printf '#SBATCH --account=%s\n' "$SLURM_ACCOUNT"
    fi
    if [[ -n "${SLURM_PARTITION:-}" ]]; then
      printf '#SBATCH --partition=%s\n' "$SLURM_PARTITION"
    fi
    cat <<JOB

set -euo pipefail

module load "$R_MODULE"
module load "$JULIA_MODULE"

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1

cd "$REPO_ROOT"

SMOKE_STAGE="$SLURM_STAGE" \\
RESULTS_DIR="$RESULTS_DIR" \\
SEED_BASE="$SEED_BASE" \\
N_SIM_STEP="$N_SIM_STEP" \\
N_SIM_CAP="$N_SIM_CAP" \\
N_BOOT="$N_BOOT" \\
bash dev/power-pilot-smoke.sh
JOB
  } > "$SBATCH_FILE"
}

write_sbatch

echo "[power-pilot-slurm-smoke] action=$SLURM_ACTION"
echo "[power-pilot-slurm-smoke] stage=$SLURM_STAGE"
echo "[power-pilot-slurm-smoke] results_dir=$RESULTS_DIR"
echo "[power-pilot-slurm-smoke] sbatch_file=$SBATCH_FILE"
echo "[power-pilot-slurm-smoke] modules R=$R_MODULE Julia=$JULIA_MODULE"
echo "[power-pilot-slurm-smoke] threads cpus=$SLURM_CPUS_PER_TASK OMP=1 OPENBLAS=1 MKL=1"

case "$SLURM_ACTION" in
  write)
    echo "[power-pilot-slurm-smoke] wrote sbatch file only"
    ;;
  test)
    "$SBATCH" --test-only "$SBATCH_FILE"
    ;;
  submit)
    "$SBATCH" "$SBATCH_FILE"
    ;;
  *)
    echo "Unknown SLURM_ACTION: $SLURM_ACTION" >&2
    usage >&2
    exit 2
    ;;
esac
