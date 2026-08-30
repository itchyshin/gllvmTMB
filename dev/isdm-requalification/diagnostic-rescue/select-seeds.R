## Verify immutable production evidence and select deterministic sentinels.
## Sourcing defines helpers only; direct Rscript execution runs the CLI.

.ISDM_DIAG_SELECT_FILE <- local({
  current <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (is.null(current) || !nzchar(current)) {
    script <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
    candidates <- c(
      if (length(script) == 1L) sub("^--file=", "", script) else character(),
      file.path("dev", "isdm-requalification", "diagnostic-rescue",
                "select-seeds.R"),
      file.path("..", "..", "dev", "isdm-requalification",
                "diagnostic-rescue", "select-seeds.R"),
      "select-seeds.R"
    )
    existing <- candidates[file.exists(candidates)]
    current <- if (length(existing)) existing[[1L]] else "select-seeds.R"
  }
  normalizePath(current, mustWork = TRUE)
})
.ISDM_DIAG_SELECT_DIR <- dirname(.ISDM_DIAG_SELECT_FILE)
source(file.path(.ISDM_DIAG_SELECT_DIR, "contract.R"), local = TRUE)
source(file.path(.ISDM_DIAG_SELECT_DIR, "..", "contract.R"), local = TRUE)

isdm_diag_sha256 <- function(path) {
  path <- normalizePath(path, mustWork = TRUE)
  command <- if (nzchar(Sys.which("sha256sum"))) "sha256sum" else "shasum"
  args <- if (command == "shasum") c("-a", "256", shQuote(path)) else
    shQuote(path)
  value <- system2(command, args, stdout = TRUE, stderr = TRUE)
  status <- attr(value, "status")
  if (is.null(status)) status <- 0L
  hash <- sub("[[:space:]].*$", "", value[[1L]])
  if (as.integer(status) != 0L || !grepl("^[[:xdigit:]]{64}$", hash)) {
    .isdm_diag_abort("SHA-256 command failed", "isdm_diag_hash_failed")
  }
  tolower(hash)
}

.isdm_diag_verify_hash <- function(path, expected, class) {
  observed <- isdm_diag_sha256(path)
  if (!identical(observed, tolower(expected))) {
    .isdm_diag_abort(
      sprintf("SHA-256 mismatch for %s", basename(path)), class
    )
  }
  observed
}

.isdm_diag_manifest_map <- function(path) {
  lines <- readLines(path, warn = FALSE)
  matched <- regexec("^([[:xdigit:]]{64})[[:space:]]+(.+)$", lines)
  pieces <- regmatches(lines, matched)
  if (!length(lines) || any(lengths(pieces) != 3L)) {
    .isdm_diag_abort("raw manifest contains malformed rows",
                     "isdm_diag_raw_manifest_invalid")
  }
  hashes <- tolower(vapply(pieces, `[[`, character(1L), 2L))
  names(hashes) <- vapply(pieces, `[[`, character(1L), 3L)
  if (anyDuplicated(names(hashes))) {
    .isdm_diag_abort("raw manifest contains duplicate paths",
                     "isdm_diag_raw_manifest_invalid")
  }
  hashes
}

isdm_diag_verify_production <- function(production_dir,
                                        source_contract_path = NULL) {
  production_dir <- normalizePath(production_dir, mustWork = TRUE)
  if (is.null(source_contract_path)) {
    source_contract_path <- file.path(
      dirname(production_dir), "receipts", "source-contract.rds"
    )
  }
  source_contract_path <- normalizePath(source_contract_path, mustWork = TRUE)
  raw_path <- file.path(production_dir, "raw-manifest-sha256.txt")
  chain_path <- file.path(production_dir, "v3-manifest-sha256.txt")
  adjudication_path <- file.path(production_dir, "adjudication-v3.rds")
  if (!all(file.exists(c(raw_path, chain_path, adjudication_path)))) {
    .isdm_diag_abort("production binding files are missing",
                     "isdm_diag_production_binding_missing")
  }
  raw_hash <- .isdm_diag_verify_hash(
    raw_path, ISDM_DIAG_RAW_MANIFEST_SHA256,
    "isdm_diag_raw_manifest_hash_mismatch"
  )
  chain_hash <- .isdm_diag_verify_hash(
    chain_path, ISDM_DIAG_CHAIN_MANIFEST_SHA256,
    "isdm_diag_chain_manifest_hash_mismatch"
  )
  adjudication_hash <- .isdm_diag_verify_hash(
    adjudication_path, ISDM_DIAG_ADJUDICATION_V3_SHA256,
    "isdm_diag_adjudication_hash_mismatch"
  )
  capture <- tempfile("isdm-diag-manifest-check-")
  on.exit(unlink(capture), add = TRUE)
  checked <- system2("sha256sum", c("-c", shQuote(raw_path)),
                     stdout = capture, stderr = capture)
  status <- if (is.numeric(checked) && length(checked) == 1L) checked else
    attr(checked, "status")
  if (is.null(status)) status <- 0L
  if (as.integer(status) != 0L) {
    .isdm_diag_abort("frozen raw production manifest verification failed",
                     "isdm_diag_raw_manifest_verification_failed")
  }
  source_contract <- readRDS(source_contract_path)
  if (!is.list(source_contract) ||
      !identical(source_contract$source_sha, ISDM_DIAG_PRODUCTION_SOURCE_SHA) ||
      !identical(source_contract$source_tree, ISDM_DIAG_PRODUCTION_SOURCE_TREE)) {
    .isdm_diag_abort("source contract does not match frozen production pin",
                     "isdm_diag_source_mismatch")
  }
  list(
    production_dir = production_dir,
    source_contract_path = source_contract_path,
    source_contract = source_contract,
    raw_manifest_path = raw_path,
    raw_manifest_sha256 = raw_hash,
    raw_manifest_entries = .isdm_diag_manifest_map(raw_path),
    chain_manifest_sha256 = chain_hash,
    adjudication_v3_sha256 = adjudication_hash
  )
}

.isdm_diag_record_path <- function(production_dir, task_id) {
  file.path(production_dir, "attempts", sprintf("task-%06d.rds", task_id))
}

.isdm_diag_record_hash <- function(path, binding) {
  expected <- binding$raw_manifest_entries[[normalizePath(path, mustWork = TRUE)]]
  if (is.null(expected)) {
    .isdm_diag_abort("attempt is absent from the frozen raw manifest",
                     "isdm_diag_record_unbound")
  }
  .isdm_diag_verify_hash(path, expected, "isdm_diag_record_hash_mismatch")
}

.isdm_diag_index_record <- function(spec, binding) {
  task_id <- as.integer(spec$task_id[[1L]])
  path <- .isdm_diag_record_path(binding$production_dir, task_id)
  if (!file.exists(path)) {
    .isdm_diag_abort(sprintf("production attempt %d is missing", task_id),
                     "isdm_diag_record_missing")
  }
  hash <- .isdm_diag_record_hash(path, binding)
  record <- readRDS(path)
  keys <- names(spec)
  spec_ok <- is.list(record$task_spec) && all(vapply(keys, function(key) {
    identical(record$task_spec[[key]], spec[[key]][[1L]])
  }, logical(1L)))
  if (!spec_ok || !identical(record$task_id, task_id) ||
      !identical(record$seed, as.integer(spec$seed[[1L]]))) {
    .isdm_diag_abort("terminal record differs from its native task specification",
                     "isdm_diag_task_spec_mismatch")
  }
  if (!identical(record$source_sha, ISDM_DIAG_PRODUCTION_SOURCE_SHA) ||
      !identical(record$source_tree, ISDM_DIAG_PRODUCTION_SOURCE_TREE)) {
    .isdm_diag_abort("terminal record source differs from the frozen pin",
                     "isdm_diag_source_mismatch")
  }
  data.frame(
    task_id = task_id,
    programme = as.character(spec$programme[[1L]]),
    n_sources = as.integer(spec$n_sources[[1L]]),
    overlap = as.character(spec$overlap[[1L]]),
    n_cells = as.integer(spec$n_cells[[1L]]),
    pair_id = if ("pair_id" %in% names(spec)) as.integer(spec$pair_id[[1L]]) else
      NA_integer_,
    structure_seed = if ("structure_seed" %in% names(spec))
      as.integer(spec$structure_seed[[1L]]) else NA_integer_,
    seed = as.integer(spec$seed[[1L]]),
    status = as.character(record$status),
    convergence = as.integer(record$diagnostics$convergence),
    pd_hessian = as.logical(record$diagnostics$pd_hessian),
    source_sha = as.character(record$source_sha),
    source_tree = as.character(record$source_tree),
    record_sha256 = hash,
    stringsAsFactors = FALSE
  )
}

.isdm_diag_candidate_specs <- function() {
  ordinary <- isdm_point_plan("ordinary")
  spatial <- isdm_point_plan("spatial")
  ordinary_index <- ordinary
  ordinary_index$status <- "fit_returned"
  ordinary_index$convergence <- 0L
  ordinary_index$pd_hessian <- TRUE
  ordinary_index$source_sha <- ISDM_DIAG_PRODUCTION_SOURCE_SHA
  ordinary_index$source_tree <- ISDM_DIAG_PRODUCTION_SOURCE_TREE
  ordinary_index$record_sha256 <- rep(strrep("0", 64L), nrow(ordinary_index))
  selected <- isdm_diag_select_nonspatial(ordinary_index)
  list(
    nonspatial = ordinary[match(selected$task_id, ordinary$task_id), , drop = FALSE],
    spatial = spatial
  )
}

isdm_diag_build_seed_manifest <- function(production_dir,
                                          source_contract_path = NULL) {
  binding <- isdm_diag_verify_production(production_dir, source_contract_path)
  candidates <- .isdm_diag_candidate_specs()
  nonsp_index <- do.call(rbind, lapply(seq_len(nrow(candidates$nonspatial)),
    function(i) .isdm_diag_index_record(candidates$nonspatial[i, , drop = FALSE],
                                        binding)))
  spatial_index <- do.call(rbind, lapply(seq_len(nrow(candidates$spatial)),
    function(i) .isdm_diag_index_record(candidates$spatial[i, , drop = FALSE],
                                        binding)))
  nonspatial <- isdm_diag_select_nonspatial(nonsp_index)
  spatial <- isdm_diag_select_spatial(spatial_index)
  manifest <- list(
    schema = ISDM_DIAG_SEED_MANIFEST_SCHEMA,
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    selection_rule = list(
      nonspatial = "smallest common pair_id per n_sources and n_cells",
      spatial = paste(
        "smallest seed per n_sources, overlap, and outcome class:",
        "converged_pd, converged_nonpd, nonconverged_nonpd"
      )
    ),
    production_binding = list(
      production_dir = binding$production_dir,
      source_sha = binding$source_contract$source_sha,
      source_tree = binding$source_contract$source_tree,
      raw_manifest_sha256 = binding$raw_manifest_sha256,
      chain_manifest_sha256 = binding$chain_manifest_sha256,
      adjudication_v3_sha256 = binding$adjudication_v3_sha256
    ),
    nonspatial = nonspatial,
    spatial = spatial
  )
  diagnostic_plan(manifest)
  manifest
}

isdm_diag_write_seed_manifest <- function(manifest, output_path) {
  diagnostic_plan(manifest)
  output_path <- path.expand(output_path)
  if (file.exists(output_path) || file.exists(paste0(output_path, ".sha256"))) {
    .isdm_diag_abort("seed manifest output already exists; refusing overwrite",
                     "isdm_diag_output_exists")
  }
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile(".seed-manifest-", tmpdir = dirname(output_path))
  on.exit(if (file.exists(temporary)) unlink(temporary), add = TRUE)
  saveRDS(manifest, temporary)
  if (!file.rename(temporary, output_path)) {
    .isdm_diag_abort("atomic seed-manifest rename failed",
                     "isdm_diag_atomic_write_failed")
  }
  hash <- isdm_diag_sha256(output_path)
  sidecar <- paste0(output_path, ".sha256")
  writeLines(sprintf("%s  %s", hash, basename(output_path)), sidecar,
             useBytes = TRUE)
  invisible(list(path = output_path, sha256 = hash, sidecar = sidecar))
}

isdm_diag_select_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (!length(args) %in% c(2L, 3L)) {
    stop(paste(
      "usage: select-seeds.R PRODUCTION_DIR OUTPUT_RDS [SOURCE_CONTRACT_RDS]"
    ))
  }
  manifest <- isdm_diag_build_seed_manifest(
    args[[1L]], if (length(args) == 3L) args[[3L]] else NULL
  )
  receipt <- isdm_diag_write_seed_manifest(manifest, args[[2L]])
  cat(sprintf("selected 8 nonspatial and 12 spatial sentinels\n"))
  cat(sprintf("seed manifest SHA-256: %s\n", receipt$sha256))
  invisible(receipt)
}

.isdm_diag_running_this_file <- function() {
  script <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  length(script) == 1L && identical(
    normalizePath(sub("^--file=", "", script), mustWork = TRUE),
    normalizePath(.ISDM_DIAG_SELECT_FILE, mustWork = TRUE)
  )
}

if (.isdm_diag_running_this_file()) isdm_diag_select_cli()
