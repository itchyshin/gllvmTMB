#!/usr/bin/env bash
# Read-only DRAC campaign monitor. It never submits, cancels, or edits jobs.

set -euo pipefail

die() { echo "[mspl-coverage-monitor] $*" >&2; exit 2; }
import_job_env() {
  local file="$1" line key value records=0 seen="|"
  [[ "$file" == /* && -f "$file" ]] || die "Invalid MSPL_COVERAGE_JOB_ENV: $file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^(MSPL_COVERAGE_[A-Z0-9_]+)=([A-Za-z0-9._/@:+,-]*)$ ]] || die "Job environment is not strict safe KEY=VALUE data."
    key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
    case "$key" in
      MSPL_COVERAGE_ROOT|MSPL_COVERAGE_LAUNCHER_DIR|MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256|MSPL_COVERAGE_HELPER_SHA256|MSPL_COVERAGE_RUNTIME_ARCHIVE|MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256|MSPL_COVERAGE_CLUSTER|MSPL_COVERAGE_CAMPAIGN_ID|MSPL_COVERAGE_SOURCE_SHA|MSPL_COVERAGE_MANIFEST_SHA256|MSPL_COVERAGE_SOURCE_ARCHIVE|MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256|MSPL_COVERAGE_SOURCE_BUNDLE|MSPL_COVERAGE_SOURCE_BUNDLE_SHA256|MSPL_COVERAGE_STDENV_MODULE|MSPL_COVERAGE_COMPILER_MODULE|MSPL_COVERAGE_R_MODULE|MSPL_COVERAGE_EXTRA_MODULES|MSPL_COVERAGE_DEPENDENCY_PACKAGES|MSPL_COVERAGE_ARRAY_MAP|MSPL_COVERAGE_STAGE|MSPL_COVERAGE_JOB_ID) ;;
      *) die "Unknown monitor environment key: $key" ;;
    esac
    [[ "$seen" != *"|${key}|"* ]] || die "Duplicate monitor environment key: $key"
    [[ -n "$value" || "$key" == MSPL_COVERAGE_EXTRA_MODULES ]] || die "Empty monitor environment key: $key"
    seen="${seen}${key}|"; records=$((records + 1)); printf -v "$key" '%s' "$value"; export "$key"
  done < "$file"
  ((records > 0)) || die "Monitor job environment is empty."
}
[[ -z "${MSPL_COVERAGE_JOB_ENV:-}" ]] || import_job_env "$MSPL_COVERAGE_JOB_ENV"
for required in MSPL_COVERAGE_ROOT MSPL_COVERAGE_LAUNCHER_DIR MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256 MSPL_COVERAGE_HELPER_SHA256 MSPL_COVERAGE_CLUSTER MSPL_COVERAGE_CAMPAIGN_ID MSPL_COVERAGE_SOURCE_SHA MSPL_COVERAGE_MANIFEST_SHA256 MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256 MSPL_COVERAGE_SOURCE_BUNDLE_SHA256 MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256; do
  [[ -n "${!required:-}" ]] || die "Required monitor binding is unset: $required"
done
ROOT="$MSPL_COVERAGE_ROOT"
if [[ "${MSPL_COVERAGE_MONITOR_TEST_MODE:-false}" == "true" ]]; then
  [[ "$ROOT" == /private/tmp/* || "$ROOT" == /tmp/* ]] || die "Monitor test root must be under /private/tmp or /tmp."
else
  [[ "$ROOT" == /project/* ]] || die "Set MSPL_COVERAGE_ROOT to the explicit /project campaign root."
fi
[[ "$MSPL_COVERAGE_LAUNCHER_DIR" == "$ROOT/launcher" ]] || die "Monitor requires the campaign-staged launcher directory."
LEDGER="$MSPL_COVERAGE_LAUNCHER_DIR/LAUNCHER-SHA256SUMS"
[[ -s "$LEDGER" ]] || die "Launcher hash ledger is absent."
awk 'BEGIN { expected[1]="README.md"; expected[2]="contract-self-test.sh"; expected[3]="drac-array.sbatch"; expected[4]="drac-monitor.sh"; expected[5]="drac-setup.sbatch"; expected[6]="drac-smoke.sbatch"; expected[7]="lib-mspl-coverage.sh" }
  { hash=substr($0,1,64); sep=substr($0,65,2); file=substr($0,67); if (length(hash)!=64 || hash !~ /^[0-9a-f]+$/ || sep!="  " || file!=expected[NR]) invalid=1 }
  END { if (NR!=7) invalid=1; exit invalid ? 2 : 0 }' "$LEDGER" || die "Launcher hash ledger schema disagrees."
[[ "$(sha256sum "$LEDGER" | awk '{print $1}')" == "$MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256" ]] || die "Launcher bundle SHA-256 disagrees."
(cd "$MSPL_COVERAGE_LAUNCHER_DIR" && sha256sum -c LAUNCHER-SHA256SUMS >/dev/null) || die "Staged launcher bundle file hash disagrees."
[[ "$(sha256sum "${BASH_SOURCE[0]}" | awk '{print $1}')" == "$(awk 'substr($0,67)=="drac-monitor.sh" {print substr($0,1,64)}' "$LEDGER")" ]] || die "Monitor script hash disagrees with staged bundle."
HELPER="$MSPL_COVERAGE_LAUNCHER_DIR/lib-mspl-coverage.sh"
[[ "$(sha256sum "$HELPER" | awk '{print $1}')" == "$MSPL_COVERAGE_HELPER_SHA256" ]] || die "Launcher helper SHA-256 disagrees."
# shellcheck source=/dev/null
source "$HELPER"
mspl_validate_manifest_binding
mspl_validate_production_manifest
mspl_verify_hash "$ROOT/manifest.csv" "$MSPL_COVERAGE_MANIFEST_SHA256"
mspl_assert_cluster
MAP="${MSPL_COVERAGE_ARRAY_MAP:-$ROOT/remaining-production-array-map.tsv}"
[[ -f "$MAP" ]] || die "Missing runner-produced remaining production map: $MAP"
mspl_validate_remaining_production_map "$MAP"
CLUSTER_CONTRACT="$(mspl_remaining_cluster_contract "$MSPL_COVERAGE_CLUSTER")" || die "Invalid monitor cluster contract."
IFS=$'\t' read -r FIRST_CASE LAST_CASE EXPECTED <<< "$CLUSTER_CONTRACT"

command -v Rscript >/dev/null 2>&1 || die "Rscript is required to validate completed shards."
SNAPSHOT="$(Rscript --vanilla - \
  "$ROOT" "$MSPL_COVERAGE_CLUSTER" "$MSPL_COVERAGE_CAMPAIGN_ID" \
  "$MSPL_COVERAGE_SOURCE_SHA" "$MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256" \
  "$MSPL_COVERAGE_SOURCE_BUNDLE_SHA256" "$MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256" \
  "$MSPL_COVERAGE_HELPER_SHA256" "$MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256" \
  "$FIRST_CASE" "$LAST_CASE" "$EXPECTED" <<'RS'
args <- commandArgs(trailingOnly = TRUE)
root <- args[[1L]]; cluster <- args[[2L]]; campaign <- args[[3L]]; source_sha <- args[[4L]]
expected_hashes <- setNames(args[5:9], c(
  "source_archive_sha256", "source_bundle_sha256", "launcher_bundle_sha256",
  "launcher_helper_sha256", "runtime_archive_sha256"
))
first_case <- as.integer(args[[10L]]); last_case <- as.integer(args[[11L]])
expected_count <- as.integer(args[[12L]])
manifest <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
case_ids <- sprintf("C%03d", first_case:last_case)
expected_names <- unlist(lapply(case_ids, function(case_id) {
  sprintf("%s-shard-%03d.rds", case_id, 2:100)
}), use.names = FALSE)
if (length(expected_names) != expected_count) stop("Cluster-local expected shard count disagrees.")
files <- list.files(file.path(root, "shards"), pattern = "\\.rds$", full.names = TRUE)
present <- files[basename(files) %in% expected_names]
allowed_gate4 <- sprintf("%s-shard-001.rds", case_ids)
unexpected <- files[!basename(files) %in% c(expected_names, allowed_gate4)]
required_provenance <- c(
  "manifest_version", "campaign_id", "source_sha", "cluster", "case_id", "shard_id",
  "runtime_fingerprint", "source_archive_sha256", "source_bundle_sha256",
  "launcher_bundle_sha256", "launcher_helper_sha256", "runtime_archive_sha256"
)
identity_fields <- c("manifest_version", "campaign_id", "source_sha", "cluster", "case_id",
  "shard_id", "runtime_fingerprint")
validate_one <- function(path) {
  x <- tryCatch(readRDS(path), error = function(e) NULL)
  if (!is.list(x) || !identical(x$schema_version, "gate0-shard-v2") ||
      !is.data.frame(x$provenance) || nrow(x$provenance) != 1L ||
      !identical(names(x$provenance), required_provenance)) return(FALSE)
  p <- x$provenance[1L, , drop = FALSE]
  filename <- basename(path)
  case_id <- sub("-shard-[0-9]{3}\\.rds$", "", filename)
  shard_id <- as.integer(sub("^.*-shard-([0-9]{3})\\.rds$", "\\1", filename))
  mi <- match(case_id, manifest$case_id)
  if (is.na(mi) || !case_id %in% case_ids || shard_id < 2L || shard_id > 100L ||
      !identical(as.character(p$case_id), case_id) || !identical(as.integer(p$shard_id), shard_id) ||
      !identical(as.character(p$campaign_id), campaign) ||
      !identical(as.character(p$source_sha), source_sha) ||
      !identical(as.character(p$cluster), cluster) ||
      !identical(as.character(p$manifest_version), as.character(manifest$manifest_version[[mi]])) ||
      !identical(as.character(manifest$assigned_cluster[[mi]]), cluster) ||
      !nzchar(as.character(p$runtime_fingerprint))) return(FALSE)
  for (field in names(expected_hashes)) {
    if (!identical(as.character(p[[field]]), expected_hashes[[field]]) ||
        !grepl("^[0-9a-f]{64}$", as.character(p[[field]]))) return(FALSE)
  }
  tables <- c("outer_fits", "bootstrap_attempts", "endpoints", "profile_traces")
  if (!all(tables %in% names(x)) || !all(vapply(x[tables], is.data.frame, logical(1L)))) return(FALSE)
  first_outer <- (shard_id - 1L) * 10L + 1L
  expected_outer <- first_outer:(first_outer + 9L)
  if (nrow(x$outer_fits) != 10L || nrow(x$bootstrap_attempts) != 5000L ||
      nrow(x$endpoints) != 90L ||
      !identical(sort(unique(as.integer(x$outer_fits$outer_id))), expected_outer)) return(FALSE)
  for (table in x[tables]) {
    if (!nrow(table)) next
    if (!all(identity_fields %in% names(table))) return(FALSE)
    for (field in identity_fields) {
      if (any(as.character(table[[field]]) != as.character(p[[field]]))) return(FALSE)
    }
  }
  boot_key <- paste(x$bootstrap_attempts$outer_id, x$bootstrap_attempts$attempt_id, sep = "/")
  endpoint_key <- paste(x$endpoints$outer_id, x$endpoints$method, x$endpoints$target, sep = "/")
  if (anyDuplicated(boot_key) || length(boot_key) != 5000L ||
      anyDuplicated(endpoint_key) || length(endpoint_key) != 90L) return(FALSE)
  TRUE
}
ok <- if (length(present)) vapply(present, validate_one, logical(1L)) else logical()
valid_files <- present[ok]
invalid_files <- c(unexpected, present[!ok])
mtime <- if (length(valid_files)) max(as.numeric(file.info(valid_files)$mtime)) else NA_real_
cat("valid=", length(valid_files), "\n", sep = "")
cat("invalid=", length(invalid_files), "\n", sep = "")
cat("newest_valid_shard_timestamp=", if (is.finite(mtime)) sprintf("%.0f", floor(mtime)) else "none", "\n", sep = "")
cat("invalid_files=", if (length(invalid_files)) paste(sort(basename(invalid_files)), collapse = ",") else "none", "\n", sep = "")
RS
)" || die "Schema-v2 shard validation failed."
snapshot_value() {
  local key="$1" value
  value="$(awk -F= -v key="$key" '$1 == key {print substr($0, length(key) + 2); n += 1} END {if (n != 1) exit 2}' <<< "$SNAPSHOT")" ||
    die "Monitor snapshot field is missing or duplicated: $key"
  printf '%s\n' "$value"
}
COMPLETED="$(snapshot_value valid)"
INVALID="$(snapshot_value invalid)"
NEWEST_SHARD_TIMESTAMP="$(snapshot_value newest_valid_shard_timestamp)"
INVALID_FILES="$(snapshot_value invalid_files)"
[[ "$COMPLETED" =~ ^[0-9]+$ && "$INVALID" =~ ^[0-9]+$ && "$NEWEST_SHARD_TIMESTAMP" =~ ^(none|[0-9]+)$ ]] ||
  die "Monitor snapshot values are malformed."

JOB_ID="${MSPL_COVERAGE_JOB_ID:-}"
RUNNING=0 PENDING=0 FAILED=0
NOW_EPOCH="${MSPL_COVERAGE_MONITOR_NOW_EPOCH:-$(date +%s)}"
[[ "$NOW_EPOCH" =~ ^[0-9]+$ ]] || die "Monitor current epoch is malformed."
FIRST_START_EPOCH=0 OLDEST_PENDING_AGE=0 MAX_RUNNING_SECONDS=0
STOP_REASONS=()
duration_seconds() {
  local value="$1" days=0 hours=0 minutes=0 seconds=0 rest
  if [[ "$value" == *-* ]]; then days="${value%%-*}"; rest="${value#*-}"; else rest="$value"; fi
  IFS=: read -r -a parts <<< "$rest"
  case "${#parts[@]}" in
    3) hours="${parts[0]}"; minutes="${parts[1]}"; seconds="${parts[2]}" ;;
    2) minutes="${parts[0]}"; seconds="${parts[1]}" ;;
    1) seconds="${parts[0]}" ;;
    *) return 2 ;;
  esac
  [[ "$days" =~ ^[0-9]+$ && "$hours" =~ ^[0-9]+$ && "$minutes" =~ ^[0-9]+$ && "$seconds" =~ ^[0-9]+$ ]] || return 2
  printf '%s\n' "$((10#$days * 86400 + 10#$hours * 3600 + 10#$minutes * 60 + 10#$seconds))"
}
time_epoch() {
  local value="$1"
  if [[ "$value" =~ ^[0-9]+$ ]]; then printf '%s\n' "$value"; return 0; fi
  [[ "$value" != Unknown && "$value" != N/A && "$value" != none ]] || return 2
  date -d "$value" +%s 2>/dev/null
}
if [[ -n "$JOB_ID" ]]; then
  if [[ -n "${MSPL_COVERAGE_SQUEUE_FIXTURE:-}" && "${MSPL_COVERAGE_MONITOR_TEST_MODE:-false}" == "true" ]]; then
    SQUEUE_STATES="$(cat "$MSPL_COVERAGE_SQUEUE_FIXTURE")" || die "Could not read squeue fixture."
  else
    command -v squeue >/dev/null 2>&1 || die "squeue is required when MSPL_COVERAGE_JOB_ID is supplied."
    SQUEUE_STATES="$(squeue -h -j "$JOB_ID" -o '%T|%V|%S|%M')" || die "squeue failed for job $JOB_ID."
  fi
  while IFS='|' read -r state submit start elapsed; do
    [[ -z "$state" ]] && continue
    case "$state" in
      RUNNING|COMPLETING)
        RUNNING=$((RUNNING + 1))
        elapsed_seconds="$(duration_seconds "$elapsed")" || die "Could not parse scheduler elapsed time: $elapsed"
        ((elapsed_seconds > MAX_RUNNING_SECONDS)) && MAX_RUNNING_SECONDS="$elapsed_seconds"
        if start_epoch="$(time_epoch "$start")"; then
          ((FIRST_START_EPOCH == 0 || start_epoch < FIRST_START_EPOCH)) && FIRST_START_EPOCH="$start_epoch"
        fi
        ;;
      PENDING|CONFIGURING)
        PENDING=$((PENDING + 1))
        submit_epoch="$(time_epoch "$submit")" || die "Could not parse scheduler submit time: $submit"
        submit_age=$((NOW_EPOCH - submit_epoch)); ((submit_age < 0)) && submit_age=0
        ((submit_age > OLDEST_PENDING_AGE)) && OLDEST_PENDING_AGE="$submit_age"
        ;;
    esac
  done <<< "$SQUEUE_STATES"
  if [[ -n "${MSPL_COVERAGE_SACCT_FIXTURE:-}" && "${MSPL_COVERAGE_MONITOR_TEST_MODE:-false}" == "true" ]]; then
    SACCT_STATES="$(cat "$MSPL_COVERAGE_SACCT_FIXTURE")" || die "Could not read sacct fixture."
  else
    command -v sacct >/dev/null 2>&1 || die "sacct is required when MSPL_COVERAGE_JOB_ID is supplied."
    SACCT_STATES="$(sacct -n -X -P -j "$JOB_ID" --format=State,Submit,Start,Elapsed)" || die "sacct failed for job $JOB_ID."
  fi
  while IFS='|' read -r state submit start elapsed extra; do
    [[ -z "$state" ]] && continue
    [[ -z "${extra:-}" ]] || die "Unexpected sacct fixture/query field count."
    case "$state" in
      FAILED*|CANCELLED*|TIMEOUT*|OUT_OF_MEMORY*|NODE_FAIL*|BOOT_FAIL*) FAILED=$((FAILED + 1)) ;;
    esac
    if start_epoch="$(time_epoch "$start")"; then
      ((FIRST_START_EPOCH == 0 || start_epoch < FIRST_START_EPOCH)) && FIRST_START_EPOCH="$start_epoch"
    fi
  done <<< "$SACCT_STATES"
fi

((INVALID > 0)) && STOP_REASONS+=(invalid_shard)
((FAILED > 0)) && STOP_REASONS+=(failed_task)
((MAX_RUNNING_SECONDS > 871)) && STOP_REASONS+=(task_over_2x_gate4_median)
((MAX_RUNNING_SECONDS >= 1800)) && STOP_REASONS+=(task_at_30m_hard_limit)
((COMPLETED == 0 && FIRST_START_EPOCH > 0 && NOW_EPOCH - FIRST_START_EPOCH > 3600)) && STOP_REASONS+=(no_first_valid_shard_60m)
((COMPLETED == 0 && RUNNING == 0 && PENDING > 0 && OLDEST_PENDING_AGE > 2700)) && STOP_REASONS+=(no_start_45m)
((PENDING > 0 && OLDEST_PENDING_AGE > 7200)) && STOP_REASONS+=(pending_over_2h)
STOP_RECOMMENDED=FALSE
((${#STOP_REASONS[@]})) && STOP_RECOMMENDED=TRUE
STOP_REASON_TEXT=none
((${#STOP_REASONS[@]})) && STOP_REASON_TEXT="$(IFS=,; printf '%s' "${STOP_REASONS[*]}")"

shopt -s nullglob
receipts=("$ROOT"/receipts/*.receipt)
NEWEST_RECEIPT="none"
if ((${#receipts[@]})); then NEWEST_RECEIPT="$(ls -1t "${receipts[@]}" | head -n 1)"; fi
printf 'cluster=%s\nexpected=%s\ncompleted=%s\ninvalid=%s\ninvalid_files=%s\nrunning=%s\npending=%s\nfailed=%s\nmax_running_seconds=%s\noldest_pending_age_seconds=%s\nnewest_valid_shard_timestamp=%s\nnewest_receipt=%s\nstop_recommended=%s\nstop_reasons=%s\n' \
  "$MSPL_COVERAGE_CLUSTER" "$EXPECTED" "$COMPLETED" "$INVALID" "$INVALID_FILES" \
  "$RUNNING" "$PENDING" "$FAILED" "$MAX_RUNNING_SECONDS" "$OLDEST_PENDING_AGE" \
  "$NEWEST_SHARD_TIMESTAMP" "$NEWEST_RECEIPT" "$STOP_RECOMMENDED" "$STOP_REASON_TEXT"
