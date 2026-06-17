#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SRC="$ROOT/docs/dev-log/dashboard"
DASH_DIR="${GLLVM_DASHBOARD_DIR:-/tmp/gllvm-dashboard}"
PORT="${GLLVM_DASHBOARD_PORT:-8770}"
HOST="${GLLVM_DASHBOARD_HOST:-127.0.0.1}"
LOG="${GLLVM_DASHBOARD_LOG:-/tmp/gllvm-dashboard.log}"
PIDFILE="${GLLVM_DASHBOARD_PIDFILE:-/tmp/gllvm-dashboard.pid}"
BACKGROUND=0

case "${1:-}" in
  --background)
    BACKGROUND=1
    ;;
  "" )
    ;;
  -h|--help)
    echo "Usage: sh tools/start-mission-control.sh [--background]"
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 2
    ;;
esac

if [ ! -d "$SRC" ]; then
  echo "Dashboard source not found: $SRC" >&2
  exit 1
fi

sync_dashboard_files() {
  dest="$1"
  mkdir -p "$dest"
  cp "$SRC/index.html" "$SRC/status.json" "$SRC/sweep.json" "$SRC/version.txt" "$SRC/README.md" "$dest/"
}

sync_dashboard_files "$DASH_DIR"

port_pid() {
  lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -n 1 || true
}

is_this_dashboard() {
  current_version=$(curl -fsS "http://$HOST:$PORT/version.txt" 2>/dev/null || true)
  expected_version=$(cat "$SRC/version.txt")
  [ "$current_version" = "$expected_version" ]
}

PID=$(port_pid)
if [ -n "$PID" ]; then
  CMD=$(ps -p "$PID" -o command= 2>/dev/null || true)
  SERVE_DIR=$(printf "%s\n" "$CMD" | sed -n 's/.*--directory \([^ ]*\).*/\1/p')
  if [ -n "$SERVE_DIR" ]; then
    case "$SERVE_DIR" in
      /*) LIVE_DIR="$SERVE_DIR" ;;
      *) LIVE_DIR="$ROOT/$SERVE_DIR" ;;
    esac
    if [ -d "$LIVE_DIR" ]; then
      sync_dashboard_files "$LIVE_DIR"
    fi
  fi
  if is_this_dashboard; then
    echo "GLLVM mission-control dashboard already available at http://$HOST:$PORT/"
    echo "Synced dashboard files to $DASH_DIR"
    if [ -n "${LIVE_DIR:-}" ] && [ "$LIVE_DIR" != "$DASH_DIR" ]; then
      echo "Mirrored disposable live output to $LIVE_DIR"
    fi
    exit 0
  fi
  case "$CMD" in
    *http.server*)
      echo "Stopping existing local http.server on port $PORT (pid $PID)."
      kill "$PID" 2>/dev/null || true
      i=0
      while [ "$i" -lt 20 ]; do
        if [ -z "$(port_pid)" ]; then
          break
        fi
        sleep 0.25
        i=$((i + 1))
      done
      ;;
    *)
      echo "Port $PORT is already in use by: $CMD" >&2
      echo "Set GLLVM_DASHBOARD_PORT to another port or stop that process." >&2
      exit 1
      ;;
  esac
fi

if [ "$BACKGROUND" -eq 1 ]; then
  (
    python3 -m http.server "$PORT" --bind "$HOST" --directory "$DASH_DIR" >"$LOG" 2>&1 &
    echo "$!" >"$PIDFILE"
  )
  sleep 1
  echo "GLLVM mission-control dashboard: http://$HOST:$PORT/"
  echo "Source: $SRC"
  echo "Live copy: $DASH_DIR"
  echo "Log: $LOG"
  exit 0
fi

echo "GLLVM mission-control dashboard: http://$HOST:$PORT/"
exec python3 -m http.server "$PORT" --bind "$HOST" --directory "$DASH_DIR"
