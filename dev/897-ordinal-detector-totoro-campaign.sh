#!/usr/bin/env bash
# #897 ordinal-probit development campaign.  The held-out campaign is a
# separate launch after this evidence selects and freezes a detector rule.
set -euo pipefail

readonly TOTORO_CORE_CAP=150
readonly NWORKERS="${GLLVM897_WORKERS:-40}"
readonly REMOTE_ROOT='~/gllvm_work/897-ordinal-detector-admission'
readonly REMOTE_LIB='~/gllvm_work/R-897-lib'
readonly REMOTE_FALLBACK_LIB='~/R/x86_64-pc-linux-gnu-library/4.5'
readonly PHASE="${GLLVM897_PHASE:-development}"
readonly SEEDS="${GLLVM897_SEEDS:-1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}"

if [[ "${GLLVM897_CONFIRM:-}" != "YES" ]]; then
  echo 'Refusing #897 campaign: set GLLVM897_CONFIRM=YES after approval.' >&2
  exit 2
fi
if (( NWORKERS > TOTORO_CORE_CAP )); then
  echo "NWORKERS=$NWORKERS exceeds Totoro cap $TOTORO_CORE_CAP" >&2
  exit 2
fi

repo_root=$(git rev-parse --show-toplevel)
commit=$(git rev-parse HEAD)
remote_shell="set -euo pipefail
mkdir -p $REMOTE_ROOT $REMOTE_LIB ~/gllvm_work/results/897-ordinal-detector
cd $REMOTE_ROOT
R_LIBS_USER=$REMOTE_LIB:$REMOTE_FALLBACK_LIB R CMD INSTALL -l $REMOTE_LIB --no-multiarch --with-keep.source . > $REMOTE_ROOT/campaign-$PHASE-install.log 2>&1
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \\
  R_LIBS_USER=$REMOTE_LIB:$REMOTE_FALLBACK_LIB GLLVM897_COMMIT=$commit \\
  GLLVM897_OUT=~/gllvm_work/results/897-ordinal-detector \\
  GLLVM897_PHASE=$PHASE GLLVM897_SEEDS=$SEEDS GLLVM897_WORKERS=$NWORKERS \\
  /usr/bin/time -v Rscript --vanilla dev/897-ordinal-detector-admission.R --campaign \\
  > $REMOTE_ROOT/campaign-$PHASE-run.log 2>&1
sha256sum $REMOTE_ROOT/campaign-$PHASE-install.log $REMOTE_ROOT/campaign-$PHASE-run.log \\
  ~/gllvm_work/results/897-ordinal-detector/campaign-$PHASE-{cells,provenance,manifest}.csv \\
  ~/gllvm_work/results/897-ordinal-detector/campaign-$PHASE-receipt.rds \\
  > ~/gllvm_work/results/897-ordinal-detector/campaign-$PHASE-sha256.txt"

echo "#897 Totoro $PHASE campaign: commit=$commit workers=$NWORKERS cap=$TOTORO_CORE_CAP seeds=$SEEDS"
rsync -az --exclude='.git' --exclude='.Rproj.user' "$repo_root/" "totoro:$REMOTE_ROOT/"
ssh -o BatchMode=yes -o ConnectTimeout=20 totoro "bash -lc $(printf '%q' "$remote_shell")"
