#!/usr/bin/env Rscript
d99_args <- commandArgs(trailingOnly = TRUE); d99_arg <- function(f, d = NULL) { i <- match(f, d99_args); if (is.na(i)) d else d99_args[[i + 1L]] }
d99_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]); d99_here <- normalizePath(file.path(dirname(d99_file), ".."), mustWork = TRUE)
for (f in c("records.R", "task-graph.R", "numerics.R", "charts.R", "aghq.R", "optimizers.R", "independent-oracle.R")) source(file.path(d99_here, "R", f))
root <- d99_arg("--output-root"); input_path <- d99_arg("--input"); input <- d99_read_json(input_path)
if (!d99_validate_input(input)) stop("Malformed immutable oracle input", call. = FALSE)
graph <- d99_build_task_graph(input$run_id); task <- graph[[input$task_id]]
if (is.null(task) || !identical(task$task_class, "oracle")) stop("Expected a frozen oracle task", call. = FALSE)
ih <- d99_sha256_file(input_path); started <- d99_now(); d99_write_heartbeat(root, task$task_id, 1L, "started")
cell <- d99_read_terminal(root, graph[[task$dependencies[[1L]]]])
if (is.null(cell) || !identical(cell$status, "PASS")) {
  d99_write_terminal(root, task, "DEPENDENCY_BLOCKED", ih, list(started_at = started, dependency_ids = task$dependencies, allowed_n128_diagnostic = identical(as.integer(task$n), 128L) && !is.null(cell) && identical(cell$status, "DIAGNOSTIC_N128_NONINTERIOR"), mode = d99_or(input$mode, "NON_EVIDENCE")))
  quit(status = 0L)
}
if (!d99_validate_dependency_payload(root, cell, TRUE)) d99_abort_mechanical("Cell dependency hashes or payload are invalid", "DEPENDENCY_HASH")
selected <- d99_read_json(d99_payload_path(root, cell$task_id)); endpoint <- selected$endpoint
key <- paste0("N", task$n); counts <- as.integer(unlist(input$fixture$counts[[key]], use.names = FALSE))
if (is.null(endpoint) || length(counts) != 64L || anyNA(counts) || any(counts < 0L) ||
    !identical(d99_sha256_object(counts), input$fixture$pattern_count_hashes[[key]])) {
  d99_write_terminal(root, task, "MECHANICAL_STOP", ih, list(started_at = started, error = "Cell payload or immutable count vector is malformed", dependency_ids = task$dependencies, mode = d99_or(input$mode, "NON_EVIDENCE")))
  quit(status = 0L)
}
gh <- input$quadrature$rules$H31; tryCatch(d99_validate_gh(gh), error = function(e) d99_abort_mechanical(conditionMessage(e), "QUADRATURE_SCHEMA"))
all_patterns <- identical(as.integer(task$n), 2048L); cap <- as.numeric(sub("^cap", "", endpoint$task$guard))
ans <- tryCatch({
  J <- d99_chart_jacobian(endpoint$theta, task$chart, cap)
  agh <- d99_aghq_eval(counts, endpoint$beta, endpoint$Lambda, gh, TRUE, all_patterns = all_patterns)
  nested <- d99_oracle_eval(counts, endpoint$beta, endpoint$Lambda, "nested", all_patterns = all_patterns, chart_jacobian = J)
  cube <- d99_oracle_eval(counts, endpoint$beta, endpoint$Lambda, "cubature", all_patterns = all_patterns, chart_jacobian = J)
  observed <- if (all_patterns) seq_len(64L) else which(counts > 0); n <- sum(counts)
  nested_codes <- vapply(nested$backend_status_by_pattern[observed], function(x) is.list(x) && identical(x$message, "OK") && isTRUE(x$success), logical(1))
  cube_codes <- vapply(cube$backend_status_by_pattern[observed], function(x) is.list(x) && identical(as.integer(x$return_code), 0L) && isTRUE(x$success), logical(1))
  agh_chart_score <- drop(crossprod(J, agh$score)); xi <- d99_chart_to_xi(endpoint$theta, task$chart, cap)
  intervals <- d99_oracle_interval_gate(agh_chart_score, nested, cube, n, pmax(1, abs(xi)))
  chart_tail <- drop(crossprod(abs(J), cube$tail_bounds$invariant))
  metrics <- list(
    agh_nested_loglik_per_unit = abs(agh$loglik - nested$loglik) / n,
    agh_cubature_loglik_per_unit = abs(agh$loglik - cube$loglik) / n,
    nested_cubature_loglik_per_unit = abs(nested$loglik - cube$loglik) / n,
    interval_score_distance = intervals$scaled_distance,
    nested_interval_error = intervals$nested_error, cubature_interval_error = intervals$cubature_error,
    maximum_chart_tail = max(chart_tail),
    agh_nested_pattern = max(abs(agh$log_prob[observed] - nested$log_prob[observed])),
    agh_cubature_pattern = max(abs(agh$log_prob[observed] - cube$log_prob[observed])),
    nested_cubature_pattern = max(abs(nested$log_prob[observed] - cube$log_prob[observed])))
  if (all_patterns) {
    metrics$probability_sum <- abs(sum(cube$prob) - 1)
    metrics$probability_score_sum <- max(abs(colSums(cube$prob * cube$chart_score_by_pattern)))
  }
  ok <- isTRUE(nested$success) && isTRUE(cube$success) && all(nested_codes) && all(cube_codes) &&
    isTRUE(intervals$ok) && max(chart_tail) < 5e-7 && all(is.finite(unlist(metrics))) &&
    max(unlist(metrics[grep("loglik", names(metrics))])) < 1e-8 &&
    max(unlist(metrics[grep("pattern", names(metrics))])) < 1e-7 &&
    (!all_patterns || (metrics$probability_sum < 1e-10 && metrics$probability_score_sum < 1e-8))
  list(ok = ok, metrics = metrics, certified_intervals = intervals, backend_success = list(nested = nested_codes, cubature = cube_codes),
       selected_task_id = selected$selected_task_id, endpoint = endpoint, all_patterns = all_patterns)
}, error = identity)
if (inherits(ans, "error")) {
  d99_write_terminal(root, task, d99_error_status(ans, "QUADRATURE_STABILITY_STOP"), ih, list(started_at = started, error = conditionMessage(ans), dependency_ids = task$dependencies, mode = d99_or(input$mode, "NON_EVIDENCE")))
} else {
  d99_write_payload(root, task$task_id, ans); d99_write_heartbeat(root, task$task_id, 2L, "finished")
  d99_write_terminal(root, task, if (ans$ok) "PASS" else "QUADRATURE_STABILITY_STOP", ih, list(started_at = started, dependency_ids = task$dependencies, payload_hash = d99_sha256_file(d99_payload_path(root, task$task_id)), mode = d99_or(input$mode, "NON_EVIDENCE")))
}
