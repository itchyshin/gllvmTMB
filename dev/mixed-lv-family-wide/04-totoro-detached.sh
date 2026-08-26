#!/usr/bin/env bash
set -uo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 ABSOLUTE_SOURCE_SNAPSHOT pure_recovery|calibration" >&2
  exit 64
fi

readonly SOURCE_SNAPSHOT="$1"
readonly CAMPAIGN_KIND="$2"
readonly STATE_DIR="${SOURCE_SNAPSHOT}/artifacts/${CAMPAIGN_KIND}-launcher"
mkdir -p "${STATE_DIR}"
date -u '+%Y-%m-%dT%H:%M:%SZ' >"${STATE_DIR}/launcher.started-utc"

set +e
bash "${SOURCE_SNAPSHOT}/dev/mixed-lv-family-wide/03-totoro-launch.sh" \
  "${SOURCE_SNAPSHOT}" "${CAMPAIGN_KIND}" \
  >"${STATE_DIR}/launcher.log" 2>&1
status="$?"
set -e

printf '%s\n' "${status}" >"${STATE_DIR}/launcher.exit"
date -u '+%Y-%m-%dT%H:%M:%SZ' >"${STATE_DIR}/launcher.finished-utc"
exit "${status}"
