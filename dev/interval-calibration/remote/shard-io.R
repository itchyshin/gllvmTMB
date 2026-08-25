## Orchestration-only helpers for immutable interval-calibration campaign shards.
## This file does not define a DGP, fit, estimand, interval, or promotion rule.

interval_stop <- function(...) stop(..., call. = FALSE)

interval_runtime_packages <- c(
  "assertthat", "cli", "fmesher", "generics", "lifecycle",
  "rlang", "tidyselect", "TMB", "BH", "RcppEigen", "Matrix", "ape"
)

interval_assert_runtime_dependencies <- function(
  required = interval_runtime_packages,
  available = requireNamespace,
  version = utils::packageVersion
) {
  required <- unique(as.character(required))
  if (!length(required) || any(!nzchar(required))) {
    interval_stop("runtime dependency list must contain package names")
  }
  present <- vapply(
    required,
    function(package) isTRUE(available(package, quietly = TRUE)),
    logical(1)
  )
  missing <- required[!present]
  if (length(missing)) {
    interval_stop(
      "missing campaign runtime dependencies: ",
      paste(missing, collapse = ", ")
    )
  }
  stats::setNames(
    vapply(required, function(package) as.character(version(package)), character(1)),
    required
  )
}

interval_validate_post_guard_receipt <- function(receipt, task_manifest) {
  required_fields <- c(
    "schema",
    "packet",
    "cell_id",
    "rep",
    "seed",
    "scientific_source_sha",
    "environment_valid",
    "runtime_dependencies",
    "scientific_outcome",
    "canonical_action"
  )
  if (!is.list(receipt) || any(!required_fields %in% names(receipt))) {
    interval_stop("post-guard receipt is incomplete")
  }
  if (
    !identical(
      receipt$schema,
      "INTERVAL_CALIBRATION_POST_GUARD_RECEIPT_V1"
    )
  ) {
    interval_stop("post-guard receipt has the wrong schema")
  }
  if (
    !is.data.frame(task_manifest) ||
      any(!c("packet", "cell_id", "rep", "seed") %in% names(task_manifest))
  ) {
    interval_stop("post-guard validation requires a task manifest")
  }
  packet <- toupper(interval_scalar_string(receipt$packet, "packet"))
  cell_id <- interval_scalar_integer(receipt$cell_id, "cell_id")
  rep <- interval_scalar_integer(receipt$rep, "rep")
  seed <- interval_scalar_integer(receipt$seed, "seed")
  if (
    !identical(receipt$environment_valid, TRUE) ||
      !all(interval_runtime_packages %in% names(receipt$runtime_dependencies))
  ) {
    interval_stop(
      "post-guard receipt did not pass the complete environment gate"
    )
  }
  if (
    !identical(
      receipt$scientific_source_sha,
      interval_approved_source(packet)
    )
  ) {
    interval_stop("post-guard receipt uses an unapproved scientific source")
  }
  interval_scalar_string(receipt$scientific_outcome, "scientific_outcome")
  action <- interval_scalar_string(receipt$canonical_action, "canonical_action")
  hit <-
    task_manifest$packet == packet &
    task_manifest$cell_id == cell_id &
    task_manifest$rep == rep
  if (any(hit)) {
    if (
      sum(hit) != 1L || !identical(as.integer(task_manifest$seed[hit]), seed)
    ) {
      interval_stop("post-guard campaign identity conflicts with its manifest")
    }
    if (!identical(action, "import")) {
      interval_stop(
        "post-guard campaign identity must be imported as canonical"
      )
    }
  } else if (!identical(action, "preflight_only")) {
    interval_stop("out-of-manifest post-guard identity must be preflight_only")
  }
  invisible(TRUE)
}

interval_reconcile_cross_root_attempts <- function(attempts) {
  required <- c(
    "packet",
    "cell_id",
    "rep",
    "seed",
    "root_class",
    "environment_valid",
    "completed_at"
  )
  if (!is.data.frame(attempts) || any(!required %in% names(attempts))) {
    interval_stop("cross-root attempts lack required provenance columns")
  }
  if (!nrow(attempts)) {
    interval_stop("cross-root attempt ledger cannot be empty")
  }
  keys <- paste(
    attempts$packet,
    attempts$cell_id,
    attempts$rep,
    attempts$seed,
    sep = "::"
  )
  valid <- !is.na(attempts$environment_valid) & attempts$environment_valid
  canonical <- rep(FALSE, nrow(attempts))
  for (key in unique(keys)) {
    candidates <- which(keys == key & valid)
    if (length(candidates)) {
      first <- candidates[which.min(attempts$completed_at[candidates])]
      canonical[first] <- TRUE
    }
  }
  disposition <- ifelse(
    !valid,
    "infrastructure_excluded",
    ifelse(canonical, "canonical", "duplicate_excluded")
  )
  operational <- attempts
  operational$disposition <- disposition
  list(
    operational = operational,
    canonical = operational[canonical, , drop = FALSE]
  )
}

interval_scalar_integer <- function(x, name, lower = 1L) {
  value <- suppressWarnings(as.integer(x))
  if (length(value) != 1L || is.na(value) || value < lower) {
    interval_stop(name, " must be one integer >= ", lower)
  }
  value
}

interval_scalar_string <- function(x, name) {
  if (!is.character(x) || length(x) != 1L || !nzchar(x)) {
    interval_stop(name, " must be one non-empty string")
  }
  x
}

interval_approved_source <- function(packet) {
  packet <- toupper(interval_scalar_string(packet, "packet"))
  switch(
    packet,
    PVT02 = "1d4e03d926f78a244257d03c3a0669549c0eceac",
    CI09 = "822024b1bd31a90a9dbe211ad09e1b26b2030ac8",
    CI10_COST = "328d8abc9125ce1e7edbcdcdcb1a41f043488431",
    CI13 = "39ab3b2983560fd3dea7bdfee124144d203cba2e",
    CI14 = "328d8abc9125ce1e7edbcdcdcb1a41f043488431",
    CI15 = "328d8abc9125ce1e7edbcdcdcb1a41f043488431",
    interval_stop("unknown approved packet: ", packet)
  )
}

interval_atomic_save_rds <- function(object, path) {
  path <- normalizePath(path, mustWork = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(path)) {
    interval_stop("refusing to overwrite immutable shard: ", path)
  }
  temporary <- tempfile(
    pattern = paste0(".", basename(path), "."),
    tmpdir = dirname(path)
  )
  on.exit(unlink(temporary), add = TRUE)
  saveRDS(object, temporary, version = 3L)
  check <- readRDS(temporary)
  if (!identical(check, object)) {
    interval_stop("RDS round-trip changed campaign shard payload")
  }
  if (!file.rename(temporary, path)) {
    interval_stop("atomic shard rename failed: ", path)
  }
  invisible(path)
}

interval_git_output <- function(args, source_root = ".") {
  out <- system2(
    "git",
    c("-C", source_root, args),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    interval_stop("git provenance check failed: ", paste(out, collapse = "\n"))
  }
  out
}

interval_assert_clean_checkout <- function(source_root = ".") {
  dirty <- interval_git_output(
    c("status", "--porcelain", "--untracked-files=all"),
    source_root
  )
  if (length(dirty)) {
    interval_stop(
      "orchestration checkout is not clean; refusing runtime drift:\n",
      paste(dirty, collapse = "\n")
    )
  }
  invisible(TRUE)
}

interval_assert_frozen_source <- function(
  scientific_source_sha,
  scientific_paths,
  source_root = "."
) {
  interval_assert_clean_checkout(source_root)
  scientific_source_sha <- interval_scalar_string(
    scientific_source_sha,
    "scientific_source_sha"
  )
  scientific_paths <- unique(as.character(scientific_paths))
  if (!length(scientific_paths) || any(!nzchar(scientific_paths))) {
    interval_stop("scientific_paths must name the frozen scientific files")
  }
  resolved <- interval_git_output(
    c("rev-parse", paste0(scientific_source_sha, "^{commit}")),
    source_root
  )
  if (!identical(trimws(resolved[[1L]]), scientific_source_sha)) {
    interval_stop("scientific source SHA is not the exact frozen commit")
  }
  diff <- system2(
    "git",
    c(
      "-C",
      source_root,
      "diff",
      "--quiet",
      scientific_source_sha,
      "--",
      scientific_paths
    ),
    stdout = FALSE,
    stderr = FALSE
  )
  if (!identical(diff, 0L)) {
    interval_stop(
      "scientific paths differ from frozen source ",
      scientific_source_sha
    )
  }
  checkout_sha <- trimws(interval_git_output(c("rev-parse", "HEAD"), source_root)[[1L]])
  list(
    scientific_source_sha = scientific_source_sha,
    checkout_sha = checkout_sha,
    scientific_paths = scientific_paths
  )
}

interval_assert_installed_package <- function(scientific_source_sha) {
  package_path <- tryCatch(
    find.package("gllvmTMB"),
    error = function(e) interval_stop("gllvmTMB is not installed in the campaign library")
  )
  marker <- file.path(package_path, ".interval-scientific-source-sha")
  if (!file.exists(marker)) {
    interval_stop("installed gllvmTMB lacks its campaign source marker")
  }
  installed_sha <- trimws(readLines(marker, warn = FALSE))
  if (!identical(installed_sha, scientific_source_sha)) {
    interval_stop("installed gllvmTMB was not built from the frozen scientific source")
  }
  list(
    package_path = normalizePath(package_path, mustWork = TRUE),
    source_marker = normalizePath(marker, mustWork = TRUE),
    installed_source_sha = installed_sha,
    package_version = as.character(utils::packageVersion("gllvmTMB"))
  )
}

interval_sha256_file <- function(path) {
  path <- normalizePath(path, mustWork = TRUE)
  out <- system2("sha256sum", path, stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    interval_stop("sha256sum failed for ", path, ": ", paste(out, collapse = "\n"))
  }
  sub("[[:space:]].*$", "", out[[1L]])
}

interval_directory_sha256 <- function(path) {
  path <- normalizePath(path, mustWork = TRUE)
  files <- sort(list.files(
    path,
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE,
    no.. = TRUE
  ))
  files <- files[!file.info(files)$isdir]
  relative <- substring(files, nchar(path) + 2L)
  stats::setNames(vapply(files, interval_sha256_file, character(1)), relative)
}

interval_validate_checksum_manifest <- function(root, files) {
  checksum_path <- file.path(root, "canonical-checksums.sha256")
  if (!file.exists(checksum_path)) {
    interval_stop("campaign root lacks canonical-checksums.sha256")
  }
  lines <- readLines(checksum_path, warn = FALSE)
  if (length(lines) != length(files)) {
    interval_stop("canonical checksum count does not match canonical shard count")
  }
  manifest_files <- sub("^[0-9a-f]{64}[[:space:]]+", "", lines)
  expected_files <- file.path("canonical", basename(files))
  if (
    any(!grepl("^[0-9a-f]{64}[[:space:]]+canonical/[^/]+[.]rds$", lines)) ||
      anyDuplicated(manifest_files) ||
      !setequal(manifest_files, expected_files)
  ) {
    interval_stop("checksum manifest filenames do not equal the canonical shard set")
  }
  old <- setwd(root)
  on.exit(setwd(old), add = TRUE)
  checked <- system2(
    "sha256sum",
    c("-c", "canonical-checksums.sha256"),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(checked, "status")
  if (!is.null(status) && status != 0L) {
    interval_stop("canonical checksum validation failed: ", paste(checked, collapse = "\n"))
  }
  invisible(checksum_path)
}

interval_extract_assignment <- function(script, name, envir) {
  expr <- parse(script)
  hit <- vapply(expr, function(x) {
    is.call(x) &&
      identical(x[[1L]], as.name("<-")) &&
      identical(x[[2L]], as.name(name))
  }, logical(1))
  if (sum(hit) != 1L) {
    interval_stop("expected exactly one assignment to ", name, " in ", script)
  }
  eval(expr[[which(hit)]], envir = envir)
  invisible(envir[[name]])
}

interval_shard_stem <- function(packet, cell_id, rep) {
  packet <- tolower(gsub("[^A-Za-z0-9]+", "-", packet))
  sprintf("%s-c%02d-r%05d", packet, as.integer(cell_id), as.integer(rep))
}

interval_canonical_payload <- function(
  packet,
  cell_id,
  rep,
  seed,
  scientific_provenance,
  attempt,
  runtime_seconds,
  runner_provenance = list(),
  attempt_version = 1L
) {
  list(
    schema = "INTERVAL_CALIBRATION_CANONICAL_SHARD_V1",
    packet = interval_scalar_string(packet, "packet"),
    cell_id = interval_scalar_integer(cell_id, "cell_id"),
    rep = interval_scalar_integer(rep, "rep"),
    attempt_version = interval_scalar_integer(
      attempt_version,
      "attempt_version"
    ),
    seed = interval_scalar_integer(seed, "seed"),
    scientific_provenance = scientific_provenance,
    attempt = attempt,
    runtime_seconds = as.numeric(runtime_seconds),
    runner_provenance = runner_provenance,
    completed_at = Sys.time()
  )
}

interval_operational_failure <- function(
  packet,
  cell_id,
  rep,
  attempt_version,
  scientific_source_sha,
  message,
  stage
) {
  list(
    schema = "INTERVAL_CALIBRATION_OPERATIONAL_FAILURE_V1",
    packet = packet,
    cell_id = as.integer(cell_id),
    rep = as.integer(rep),
    attempt_version = as.integer(attempt_version),
    scientific_source_sha = scientific_source_sha,
    message = as.character(message),
    stage = as.character(stage),
    failed_at = Sys.time()
  )
}
