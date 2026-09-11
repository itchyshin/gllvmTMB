#!/usr/bin/env bash
set -euo pipefail

readonly COMMIT="${GLLVM_TMB_COMMIT:?set GLLVM_TMB_COMMIT to the immutable execution commit}"
readonly ROOT="${HOME}/gllvmtmb-temporal-corrected-scale-${COMMIT:0:12}"
readonly LOG_DIR="${ROOT}/dev/temporal-program/results/corrected-scale-20260911/totoro-logs"
readonly WORKERS=8
readonly TOTORO_CORE_CAP=150

[[ ${WORKERS} -le ${TOTORO_CORE_CAP} ]] || {
  echo "worker count exceeds Totoro's 150-core cap" >&2
  exit 2
}

if [[ ! -d "${ROOT}/.git" ]]; then
  git clone https://github.com/itchyshin/gllvmTMB.git "${ROOT}"
fi
cd "${ROOT}"
git fetch origin
git checkout --detach "${COMMIT}"
[[ -z "$(git status --porcelain)" ]] || { echo "staged checkout is dirty" >&2; exit 2; }

mkdir -p "${LOG_DIR}"
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); cat("DEP_SPATIAL_TOTORO_BUILD_PASS\n")' \
  >"${LOG_DIR}/build.log" 2>&1

pids=()
for index in {2..9}; do
  env DEP_SPATIAL_CAMPAIGN=corrected-scale-20260911 DEP_SPATIAL_ONE="${index}" \
    Rscript --vanilla dev/temporal-program/run-dep-spatial-recovery.R \
    >"${LOG_DIR}/attempt-${index}.log" 2>&1 &
  pids+=("$!")
done

status=0
for pid in "${pids[@]}"; do
  wait "${pid}" || status=1
done

for index in {2..9}; do
  result="dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-$(printf '%02d' "${index}").csv"
  phase="${result%.csv}-phase.csv"
  [[ -f "${result}" && -f "${phase}" ]] || { echo "missing retained receipt for ${index}" >&2; status=1; }
done

exit "${status}"
