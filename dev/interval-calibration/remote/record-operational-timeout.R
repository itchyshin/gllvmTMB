#!/usr/bin/env Rscript
source("dev/interval-calibration/remote/shard-io.R")

interval_record_timeout <- function(
  packet,
  cell_id,
  rep,
  attempt_version,
  scientific_source_sha,
  root,
  message
) {
  stem <- interval_shard_stem(packet, cell_id, rep)
  prefix <- file.path(
    root,
    "operations",
    sprintf("%s-a%02d", stem, attempt_version)
  )
  completed <- paste0(prefix, "-completed.rds")
  failed <- paste0(prefix, "-failed.rds")
  timeout <- paste0(prefix, "-timeout.rds")
  not_started <- paste0(prefix, "-not-started.rds")
  if (
    file.exists(completed) ||
      file.exists(failed) ||
      file.exists(timeout) ||
      file.exists(not_started)
  ) {
    return(invisible(FALSE))
  }
  started <- file.exists(paste0(prefix, "-started.rds"))
  terminal_path <- if (started) timeout else not_started
  interval_atomic_save_rds(
    list(
      schema = if (started) {
        "INTERVAL_CALIBRATION_OPERATION_TIMEOUT_V1"
      } else {
        "INTERVAL_CALIBRATION_OPERATION_NOT_STARTED_V1"
      },
      packet = packet,
      cell_id = as.integer(cell_id),
      rep = as.integer(rep),
      attempt_version = as.integer(attempt_version),
      scientific_source_sha = scientific_source_sha,
      message = message,
      timed_out_at = Sys.time()
    ),
    terminal_path
  )
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 7L) {
    interval_stop(
      "usage: record-operational-timeout.R PACKET CELL REP ATTEMPT SHA ROOT MESSAGE"
    )
  }
  interval_record_timeout(
    toupper(args[[1L]]),
    interval_scalar_integer(args[[2L]], "cell_id"),
    interval_scalar_integer(args[[3L]], "rep"),
    interval_scalar_integer(args[[4L]], "attempt_version"),
    args[[5L]],
    args[[6L]],
    args[[7L]]
  )
}
