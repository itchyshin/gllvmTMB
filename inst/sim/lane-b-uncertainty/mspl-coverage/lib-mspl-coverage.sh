#!/usr/bin/env bash
# Shared, source-only helpers for the private LA-MSPL DRAC coverage ladder.

set -euo pipefail

mspl_die() { echo "[mspl-coverage] $*" >&2; exit 2; }

mspl_require_env() {
  local name
  for name in "$@"; do
    [[ -n "${!name:-}" ]] || mspl_die "Required environment variable is unset: $name"
  done
}

mspl_sha256() {
  command -v sha256sum >/dev/null 2>&1 || mspl_die "sha256sum is required."
  sha256sum "$1" | awk '{print $1}'
}

mspl_verify_hash() {
  local file="$1" expected="$2" observed
  [[ -f "$file" ]] || mspl_die "Required file does not exist: $file"
  observed="$(mspl_sha256 "$file")"
  [[ "$observed" == "$expected" ]] || mspl_die "SHA-256 mismatch for $file (expected $expected, observed $observed)"
}

mspl_load_modules() {
  module purge
  module load "${MSPL_COVERAGE_STDENV_MODULE:-StdEnv/2023}"
  module load "${MSPL_COVERAGE_COMPILER_MODULE:-gcc/12.3}"
  if [[ -n "${MSPL_COVERAGE_EXTRA_MODULES:-}" ]]; then
    local module_name
    IFS=, read -r -a extra <<< "$MSPL_COVERAGE_EXTRA_MODULES"
    for module_name in "${extra[@]}"; do
      [[ "$module_name" =~ ^[A-Za-z0-9._/+:-]+$ ]] || mspl_die "Invalid extra module name: $module_name"
    done
    module load "${extra[@]}"
  fi
  module load "${MSPL_COVERAGE_R_MODULE:-r/4.5.0}"
}

mspl_assert_cluster() {
  local requested="${MSPL_COVERAGE_CLUSTER:-}" actual="${SLURM_CLUSTER_NAME:-}"
  case "$requested" in fir|nibi|rorqual|narval) ;; *) mspl_die "MSPL_COVERAGE_CLUSTER must be fir, nibi, rorqual, or narval." ;; esac
  if [[ -n "$actual" && "$actual" != "$requested" ]]; then
    mspl_die "Refusing cross-cluster execution: requested=$requested scheduler=$actual"
  fi
}

mspl_validate_common_inputs() {
  mspl_require_env MSPL_COVERAGE_ROOT MSPL_COVERAGE_CAMPAIGN_ID MSPL_COVERAGE_SOURCE_SHA \
    MSPL_COVERAGE_SOURCE_ARCHIVE MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256 \
    MSPL_COVERAGE_CLUSTER MSPL_COVERAGE_MANIFEST_SHA256 \
    MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256 MSPL_COVERAGE_HELPER_SHA256
  [[ -n "${SLURM_TMPDIR:-}" && -d "$SLURM_TMPDIR" ]] || mspl_die "SLURM_TMPDIR must be an existing job-local directory."
  [[ "$MSPL_COVERAGE_ROOT" == /project/* ]] || mspl_die "MSPL_COVERAGE_ROOT must be an explicit /project path."
  [[ "$MSPL_COVERAGE_CAMPAIGN_ID" =~ ^[0-9A-Za-z._-]+$ ]] || mspl_die "Campaign ID may contain only safe label characters."
  [[ "$MSPL_COVERAGE_SOURCE_SHA" =~ ^[0-9A-Za-z._-]+$ ]] || mspl_die "Source SHA may contain only safe label characters."
  mspl_assert_cluster
  mspl_verify_hash "$MSPL_COVERAGE_SOURCE_ARCHIVE" "$MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256"
  [[ -f "$MSPL_COVERAGE_ROOT/manifest.csv" ]] || mspl_die "Missing frozen manifest.csv at campaign root."
  mspl_verify_hash "$MSPL_COVERAGE_ROOT/manifest.csv" "$MSPL_COVERAGE_MANIFEST_SHA256"
  mspl_validate_manifest_binding
}

mspl_prepare_workdir() {
  MSPL_COVERAGE_WORK="${SLURM_TMPDIR}/mspl-coverage-${MSPL_COVERAGE_CLUSTER}-${SLURM_JOB_ID:-manual}"
  MSPL_COVERAGE_SOURCE_DIR="${MSPL_COVERAGE_WORK}/source"
  MSPL_COVERAGE_LOCAL_ROOT="${MSPL_COVERAGE_WORK}/campaign"
  MSPL_COVERAGE_R_LIB="${MSPL_COVERAGE_WORK}/r-library"
  export MSPL_COVERAGE_WORK MSPL_COVERAGE_SOURCE_DIR MSPL_COVERAGE_LOCAL_ROOT MSPL_COVERAGE_R_LIB
  mkdir -p "$MSPL_COVERAGE_SOURCE_DIR" "$MSPL_COVERAGE_LOCAL_ROOT/shards"
}

mspl_stage_source_archive() {
  local description count
  tar -xzf "$MSPL_COVERAGE_SOURCE_ARCHIVE" -C "$MSPL_COVERAGE_SOURCE_DIR"
  count="$(find "$MSPL_COVERAGE_SOURCE_DIR" -name DESCRIPTION -type f -print | wc -l | tr -d ' ')"
  [[ "$count" == "1" ]] || mspl_die "Source archive must contain exactly one DESCRIPTION (found $count)."
  description="$(find "$MSPL_COVERAGE_SOURCE_DIR" -name DESCRIPTION -type f -print | head -n 1)"
  MSPL_COVERAGE_PACKAGE_DIR="$(dirname "$description")"
  export MSPL_COVERAGE_PACKAGE_DIR
  [[ "$(awk -F': *' '$1 == "Package" {print $2; exit}' "$description")" == "gllvmTMB" ]] || mspl_die "Source archive DESCRIPTION is not gllvmTMB."
}

mspl_stage_source_bundle() {
  mspl_require_env MSPL_COVERAGE_SOURCE_BUNDLE MSPL_COVERAGE_SOURCE_BUNDLE_SHA256
  mspl_verify_hash "$MSPL_COVERAGE_SOURCE_BUNDLE" "$MSPL_COVERAGE_SOURCE_BUNDLE_SHA256"
  MSPL_COVERAGE_BUNDLE_DIR="${MSPL_COVERAGE_WORK}/source-bundle"
  MSPL_COVERAGE_REPO_ROOT="$MSPL_COVERAGE_BUNDLE_DIR"
  MSPL_COVERAGE_CONTRIB_DIR="${MSPL_COVERAGE_REPO_ROOT}/src/contrib"
  export MSPL_COVERAGE_BUNDLE_DIR MSPL_COVERAGE_REPO_ROOT MSPL_COVERAGE_CONTRIB_DIR
  mkdir -p "$MSPL_COVERAGE_BUNDLE_DIR"
  tar -xzf "$MSPL_COVERAGE_SOURCE_BUNDLE" -C "$MSPL_COVERAGE_BUNDLE_DIR"
  [[ -s "$MSPL_COVERAGE_CONTRIB_DIR/PACKAGES" ]] || mspl_die "Source bundle must expand to src/contrib/PACKAGES; precompiled r-library bundles are forbidden."
  find "$MSPL_COVERAGE_CONTRIB_DIR" -maxdepth 1 -type f -name '*.tar.gz' -print -quit | grep -q . || mspl_die "Source repository contains no package source tarballs."
}

mspl_dependency_packages() {
  printf '%s\n' "${MSPL_COVERAGE_DEPENDENCY_PACKAGES-BH,RcppEigen,TMB,assertthat,cli,fmesher,generics,lifecycle,rlang,tidyselect}"
}

mspl_materialize_dependency_packages() {
  local package package_csv seen="|"
  package_csv="$(mspl_dependency_packages)"
  [[ -n "$package_csv" && "$package_csv" != ,* && "$package_csv" != *, && "$package_csv" != *,,* ]] ||
    mspl_die "Dependency package list contains an empty item."
  IFS=, read -r -a _MSPL_DEPENDENCY_PACKAGES <<< "$package_csv"
  ((${#_MSPL_DEPENDENCY_PACKAGES[@]})) || mspl_die "Dependency package list is empty."
  for package in "${_MSPL_DEPENDENCY_PACKAGES[@]}"; do
    [[ "$package" =~ ^[A-Za-z][A-Za-z0-9.]*$ ]] || mspl_die "Invalid dependency package name: $package"
    [[ "$seen" != *"|${package}|"* ]] || mspl_die "Duplicate dependency package name: $package"
    seen="${seen}${package}|"
  done
}

mspl_dependency_package_lines() {
  local package
  mspl_materialize_dependency_packages
  for package in "${_MSPL_DEPENDENCY_PACKAGES[@]}"; do
    printf '%s\n' "$package"
  done
}

mspl_bootstrap_packages_csv() {
  local package has_bh=false has_rcppeigen=false has_tmb=false
  mspl_materialize_dependency_packages
  for package in "${_MSPL_DEPENDENCY_PACKAGES[@]}"; do
    case "$package" in
      BH) has_bh=true ;;
      RcppEigen) has_rcppeigen=true ;;
      TMB) has_tmb=true ;;
    esac
  done
  [[ "$has_bh" == true && "$has_rcppeigen" == true && "$has_tmb" == true ]] ||
    mspl_die "Dependency list must include BH, RcppEigen, and TMB."
  printf 'BH,RcppEigen,TMB\n'
}

mspl_remaining_packages_csv() {
  local package separator=""
  mspl_materialize_dependency_packages
  for package in "${_MSPL_DEPENDENCY_PACKAGES[@]}"; do
    case "$package" in BH|RcppEigen|TMB) continue ;; esac
    printf '%s%s' "$separator" "$package"
    separator=,
  done
  printf '\n'
}

mspl_source_package_record() {
  local package="$1" version tarball
  version="$(awk -v wanted="$package" 'BEGIN { RS = ""; FS = "\n" } { p = v = ""; for (i = 1; i <= NF; i++) { if ($i ~ /^Package:/) { sub(/^Package:[[:space:]]*/, "", $i); p = $i }; if ($i ~ /^Version:/) { sub(/^Version:[[:space:]]*/, "", $i); v = $i } }; if (p == wanted) { print v; exit } }' "$MSPL_COVERAGE_CONTRIB_DIR/PACKAGES")"
  [[ -n "$version" ]] || mspl_die "Offline PACKAGES index has no entry for required dependency: $package"
  tarball="$MSPL_COVERAGE_CONTRIB_DIR/${package}_${version}.tar.gz"
  [[ -f "$tarball" ]] || mspl_die "Offline source repository lacks $package source tarball at $tarball"
  printf 'source_dependency=%s version=%s sha256=%s\n' "$package" "$version" "$(mspl_sha256 "$tarball")"
}

mspl_source_dependency_inventory() {
  local package
  mspl_materialize_dependency_packages
  for package in "${_MSPL_DEPENDENCY_PACKAGES[@]}"; do
    mspl_source_package_record "$package"
  done
}

mspl_job_env_record() {
  local key="$1" value="$2"
  [[ "$key" =~ ^MSPL_COVERAGE_[A-Z0-9_]+$ ]] || mspl_die "Unsafe runtime-environment key: $key"
  [[ "$value" =~ ^[A-Za-z0-9._/@:+,-]*$ ]] || mspl_die "Unsafe runtime-environment value for $key."
  [[ -n "$value" || "$key" == "MSPL_COVERAGE_EXTRA_MODULES" ]] || mspl_die "Empty runtime-environment value for $key."
  printf '%s=%s\n' "$key" "$value"
}

mspl_install_native_runtime() {
  local bootstrap_csv rest_csv
  bootstrap_csv="$(mspl_bootstrap_packages_csv)"
  rest_csv="$(mspl_remaining_packages_csv)"
  mkdir -p "$MSPL_COVERAGE_R_LIB"
  mkdir -p "${MSPL_COVERAGE_WORK}/tmp"
  export R_LIBS_USER="$MSPL_COVERAGE_R_LIB" R_LIBS="$MSPL_COVERAGE_R_LIB"
  export TMPDIR="${MSPL_COVERAGE_WORK}/tmp"
  export MAKEFLAGS="-j${SLURM_CPUS_PER_TASK:-1}"
  export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
  MSPL_COVERAGE_REPO_ROOT="$MSPL_COVERAGE_REPO_ROOT" MSPL_COVERAGE_R_LIB="$MSPL_COVERAGE_R_LIB" \
    MSPL_COVERAGE_INSTALL_PACKAGES="$bootstrap_csv" Rscript --vanilla - <<'RS'
repo <- normalizePath(Sys.getenv("MSPL_COVERAGE_REPO_ROOT"), mustWork = TRUE)
lib <- Sys.getenv("MSPL_COVERAGE_R_LIB")
pkgs <- strsplit(Sys.getenv("MSPL_COVERAGE_INSTALL_PACKAGES"), ",", fixed = TRUE)[[1L]]
install.packages(pkgs, lib = lib, repos = c(offline = paste0("file://", repo)),
                 type = "source", dependencies = c("Depends", "Imports", "LinkingTo"))
RS
  if [[ -n "$rest_csv" ]]; then
    MSPL_COVERAGE_REPO_ROOT="$MSPL_COVERAGE_REPO_ROOT" MSPL_COVERAGE_R_LIB="$MSPL_COVERAGE_R_LIB" \
      MSPL_COVERAGE_INSTALL_PACKAGES="$rest_csv" Rscript --vanilla - <<'RS'
repo <- normalizePath(Sys.getenv("MSPL_COVERAGE_REPO_ROOT"), mustWork = TRUE)
lib <- Sys.getenv("MSPL_COVERAGE_R_LIB")
pkgs <- strsplit(Sys.getenv("MSPL_COVERAGE_INSTALL_PACKAGES"), ",", fixed = TRUE)[[1L]]
install.packages(pkgs, lib = lib, repos = c(offline = paste0("file://", repo)),
                 type = "source", dependencies = c("Depends", "Imports", "LinkingTo"))
RS
  fi
  R CMD INSTALL --preclean --library="$MSPL_COVERAGE_R_LIB" "$MSPL_COVERAGE_PACKAGE_DIR"
}

mspl_objective_evaluation() {
  Rscript --vanilla - <<'RS'
library(gllvmTMB)
set.seed(8142026)
d <- data.frame(y = stats::rbinom(48L, 1L, 0.5),
  site = factor(rep(seq_len(16L), each = 3L)), trait = factor(rep(paste0("t", 1:3), 16L)))
fit <- gllvmTMB::gllvmTMB(
  y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE), data = d,
  family = stats::binomial(), estimator = "mspl",
  control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE), silent = TRUE
)
if (!is.finite(fit$opt$objective)) stop("Objective is not finite.")
cat("objective_finite=TRUE\nobjective=", format(fit$opt$objective, digits = 17), "\n", sep = "")
RS
}

mspl_runtime_destination() {
  printf '%s/runtime-libraries/%s/mspl-coverage-runtime-%s-%s.tar.gz\n' \
    "$MSPL_COVERAGE_ROOT" "$MSPL_COVERAGE_CLUSTER" "$MSPL_COVERAGE_CLUSTER" "$MSPL_COVERAGE_SOURCE_SHA"
}

mspl_archive_native_runtime() {
  local archive archive_tmp contract env_file env_tmp archive_hash modules
  archive="$(mspl_runtime_destination)"
  archive_tmp="${SLURM_TMPDIR}/$(basename "$archive")"
  contract="${MSPL_COVERAGE_WORK}/runtime-library.contract"
  env_file="${archive%.tar.gz}.env"
  env_tmp="${SLURM_TMPDIR}/.$(basename "$env_file").tmp"
  [[ ! -e "$archive" ]] || mspl_die "Refusing to replace immutable runtime archive: $archive"
  modules="$(module -t list 2>&1 | tr '\n' ';')"
  {
    printf 'cluster=%s\n' "$MSPL_COVERAGE_CLUSTER"
    printf 'campaign_id=%s\n' "$MSPL_COVERAGE_CAMPAIGN_ID"
    printf 'source_sha=%s\n' "$MSPL_COVERAGE_SOURCE_SHA"
    printf 'manifest_sha256=%s\n' "$MSPL_COVERAGE_MANIFEST_SHA256"
    printf 'source_archive_sha256=%s\n' "$MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256"
    printf 'source_bundle_sha256=%s\n' "$MSPL_COVERAGE_SOURCE_BUNDLE_SHA256"
    printf 'launcher_bundle_sha256=%s\n' "$MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256"
    printf 'launcher_helper_sha256=%s\n' "$MSPL_COVERAGE_HELPER_SHA256"
    printf 'architecture=%s\n' "$(uname -m)"
    printf 'modules=%s\n' "$modules"
  } > "$contract"
  mkdir -p "$(dirname "$archive")"
  tar -C "$MSPL_COVERAGE_WORK" -czf "$archive_tmp" r-library runtime-library.contract
  archive_hash="$(mspl_sha256 "$archive_tmp")"
  cp "$archive_tmp" "${archive}.tmp-${SLURM_JOB_ID:-manual}"
  mv "${archive}.tmp-${SLURM_JOB_ID:-manual}" "$archive"
  {
    mspl_job_env_record MSPL_COVERAGE_ROOT "$MSPL_COVERAGE_ROOT"
    mspl_job_env_record MSPL_COVERAGE_LAUNCHER_DIR "$MSPL_COVERAGE_LAUNCHER_DIR"
    mspl_job_env_record MSPL_COVERAGE_HELPER_SHA256 "$MSPL_COVERAGE_HELPER_SHA256"
    mspl_job_env_record MSPL_COVERAGE_RUNTIME_ARCHIVE "$archive"
    mspl_job_env_record MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256 "$archive_hash"
    mspl_job_env_record MSPL_COVERAGE_CLUSTER "$MSPL_COVERAGE_CLUSTER"
    mspl_job_env_record MSPL_COVERAGE_CAMPAIGN_ID "$MSPL_COVERAGE_CAMPAIGN_ID"
    mspl_job_env_record MSPL_COVERAGE_SOURCE_SHA "$MSPL_COVERAGE_SOURCE_SHA"
    mspl_job_env_record MSPL_COVERAGE_MANIFEST_SHA256 "$MSPL_COVERAGE_MANIFEST_SHA256"
    mspl_job_env_record MSPL_COVERAGE_SOURCE_ARCHIVE "$MSPL_COVERAGE_SOURCE_ARCHIVE"
    mspl_job_env_record MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256 "$MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256"
    mspl_job_env_record MSPL_COVERAGE_SOURCE_BUNDLE_SHA256 "$MSPL_COVERAGE_SOURCE_BUNDLE_SHA256"
    mspl_job_env_record MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256 "$MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256"
    mspl_job_env_record MSPL_COVERAGE_STDENV_MODULE "${MSPL_COVERAGE_STDENV_MODULE:-StdEnv/2023}"
    mspl_job_env_record MSPL_COVERAGE_COMPILER_MODULE "${MSPL_COVERAGE_COMPILER_MODULE:-gcc/12.3}"
    mspl_job_env_record MSPL_COVERAGE_R_MODULE "${MSPL_COVERAGE_R_MODULE:-r/4.5.0}"
    mspl_job_env_record MSPL_COVERAGE_EXTRA_MODULES "${MSPL_COVERAGE_EXTRA_MODULES:-}"
  } > "$env_tmp"
  mv "$env_tmp" "$env_file"
  export MSPL_COVERAGE_RUNTIME_ARCHIVE="$archive" MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256="$archive_hash"
}

mspl_write_setup_receipt() {
  local receipt_dir="$MSPL_COVERAGE_ROOT/receipts" receipt tmp modules objective package
  receipt="${receipt_dir}/setup-${MSPL_COVERAGE_CLUSTER}-${SLURM_JOB_ID:-manual}.receipt"
  tmp="${SLURM_TMPDIR}/.$(basename "$receipt").tmp"
  mkdir -p "$receipt_dir"
  modules="$(module -t list 2>&1 | tr '\n' ';')"
  objective="$(mspl_objective_evaluation)"
  {
    printf 'receipt_type=cluster_native_setup\ncluster=%s\ncampaign_id=%s\nsource_sha=%s\n' "$MSPL_COVERAGE_CLUSTER" "$MSPL_COVERAGE_CAMPAIGN_ID" "$MSPL_COVERAGE_SOURCE_SHA"
    printf 'manifest_sha256=%s\nsource_archive_sha256=%s\nsource_bundle_sha256=%s\n' "$MSPL_COVERAGE_MANIFEST_SHA256" "$MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256" "$MSPL_COVERAGE_SOURCE_BUNDLE_SHA256"
    printf 'runtime_archive=%s\nruntime_archive_sha256=%s\n' "$MSPL_COVERAGE_RUNTIME_ARCHIVE" "$MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256"
    printf 'launcher_bundle_sha256=%s\nlauncher_helper_sha256=%s\n' "$MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256" "$MSPL_COVERAGE_HELPER_SHA256"
    printf 'r_module=%s\ncompiler_module=%s\narchitecture=%s\nmodules=%s\n' "${MSPL_COVERAGE_R_MODULE:-r/4.5.0}" "${MSPL_COVERAGE_COMPILER_MODULE:-gcc/12.3}" "$(uname -m)" "$modules"
    mspl_source_dependency_inventory
    MSPL_COVERAGE_DEPENDENCY_PACKAGES="$(mspl_dependency_packages)" Rscript --vanilla -e 'pkgs <- c("gllvmTMB", strsplit(Sys.getenv("MSPL_COVERAGE_DEPENDENCY_PACKAGES"), ",", fixed = TRUE)[[1]]); for (p in pkgs) cat("installed_dependency=", p, " version=", as.character(utils::packageVersion(p)), "\\n", sep = "")'
    printf '%s\n' "$objective"
    printf 'session_info_begin\n'
    Rscript --vanilla -e 'sessionInfo()'
    printf 'session_info_end\n'
  } > "$tmp"
  mv "$tmp" "$receipt"
  printf '%s\n' "$receipt"
}

mspl_validate_runtime_inputs() {
  mspl_validate_common_inputs
  mspl_require_env MSPL_COVERAGE_RUNTIME_ARCHIVE MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256 \
    MSPL_COVERAGE_SOURCE_BUNDLE_SHA256
  mspl_verify_hash "$MSPL_COVERAGE_RUNTIME_ARCHIVE" "$MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256"
}

mspl_verify_runtime_contract() {
  local contract="$1"
  [[ -s "$contract" ]] || mspl_die "Runtime archive lacks runtime-library.contract."
  grep -Fxq "cluster=$MSPL_COVERAGE_CLUSTER" "$contract" || mspl_die "Runtime archive is labelled for another cluster; cross-cluster compiled libraries are forbidden."
  grep -Fxq "campaign_id=$MSPL_COVERAGE_CAMPAIGN_ID" "$contract" || mspl_die "Runtime archive campaign ID disagrees."
  grep -Fxq "source_sha=$MSPL_COVERAGE_SOURCE_SHA" "$contract" || mspl_die "Runtime archive source SHA disagrees."
  grep -Fxq "manifest_sha256=$MSPL_COVERAGE_MANIFEST_SHA256" "$contract" || mspl_die "Runtime archive manifest SHA-256 disagrees."
  grep -Fxq "source_archive_sha256=$MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256" "$contract" || mspl_die "Runtime archive was compiled from a different source archive."
  grep -Fxq "source_bundle_sha256=$MSPL_COVERAGE_SOURCE_BUNDLE_SHA256" "$contract" || mspl_die "Runtime archive was compiled from a different source dependency bundle."
  grep -Fxq "launcher_bundle_sha256=$MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256" "$contract" || mspl_die "Runtime archive was built with a different launcher bundle."
  grep -Fxq "launcher_helper_sha256=$MSPL_COVERAGE_HELPER_SHA256" "$contract" || mspl_die "Runtime archive was built with a different launcher helper."
  grep -Fxq "architecture=$(uname -m)" "$contract" || mspl_die "Runtime archive architecture disagrees."
}

mspl_stage_runtime() {
  local contract
  mspl_prepare_workdir
  mspl_stage_source_archive
  tar -xzf "$MSPL_COVERAGE_RUNTIME_ARCHIVE" -C "$MSPL_COVERAGE_WORK"
  contract="${MSPL_COVERAGE_WORK}/runtime-library.contract"
  [[ -d "$MSPL_COVERAGE_R_LIB" ]] || mspl_die "Runtime archive must contain r-library/."
  mspl_verify_runtime_contract "$contract"
  export R_LIBS_USER="$MSPL_COVERAGE_R_LIB" R_LIBS="$MSPL_COVERAGE_R_LIB"
  export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
  cp "$MSPL_COVERAGE_ROOT/manifest.csv" "$MSPL_COVERAGE_LOCAL_ROOT/manifest.csv"
}

mspl_manifest_first_field() {
  local manifest="$1" wanted_field="$2"
  awk -F, -v wanted_field="$wanted_field" '
    function clean(value) { gsub(/^"|"$/, "", value); return value }
    NR == 1 {
      header_count = NF
      for (i = 1; i <= NF; i++) {
        name = clean($i)
        if (name !~ /^[A-Za-z][A-Za-z0-9_]*$/) invalid = 1
        if (name == wanted_field) { column = i; columns += 1 }
      }
      next
    }
    {
      if (NF != header_count) invalid = 1
      for (i = 1; i <= NF; i++) if (clean($i) !~ /^[A-Za-z0-9._-]+$/) invalid = 1
      if (NR == 2 && columns == 1) { value = clean($column); found = 1 }
    }
    END { if (invalid || columns != 1 || !found) exit 2; print value }
  ' "$manifest"
}

mspl_manifest_case_field() {
  local manifest="$1" wanted_case="$2" wanted_field="$3"
  awk -F, -v wanted_case="$wanted_case" -v wanted_field="$wanted_field" '
    function clean(value) { gsub(/^"|"$/, "", value); return value }
    NR == 1 {
      header_count = NF
      for (i = 1; i <= NF; i++) {
        name = clean($i)
        if (name !~ /^[A-Za-z][A-Za-z0-9_]*$/) invalid = 1
        if (name == "case_id") { case_column = i; case_columns += 1 }
        if (name == wanted_field) { value_column = i; value_columns += 1 }
      }
      next
    }
    {
      if (NF != header_count) invalid = 1
      for (i = 1; i <= NF; i++) if (clean($i) !~ /^[A-Za-z0-9._-]+$/) invalid = 1
      if (case_columns == 1 && value_columns == 1 && clean($case_column) == wanted_case) {
        value = clean($value_column); matches += 1
      }
    }
    END {
      if (invalid || case_columns != 1 || value_columns != 1 || matches != 1) exit 2
      print value
    }
  ' "$manifest"
}

mspl_campaign_id() {
  mspl_manifest_first_field "$MSPL_COVERAGE_ROOT/manifest.csv" campaign_id
}

mspl_manifest_source_sha() {
  mspl_manifest_first_field "$MSPL_COVERAGE_ROOT/manifest.csv" source_sha
}

mspl_validate_manifest_binding() {
  local campaign_id source_sha
  mspl_require_env MSPL_COVERAGE_CAMPAIGN_ID MSPL_COVERAGE_SOURCE_SHA
  campaign_id="$(mspl_campaign_id)" || mspl_die "Could not read the unique safe campaign_id from manifest.csv."
  source_sha="$(mspl_manifest_source_sha)" || mspl_die "Could not read the unique safe source_sha from manifest.csv."
  [[ "$campaign_id" == "$MSPL_COVERAGE_CAMPAIGN_ID" ]] ||
    mspl_die "Manifest campaign ID disagrees with the explicit runtime campaign binding."
  [[ "$source_sha" == "$MSPL_COVERAGE_SOURCE_SHA" ]] ||
    mspl_die "Manifest source SHA disagrees with the explicit runtime source binding."
}

mspl_validate_gate4_shard_hash_ledger() {
  local ledger="$1"
  [[ -s "$ledger" ]] || mspl_die "Missing immutable Gate 4 shard hash ledger: $ledger"
  awk '
    {
      expected = sprintf("C%03d-shard-001.rds", NR)
      hash = substr($0, 1, 64); separator = substr($0, 65, 2); filename = substr($0, 67)
      if (length(hash) != 64 || hash !~ /^[0-9a-f]+$/ || separator != "  " || filename != expected) invalid = 1
    }
    END { if (NR != 12) invalid = 1; exit invalid ? 2 : 0 }
  ' "$ledger" || mspl_die "Gate 4 shard hash ledger must be 12 sorted shard-001 hashes, one per C001..C012, with no paths or duplicates."
}

mspl_validate_gate3_ready_receipt() {
  local receipt="$1" manifest_hash smoke_manifest smoke_manifest_hash aggregate ledger aggregate_hash ledger_hash
  [[ -s "$receipt" ]] || mspl_die "Pre-run blocked: Gate 3 ready receipt is absent or empty: $receipt"
  mspl_require_env MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256 MSPL_COVERAGE_SOURCE_BUNDLE_SHA256 \
    MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256 MSPL_COVERAGE_HELPER_SHA256 MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256
  smoke_manifest="$MSPL_COVERAGE_ROOT/gates/gate3-smoke-manifest.csv"
  aggregate="$MSPL_COVERAGE_ROOT/gates/gate3-smoke-receipt.txt"
  ledger="$MSPL_COVERAGE_ROOT/gates/gate3-smoke-shard-hashes.sha256"
  [[ -s "$smoke_manifest" && -s "$aggregate" && -s "$ledger" ]] || mspl_die "Pre-run blocked: staged Gate 3 smoke evidence is incomplete."
  awk '$0 == "launcher_unlock_eligible: FALSE" { found += 1 } END { exit found == 1 ? 0 : 2 }' "$aggregate" ||
    mspl_die "Gate 3 statistical aggregate must be explicitly launcher-unlock-ineligible."
  awk '{ expected = (NR == 1 ? "C001-shard-001.rds" : (NR == 2 ? "C005-shard-001.rds" : "C009-shard-001.rds")); hash=substr($0,1,64); sep=substr($0,65,2); file=substr($0,67); if (length(hash)!=64 || hash !~ /^[0-9a-f]+$/ || sep!="  " || file!=expected) invalid=1 }
    END { if (NR!=3) invalid=1; exit invalid ? 2 : 0 }' "$ledger" || mspl_die "Gate 3 shard ledger must contain exactly sorted C001/C005/C009 shard-001 hashes."
  manifest_hash="$(mspl_sha256 "$MSPL_COVERAGE_ROOT/manifest.csv")"
  smoke_manifest_hash="$(mspl_sha256 "$smoke_manifest")"; aggregate_hash="$(mspl_sha256 "$aggregate")"; ledger_hash="$(mspl_sha256 "$ledger")"
  awk -F= -v campaign="$MSPL_COVERAGE_CAMPAIGN_ID" -v source="$MSPL_COVERAGE_SOURCE_SHA" -v manifest="$manifest_hash" \
    -v smoke_manifest="$smoke_manifest_hash" -v source_archive="$MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256" \
    -v source_bundle="$MSPL_COVERAGE_SOURCE_BUNDLE_SHA256" -v launcher_bundle="$MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256" \
    -v helper="$MSPL_COVERAGE_HELPER_SHA256" -v cluster="$MSPL_COVERAGE_CLUSTER" -v runtime="$MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256" \
    -v aggregate="$aggregate_hash" -v ledger="$ledger_hash" '
    BEGIN {
      expected["receipt_type"]="gate3-smoke-ready-v1"; expected["gate_status"]="PASS"
      expected["campaign_id"]=campaign; expected["source_sha"]=source; expected["manifest_sha256"]=manifest
      expected["smoke_manifest_sha256"]=smoke_manifest; expected["source_archive_sha256"]=source_archive
      expected["source_bundle_sha256"]=source_bundle; expected["launcher_bundle_sha256"]=launcher_bundle
      expected["launcher_helper_sha256"]=helper; expected["cluster"]=cluster; expected["runtime_archive_sha256"]=runtime
      expected["gate3_smoke_receipt_sha256"]=aggregate; expected["gate3_shard_ledger_sha256"]=ledger
      expected["shard_count"]="3"; expected["outer_fit_rows"]="3"; expected["bootstrap_attempt_rows"]="6"
      expected["endpoint_rows"]="27"; expected["calibration_gate_eligible"]="FALSE"
    }
    {
      if (NF != 2 || $1 !~ /^[a-z][a-z0-9_]*$/ || $2 !~ /^[A-Za-z0-9._-]+$/ || !($1 in expected) || seen[$1]++) invalid = 1
      else if ($2 != expected[$1]) invalid = 1
    }
    END { for (key in expected) if (seen[key] != 1) invalid = 1; if (NR != 19) invalid = 1; exit invalid ? 2 : 0 }
  ' "$receipt" || mspl_die "Pre-run blocked: Gate 3 ready receipt schema or provenance disagrees."
}

mspl_validate_gate4_ready_receipt() {
  local receipt="$1" aggregate ledger manifest_hash aggregate_hash shard_ledger_hash runtime_field
  mspl_require_env MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256 MSPL_COVERAGE_SOURCE_BUNDLE_SHA256 \
    MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256 MSPL_COVERAGE_HELPER_SHA256 \
    MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256 MSPL_COVERAGE_MANIFEST_SHA256
  aggregate="$MSPL_COVERAGE_ROOT/gates/gate4-prerun-receipt.txt"
  ledger="$MSPL_COVERAGE_ROOT/gates/gate4-shard-hashes.sha256"
  [[ -s "$receipt" ]] || mspl_die "Production blocked: Gate 4 ready receipt is absent or empty: $receipt"
  [[ -s "$aggregate" ]] || mspl_die "Production blocked: staged Gate 4 aggregate receipt is absent: $aggregate"
  awk '$0 == "launcher_unlock_eligible: FALSE" { found += 1 } END { exit found == 1 ? 0 : 2 }' "$aggregate" ||
    mspl_die "Gate 4 statistical aggregate must be explicitly launcher-unlock-ineligible."
  mspl_validate_gate4_shard_hash_ledger "$ledger"
  manifest_hash="$(mspl_sha256 "$MSPL_COVERAGE_ROOT/manifest.csv")"
  aggregate_hash="$(mspl_sha256 "$aggregate")"
  shard_ledger_hash="$(mspl_sha256 "$ledger")"
  [[ "$manifest_hash" == "$MSPL_COVERAGE_MANIFEST_SHA256" ]] || mspl_die "Production blocked: live manifest hash disagrees with runtime binding."
  case "$MSPL_COVERAGE_CLUSTER" in
    nibi) runtime_field=nibi_runtime_archive_sha256 ;;
    narval) runtime_field=narval_runtime_archive_sha256 ;;
    *) mspl_die "Production unlock is defined only for nibi or narval." ;;
  esac
  awk -F= \
    -v campaign="$MSPL_COVERAGE_CAMPAIGN_ID" -v source="$MSPL_COVERAGE_SOURCE_SHA" \
    -v manifest="$manifest_hash" -v source_archive="$MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256" \
    -v source_bundle="$MSPL_COVERAGE_SOURCE_BUNDLE_SHA256" -v launcher_bundle="$MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256" \
    -v helper="$MSPL_COVERAGE_HELPER_SHA256" -v cluster="$MSPL_COVERAGE_CLUSTER" \
    -v aggregate="$aggregate_hash" -v shard_ledger="$shard_ledger_hash" \
    -v runtime_field="$runtime_field" -v runtime_hash="$MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256" '
    BEGIN {
      expected["receipt_type"] = "gate4-prerun-ready-v1"; expected["gate_status"] = "PASS"
      expected["campaign_id"] = campaign; expected["source_sha"] = source; expected["manifest_sha256"] = manifest
      expected["source_archive_sha256"] = source_archive; expected["source_bundle_sha256"] = source_bundle
      expected["launcher_bundle_sha256"] = launcher_bundle; expected["launcher_helper_sha256"] = helper
      expected["gate4_prerun_receipt_sha256"] = aggregate; expected["gate4_shard_ledger_sha256"] = shard_ledger
      expected["nibi_runtime_archive_sha256"] = "__sha256__"
      expected["narval_runtime_archive_sha256"] = "__sha256__"
      expected[runtime_field] = runtime_hash
      expected["case_count"] = "12"; expected["shard_count"] = "12"; expected["outer_fit_rows"] = "120"
      expected["bootstrap_attempt_rows"] = "60000"; expected["endpoint_rows"] = "1080"
      expected["calibration_gate_eligible"] = "FALSE"; expected["launcher_unlock_eligible"] = "TRUE"
      expected["approved_by"] = "maintainer"; expected["approved_at_utc"] = "__utc__"
    }
    {
      key = $1; value = $2
      if (NF != 2 || key !~ /^[a-z][a-z0-9_]*$/ || value !~ /^[A-Za-z0-9._:+-]+$/ || !(key in expected) || seen[key]++) invalid = 1
      else if (expected[key] == "__sha256__" && (length(value) != 64 || value !~ /^[0-9a-f]+$/)) invalid = 1
      else if (expected[key] == "__utc__" && value !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/) invalid = 1
      else if (expected[key] != "__sha256__" && expected[key] != "__utc__" && value != expected[key]) invalid = 1
    }
    END { for (key in expected) if (seen[key] != 1) invalid = 1; if (NR != 22) invalid = 1; exit invalid ? 2 : 0 }
  ' "$receipt" || mspl_die "Production blocked: Gate 4 ready receipt has missing, duplicate, unknown, unsafe, stale, or mismatched provenance fields."
}

mspl_require_gate_receipt() {
  local stage="${MSPL_COVERAGE_STAGE:-production}" receipt
  mspl_validate_manifest_binding
  case "$stage" in
    pre-run)
      receipt="$MSPL_COVERAGE_ROOT/gates/gate3-ready.receipt"
      mspl_validate_gate3_ready_receipt "$receipt"
      ;;
    production)
      receipt="$MSPL_COVERAGE_ROOT/gates/gate4-prerun-ready.receipt"
      mspl_validate_gate4_ready_receipt "$receipt"
      ;;
    *) mspl_die "MSPL_COVERAGE_STAGE must be pre-run or production." ;;
  esac
}

mspl_validate_production_manifest() {
  local manifest="${1:-$MSPL_COVERAGE_ROOT/manifest.csv}"
  [[ -f "$manifest" ]] || mspl_die "Missing production manifest: $manifest"
  awk '
    function clean(x) { gsub(/^"|"$/, "", x); return x }
    NR == 1 {
      header_count = split($0, field, ",")
      for (i = 1; i <= header_count; i++) {
        name = clean(field[i]); column[name] = i; header_seen[name] += 1
        if (name !~ /^[A-Za-z][A-Za-z0-9_]*$/) invalid = 1
      }
      required = "case_id case_number regime link beta_shift lambda_scale seed_base n_outer bootstrap_reps minimum_usable_bootstrap outer_per_shard n_shards assigned_cluster availability_min coverage_wilson_level coverage_equivalence_lower coverage_equivalence_upper wald_min_available manifest_version campaign_id source_sha"
      required_count = split(required, required_name, " ")
      for (i = 1; i <= required_count; i++) if (header_seen[required_name[i]] != 1) invalid = 1
      next
    }
    {
      n = split($0, field, ",")
      row = NR - 1
      if (n != header_count || row > 12) invalid = 1
      for (i = 1; i <= n; i++) {
        field[i] = clean(field[i])
        if (field[i] !~ /^[A-Za-z0-9._-]+$/) invalid = 1
      }
      expected_case = sprintf("C%03d", row)
      regime_index = ((row - 1) % 4) + 1
      expected_regime = (regime_index == 1 ? "baseline" : (regime_index == 2 ? "low_prevalence" : (regime_index == 3 ? "high_prevalence" : "strong_signal")))
      expected_link = (row <= 4 ? "logit" : (row <= 8 ? "probit" : "cloglog"))
      expected_beta = (regime_index == 2 ? -1.5 : (regime_index == 3 ? 1.5 : 0))
      expected_lambda = (regime_index == 4 ? 1.75 : 1)
      expected_cluster = (row <= 6 || row == 11 ? "nibi" : "narval")
      if (field[column["case_id"]] != expected_case || field[column["case_number"]] + 0 != row ||
          field[column["regime"]] != expected_regime || field[column["link"]] != expected_link ||
          field[column["beta_shift"]] + 0 != expected_beta || field[column["lambda_scale"]] + 0 != expected_lambda ||
          field[column["seed_base"]] + 0 != 1900000000 + row * 10000000 ||
          field[column["n_outer"]] + 0 != 1000 || field[column["bootstrap_reps"]] + 0 != 500 ||
          field[column["minimum_usable_bootstrap"]] + 0 != 475 || field[column["outer_per_shard"]] + 0 != 10 ||
          field[column["n_shards"]] + 0 != 100 || field[column["assigned_cluster"]] != expected_cluster ||
          field[column["availability_min"]] + 0 != 0.95 || field[column["coverage_wilson_level"]] + 0 != 0.90 ||
          field[column["coverage_equivalence_lower"]] + 0 != 0.92 || field[column["coverage_equivalence_upper"]] + 0 != 0.98 ||
          field[column["wald_min_available"]] + 0 != 500 ||
          field[column["manifest_version"]] != "lane-b-mspl-coverage-gate0-v1-2026-08-14") invalid = 1
      campaign = field[column["campaign_id"]]; source = field[column["source_sha"]]
      if (row == 1) { frozen_campaign = campaign; frozen_source = source }
      if (campaign == "" || source == "" || campaign != frozen_campaign || source != frozen_source) invalid = 1
    }
    END { if (NR != 13) invalid = 1; exit invalid ? 2 : 0 }
  ' "$manifest" || mspl_die "Array execution requires the exact 12-row production manifest; smoke, mini, test, mixed-version, or downgraded manifests are forbidden."
}

mspl_validate_prerun_map() {
  local map="$1"
  awk '
    NR == FNR {
      n = split($0, field, ",")
      if (FNR == 1) {
        for (i = 1; i <= n; i++) {
          gsub(/^"|"$/, "", field[i])
          if (field[i] == "case_id") case_column = i
          if (field[i] == "outer_per_shard") outer_column = i
        }
        next
      }
      case_id = field[case_column]; outer = field[outer_column]
      gsub(/^"|"$/, "", case_id); gsub(/^"|"$/, "", outer)
      manifest_cases[case_id] += 1
      manifest_rows += 1
      if (outer != 10) invalid = 1
      next
    }
    FNR == 1 {
      n = split($0, field, "\t")
      if (n != 3 || field[1] != "array_index" || field[2] != "case_id" || field[3] != "shard_id") invalid = 1
      next
    }
    {
      n = split($0, field, "\t")
      if (n != 3 || field[1] !~ /^[1-9][0-9]*$/ || field[2] !~ /^C[0-9][0-9][0-9]$/ || field[3] != 1) invalid = 1
      map_indices[field[1]] += 1
      map_cases[field[2]] += 1
      map_rows += 1
    }
    END {
      if (!case_column || !outer_column || manifest_rows != 12 || map_rows != 12) invalid = 1
      for (case_id in manifest_cases) if (manifest_cases[case_id] != 1 || map_cases[case_id] != 1) invalid = 1
      for (case_id in map_cases) if (!(case_id in manifest_cases) || map_cases[case_id] != 1) invalid = 1
      for (i = 1; i <= 12; i++) if (map_indices[i] != 1) invalid = 1
      exit invalid ? 2 : 0
    }
  ' "$MSPL_COVERAGE_ROOT/manifest.csv" "$map" || mspl_die "Gate 4 pre-run map must be exactly 12 unique manifest cases, shard_id=1, indices 1:12, with outer_per_shard=10."
}

mspl_validate_remaining_production_map() {
  local map="$1"
  awk -F '\t' '
    NR == 1 {
      if (NF != 3 || $1 != "array_index" || $2 != "case_id" || $3 != "shard_id") invalid = 1
      next
    }
    {
      row = NR - 1
      expected_case = sprintf("C%03d", int((row - 1) / 99) + 1)
      expected_shard = ((row - 1) % 99) + 2
      if (NF != 3 || $1 != row || $2 != expected_case || $3 != expected_shard) invalid = 1
    }
    END { if (NR != 1189) invalid = 1; exit invalid ? 2 : 0 }
  ' "$map" || mspl_die "Production map must be exactly 1,188 ordered remaining keys: C001..C012, shards 002..100, indices 1:1188."
}

mspl_remaining_cluster_contract() {
  case "$1" in
    nibi) printf 'C001,C002,C003,C004,C005,C006,C011\t693\n' ;;
    narval) printf 'C007,C008,C009,C010,C012\t495\n' ;;
    *) mspl_die "Remaining-production contract supports nibi or narval only." ;;
  esac
}

mspl_array_task() {
  local stage="${MSPL_COVERAGE_STAGE:-production}" map row index case_id shard_id cluster
  mspl_validate_manifest_binding
  case "$stage" in
    pre-run|production) mspl_validate_production_manifest ;;
    smoke) ;;
    *) mspl_die "MSPL_COVERAGE_STAGE must be smoke, pre-run, or production." ;;
  esac
  case "$stage" in
    smoke) map="${MSPL_COVERAGE_ARRAY_MAP:-$MSPL_COVERAGE_ROOT/array-map.tsv}" ;;
    pre-run) map="${MSPL_COVERAGE_ARRAY_MAP:-$MSPL_COVERAGE_ROOT/pre-run-array-map.tsv}" ;;
    production) map="${MSPL_COVERAGE_ARRAY_MAP:-$MSPL_COVERAGE_ROOT/remaining-production-array-map.tsv}" ;;
  esac
  [[ -f "$map" ]] || mspl_die "Missing runner-produced frozen array map: $map"
  if [[ "$stage" == "pre-run" ]]; then mspl_validate_prerun_map "$map"; fi
  if [[ "$stage" == "production" ]]; then mspl_validate_remaining_production_map "$map"; fi
  IFS=$'\t' read -r -a _mspl_header < "$map"
  [[ "${_mspl_header[*]}" == "array_index case_id shard_id" ]] || mspl_die "array-map.tsv header must be array_index<TAB>case_id<TAB>shard_id."
  index="${SLURM_ARRAY_TASK_ID:-}"
  [[ "$index" =~ ^[1-9][0-9]*$ ]] || mspl_die "SLURM_ARRAY_TASK_ID must be a positive integer."
  row="$(awk -F '\t' -v wanted="$index" '$1 == wanted {print $0; found = 1; exit} END {if (!found) exit 2}' "$map")" || mspl_die "No manifest row for array task $index."
  IFS=$'\t' read -r index case_id shard_id <<< "$row"
  [[ "$case_id" =~ ^C[0-9]{3}$ && "$shard_id" =~ ^[1-9][0-9]*$ ]] || mspl_die "Malformed mapping row: $row"
  cluster="$(mspl_manifest_case_field "$MSPL_COVERAGE_ROOT/manifest.csv" "$case_id" assigned_cluster)" ||
    mspl_die "Could not read the unique assigned_cluster for case $case_id from manifest.csv."
  [[ "$cluster" == "$MSPL_COVERAGE_CLUSTER" ]] || mspl_die "Runner task assignment rejects case $case_id on $MSPL_COVERAGE_CLUSTER (manifest assigns ${cluster:-none})."
  printf '%s\t%s\n' "$case_id" "$shard_id"
}

mspl_publish_rds_shard() {
  local case_id="$1" shard_id="$2" local_rds="$3" stem destination temporary
  stem="$(printf '%s-shard-%03d' "$case_id" "$shard_id")"
  destination="$MSPL_COVERAGE_ROOT/shards/${stem}.rds"
  temporary="$MSPL_COVERAGE_ROOT/shards/.${stem}.${SLURM_JOB_ID:-manual}.${SLURM_ARRAY_TASK_ID:-0}.tmp"
  [[ -f "$local_rds" ]] || mspl_die "Runner did not create the expected compressed RDS shard: $local_rds"
  mkdir -p "$MSPL_COVERAGE_ROOT/shards"
  [[ ! -e "$destination" ]] || mspl_die "Refusing to replace an existing immutable shard: $destination"
  cp "$local_rds" "$temporary"
  mv "$temporary" "$destination"
  printf '%s\n' "$destination"
}
