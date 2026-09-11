#!/usr/bin/env bash
# Generate, validate, or submit the distinct six-cell damped-Newton
# qualification array.  It is intentionally separate from the frozen 22-cell
# recovery remainder and requires a fresh approval token to submit.
set -euo pipefail

usage() {
  cat <<'USAGE'
Run from the exact gllvmTMB source checkout on a DRAC login node.

Environment:
  SLURM_ACTION  write | test | submit (default: write)
  RESULTS_DIR   durable output root; default: $PROJECT/$USER/gllvmtmb-temporal-phylo-newton
  SLURM_ACCOUNT required for submit
  SLURM_TIME    wall time per single-cell task (default: 00:45:00)
  SLURM_MEM     memory per task (default: 8G)
  R_MODULE      R module (default: r/4.5.0)
  R_LIBS_USER_DIR user R library (default: $PROJECT/$USER/R/<R>)
  GLLVMTMB_TEMPORAL_LOAD installed | pkgload (default: installed)
  TEMPORAL_PHYLO_DAMPED_NEWTON_STAGE full | baseline | probe | curvature_collect | line | step_collect | final | final_collect (default: full)
  TEMPORAL_PHYLO_DAMPED_NEWTON_DRAC_APPROVED=YES required for submit

The baseline has six frozen cells.  Each expensive TMB endpoint uses one
single-core task and retains one RDS receipt.  Collector stages refuse missing,
duplicate, or mismatched receipts; a model rejection remains retained evidence.
USAGE
}

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$script_dir/../../.." && pwd)"
cd "$root"
action="${SLURM_ACTION:-write}"
stage="${TEMPORAL_PHYLO_DAMPED_NEWTON_STAGE:-full}"
time="${SLURM_TIME:-00:45:00}"
mem="${SLURM_MEM:-8G}"
r_module="${R_MODULE:-r/4.5.0}"
load_mode="${GLLVMTMB_TEMPORAL_LOAD:-installed}"
r_version="${r_module##*/}"
if [[ -z "${RESULTS_DIR:-}" ]]; then
  : "${PROJECT:?Set RESULTS_DIR or PROJECT before generating a DRAC launch.}"
  RESULTS_DIR="$PROJECT/$USER/gllvmtmb-temporal-phylo-newton"
fi
if [[ -z "${R_LIBS_USER_DIR:-}" ]]; then
  if [[ -n "${PROJECT:-}" ]]; then R_LIBS_USER_DIR="$PROJECT/$USER/R/$r_version";
  else R_LIBS_USER_DIR="$HOME/.local/R/$r_version"; fi
fi
[[ "$load_mode" == "installed" || "$load_mode" == "pkgload" ]] || {
  echo "GLLVMTMB_TEMPORAL_LOAD must be installed or pkgload." >&2; exit 2; }
Rscript --vanilla dev/temporal-program/remote/phylo-damped-newton-task.R --mode=plan
case "$stage" in full|baseline|probe|curvature_collect|line|step_collect|final|final_collect) ;; *)
  echo "Unsupported TEMPORAL_PHYLO_DAMPED_NEWTON_STAGE: $stage" >&2; exit 2 ;; esac
source_commit="$(git rev-parse HEAD)"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Refuse to construct a compute envelope from a dirty source checkout." >&2; exit 2
fi

slurm_dir="$RESULTS_DIR/_slurm"
attempt_dir="$RESULTS_DIR/attempts"
sbatch_file="$slurm_dir/phylo-damped-newton-${stage}.sbatch"
checkpoint_dir="$RESULTS_DIR/baselines"
probe_dir="$RESULTS_DIR/probes"
curvature_dir="$RESULTS_DIR/curvature"
line_dir="$RESULTS_DIR/line"
step_dir="$RESULTS_DIR/steps"
final_dir="$RESULTS_DIR/final"
decision_dir="$RESULTS_DIR/decisions"
mkdir -p "$slurm_dir" "$attempt_dir"
# --array=1-6%6 is the frozen six-cell shape for full, baseline, and all
# collector stages. Probe and line stages replace it only with independent
# endpoint tasks, capped at the authorized 250 total workers.
array="1-6%6"
worker_args="--mode=task --task-id=\${SLURM_ARRAY_TASK_ID} --results-dir=$attempt_dir"
if [[ "$stage" == "baseline" ]]; then
  mkdir -p "$checkpoint_dir"
  worker_args="--mode=baseline --task-id=\${SLURM_ARRAY_TASK_ID} --results-dir=$checkpoint_dir"
elif [[ "$stage" == "probe" ]]; then
  mkdir -p "$probe_dir"
  probe_plan="$slurm_dir/phylo-damped-newton-probe-plan.tsv"
  [[ ! -e "$probe_plan" ]] || { echo "Refusing to overwrite frozen probe plan: $probe_plan" >&2; exit 2; }
  Rscript --vanilla dev/temporal-program/remote/phylo-damped-newton-task.R \
    --mode=probe_plan --checkpoint-dir="$checkpoint_dir" --output="$probe_plan"
  probe_count="$(awk 'END { print NR - 1 }' "$probe_plan")"
  [[ "$probe_count" =~ ^[1-9][0-9]*$ ]] || { echo "Probe plan is empty." >&2; exit 2; }
  array="1-${probe_count}%250"
  worker_args="--mode=probe --probe-plan=$probe_plan --checkpoint-dir=$checkpoint_dir --probe-task-id=\${SLURM_ARRAY_TASK_ID} --results-dir=$probe_dir"
elif [[ "$stage" == "curvature_collect" ]]; then
  mkdir -p "$curvature_dir"
  probe_plan="$slurm_dir/phylo-damped-newton-probe-plan.tsv"
  [[ -f "$probe_plan" ]] || { echo "Missing frozen probe plan: $probe_plan" >&2; exit 2; }
  array="1-6%6"
  worker_args="--mode=curvature_collect --checkpoint-dir=$checkpoint_dir --probe-plan=$probe_plan --probe-dir=$probe_dir --task-id=\${SLURM_ARRAY_TASK_ID} --results-dir=$curvature_dir"
elif [[ "$stage" == "line" ]]; then
  mkdir -p "$line_dir"
  line_plan="$slurm_dir/phylo-damped-newton-line-plan.tsv"
  [[ ! -e "$line_plan" ]] || { echo "Refusing to overwrite frozen line-search plan: $line_plan" >&2; exit 2; }
  Rscript --vanilla dev/temporal-program/remote/phylo-damped-newton-task.R \
    --mode=line_plan --checkpoint-dir="$checkpoint_dir" --curvature-dir="$curvature_dir" --output="$line_plan"
  line_count="$(awk 'END { print NR - 1 }' "$line_plan")"
  if [[ "$line_count" == "0" ]]; then
    echo "TEMPORAL_PHYLO_DAMPED_NEWTON_NO_ELIGIBLE_LINE_TRIALS"
    exit 0
  fi
  [[ "$line_count" =~ ^[1-9][0-9]*$ ]] || { echo "Line plan is malformed." >&2; exit 2; }
  array="1-${line_count}%250"
  worker_args="--mode=line_probe --line-plan=$line_plan --checkpoint-dir=$checkpoint_dir --curvature-dir=$curvature_dir --line-task-id=\${SLURM_ARRAY_TASK_ID} --results-dir=$line_dir"
elif [[ "$stage" == "step_collect" ]]; then
  mkdir -p "$step_dir"
  line_plan="$slurm_dir/phylo-damped-newton-line-plan.tsv"
  [[ -f "$line_plan" ]] || { echo "Missing frozen line-search plan: $line_plan" >&2; exit 2; }
  array="1-6%6"
  worker_args="--mode=step_collect --checkpoint-dir=$checkpoint_dir --curvature-dir=$curvature_dir --line-plan=$line_plan --line-dir=$line_dir --task-id=\${SLURM_ARRAY_TASK_ID} --results-dir=$step_dir"
elif [[ "$stage" == "final" ]]; then
  mkdir -p "$final_dir"
  final_plan="$slurm_dir/phylo-damped-newton-final-plan.tsv"
  [[ ! -e "$final_plan" ]] || { echo "Refusing to overwrite frozen final-replay plan: $final_plan" >&2; exit 2; }
  Rscript --vanilla dev/temporal-program/remote/phylo-damped-newton-task.R \
    --mode=final_plan --checkpoint-dir="$checkpoint_dir" --step-dir="$step_dir" --output="$final_plan"
  final_count="$(awk 'END { print NR - 1 }' "$final_plan")"
  if [[ "$final_count" == "0" ]]; then
    echo "TEMPORAL_PHYLO_DAMPED_NEWTON_NO_FINAL_REPLAYS"
    exit 0
  fi
  [[ "$final_count" =~ ^[1-9][0-9]*$ ]] || { echo "Final-replay plan is malformed." >&2; exit 2; }
  array="1-${final_count}%250"
  worker_args="--mode=final_probe --final-plan=$final_plan --checkpoint-dir=$checkpoint_dir --step-dir=$step_dir --final-task-id=\${SLURM_ARRAY_TASK_ID} --results-dir=$final_dir"
elif [[ "$stage" == "final_collect" ]]; then
  mkdir -p "$decision_dir"
  final_plan="$slurm_dir/phylo-damped-newton-final-plan.tsv"
  [[ -f "$final_plan" ]] || { echo "Missing frozen final-replay plan: $final_plan" >&2; exit 2; }
  array="1-6%6"
  worker_args="--mode=final_collect --checkpoint-dir=$checkpoint_dir --curvature-dir=$curvature_dir --step-dir=$step_dir --final-plan=$final_plan --final-dir=$final_dir --task-id=\${SLURM_ARRAY_TASK_ID} --results-dir=$decision_dir"
fi
{
  printf 'source_commit\t%s\n' "$source_commit"
  printf 'task_plan\t%s\n' 'temporal_phylo_damped_newton_plan'
  printf 'task_count\t6\n'
  printf 'stage\t%s\n' "$stage"
  printf 'array\t%s\n' "$array"
  printf 'walltime_per_task\t%s\n' "$time"
  printf 'memory_per_task\t%s\n' "$mem"
  printf 'load_mode\t%s\n' "$load_mode"
} > "$slurm_dir/manifest.tsv"
cat > "$sbatch_file" <<EOF
#!/usr/bin/env bash
#SBATCH --job-name=gllvmtmb-temporal-newton
#SBATCH --array=$array
#SBATCH --time=$time
#SBATCH --cpus-per-task=1
#SBATCH --mem=$mem
#SBATCH --output=$slurm_dir/%x-%A-%a.out
#SBATCH --error=$slurm_dir/%x-%A-%a.err
EOF
if [[ -n "${SLURM_ACCOUNT:-}" ]]; then printf '#SBATCH --account=%s\n' "$SLURM_ACCOUNT" >> "$sbatch_file"; fi
cat >> "$sbatch_file" <<EOF
set -euo pipefail
module load "$r_module"
export R_LIBS_USER="$R_LIBS_USER_DIR"
export R_LIBS="\$R_LIBS_USER\${R_LIBS:+:\$R_LIBS}"
export GLLVMTMB_TEMPORAL_LOAD="$load_mode"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
cd "$root"
test "\$(git rev-parse HEAD)" = "$source_commit"
test -z "\$(git status --porcelain)"
Rscript --vanilla dev/temporal-program/remote/phylo-damped-newton-task.R $worker_args
EOF
echo "TEMPORAL_PHYLO_DAMPED_NEWTON_DRAC_ENVELOPE action=$action stage=$stage source=$source_commit array=$array sbatch=$sbatch_file"
case "$action" in
  write) echo "TEMPORAL_PHYLO_DAMPED_NEWTON_DRAC_WRITE_PASS" ;;
  test) sbatch --test-only "$sbatch_file" ;;
  submit)
    [[ "${TEMPORAL_PHYLO_DAMPED_NEWTON_DRAC_APPROVED:-}" == "YES" ]] || {
      echo "Refusing submission without TEMPORAL_PHYLO_DAMPED_NEWTON_DRAC_APPROVED=YES." >&2; exit 2; }
    : "${SLURM_ACCOUNT:?Set SLURM_ACCOUNT for submission.}"
    sbatch "$sbatch_file"
    ;;
  *) usage >&2; exit 2 ;;
esac
