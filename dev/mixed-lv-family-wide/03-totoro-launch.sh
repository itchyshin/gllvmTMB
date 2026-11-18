#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 ABSOLUTE_SOURCE_SNAPSHOT pure_recovery|calibration" >&2
  exit 64
fi

readonly SOURCE_SNAPSHOT="$1"
readonly CAMPAIGN_KIND="$2"
readonly N_WORKERS=40
readonly TOTORO_CORE_CAP=150
readonly MAX_WALL_SECONDS=1800
readonly TERM_GRACE_SECONDS=10

case "${CAMPAIGN_KIND}" in
  pure_recovery)
    readonly OUTPUT_DIR="${SOURCE_SNAPSHOT}/artifacts/mixed-lv-pure-r200-recovery"
    ;;
  calibration)
    readonly OUTPUT_DIR="${SOURCE_SNAPSHOT}/artifacts/mixed-lv-r500-calibration"
    ;;
  *)
    echo "campaign must be pure_recovery or calibration" >&2
    exit 64
    ;;
esac

if [[ ! -d "${SOURCE_SNAPSHOT}/.git" ]]; then
  echo "source snapshot must be a self-contained git checkout" >&2
  exit 65
fi
if ! command -v setsid >/dev/null 2>&1; then
  echo "setsid is required for killable campaign process-group isolation" >&2
  exit 69
fi

available_cores="$(nproc)"
safe_local_cap=$((available_cores - 4))
if (( N_WORKERS > TOTORO_CORE_CAP || N_WORKERS > safe_local_cap )); then
  echo "40-worker request exceeds the Totoro or live-host safety cap" >&2
  exit 66
fi
if [[ -e "${OUTPUT_DIR}" ]]; then
  echo "refusing to overwrite an existing retained campaign directory" >&2
  exit 67
fi

mkdir -p "${OUTPUT_DIR}/attempts" "${OUTPUT_DIR}/started" "${OUTPUT_DIR}/logs"
cd "${SOURCE_SNAPSHOT}"

export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export GLLVMTMB_MIXED_LV_RUN=true
unset GLLVMTMB_MIXED_LV_PACKAGE_PRELOADED

supervisor_pid=""
watchdog_pid=""
cleanup_campaign() {
  if [[ -n "${watchdog_pid}" ]] && kill -0 "${watchdog_pid}" 2>/dev/null; then
    kill -TERM "${watchdog_pid}" 2>/dev/null || true
  fi
  if [[ -n "${supervisor_pid}" ]] && kill -0 "${supervisor_pid}" 2>/dev/null; then
    kill -TERM -- "-${supervisor_pid}" 2>/dev/null || true
  fi
}
trap cleanup_campaign EXIT INT TERM

setsid Rscript --vanilla \
  dev/mixed-lv-family-wide/05-totoro-run.R \
  "${OUTPUT_DIR}" "${N_WORKERS}" "${CAMPAIGN_KIND}" \
  >"${OUTPUT_DIR}/logs/supervisor.log" 2>&1 &
supervisor_pid="$!"

(
  sleep "${MAX_WALL_SECONDS}"
  if kill -0 "${supervisor_pid}" 2>/dev/null; then
    date -u '+%Y-%m-%dT%H:%M:%SZ' >"${OUTPUT_DIR}/logs/overrun-status"
    kill -TERM -- "-${supervisor_pid}" 2>/dev/null || true
    sleep "${TERM_GRACE_SECONDS}"
    kill -KILL -- "-${supervisor_pid}" 2>/dev/null || true
  fi
) &
watchdog_pid="$!"

supervisor_failure=0
if ! wait "${supervisor_pid}"; then
  supervisor_failure=1
fi
supervisor_pid=""
if [[ -f "${OUTPUT_DIR}/logs/overrun-status" ]]; then
  wait "${watchdog_pid}" 2>/dev/null || true
else
  if kill -0 "${watchdog_pid}" 2>/dev/null; then
    kill -TERM "${watchdog_pid}" 2>/dev/null || true
  fi
  wait "${watchdog_pid}" 2>/dev/null || true
fi
watchdog_pid=""

collector_failure=0
if ! Rscript --vanilla \
  dev/mixed-lv-family-wide/06-totoro-collect.R \
  "${OUTPUT_DIR}" "${CAMPAIGN_KIND}"; then
  collector_failure=1
fi

trap - EXIT INT TERM
if [[ -f "${OUTPUT_DIR}/logs/overrun-status" ]]; then
  echo "campaign exceeded 1,800 seconds; partial denominator retained" >&2
  exit 70
fi
if (( supervisor_failure != 0 )); then
  echo "one or more workers exited non-zero; reconciled denominator retained" >&2
  exit 68
fi
if (( collector_failure != 0 )); then
  echo "collector rejected the retained denominator" >&2
  exit 71
fi

echo "campaign complete: ${OUTPUT_DIR}"
