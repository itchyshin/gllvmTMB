#!/bin/bash
#SBATCH --account=def-snakagaw
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --array=1-18%18
#SBATCH --job-name=gllvmtmb-ci10-cost
#SBATCH --output=/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/ci10-cost-array/slurm/%A_%a.out
#SBATCH --error=/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/ci10-cost-array/slurm/%A_%a.err

set -eu
. /cvmfs/soft.computecanada.ca/custom/software/lmod/lmod/init/bash
module load StdEnv/2023 gcc/12.3 r/4.5.0
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

: "${INTERVAL_SOURCE_ROOT:?INTERVAL_SOURCE_ROOT is required}"
: "${INTERVAL_TASK_TSV:?INTERVAL_TASK_TSV is required}"
: "${INTERVAL_LIBRARY_ROOT:?INTERVAL_LIBRARY_ROOT is required}"
: "${INTERVAL_SESSION_RECEIPT:?INTERVAL_SESSION_RECEIPT is required}"
export R_LIBS_USER=$INTERVAL_LIBRARY_ROOT

out_root=/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/ci10-cost-array
test -f "$INTERVAL_SESSION_RECEIPT"
cd "$INTERVAL_SOURCE_ROOT"
Rscript --vanilla dev/interval-calibration/remote/validate-task-manifest.R \
  CI10_COST "$INTERVAL_TASK_TSV"

task=$(awk -F '\t' -v row="$SLURM_ARRAY_TASK_ID" 'NR == row + 1 {print $0}' "$INTERVAL_TASK_TSV")
if [ -z "$task" ]; then
  echo "missing CI-10 task row $SLURM_ARRAY_TASK_ID" >&2
  exit 65
fi
packet=$(printf '%s\n' "$task" | cut -f1)
cell_id=$(printf '%s\n' "$task" | cut -f2)
rep=$(printf '%s\n' "$task" | cut -f3)
source_sha=$(printf '%s\n' "$task" | cut -f4)
attempt=$(printf '%s\n' "$task" | cut -f5)

seed=$(printf '%s\n' "$task" | cut -f6)
expected_seed=$((60718 + 1000003 * cell_id + 3))
if [ "$packet" != CI10_COST ] || [ "$rep" -ne 3 ] || \
   [ "$cell_id" -ne "$SLURM_ARRAY_TASK_ID" ] || [ "$attempt" -ne 1 ] || \
   [ "$source_sha" != 328d8abc9125ce1e7edbcdcdcb1a41f043488431 ] || \
   [ "$seed" -ne "$expected_seed" ]; then
  echo "CI-10 array task violates the approved cost-only identity" >&2
  exit 65
fi

if timeout --signal=TERM --kill-after=30s 28m \
  Rscript --vanilla dev/interval-calibration/remote/run-shard.R \
    "$packet" "$cell_id" "$rep" "$source_sha" "$out_root" "$attempt"
then
  exit 0
else
  task_status=$?
  Rscript --vanilla dev/interval-calibration/remote/record-operational-timeout.R \
    "$packet" "$cell_id" "$rep" "$attempt" "$source_sha" "$out_root" \
    "DRAC task exited nonzero or reached its 28-minute inner hard stop"
  exit "$task_status"
fi
