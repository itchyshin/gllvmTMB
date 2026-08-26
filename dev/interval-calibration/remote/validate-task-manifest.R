#!/usr/bin/env Rscript
if (!exists("interval_stop", mode = "function")) {
  source("dev/interval-calibration/remote/shard-io.R")
}
if (!exists("interval_build_task_manifest", mode = "function")) {
  source("dev/interval-calibration/remote/build-task-manifests.R")
}

interval_validate_task_manifest <- function(packet, path) {
  expected <- interval_build_task_manifest(packet)
  observed <- utils::read.delim(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  rownames(observed) <- NULL
  if (!identical(observed, expected)) {
    interval_stop("task TSV differs from the complete frozen ", packet, " manifest")
  }
  invisible(observed)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) {
    interval_stop("usage: validate-task-manifest.R PACKET TASK_TSV")
  }
  interval_validate_task_manifest(toupper(args[[1L]]), args[[2L]])
  cat("INTERVAL_TASK_MANIFEST_OK\n")
}
