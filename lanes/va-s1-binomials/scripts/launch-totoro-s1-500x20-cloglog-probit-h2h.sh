#!/usr/bin/env bash
set -euo pipefail

# Totoro launcher — 500×20 cloglog vs probit GH H2H (Design-110).
# Does NOT kill other Totoro jobs. No fence change. D-50: raw under REMOTE_ROOT/results.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE_SCRIPT="$SCRIPT_DIR/probe-binomial-500x20-cloglog-probit-h2h.R"

ACTION="${ACTION:-dry-run}"
HOST="${TOTORO_HOST:-totoro}"
REMOTE_ROOT="${REMOTE_ROOT:-/home/snakagaw/gllvm_work/va-s1-binomial-500x20-cloglog-probit-h2h-20260807}"
REMOTE_CHECKOUT="${REMOTE_CHECKOUT:-/home/snakagaw/gllvm_work/va-gh-h7-totoro-confirmation-022b4eab-20260806/checkout}"
LOCAL_PROBE="$PROBE_SCRIPT"

N_SEED="${PROBE_N_SEED:-12}"
SEED0="${PROBE_SEED0:-11001}"
LINKS="${PROBE_LINKS:-probit,cloglog}"
VA_H="${PROBE_VA_H:-7}"
N="${PROBE_N:-500}"
P="${PROBE_P:-20}"
Q="${PROBE_Q:-2}"
CORES="${PILOT_CORES:-12}"
CORE_CAP="${PROBE_CORE_CAP:-$CORES}"
DO_LA="${PROBE_DO_LA:-1}"
DO_GLLVM="${PROBE_DO_GLLVM:-0}"
DO_POISG="${PROBE_DO_POISG:-0}"

usage() {
  cat <<'U'
ACTION=dry-run|sync|full|status

  dry-run  Print env + remote paths
  sync     mkdir remote + scp probe + write env.sh
  full     nohup N_SEED grid (default 12), PILOT_CORES
  status   tail remote log + ls results

Env: PROBE_N_SEED PROBE_SEED0 PROBE_LINKS PROBE_VA_H PROBE_N/P/Q
     PILOT_CORES PROBE_DO_LA PROBE_DO_GLLVM PROBE_DO_POISG
U
}

write_env_sh() {
  cat <<E
export PROBE_REPO=$REMOTE_CHECKOUT
export PROBE_OUT=$REMOTE_ROOT/results
export PROBE_N_SEED=$N_SEED
export PROBE_SEED0=$SEED0
export PROBE_LINKS=$LINKS
export PROBE_VA_H=$VA_H
export PROBE_N=$N
export PROBE_P=$P
export PROBE_Q=$Q
export PILOT_CORES=$CORES
export PROBE_CORE_CAP=$CORE_CAP
export PROBE_DO_LA=$DO_LA
export PROBE_DO_GLLVM=$DO_GLLVM
export PROBE_DO_POISG=$DO_POISG
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
    echo "S1 500x20 cloglog-probit H2H Totoro dry-run"
    echo "  HOST=$HOST"
    echo "  REMOTE_ROOT=$REMOTE_ROOT"
    echo "  REMOTE_CHECKOUT=$REMOTE_CHECKOUT"
    echo "  N_SEED=$N_SEED SEED0=$SEED0 LINKS=$LINKS H=$VA_H n/p/q=$N/$P/$Q"
    echo "  CORES=$CORES DO_LA=$DO_LA DO_GLLVM=$DO_GLLVM DO_POISG=$DO_POISG"
    ;;
  sync)
    ssh "$HOST" "mkdir -p '$REMOTE_ROOT'/{scripts,results,logs}"
    scp "$LOCAL_PROBE" "$HOST:$REMOTE_ROOT/scripts/probe-binomial-500x20-cloglog-probit-h2h.R"
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
Rscript --vanilla -e 'suppressPackageStartupMessages(pkgload::load_all(".", quiet=TRUE)); invisible(gllvmTMB:::.va_r3_load_dll()); cat("pre-warm ok\\n")' \
  > '$REMOTE_ROOT/logs/warm.log' 2>&1
nohup env PROBE_REPO="\$PROBE_REPO" PROBE_OUT="\$PROBE_OUT" \\
  PROBE_N_SEED=$N_SEED PROBE_SEED0=$SEED0 PROBE_LINKS='$LINKS' PROBE_VA_H=$VA_H \\
  PROBE_N=$N PROBE_P=$P PROBE_Q=$Q \\
  PILOT_CORES=$CORES PROBE_CORE_CAP=$CORE_CAP \\
  PROBE_DO_LA=$DO_LA PROBE_DO_GLLVM=$DO_GLLVM PROBE_DO_POISG=$DO_POISG \\
  Rscript --vanilla '$REMOTE_ROOT/scripts/probe-binomial-500x20-cloglog-probit-h2h.R' \\
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
S
    ;;
  *)
    echo "ACTION must be dry-run|sync|full|status (got $ACTION)" >&2
    usage >&2
    exit 2
    ;;
esac
