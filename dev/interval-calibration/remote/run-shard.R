#!/usr/bin/env Rscript
## Run exactly one frozen interval-calibration outer identity.
##
## Usage:
##   Rscript run-shard.R PACKET CELL_ID REP SCIENTIFIC_SHA OUT_ROOT [ATTEMPT]
## PACKET is one of PVT02, CI09, CI10_COST, CI13, CI14, CI15.

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) {
  stop(
    "usage: run-shard.R PACKET CELL_ID REP SCIENTIFIC_SHA OUT_ROOT [ATTEMPT]",
    call. = FALSE
  )
}
if (!length(args) %in% c(5L, 6L)) {
  stop("run-shard.R received the wrong number of arguments", call. = FALSE)
}

source("dev/interval-calibration/remote/shard-io.R")
packet <- toupper(interval_scalar_string(args[[1L]], "packet"))
cell_id <- interval_scalar_integer(args[[2L]], "cell_id")
rep <- interval_scalar_integer(args[[3L]], "rep")
scientific_sha <- interval_scalar_string(args[[4L]], "scientific_sha")
out_root <- interval_scalar_string(args[[5L]], "out_root")
attempt_version <- if (length(args) == 6L) {
  interval_scalar_integer(args[[6L]], "attempt_version")
} else {
  1L
}

allowed <- c("PVT02", "CI09", "CI10_COST", "CI13", "CI14", "CI15")
if (!packet %in% allowed) {
  interval_stop("unknown campaign packet: ", packet)
}
if (!identical(scientific_sha, interval_approved_source(packet))) {
  interval_stop("campaign shard source SHA is outside the approved envelope")
}
if (identical(packet, "CI10_COST") && rep != 3L) {
  interval_stop("CI-10 cost-array authority is restricted to canonical rep 3")
}

paths <- switch(
  packet,
  PVT02 = c("DESCRIPTION", "NAMESPACE", "R", "src", "dev/m3-grid.R", "dev/pvt02/pvt02-contract.R", "dev/pvt02/pvt02-smoke.R"),
  CI09 = c("DESCRIPTION", "NAMESPACE", "R", "src", "dev/interval-calibration/ci09/ci09-kernels.R", "dev/interval-calibration/ci09/smoke.R"),
  CI10_COST = c("DESCRIPTION", "NAMESPACE", "R", "src", "dev/cross-family-coverage.R", "dev/interval-calibration/ci10/ci10-kernels.R", "dev/interval-calibration/ci10/one-replicate-smoke.R"),
  CI13 = c("DESCRIPTION", "NAMESPACE", "R", "src", "dev/interval-calibration/ci13/ci13-kernels.R", "dev/interval-calibration/ci13/smoke.R"),
  CI14 = c("DESCRIPTION", "NAMESPACE", "R", "src", "dev/interval-calibration/ci14-ci15/ci1415-kernels.R", "dev/interval-calibration/ci14-ci15/smoke-runners.R"),
  CI15 = c("DESCRIPTION", "NAMESPACE", "R", "src", "dev/interval-calibration/ci14-ci15/ci1415-kernels.R", "dev/interval-calibration/ci14-ci15/smoke-runners.R")
)
stem <- interval_shard_stem(packet, cell_id, rep)
canonical_path <- file.path(out_root, "canonical", paste0(stem, ".rds"))
operation_stem <- file.path(
  out_root,
  "operations",
  sprintf("%s-a%02d", stem, attempt_version)
)
operation_started_path <- paste0(operation_stem, "-started.rds")
operation_completed_path <- paste0(operation_stem, "-completed.rds")
operation_failed_path <- paste0(operation_stem, "-failed.rds")
operation_timeout_path <- paste0(operation_stem, "-timeout.rds")
operation_not_started_path <- paste0(operation_stem, "-not-started.rds")
if (file.exists(canonical_path)) {
  interval_stop("canonical identity already exists: ", canonical_path)
}
if (any(file.exists(c(
  operation_started_path,
  operation_completed_path,
  operation_failed_path,
  operation_timeout_path,
  operation_not_started_path
)))) {
  interval_stop("operational attempt already exists: ", operation_stem)
}

started <- proc.time()[["elapsed"]]
interval_atomic_save_rds(
  list(
    schema = "INTERVAL_CALIBRATION_OPERATION_STARTED_V1",
    packet = packet,
    cell_id = cell_id,
    rep = rep,
    attempt_version = attempt_version,
    scientific_source_sha = scientific_sha,
    host = Sys.info()[["nodename"]],
    pid = Sys.getpid(),
    started_at = Sys.time()
  ),
  operation_started_path
)
result <- tryCatch({
  runtime_dependencies <- interval_assert_runtime_dependencies()
  scientific <- interval_assert_frozen_source(scientific_sha, paths)
  scientific$installed_package <- interval_assert_installed_package(scientific_sha)
  if (identical(packet, "PVT02")) {
    env <- new.env(parent = globalenv())
    sys.source("dev/pvt02/pvt02-contract.R", envir = env)
    sys.source("dev/m3-grid.R", envir = env)
    interval_extract_assignment("dev/pvt02/pvt02-smoke.R", "cell", env)
    interval_extract_assignment(
      "dev/pvt02/pvt02-smoke.R",
      "pvt02_smoke_one",
      env
    )
    manifest <- env$pvt02_campaign_manifest(env$cell, scientific_sha, reps = rep)
    attempt <- env$pvt02_smoke_one(manifest)
    seed <- manifest$seed[[1L]]
    provenance <- list(manifest_fingerprint = env$pvt02_manifest_fingerprint(manifest))
  } else if (identical(packet, "CI09")) {
    source("dev/interval-calibration/ci09/smoke.R")
    one <- ci09_smoke_once(cell_id, rep, scientific_sha)
    attempt <- one$attempt
    seed <- one$provenance$seed
    provenance <- one$provenance
  } else if (identical(packet, "CI10_COST")) {
    source("dev/interval-calibration/ci10/one-replicate-smoke.R")
    spec <- ci10_campaign_spec()
    cell <- spec$cells[spec$cells$cell_id == cell_id, , drop = FALSE]
    if (nrow(cell) != 1L) interval_stop("CI-10 cell is outside the frozen grid")
    scratch <- tempfile("ci10-cost-")
    one <- tryCatch(
      ci10_smoke_one_replicate(
        partner = cell$partner,
        N = cell$N,
        target_multiple_r = cell$target_multiple_r,
        rep = rep,
        n_boot = 499L,
        reps = 5L,
        source_sha = scientific_sha,
        out_dir = scratch
      ),
      finally = unlink(scratch, recursive = TRUE)
    )
    if (
      !identical(one$runtime$n_boot, 499L) ||
        !identical(one$runtime$reps, 5L) ||
        !identical(one$provenance$source_sha, scientific_sha) ||
        !identical(one$attempt$cell_id, cell_id) ||
        !identical(one$attempt$rep, 3L)
    ) {
      interval_stop("CI-10 cost shard failed its adjacent runtime/provenance checks")
    }
    attempt <- one$attempt
    seed <- attempt$seed
    provenance <- one$provenance
    provenance$ci10_runtime <- one$runtime
  } else if (identical(packet, "CI13")) {
    source("dev/interval-calibration/ci13/smoke.R")
    one <- ci13_smoke_one_replicate(cell_id, rep, scientific_sha)
    attempt <- one$attempt
    seed <- one$provenance$seed
    provenance <- one$provenance
  } else {
    source("dev/interval-calibration/ci14-ci15/ci1415-kernels.R")
    source("dev/interval-calibration/ci14-ci15/smoke-runners.R")
    source("dev/interval-calibration/ci14-ci15/campaign-shard.R")
    inner_path <- tempfile("ci1415-validated-", fileext = ".rds")
    inner <- tryCatch(
      ci1415_run_campaign_shard(
        packet,
        cell_id,
        rep,
        scientific_sha,
        inner_path
      ),
      finally = unlink(inner_path)
    )
    attempt <- inner$shard$outer_attempt
    seed <- inner$shard$seed
    provenance <- inner$shard$provenance
    provenance$ci1415_adapter_schema <- inner$shard$shard_schema_version
    provenance$ci1415_failure <- inner$shard$failure
    provenance$ci1415_fit_health <- inner$shard$fit_health
  }
  provenance$runtime_dependencies <- runtime_dependencies
  payload <- interval_canonical_payload(
    packet = packet,
    cell_id = cell_id,
    rep = rep,
    seed = seed,
    scientific_provenance = scientific,
    attempt = attempt,
    runtime_seconds = proc.time()[["elapsed"]] - started,
    runner_provenance = provenance,
    attempt_version = attempt_version
  )
  interval_atomic_save_rds(payload, canonical_path)
  interval_atomic_save_rds(
    list(
      schema = "INTERVAL_CALIBRATION_OPERATION_COMPLETED_V1",
      packet = packet,
      cell_id = cell_id,
      rep = rep,
      attempt_version = attempt_version,
      canonical_path = canonical_path,
      canonical_file = file.path("canonical", basename(canonical_path)),
      runtime_seconds = payload$runtime_seconds,
      completed_at = Sys.time()
    ),
    operation_completed_path
  )
  list(ok = TRUE, path = canonical_path)
}, error = function(e) {
  failure <- interval_operational_failure(
    packet,
    cell_id,
    rep,
    attempt_version,
    scientific_sha,
    conditionMessage(e),
    stage = "campaign-shard"
  )
  interval_atomic_save_rds(failure, operation_failed_path)
  list(ok = FALSE, path = operation_failed_path, message = conditionMessage(e))
})

if (!isTRUE(result$ok)) {
  message("INTERVAL_SHARD_FAILED ", result$path, ": ", result$message)
  quit(save = "no", status = 1L)
}
cat("INTERVAL_SHARD_WROTE ", result$path, "\n", sep = "")
