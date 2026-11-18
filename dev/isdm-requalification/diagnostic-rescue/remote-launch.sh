#!/usr/bin/env bash
set -uo pipefail

packet="${1:?usage: remote-launch.sh PACKET_DIR PLAN_RDS OUTPUT_DIR QUALIFICATION_RDS WORKERS smoke|experiment}"
plan="${2:?}"
output="${3:?}"
qualification="${4:?}"
workers="${5:?}"
run_kind="${6:?}"
case "$run_kind" in smoke|experiment) ;; *) echo "invalid run kind" >&2; exit 2 ;; esac
case "$workers" in ''|*[!0-9]*) echo "WORKERS must be an integer" >&2; exit 2 ;; esac
if [ "$workers" -lt 1 ] || [ "$workers" -gt 16 ]; then
  echo "WORKERS must be between 1 and 16" >&2
  exit 2
fi
Rscript --vanilla "$packet/launch-preflight.R" "$plan" "$qualification" \
  "$run_kind" - || exit 4
if [ -e "$output" ]; then
  echo "refusing existing output directory: $output" >&2
  exit 3
fi
mkdir -p "$output/logs"
launch_begin=$(date +%s)
Rscript --vanilla "$packet/launch-preflight.R" "$plan" "$qualification" \
  "$run_kind" "$output/launch-start.rds" \
  >"$output/logs/launch-preflight.log" 2>&1 || exit 4
reconcile_on_exit() {
  status="$1"
  trap - EXIT INT TERM HUP
  launch_end=$(date +%s)
  runtime=$((launch_end - launch_begin))
  if [ ! -e "$output/launch-terminal.rds" ]; then
    Rscript --vanilla "$packet/write-launch-terminal.R" \
      "$output/launch-start.rds" "$status" "$runtime" \
      "$output/launch-terminal.rds" \
      >"$output/logs/launch-terminal.log" 2>&1 || status=91
  fi
  if [ "$status" -ne 0 ]; then
    if ! Rscript --vanilla "$packet/reconcile.R" "$plan" "$output" \
      "$qualification" "diagnostic supervisor status $status" \
      >"$output/logs/reconciliation.log" 2>&1; then
      echo "DIAGNOSTIC_RECONCILIATION_FAILED" >&2
      exit 90
    fi
  fi
  exit "$status"
}
trap 'reconcile_on_exit $?' EXIT
supervisor_pid=""
forward_signal() {
  signal="$1"
  status="$2"
  if [ -n "$supervisor_pid" ] && kill -0 "$supervisor_pid" 2>/dev/null; then
    kill -s "$signal" "$supervisor_pid" 2>/dev/null || true
    wait "$supervisor_pid" 2>/dev/null || true
  fi
  exit "$status"
}
trap 'forward_signal TERM 143' TERM
trap 'forward_signal INT 130' INT
trap 'forward_signal HUP 129' HUP
commands="$output/command-index.tsv"
Rscript --vanilla "$packet/command-index.R" "$plan" "$commands" "$run_kind" \
  >"$output/logs/command-index.log" 2>&1 || exit 4

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
export DIAGNOSTIC_PACKET="$packet"
export DIAGNOSTIC_PLAN="$plan"
export DIAGNOSTIC_OUTPUT="$output"
export DIAGNOSTIC_QUALIFICATION="$qualification"
export DIAGNOSTIC_RUN_KIND="$run_kind"

run_commands='while IFS=$'"'"'\t'"'"' read -r mode key; do
  Rscript --vanilla "$DIAGNOSTIC_PACKET/runner.R" "$mode" "$key" \
    "$DIAGNOSTIC_PLAN" "$DIAGNOSTIC_OUTPUT" "$DIAGNOSTIC_QUALIFICATION" \
    "$DIAGNOSTIC_RUN_KIND" \
    >"$DIAGNOSTIC_OUTPUT/logs/${mode}-${key}.log" 2>&1 &
  while [ "$(jobs -pr | wc -l)" -ge '"$workers"' ]; do
    wait -n || true
  done
done < "$DIAGNOSTIC_OUTPUT/command-index.tsv"
wait'

python3 "$packet/watchdog.py" 600 bash -c "$run_commands" &
supervisor_pid=$!
wait "$supervisor_pid"
status=$?
supervisor_pid=""
if [ "$status" -ne 0 ]; then
  echo "DIAGNOSTIC_LAUNCH_TERMINAL status=$status"
  exit "$status"
fi

Rscript --vanilla "$packet/reconcile.R" "$plan" "$output" \
  "$qualification" "normal completion reconciliation" \
  >"$output/logs/reconciliation.log" 2>&1 || exit 5
launch_end=$(date +%s)
runtime=$((launch_end - launch_begin))
Rscript --vanilla "$packet/write-launch-terminal.R" \
  "$output/launch-start.rds" 0 "$runtime" "$output/launch-terminal.rds" \
  >"$output/logs/launch-terminal.log" 2>&1 || exit 6
trap - EXIT
echo "DIAGNOSTIC_LAUNCH_COMPLETE"
