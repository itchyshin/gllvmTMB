#!/usr/bin/env Rscript

args0 <- commandArgs(trailingOnly = FALSE)
self <- sub("^--file=", "", args0[grepl("^--file=", args0)])[[1L]]
sim_dir <- dirname(normalizePath(self))
source(file.path(sim_dir, "lane-b-b2-runner.R"))
source(file.path(sim_dir, "lane-b-quasi-supplement.R"))

args <- commandArgs(trailingOnly = TRUE)
value_after <- function(flag, required = TRUE) {
  where <- match(flag, args)
  if (is.na(where)) {
    if (required) stop("Missing ", flag)
    return(NULL)
  }
  if (where == length(args)) stop("Missing value after ", flag)
  args[[where + 1L]]
}
command <- if (length(args)) args[[1L]] else stop("Use prepare, run, or aggregate.")
root <- lane_b_validate_campaign_root(value_after("--root"))
paths <- lane_b_quasi_paths(root)
source_hashes <- lane_b_quasi_source_receipt

if (command == "prepare") {
  invisible(lapply(paths, dir.create, recursive = TRUE, showWarnings = FALSE))
  manifest <- lane_b_quasi_manifest()
  queue <- lane_b_quasi_queue(manifest)
  frozen <- list(
    supplement_version = lane_b_quasi_version(),
    manifest_version = lane_b_manifest_version(), manifest = manifest,
    queue = queue, thresholds = lane_b_thresholds(), source_sha256 = source_hashes(),
    source_tarball_sha256 = Sys.getenv("GLLVMTMB_LANE_B_TARBALL_SHA256"),
    runtime_receipt = lane_b_quasi_runtime_receipt(),
    session_info = utils::sessionInfo(), smoke = FALSE
  )
  frozen_path <- file.path(paths[["frozen"]], "lane-b-quasi-frozen-v1.rds")
  lane_b_atomic_save_rds(frozen, frozen_path)
  utils::write.csv(queue, file.path(paths[["queue"]], "lane-b-quasi-queue-v1.csv"),
                   row.names = FALSE)
  receipt <- list(supplement_version = frozen$supplement_version,
                  cells = nrow(manifest), datasets = sum(manifest$n_rep),
                  primary_attempts = sum(queue$primary_attempt_count),
                  shards = nrow(queue), frozen_sha256 = lane_b_sha256_file(frozen_path),
                  source_tarball_sha256 = frozen$source_tarball_sha256,
                  runtime_receipt = frozen$runtime_receipt)
  lane_b_atomic_save_rds(receipt, file.path(paths[["session"]], "prepare-receipt-v1.rds"))
  print(receipt)
} else {
  frozen_path <- file.path(paths[["frozen"]], "lane-b-quasi-frozen-v1.rds")
  if (!file.exists(frozen_path)) stop("Run prepare first.")
  frozen <- readRDS(frozen_path)
  if (!identical(frozen$source_sha256, source_hashes()))
    stop("Quasi supplement source differs from the frozen receipt.")
  if (!identical(frozen$runtime_receipt, lane_b_quasi_runtime_receipt()))
    stop("Installed quasi runtime differs from the frozen receipt.")

  if (command == "run") {
    shard_id <- value_after("--shard-id")
    shard <- frozen$queue[frozen$queue$shard_id == shard_id, , drop = FALSE]
    if (nrow(shard) != 1L) stop("Unknown quasi shard: ", shard_id)
    complete_path <- file.path(paths[["state/complete"]], paste0(shard_id, ".rds"))
    if (file.exists(complete_path)) quit(save = "no", status = 0L)
    lane_b_assert_capabilities(FALSE)
    lock <- file.path(paths[["state/running"]], paste0(shard_id, ".lock"))
    if (!file.create(lock)) stop("Quasi shard is already locked: ", shard_id)
    on.exit(lane_b_release_lock(lock), add = TRUE)
    cell <- frozen$manifest[frozen$manifest$cell_id == shard$cell_id[[1L]], , drop = FALSE]
    started <- proc.time()[["elapsed"]]
    attempts <- tryCatch({
      rows <- lapply(seq.int(shard$replicate_first, shard$replicate_last), function(rep_id) {
        dat <- lane_b_generate_targeted_quasi(cell, rep_id)
        certificate <- lane_b_b0_status_by_trait(dat)
        if (!identical(unname(certificate[[1L]]), "QUASI_COMPLETE"))
          stop("Target trait did not retain its exact quasi-complete certificate.")
        lane_b_fit_dataset_attempts(dat, cell, "quasi", frozen)
      })
      do.call(rbind, rows)
    }, error = identity)
    elapsed <- proc.time()[["elapsed"]] - started
    if (inherits(attempts, "condition")) {
      receipt <- list(shard_id = shard_id, status = "failed",
                      error = conditionMessage(attempts), elapsed_seconds = elapsed)
      lane_b_atomic_save_rds(receipt,
        file.path(paths[["state/failed"]], paste0(shard_id, ".rds")))
      lane_b_release_lock(lock)
      stop(conditionMessage(attempts))
    }
    raw_path <- file.path(paths[["raw"]], paste0(shard_id, ".rds"))
    raw_sha <- lane_b_atomic_save_rds(attempts, raw_path)
    receipt <- list(shard_id = shard_id, status = "complete",
                    rows = nrow(attempts), elapsed_seconds = elapsed,
                    raw_sha256 = raw_sha)
    lane_b_atomic_save_rds(receipt, complete_path)
    lane_b_release_lock(lock)
  } else if (command == "aggregate") {
    verified <- lane_b_verify_shard_receipts(
      frozen$queue, paths[["raw"]], paths[["state/complete"]],
      hash_field = "raw_sha256", require_complete = TRUE
    )
    attempts <- do.call(rbind, verified$attempts)
    metrics <- lane_b_quasi_cell_metrics(attempts, frozen$manifest)
    gate <- lane_b_quasi_family_gate(metrics)
    result <- list(
      label = if (all(gate$pass)) "QUASI-PROMOTION-PASS" else
        "QUASI-PROMOTION-WITHHELD",
      supplement_version = frozen$supplement_version,
      manifest_version = frozen$manifest_version,
      attempts = attempts, cell_arm_summary = lane_b_attempt_summary(attempts),
      cell_metrics = metrics, family_gate = gate,
      source_sha256 = frozen$source_sha256, thresholds = frozen$thresholds,
      verified_shards = verified$ids
    )
    lane_b_validate_quasi_summary(result, root, frozen$manifest)
    lane_b_atomic_save_rds(result,
      file.path(paths[["summaries"]], "lane-b-quasi-summary-v1.rds"))
    cat(result$label, "\n")
    print(gate)
  } else stop("Use prepare, run, or aggregate.")
}
