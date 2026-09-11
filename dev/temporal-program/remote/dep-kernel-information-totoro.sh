#!/usr/bin/env bash
# Prepare or run the frozen six-cell temporal dep-kernel information diagnostic
# on Totoro.  Submission is deliberately refused without a fresh approval
# token.  Each fit is one process and one BLAS/OpenMP thread.
set -euo pipefail

: "${GLLVM_TMB_COMMIT:?set GLLVM_TMB_COMMIT to the immutable execution commit}"
readonly ROOT="${HOME}/gllvmtmb-temporal-information-${GLLVM_TMB_COMMIT:0:12}"
readonly RESULT_DIR="${ROOT}/dev/temporal-program/results/diagnostics/dep-kernel-information-20260911"
readonly LOG_DIR="${RESULT_DIR}/totoro-logs"
readonly WORKERS=6
readonly TOTORO_CORE_CAP=150

[[ ${WORKERS} -le ${TOTORO_CORE_CAP} ]] || {
  echo "worker count exceeds Totoro's 150-core cap" >&2; exit 2;
}
[[ "${TEMPORAL_DEP_KERNEL_INFORMATION_TOTORO_APPROVED:-}" == "YES" ]] || {
  echo "Refusing run without TEMPORAL_DEP_KERNEL_INFORMATION_TOTORO_APPROVED=YES." >&2; exit 2;
}

if [[ ! -d "${ROOT}/.git" ]]; then
  git clone https://github.com/itchyshin/gllvmTMB.git "${ROOT}"
fi
cd "${ROOT}"
git fetch origin
git checkout --detach "${GLLVM_TMB_COMMIT}"
[[ -z "$(git status --porcelain)" ]] || { echo "staged checkout is dirty" >&2; exit 2; }
[[ "$(git rev-parse HEAD)" == "${GLLVM_TMB_COMMIT}" ]] || { echo "wrong staged commit" >&2; exit 2; }

mkdir -p "${RESULT_DIR}" "${LOG_DIR}"
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); cat("DEP_KERNEL_INFORMATION_TOTORO_BUILD_PASS\\n")' \
  >"${LOG_DIR}/build.log" 2>&1

cells=(
  "80 2609221" "80 2609222" "80 2609223"
  "160 2609221" "160 2609222" "160 2609223"
)
pids=()
status=0
for cell in "${cells[@]}"; do
  read -r n_series seed <<<"${cell}"
  receipt="${RESULT_DIR}/dep-kernel-information-n${n_series}-seed${seed}.rds"
  log="${LOG_DIR}/n${n_series}-seed${seed}.log"
  [[ ! -e "${receipt}" ]] || { echo "refusing to overwrite ${receipt}" >&2; exit 2; }
  Rscript --vanilla dev/temporal-program/diagnose-dep-kernel-information.R \
    --n-series="${n_series}" --seed="${seed}" --output="${receipt}" >"${log}" 2>&1 &
  pids+=("$!")
done
for pid in "${pids[@]}"; do wait "${pid}" || status=1; done
for cell in "${cells[@]}"; do
  read -r n_series seed <<<"${cell}"
  receipt="${RESULT_DIR}/dep-kernel-information-n${n_series}-seed${seed}.rds"
  [[ -s "${receipt}" ]] || { echo "missing retained receipt for n=${n_series}, seed=${seed}" >&2; status=1; }
done
exit "${status}"
