args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop("usage: write-launch-terminal.R LAUNCH_START_RDS STATUS RUNTIME_S OUTPUT_RDS")
}
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
                                     value = TRUE)[[1L]])
source(file.path(dirname(normalizePath(script)), "record.R"), local = TRUE)
start_path <- normalizePath(args[[1L]], mustWork = TRUE)
status <- as.integer(args[[2L]])
runtime_s <- as.numeric(args[[3L]])
if (is.na(status) || !is.finite(runtime_s) || runtime_s < 0) {
  stop("launch terminal status/runtime is invalid")
}
start <- readRDS(start_path)
receipt <- list(
  schema = "isdm-diagnostic-launch-terminal-v1",
  created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  run_kind = start$run_kind, planned = start$planned,
  command_status = status, runtime_s = runtime_s,
  launch_start_sha256 = unname(diagnostic_sha256(start_path))
)
diagnostic_atomic_save(receipt, args[[4L]])
cat("DIAGNOSTIC_LAUNCH_TERMINAL_WRITTEN\n")
