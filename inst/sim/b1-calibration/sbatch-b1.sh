#!/usr/bin/env bash
## Design 118 B1 -- DRAC job-array template.
## docs/design/118-mspl-interval-calibration-protocol.md s6.4;
## docs/dev-log/2026-08-15-b1-launch-spec.md.
##
## #####################################################################
## # DO NOT SUBMIT BY HAND. This is a TEMPLATE for the orchestrator's   #
## # launch step, not a ready-to-run script. It is committed so the    #
## # sbatch shape, account, and module conventions are reviewable, and #
## # is deliberately NOT wired into any CI or automatic launch path    #
## # (D-50: simulation campaigns run on Totoro or DRAC, never GitHub   #
## # Actions).                                                          #
## #####################################################################
##
## Conventions below (account string, module load order, R library on
## /project, OPENBLAS_NUM_THREADS=1) are copied from the prior MSPL
## campaign's DRAC wrappers on branch codex/lane-b-mspl-interval-feasibility
## (inst/sim/lane-b-uncertainty/mspl-coverage/lib-mspl-coverage.sh
## mspl_load_modules()/mspl_stage_runtime(), and the drac-*.sbatch account
## lines). This template does NOT reproduce that campaign's staged-runtime /
## SHA-256 launcher-bundle verification machinery -- that is a separate,
## more elaborate deployment mechanism outside this harness's scope; the
## orchestrator may wrap this template with an equivalent integrity check
## before it is ever submitted.
##
## ---- Parameters the orchestrator must fill in before submitting --------
#SBATCH --account=def-snakagaw_cpu
#SBATCH --job-name=mspl_b1_calibration
## ARRAY range: N = number of rows from
##   Rscript inst/sim/b1-calibration/run-b1-shard.R --print-map | wc -l
## which is `132 cells * ceiling(600 / outer-per-shard) shards/cell`
## (7,920 at the default --outer-per-shard 10; Design 118 s5). Fill in
## before submitting -- deliberately left unset here so an accidental
## `sbatch` of this file fails closed instead of launching an unsized array.
##SBATCH --array=1-7920
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G

set -euo pipefail

## ---- Fill in before submitting (all four; /project only, never /scratch,
## for anything the campaign needs to keep -- D-143/D-50) -----------------
PACKAGE_ROOT="${MSPL_B1_PACKAGE_ROOT:?set to the gllvmTMB checkout on /project}"
R_LIB="${MSPL_B1_R_LIB:?set to an R library directory on /project}"
OUT_ROOT="${MSPL_B1_OUT_ROOT:?set to the campaign output root on /project}"
[[ "$OUT_ROOT" == /project/* ]] || { echo "OUT_ROOT must be under /project" >&2; exit 2; }

module purge
module load StdEnv/2023
module load gcc/12.3
module load r/4.5.0

export R_LIBS_USER="$R_LIB"
export R_LIBS="$R_LIB"
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
## Design 118 s7 prerequisites (mspl_c_n_multiplier, profile bracket fix)
## are not yet in any installed site library -- load from source.
export GLLVM_TMB_PILOT_SOURCE=true

cd "$PACKAGE_ROOT"
Rscript --vanilla inst/sim/b1-calibration/run-b1-shard.R \
  --task-id "${SLURM_ARRAY_TASK_ID:?}" \
  --outer-per-shard 10 \
  --reps 600 \
  --bootstrap-reps 500 \
  --out "$OUT_ROOT"

## ---- Pre-launch smoke (D-139), run once before releasing the full array:
##   sbatch --array=1-1 sbatch-b1.sh
## then verify a non-empty shard CSV with no NA in key columns before
## submitting the sized array above.
