#!/usr/bin/env bash
set -euo pipefail

# Totoro launcher — S4 GH-hard / hybrid family n-ladders.
# FAMILY=tweedie|student|truncated_poisson|truncated_nbinom2|
#         ordinal_probit|delta_gamma|delta_lognormal
# n ∈ {120,400,1000}; p=8 q=2; gtmb LA+VA ± gllvm as feasible.
# Do NOT kill unrelated Totoro jobs (incl. beta/betabinomial). D-50.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LANE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="${CHECKOUT:-$(cd "$LANE_ROOT/../.." && pwd)}"
PROBE_SCRIPT="$SCRIPT_DIR/probe-s4-family-nladder.R"

FAMILY="${FAMILY:?set FAMILY=tweedie|student|truncated_poisson|truncated_nbinom2|ordinal_probit|delta_gamma|delta_lognormal}"
ACTION="${ACTION:-dry-run}"
HOST="${TOTORO_HOST:-totoro}"
FAM_SLUG="${FAMILY//_/-}"
REMOTE_ROOT="${REMOTE_ROOT:-/home/snakagaw/gllvm_work/va-s4-${FAM_SLUG}-nladder-20260807}"
REMOTE_CHECKOUT="${REMOTE_CHECKOUT:-/home/snakagaw/gllvm_work/va-gh-h7-totoro-confirmation-022b4eab-20260806/checkout}"
LOCAL_PROBE="$PROBE_SCRIPT"

N_SEED="${PROBE_N_SEED:-12}"
SEED0="${PROBE_SEED0:-11401}"
N_GRID="${PROBE_N_GRID:-120,400,1000}"
Q="${PROBE_Q:-2}"
P="${PROBE_P:-8}"
VA_H="${PROBE_VA_H:-7}"
N_STARTS="${PROBE_N_STARTS:-1}"
GLLVM_VA_NS="${PROBE_GLLVM_VA_NS:-120}"
DO_GLLVM_LA="${PROBE_DO_GLLVM_LA:-1}"
DO_GLLVM_VA="${PROBE_DO_GLLVM_VA:-1}"
CORES="${PILOT_CORES:-12}"
CORE_CAP="${PROBE_CORE_CAP:-$CORES}"

usage() {
  cat <<'EOF'
FAMILY=... ACTION=dry-run|sync|smoke|full|status|pull

  dry-run  Print env + remote paths (default)
  sync     mkdir remote + scp probe + write env.sh
  smoke    Remote: 1 seed, n=120 only, 2 cores
  full     Remote: N_SEED × N_GRID, PILOT_CORES
  status   tail remote log + ls results
  pull     scp results to LOCAL_PULL (/private/tmp/...)

Env: FAMILY (required) PROBE_N_SEED PROBE_SEED0 PROBE_N_GRID PROBE_Q PROBE_P
     PROBE_VA_H PROBE_N_STARTS PROBE_GLLVM_VA_NS PROBE_DO_GLLVM_LA
     PROBE_DO_GLLVM_VA PILOT_CORES PROBE_CORE_CAP REMOTE_ROOT REMOTE_CHECKOUT
EOF
}

write_env_sh() {
  cat <<EOF
export PROBE_REPO=$REMOTE_CHECKOUT
export PROBE_OUT=$REMOTE_ROOT/results
export PROBE_FAMILY=$FAMILY
export PROBE_N_SEED=$N_SEED
export PROBE_SEED0=$SEED0
export PROBE_N_GRID=$N_GRID
export PROBE_Q=$Q
export PROBE_P=$P
export PROBE_VA_H=$VA_H
export PROBE_N_STARTS=$N_STARTS
export PROBE_GLLVM_VA_NS=$GLLVM_VA_NS
export PROBE_DO_GLLVM_LA=$DO_GLLVM_LA
export PROBE_DO_GLLVM_VA=$DO_GLLVM_VA
export PILOT_CORES=$CORES
export PROBE_CORE_CAP=$CORE_CAP
export R_LIBS=\${R_LIBS:-/home/snakagaw/R/lib}
export R_LIBS_USER=\${R_LIBS_USER:-/home/snakagaw/R/lib}
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
EOF
}

case "$ACTION" in
  -h|--help) usage; exit 0 ;;
  dry-run)
    echo "S4 $FAMILY n-ladder Totoro dry-run"
    echo "  HOST=$HOST"
    echo "  REMOTE_ROOT=$REMOTE_ROOT"
    echo "  REMOTE_CHECKOUT=$REMOTE_CHECKOUT"
    echo "  LOCAL_PROBE=$LOCAL_PROBE"
    echo "  N_SEED=$N_SEED SEED0=$SEED0 N_GRID=$N_GRID Q=$Q P=$P H=$VA_H"
    echo "  n_starts=$N_STARTS CORES=$CORES"
    echo "Say ACTION=sync then ACTION=smoke|full to launch."
    ;;
  sync)
    ssh "$HOST" "mkdir -p '$REMOTE_ROOT'/{scripts,results,logs}"
    scp "$LOCAL_PROBE" "$HOST:$REMOTE_ROOT/scripts/probe-s4-family-nladder.R"
    write_env_sh | ssh "$HOST" "cat > '$REMOTE_ROOT/env.sh'"
    ssh "$HOST" "test -d '$REMOTE_CHECKOUT' || { echo missing checkout: $REMOTE_CHECKOUT >&2; exit 3; }"
    echo "Synced probe + env.sh under $REMOTE_ROOT"
    ;;
  smoke)
    ssh "$HOST" "test -f '$REMOTE_ROOT/env.sh' || { echo run ACTION=sync first >&2; exit 4; }"
    ssh "$HOST" bash -s <<EOF
set -euo pipefail
source '$REMOTE_ROOT/env.sh'
export PROBE_OUT='$REMOTE_ROOT/results/smoke'
mkdir -p "\$PROBE_OUT"
cd "\$PROBE_REPO"
nohup env PROBE_REPO="\$PROBE_REPO" PROBE_OUT="\$PROBE_OUT" PROBE_FAMILY=$FAMILY \\
  PROBE_N_SEED=1 PROBE_SEED0=$SEED0 PROBE_N_GRID=120 \\
  PROBE_Q=$Q PROBE_P=$P PROBE_VA_H=$VA_H PROBE_N_STARTS=$N_STARTS \\
  PROBE_GLLVM_VA_NS=$GLLVM_VA_NS PROBE_DO_GLLVM_LA=$DO_GLLVM_LA \\
  PROBE_DO_GLLVM_VA=$DO_GLLVM_VA \\
  PILOT_CORES=2 PROBE_CORE_CAP=2 \\
  Rscript --vanilla '$REMOTE_ROOT/scripts/probe-s4-family-nladder.R' \\
  > '$REMOTE_ROOT/logs/smoke.log' 2>&1 &
echo \$! > '$REMOTE_ROOT/logs/smoke.pid'
echo "smoke pid=\$(cat '$REMOTE_ROOT/logs/smoke.pid') log=$REMOTE_ROOT/logs/smoke.log"
EOF
    ;;
  full)
    ssh "$HOST" "test -f '$REMOTE_ROOT/env.sh' || { echo run ACTION=sync first >&2; exit 4; }"
    ssh "$HOST" bash -s <<EOF
set -euo pipefail
source '$REMOTE_ROOT/env.sh'
mkdir -p "\$PROBE_OUT"
cd "\$PROBE_REPO"
if [[ -f '$REMOTE_ROOT/logs/full.pid' ]]; then
  old=\$(cat '$REMOTE_ROOT/logs/full.pid')
  if kill -0 "\$old" 2>/dev/null; then
    echo "full already running pid=\$old — refuse overlap" >&2
    exit 5
  fi
fi
nohup env PROBE_REPO="\$PROBE_REPO" PROBE_OUT="\$PROBE_OUT" PROBE_FAMILY=$FAMILY \\
  PROBE_N_SEED=$N_SEED PROBE_SEED0=$SEED0 PROBE_N_GRID=$N_GRID \\
  PROBE_Q=$Q PROBE_P=$P PROBE_VA_H=$VA_H PROBE_N_STARTS=$N_STARTS \\
  PROBE_GLLVM_VA_NS=$GLLVM_VA_NS PROBE_DO_GLLVM_LA=$DO_GLLVM_LA \\
  PROBE_DO_GLLVM_VA=$DO_GLLVM_VA \\
  PILOT_CORES=$CORES PROBE_CORE_CAP=$CORE_CAP \\
  Rscript --vanilla '$REMOTE_ROOT/scripts/probe-s4-family-nladder.R' \\
  > '$REMOTE_ROOT/logs/full.log' 2>&1 &
echo \$! > '$REMOTE_ROOT/logs/full.pid'
echo "full pid=\$(cat '$REMOTE_ROOT/logs/full.pid') log=$REMOTE_ROOT/logs/full.log out=\$PROBE_OUT"
EOF
    ;;
  status)
    ssh "$HOST" bash -s <<EOF
set -euo pipefail
echo "== load =="
uptime || true
echo "== our pids =="
for f in '$REMOTE_ROOT'/logs/*.pid; do
  [[ -f "\$f" ]] || continue
  pid=\$(cat "\$f")
  if kill -0 "\$pid" 2>/dev/null; then st=RUNNING; else st=done; fi
  echo "\$(basename "\$f") pid=\$pid \$st"
done
echo "== other Rscript (info only; do not kill) =="
pgrep -af 'Rscript|probe-' 2>/dev/null | head -30 || true
echo "== logs (tail) =="
tail -n 40 '$REMOTE_ROOT'/logs/*.log 2>/dev/null || true
echo "== results =="
ls -la '$REMOTE_ROOT'/results 2>/dev/null || true
EOF
    ;;
  pull)
    LOCAL_PULL="${LOCAL_PULL:-/private/tmp/va-s4-${FAM_SLUG}-nladder-20260807}"
    mkdir -p "$LOCAL_PULL"
    scp -r "$HOST:$REMOTE_ROOT/results/." "$LOCAL_PULL/"
    scp "$HOST:$REMOTE_ROOT/logs/full.log" "$LOCAL_PULL/full.log" 2>/dev/null || true
    echo "Pulled to $LOCAL_PULL"
    ls -la "$LOCAL_PULL"
    ;;
  *)
    echo "ACTION must be dry-run|sync|smoke|full|status|pull (got $ACTION)" >&2
    usage >&2
    exit 2
    ;;
esac
