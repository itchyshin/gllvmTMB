#!/usr/bin/env Rscript

# Design-100 private CLI (worktree-local). It exposes planning metadata only and intentionally
# refuses numerical execution until a separate, approved runner is supplied.

.d100_worker_root <- function() {
  argument <- commandArgs(trailingOnly = FALSE)
  script <- sub("^--file=", "", argument[grepl("^--file=", argument)])
  if (length(script) != 1L) {
    stop("Run this script with Rscript so its private root can be located.", call. = FALSE)
  }
  normalizePath(file.path(dirname(script), ".."), mustWork = TRUE)
}

.d100_worker_usage <- function() {
  paste(
    "Usage:",
    "  oracle-worker.R --plan <coordinate_hash> <pattern_code> <backend> [component]",
    "  oracle-worker.R --help",
    "",
    "`--execute` is intentionally unavailable in this contract-only worker.",
    sep = "\n"
  )
}

root <- .d100_worker_root()
source(file.path(root, "R", "independent-oracle.R"), local = globalenv())

arguments <- commandArgs(trailingOnly = TRUE)
if (identical(arguments, "--help") || !length(arguments)) {
  cat(.d100_worker_usage(), "\n")
  quit(status = 0L)
}

if (identical(arguments[[1L]], "--execute")) {
  d100_oracle_execution_guard(execute = TRUE)
}

if (!identical(arguments[[1L]], "--plan") || !(length(arguments) %in% c(4L, 5L))) {
  stop(.d100_worker_usage(), call. = FALSE)
}

task <- d100_oracle_task_input(
  coordinate_hash = arguments[[2L]],
  pattern_code = arguments[[3L]],
  backend = arguments[[4L]],
  component = if (length(arguments) == 5L) arguments[[5L]] else NULL
)
components <- if (is.null(task$component)) "component_pending" else task$component
events <- d100_oracle_emit_progress(task, components, emit = function(event) event)

print(list(
  record_type = "declarative_plan",
  status = "not_executed",
  task = as.list.environment(task, all.names = TRUE),
  declarative_progress = events,
  component_plan = lapply(components, function(component) {
    d100_oracle_component_plan(task, component)
  })
))
