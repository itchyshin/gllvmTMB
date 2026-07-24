#!/usr/bin/env Rscript
# Deterministic NON_EVIDENCE timing only; this script cannot create a real lock.
d99_args <- commandArgs(trailingOnly = TRUE)
d99_arg <- function(flag, default = NULL) { i <- match(flag, d99_args); if (is.na(i)) default else d99_args[[i + 1L]] }
d99_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
d99_here <- normalizePath(file.path(dirname(d99_file), ".."), mustWork = TRUE)
for (f in c("records.R", "numerics.R", "charts.R", "aghq.R", "fixture.R", "task-graph.R")) source(file.path(d99_here, "R", f))
root <- d99_arg("--output-root")
if (is.null(root)) stop("--output-root is required", call. = FALSE)
if (file.exists(file.path(root, "REAL_RUN.json"))) stop("NON_EVIDENCE benchmark root is locked", call. = FALSE)
receipt <- file.path(root, "compute-route.json")
if (file.exists(receipt)) stop("Compute-route receipt already exists", call. = FALSE)
mock <- d99_arg("--mock-elapsed-s")
if (is.null(mock)) {
  set.seed(992L)
  y <- matrix(rbinom(128L * 6L, 1L, .47), ncol = 6L)
  counts <- d99_pattern_counts(y)
  theta <- d99_chart_pack(d99_empirical_beta(y), d99_fixed_loading(), "C12", 4)
  elapsed <- system.time(d99_eval_chart(theta, counts, "C12", 4, d99_gh_rule(9L), FALSE))["elapsed"]
  mock_used <- FALSE
} else {
  elapsed <- as.numeric(mock)
  if (!is.finite(elapsed) || elapsed < 0) stop("--mock-elapsed-s must be finite and non-negative", call. = FALSE)
  mock_used <- TRUE
}
graph <- d99_build_task_graph("NON_EVIDENCE")
phase_weights <- vapply(graph, function(task) {
  if (task$task_class %in% c("cell-evaluator", "oracle", "n-evaluator", "finalizer")) return(1)
  h <- as.numeric(sub(".*H", "", task$task_class)); (as.numeric(task$n) / 128) * (h / 9)^2
}, numeric(1))
projected_s <- unname(elapsed) * sum(phase_weights)
route <- if (projected_s <= 45 * 60) "LOCAL" else "TOTORO"
d99_write_exclusive_json(receipt, list(schema = "d99-compute-route-v1", status = "PASS",
  mode = "NON_EVIDENCE", synthetic_seed = 992L, approved_fixture_seed_used = FALSE,
  real_uuid_used = FALSE, mock_elapsed = mock_used, sample_elapsed_s = unname(elapsed),
  projected_full_graph_s = projected_s, threshold_s = 45 * 60, route = route,
  task_count = length(graph), created_at = d99_now()))
cat("Design-99 NON_EVIDENCE projected route: ", route, "\n", sep = "")
