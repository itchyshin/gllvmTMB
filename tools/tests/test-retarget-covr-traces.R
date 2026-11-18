# Base-R checks for tools/retarget-covr-traces.R. No package install.
local({
  root <- Sys.getenv("GLLVMTMB_REPO_ROOT", normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = FALSE))
  helper <- file.path(root, "tools", "retarget-covr-traces.R")
  if (!file.exists(helper)) {
    # Invoked as `Rscript tools/tests/test-retarget-covr-traces.R` from the repo root.
    root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
    helper <- file.path(root, "tools", "retarget-covr-traces.R")
  }
  if (!file.exists(helper)) stop("cannot find ", helper, call. = FALSE)
  source(helper, local = TRUE)

  fail <- function(...) stop(sprintf(...), call. = FALSE)
  tmp <- tempfile("retarget-covr-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  stable <- file.path(tmp, "covr_counters.rds")
  saveRDS(list(keys = c("a", "b")), stable)

  dead <- file.path(tmp, "gone", "RLIBS_x", "gllvmTMB", "R", "covr_counters.rds")
  trace <- file.path(tmp, "covr_trace_dead")
  saveRDS(
    structure(list(counters_file = dead, counts = c(a = 2)), class = "covr_counts"),
    trace
  )
  kept <- file.path(tmp, "covr_trace_full")
  saveRDS(list(value = 1L), kept)
  live_path <- file.path(tmp, "already.rds")
  saveRDS(list(ok = TRUE), live_path)
  live <- file.path(tmp, "covr_trace_live")
  saveRDS(
    structure(list(counters_file = live_path, counts = c(a = 1)), class = "covr_counts"),
    live
  )
  pending <- file.path(tmp, "covr_pending_1_abc")
  saveRDS(list(marker = TRUE), pending)

  n <- retarget_missing_covr_counters(tmp, stable)
  if (!identical(n, 1L)) fail("expected 1 retargeted trace, got %s", n)
  fixed <- readRDS(trace)
  if (!identical(fixed[["counters_file"]], stable)) fail("dead trace was not retargeted")
  if (!identical(fixed[["counts"]], c(a = 2))) fail("retarget changed the hit counts")
  if (!identical(readRDS(kept), list(value = 1L))) fail("non-covr_counts trace was rewritten")
  if (!identical(readRDS(live)[["counters_file"]], live_path)) fail("live counters path was rewritten")
  if (!identical(readRDS(pending), list(marker = TRUE))) fail("pending marker was rewritten")
  if (length(list.files(tmp, pattern = "[.]retarget$")) != 0L) fail("retarget tempfile was left behind")

  orphan <- file.path(tmp, "covr_trace_orphan")
  saveRDS(
    structure(list(counters_file = dead, counts = c(a = 3)), class = "covr_counts"),
    orphan
  )
  blew <- tryCatch(
    retarget_missing_covr_counters(tmp, file.path(tmp, "no-such-counters.rds")),
    error = function(e) conditionMessage(e)
  )
  if (!is.character(blew) || !grepl("missing counters file", blew, fixed = TRUE)) {
    fail("missing stable counters file did not stop the retarget, got %s", paste(blew, collapse = " "))
  }
  if (!identical(readRDS(trace)[["counters_file"]], stable)) {
    fail("a failed retarget rewrote a trace that was already fixed")
  }

  cat("retarget_covr_traces: PASS\n")
})
