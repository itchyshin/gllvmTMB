#!/usr/bin/env bash
# dev/launch-local-pilot.sh
# =========================
# Durable-ish launcher for the SECOND (local) power-pilot engine
# (dev/m3-pilot-local-loop.R). This is the LIGHTWEIGHT option: a nohup'd
# background Rscript that survives the terminal/SSH session closing but
# does NOT auto-restart on crash or reboot. For the MORE durable option
# (auto-restart on crash, start at login) use the macOS LaunchAgent:
# dev/com.gllvmtmb.power-pilot-local.plist.template (see its header).
#
# ---------------------------------------------------------------------
# USAGE (run from anywhere; the script cd's to the repo root itself):
#
#   bash dev/launch-local-pilot.sh            # start the loop (nohup)
#   bash dev/launch-local-pilot.sh stop       # request a clean stop
#   bash dev/launch-local-pilot.sh status     # is it running? tail the log
#
# The loop pins to <= 10 cores (LOCAL_CORES in the R script). Override any
# setting via env, e.g.:
#   LOCAL_CORES=8 LOCAL_N_SIM_CAP=10000 bash dev/launch-local-pilot.sh
#
# ARTIFACTS (all under dev/, which is in .Rbuildignore):
#   dev/m3-pilot-local.log     - append-only run log (one line per batch)
#   dev/m3-pilot-local.pid     - PID of the running loop
#   dev/STOP-LOCAL-PILOT       - stop-flag file (created by `stop`)
#   dev/m3-pilot-results-local - the local accumulate store (gitignored)
# ---------------------------------------------------------------------

set -euo pipefail

# Resolve the repo root = the parent of this script's dev/ directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

LOG="dev/m3-pilot-local.log"
PIDFILE="dev/m3-pilot-local.pid"
STOPFLAG="dev/STOP-LOCAL-PILOT"
LOOP="dev/m3-pilot-local-loop.R"

cmd="${1:-start}"

is_running() {
  [ -f "$PIDFILE" ] || return 1
  local pid
  pid="$(cat "$PIDFILE" 2>/dev/null || true)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

case "$cmd" in
  start)
    if is_running; then
      echo "local pilot loop already running (PID $(cat "$PIDFILE"))."
      exit 0
    fi
    # Clear any stale stop flag so a fresh start is not halted immediately.
    rm -f "$STOPFLAG"
    mkdir -p dev
    echo "starting local pilot loop (nohup); log -> $LOG"
    # nohup + background: survives the terminal closing. Output appended to
    # the same log the R script writes (harmless duplication of headers).
    nohup Rscript "$LOOP" >> "$LOG" 2>&1 &
    echo $! > "$PIDFILE"
    echo "launched PID $(cat "$PIDFILE"). Tail with: tail -f $LOG"
    ;;
  stop)
    echo "requesting clean stop via $STOPFLAG (loop exits after the current batch)."
    touch "$STOPFLAG"
    if is_running; then
      echo "stop flag set; PID $(cat "$PIDFILE") will exit shortly. Watch: tail -f $LOG"
    else
      echo "no running loop detected; stop flag set for any external runner."
    fi
    ;;
  status)
    if is_running; then
      echo "RUNNING (PID $(cat "$PIDFILE"))."
    else
      echo "not running."
    fi
    if [ -f "$LOG" ]; then
      echo "--- last 10 log lines ---"
      tail -n 10 "$LOG"
    fi
    ;;
  *)
    echo "usage: bash dev/launch-local-pilot.sh [start|stop|status]" >&2
    exit 2
    ;;
esac
