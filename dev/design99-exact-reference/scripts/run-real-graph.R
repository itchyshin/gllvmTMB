#!/usr/bin/env Rscript
# Resume-only graph driver.  Existing launches or terminals are never replaced.
d99_args <- commandArgs(trailingOnly = TRUE)
d99_arg <- function(flag, default = NULL) { i <- match(flag, d99_args); if (is.na(i)) default else d99_args[[i + 1L]] }
d99_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
d99_here <- normalizePath(file.path(dirname(d99_file), ".."), mustWork = TRUE)
for (f in c("records.R", "task-graph.R")) source(file.path(d99_here, "R", f))
root <- d99_arg("--output-root")
if (is.null(root)) stop("--output-root is required", call. = FALSE)
manifest <- d99_read_json(file.path(root, "REAL_RUN.json"))
if (is.null(manifest) || !identical(manifest$mode, "REAL_RUN") || !identical(manifest$preflight_status, "PASS")) stop("A valid REAL_RUN preflight is required", call. = FALSE)
if (!identical(manifest$compute_route, "LOCAL")) stop("The requested compute route needs its dedicated launcher", call. = FALSE)
graph <- d99_build_task_graph(manifest$run_id)
if (!all(vapply(graph, function(task) file.exists(d99_input_path(root, task$task_id)), logical(1)))) stop("All 208 immutable inputs are required", call. = FALSE)
supervisor <- file.path(d99_here, "scripts", "supervise.R")
finalizer <- file.path(d99_here, "scripts", "finalize.R")
scientific <- setdiff(names(graph), "finalizer")
repeat {
  before <- sum(vapply(scientific, function(id) file.exists(d99_terminal_path(root, id)), logical(1)))
  if (before == length(scientific)) break
  out <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", supervisor, "--exclude-finalizer", "--output-root", root, "--run-id", manifest$run_id, "--mode", "REAL_RUN"), stdout = TRUE, stderr = TRUE)
  after <- sum(vapply(scientific, function(id) file.exists(d99_terminal_path(root, id)), logical(1)))
  if (!is.null(attr(out, "status")) || after == before) stop("Supervisor made no permitted progress; no retry or overwrite is allowed", call. = FALSE)
}
if (!file.exists(d99_terminal_path(root, "finalizer"))) {
  out <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", finalizer, "--input", d99_input_path(root, "finalizer"), "--output-root", root, "--run-id", manifest$run_id, "--mode", "REAL_RUN"), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(out, "status")) || !file.exists(d99_terminal_path(root, "finalizer"))) stop("Aggregation-only finalizer did not create its terminal", call. = FALSE)
}
cat("Design-99 graph terminal aggregation complete\n")
