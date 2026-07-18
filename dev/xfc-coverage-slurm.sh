#!/usr/bin/env bash
#
# DRAFT DRAC SLURM array script -- cross-family coverage CONFIRM run.
#
#   STATUS: DRAFT. Verify --account/paths on a real DRAC login node before
#   use. This file authors a job array; it is NOT deployed or submitted by
#   writing it.
#   AUTH: needs exactly one interactive Duo MFA login on the DRAC login node
#   to `sbatch` this file (or to rsync the worktree there first).
#   RESULTS: LOCAL only (D-50) -- never store campaign output as a GitHub
#   Actions artifact. Copy shard .rds files off /scratch (60-day purge, no
#   backup) onto /project or back to a local disk promptly.
#   CERTIFICATION STATUS: every number this harness produces is
#   "MEASURED, NOT certified -- awaiting D-43 panel" (see XFC_BANNER in
#   dev/cross-family-coverage.R). This script does not change that.
#
# One array task == one shard == one contiguous rep-range block per grid
# cell (see .xfc_shard_range() in dev/cross-family-coverage.R). Each task
# calls the harness with --mode=confirm --shard=$SLURM_ARRAY_TASK_ID
# --n-shards=<N> and writes exactly one .rds under --out-dir; shards are
# aggregated OFFLINE after the array completes (no reduction step here).
#
#SBATCH --job-name=gtmb-xfc-coverage
#SBATCH --account=def-snakagaw
#SBATCH --array=1-100
# --time and --mem are sane defaults for one shard of the certified grid
# (18 cells x confirm-scale rep block, K=3 cross-family refits per rep,
# inner bootstrap n-boot=499 on the wired bootstrap cells). RIGHT-SIZE both
# after the first few array tasks land: `seff <jobid>_<taskid>` and adjust.
#SBATCH --time=06:00:00
#SBATCH --mem=8G
# One thread is enough per task unless BLAS is multi-threaded; pin
# OMP/OPENBLAS/MKL to 1 below regardless, so --cpus-per-task=1 is the safe
# default. Bump only if profiling with `seff` shows the task is CPU-bound
# across more than one core.
#SBATCH --cpus-per-task=1
#SBATCH --output=/project/def-snakagaw/%u/gtmb-xfam-ci11/logs/xfc-coverage-%A_%a.out
#SBATCH --error=/project/def-snakagaw/%u/gtmb-xfam-ci11/logs/xfc-coverage-%A_%a.err

set -euo pipefail

# ---------------------------------------------------------------------
# R_LIBS -- MUST point at a /project-side library, built fresh for this
# job. DO NOT reuse /scratch (60-day purge, no backup) or a stale 0.5.0
# install (the same gotcha documented for Totoro: an old gllvmTMB build
# sitting ahead of the load_all/installed dev copy on the search path
# silently runs the wrong package version). Build the lib in a PRIOR
# interactive/Duo session with:
#   module load r/4.5.0
#   mkdir -p /home/$USER/projects/def-snakagaw/$USER/gtmb-xfam-lib
#   Rscript -e 'install.packages("remotes", lib="/home/$USER/projects/def-snakagaw/$USER/gtmb-xfam-lib")'
#   R_LIBS=/home/$USER/projects/def-snakagaw/$USER/gtmb-xfam-lib Rscript -e \
#     'remotes::install_local(".", dependencies = TRUE, upgrade = "never")'
# then re-verify with `packageVersion("gllvmTMB")` INSIDE this job before
# trusting a run.
# ---------------------------------------------------------------------
export R_LIBS="/home/${USER}/projects/def-snakagaw/${USER}/gtmb-xfam-lib:/home/${USER}/R/lib"

module load r/4.5.0

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1

# Placeholder paths -- verify before submitting. REPO_ROOT is wherever the
# gtmb-xfam-ci11 worktree lands on DRAC (rsync'd or cloned separately; this
# script does not do that step).
REPO_ROOT="/project/def-snakagaw/${USER}/gtmb-xfam-ci11"
OUT_DIR="/project/def-snakagaw/${USER}/gtmb-xfam-ci11-results"
N_SHARDS=100

mkdir -p "$OUT_DIR"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------
# Certification invocation (the CONFIRM run this array performs). n-sim is
# inflated above the target ~13k CONVERGED reps to absorb non-convergence
# attrition (see .xfc_launch_note() in dev/cross-family-coverage.R); n-boot
# is the certification bootstrap resolution (>= 499); estimands cover both
# wired functionals (multiple_r x {bootstrap, wald}; contrast_r x
# {profile, wald, bootstrap}).
# ---------------------------------------------------------------------
XFC_MAIN=1 Rscript --vanilla dev/cross-family-coverage.R \
  --mode=confirm \
  --grid=certified \
  --shard="${SLURM_ARRAY_TASK_ID}" \
  --n-shards="${N_SHARDS}" \
  --n-sim=13000 \
  --n-boot=499 \
  --seed-base=20260718 \
  --out-dir="${OUT_DIR}" \
  --estimands=multiple_r,contrast_r
