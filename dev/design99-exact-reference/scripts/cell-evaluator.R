#!/usr/bin/env Rscript
d99_args <- commandArgs(trailingOnly = TRUE); d99_arg <- function(f, d = NULL) { i <- match(f, d99_args); if (is.na(i)) d else d99_args[[i + 1L]] }
d99_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]); d99_here <- normalizePath(file.path(dirname(d99_file), ".."), mustWork = TRUE)
for (f in c("records.R", "task-graph.R", "charts.R")) source(file.path(d99_here, "R", f))
root <- d99_arg("--output-root"); input_path <- d99_arg("--input"); input <- d99_read_json(input_path)
if (!d99_validate_input(input)) stop("Malformed immutable cell input", call. = FALSE)
graph <- d99_build_task_graph(input$run_id); task <- graph[[input$task_id]]
if (is.null(task) || !identical(task$task_class, "cell-evaluator")) stop("Expected a frozen cell evaluator task", call. = FALSE)
ih <- d99_sha256_file(input_path); started <- d99_now(); d99_write_heartbeat(root, task$task_id, 1L, "started")
records <- lapply(task$dependencies, function(id) d99_read_terminal(root, graph[[id]])); names(records) <- task$dependencies
if (any(vapply(records, is.null, logical(1)))) {
  d99_write_terminal(root, task, "MISSING_DEPENDENCY", ih, list(started_at = started, dependency_ids = task$dependencies, mode = d99_or(input$mode, "NON_EVIDENCE")))
  quit(status = 0L)
}
payloads <- lapply(task$dependencies, function(id) d99_read_json(d99_payload_path(root, id))); names(payloads) <- task$dependencies
artifact_ok <- vapply(records, function(x) d99_validate_dependency_payload(root, x, identical(x$status, "PASS")), logical(1))
if (!all(artifact_ok) || any(vapply(records, function(x) identical(x$status, "MECHANICAL_STOP"), logical(1)))) {
  d99_write_terminal(root, task, "MECHANICAL_STOP", ih, list(started_at = started, dependency_ids = task$dependencies, error = "Endpoint dependency schema/hash/payload failure", mode = d99_or(input$mode, "NON_EVIDENCE")))
  quit(status = 0L)
}
endpoint_ok <- vapply(seq_along(records), function(i) identical(records[[i]]$status, "PASS") && is.list(payloads[[i]]) && isTRUE(payloads[[i]]$health$ok), logical(1))
allowed_n128 <- identical(as.integer(task$n), 128L) && all(vapply(records, function(x) x$status %in% c("PASS", "DIAGNOSTIC_N128_NONINTERIOR", "OPTIMIZER_HEALTH_STOP"), logical(1)))
if (!all(endpoint_ok)) {
  status <- if (allowed_n128) "DIAGNOSTIC_N128_NONINTERIOR" else "OPTIMIZER_HEALTH_STOP"
  d99_write_terminal(root, task, status, ih, list(started_at = started, dependency_ids = task$dependencies, endpoint_status = vapply(records, `[[`, character(1), "status"), mode = d99_or(input$mode, "NON_EVIDENCE")))
  quit(status = 0L)
}
invariants <- lapply(payloads, `[[`, "invariants")
pairwise <- combn(seq_along(invariants), 2L, function(ix) d99_invariant_agreement(invariants[[ix[1L]]], invariants[[ix[2L]]]), simplify = FALSE)
objectives <- vapply(payloads, function(p) p$health$metrics$objective_h31, numeric(1))
agreement <- list(objective_per_unit = abs(max(objectives) - min(objectives)) / as.numeric(task$n),
  beta_max = max(vapply(pairwise, `[[`, numeric(1), "beta_max")), Sigma_max = max(vapply(pairwise, `[[`, numeric(1), "Sigma_max")),
  population_probability_max = max(vapply(pairwise, `[[`, numeric(1), "population_probability_max")))
ok <- all(is.finite(unlist(agreement))) && agreement$objective_per_unit < 1e-9 && agreement$beta_max < 1e-3 && agreement$Sigma_max < 5e-3 && agreement$population_probability_max < 1e-4
if (!ok) {
  status <- if (identical(as.integer(task$n), 128L)) "DIAGNOSTIC_N128_NONINTERIOR" else "OPTIMIZER_HEALTH_STOP"
  d99_write_terminal(root, task, status, ih, list(started_at = started, dependency_ids = task$dependencies, agreement = agreement, mode = d99_or(input$mode, "NON_EVIDENCE")))
  quit(status = 0L)
}
order_key <- order(vapply(payloads, function(p) p$health$metrics$objective_h31, numeric(1)),
  vapply(payloads, function(p) if (identical(p$task$guard, "cap4")) 0L else 1L, integer(1)),
  match(vapply(payloads, function(p) p$task$start, character(1)), c("fixed", "spectral", "truth")), decreasing = c(TRUE, FALSE, FALSE))
selected_id <- task$dependencies[[order_key[[1L]]]]; selected <- payloads[[selected_id]]
payload <- list(selected_task_id = selected_id, endpoint = selected, agreement = agreement, dependency_ids = task$dependencies)
d99_write_exclusive_json(d99_payload_path(root, task$task_id), payload); d99_write_heartbeat(root, task$task_id, 2L, "finished")
d99_write_terminal(root, task, "PASS", ih, list(started_at = started, dependency_ids = task$dependencies, payload_hash = d99_sha256_file(d99_payload_path(root, task$task_id)), mode = d99_or(input$mode, "NON_EVIDENCE")))
