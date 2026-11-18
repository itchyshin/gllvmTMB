#!/usr/bin/env bash
# Design 118 B1 — Totoro launcher. Dry-run by default.
#
# Receipt: docs/dev-log/research/2026-08-15-mspl-b1-totoro-receipt.md
# Harness: inst/sim/b1-calibration/ on PR #981 (claude/mspl-b0-prereqs).
# Not on origin/main as of fe867e40.
#
# This script NEVER starts a campaign unless ALL of these are true:
#   --launch          (local side: scp + ssh)
#   MSPL_B1_CONFIRM=yes
#   --mode=full|canary
#   hostname looks like Totoro when --on-totoro
#   NWORKERS <= 150 (D-143; the cap is the rule, not nproc-4)
#   GITHUB_ACTIONS is unset (D-50)
#
# Default invocation prints the plan and the exact fire command, then
# exits 0. It does not open SSH. It does not occupy Totoro.
#
# Usage:
#   dev/mspl-b1-totoro-launch.sh                  # dry-run, --mode=full plan
#   dev/mspl-b1-totoro-launch.sh --mode=canary    # dry-run, one reduced shard
#   dev/mspl-b1-totoro-launch.sh --self-test      # local guards only
#   MSPL_B1_CONFIRM=yes dev/mspl-b1-totoro-launch.sh --mode=full --launch
#
set -euo pipefail

readonly TOTORO_CORE_CAP=150   # D-143; raise ONLY with an explicit, recorded yes
readonly DEFAULT_WORKERS=140   # B0's measured Totoro parallelism
readonly TASKS_FULL=7920       # 132 cells * ceil(600/10)
readonly CANARY_CELL=B010      # cloglog, pi=0.97, n_site=12 (C-core worst corner)
readonly CANARY_SHARD=1
readonly CANARY_OUTER=1
readonly CANARY_BOOT=5
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

MODE="full"
DO_LAUNCH=0
ON_TOTORO=0
SELF_TEST=0
DRY_RUN=1

usage() {
  sed -n '2,28p' "$SCRIPT_PATH"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:?--mode needs full|canary}"
      shift 2
      ;;
    --mode=*)
      MODE="${1#--mode=}"
      shift
      ;;
    --launch)
      DO_LAUNCH=1
      DRY_RUN=0
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      DO_LAUNCH=0
      shift
      ;;
    --on-totoro)
      ON_TOTORO=1
      DRY_RUN=0
      shift
      ;;
    --self-test)
      SELF_TEST=1
      shift
      ;;
    -h|--help)
      usage 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage 2
      ;;
  esac
done

case "$MODE" in
  full|canary) ;;
  *)
    echo "MODE must be full or canary, got: $MODE" >&2
    exit 2
    ;;
esac

if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  echo "refusing: D-50 forbids campaign launch on GitHub Actions." >&2
  exit 2
fi

NWORKERS="${MSPL_B1_WORKERS:-$DEFAULT_WORKERS}"
if ! [[ "$NWORKERS" =~ ^[0-9]+$ ]]; then
  echo "MSPL_B1_WORKERS must be an integer, got: $NWORKERS" >&2
  exit 2
fi
if (( NWORKERS < 1 || NWORKERS > TOTORO_CORE_CAP )); then
  echo "NWORKERS=$NWORKERS exceeds the ${TOTORO_CORE_CAP}-core cap (D-143). Ask Shinichi first." >&2
  exit 2
fi

PACKAGE_ROOT="${MSPL_B1_PACKAGE_ROOT:-}"
OUT_ROOT="${MSPL_B1_OUT_ROOT:-}"
SSH_HOST="${MSPL_B1_SSH_HOST:-totoro}"
CONFIRM="${MSPL_B1_CONFIRM:-}"

harness_ok() {
  local root="$1"
  [[ -n "$root" && -f "$root/inst/sim/b1-calibration/run-b1-shard.R" && -f "$root/inst/sim/b0-fence-roc/lib-b0-fence-roc.R" ]]
}

print_plan() {
  cat <<EOF
# B1 Totoro launch plan (dry-run — nothing started)
#
# Receipt: docs/dev-log/research/2026-08-15-mspl-b1-totoro-receipt.md
# Host: Totoro    mode: $MODE    workers: $NWORKERS (cap $TOTORO_CORE_CAP)
# Estimate (full grid): ~2,900 core-h / ~19–21 h wall @ 140–150 cores
#   from B0 0.4 s/fit-eq × 26 M (D2). Not a B1-measured shard.
# Canary: $CANARY_CELL shard $CANARY_SHARD, outer=$CANARY_OUTER, boot=$CANARY_BOOT
#   intended ≤30 min; timing probe only — not B1.
# SE covered? no. Public sd_report still withheld.
# D-50: never GitHub Actions. D-142: reap xargs process group after.
#
# Harness is on PR #981 (claude/mspl-b0-prereqs), not origin/main.
# Set MSPL_B1_PACKAGE_ROOT to a checkout that has inst/sim/b1-calibration/.
# Set MSPL_B1_OUT_ROOT to a directory *outside* that checkout.
#
# Exact fire command (human / next agent — not a dry-run sitting):
MSPL_B1_PACKAGE_ROOT=${PACKAGE_ROOT:-~/gllvmtmb-mspl-b1} \\
MSPL_B1_OUT_ROOT=${OUT_ROOT:-~/gllvmtmb-local-artifacts/b1-calibration} \\
MSPL_B1_WORKERS=$NWORKERS \\
MSPL_B1_CONFIRM=yes \\
  $SCRIPT_PATH --mode=$MODE --launch
EOF
}

remote_full_cmd() {
  local root="$1" out="$2" workers="$3"
  cat <<EOF
set -euo pipefail
cd $(printf '%q' "$root")
export GLLVM_TMB_PILOT_SOURCE=true
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
mkdir -p $(printf '%q' "$out")/shards $(printf '%q' "$out")/sidecars $(printf '%q' "$out")/logs
seq 1 $TASKS_FULL | xargs -P$workers -I{} sh -c '
  task="\$1"
  logdir="\$2/logs"
  Rscript --vanilla inst/sim/b1-calibration/run-b1-shard.R \\
    --task-id "\$task" --outer-per-shard 10 --reps 600 --bootstrap-reps 500 \\
    --out "\$2" > "\$logdir/task-\$task.log" 2>&1
' _ {} $(printf '%q' "$out")
EOF
}

remote_canary_cmd() {
  local root="$1" out="$2"
  cat <<EOF
set -euo pipefail
cd $(printf '%q' "$root")
export GLLVM_TMB_PILOT_SOURCE=true
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
mkdir -p $(printf '%q' "$out")/shards $(printf '%q' "$out")/sidecars $(printf '%q' "$out")/logs
Rscript --vanilla inst/sim/b1-calibration/run-b1-shard.R \\
  --cell-id $CANARY_CELL --shard-id $CANARY_SHARD \\
  --outer-per-shard $CANARY_OUTER --reps $CANARY_OUTER --bootstrap-reps $CANARY_BOOT \\
  --out $(printf '%q' "$out")
EOF
}

assert_on_totoro() {
  local host
  host="$(hostname -s 2>/dev/null || hostname)"
  if [[ "$host" != *totoro* ]]; then
    echo "refusing --on-totoro: hostname '$host' is not Totoro." >&2
    exit 2
  fi
}

run_on_totoro() {
  assert_on_totoro
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "refusing --on-totoro without MSPL_B1_CONFIRM=yes." >&2
    exit 2
  fi
  if [[ -z "$PACKAGE_ROOT" || -z "$OUT_ROOT" ]]; then
    echo "MSPL_B1_PACKAGE_ROOT and MSPL_B1_OUT_ROOT are required on Totoro." >&2
    exit 2
  fi
  if ! harness_ok "$PACKAGE_ROOT"; then
    echo "harness missing under $PACKAGE_ROOT (need PR #981 inst/sim/b1-calibration/)." >&2
    exit 2
  fi
  case "$OUT_ROOT" in
    "$PACKAGE_ROOT"|"$PACKAGE_ROOT"/*)
      echo "OUT_ROOT must be outside the package checkout (D-50 keepers stay local, not in-repo)." >&2
      exit 2
      ;;
  esac
  # D-143 second bound: machine size, after the rule's 150.
  local nproc_cap
  nproc_cap=$(( $(nproc) - 4 ))
  if (( NWORKERS > nproc_cap )); then
    echo "NWORKERS=$NWORKERS exceeds nproc-4=$nproc_cap." >&2
    exit 2
  fi
  echo "B1 $MODE starting on $(hostname) workers=$NWORKERS out=$OUT_ROOT"
  # D-142: kill the process GROUP on exit so a stopped xargs cannot linger.
  trap 'pgid=$(ps -o pgid= -p $$ | tr -d " "); kill -KILL -"$pgid" 2>/dev/null || true' EXIT
  if [[ "$MODE" == "canary" ]]; then
    eval "$(remote_canary_cmd "$PACKAGE_ROOT" "$OUT_ROOT")"
  else
    eval "$(remote_full_cmd "$PACKAGE_ROOT" "$OUT_ROOT" "$NWORKERS")"
  fi
  trap - EXIT
  echo "B1 $MODE finished. Reap complete (D-142)."
}

launch_from_laptop() {
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "refusing --launch without MSPL_B1_CONFIRM=yes. Dry-run instead:" >&2
    print_plan
    exit 2
  fi
  if [[ -z "$PACKAGE_ROOT" || -z "$OUT_ROOT" ]]; then
    echo "set MSPL_B1_PACKAGE_ROOT and MSPL_B1_OUT_ROOT before --launch." >&2
    exit 2
  fi
  echo "This path SSHes to $SSH_HOST and occupies Totoro."
  echo "Re-read docs/dev-log/research/2026-08-15-mspl-b1-totoro-receipt.md first."
  ssh -o BatchMode=yes -o ConnectTimeout=20 "$SSH_HOST" \
    "MSPL_B1_PACKAGE_ROOT=$(printf '%q' "$PACKAGE_ROOT") MSPL_B1_OUT_ROOT=$(printf '%q' "$OUT_ROOT") MSPL_B1_WORKERS=$NWORKERS MSPL_B1_CONFIRM=yes bash -s -- --on-totoro --mode=$MODE" \
    < "$SCRIPT_PATH"
}

self_test() {
  local fail=0
  local out
  out="$(MSPL_B1_WORKERS=140 "$SCRIPT_PATH" --mode=full --dry-run)"
  printf '%s\n' "$out" | grep -q 'nothing started' || { echo "self-test: dry-run missing banner"; fail=1; }
  printf '%s\n' "$out" | grep -q 'SE covered? no' || { echo "self-test: missing SE fence"; fail=1; }
  if MSPL_B1_WORKERS=151 "$SCRIPT_PATH" --mode=full --dry-run >/dev/null 2>&1; then
    echo "self-test: 151 workers should have been refused"
    fail=1
  fi
  if GITHUB_ACTIONS=true "$SCRIPT_PATH" --mode=full --dry-run >/dev/null 2>&1; then
    echo "self-test: GITHUB_ACTIONS should have been refused"
    fail=1
  fi
  if MSPL_B1_CONFIRM=no "$SCRIPT_PATH" --mode=full --launch >/dev/null 2>&1; then
    echo "self-test: --launch without CONFIRM=yes should have been refused"
    fail=1
  fi
  if "$SCRIPT_PATH" --on-totoro --mode=canary >/dev/null 2>&1; then
    echo "self-test: --on-totoro off Totoro should have been refused"
    fail=1
  fi
  if [[ $fail -ne 0 ]]; then
    echo "self-test FAIL"
    exit 1
  fi
  echo "self-test PASS (dry-run, cap, Actions, confirm, hostname)"
}

if [[ "$SELF_TEST" == 1 ]]; then
  self_test
  exit 0
fi

if [[ "$ON_TOTORO" == 1 ]]; then
  run_on_totoro
  exit 0
fi

if [[ "$DO_LAUNCH" == 1 ]]; then
  launch_from_laptop
  exit 0
fi

print_plan
if [[ -n "$PACKAGE_ROOT" ]]; then
  if harness_ok "$PACKAGE_ROOT"; then
    echo "# harness: present under $PACKAGE_ROOT"
  else
    echo "# harness: MISSING under $PACKAGE_ROOT (check out #981 before --launch)"
  fi
else
  echo "# harness: MSPL_B1_PACKAGE_ROOT unset; --launch will refuse until it points at #981"
fi
echo
echo "# Remote body that --launch would run on Totoro:"
if [[ "$MODE" == "canary" ]]; then
  remote_canary_cmd "${PACKAGE_ROOT:-~/gllvmtmb-mspl-b1}" "${OUT_ROOT:-~/gllvmtmb-local-artifacts/b1-calibration}"
else
  remote_full_cmd "${PACKAGE_ROOT:-~/gllvmtmb-mspl-b1}" "${OUT_ROOT:-~/gllvmtmb-local-artifacts/b1-calibration}" "$NWORKERS"
fi
