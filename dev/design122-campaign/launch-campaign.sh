#!/usr/bin/env bash
# Design 122 CONFIRMATORY campaign — Totoro launcher. Dry-run by default.
#
# Companion: dev/design122-campaign/run-campaign.R (read that file's header
# for the grid, the pre-registered deferrals, and the mirai self-contained
# run_row() pattern). Copies dev/coxreid-ab/launch-ab.sh's guard style.
#
# This script NEVER starts a campaign unless ALL of these are true:
#   --launch                    (runs the Rscript directly -- run this ON Totoro)
#   DESIGN122_CONFIRM=yes
#   --mode=smoke|canary|full    (full may add --chunk=<cell_id>)
#   hostname looks like Totoro
#   NWORKERS <= 150 (D-143; the cap is the rule, not nproc-4)
#   GITHUB_ACTIONS is unset (D-50)
#
# Default invocation prints the plan and the exact Rscript command, then
# exits 0. It never runs R. It never occupies Totoro.
#
# Usage:
#   dev/design122-campaign/launch-campaign.sh                              # dry-run, canary plan
#   dev/design122-campaign/launch-campaign.sh --mode=full --chunk=1        # dry-run, one-chunk plan
#   dev/design122-campaign/launch-campaign.sh --self-test                 # local guards only
#   DESIGN122_CONFIRM=yes dev/design122-campaign/launch-campaign.sh --mode=canary --launch
#
set -euo pipefail

readonly TOTORO_CORE_CAP=150     # D-143; raise ONLY with an explicit, recorded yes
readonly DEFAULT_WORKERS=96      # this campaign's own script-level cap (run-campaign.R hard-caps at 96 regardless)
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
readonly R_SCRIPT="$SCRIPT_DIR/run-campaign.R"

MODE="canary"
CHUNK=""
DO_LAUNCH=0
SELF_TEST=0

usage() {
  sed -n '2,27p' "$SCRIPT_PATH"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:?--mode needs smoke|canary|full}"; shift 2 ;;
    --mode=*) MODE="${1#--mode=}"; shift ;;
    --chunk) CHUNK="${2:?--chunk needs a cell_id integer}"; shift 2 ;;
    --chunk=*) CHUNK="${1#--chunk=}"; shift ;;
    --launch) DO_LAUNCH=1; shift ;;
    --self-test) SELF_TEST=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 2 ;;
  esac
done

case "$MODE" in
  smoke|canary|full) ;;
  *) echo "MODE must be smoke, canary, or full, got: $MODE" >&2; exit 2 ;;
esac

if [[ -n "$CHUNK" ]]; then
  if [[ "$MODE" != "full" ]]; then
    echo "--chunk is only valid with --mode=full" >&2
    exit 2
  fi
  if ! [[ "$CHUNK" =~ ^[0-9]+$ ]] || (( CHUNK < 1 || CHUNK > 24 )); then
    echo "--chunk must be an integer cell_id in 1..24, got: $CHUNK" >&2
    exit 2
  fi
fi

if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  echo "refusing: D-50 forbids campaign launch on GitHub Actions." >&2
  exit 2
fi

NWORKERS="${DESIGN122_WORKERS:-$DEFAULT_WORKERS}"
if ! [[ "$NWORKERS" =~ ^[0-9]+$ ]]; then
  echo "DESIGN122_WORKERS must be an integer, got: $NWORKERS" >&2
  exit 2
fi
if (( NWORKERS < 1 || NWORKERS > TOTORO_CORE_CAP )); then
  echo "NWORKERS=$NWORKERS exceeds the ${TOTORO_CORE_CAP}-core cap (D-143). Ask Shinichi first." >&2
  exit 2
fi

CONFIRM="${DESIGN122_CONFIRM:-}"
CAMPAIGN_ID="${DESIGN122_CAMPAIGN_ID:-<unset -- fill in with the admit.sh campaign_id from MANIFEST.txt>}"
CAMPAIGN_DEST="${DESIGN122_DEST:-<unset -- fill in with the admit.sh destination dir>}"
COMMIT="${DESIGN122_COMMIT:-<unset -- fill in with the deployed R CMD INSTALL revision>}"

print_plan() {
  local tasks
  case "$MODE" in
    smoke)  tasks=1 ;;
    canary) tasks=72 ;;   # 24 cells x 3 arms x 1 seed
    full)
      if [[ -n "$CHUNK" ]]; then tasks=900; else tasks=21600; fi
      ;;
  esac
  cat <<EOF
# Design 122 confirmatory campaign launch plan (dry-run — nothing started)
#
# Mode: $MODE${CHUNK:+ (chunk=$CHUNK)}    tasks: $tasks    workers: $NWORKERS (cap $TOTORO_CORE_CAP)
# Campaign id: $CAMPAIGN_ID
# Destination: $CAMPAIGN_DEST
# Deployed commit: $COMMIT
# D-50: never GitHub Actions. Results stay local under the admitted destination.
#
# This script runs directly ON Totoro (no ssh hop). --launch requires:
#   DESIGN122_CONFIRM=yes AND hostname matching totoro AND NWORKERS <= $TOTORO_CORE_CAP.
#
# Full mode WITHOUT --chunk loops over all 24 cells (21,600 fits total) --
# this is the FULL CAMPAIGN and per Design 122's own staging must only be
# launched after the smoke ladder (rungs 1-3) passes and the maintainer
# gives an explicit D-139 go on the extrapolated wall-time estimate. Full
# mode WITH --chunk=<id> runs exactly one cell (900 fits) -- this is rung 3.
#
# Exact command --launch would run (human / next agent — not a dry-run sitting):
DESIGN122_CONFIRM=yes CAMPAIGN_MODE=$MODE ${CHUNK:+CAMPAIGN_CHUNK=$CHUNK} CAMPAIGN_WORKERS=$NWORKERS \\
  CAMPAIGN_ID=$CAMPAIGN_ID CAMPAIGN_DEST=$CAMPAIGN_DEST \\
  $SCRIPT_PATH --mode=$MODE${CHUNK:+ --chunk=$CHUNK} --launch
#
# which resolves to:
CAMPAIGN_MODE=$([[ "$MODE" == "smoke" ]] && echo "canary" || echo "$MODE") \\
  GRID_SMOKE=$([[ "$MODE" == "smoke" ]] && echo "TRUE" || echo "FALSE") \\
  ${CHUNK:+CAMPAIGN_CHUNK=$CHUNK }CAMPAIGN_WORKERS=$NWORKERS \\
  CAMPAIGN_ID=$CAMPAIGN_ID CAMPAIGN_DEST=$CAMPAIGN_DEST \\
  Rscript --vanilla $R_SCRIPT
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
    echo "refusing --launch without DESIGN122_CONFIRM=yes. Dry-run instead:" >&2
    print_plan
    exit 2
  fi
  if [[ ! -f "$R_SCRIPT" ]]; then
    echo "missing $R_SCRIPT" >&2
    exit 2
  fi
  echo "Design 122 confirmatory $MODE${CHUNK:+ (chunk=$CHUNK)} starting on $(hostname) workers=$NWORKERS commit=$COMMIT campaign_id=$CAMPAIGN_ID"
  if [[ "$MODE" == "smoke" ]]; then
    GRID_SMOKE=TRUE CAMPAIGN_WORKERS="$NWORKERS" CAMPAIGN_ID="$CAMPAIGN_ID" \
      CAMPAIGN_DEST="$CAMPAIGN_DEST" Rscript --vanilla "$R_SCRIPT"
  else
    # NOTE: CAMPAIGN_CHUNK is always assigned literally here (possibly to an
    # empty string) rather than conditionally spliced in via
    # `${CHUNK:+CAMPAIGN_CHUNK="$CHUNK"}` -- that pattern LOOKS equivalent
    # but is NOT: bash's assignment-prefix recognition happens at PARSE
    # TIME from literal `NAME=` syntax, not from the runtime value of a
    # parameter expansion. A `${...}` word in assignment-prefix position is
    # never parsed as an assignment even when it expands to empty, which
    # silently breaks every assignment word after it (reproduced directly:
    # `A=1 ${X:+B=2} C=3 cmd` fails with "C=3: command not found" even
    # though `${X:+B=2}` expands to nothing). run-campaign.R already treats
    # CAMPAIGN_CHUNK="" as "no chunk" (`if (nzchar(CHUNK))`), so an always
    # -present, possibly-empty assignment is correct for both cases.
    CAMPAIGN_MODE="$MODE" CAMPAIGN_CHUNK="$CHUNK" CAMPAIGN_WORKERS="$NWORKERS" \
      CAMPAIGN_ID="$CAMPAIGN_ID" CAMPAIGN_DEST="$CAMPAIGN_DEST" Rscript --vanilla "$R_SCRIPT"
  fi
  echo "Design 122 confirmatory $MODE${CHUNK:+ (chunk=$CHUNK)} finished."
}

self_test() {
  local fail=0
  local out

  out="$("$SCRIPT_PATH" --mode=canary)"
  printf '%s\n' "$out" | grep -q 'nothing started' || { echo "self-test: dry-run missing banner"; fail=1; }

  if DESIGN122_WORKERS=151 "$SCRIPT_PATH" --mode=canary >/dev/null 2>&1; then
    echo "self-test: 151 workers should have been refused"
    fail=1
  fi

  if GITHUB_ACTIONS=true "$SCRIPT_PATH" --mode=canary >/dev/null 2>&1; then
    echo "self-test: GITHUB_ACTIONS should have been refused"
    fail=1
  fi

  if DESIGN122_CONFIRM=no "$SCRIPT_PATH" --mode=canary --launch >/dev/null 2>&1; then
    echo "self-test: --launch without CONFIRM=yes should have been refused"
    fail=1
  fi

  # off-Totoro: even WITH confirm=yes, hostname gate must refuse.
  if DESIGN122_CONFIRM=yes "$SCRIPT_PATH" --mode=canary --launch >/dev/null 2>&1; then
    echo "self-test: --launch off Totoro should have been refused"
    fail=1
  fi

  if "$SCRIPT_PATH" --mode=canary --chunk=1 >/dev/null 2>&1; then
    echo "self-test: --chunk with --mode=canary should have been refused"
    fail=1
  fi

  if "$SCRIPT_PATH" --mode=full --chunk=25 >/dev/null 2>&1; then
    echo "self-test: --chunk=25 (out of 1..24) should have been refused"
    fail=1
  fi

  if [[ $fail -ne 0 ]]; then
    echo "self-test FAIL"
    exit 1
  fi
  echo "self-test PASS (dry-run banner, cap, Actions, confirm, hostname, chunk validation)"
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
