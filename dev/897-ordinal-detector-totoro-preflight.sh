#!/usr/bin/env bash
# #897 Totoro timing preflight.  This launcher is intentionally inert unless
# GLLVM897_CONFIRM=YES is supplied after an explicit maintainer approval.
set -euo pipefail

readonly TOTORO_CORE_CAP=150
readonly NWORKERS=1
readonly REMOTE_ROOT='~/gllvm_work/897-ordinal-detector-admission'
readonly REMOTE_LIB='~/gllvm_work/R-897-lib'

if [[ "${GLLVM897_CONFIRM:-}" != "YES" ]]; then
  cat >&2 <<'EOF'
Refusing to start the #897 Totoro preflight.
Set GLLVM897_CONFIRM=YES only after explicit approval for this four-cell run.
EOF
  exit 2
fi

if (( NWORKERS > TOTORO_CORE_CAP )); then
  echo "NWORKERS=$NWORKERS exceeds Totoro's $TOTORO_CORE_CAP-core cap." >&2
  exit 2
fi

repo_root=$(git rev-parse --show-toplevel)
commit=$(git rev-parse HEAD)
remote_shell="set -euo pipefail
mkdir -p $REMOTE_ROOT $REMOTE_LIB
printf '%s\\n' '$commit' > $REMOTE_ROOT/COMMIT
cd $REMOTE_ROOT
R_LIBS_USER=$REMOTE_LIB R CMD INSTALL -l $REMOTE_LIB --no-multiarch --with-keep.source . > $REMOTE_ROOT/preflight-install.log 2>&1
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \\
  R_LIBS_USER=$REMOTE_LIB GLLVM897_COMMIT=$commit \\
  GLLVM897_OUT=~/gllvm_work/results/897-ordinal-detector \\
  /usr/bin/time -v Rscript --vanilla dev/897-ordinal-detector-admission.R --totoro-preflight > $REMOTE_ROOT/preflight-run.log 2>&1
sha256sum $REMOTE_ROOT/preflight-install.log $REMOTE_ROOT/preflight-run.log \\
  ~/gllvm_work/results/897-ordinal-detector/totoro-preflight-{cells,provenance,manifest}.csv \\
  ~/gllvm_work/results/897-ordinal-detector/totoro-preflight-receipt.rds \\
  > ~/gllvm_work/results/897-ordinal-detector/totoro-preflight-sha256.txt"

echo "#897 Totoro preflight: commit=$commit workers=$NWORKERS cap=$TOTORO_CORE_CAP"
rsync -az --exclude='.git' --exclude='.Rproj.user' "$repo_root/" "totoro:$REMOTE_ROOT/"
ssh -o BatchMode=yes -o ConnectTimeout=20 totoro "bash -lc $(printf '%q' "$remote_shell")"
