#!/usr/bin/env bash
# Design 121 A+B campaign — Totoro launcher. Dry-run by default.
#
# Companion: dev/coxreid-ab/run-ab.R (arms A/B only; run that file's header
# comment for the two prerun corrections and the seed scheme).
#
# This script NEVER starts a campaign unless ALL of these are true:
#   --launch                    (runs the Rscript directly -- run this ON Totoro)
#   COXREID_AB_CONFIRM=yes
#   --mode=canary|full
#   hostname looks like Totoro
#   NWORKERS <= 150 (D-143; the cap is the rule, not nproc-4)
#   GITHUB_ACTIONS is unset (D-50)
#
# Default invocation prints the plan and the exact Rscript command, then
# exits 0. It never runs R. It never occupies Totoro.
#
# Usage:
#   dev/coxreid-ab/launch-ab.sh                          # dry-run, --mode=canary plan
#   dev/coxreid-ab/launch-ab.sh --mode=full               # dry-run, full-grid plan
#   dev/coxreid-ab/launch-ab.sh --self-test               # local guards only
#   COXREID_AB_CONFIRM=yes dev/coxreid-ab/launch-ab.sh --mode=canary --launch
#
set -euo pipefail

readonly TOTORO_CORE_CAP=150     # D-143; raise ONLY with an explicit, recorded yes
readonly DEFAULT_WORKERS=96
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
readonly R_SCRIPT="$SCRIPT_DIR/run-ab.R"

MODE="canary"
DO_LAUNCH=0
SELF_TEST=0

usage() {
  sed -n '2,22p' "$SCRIPT_PATH"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:?--mode needs canary|full}"
      shift 2
      ;;
    --mode=*)
      MODE="${1#--mode=}"
      shift
      ;;
    --launch)
      DO_LAUNCH=1
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
  canary|full) ;;
  *)
    echo "MODE must be canary or full, got: $MODE" >&2
    exit 2
    ;;
esac

if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  echo "refusing: D-50 forbids campaign launch on GitHub Actions." >&2
  exit 2
fi

NWORKERS="${COXREID_AB_WORKERS:-$DEFAULT_WORKERS}"
if ! [[ "$NWORKERS" =~ ^[0-9]+$ ]]; then
  echo "COXREID_AB_WORKERS must be an integer, got: $NWORKERS" >&2
  exit 2
fi
if (( NWORKERS < 1 || NWORKERS > TOTORO_CORE_CAP )); then
  echo "NWORKERS=$NWORKERS exceeds the ${TOTORO_CORE_CAP}-core cap (D-143). Ask Shinichi first." >&2
  exit 2
fi

CONFIRM="${COXREID_AB_CONFIRM:-}"
COMMIT="${COXREID_AB_COMMIT:-<unset -- fill in with the deployed R CMD INSTALL revision>}"

print_plan() {
  local tasks
  if [[ "$MODE" == "canary" ]]; then
    tasks=16    # 8 cells x 2 arms x 1 seed
  else
    tasks=1600  # 8 cells x 2 arms x 100 seeds
  fi
  cat <<EOF
# Cox-Reid A+B launch plan (dry-run — nothing started)
#
# Mode: $MODE    tasks: $tasks    workers: $NWORKERS (cap $TOTORO_CORE_CAP)
# Deployed commit: $COMMIT
# D-50: never GitHub Actions. Results stay local under \$HOME/gllvm_work/results.
#
# This script runs directly ON Totoro (no ssh hop). --launch requires:
#   COXREID_AB_CONFIRM=yes AND hostname matching totoro AND NWORKERS <= $TOTORO_CORE_CAP.
#
# Exact command --launch would run (human / next agent — not a dry-run sitting):
COXREID_AB_CONFIRM=yes AB_MODE=$MODE GRID_WORKERS=$NWORKERS \\
  $SCRIPT_PATH --mode=$MODE --launch
#
# which resolves to:
AB_MODE=$MODE GRID_WORKERS=$NWORKERS Rscript --vanilla $R_SCRIPT
EOF
}

assert_on_totoro() {
  local host
  host="$(hostname -s 2>/dev/null || hostname)"
  if [[ "$host" != *totoro* ]]; then
    echo "refusing --launch: hostname '$host' is not Totoro." >&2
    exit 2
  fi
}

run_launch() {
  assert_on_totoro
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "refusing --launch without COXREID_AB_CONFIRM=yes. Dry-run instead:" >&2
    print_plan
    exit 2
  fi
  if [[ ! -f "$R_SCRIPT" ]]; then
    echo "missing $R_SCRIPT" >&2
    exit 2
  fi
  echo "Cox-Reid A+B $MODE starting on $(hostname) workers=$NWORKERS commit=$COMMIT"
  AB_MODE="$MODE" GRID_WORKERS="$NWORKERS" Rscript --vanilla "$R_SCRIPT"
  echo "Cox-Reid A+B $MODE finished."
}

self_test() {
  local fail=0
  local out

  out="$(COXREID_AB_WORKERS=96 "$SCRIPT_PATH" --mode=canary)"
  printf '%s\n' "$out" | grep -q 'nothing started' || { echo "self-test: dry-run missing banner"; fail=1; }

  if COXREID_AB_WORKERS=151 "$SCRIPT_PATH" --mode=canary >/dev/null 2>&1; then
    echo "self-test: 151 workers should have been refused"
    fail=1
  fi

  if GITHUB_ACTIONS=true "$SCRIPT_PATH" --mode=canary >/dev/null 2>&1; then
    echo "self-test: GITHUB_ACTIONS should have been refused"
    fail=1
  fi

  if COXREID_AB_CONFIRM=no "$SCRIPT_PATH" --mode=canary --launch >/dev/null 2>&1; then
    echo "self-test: --launch without CONFIRM=yes should have been refused"
    fail=1
  fi

  # off-Totoro: even WITH confirm=yes, hostname gate must refuse.
  if COXREID_AB_CONFIRM=yes "$SCRIPT_PATH" --mode=canary --launch >/dev/null 2>&1; then
    echo "self-test: --launch off Totoro should have been refused"
    fail=1
  fi

  if [[ $fail -ne 0 ]]; then
    echo "self-test FAIL"
    exit 1
  fi
  echo "self-test PASS (dry-run banner, cap, Actions, confirm, hostname)"
}

if [[ "$SELF_TEST" == 1 ]]; then
  self_test
  exit 0
fi

if [[ "$DO_LAUNCH" == 1 ]]; then
  run_launch
  exit 0
fi

print_plan
