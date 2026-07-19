#!/usr/bin/env bash
set -euo pipefail

# Launch one bounded paired ML/REML funnel stage on Totoro.  The branch must
# already be installed in the remote R library; this script never edits it.
: "${CORES:=64}"
: "${NREPS:=25}"
: "${STAGE:=pilot25}"
: "${OUTDIR:=docs/dev-log/artifacts/reml-paired/${STAGE}}"
: "${N_UNITS:=50}"
: "${N_SHARDS:=$CORES}"
: "${REMOTE_WORKDIR:?Set REMOTE_WORKDIR to the clean remote gllvmTMB checkout}"
: "${R_LIBS_USER:=/home/snakagaw/gllvm_work/Rlib}"

if (( CORES > 100 )); then
  echo "CORES must be <= 100 on shared Totoro" >&2
  exit 2
fi
socket=$(ls "$HOME"/.ssh/cm-*totoro* 2>/dev/null | head -1 || true)
if [[ -z "$socket" ]]; then
  echo "No Totoro ControlMaster socket; ask the maintainer to refresh it once." >&2
  exit 2
fi

remote="cd '$REMOTE_WORKDIR' && package_sha=\$(git rev-parse HEAD) && export OPENBLAS_NUM_THREADS=1 GLLVM_REML_FUNNEL_INSTALLED=1 GLLVM_REML_FUNNEL_PACKAGE_SHA=\$package_sha R_LIBS_USER='$R_LIBS_USER' && mkdir -p '$OUTDIR' && seq 1 '$N_SHARDS' | xargs -P '$CORES' -I{} sh -c '\''start=$(( ({} - 1) * '$NREPS' / '$N_SHARDS' + 1 )); end=$(( {} * '$NREPS' / '$N_SHARDS' )); if [ $start -le $end ]; then Rscript --vanilla dev/reml-paired-funnel.R --mode=run --stage='$STAGE' --rep-start=$start --rep-end=$end --n-units='$N_UNITS' --out-dir='$OUTDIR'; fi'\'' && Rscript --vanilla dev/reml-paired-funnel.R --mode=aggregate --out-dir='$OUTDIR'"
ssh -o ControlPath="$socket" -o ControlMaster=no -o BatchMode=yes -o ConnectTimeout=15 totoro "$remote"
