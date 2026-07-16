#!/usr/bin/env bash
## Turnkey Totoro launch for the Model A coverage campaigns (Lane B, 2026-07-16).
## PREREQ (human, once): open the ControlMaster socket with MFA:  ssh totoro
## Then run this from the Mac:  bash dev/totoro-launch-modelA-coverage.sh
## Doctrine: smoke-first (D-50: Totoro/DRAC, NOT GitHub Actions); cap <=96 cores (shared lab server).
set -euo pipefail
# ControlMaster socket: real path uses a `cm-` prefix (NOT a cm/ subdir). Find robustly.
SOCK="$(ls "$HOME"/.ssh/cm-*totoro* 2>/dev/null | head -1)"
: "${SOCK:=$HOME/.ssh/cm-snakagaw@totoro.biology.ualberta.ca:22}"
SSH=(ssh -o ControlPath="$SOCK" -o ControlMaster=no totoro)
REMOTE=~/gllvm_work/lvb-modelA-extend
CORES=90            # <=96 per the Totoro shared-server rule
REPS_TOTAL=500      # production bar per cell
REPS_PER_TASK=5     # => 100 tasks/cell

if [ ! -S "$SOCK" ]; then echo "NO Totoro socket. Run 'ssh totoro' (Duo MFA) first."; exit 1; fi
echo "== 0. connectivity =="; "${SSH[@]}" 'echo OK; nproc'

echo "== 1. sync worktree (harnesses + package source) =="
rsync -az --delete -e "ssh -o ControlPath=$SOCK -o ControlMaster=no" \
  --exclude results --exclude '.git' --exclude '*.o' --exclude '*.so' \
  "$HOME/gllvm_work/lvb-modelA-extend/" "totoro:$REMOTE/"

echo "== 2. ensure gllvmTMB installed on Totoro (compiles TMB once) =="
"${SSH[@]}" "cd $REMOTE && Rscript -e 'if(!requireNamespace(\"gllvmTMB\",quietly=TRUE)) install.packages(\".\",repos=NULL,type=\"source\"); cat(as.character(packageVersion(\"gllvmTMB\")))'"

echo "== 3. SMOKE-FIRST (1 task, 3 reps per harness/cell) — abort if empty/NA =="
for spec in "modelA-rank2-coverage.R gauss-S200-K2-hard" \
            "modelA-source-coverage.R kernel-S200-K2" \
            "modelA-source-coverage.R animal-S200-K2"; do
  set -- $spec
  "${SSH[@]}" "cd $REMOTE && OPENBLAS_NUM_THREADS=1 Rscript dev/$1 run $2 999 3"
done
echo ">> Inspect the smoke lines above: converged>0 and prof_ci>0 REQUIRED before scaling."
read -p "Smoke green? launch full campaigns? [y/N] " ok; [ "$ok" = y ] || { echo "aborted"; exit 0; }

echo "== 4. launch full campaigns (xargs -P $CORES, $REPS_TOTAL reps/cell) =="
launch () { # $1=script $2=cell
  "${SSH[@]}" "cd $REMOTE && seq 1 $((REPS_TOTAL/REPS_PER_TASK)) | \
    OPENBLAS_NUM_THREADS=1 xargs -P $CORES -I{} Rscript dev/$1 run $2 {} $REPS_PER_TASK \
    > results/$2.launch.log 2>&1 &"
}
launch modelA-rank2-coverage.R  gauss-S200-K2-hard
launch modelA-source-coverage.R kernel-S200-K2
launch modelA-source-coverage.R animal-S200-K2
# add modelA-poisson-coverage.R once the Poisson admission lands
echo ">> launched. Monitor: ssh totoro 'ls \$REMOTE/results/*/*.csv | wc -l'"
echo ">> Summarise when done: ssh totoro 'cd \$REMOTE && Rscript dev/modelA-rank2-coverage.R summarise results/modelA-rank2-coverage'"
