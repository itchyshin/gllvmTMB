#!/usr/bin/env Rscript
## Import an in-manifest post-guard shard and remove its task from execution.

source("dev/interval-calibration/remote/shard-io.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) {
  interval_stop(
    paste(
      "usage: import-post-guard-receipt.R",
      "PACKET TASK_TSV RECEIPT_RDS OUT_ROOT REMAINING_TSV"
    )
  )
}
packet <- toupper(interval_scalar_string(args[[1L]], "packet"))
manifest <- utils::read.delim(
  args[[2L]],
  stringsAsFactors = FALSE,
  check.names = FALSE
)
receipt <- readRDS(args[[3L]])
out_root <- args[[4L]]
remaining_tsv <- args[[5L]]
if (!identical(receipt$packet, packet)) {
  interval_stop("post-guard import packet differs from the wave")
}
plan <- interval_post_guard_import_plan(receipt, manifest)
if (nrow(plan$imported_task)) {
  shard <- readRDS(receipt$shard_path)
  stem <- interval_shard_stem(packet, shard$cell_id, shard$rep)
  version <- interval_scalar_integer(shard$attempt_version, "attempt_version")
  source_root <- dirname(dirname(receipt$shard_path))
  source_operations <- file.path(
    source_root,
    "operations",
    sprintf(
      "%s-a%02d-%s.rds",
      stem,
      version,
      c("started", "completed")
    )
  )
  destination <- c(
    file.path(out_root, "canonical", basename(receipt$shard_path)),
    file.path(out_root, "operations", basename(source_operations))
  )
  if (
    any(!file.exists(c(receipt$shard_path, source_operations))) ||
      any(file.exists(destination))
  ) {
    interval_stop("post-guard import sources are missing or destinations exist")
  }
  copied <- file.copy(c(receipt$shard_path, source_operations), destination)
  if (!all(copied)) interval_stop("post-guard import copy failed")
  if (!identical(interval_sha256_file(destination[[1L]]), receipt$shard_sha256)) {
    interval_stop("imported post-guard shard changed during copy")
  }
  dir.create(file.path(out_root, "import"), showWarnings = FALSE)
  interval_atomic_save_rds(
    list(
      schema = "INTERVAL_CALIBRATION_POST_GUARD_IMPORT_V1",
      receipt = receipt,
      imported_task = plan$imported_task,
      destination = destination,
      imported_at = Sys.time()
    ),
    file.path(out_root, "import", "post-guard-import.rds")
  )
}
utils::write.table(
  plan$remaining_tasks,
  remaining_tsv,
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)
cat("INTERVAL_POST_GUARD_IMPORT_READY\n")
