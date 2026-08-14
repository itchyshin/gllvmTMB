#!/usr/bin/env bash
#SBATCH --account=def-snakagaw_cpu
#SBATCH --job-name=msplcov_smoke
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G

set -euo pipefail
mspl_bootstrap_die() { echo "[mspl-coverage-bootstrap] $*" >&2; exit 2; }
mspl_import_job_env() {
  local file="$1" line key value records=0 seen="|"
  [[ "$file" == /* && -f "$file" ]] || mspl_bootstrap_die "Invalid MSPL_COVERAGE_JOB_ENV: $file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^(MSPL_COVERAGE_[A-Z0-9_]+)=([A-Za-z0-9._/@:+,-]*)$ ]] ||
      mspl_bootstrap_die "Job environment must contain only safe KEY=VALUE data records."
    key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
    case "$key" in
      MSPL_COVERAGE_ROOT|MSPL_COVERAGE_LAUNCHER_DIR|MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256|MSPL_COVERAGE_HELPER_SHA256|MSPL_COVERAGE_RUNTIME_ARCHIVE|MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256|MSPL_COVERAGE_CLUSTER|MSPL_COVERAGE_CAMPAIGN_ID|MSPL_COVERAGE_SOURCE_SHA|MSPL_COVERAGE_MANIFEST_SHA256|MSPL_COVERAGE_SOURCE_ARCHIVE|MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256|MSPL_COVERAGE_SOURCE_BUNDLE|MSPL_COVERAGE_SOURCE_BUNDLE_SHA256|MSPL_COVERAGE_STDENV_MODULE|MSPL_COVERAGE_COMPILER_MODULE|MSPL_COVERAGE_R_MODULE|MSPL_COVERAGE_EXTRA_MODULES|MSPL_COVERAGE_DEPENDENCY_PACKAGES|MSPL_COVERAGE_ARRAY_MAP|MSPL_COVERAGE_STAGE) ;;
      *) mspl_bootstrap_die "Unknown job-environment key: $key" ;;
    esac
    [[ "$seen" != *"|${key}|"* ]] || mspl_bootstrap_die "Duplicate job-environment key: $key"
    [[ -n "$value" || "$key" == MSPL_COVERAGE_EXTRA_MODULES ]] || mspl_bootstrap_die "Empty job-environment value: $key"
    seen="${seen}${key}|"; records=$((records + 1))
    printf -v "$key" '%s' "$value"
    export "$key"
  done < "$file"
  ((records > 0)) || mspl_bootstrap_die "Job environment is empty."
}
[[ -z "${MSPL_COVERAGE_JOB_ENV:-}" ]] || mspl_import_job_env "$MSPL_COVERAGE_JOB_ENV"
for required in MSPL_COVERAGE_ROOT MSPL_COVERAGE_LAUNCHER_DIR MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256 MSPL_COVERAGE_HELPER_SHA256 MSPL_COVERAGE_CAMPAIGN_ID MSPL_COVERAGE_SOURCE_SHA MSPL_COVERAGE_MANIFEST_SHA256; do
  [[ -n "${!required:-}" ]] || mspl_bootstrap_die "Required job-environment key is unset: $required"
  export "$required"
done
[[ "$MSPL_COVERAGE_LAUNCHER_DIR" == "$MSPL_COVERAGE_ROOT/launcher" ]] ||
  mspl_bootstrap_die "Launcher directory must be the campaign-staged $MSPL_COVERAGE_ROOT/launcher path."
mspl_authenticate_launcher_bundle() {
  local expected_script="$1" ledger="$MSPL_COVERAGE_LAUNCHER_DIR/LAUNCHER-SHA256SUMS" ledger_hash expected_hash observed_hash
  [[ -s "$ledger" ]] || mspl_bootstrap_die "Launcher hash ledger is absent: $ledger"
  awk 'BEGIN { expected[1]="README.md"; expected[2]="contract-self-test.sh"; expected[3]="drac-array.sbatch"; expected[4]="drac-monitor.sh"; expected[5]="drac-setup.sbatch"; expected[6]="drac-smoke.sbatch"; expected[7]="lib-mspl-coverage.sh" }
    { hash=substr($0,1,64); sep=substr($0,65,2); file=substr($0,67); if (length(hash)!=64 || hash !~ /^[0-9a-f]+$/ || sep!="  " || file!=expected[NR]) invalid=1 }
    END { if (NR!=7) invalid=1; exit invalid ? 2 : 0 }' "$ledger" || mspl_bootstrap_die "Launcher hash ledger schema disagrees."
  ledger_hash="$(sha256sum "$ledger" | awk '{print $1}')"
  [[ "$ledger_hash" == "$MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256" ]] || mspl_bootstrap_die "Launcher bundle SHA-256 disagrees."
  (cd "$MSPL_COVERAGE_LAUNCHER_DIR" && sha256sum -c LAUNCHER-SHA256SUMS >/dev/null) || mspl_bootstrap_die "Staged launcher bundle file hash disagrees."
  expected_hash="$(awk -v target="$expected_script" 'substr($0,67)==target {print substr($0,1,64)}' "$ledger")"
  observed_hash="$(sha256sum "${BASH_SOURCE[0]}" | awk '{print $1}')"
  [[ -n "$expected_hash" && "$observed_hash" == "$expected_hash" ]] || mspl_bootstrap_die "Spooled SBATCH script hash disagrees with staged bundle."
}
mspl_authenticate_launcher_bundle drac-smoke.sbatch
MSPL_COVERAGE_HELPER="$MSPL_COVERAGE_LAUNCHER_DIR/lib-mspl-coverage.sh"
[[ -f "$MSPL_COVERAGE_HELPER" ]] || mspl_bootstrap_die "Staged helper is absent: $MSPL_COVERAGE_HELPER"
command -v sha256sum >/dev/null 2>&1 || mspl_bootstrap_die "sha256sum is required."
observed_helper_sha256="$(sha256sum "$MSPL_COVERAGE_HELPER" | awk '{print $1}')"
[[ "$observed_helper_sha256" == "$MSPL_COVERAGE_HELPER_SHA256" ]] ||
  mspl_bootstrap_die "Staged helper SHA-256 disagrees."
# shellcheck source=/dev/null
source "$MSPL_COVERAGE_HELPER"
if [[ "${MSPL_COVERAGE_BOOTSTRAP_ONLY:-false}" == "true" ]]; then
  bash -c ': "${MSPL_COVERAGE_CAMPAIGN_ID:?campaign did not reach child}" "${MSPL_COVERAGE_SOURCE_SHA:?source did not reach child}" "${MSPL_COVERAGE_MANIFEST_SHA256:?manifest hash did not reach child}" "${MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256:?launcher hash did not reach child}"'
  printf 'launcher-bootstrap=PASS\n'
  exit 0
fi

mspl_validate_runtime_inputs
mspl_load_modules
mspl_stage_runtime
MSPL_COVERAGE_STAGE=smoke
export MSPL_COVERAGE_STAGE
TASK_IDENTITY="$(mspl_array_task)" || mspl_die "Smoke array identity validation failed."
IFS=$'\t' read -r CASE_ID SHARD_ID <<< "$TASK_IDENTITY"
RUNNER="${MSPL_COVERAGE_RUNNER:-inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R}"
[[ "$RUNNER" == "inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R" ]] || mspl_die "Only the frozen Gate-0 coverage runner is accepted."
cd "$MSPL_COVERAGE_PACKAGE_DIR"
Rscript --vanilla "$RUNNER" run-shard \
  --root "$MSPL_COVERAGE_LOCAL_ROOT" --case-id "$CASE_ID" --shard-id "$SHARD_ID" \
  --cluster "$MSPL_COVERAGE_CLUSTER"
mspl_publish_rds_shard "$CASE_ID" "$SHARD_ID" \
  "$MSPL_COVERAGE_LOCAL_ROOT/shards/$(printf '%s-shard-%03d.rds' "$CASE_ID" "$SHARD_ID")"
