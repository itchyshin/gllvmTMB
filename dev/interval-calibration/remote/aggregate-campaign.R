#!/usr/bin/env Rscript
## Validate and aggregate one complete immutable campaign root.

source("dev/interval-calibration/remote/shard-io.R")
source("dev/interval-calibration/remote/build-task-manifests.R")

interval_read_canonical_shards <- function(packet, root) {
  interval_assert_clean_checkout(".")
  expected <- interval_build_task_manifest(packet)
  task_manifest_path <- file.path(root, "task-manifest.tsv")
  if (!file.exists(task_manifest_path)) {
    interval_stop("campaign root lacks its immutable task-manifest.tsv")
  }
  observed_tasks <- utils::read.delim(
    task_manifest_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  rownames(observed_tasks) <- NULL
  if (!identical(observed_tasks, expected)) {
    interval_stop("campaign-root task manifest differs from the frozen grid")
  }
  files <- sort(list.files(
    file.path(root, "canonical"),
    pattern = "\\.rds$",
    full.names = TRUE
  ))
  if (length(files) != nrow(expected)) {
    interval_stop(
      packet,
      " retained ",
      length(files),
      " canonical shards; expected ",
      nrow(expected)
    )
  }
  interval_validate_checksum_manifest(root, files)
  shards <- lapply(files, readRDS)
  for (i in seq_along(shards)) {
    shard <- shards[[i]]
    if (
      !is.list(shard) ||
        !identical(shard$schema, "INTERVAL_CALIBRATION_CANONICAL_SHARD_V1") ||
        !identical(shard$packet, packet) ||
        !identical(shard$scientific_provenance$scientific_source_sha, interval_task_source(packet))
    ) {
      interval_stop("invalid or source-drifted canonical shard: ", files[[i]])
    }
  }
  keys <- vapply(
    shards,
    function(x) paste(x$cell_id, x$rep, sep = "::"),
    character(1)
  )
  expected_keys <- paste(expected$cell_id, expected$rep, sep = "::")
  if (anyDuplicated(keys) || !setequal(keys, expected_keys)) {
    interval_stop(packet, " canonical identities are duplicated or incomplete")
  }
  shards <- shards[match(expected_keys, keys)]
  for (shard in shards) {
    stem <- interval_shard_stem(packet, shard$cell_id, shard$rep)
    version <- interval_scalar_integer(
      shard$attempt_version,
      "canonical attempt_version"
    )
    started <- file.path(
      root,
      "operations",
      sprintf("%s-a%02d-started.rds", stem, version)
    )
    completed <- file.path(
      root,
      "operations",
      sprintf("%s-a%02d-completed.rds", stem, version)
    )
    failed <- sub("-completed[.]rds$", "-failed.rds", completed)
    timeout <- sub("-completed[.]rds$", "-timeout.rds", completed)
    not_started <- sub("-completed[.]rds$", "-not-started.rds", completed)
    if (
      !file.exists(started) ||
        !file.exists(completed) ||
        any(file.exists(c(failed, timeout, not_started)))
    ) {
      interval_stop("canonical shard lacks its start/completed operation pair: ", stem)
    }
    start <- readRDS(started)
    op <- readRDS(completed)
    if (
      !identical(start$schema, "INTERVAL_CALIBRATION_OPERATION_STARTED_V1") ||
        !identical(start$packet, packet) ||
        !identical(start$cell_id, shard$cell_id) ||
        !identical(start$rep, shard$rep) ||
        !identical(start$attempt_version, version) ||
        !identical(
          start$scientific_source_sha,
          interval_task_source(packet)
        ) ||
      !identical(op$schema, "INTERVAL_CALIBRATION_OPERATION_COMPLETED_V1") ||
        !identical(op$packet, packet) ||
        !identical(op$cell_id, shard$cell_id) ||
        !identical(op$rep, shard$rep) ||
        !identical(op$attempt_version, version) ||
        !identical(
          op$canonical_file,
          file.path("canonical", paste0(stem, ".rds"))
        )
    ) {
      interval_stop("operation completion receipt conflicts with canonical shard: ", stem)
    }
  }
  session_files <- list.files(
    file.path(root, "session"),
    pattern = "[.]rds$",
    full.names = TRUE
  )
  if (length(session_files) != 1L) {
    interval_stop("campaign root requires exactly one environment/session receipt")
  }
  session <- readRDS(session_files[[1L]])
  if (!identical(session$schema, "INTERVAL_CALIBRATION_SESSION_RECEIPT_V1")) {
    interval_stop("campaign session receipt has the wrong schema")
  }
  expected_root <- normalizePath(root, mustWork = TRUE)
  expected_threads <- c(
    OPENBLAS_NUM_THREADS = "1",
    OMP_NUM_THREADS = "1",
    MKL_NUM_THREADS = "1"
  )
  if (
    !identical(session$packet, packet) ||
      !identical(session$checkout_status, "clean") ||
      !identical(session$approved_source_sha, interval_task_source(packet)) ||
      !identical(session$output_root, expected_root) ||
      !identical(
        unname(session$thread_environment[names(expected_threads)]),
        unname(expected_threads)
      ) ||
      !identical(
        session$installed_package$installed_source_sha,
        interval_task_source(packet)
      ) ||
      !identical(
        session$installed_tree_sha256,
        interval_directory_sha256(
          session$installed_package$package_path
        )
      ) ||
      !identical(
        session$task_manifest_sha256,
        interval_sha256_file(task_manifest_path)
      ) ||
      !identical(
        session$runner_sha256,
        interval_sha256_file("dev/interval-calibration/remote/run-shard.R")
      ) ||
      !identical(
        session$aggregator_sha256,
        interval_sha256_file(
          "dev/interval-calibration/remote/aggregate-campaign.R"
        )
      ) ||
      !identical(
        session$checkout_sha,
        trimws(interval_git_output(c("rev-parse", "HEAD"))[[1L]])
      )
  ) {
    interval_stop("campaign session receipt conflicts with packet/source/root/environment")
  }
  if (identical(packet, "CI10_COST")) {
    submission <- file.path(
      root,
      "operations",
      "ci10-cost-array-submitted.tsv"
    )
    conflicts <- file.path(
      root,
      "operations",
      c(
        "ci10-cost-array-submission-failed.tsv",
        "ci10-cost-array-submission-ambiguous.tsv"
      )
    )
    if (!file.exists(submission) || any(file.exists(conflicts))) {
      interval_stop(
        "CI-10 campaign lacks one unambiguous successful SLURM submission receipt"
      )
    }
    receipt <- utils::read.delim(
      submission,
      header = FALSE,
      col.names = c("key", "value"),
      stringsAsFactors = FALSE,
      quote = "",
      check.names = FALSE
    )
    receipt_value <- function(key) {
      hit <- receipt$value[receipt$key == key]
      if (length(hit) != 1L || !nzchar(hit)) {
        interval_stop("CI-10 submission receipt has invalid key: ", key)
      }
      hit
    }
    if (
      !identical(
        receipt_value("schema"),
        "INTERVAL_CALIBRATION_CI10_SUBMITTED_V1"
      ) ||
        !identical(receipt_value("packet"), "CI10_COST") ||
        !identical(
          receipt_value("source_sha"),
          interval_task_source(packet)
        ) ||
        !identical(
          receipt_value("task_manifest_sha256"),
          interval_sha256_file(task_manifest_path)
        ) ||
        !identical(receipt_value("output_root"), expected_root) ||
        !identical(receipt_value("submission_exit_status"), "0") ||
        !grepl("^[0-9]+$", receipt_value("job_id"))
    ) {
      interval_stop("CI-10 SLURM submission receipt conflicts with campaign root")
    }
    for (shard in shards) {
      runtime <- shard$runner_provenance$ci10_runtime
      if (
        !identical(runtime$n_boot, 499L) ||
          !identical(runtime$reps, 5L)
      ) {
        interval_stop("CI-10 canonical shard lost n_boot=499/reps=5 provenance")
      }
    }
  }
  shards
}

interval_aggregate_campaign <- function(packet, root) {
  shards <- interval_read_canonical_shards(packet, root)
  attempts <- lapply(shards, `[[`, "attempt")
  source_sha <- interval_task_source(packet)
  if (identical(packet, "PVT02")) {
    env <- new.env(parent = globalenv())
    sys.source("dev/pvt02/pvt02-contract.R", envir = env)
    interval_extract_assignment("dev/pvt02/pvt02-smoke.R", "cell", env)
    manifest <- env$pvt02_campaign_manifest(env$cell, source_sha)
    canonical <- do.call(rbind, attempts)
    receipt <- env$pvt02_batch_receipt(manifest, canonical)
    merged <- env$pvt02_merge_batch_receipts(manifest, list(receipt))
    summary <- env$pvt02_summarise_campaign(merged, manifest)
    verdict <- env$pvt02_campaign_promotion_verdict(
      env$cell,
      manifest,
      merged,
      seed_disjoint = TRUE
    )
  } else if (identical(packet, "CI09")) {
    source("dev/interval-calibration/ci09/ci09-kernels.R")
    manifest <- ci09_attempt_manifest(source_sha = source_sha)
    merged <- ci09_merge_attempts(manifest, attempts)
    summary <- ci09_summarise(merged)
    verdict <- ci09_promote(summary)
  } else if (identical(packet, "CI13")) {
    source("dev/interval-calibration/ci13/ci13-kernels.R")
    manifest <- ci13_attempt_manifest(source_sha = source_sha)
    merged <- ci13_merge_attempts(manifest, attempts)
    summary <- ci13_summarise(merged)
    verdict <- ci13_promote(manifest, attempts)
  } else if (packet %in% c("CI14", "CI15")) {
    source("dev/interval-calibration/ci14-ci15/ci1415-kernels.R")
    manifest <- ci1415_attempt_manifest(
      sub("^CI", "CI", packet),
      source_sha = source_sha
    )
    merged <- ci1415_merge_attempts(manifest, attempts)
    summary <- ci1415_summarise(merged)
    verdict <- ci1415_promote(manifest, attempts)
  } else if (identical(packet, "CI10_COST")) {
    source("dev/interval-calibration/ci10/ci10-kernels.R")
    manifest <- ci10_attempt_manifest(
      cell_ids = 1:18,
      rep_ids = 3L,
      source_sha = source_sha
    )
    merged <- ci10_merge_attempts(manifest, attempts)
    summary <- ci10_summarise(merged)
    verdict <- list(
      promote = FALSE,
      reason = "cost-array-only: full 90000-row campaign not authorised"
    )
  } else {
    interval_stop("unknown aggregation packet: ", packet)
  }
  list(
    schema = "INTERVAL_CALIBRATION_AGGREGATE_V1",
    packet = packet,
    source_sha = source_sha,
    n_canonical = length(shards),
    merged = merged,
    summary = summary,
    verdict = verdict,
    aggregated_at = Sys.time()
  )
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 3L) {
    interval_stop("usage: aggregate-campaign.R PACKET CAMPAIGN_ROOT OUTPUT_RDS")
  }
  result <- interval_aggregate_campaign(toupper(args[[1L]]), args[[2L]])
  interval_atomic_save_rds(result, args[[3L]])
  cat("INTERVAL_AGGREGATE_WROTE ", args[[3L]], "\n", sep = "")
}
