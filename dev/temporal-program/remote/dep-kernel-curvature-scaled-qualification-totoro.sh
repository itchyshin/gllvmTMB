#!/usr/bin/env bash
# Run the immutable nine-cell curvature-scaled temporal dep-kernel qualification.
set -euo pipefail

: "${GLLVM_TMB_COMMIT:?set GLLVM_TMB_COMMIT to the immutable execution commit}"
readonly ROOT="${HOME}/gllvmtmb-temporal-dep-kernel-scaled-${GLLVM_TMB_COMMIT:0:12}"
readonly RESULT_DIR="${ROOT}/dev/temporal-program/results/curvature-scaled-qualification-20260912"
readonly LOG_DIR="${RESULT_DIR}/totoro-logs"
readonly WORKERS=9
readonly TOTORO_CORE_CAP=150

[[ ${WORKERS} -le ${TOTORO_CORE_CAP} ]] || { echo "worker count exceeds Totoro's 150-core cap" >&2; exit 2; }
[[ "${TEMPORAL_DEP_KERNEL_SCALED_TOTORO_APPROVED:-}" == "YES" ]] || {
  echo "Refusing run without TEMPORAL_DEP_KERNEL_SCALED_TOTORO_APPROVED=YES." >&2; exit 2;
}
if [[ ! -d "${ROOT}/.git" ]]; then
  git init "${ROOT}"
  git -C "${ROOT}" remote add origin git@github.com:itchyshin/gllvmTMB.git
fi
cd "${ROOT}"
git fetch --no-tags origin "${GLLVM_TMB_COMMIT}"
git checkout --detach FETCH_HEAD
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || {
  echo "staged checkout has tracked changes" >&2; exit 2;
}
[[ "$(git rev-parse HEAD)" == "${GLLVM_TMB_COMMIT}" ]] || { echo "wrong staged commit" >&2; exit 2; }
mkdir -p "${RESULT_DIR}" "${LOG_DIR}"
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); cat("DEP_KERNEL_SCALED_TOTORO_BUILD_PASS\\n")' >"${LOG_DIR}/build.log" 2>&1

cells=("-0.4 2609371" "-0.4 2609372" "-0.4 2609373" "0 2609371" "0 2609372" "0 2609373" "0.6 2609371" "0.6 2609372" "0.6 2609373")
pids=()
for cell in "${cells[@]}"; do
  read -r phi seed <<<"${cell}"
  receipt="${RESULT_DIR}/dep-kernel-scaled-phi${phi}-seed${seed}.rds"
  log="${LOG_DIR}/phi${phi}-seed${seed}.log"
  [[ ! -e "${receipt}" ]] || { echo "refusing to overwrite ${receipt}" >&2; exit 2; }
  Rscript --vanilla dev/temporal-program/run-dep-kernel-curvature-scaled-qualification.R --phi="${phi}" --seed="${seed}" --output="${receipt}" >"${log}" 2>&1 &
  pids+=("$!")
done
status=0
for pid in "${pids[@]}"; do wait "${pid}" || status=1; done
for cell in "${cells[@]}"; do
  read -r phi seed <<<"${cell}"
  receipt="${RESULT_DIR}/dep-kernel-scaled-phi${phi}-seed${seed}.rds"
  [[ -s "${receipt}" ]] || { echo "missing retained receipt phi=${phi} seed=${seed}" >&2; status=1; continue; }
  Rscript --vanilla -e 'x <- readRDS(commandArgs(TRUE)[[1L]]); quit(status = as.integer(!identical(x$terminal, "success") || !isTRUE(x$adjudication$accepted)))' "${receipt}" || status=1
done
exit "${status}"
