#!/usr/bin/env Rscript
## Validate the one-shard dependency/health receipt before a campaign launch.

source("dev/interval-calibration/remote/shard-io.R")

args <- commandArgs(trailingOnly = TRUE)
if (!length(args) %in% 3:4) {
  interval_stop(
    paste(
      "usage: validate-post-guard-receipt.R",
      "PACKET TASK_TSV RECEIPT_RDS [LOCAL_SHARD_RDS]"
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
if (!identical(receipt$packet, packet)) {
  interval_stop("post-guard receipt packet differs from the launch gate")
}
shard_path_override <- if (length(args) == 4L) args[[4L]] else NULL
interval_validate_post_guard_receipt(
  receipt,
  manifest,
  shard_path_override = shard_path_override
)
cat("INTERVAL_POST_GUARD_RECEIPT_VALID\n")
