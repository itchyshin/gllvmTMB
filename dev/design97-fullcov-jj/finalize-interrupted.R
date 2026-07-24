#!/usr/bin/env Rscript
# Emergency closeout only: it never fits, retries, or changes an existing record.
stopifnot(requireNamespace("jsonlite", quietly=TRUE))
out <- file.path("dev", "design97-fullcov-jj", "results")
stopifnot(dir.exists(out), !file.exists(file.path(out, "summary.json")))
atomic_json <- function(path, object) {
  if (file.exists(path)) stop("Refusing overwrite: ", path)
  con <- file(path, open="wx"); on.exit(close(con), add=TRUE)
  writeLines(jsonlite::toJSON(object, auto_unbox=TRUE, null="null", na="null", digits=16, pretty=TRUE), con)
}
atomic_json(file.path(out, "gate3-free.json"), list(
  label="free", status="RUNNER_INTERRUPTED_BEFORE_GATE3_RECORD",
  healthy=FALSE, attempted_fit=NA, retry_permitted=FALSE,
  reason="The one-shot runner produced immutable manifest, fixtures, and Gate-2 record but no Gate-3 record or summary. No fit is replayed; this receipt closes the design.",
  completed_utc=format(Sys.time(),tz="UTC",usetz=TRUE)))
atomic_json(file.path(out, "summary.json"), list(
  design=97L, verdict="SMOKE_STOP", health=FALSE,
  reason="RUNNER_INTERRUPTED_BEFORE_GATE3_RECORD", retry_permitted=FALSE,
  completed_utc=format(Sys.time(),tz="UTC",usetz=TRUE)))
cat("Design 97 verdict: SMOKE_STOP (runner interrupted before Gate 3 record)\n")
