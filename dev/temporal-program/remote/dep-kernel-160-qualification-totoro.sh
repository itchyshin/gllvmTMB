#!/usr/bin/env bash
# Launch the frozen disjoint 160-series temporal dep-kernel qualification.
set -euo pipefail

: "${GLLVM_TMB_COMMIT:?set GLLVM_TMB_COMMIT to the immutable execution commit}"
readonly ROOT="${HOME}/gllvmtmb-temporal-dep-kernel-160-${GLLVM_TMB_COMMIT:0:12}"
readonly RESULT_DIR="${ROOT}/dev/temporal-program/results/qualification-160-20260912"
readonly LOG_DIR="${RESULT_DIR}/totoro-logs"
readonly WORKERS=9
readonly TOTORO_CORE_CAP=150
readonly MODE="${1:-campaign}"

[[ ${WORKERS} -le ${TOTORO_CORE_CAP} ]] || { echo "worker count exceeds Totoro's 150-core cap" >&2; exit 2; }
[[ "${TEMPORAL_DEP_KERNEL_160_TOTORO_APPROVED:-}" == "YES" ]] || {
  echo "Refusing run without TEMPORAL_DEP_KERNEL_160_TOTORO_APPROVED=YES." >&2; exit 2;
}
[[ "${MODE}" == "campaign" || "${MODE}" == "pre-run" ]] || {
  echo "usage: dep-kernel-160-qualification-totoro.sh [pre-run]" >&2; exit 2;
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
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); cat("DEP_KERNEL_160_TOTORO_BUILD_PASS\\n")' >"${LOG_DIR}/build.log" 2>&1

if [[ "${MODE}" == "pre-run" ]]; then
  readonly receipt="${RESULT_DIR}/dep-kernel-160-prerun-seed2609340.rds"
  [[ ! -e "${receipt}" ]] || { echo "refusing to overwrite ${receipt}" >&2; exit 2; }
  Rscript --vanilla dev/temporal-program/run-dep-kernel-160-qualification.R --pre-run --output="${receipt}" >"${LOG_DIR}/prerun-seed2609340.log" 2>&1
  [[ -s "${receipt}" ]] || { echo "missing retained pre-run receipt" >&2; exit 2; }
  exit 0
fi

cells=("-0.4 2609341" "-0.4 2609342" "-0.4 2609343" "0 2609341" "0 2609342" "0 2609343" "0.6 2609341" "0.6 2609342" "0.6 2609343")
pids=()
status=0
for cell in "${cells[@]}"; do
  read -r phi seed <<<"${cell}"
  receipt="${RESULT_DIR}/dep-kernel-160-phi${phi}-seed${seed}.rds"
  log="${LOG_DIR}/phi${phi}-seed${seed}.log"
  [[ ! -e "${receipt}" ]] || { echo "refusing to overwrite ${receipt}" >&2; exit 2; }
  Rscript --vanilla dev/temporal-program/run-dep-kernel-160-qualification.R --phi="${phi}" --seed="${seed}" --output="${receipt}" >"${log}" 2>&1 &
  pids+=("$!")
done
for pid in "${pids[@]}"; do wait "${pid}" || status=1; done
for cell in "${cells[@]}"; do
  read -r phi seed <<<"${cell}"
  [[ -s "${RESULT_DIR}/dep-kernel-160-phi${phi}-seed${seed}.rds" ]] || { echo "missing retained receipt phi=${phi} seed=${seed}" >&2; status=1; }
done
exit "${status}"
