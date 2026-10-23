#!/usr/bin/env Rscript
source("dev/interval-calibration/remote/shard-io.R")
source("dev/interval-calibration/remote/validate-task-manifest.R")
source("dev/interval-calibration/remote/record-operational-timeout.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  interval_stop("usage: record-wave-timeouts.R PACKET TASK_TSV ROOT MESSAGE")
}
packet <- toupper(args[[1L]])
tasks <- interval_validate_task_manifest(packet, args[[2L]])
for (i in seq_len(nrow(tasks))) {
  interval_record_timeout(
    packet,
    tasks$cell_id[[i]],
    tasks$rep[[i]],
    tasks$attempt_version[[i]],
    tasks$scientific_source_sha[[i]],
    args[[3L]],
    args[[4L]]
  )
}
