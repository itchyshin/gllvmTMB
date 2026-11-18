#!/usr/bin/env bash
set -euo pipefail

REPO="${GLLVMTMB_ROOT:-/Users/z3437171/local-scratch/lanes/gllvmTMB-gllvm-twin-20260904}"
REMOTE="snakagaw@totoro.biology.ualberta.ca"
CM="${HOME}/.ssh/cm-snakagaw@totoro.biology.ualberta.ca:22"
SSH=(ssh -o ControlPath="$CM" "$REMOTE")
RSYNC=(rsync -az -e "ssh -o ControlPath=$CM")
MAX_CORES=150
RDIR='gllvmtmb-arcG-coverage'
HEAD=$(git -C "$REPO" rev-parse --short HEAD)

OUT_LOCAL="${REPO}/dev/gapclose/arcG/results"
mkdir -p "$OUT_LOCAL/raw" "$OUT_LOCAL/summary"
LOG="$OUT_LOCAL/totoro-run.log"

if ! ssh -O check -o ControlPath="$CM" "$REMOTE" >/dev/null 2>&1; then
  echo "ERROR: ControlMaster dead (D-64)." >&2
  exit 1
fi

{
  echo "# arcG grid SUBMIT $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# HEAD: $HEAD"
  echo "# jobs: 4500; mc.cores=$MAX_CORES"
} > "$LOG"

"${SSH[@]}" bash -s "$RDIR" <<'REMOTE_SETUP'
set -euo pipefail
RDIR="$1"
BASE="$HOME/$RDIR"
mkdir -p "$BASE/src" "$BASE/out" "$BASE/summary" "$BASE/logs" "$BASE/priv-lib"
if [[ -d "$HOME/~${RDIR}" && ! -d "$BASE/src/DESCRIPTION" ]]; then
  echo "Migrating legacy ~${RDIR} path..."
  rsync -a "$HOME/~${RDIR}/" "$BASE/"
fi
REMOTE_SETUP

echo "Syncing source..." | tee -a "$LOG"
"${RSYNC[@]}" --delete \
  --exclude '.git' --exclude 'revdep' --exclude 'doc' --exclude 'Meta' \
  "$REPO/" "$REMOTE:~/gllvmtmb-arcG-coverage/src/"

echo "Installing gllvmTMB on Totoro..." | tee -a "$LOG"
"${SSH[@]}" bash -s "$RDIR" <<'REMOTE_INSTALL' >> "$LOG" 2>&1
set -euo pipefail
BASE="$HOME/$1"
cd "$BASE/src"
OPENBLAS_NUM_THREADS=1 Rscript dev/gapclose/arcG/install-remote.R "$BASE/priv-lib"
REMOTE_INSTALL

echo "Launching run_grid.R..." | tee -a "$LOG"
PID=$("${SSH[@]}" bash -s "$RDIR" "$MAX_CORES" <<'REMOTE_RUN'
set -euo pipefail
BASE="$HOME/$1"
MC="$2"
cd "$BASE/src"
nohup env OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 NOT_CRAN=true \
  Rscript dev/gapclose/arcG/run_grid.R "$BASE/out" "$BASE/src" "$BASE/priv-lib" "$MC" \
  > "$BASE/logs/run_grid.log" 2>&1 &
echo $! > "$BASE/logs/run_grid.pid"
cat "$BASE/logs/run_grid.pid"
REMOTE_RUN
)
echo "# remote pid: $PID" >> "$LOG"
echo "Submitted PID $PID" | tee -a "$LOG"
