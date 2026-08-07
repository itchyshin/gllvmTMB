#!/usr/bin/env bash
set -euo pipefail

# Totoro launcher — binomial probit n=500 p=20 q=2 smoke (GH+AC+LA + opt gllvm VA).
# Does NOT change the public VA fence. D-50: raw stays under REMOTE_ROOT/results.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE_SCRIPT="$SCRIPT_DIR/probe-binomial-500x20-probit-smoke.R"

ACTION="${ACTION:-dry-run}"
HOST="${TOTORO_HOST:-totoro}"
REMOTE_ROOT="${REMOTE_ROOT:-/home/snakagaw/gllvm_work/va-s1-binomial-500x20-probit-smoke-20260807}"
REMOTE_CHECKOUT="${REMOTE_CHECKOUT:-/home/snakagaw/gllvm_work/va-gh-h7-totoro-confirmation-022b4eab-20260806/checkout}"
LOCAL_PROBE="$PROBE_SCRIPT"

N_SEED="${PROBE_N_SEED:-12}"
SEED0="${PROBE_SEED0:-11001}"
LINK="${PROBE_LINK:-probit}"
VA_H="${PROBE_VA_H:-7}"
N="${PROBE_N:-500}"
P="${PROBE_P:-20}"
Q="${PROBE_Q:-2}"
CORES="${PILOT_CORES:-12}"
CORE_CAP="${PROBE_CORE_CAP:-$CORES}"
DO_LA="${PROBE_DO_LA:-1}"
DO_GLLVM="${PROBE_DO_GLLVM:-1}"

usage() {
  cat <<'U'
ACTION=dry-run|sync|full|status|warm

  dry-run  Print env + remote paths (default)
  sync     mkdir remote + scp probe + write env.sh
  warm     One-shot .va_r3_load_dll on Totoro checkout
  full     nohup N_SEED grid (default 12), PILOT_CORES
  status   tail remote log + ls results

Env: PROBE_N_SEED PROBE_SEED0 PROBE_LINK PROBE_VA_H PROBE_N/P/Q
     PILOT_CORES PROBE_DO_LA PROBE_DO_GLLVM REMOTE_ROOT REMOTE_CHECKOUT
U
}

write_env_sh() {
  cat <<E
export PROBE_REPO=$REMOTE_CHECKOUT
export PROBE_OUT=$REMOTE_ROOT/results
export PROBE_N_SEED=$N_SEED
export PROBE_SEED0=$SEED0
export PROBE_LINK=$LINK
export PROBE_VA_H=$VA_H
export PROBE_N=$N
export PROBE_P=$P
export PROBE_Q=$Q
export PILOT_CORES=$CORES
export PROBE_CORE_CAP=$CORE_CAP
export PROBE_DO_LA=$DO_LA
export PROBE_DO_GLLVM=$DO_GLLVM
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
    echo "S1 500x20 probit Totoro dry-run"
    echo "  HOST=$HOST"
    echo "  REMOTE_ROOT=$REMOTE_ROOT"
    echo "  REMOTE_CHECKOUT=$REMOTE_CHECKOUT"
    echo "  N_SEED=$N_SEED SEED0=$SEED0 LINK=$LINK H=$VA_H n/p/q=$N/$P/$Q"
    echo "  CORES=$CORES DO_LA=$DO_LA DO_GLLVM=$DO_GLLVM"
    ;;
  sync)
    ssh "$HOST" "mkdir -p '$REMOTE_ROOT'/{scripts,results,logs}"
    scp "$LOCAL_PROBE" "$HOST:$REMOTE_ROOT/scripts/probe-binomial-500x20-probit-smoke.R"
    write_env_sh | ssh "$HOST" "cat > '$REMOTE_ROOT/env.sh'"
    ssh "$HOST" "test -d '$REMOTE_CHECKOUT' || { echo missing checkout: $REMOTE_CHECKOUT >&2; exit 3; }"
    echo "Synced probe + env.sh under $REMOTE_ROOT"
    ;;
  warm)
    ssh "$HOST" bash -s <<W
set -euo pipefail
source '$REMOTE_ROOT/env.sh'
cd "\$PROBE_REPO"
Rscript --vanilla -e 'suppressPackageStartupMessages(pkgload::load_all(".", quiet=TRUE)); invisible(gllvmTMB:::.va_r3_load_dll()); cat("dll ready\\n")'
W
    ;;
  full)
    ssh "$HOST" "test -f '$REMOTE_ROOT/env.sh' || { echo run ACTION=sync first >&2; exit 4; }"
    ssh "$HOST" bash -s <<F
set -euo pipefail
source '$REMOTE_ROOT/env.sh'
mkdir -p "\$PROBE_OUT" '$REMOTE_ROOT/logs'
cd "\$PROBE_REPO"
# Warm DLL once on master before nohup grid (also re-warmed inside probe).
Rscript --vanilla -e 'suppressPackageStartupMessages(pkgload::load_all(".", quiet=TRUE)); invisible(gllvmTMB:::.va_r3_load_dll()); cat("pre-warm ok\\n")' \
  > '$REMOTE_ROOT/logs/warm.log' 2>&1
nohup env PROBE_REPO="\$PROBE_REPO" PROBE_OUT="\$PROBE_OUT" \\
  PROBE_N_SEED=$N_SEED PROBE_SEED0=$SEED0 PROBE_LINK=$LINK PROBE_VA_H=$VA_H \\
  PROBE_N=$N PROBE_P=$P PROBE_Q=$Q \\
  PILOT_CORES=$CORES PROBE_CORE_CAP=$CORE_CAP \\
  PROBE_DO_LA=$DO_LA PROBE_DO_GLLVM=$DO_GLLVM \\
  Rscript --vanilla '$REMOTE_ROOT/scripts/probe-binomial-500x20-probit-smoke.R' \\
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
tail -n 40 '$REMOTE_ROOT'/logs/*.log 2>/dev/null || true
echo "== results =="
ls -la '$REMOTE_ROOT'/results 2>/dev/null || true
S
    ;;
  *)
    echo "ACTION must be dry-run|sync|warm|full|status (got $ACTION)" >&2
    usage >&2
    exit 2
    ;;
esac
