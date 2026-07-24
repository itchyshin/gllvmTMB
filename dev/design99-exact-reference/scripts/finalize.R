#!/usr/bin/env Rscript
# G8 is aggregation-only: no fixture, objective, optimiser, oracle, or worker source.
d99_args <- commandArgs(trailingOnly = TRUE); d99_arg <- function(f, d = NULL) { i <- match(f, d99_args); if (is.na(i)) d else d99_args[[i + 1L]] }
d99_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]); d99_here <- normalizePath(file.path(dirname(d99_file), ".."), mustWork = TRUE)
source(file.path(d99_here, "R", "records.R")); source(file.path(d99_here, "R", "task-graph.R"))
root <- d99_arg("--output-root"); run_id <- d99_arg("--run-id"); graph <- d99_build_task_graph(run_id); task <- graph[["finalizer"]]
input_path <- d99_arg("--input", d99_input_path(root, task$task_id)); ih <- if (file.exists(input_path)) d99_sha256_file(input_path) else d99_arg("--input-hash", "NON_EVIDENCE")
label <- d99_classify_terminals(root, graph)
d99_write_terminal(root, task, label, ih, list(aggregate_only = TRUE, mode = d99_arg("--mode", "NON_EVIDENCE"), expected_tasks = 208L, dependency_ids = task$dependencies,
  telemetry = list(classification_order = c("PROVENANCE_STOP", "INFRASTRUCTURE_INCOMPLETE", "TECHNICAL_INCOMPLETE", "MECHANICAL_STOP", "QUADRATURE_STABILITY_STOP", "WEAK_OR_NONIDENTIFIED_REFERENCE", "OPTIMIZER_HEALTH_STOP", "BOUNDED_ORACLE_PASS"))))
