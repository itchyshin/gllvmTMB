#!/bin/bash
set -eu

if [ "$#" -ne 4 ]; then
  echo "usage: prepare-ci10-cost-array.sh SOURCE_ROOT TASK_TSV OUT_ROOT LIBRARY_ROOT" >&2
  exit 64
fi
source_root=$1
task_tsv=$2
out_root=$3
library_root=$4
expected_root=/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/ci10-cost-array
host=$(hostname -f)
case "$host:$out_root" in
  login[0-9]*.int.fir.alliancecan.ca:$expected_root) ;;
  *)
    echo "CI-10 cost array is pinned to a numbered Fir login host and the approved backed-up home root" >&2
    exit 65
    ;;
esac
. /cvmfs/soft.computecanada.ca/custom/software/lmod/lmod/init/bash
module load StdEnv/2023 gcc/12.3 r/4.5.0
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export R_LIBS_USER=$library_root
cd "$source_root"
Rscript --vanilla dev/interval-calibration/remote/validate-task-manifest.R \
  CI10_COST "$task_tsv"
if [ -e "$out_root" ] || ! mkdir "$out_root"; then
  echo "refusing existing or concurrently reserved CI-10 campaign root" >&2
  exit 65
fi
mkdir "$out_root/canonical" "$out_root/operations" \
  "$out_root/session" "$out_root/slurm"
cp "$task_tsv" "$out_root/task-manifest.tsv"
task_tsv=$out_root/task-manifest.tsv
session_receipt=$out_root/session/environment.rds
Rscript --vanilla dev/interval-calibration/remote/write-session-receipt.R \
  CI10_COST "$task_tsv" "$source_root" "$out_root" "$session_receipt"
export INTERVAL_SOURCE_ROOT=$source_root
export INTERVAL_TASK_TSV=$task_tsv
export INTERVAL_LIBRARY_ROOT=$library_root
export INTERVAL_SESSION_RECEIPT=$session_receipt
source_sha=$(Rscript --vanilla -e \
  'source(commandArgs(TRUE)[1]); cat(interval_approved_source("CI10_COST"))' \
  dev/interval-calibration/remote/shard-io.R)
manifest_sha=$(sha256sum "$task_tsv" | awk '{print $1}')
submission_output=$out_root/slurm/submission-output.txt

write_receipt() {
  schema=$1
  receipt=$2
  status=$3
  job_id=$4
  tmp=$receipt.tmp.$$
  {
    printf 'schema\t%s\n' "$schema"
    printf 'packet\tCI10_COST\n'
    printf 'source_sha\t%s\n' "$source_sha"
    printf 'task_manifest_sha256\t%s\n' "$manifest_sha"
    printf 'output_root\t%s\n' "$out_root"
    printf 'submission_exit_status\t%s\n' "$status"
    printf 'job_id\t%s\n' "$job_id"
    printf 'submission_output\t%s\n' "$submission_output"
    printf 'recorded_at_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$tmp"
  mv "$tmp" "$receipt"
}

if sbatch --parsable \
  dev/interval-calibration/remote/ci10-cost-array.sbatch \
  > "$submission_output" 2>&1; then
  raw_job_id=$(sed -n '1p' "$submission_output")
  job_id=${raw_job_id%%;*}
  case "$job_id" in
    ''|*[!0-9]*)
      write_receipt \
        INTERVAL_CALIBRATION_CI10_SUBMISSION_AMBIGUOUS_V1 \
        "$out_root/operations/ci10-cost-array-submission-ambiguous.tsv" \
        0 "$raw_job_id"
      echo "sbatch succeeded but returned an unparseable job id; inspect before any action" >&2
      exit 66
      ;;
  esac
  write_receipt \
    INTERVAL_CALIBRATION_CI10_SUBMITTED_V1 \
    "$out_root/operations/ci10-cost-array-submitted.tsv" \
    0 "$job_id"
  printf 'INTERVAL_CI10_SUBMITTED %s\n' "$job_id"
else
  status=$?
  write_receipt \
    INTERVAL_CALIBRATION_CI10_SUBMISSION_FAILED_V1 \
    "$out_root/operations/ci10-cost-array-submission-failed.tsv" \
    "$status" ""
  echo "CI-10 sbatch submission failed; immutable root retained for review" >&2
  exit "$status"
fi
