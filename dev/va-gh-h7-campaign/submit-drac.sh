#!/usr/bin/env bash
set -euo pipefail

# Login-node-safe submission wrapper. It validates immutable inputs and derives
# the SLURM array from nrow(plan); all fits run in drac-array.sbatch.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVER="$SCRIPT_DIR/run-cell.R"
SBATCH_FILE="$SCRIPT_DIR/drac-array.sbatch"
ACTION="${ACTION:-write}"
ARRAY_LIMIT="${ARRAY_LIMIT:-100}"
MAX_ARRAY_TASKS="${MAX_ARRAY_TASKS:-1000}"

: "${REPO_DIR:?Set REPO_DIR to the gllvmTMB checkout on /project}"
: "${CAMPAIGN_PROJECT_ROOT:?Set CAMPAIGN_PROJECT_ROOT under /project}"
: "${GATE_E_RECEIPT:?Set GATE_E_RECEIPT to the structured Gate-E receipt}"
: "${VA_RUNTIME_MANIFEST:?Set VA_RUNTIME_MANIFEST to runtime.dcf}"
: "${VA_PREFLIGHT_RECEIPT:?Set VA_PREFLIGHT_RECEIPT to preflight.dcf}"
: "${SLURM_ACCOUNT:?Set SLURM_ACCOUNT explicitly}"

PLAN="${PLAN:-$CAMPAIGN_PROJECT_ROOT/plan.csv}"
OUTPUT_DIR="${OUTPUT_DIR:-$CAMPAIGN_PROJECT_ROOT/results}"
LOG_DIR="${LOG_DIR:-$CAMPAIGN_PROJECT_ROOT/logs}"

for path in "$REPO_DIR" "$CAMPAIGN_PROJECT_ROOT" "$GATE_E_RECEIPT" \
  "$VA_RUNTIME_MANIFEST" "$VA_PREFLIGHT_RECEIPT" "$PLAN" \
  "$OUTPUT_DIR" "$LOG_DIR"; do
  case "$path" in /project/*) ;; *) echo "DRAC path must be under /project: $path" >&2; exit 2 ;; esac
done
if ! [[ "$ARRAY_LIMIT" =~ ^[0-9]+$ ]] || (( ARRAY_LIMIT < 1 )); then
  echo "ARRAY_LIMIT must be a positive integer." >&2
  exit 2
fi
if ! [[ "$MAX_ARRAY_TASKS" =~ ^[0-9]+$ ]] || (( MAX_ARRAY_TASKS < 1 )); then
  echo "MAX_ARRAY_TASKS must be a positive integer." >&2
  exit 2
fi
[[ -f "$PLAN" ]] || { echo "immutable plan missing: $PLAN" >&2; exit 3; }

Rscript --vanilla "$DRIVER" --mode=verify-runtime \
  --gate-receipt="$GATE_E_RECEIPT" \
  --runtime-manifest="$VA_RUNTIME_MANIFEST" \
  --preflight-receipt="$VA_PREFLIGHT_RECEIPT"

tasks="$(Rscript --vanilla -e 'x <- read.csv(commandArgs(TRUE)[1]); stopifnot(nrow(x) > 0L, identical(as.integer(x$task_id), seq_len(nrow(x)))); cat(nrow(x))' "$PLAN")"
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

submission_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
submission_log="$LOG_DIR/submission-$submission_stamp.tsv"

submit_batch() {
  local first="$1"
  local last="$2"
  local label="$3"
  local count=$((last - first + 1))
  local offset=$((first - 1))
  local array_spec="1-${count}%${ARRAY_LIMIT}"
  local export_spec="ALL,REPO_DIR=$REPO_DIR,CAMPAIGN_PROJECT_ROOT=$CAMPAIGN_PROJECT_ROOT,GATE_E_RECEIPT=$GATE_E_RECEIPT,VA_RUNTIME_MANIFEST=$VA_RUNTIME_MANIFEST,VA_PREFLIGHT_RECEIPT=$VA_PREFLIGHT_RECEIPT,PLAN=$PLAN,OUTPUT_DIR=$OUTPUT_DIR,TASK_OFFSET=$offset"
  local command=(
    sbatch
    "--account=$SLURM_ACCOUNT"
    "--array=$array_spec"
    "--job-name=va-gh-h7-$label"
    "--output=$LOG_DIR/va-gh-h7-$label-%A-%a.out"
    "--error=$LOG_DIR/va-gh-h7-$label-%A-%a.err"
    "--export=$export_spec"
    --parsable
    "$SBATCH_FILE"
  )
  if [[ "$ACTION" == "write" ]]; then
    printf 'tasks=%s-%s ' "$first" "$last"
    printf '%q ' "${command[@]}"
    printf '\n'
  else
    local job_id
    job_id="$("${command[@]}")"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$submission_stamp" "$job_id" "$first" "$last" "$PLAN" >> "$submission_log"
    printf 'submitted job=%s tasks=%s-%s\n' "$job_id" "$first" "$last"
  fi
}

case "$ACTION" in
  smoke)
    printf 'submitted_utc\tjob_id\tfirst_task\tlast_task\tplan\n' > "$submission_log"
    submit_batch 1 1 smoke
    ;;
  write|submit)
    if [[ "$ACTION" == "submit" ]]; then
      Rscript --vanilla "$DRIVER" --mode=verify-task --plan="$PLAN" \
        --output-dir="$OUTPUT_DIR" --task-index=1 \
        --gate-receipt="$GATE_E_RECEIPT" \
        --runtime-manifest="$VA_RUNTIME_MANIFEST" \
        --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
      printf 'submitted_utc\tjob_id\tfirst_task\tlast_task\tplan\n' > "$submission_log"
    fi
    first=1
    batch=1
    while (( first <= tasks )); do
      last=$((first + MAX_ARRAY_TASKS - 1))
      (( last > tasks )) && last="$tasks"
      submit_batch "$first" "$last" "b$batch"
      first=$((last + 1))
      batch=$((batch + 1))
    done
    ;;
  *) echo "ACTION must be write, smoke, or submit" >&2; exit 2 ;;
esac
