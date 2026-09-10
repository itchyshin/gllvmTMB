#!/usr/bin/env bash
# Generate, validate, or submit the retained temporal--phylogenetic recovery array.
# Default action writes a Slurm script only; submission requires both an explicit
# action and TEMPORAL_PHYLO_DRAC_APPROVED=YES.
set -euo pipefail

usage() {
  cat <<'USAGE'
Run from the exact gllvmTMB source checkout on a DRAC login node.

Environment:
  SLURM_ACTION   write | test | submit  (default: write)
  RESULTS_DIR    durable output root; default: $PROJECT/$USER/gllvmtmb-temporal-phylo
  SLURM_ACCOUNT  required for submit
  SLURM_TIME     wall time per one-fit task (default: 00:15:00)
  SLURM_MEM      memory per one-fit task (default: 8G)
  SLURM_ARRAY_LIMIT  simultaneous tasks (default: 6)
  R_MODULE       R module (default: r/4.5.0)
  R_LIBS_USER_DIR user R library (default: $PROJECT/$USER/R/<R>)
  TEMPORAL_PHYLO_DRAC_APPROVED=YES  required for submit

The array has 22 cells: the exact unfinished portion of the frozen
160-series phylogenetic recovery fixture. Each task writes one receipt under
RESULTS_DIR/attempts; collection is a separate deliberate action.
USAGE
}

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$script_dir/../../.." && pwd)"
cd "$root"

action="${SLURM_ACTION:-write}"
time="${SLURM_TIME:-00:15:00}"
mem="${SLURM_MEM:-8G}"
limit="${SLURM_ARRAY_LIMIT:-6}"
r_module="${R_MODULE:-r/4.5.0}"
r_version="${r_module##*/}"
if [[ -z "${RESULTS_DIR:-}" ]]; then
  : "${PROJECT:?Set RESULTS_DIR or PROJECT before generating a DRAC launch.}"
  RESULTS_DIR="$PROJECT/$USER/gllvmtmb-temporal-phylo"
fi
if [[ -z "${R_LIBS_USER_DIR:-}" ]]; then
  if [[ -n "${PROJECT:-}" ]]; then
    R_LIBS_USER_DIR="$PROJECT/$USER/R/$r_version"
  else
    R_LIBS_USER_DIR="$HOME/.local/R/$r_version"
  fi
fi

[[ -f dev/temporal-program/results/phylo-recovery-160-tasks-20260909.csv ]] || {
  echo "Frozen task manifest is absent." >&2; exit 2; }
Rscript --vanilla dev/temporal-program/remote/phylo-recovery-task.R --mode=plan
source_commit="$(git rev-parse HEAD)"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Refuse to construct a compute envelope from a dirty source checkout." >&2
  exit 2
fi

slurm_dir="$RESULTS_DIR/_slurm"
attempt_dir="$RESULTS_DIR/attempts"
sbatch_file="$slurm_dir/phylo-recovery-160.sbatch"
mkdir -p "$slurm_dir" "$attempt_dir"
cat > "$slurm_dir/manifest.tsv" <<EOF
source_commit\t$source_commit
task_manifest\tphylo-recovery-160-tasks-20260909.csv
task_count\t22
walltime_per_task\t$time
memory_per_task\t$mem
array_limit\t$limit
EOF
cat > "$sbatch_file" <<EOF
#!/usr/bin/env bash
#SBATCH --job-name=gllvmtmb-temporal-phylo
#SBATCH --array=1-22%$limit
#SBATCH --time=$time
#SBATCH --cpus-per-task=1
#SBATCH --mem=$mem
#SBATCH --output=$slurm_dir/%x-%A-%a.out
#SBATCH --error=$slurm_dir/%x-%A-%a.err
EOF
if [[ -n "${SLURM_ACCOUNT:-}" ]]; then
  printf '#SBATCH --account=%s\n' "$SLURM_ACCOUNT" >> "$sbatch_file"
fi
cat >> "$sbatch_file" <<EOF
set -euo pipefail
module load "$r_module"
export R_LIBS_USER="$R_LIBS_USER_DIR"
export R_LIBS="\$R_LIBS_USER\${R_LIBS:+:\$R_LIBS}"
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
cd "$root"
test "\$(git rev-parse HEAD)" = "$source_commit"
test -z "\$(git status --porcelain)"
Rscript --vanilla dev/temporal-program/remote/phylo-recovery-task.R \\
  --mode=task --task-id="\${SLURM_ARRAY_TASK_ID}" --results-dir="$attempt_dir"
EOF

echo "TEMPORAL_PHYLO_DRAC_ENVELOPE action=$action source=$source_commit tasks=22 sbatch=$sbatch_file"
case "$action" in
  write) echo "TEMPORAL_PHYLO_DRAC_WRITE_PASS" ;;
  test) sbatch --test-only "$sbatch_file" ;;
  submit)
    [[ "${TEMPORAL_PHYLO_DRAC_APPROVED:-}" == "YES" ]] || {
      echo "Refusing submission without TEMPORAL_PHYLO_DRAC_APPROVED=YES." >&2; exit 2; }
    : "${SLURM_ACCOUNT:?Set SLURM_ACCOUNT for submission.}"
    sbatch "$sbatch_file"
    ;;
  *) usage >&2; exit 2 ;;
esac
