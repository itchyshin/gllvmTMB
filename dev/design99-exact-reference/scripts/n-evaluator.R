#!/usr/bin/env Rscript
d99_args <- commandArgs(trailingOnly = TRUE); d99_arg <- function(f, d = NULL) { i <- match(f, d99_args); if (is.na(i)) d else d99_args[[i + 1L]] }
d99_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]); d99_here <- normalizePath(file.path(dirname(d99_file), ".."), mustWork = TRUE)
for (f in c("records.R", "task-graph.R", "numerics.R", "charts.R", "aghq.R", "optimizers.R")) source(file.path(d99_here, "R", f))
root <- d99_arg("--output-root"); input_path <- d99_arg("--input"); input <- d99_read_json(input_path)
if (!d99_validate_input(input)) stop("Malformed immutable N-evaluator input", call. = FALSE)
graph <- d99_build_task_graph(input$run_id); task <- graph[[input$task_id]]
if (is.null(task) || !identical(task$task_class, "n-evaluator")) stop("Expected a frozen N-evaluator task", call. = FALSE)
ih <- d99_sha256_file(input_path); started <- d99_now(); d99_write_heartbeat(root, task$task_id, 1L, "started")
records <- lapply(task$dependencies, function(id) d99_read_terminal(root, graph[[id]])); names(records) <- task$dependencies
allowed_block <- function(id, rec) {
  if (is.null(rec) || !identical(rec$status, "DEPENDENCY_BLOCKED") || !identical(as.integer(task$n), 128L)) return(FALSE)
  cell_id <- sub("^oracle", "cell", id); cell <- d99_read_terminal(root, graph[[cell_id]])
  !is.null(cell) && identical(cell$status, "DIAGNOSTIC_N128_NONINTERIOR")
}
if (any(vapply(records, is.null, logical(1)))) {
  d99_write_terminal(root, task, "MISSING_DEPENDENCY", ih, list(started_at = started, dependency_ids = task$dependencies, mode = d99_or(input$mode, "NON_EVIDENCE"))); quit(status = 0L)
}
ids <- names(records); statuses <- vapply(records, `[[`, character(1), "status")
if (any(statuses != "PASS")) {
  diagnostic <- identical(as.integer(task$n), 128L) && all(vapply(ids, function(id) identical(records[[id]]$status, "PASS") || allowed_block(id, records[[id]]), logical(1)))
  d99_write_terminal(root, task, if (diagnostic) "DIAGNOSTIC_N128_NONINTERIOR" else "TECHNICAL_INCOMPLETE", ih,
    list(started_at = started, dependency_ids = task$dependencies, oracle_status = statuses, mode = d99_or(input$mode, "NON_EVIDENCE"))); quit(status = 0L)
}
if (any(!vapply(records, function(x) d99_validate_dependency_payload(root, x, TRUE), logical(1)))) {
  d99_write_terminal(root, task, "MECHANICAL_STOP", ih, list(started_at = started, dependency_ids = task$dependencies, error = "Oracle dependency hashes or payload are invalid", mode = d99_or(input$mode, "NON_EVIDENCE"))); quit(status = 0L)
}
payloads <- lapply(ids, function(id) d99_read_json(d99_payload_path(root, id))); names(payloads) <- ids
if (any(vapply(payloads, function(x) !is.list(x) || !isTRUE(x$ok) || !is.list(x$endpoint$invariants), logical(1)))) {
  d99_write_terminal(root, task, "QUADRATURE_STABILITY_STOP", ih, list(started_at = started, dependency_ids = task$dependencies, mode = d99_or(input$mode, "NON_EVIDENCE"))); quit(status = 0L)
}
invariants <- lapply(payloads, function(x) x$endpoint$invariants)
pairs <- combn(seq_along(invariants), 2L, function(ix) d99_invariant_agreement(invariants[[ix[1L]]], invariants[[ix[2L]]]), simplify = FALSE)
agreement <- list(beta_max = max(vapply(pairs, `[[`, numeric(1), "beta_max")), Sigma_max = max(vapply(pairs, `[[`, numeric(1), "Sigma_max")), population_probability_max = max(vapply(pairs, `[[`, numeric(1), "population_probability_max")))
agreement_ok <- all(is.finite(unlist(agreement))) && agreement$beta_max < 1e-3 && agreement$Sigma_max < 5e-3 && agreement$population_probability_max < 1e-4
diagnostics <- NULL; identification_ok <- TRUE
if (identical(as.integer(task$n), 2048L) && agreement_ok) {
  counts <- as.integer(unlist(input$fixture$counts$N2048, use.names = FALSE)); gh31 <- input$quadrature$rules$H31
  if (length(counts) != 64L || anyNA(counts) || !identical(d99_sha256_object(counts), input$fixture$pattern_count_hashes$N2048)) {
    d99_write_terminal(root, task, "MECHANICAL_STOP", ih, list(started_at = started, dependency_ids = task$dependencies, error = "N2048 count checksum is invalid", mode = d99_or(input$mode, "NON_EVIDENCE")))
    quit(status = 0L)
  }
  diagnostics <- lapply(ids, function(id) {
    endpoint <- payloads[[id]]$endpoint; oracle_task <- graph[[id]]; cap <- as.numeric(sub("^cap", "", endpoint$task$guard))
    identification <- d99_pattern_probability_jacobian(endpoint$theta, oracle_task$chart, cap, gh31, counts = counts)
    information <- d99_observed_information(endpoint$theta, counts, oracle_task$chart, cap, gh31)
    list(identification = identification, information = information, gate = d99_identification_gate(identification, information))
  }); names(diagnostics) <- ids
  identification_ok <- all(vapply(diagnostics, function(x) isTRUE(x$gate$ok), logical(1)))
}
ok <- agreement_ok && identification_ok
payload <- list(oracle_ids = ids, agreement = agreement, identification = diagnostics, endpoint_ids = vapply(payloads, `[[`, character(1), "selected_task_id"), n = task$n, ok = ok)
d99_write_payload(root, task$task_id, payload); d99_write_heartbeat(root, task$task_id, 2L, "finished")
status <- if (ok) "PASS" else if (identical(as.integer(task$n), 128L)) "DIAGNOSTIC_N128_NONINTERIOR" else if (identical(as.integer(task$n), 2048L) && !identification_ok) "WEAK_OR_NONIDENTIFIED_REFERENCE" else "OPTIMIZER_HEALTH_STOP"
d99_write_terminal(root, task, status, ih, list(started_at = started, dependency_ids = task$dependencies, payload_hash = d99_sha256_file(d99_payload_path(root, task$task_id)), mode = d99_or(input$mode, "NON_EVIDENCE")))
