#!/usr/bin/env bash
# =============================================================================
# Totoro launcher for the Sigma_unit_diag coverage RE-SCORE (profile_total /
# wald_t_logsd), the certificate-path companion to the grid2000 bootstrap
# column. Written 2026-07-16 (Lane A).
#
# Totoro is Shinichi's personal lab server: PASSWORDLESS key-based `ssh totoro`,
# NO Duo/MFA, no queue/SLURM (that is DRAC only). Runs directly. A ControlMaster
# socket (~/.ssh/cm/cm-<user>@totoro...:22) may exist and speeds repeat calls,
# but plain `ssh totoro 'cmd'` works on its own.
#
# Discipline (brain totoro-setup + D-50):
#   * <= 100 cores (shared lab server) -> CORES=96 default.
#   * R library on /project (persistent), NEVER /scratch (60-day purge).
#   * OPENBLAS_NUM_THREADS=1. Results stay LOCAL. Never GitHub artifacts (D-50).
#   * Core-2 cells ONLY (gaussian, binomial). nbinom2 + ordinal stay FENCED.
#   * Certificate defaults NOT-DONE (D-43): the Rose panel gates any flip.
#
# The profile is the compute driver (~30 s/rep local; analytic gradient on).
# n_sim=2000 x 8 core-2 cells / 96 cores ~ a few hours through lab contention;
# estimate from the SLOWEST shard's observed rate and quote the pessimistic end.
# =============================================================================
set -euo pipefail

SOCK="$HOME/.ssh/cm/cm-snakagaw@totoro.biology.ualberta.ca:22"
REMOTE="totoro"
RWORK="gllvm_work/gllvmTMB"
# Totoro is a personal server: NO /project mount. R library lives in HOME
# (~/gllvm_work/Rlib, already provisioned by the grid2000 campaign).
RLIB="\$HOME/gllvm_work/Rlib"
CORES="${CORES:-64}"
NSIM="${NSIM:-2000}"
NBOOT="${NBOOT:-100}"
OUTDIR="${OUTDIR:-\$HOME/gllvm_work/profile_rescore}"
STAGE="${1:-smoke}"                       # smoke | grid | aggregate

# Prefer the ControlMaster socket if present; otherwise a plain passwordless
# key-based ssh (Totoro needs NO Duo -- that is DRAC only).
ssh_t() {
  if [ -S "$SOCK" ]; then
    ssh -o ControlPath="$SOCK" -o ControlMaster=no -o BatchMode=yes "$REMOTE" "$@"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=15 "$REMOTE" "$@"
  fi
}

if ! ssh_t 'true' 2>/dev/null; then
  echo "ERROR: cannot reach Totoro over passwordless ssh." >&2
  echo "  Check:  ssh -o BatchMode=yes totoro 'echo ok'   (key-based, no Duo)" >&2
  exit 1
fi
echo "[totoro] reachable; host: $(ssh_t hostname); nproc: $(ssh_t nproc)"

# --- 1. Deploy package + harness ---------------------------------------------
echo "[totoro] rsync package + dev harness -> $RWORK"
rsync -az --delete \
  -e "ssh -o ControlPath=$SOCK -o ControlMaster=no" \
  --exclude '.git' --exclude 'results' --exclude '*.o' --exclude '*.so' \
  ./ "$REMOTE:$RWORK/"

# --- 2. Build the package on Totoro ------------------------------------------
# Internals are @noRd -> no NAMESPACE/Rd regen needed; install with the existing
# (committed) NAMESPACE. Compiles the TMB template once so shards just load the
# installed, pre-compiled namespace (never load_all -> no per-shard recompile).
ssh_t "mkdir -p '$RLIB' && cd $RWORK && \
  OPENBLAS_NUM_THREADS=1 R_LIBS_USER='$RLIB' R CMD INSTALL --no-multiarch ."

# --- 3a. SMOKE: 1 shard, tiny n_sim, read the FIRST cell early ---------------
if [ "$STAGE" = "smoke" ]; then
  echo "[totoro] SMOKE: n_sim=2, 1 shard (proves non-empty valid output BEFORE the grid)"
  ssh_t "cd $RWORK && OPENBLAS_NUM_THREADS=1 R_LIBS_USER='$RLIB' \
    Rscript dev/profile-rescore-run.R --mode=shard --shard=1 --n-shards=1 \
      --n-sim=2 --n-boot=10 --out-dir='$OUTDIR/smoke'"
  echo "[totoro] smoke done. Inspect $OUTDIR/smoke, then:  CORES=$CORES NSIM=$NSIM $0 grid"
  exit 0
fi

# --- 3b. GRID: shard rep-ranges across CORES ---------------------------------
if [ "$STAGE" = "grid" ]; then
  echo "[totoro] RE-SCORE grid: n_sim=$NSIM, core-2 cells, $CORES rep-shards"
  ssh_t "cd $RWORK && seq 1 $CORES | \
    OPENBLAS_NUM_THREADS=1 R_LIBS_USER='$RLIB' \
    xargs -P $CORES -I {} Rscript dev/profile-rescore-run.R \
      --mode=shard --shard={} --n-shards=$CORES \
      --n-sim=$NSIM --n-boot=$NBOOT --out-dir='$OUTDIR'"
  echo "[totoro] grid shards done. Aggregate:  $0 aggregate"
  exit 0
fi

# --- 3c. AGGREGATE: collect shards -> m3_summarise ---------------------------
if [ "$STAGE" = "aggregate" ]; then
  ssh_t "cd $RWORK && OPENBLAS_NUM_THREADS=1 R_LIBS_USER='$RLIB' \
    Rscript dev/profile-rescore-run.R --mode=aggregate --out-dir='$OUTDIR'"
  echo "[totoro] pull results:  rsync -az -e 'ssh -o ControlPath=$SOCK -o ControlMaster=no' \\"
  echo "  $REMOTE:$OUTDIR/rescore-summary.rds ~/gllvm_work/profile_rescore/"
  exit 0
fi

echo "Unknown stage: $STAGE (use: smoke | grid | aggregate)" >&2
exit 1
