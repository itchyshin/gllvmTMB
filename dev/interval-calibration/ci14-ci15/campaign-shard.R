## Immutable one-identity CI-14/15 campaign shard writer.
##
## This module does not launch remote work.  Its CLI wrapper calls exactly one
## approved timing/campaign identity and retains the resulting outer attempt in
## an atomic RDS shard for a later merger.

if (!exists("ci1415_smoke_request", mode = "function")) {
  stop("source ci1415-kernels.R and smoke-runners.R before campaign-shard.R", call. = FALSE)
}

.ci1415_parse_positive_integer <- function(value, name) {
  if (!is.character(value) || length(value) != 1L || !grepl("^[1-9][0-9]*$", value)) {
    .ci1415_stop("CI-14/15 shard ", name, " must be one positive integer")
  }
  out <- suppressWarnings(as.integer(value))
  if (is.na(out)) .ci1415_stop("CI-14/15 shard ", name, " is outside R integer range")
  out
}

ci1415_parse_shard_args <- function(args) {
  if (!is.character(args) || length(args) != 5L) {
    .ci1415_stop("CI-14/15 shard CLI requires exactly five arguments: packet cell_id rep source_sha out_path")
  }
  packet <- args[[1L]]
  if (!packet %in% c("CI14", "CI15")) {
    .ci1415_stop("CI-14/15 shard packet must be CI14 or CI15")
  }
  cell_id <- .ci1415_parse_positive_integer(args[[2L]], "cell_id")
  rep <- .ci1415_parse_positive_integer(args[[3L]], "rep")
  source_sha <- args[[4L]]
  out_path <- args[[5L]]
  if (!nzchar(source_sha)) .ci1415_stop("CI-14/15 shard requires a non-empty source_sha")
  if (!nzchar(out_path)) .ci1415_stop("CI-14/15 shard requires a non-empty out_path")
  ## The request constructs the immutable manifest and validates the frozen
  ## packet/cell/rep/seed relationship without running a fit.
  request <- ci1415_smoke_request(packet, cell_id = cell_id, rep = rep, source_sha = source_sha)
  list(
    packet = packet, cell_id = cell_id, rep = rep, source_sha = source_sha,
    out_path = out_path, request = request
  )
}

.ci1415_shard_identity <- function(request) {
  list(
    packet = request$packet,
    campaign_id = request$campaign_id,
    cell_id = request$cell_id,
    rep = request$rep,
    seed = request$seed,
    route = request$route,
    source_sha = request$source_sha,
    truth_fingerprint = request$truth_fingerprint,
    manifest_fingerprint = request$manifest$fingerprint
  )
}

.ci1415_validate_shard_result <- function(request, result) {
  needed <- c("outer_attempt", "runtime_seconds", "source_sha", "seed", "truth_fingerprint", "provenance")
  if (!is.list(result) || !all(needed %in% names(result))) {
    .ci1415_stop("CI-14/15 shard runner returned incomplete provenance")
  }
  identity <- .ci1415_shard_identity(request)
  attempt <- result$outer_attempt
  if (!is.list(attempt) ||
      !identical(result$source_sha, identity$source_sha) ||
      !identical(result$seed, identity$seed) ||
      !identical(result$truth_fingerprint, identity$truth_fingerprint) ||
      !identical(attempt$packet, identity$packet) ||
      !identical(attempt$campaign_id, identity$campaign_id) ||
      !identical(attempt$source_sha, identity$source_sha) ||
      !identical(attempt$cell_id, identity$cell_id) ||
      !identical(attempt$rep, identity$rep) ||
      !identical(attempt$seed, identity$seed) ||
      !identical(attempt$route, identity$route) ||
      !identical(attempt$truth_fingerprint, identity$truth_fingerprint)) {
    .ci1415_stop("CI-14/15 shard runner returned an identity, source SHA, seed, route, or truth mismatch")
  }
  if (!is.numeric(result$runtime_seconds) || length(result$runtime_seconds) != 1L ||
      !is.finite(result$runtime_seconds) || result$runtime_seconds < 0) {
    .ci1415_stop("CI-14/15 shard runner returned an invalid runtime")
  }
  if (!is.list(result$provenance)) {
    .ci1415_stop("CI-14/15 shard runner returned invalid provenance")
  }
  ## This exercises the same all-attempt / target-payload validator that the
  ## campaign merger will use.  A one-identity manifest is required here.
  ci1415_merge_attempts(request$manifest, list(attempt))
  invisible(TRUE)
}

.ci1415_build_shard <- function(request, result) {
  .ci1415_validate_shard_result(request, result)
  list(
    shard_schema_version = "ci1415-shard-v1",
    identity = .ci1415_shard_identity(request),
    outer_attempt = result$outer_attempt,
    runtime_seconds = as.numeric(result$runtime_seconds),
    source_sha = result$source_sha,
    seed = result$seed,
    truth_fingerprint = result$truth_fingerprint,
    fit_health = result$fit_health %||% NA,
    failure = result$failure %||% NULL,
    provenance = result$provenance
  )
}

.ci1415_existing_shard_status <- function(path, requested_identity, requested_attempt) {
  existing <- tryCatch(readRDS(path), error = function(e) e)
  if (inherits(existing, "error") || !is.list(existing) ||
      !identical(existing$shard_schema_version, "ci1415-shard-v1") ||
      !identical(existing$identity, requested_identity)) {
    .ci1415_stop("refusing existing conflicting shard")
  }
  if (!identical(existing$outer_attempt, requested_attempt)) {
    .ci1415_stop("refusing existing conflicting shard")
  }
  "already_present"
}

.ci1415_write_shard_atomic <- function(shard, out_path) {
  out_dir <- dirname(out_path)
  if (!dir.exists(out_dir)) {
    .ci1415_stop("CI-14/15 shard output directory does not exist: ", out_dir)
  }
  if (file.exists(out_path)) {
    return(.ci1415_existing_shard_status(out_path, shard$identity, shard$outer_attempt))
  }
  tmp_path <- tempfile(
    pattern = paste0(".", basename(out_path), ".tmp-"),
    tmpdir = out_dir,
    fileext = ".rds"
  )
  on.exit(if (file.exists(tmp_path)) unlink(tmp_path), add = TRUE)
  saveRDS(shard, tmp_path, version = 3L)
  ## Do not overwrite an artefact another worker placed while this worker was
  ## serialising.  The surrounding campaign dispatcher allocates one identity
  ## per output path; this second check makes accidental collisions fail closed.
  if (file.exists(out_path)) {
    return(.ci1415_existing_shard_status(out_path, shard$identity, shard$outer_attempt))
  }
  if (!file.rename(tmp_path, out_path)) {
    .ci1415_stop("CI-14/15 shard atomic rename failed")
  }
  "written"
}

ci1415_run_campaign_shard <- function(packet, cell_id, rep, source_sha, out_path,
                                      runner = NULL) {
  parsed <- ci1415_parse_shard_args(c(
    as.character(packet), as.character(cell_id), as.character(rep), source_sha, out_path
  ))
  request <- parsed$request
  runner <- runner %||% request$runner
  if (!is.function(runner)) .ci1415_stop("CI-14/15 shard runner is not callable")
  result <- runner(
    cell_id = request$cell_id,
    rep = request$rep,
    source_sha = request$source_sha
  )
  shard <- .ci1415_build_shard(request, result)
  status <- .ci1415_write_shard_atomic(shard, parsed$out_path)
  list(status = status, out_path = parsed$out_path, shard = shard)
}

ci1415_run_campaign_shard_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  parsed <- ci1415_parse_shard_args(args)
  result <- ci1415_run_campaign_shard(
    parsed$packet, parsed$cell_id, parsed$rep, parsed$source_sha, parsed$out_path
  )
  cat(sprintf("CI1415_SHARD_%s %s\n", toupper(result$status), result$out_path))
  invisible(result)
}
