#!/usr/bin/env bash
# Totoro T1 panel: 1-rep smoke on T1-anchor-n40-T8, then 4x200 if PASS.
# Hard OUT: no public se; no undraft #1077; no T* freeze; no git add -A.
# D-143 courtesy: this job uses 16 cores (GOAL cap), never 150.
set -euo pipefail

readonly TOTORO_CORE_CAP=150
readonly T1_CORE_CAP=16
readonly DEPLOY="${HOME}/gllvmtmb-mspl-forkB-t1-20260818"
readonly RLIB="${DEPLOY}/.Rlib-campaign"
readonly OUT="${DEPLOY}/docs/dev-log/research"
readonly SMOKE_CELL="${SMOKE_CELL:-T1-anchor-n40-T8}"
readonly SMOKE_SEED="${SMOKE_SEED:-20260830}"
readonly NWORKERS="${T1_WORKERS:-$T1_CORE_CAP}"
readonly NREP="${T1_NREP:-200}"

if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  echo "refusing: D-50 forbids campaign launch on GitHub Actions." >&2
  exit 2
fi
if ! [[ "$NWORKERS" =~ ^[0-9]+$ ]] || (( NWORKERS < 1 || NWORKERS > T1_CORE_CAP || NWORKERS > TOTORO_CORE_CAP )); then
  echo "NWORKERS=$NWORKERS exceeds the T1 ${T1_CORE_CAP}-core / D-143 ${TOTORO_CORE_CAP}-core cap." >&2
  exit 2
fi

echo "=== host ==="
hostname
cat /proc/loadavg
date -u +"utc=%Y-%m-%dT%H:%M:%SZ"
git -C "${DEPLOY}" rev-parse --short HEAD
test -f "${DEPLOY}/dev/mspl-forkB-t1-smoke.R"
test -d "${RLIB}/gllvmTMB"
mkdir -p "${OUT}"

export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 NOT_CRAN=true

SMOKE_RDS="${OUT}/2026-08-18-mspl-forkB-t1-k2-${SMOKE_CELL}-${SMOKE_SEED}-n1.rds"
SMOKE_LOG="${OUT}/2026-08-18-mspl-forkB-t1-k2-${SMOKE_CELL}-${SMOKE_SEED}-n1.log"

echo "=== 1-rep smoke ${SMOKE_CELL} seed ${SMOKE_SEED} ==="
cd "${DEPLOY}"
Rscript --vanilla dev/mspl-forkB-t1-smoke.R \
  --n_rep=1 \
  --cell="${SMOKE_CELL}" \
  --seed_base="${SMOKE_SEED}" \
  --lib="${RLIB}" \
  --out="${OUT}" \
  | tee "${SMOKE_LOG}"

if [[ ! -s "${SMOKE_RDS}" ]]; then
  echo "ABORT: smoke RDS missing or empty: ${SMOKE_RDS}" >&2
  exit 3
fi
if [[ ! -s "${SMOKE_LOG}" ]]; then
  echo "ABORT: smoke LOG missing or empty: ${SMOKE_LOG}" >&2
  exit 3
fi
if ! grep -q 'smoke_ok: TRUE' "${SMOKE_LOG}"; then
  echo "ABORT: smoke_ok is not TRUE" >&2
  exit 3
fi
echo "SMOKE_PASS rds_bytes=$(wc -c < "${SMOKE_RDS}") log_bytes=$(wc -c < "${SMOKE_LOG}")"

if [[ "${1:-}" == "--smoke-only" ]]; then
  echo "smoke-only; not launching panel"
  exit 0
fi

echo "=== T1 panel n_rep=${NREP} workers=${NWORKERS} ==="
Rscript --vanilla dev/mspl-forkB-t1-smoke.R \
  --panel=t1 \
  --n_rep="${NREP}" \
  --workers="${NWORKERS}" \
  --lib="${RLIB}" \
  --out="${OUT}" \
  | tee "${OUT}/2026-08-18-mspl-forkB-t1-panel.log"

if [[ ! -s "${OUT}/2026-08-18-mspl-forkB-t1-panel.rds" ]]; then
  echo "ABORT: panel RDS missing or empty" >&2
  exit 3
fi
echo "PANEL_DONE rds_bytes=$(wc -c < "${OUT}/2026-08-18-mspl-forkB-t1-panel.rds")"
