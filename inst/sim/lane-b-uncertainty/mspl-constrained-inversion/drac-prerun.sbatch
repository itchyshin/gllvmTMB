#!/usr/bin/env bash
#SBATCH --account=def-snakagaw_cpu
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00

## Exact one-outer-per-case constrained-inversion pre-run.  The caller must
## bind the staged campaign root, native runtime archive, source archive, and
## immutable 12-key pre-run map through the existing MSPL launcher contract.
set -euo pipefail

die() { printf '%s\n' "[mspl-constrained-inversion] $*" >&2; exit 2; }

import_job_env() {
  local file="$1" line key value
  [[ "$file" == /* && -f "$file" ]] || die "Invalid MSPL_COVERAGE_JOB_ENV."
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^(MSPL_COVERAGE_[A-Z0-9_]+)=([A-Za-z0-9._/@:+,-]*)$ ]] || die "Unsafe job environment record."
    key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
    case "$key" in
      MSPL_COVERAGE_ROOT|MSPL_COVERAGE_LAUNCHER_DIR|MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256|MSPL_COVERAGE_HELPER_SHA256|MSPL_COVERAGE_RUNTIME_ARCHIVE|MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256|MSPL_COVERAGE_CLUSTER|MSPL_COVERAGE_CAMPAIGN_ID|MSPL_COVERAGE_SOURCE_SHA|MSPL_COVERAGE_MANIFEST_SHA256|MSPL_COVERAGE_SOURCE_ARCHIVE|MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256|MSPL_COVERAGE_SOURCE_BUNDLE|MSPL_COVERAGE_SOURCE_BUNDLE_SHA256|MSPL_COVERAGE_STDENV_MODULE|MSPL_COVERAGE_COMPILER_MODULE|MSPL_COVERAGE_R_MODULE|MSPL_COVERAGE_EXTRA_MODULES) ;;
      *) die "Unknown job environment key: $key" ;;
    esac
    [[ -z "${!key+x}" ]] || die "Duplicate job environment key: $key"
    printf -v "$key" '%s' "$value"; export "$key"
  done < "$file"
}

[[ -z "${MSPL_COVERAGE_JOB_ENV:-}" ]] || import_job_env "$MSPL_COVERAGE_JOB_ENV"
for required in MSPL_COVERAGE_ROOT MSPL_COVERAGE_LAUNCHER_DIR MSPL_COVERAGE_HELPER_SHA256 MSPL_COVERAGE_RUNTIME_ARCHIVE MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256 MSPL_COVERAGE_CLUSTER MSPL_COVERAGE_SOURCE_SHA MSPL_COVERAGE_MANIFEST_SHA256 MSPL_CONSTRAINED_INVERSION_PRERUN_MAP_SHA256; do
  [[ -n "${!required:-}" ]] || die "Missing required binding: $required"
done
[[ "$MSPL_COVERAGE_ROOT" == /project/* ]] || die "Campaign root must be explicit /project storage."
[[ "$MSPL_CONSTRAINED_INVERSION_PRERUN_MAP_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "Invalid pre-run map SHA-256."

HELPER="$MSPL_COVERAGE_LAUNCHER_DIR/lib-mspl-coverage.sh"
[[ -f "$HELPER" ]] || die "Missing staged launcher helper."
[[ "$(sha256sum "$HELPER" | awk '{print $1}')" == "$MSPL_COVERAGE_HELPER_SHA256" ]] || die "Launcher helper hash disagrees."
# shellcheck source=/dev/null
source "$HELPER"
mspl_validate_runtime_inputs
mspl_validate_manifest_binding
MAP="$MSPL_COVERAGE_ROOT/pre-run-array-map.tsv"
mspl_verify_hash "$MAP" "$MSPL_CONSTRAINED_INVERSION_PRERUN_MAP_SHA256"
mspl_load_modules
mspl_stage_runtime

TASK_ID="${SLURM_ARRAY_TASK_ID:-}"
[[ "$TASK_ID" =~ ^([1-9]|1[0-2])$ ]] || die "Pre-run task ID must be 1..12."
ROW="$(awk -F '\t' -v id="$TASK_ID" '$1 == id {print; found=1; exit} END {exit found ? 0 : 2}' "$MAP")" || die "No frozen map row for task $TASK_ID."
IFS=$'\t' read -r INDEX CASE_ID SHARD_ID <<< "$ROW"
[[ "$INDEX" == "$TASK_ID" && "$SHARD_ID" == 1 && "$CASE_ID" =~ ^C[0-9]{3}$ ]] || die "Malformed pre-run map row."
ASSIGNED="$(mspl_manifest_case_field "$MSPL_COVERAGE_ROOT/manifest.csv" "$CASE_ID" assigned_cluster)" || die "Could not resolve case cluster."
[[ "$ASSIGNED" == "$MSPL_COVERAGE_CLUSTER" ]] || die "Case $CASE_ID is assigned to $ASSIGNED, not $MSPL_COVERAGE_CLUSTER."

RUNNER="inst/sim/lane-b-uncertainty/run-mspl-constrained-inversion-calibration.R"
cd "$MSPL_COVERAGE_PACKAGE_DIR"
Rscript --vanilla "$RUNNER" run-shard --root "$MSPL_COVERAGE_LOCAL_ROOT" --case-id "$CASE_ID" --shard-id 1 --cluster "$MSPL_COVERAGE_CLUSTER"
LOCAL="$MSPL_COVERAGE_LOCAL_ROOT/shards/${CASE_ID}-shard-0001.rds"
DESTINATION="$MSPL_COVERAGE_ROOT/shards/${CASE_ID}-shard-0001.rds"
[[ -f "$LOCAL" && ! -e "$DESTINATION" ]] || die "Refusing absent or replacement shard publication."
cp "$LOCAL" "$DESTINATION.tmp-${SLURM_JOB_ID:-manual}-${TASK_ID}"
mv "$DESTINATION.tmp-${SLURM_JOB_ID:-manual}-${TASK_ID}" "$DESTINATION"
printf '%s\n' "$DESTINATION"
