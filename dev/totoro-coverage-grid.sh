#!/usr/bin/env bash
# =============================================================================
# A2 — turnkey Totoro run of the Design-66 n_sim=2000 coverage grid.
#
# WRITTEN 2026-07-13 (solo Claude) as headline prep. It CANNOT run until a
# Totoro ControlMaster socket exists (Cisco Duo MFA is required and cannot be
# done headless). To create the socket, from an interactive terminal:
#     ssh totoro     # approve the Duo push; leave it / it seeds the socket
# then run this script. It attaches over the EXISTING socket (no new MFA).
#
# Discipline (brain totoro-setup runbook + D-50):
#   * <= 100 cores (shared lab server) -> CORES=96 default.
#   * R library on /project (persistent), NEVER /scratch (60-day purge).
#   * OPENBLAS_NUM_THREADS=1 (avoid nested BLAS threads under parallel R).
#   * Compute on Totoro, results stay LOCAL. Never GitHub Actions (D-50).
#   * Core families ONLY: gaussian, nbinom2, binomial_probit. Ordinal EXCLUDED.
#   * Gate: pilot must PASS_TO_SCALE (pilot_scale_gate) before the n_sim=2000 grid.
# =============================================================================
set -euo pipefail

# ControlMaster socket: real path is ~/.ssh/cm-<host>:22 (cm- PREFIX, NOT a cm/
# subdirectory -- the cm/ form was wrong and false-failed preflight). Resolve it
# robustly, with the canonical name as a fallback.
SOCK="$(ls "$HOME"/.ssh/cm-*totoro* 2>/dev/null | head -1)"
SOCK="${SOCK:-$HOME/.ssh/cm-snakagaw@totoro.biology.ualberta.ca:22}"
REMOTE="totoro"
RWORK="\$HOME/gllvm_work/gllvmTMB"        # remote work dir (expanded remotely)
RLIB='/home/snakagaw/gllvm_work/Rlib'    # persistent R library on Totoro (home; NOT DRAC /project)
CORES="${CORES:-96}"
NSIM="${NSIM:-2000}"
STAGE="${1:-smoke}"                        # smoke | grid  (default: smoke first)

ssh_t() { ssh -o ControlPath="$SOCK" -o ControlMaster=no "$REMOTE" "$@"; }

# --- 0. Preflight: the socket MUST exist (no headless MFA) --------------------
if [ ! -S "$SOCK" ]; then
  echo "ERROR: no Totoro ControlMaster socket at $SOCK." >&2
  echo "  Open one first (interactive):  ssh totoro   # approve Duo, keep it alive" >&2
  exit 1
fi
echo "[totoro] socket OK; host: $(ssh_t hostname); nproc: $(ssh_t nproc)"

# --- 1. Deploy the package + harness (rsync over the socket) ------------------
echo "[totoro] rsync package + dev harness -> $RWORK"
rsync -az --delete \
  -e "ssh -o ControlPath=$SOCK -o ControlMaster=no" \
  --exclude '.git' --exclude '.claude' --exclude 'dev/m3-pilot-results' \
  --exclude 'results' --exclude '*.o' --exclude '*.so' \
  ./ "$REMOTE:gllvm_work/gllvmTMB/"

# --- 2. Ensure R deps + build the package on Totoro (one-time-ish) ------------
ssh_t "mkdir -p '$RLIB' && cd $RWORK && \
  OPENBLAS_NUM_THREADS=1 R_LIBS_USER='$RLIB' Rscript -e '
    if (!requireNamespace(\"TMB\", quietly=TRUE)) install.packages(\"TMB\", repos=\"https://cloud.r-project.org\")
    if (!requireNamespace(\"devtools\", quietly=TRUE)) install.packages(\"devtools\", repos=\"https://cloud.r-project.org\")
    suppressMessages(devtools::document())
  ' && OPENBLAS_NUM_THREADS=1 R_LIBS_USER='$RLIB' R CMD INSTALL --no-multiarch ."

# --- 3a. SMOKE stage: immutable-chunk smoke ladder (fast; MUST pass first) -----
if [ "$STAGE" = "smoke" ]; then
  echo "[totoro] SMOKE ladder (audit-mini -> chunk -> chunk-audit -> chunk-aggregate)"
  ssh_t "cd $RWORK && OPENBLAS_NUM_THREADS=1 R_LIBS_USER='$RLIB' \
    NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 \
    Rscript dev/power-pilot-run.R --mode=audit-mini-run --seed-base=1"
  echo "[totoro] smoke complete. If clean, re-run:  CORES=$CORES NSIM=$NSIM $0 grid"
  exit 0
fi

# --- 3b. GRID stage: n_sim=2000 core grid, sharded across CORES ---------------
# Core families = gaussian, nbinom2, binomial_probit (ordinal excluded, Repair #2).
# Shards run in parallel (<= CORES); each shard is one immutable chunk.
echo "[totoro] Phase-2 grid: n_sim=$NSIM, core families, $CORES shards"
NSHARDS="$CORES"
ssh_t "cd $RWORK && seq 1 $NSHARDS | \
  OPENBLAS_NUM_THREADS=1 R_LIBS_USER='$RLIB' NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 \
  xargs -P $CORES -I {} Rscript dev/power-pilot-run.R \
    --mode=chunk --shard={} --n-shards=$NSHARDS --seed-base=1"

echo "[totoro] chunk-audit + chunk-aggregate"
ssh_t "cd $RWORK && OPENBLAS_NUM_THREADS=1 R_LIBS_USER='$RLIB' \
  Rscript dev/power-pilot-run.R --mode=chunk-audit && \
  Rscript dev/power-pilot-run.R --mode=chunk-aggregate"

# --- 4. The calibrated verdict (pilot_scale_gate on the aggregate) ------------
echo "[totoro] pilot_scale_gate verdict on the n_sim=$NSIM core grid"
ssh_t "cd $RWORK && OPENBLAS_NUM_THREADS=1 R_LIBS_USER='$RLIB' NOT_CRAN=true \
  Rscript -e 'source(\"dev/m3-grid.R\"); source(\"dev/m3-pilot-report.R\");
    ad <- pilot_chunk_aggregate_results_dirs(\"dev/m3-pilot-results\");
    g <- pilot_scale_gate_eval(pilot_collect_chunk_aggregates());
    cat(\"CORE-GRID VERDICT:\", g\$verdict, \"\\n\"); print(g\$reasons);
    print(g\$cells[, c(\"family\",\"signal\",\"coverage_primary\",\"coverage_mcse\",\"ci_missing_rate\",\"gate_health_ok\",\"one_sided_miss_share\",\"gate_miss_ok\")])'"

# --- 5. Pull results back LOCAL (D-50: outputs stay off any cloud) -------------
echo "[totoro] rsync results back -> ./results/totoro-coverage-grid/"
mkdir -p results/totoro-coverage-grid
rsync -az -e "ssh -o ControlPath=$SOCK -o ControlMaster=no" \
  "$REMOTE:gllvm_work/gllvmTMB/dev/m3-pilot-results/" results/totoro-coverage-grid/

echo "[totoro] DONE. Adversarial coverage verdict (Fisher/Efron/Gelman, default NOT-DONE)"
echo "         is the next step before any widget/NEWS flip (A3)."
