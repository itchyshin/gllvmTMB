#!/bin/bash
# =============================================================================
# 27 -- submit the AGHQ estimator campaign to DRAC as SLURM job ARRAYS
# =============================================================================
# Recipe from ~/shinichi-brain/tools/drac-setup.md:
#   §7  one array, N tasks, one seed per $SLURM_ARRAY_TASK_ID; % throttles
#   §11 module load gcc BEFORE r; same R_LIBS in the job as at install time
#   §0  never compute on a login node; --time and --account ALWAYS explicit;
#       results off /scratch (they land in ~/gllvmtmb-aghq/results, on /home)
#
# ONE ARRAY PER CELL, deliberately: --time is per-task and shared across an array,
# and the cells differ by ~20x in cost (n=100 vs n=1600). One array for everything
# would have to buy the worst case for every task, which lowers priority and makes
# the whole campaign queue behind its slowest member.
#
# Usage:  bash 27-drac-submit.sh smoke     # 2 tasks/cell, validates end-to-end
#         bash 27-drac-submit.sh stage1    # 400 tasks/cell = 2400 replicates
# =============================================================================
set -e
MODE="${1:-smoke}"
ACCOUNT="def-snakagaw_cpu"
BASE=~/gllvmtmb-aghq
RES="$BASE/results/$MODE"
LOGS="$BASE/logs/$MODE"
DGP_CHECKSUM=43.170363          # from 24-estimator-campaign.R's own mk(); see 27-checksum.R
mkdir -p "$RES" "$LOGS"

case "$MODE" in
  smoke)  NSIM=2   ;;
  stage1) NSIM=400 ;;
  stage2) NSIM=200 ;;
  stage3) NSIM=200 ;;   # #847 step 1: the laplace+ridge+multistart arm
  *) echo "unknown mode: $MODE"; exit 1 ;;
esac

# cell: family n lam_sd walltime mem
# RIGHT-SIZED FROM THE SMOKE's OWN seff, not guessed (§0 rule 5 -- over-asking lowers
# future priority AND makes jobs wait). Measured on fir, one replicate = 5 arms:
#   n=100  wall 0:59  cpu 0:55  mem 576 MB
#   n=400  wall 4:01  cpu 3:56  mem 994 MB
#   n=1600 wall 9:38  cpu 9:30  mem 1.88 GB
# Walltimes below are ~5x the measured wall, which covers node-to-node variance and
# the fact that lam_sd=3 fits are slower than the lam_sd=1 cells that were smoked.
# My original guesses (1h/3h/8h) were 50-60x over -- they came from laptop timings on
# a contended machine, and fir is far faster. Guessing from the wrong machine is how
# a campaign ends up queued behind a walltime it never needed.
# Stage 2 = the generality/control arm of the design: gaussian and poisson are the
# "does the quadrature move the answer AT ALL" families. 200 seeds is enough because
# the question there is near-0/near-1 (a proportion), not a fine effect size.
# Walltimes scaled from the local Stage-2 exercise, then divided by the ~2.5x speed
# advantage fir showed over the laptop on Stage 1, with margin kept.
if [ "$MODE" = "stage3" ]; then
# #847 step 1. Only the sigma_lambda=3 cells: that is where laplace_ridge fails
# (0% / 1% / 67% runaway at n=100/400/1600) and where the over-shrinkage is worst
# (median frob 0.666 at n=100). 200 seeds gives MCSE <= 3.5% on a runaway proportion,
# which is ample to tell 67% from 0%.
CELLS=(
  "binomial 100  3 00:30:00 2G"
  "binomial 400  3 01:00:00 2G"
  "binomial 1600 3 02:00:00 3G"
)
elif [ "$MODE" = "stage2" ]; then
CELLS=(
  "gaussian 100  1 00:15:00 2G"
  "poisson  100  1 00:30:00 2G"
  "gaussian 1600 1 00:45:00 3G"
  "poisson  1600 1 02:00:00 4G"
)
else
CELLS=(
  "binomial 100  1 00:15:00 2G"
  "binomial 100  3 00:15:00 2G"
  "binomial 400  1 00:30:00 2G"
  "binomial 400  3 00:30:00 2G"
  "binomial 1600 1 01:00:00 3G"
  "binomial 1600 3 01:00:00 3G"
)
fi

for cell in "${CELLS[@]}"; do
  read -r fam n lam wall mem <<< "$cell"
  name="aghq-${fam}-n${n}-lam${lam}"
  script="$BASE/sbatch_${name}_${MODE}.sh"
  cat > "$script" <<SBATCH
#!/bin/bash
#SBATCH --account=${ACCOUNT}
#SBATCH --job-name=${name}
#SBATCH --time=${wall}
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=${mem}
#SBATCH --array=1-${NSIM}%100
#SBATCH --output=${LOGS}/%x_%A_%a.out
set -e
module load gcc/12.3
module load proj/9.2.0 udunits/2.2.28 geos/3.12.0 gdal/3.9.1  # proj FIRST: gdal wants 9.2.0
module load r/4.5.0
export R_LIBS=~/.local/R/\${EBVERSIONR}
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1   # one core per task; no nested threads
export CELL_FAMILY=${fam} CELL_N=${n} CELL_LAM=${lam}
export OUTDIR=${RES}
export DGP_CHECKSUM=${DGP_CHECKSUM}
Rscript ${BASE}/27-drac-one-replicate.R
SBATCH
  jid=$(sbatch --parsable "$script")
  echo "submitted ${name}  array 1-${NSIM}  walltime ${wall}  mem ${mem}  jobid ${jid}"
done

echo
echo "watch:   squeue -u \$USER"
echo "results: $RES"
echo "after the smoke, run 'seff <jobid>' and tighten --time/--mem before stage1"
