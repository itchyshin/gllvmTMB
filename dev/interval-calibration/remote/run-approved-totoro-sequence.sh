#!/bin/sh
set -eu

: "${INTERVAL_CAMPAIGN_BASE:=/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25}"
base=$INTERVAL_CAMPAIGN_BASE
case "$base" in
  /home/snakagaw/gllvmTMB-interval-calibration/2026-08-25|\
  /home/snakagaw/gllvmTMB-interval-calibration/2026-08-25-r2) ;;
  *) echo "Totoro sequence root is outside the approved original/retry envelope" >&2; exit 65 ;;
esac
export INTERVAL_DEPENDENCY_LIBRARY_ROOT=/home/snakagaw/R/x86_64-pc-linux-gnu-library/4.5
deploy=$base/deployment
orchestrator=$base/orchestrator
prepared=$deploy/prepared-totoro.tsv
post_guard=$deploy/post-guard-receipt-v2.rds
started=$deploy/totoro-sequence-started.tsv
completed=$deploy/totoro-sequence-completed.tsv
failed=$deploy/totoro-sequence-failed.tsv
log=$deploy/totoro-sequence.log
lock=$deploy/totoro-sequence-lock

if [ "$(hostname -f)" != "totoro.biology.ualberta.ca" ] || \
   [ ! -f "$prepared" ] || [ ! -f "$post_guard" ]; then
  echo "Totoro sequence requires the approved prepared host" >&2
  exit 65
fi
cd "$deploy"
sha256sum -c remote-payload-checksums.sha256
expected_sha=$(awk -F '\t' '$1 == "orchestrator_sha" {print $2}' approved-dispatch.tsv)
if [ -z "$expected_sha" ] || \
   [ "$(git -C "$orchestrator" rev-parse HEAD)" != "$expected_sha" ] || \
   [ -n "$(git -C "$orchestrator" status --porcelain --untracked-files=all)" ]; then
  echo "Totoro orchestration checkout differs from the approved clean commit" >&2
  exit 65
fi
Rscript --vanilla \
  "$orchestrator/dev/interval-calibration/remote/validate-post-guard-receipt.R" \
  PVT02 "$deploy/manifests/pvt02-tasks.tsv" "$post_guard"
if [ -e "$started" ] || [ -e "$completed" ] || [ -e "$failed" ]; then
  echo "Totoro sequence already has an operational receipt" >&2
  exit 65
fi
if ! mkdir "$lock"; then
  echo "Totoro sequence is already reserved or requires review" >&2
  exit 65
fi

{
  printf 'schema\tINTERVAL_CALIBRATION_TOTORO_SEQUENCE_STARTED_V1\n'
  printf 'pid\t%s\n' "$$"
  printf 'started_at_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$started"

run_sequence() {
  for packet in PVT02 CI09 CI13 CI14 CI15; do
    lower=$(printf '%s' "$packet" | tr '[:upper:]' '[:lower:]')
    if [ "$packet" = "PVT02" ]; then lower=pvt02; fi
    source_sha=$(Rscript --vanilla -e \
      'source(commandArgs(TRUE)[1]); cat(interval_approved_source(commandArgs(TRUE)[2]))' \
      "$orchestrator/dev/interval-calibration/remote/shard-io.R" "$packet")
    export INTERVAL_LIBRARY_ROOT=$base/libraries/$source_sha
    sh "$orchestrator/dev/interval-calibration/remote/run-totoro-wave.sh" \
      "$packet" "$deploy/manifests/$lower-tasks.tsv" \
      "$base/$lower" "$orchestrator"
  done
}

if run_sequence >> "$log" 2>&1; then
  {
    printf 'schema\tINTERVAL_CALIBRATION_TOTORO_SEQUENCE_COMPLETED_V1\n'
    printf 'completed_at_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$completed"
  exit 0
else
  status=$?
fi
{
  printf 'schema\tINTERVAL_CALIBRATION_TOTORO_SEQUENCE_FAILED_V1\n'
  printf 'exit_status\t%s\n' "$status"
  printf 'failed_at_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$failed"
exit "$status"
