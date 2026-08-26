#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
  echo "usage: run-totoro-wave.sh PACKET TASK_TSV OUT_ROOT SOURCE_ROOT" >&2
  exit 64
fi

packet=$1
task_tsv=$2
out_root=$3
source_root=$4
campaign_base=$(dirname "$out_root")
case "$campaign_base" in
  /home/snakagaw/gllvmTMB-interval-calibration/2026-08-25|\
  /home/snakagaw/gllvmTMB-interval-calibration/2026-08-25-r2) ;;
  *) echo "Totoro campaign root is outside the approved original/retry envelope" >&2; exit 65 ;;
esac

case "$packet" in
  PVT02)
    expected_root=$campaign_base/pvt02
    predecessor=
    ;;
  CI09)
    expected_root=$campaign_base/ci09
    predecessor=$campaign_base/pvt02/aggregate/result.rds
    ;;
  CI13)
    expected_root=$campaign_base/ci13
    predecessor=$campaign_base/ci09/aggregate/result.rds
    ;;
  CI14)
    expected_root=$campaign_base/ci14
    predecessor=$campaign_base/ci13/aggregate/result.rds
    ;;
  CI15)
    expected_root=$campaign_base/ci15
    predecessor=$campaign_base/ci14/aggregate/result.rds
    ;;
  *) echo "refusing non-Totoro packet: $packet" >&2; exit 64 ;;
esac
if [ "$out_root" != "$expected_root" ]; then
  echo "Totoro packet root differs from the approved immutable root" >&2
  exit 65
fi
if [ -n "$predecessor" ] && [ ! -f "$predecessor" ]; then
  echo "previous approved Totoro wave is not complete: $predecessor" >&2
  exit 65
fi
mkdir -p "$campaign_base"
wave_lock=$campaign_base/.active-wave
if ! mkdir "$wave_lock"; then
  echo "another Totoro interval wave is active or its lock needs review" >&2
  exit 65
fi
task_args=
cleanup_wave() {
  if [ -n "$task_args" ]; then rm -f "$task_args"; fi
  rmdir "$wave_lock" 2>/dev/null || true
}
trap cleanup_wave EXIT HUP INT TERM

export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
: "${INTERVAL_LIBRARY_ROOT:?INTERVAL_LIBRARY_ROOT is required}"
: "${INTERVAL_DEPENDENCY_LIBRARY_ROOT:?INTERVAL_DEPENDENCY_LIBRARY_ROOT is required}"
export R_LIBS_USER=$INTERVAL_LIBRARY_ROOT:$INTERVAL_DEPENDENCY_LIBRARY_ROOT

cd "$source_root"
Rscript --vanilla dev/interval-calibration/remote/validate-task-manifest.R \
  "$packet" "$task_tsv"
if [ -e "$out_root" ] || ! mkdir "$out_root"; then
  echo "refusing existing or concurrently reserved campaign root" >&2
  exit 65
fi
mkdir "$out_root/canonical" "$out_root/operations" "$out_root/session"
cp "$task_tsv" "$out_root/task-manifest.tsv"
Rscript --vanilla dev/interval-calibration/remote/write-session-receipt.R \
  "$packet" "$out_root/task-manifest.tsv" "$source_root" "$out_root" \
  "$out_root/session/environment.rds"
remaining_tsv=$out_root/remaining-task-manifest.tsv
if [ "$packet" = "PVT02" ]; then
  Rscript --vanilla dev/interval-calibration/remote/import-post-guard-receipt.R \
    "$packet" "$task_tsv" \
    "$campaign_base/deployment/post-guard-receipt-v2.rds" \
    "$out_root" "$remaining_tsv"
else
  cp "$task_tsv" "$remaining_tsv"
fi
task_args=$(mktemp)
tail -n +2 "$remaining_tsv" |
  awk -F '\t' -v p="$packet" '$1 == p {print $2, $3, $4, $5}' > "$task_args"
expected=$(($(wc -l < "$task_tsv") - 1))
to_run=$(wc -l < "$task_args" | tr -d ' ')
if [ "$expected" -eq 0 ] || [ "$to_run" -eq 0 ]; then
  echo "empty task manifest for $packet" >&2
  exit 65
fi

if timeout --signal=TERM --kill-after=60s 2h \
  xargs -n 4 -P 96 sh -c '
    cell_id=$1
    rep=$2
    source_sha=$3
    attempt=$4
    Rscript --vanilla dev/interval-calibration/remote/run-shard.R \
      "'$packet'" "$cell_id" "$rep" "$source_sha" "'$out_root'" "$attempt"
  ' sh < "$task_args"
then
  wave_status=0
else
  wave_status=$?
  Rscript --vanilla dev/interval-calibration/remote/record-wave-timeouts.R \
    "$packet" "$task_tsv" "$out_root" \
    "Totoro wave exited nonzero or reached its two-hour hard stop"
  exit "$wave_status"
fi

actual=$(find "$out_root/canonical" -type f -name "$(printf '%s' "$packet" | tr '[:upper:]' '[:lower:]')-*.rds" | wc -l | tr -d ' ')
if [ "$actual" -ne "$expected" ]; then
  echo "wave retained $actual canonical shards; expected $expected" >&2
  exit 66
fi

sh dev/interval-calibration/remote/finalize-campaign.sh \
  "$packet" "$out_root/task-manifest.tsv" "$out_root" "$source_root"
