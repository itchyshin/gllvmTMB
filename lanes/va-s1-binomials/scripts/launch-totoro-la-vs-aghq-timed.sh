#!/usr/bin/env bash
set -euo pipefail

# Totoro launcher — Laplace vs AGHQ(+ridge) timed smoke.
# Default: n=1000 p=8 q=2 probit (500×20 AGHQ too slow for this sitting).
# Does NOT flip fence / auto. D-50: raw under REMOTE_ROOT/results.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE_SCRIPT="$SCRIPT_DIR/probe-la-vs-aghq-timed.R"

ACTION="${ACTION:-dry-run}"
HOST="${TOTORO_HOST:-totoro}"
REMOTE_ROOT="${REMOTE_ROOT:-/home/snakagaw/gllvm_work/va-s1-la-vs-aghq-timed-20260807}"
REMOTE_CHECKOUT="${REMOTE_CHECKOUT:-/home/snakagaw/gllvm_work/va-gh-h7-totoro-confirmation-022b4eab-20260806/checkout}"
LOCAL_PROBE="$PROBE_SCRIPT"

N_SEED="${PROBE_N_SEED:-8}"
SEED0="${PROBE_SEED0:-11101}"
LINK="${PROBE_LINK:-probit}"
N="${PROBE_N:-1000}"
P="${PROBE_P:-8}"
Q="${PROBE_Q:-2}"
AGHQ_K="${PROBE_AGHQ_K:-9}"
CORES="${PILOT_CORES:-4}"
DO_NORIDGE="${PROBE_DO_NORIDGE:-0}"

usage() {
  cat <<'U'
ACTION=dry-run|sync|full|status

  dry-run  Print env + remote paths (default)
  sync     mkdir remote + scp probe + write env.sh
  full     nohup timed grid (warm inside probe, excluded from secs)
  status   tail remote log + summary

Env: PROBE_N_SEED PROBE_SEED0 PROBE_LINK PROBE_N/P/Q PROBE_AGHQ_K
     PILOT_CORES PROBE_DO_NORIDGE REMOTE_ROOT REMOTE_CHECKOUT
U
}

write_env_sh() {
  cat <<E
export PROBE_REPO=$REMOTE_CHECKOUT
export PROBE_OUT=$REMOTE_ROOT/results
export PROBE_N_SEED=$N_SEED
export PROBE_SEED0=$SEED0
export PROBE_LINK=$LINK
export PROBE_N=$N
export PROBE_P=$P
export PROBE_Q=$Q
export PROBE_AGHQ_K=$AGHQ_K
export PILOT_CORES=$CORES
export PROBE_DO_NORIDGE=$DO_NORIDGE
export R_LIBS=\${R_LIBS:-/home/snakagaw/R/lib}
export R_LIBS_USER=\${R_LIBS_USER:-/home/snakagaw/R/lib}
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
E
}

case "$ACTION" in
  -h|--help) usage; exit 0 ;;
  dry-run)
    echo "LA vs AGHQ timed Totoro dry-run"
    echo "  HOST=$HOST"
    echo "  REMOTE_ROOT=$REMOTE_ROOT"
    echo "  REMOTE_CHECKOUT=$REMOTE_CHECKOUT"
    echo "  N_SEED=$N_SEED SEED0=$SEED0 LINK=$LINK n/p/q=$N/$P/$Q k=$AGHQ_K"
    echo "  CORES=$CORES DO_NORIDGE=$DO_NORIDGE"
    ;;
  sync)
    ssh "$HOST" "mkdir -p '$REMOTE_ROOT'/{scripts,results,logs}"
    scp "$LOCAL_PROBE" "$HOST:$REMOTE_ROOT/scripts/probe-la-vs-aghq-timed.R"
    write_env_sh | ssh "$HOST" "cat > '$REMOTE_ROOT/env.sh'"
    ssh "$HOST" "test -d '$REMOTE_CHECKOUT' || { echo missing checkout: $REMOTE_CHECKOUT >&2; exit 3; }"
    echo "Synced probe + env.sh under $REMOTE_ROOT"
    ;;
  full)
    ssh "$HOST" "test -f '$REMOTE_ROOT/env.sh' || { echo run ACTION=sync first >&2; exit 4; }"
    ssh "$HOST" bash -s <<F
set -euo pipefail
source '$REMOTE_ROOT/env.sh'
mkdir -p "\$PROBE_OUT" '$REMOTE_ROOT/logs'
cd "\$PROBE_REPO"
# Pre-warm package load once (DLL compile) before timed probe's own tiny warm.
Rscript --vanilla -e 'suppressPackageStartupMessages(pkgload::load_all(".", quiet=TRUE)); cat("pre-warm ok\\n")' \
  > '$REMOTE_ROOT/logs/warm.log' 2>&1
nohup env PROBE_REPO="\$PROBE_REPO" PROBE_OUT="\$PROBE_OUT" \\
  PROBE_N_SEED=$N_SEED PROBE_SEED0=$SEED0 PROBE_LINK=$LINK \\
  PROBE_N=$N PROBE_P=$P PROBE_Q=$Q PROBE_AGHQ_K=$AGHQ_K \\
  PILOT_CORES=$CORES PROBE_DO_NORIDGE=$DO_NORIDGE \\
  Rscript --vanilla '$REMOTE_ROOT/scripts/probe-la-vs-aghq-timed.R' \\
  > '$REMOTE_ROOT/logs/full.log' 2>&1 &
echo \$! > '$REMOTE_ROOT/logs/full.pid'
echo "full pid=\$(cat '$REMOTE_ROOT/logs/full.pid') log=$REMOTE_ROOT/logs/full.log out=\$PROBE_OUT"
F
    ;;
  status)
    ssh "$HOST" bash -s <<S
set -euo pipefail
echo "== pids =="
for f in '$REMOTE_ROOT'/logs/*.pid; do
  [[ -f "\$f" ]] || continue
  pid=\$(cat "\$f")
  if kill -0 "\$pid" 2>/dev/null; then st=RUNNING; else st=done; fi
  echo "\$(basename "\$f") pid=\$pid \$st"
done
echo "== logs (tail) =="
tail -n 50 '$REMOTE_ROOT'/logs/full.log 2>/dev/null || true
echo "== results =="
ls -la '$REMOTE_ROOT'/results 2>/dev/null || true
echo "== summary =="
cat '$REMOTE_ROOT'/results/summary.csv 2>/dev/null || true
S
    ;;
  *)
    echo "ACTION must be dry-run|sync|full|status (got $ACTION)" >&2
    usage >&2
    exit 2
    ;;
esac
