# Point covr 4 trace files at counters that survived R CMD check.
#
# covr 4 instruments a package once and writes `R/covr_counters.rds` into the
# installed copy. A test process then saves only its hit counts, plus the path
# of the counters file it loaded. `R CMD check --as-cran` does not load that
# install directly: `tools:::setRlibs()` symlinks it into a session temp
# library (`/tmp/Rtmp*/RLIBS_*`), and `check.R` deletes the session directory
# (`unlink(sessdir)`) before the check process exits. The counters file is
# still in the persistent install. The path stored in the trace is the removed
# symlink, so covr stops with "Can't read coverage trace file" after the tests
# have already passed.
#
# covr 3.6.5 writes the counters themselves into the trace and does not set
# `counters_file`. Those traces are left as they are.
retarget_missing_covr_counters <- function(trace_dir, stable_counters) {
  if (!dir.exists(trace_dir)) {
    stop("coverage trace directory does not exist: ", trace_dir, call. = FALSE)
  }
  traces <- list.files(trace_dir, pattern = "^covr_trace_", full.names = TRUE)
  n <- 0L
  for (tf in traces) {
    obj <- readRDS(tf)
    if (!inherits(obj, "covr_counts")) next
    recorded <- obj[["counters_file"]]
    if (length(recorded) != 1L || !is.character(recorded) || is.na(recorded) || !nzchar(recorded)) {
      next
    }
    if (file.exists(recorded)) next
    if (length(stable_counters) != 1L || !is.character(stable_counters) ||
        is.na(stable_counters) || !nzchar(stable_counters) || !file.exists(stable_counters)) {
      stop(
        "coverage trace ", tf,
        " points at missing counters file ", recorded,
        " and the installed counters file is not available at ",
        stable_counters,
        call. = FALSE
      )
    }
    obj[["counters_file"]] <- stable_counters
    tmp <- paste0(tf, ".retarget")
    saveRDS(obj, tmp)
    ok <- file.rename(tmp, tf)
    if (!ok) {
      unlink(tf)
      ok <- file.rename(tmp, tf)
    }
    if (!ok) {
      unlink(tmp)
      stop("could not replace coverage trace ", tf, call. = FALSE)
    }
    n <- n + 1L
  }
  cat(sprintf(
    "retargeted_covr_traces=%d of %d (stable counters %s)\n",
    n, length(traces), stable_counters
  ))
  invisible(n)
}
