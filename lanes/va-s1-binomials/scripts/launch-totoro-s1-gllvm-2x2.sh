#!/usr/bin/env bash
set -euo pipefail

# Totoro launcher — binomial gllvm 2×2 (private R3 VA + LA × gllvm VA/LA).
# q∈{2,5}; H=7; Design-110 DGP. Does NOT change the public VA fence.
# Prefer this over launch-totoro-s1.sh when the ask is the matched gllvm panel.
# Full Arc-2-style 3600-row S1 campaign stays on launch-totoro-s1.sh (needs go).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LANE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="${CHECKOUT:-$(cd "$LANE_ROOT/../.." && pwd)}"
PROBE_SCRIPT="$SCRIPT_DIR/probe-binomial-gllvm-2x2.R"

ACTION="${ACTION:-dry-run}"
HOST="${TOTORO_HOST:-totoro}"
REMOTE_ROOT="${REMOTE_ROOT:-/home/snakagaw/gllvm_work/va-s1-binomial-gllvm-2x2-20260807}"
REMOTE_CHECKOUT="${REMOTE_CHECKOUT:-/home/snakagaw/gllvm_work/va-gh-h7-totoro-confirmation-022b4eab-20260806/checkout}"
# Sync current worktree probe into Totoro campaign dir (script may be newer than confirmation SHA).
LOCAL_PROBE="$PROBE_SCRIPT"

N_SEED="${PROBE_N_SEED:-24}"
SEED0="${PROBE_SEED0:-10801}"
QS="${PROBE_QS:-2,5}"
LINK="${PROBE_LINK:-logit}"
VA_H="${PROBE_VA_H:-7}"
CORES="${PILOT_CORES:-24}"
CORE_CAP="${PROBE_CORE_CAP:-$CORES}"

usage() {
  cat <<'EOF'
ACTION=dry-run|sync|smoke|full|status

  dry-run  Print env + remote paths (default)
  sync     mkdir remote + scp probe script + write env.sh
  smoke    Remote: 1 seed, q=2, 1 core
  full     Remote: N_SEED × QS (default 24 × 2,5), PILOT_CORES
  status   tail remote log + ls results

Env overrides: PROBE_N_SEED PROBE_SEED0 PROBE_QS PROBE_LINK PROBE_VA_H
               PILOT_CORES PROBE_CORE_CAP REMOTE_ROOT REMOTE_CHECKOUT CHECKOUT
EOF
}

write_env_sh() {
  cat <<EOF
export PROBE_REPO=$REMOTE_CHECKOUT
export PROBE_OUT=$REMOTE_ROOT/results
export PROBE_N_SEED=$N_SEED
export PROBE_SEED0=$SEED0
export PROBE_QS=$QS
export PROBE_LINK=$LINK
export PROBE_VA_H=$VA_H
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
    echo "S1 binomial gllvm 2×2 Totoro dry-run"
    echo "  HOST=$HOST"
    echo "  REMOTE_ROOT=$REMOTE_ROOT"
    echo "  REMOTE_CHECKOUT=$REMOTE_CHECKOUT"
    echo "  LOCAL_PROBE=$LOCAL_PROBE"
    echo "  N_SEED=$N_SEED SEED0=$SEED0 QS=$QS LINK=$LINK H=$VA_H CORES=$CORES"
    echo "Say ACTION=sync then ACTION=smoke|full to launch."
    ;;
  sync)
    ssh "$HOST" "mkdir -p '$REMOTE_ROOT'/{scripts,results,logs}"
    scp "$LOCAL_PROBE" "$HOST:$REMOTE_ROOT/scripts/probe-binomial-gllvm-2x2.R"
    write_env_sh | ssh "$HOST" "cat > '$REMOTE_ROOT/env.sh'"
    # Also drop a copy of the probe into the checkout lane if present (optional).
    ssh "$HOST" "test -d '$REMOTE_CHECKOUT' || { echo missing checkout: $REMOTE_CHECKOUT >&2; exit 3; }"
    echo "Synced probe + env.sh under $REMOTE_ROOT"
    ;;
  smoke)
    ssh "$HOST" "test -f '$REMOTE_ROOT/env.sh' || { echo run ACTION=sync first >&2; exit 4; }"
    ssh "$HOST" bash -s <<EOF
set -euo pipefail
source '$REMOTE_ROOT/env.sh'
export PROBE_N_SEED=1
export PROBE_QS=2
export PILOT_CORES=1
export PROBE_CORE_CAP=1
export PROBE_OUT='$REMOTE_ROOT/results/smoke'
mkdir -p "\$PROBE_OUT"
cd "\$PROBE_REPO"
nohup env PROBE_REPO="\$PROBE_REPO" PROBE_OUT="\$PROBE_OUT" \\
  PROBE_N_SEED=1 PROBE_SEED0=$SEED0 PROBE_QS=2 PROBE_LINK=$LINK PROBE_VA_H=$VA_H \\
  PILOT_CORES=1 PROBE_CORE_CAP=1 \\
  Rscript --vanilla '$REMOTE_ROOT/scripts/probe-binomial-gllvm-2x2.R' \\
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
nohup env PROBE_REPO="\$PROBE_REPO" PROBE_OUT="\$PROBE_OUT" \\
  PROBE_N_SEED=$N_SEED PROBE_SEED0=$SEED0 PROBE_QS='$QS' PROBE_LINK=$LINK PROBE_VA_H=$VA_H \\
  PILOT_CORES=$CORES PROBE_CORE_CAP=$CORE_CAP \\
  Rscript --vanilla '$REMOTE_ROOT/scripts/probe-binomial-gllvm-2x2.R' \\
  > '$REMOTE_ROOT/logs/full.log' 2>&1 &
echo \$! > '$REMOTE_ROOT/logs/full.pid'
echo "full pid=\$(cat '$REMOTE_ROOT/logs/full.pid') log=$REMOTE_ROOT/logs/full.log out=\$PROBE_OUT"
EOF
    ;;
  status)
    ssh "$HOST" bash -s <<EOF
set -euo pipefail
echo "== pids =="
for f in '$REMOTE_ROOT'/logs/*.pid; do
  [[ -f "\$f" ]] || continue
  pid=\$(cat "\$f")
  if kill -0 "\$pid" 2>/dev/null; then st=RUNNING; else st=done; fi
  echo "\$(basename "\$f") pid=\$pid \$st"
done
echo "== logs (tail) =="
tail -n 30 '$REMOTE_ROOT'/logs/*.log 2>/dev/null || true
echo "== results =="
ls -la '$REMOTE_ROOT'/results 2>/dev/null || true
ls -la '$REMOTE_ROOT'/results/smoke 2>/dev/null || true
EOF
    ;;
  *)
    echo "ACTION must be dry-run|sync|smoke|full|status (got $ACTION)" >&2
    usage >&2
    exit 2
    ;;
esac
