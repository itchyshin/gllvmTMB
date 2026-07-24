#!/usr/bin/env Rscript
# One immutable optimizer phase per process.  This script deliberately has no
# retry, fallback, fixture creation, or REAL_RUN path.
d99_args <- commandArgs(trailingOnly = TRUE)
d99_arg <- function(flag, default = NULL) { i <- match(flag, d99_args); if (is.na(i)) default else d99_args[[i + 1L]] }
d99_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
d99_here <- normalizePath(file.path(dirname(d99_file), ".."), mustWork = TRUE)
for (f in c("records.R", "task-graph.R", "numerics.R", "charts.R", "aghq.R", "fixture.R", "optimizers.R")) source(file.path(d99_here, "R", f))

root <- d99_arg("--output-root"); input_path <- d99_arg("--input")
if (is.null(root) || is.null(input_path) || !file.exists(input_path)) stop("A readable immutable --input and --output-root are required", call. = FALSE)
input <- d99_read_json(input_path)
if (!d99_validate_input(input)) stop("Malformed immutable worker input", call. = FALSE)
graph <- d99_build_task_graph(input$run_id); task <- graph[[input$task_id]]
if (is.null(task) || !task$task_class %in% c("A-H9", "A-H15", "A-H31", "B-H15", "B-H31") ||
    !identical(task$task_class, input$task_class)) stop("Input does not name a frozen optimizer-phase task", call. = FALSE)
ih <- d99_sha256_file(input_path); started <- d99_now(); d99_write_heartbeat(root, task$task_id, 1L, "started")
d99_write_log_chunk(root, task$task_id, "stdout", 1L, paste("phase", task$task_class, "started", started))

d99_counts_from_input <- function(x, n) {
  key <- paste0("N", n)
  counts <- x$fixture$counts[[key]]
  if (is.null(counts)) counts <- x$fixture[[key]]$counts
  if (is.null(counts)) stop("Immutable input has no supplied pattern counts for ", key, call. = FALSE)
  counts <- as.integer(unlist(counts, use.names = FALSE))
  if (length(counts) != 64L || anyNA(counts) || any(counts < 0L)) d99_abort_mechanical("Pattern counts are malformed", "COUNT_SCHEMA")
  expected <- x$fixture$pattern_count_hashes[[key]]
  if (is.null(expected) || !identical(d99_sha256_object(counts), expected)) d99_abort_mechanical("Pattern-count checksum mismatch", "COUNT_CHECKSUM")
  d99_validate_counts(counts)
}
d99_rule_from_input <- function(x, key) {
  rule <- x$quadrature$rules[[key]]
  if (is.null(rule)) d99_abort_mechanical(paste("Immutable input has no quadrature rule", key), "QUADRATURE_SCHEMA")
  tryCatch(d99_validate_gh(rule), error = function(e) d99_abort_mechanical(conditionMessage(e), "QUADRATURE_SCHEMA")); rule
}
d99_start_from_input <- function(x, task) {
  theta <- x$start_coordinates[[task$start]]
  if (is.null(theta)) theta <- x$starts[[task$start]]
  if (is.null(theta)) d99_abort_mechanical("Immutable input has no frozen start coordinate", "START_SCHEMA")
  theta <- as.numeric(unlist(theta, use.names = FALSE))
  if (length(theta) != 17L || any(!is.finite(theta))) d99_abort_mechanical("Frozen start coordinate is malformed", "START_SCHEMA")
  theta
}
d99_dependency_theta <- function() {
  if (!length(task$dependencies)) return(d99_start_from_input(input, task))
  dep <- d99_read_terminal(root, graph[[task$dependencies[[1L]]]])
  if (is.null(dep) || !identical(dep$status, "PASS")) stop("Required dependency endpoint is not a passing terminal", call. = FALSE)
  payload <- d99_read_json(d99_payload_path(root, dep$task_id))
  theta <- as.numeric(unlist(payload$theta, use.names = FALSE))
  if (length(theta) != 17L || any(!is.finite(theta))) stop("Dependency terminal has no valid endpoint coordinate", call. = FALSE)
  theta
}
d99_phase <- function() {
  counts <- d99_counts_from_input(input, task$n)
  cap <- as.numeric(sub("^cap", "", task$guard)); chart <- task$chart
  h9 <- d99_rule_from_input(input, "H9"); h15 <- d99_rule_from_input(input, "H15")
  h21 <- d99_rule_from_input(input, "H21"); h31 <- d99_rule_from_input(input, "H31")
  theta0 <- d99_dependency_theta(); warnings <- character()
  withCallingHandlers({
    if (identical(task$task_class, "A-H9")) {
      ans <- nloptr::nloptr(x0 = theta0, eval_f = function(z) d99_mean_negloglik(z, counts, chart, cap, h9),
        lb = rep(-12, 17L), ub = rep(12, 17L), opts = list(algorithm = "NLOPT_LN_BOBYQA", xtol_rel = 1e-8, ftol_abs = 1e-10, maxeval = 2000L, print_level = 0L))
      return(list(theta = ans$solution, phase = list(code = ans$status, message = ans$message), warnings = warnings))
    }
    if (identical(task$task_class, "A-H15") || identical(task$task_class, "A-H31")) {
      rule <- if (identical(task$task_class, "A-H15")) h15 else h31
      control <- if (identical(task$task_class, "A-H15")) list(maxit = 500L, reltol = 1e-10) else list(maxit = 200L, reltol = 1e-12)
      ans <- stats::optim(theta0, fn = function(z) d99_mean_negloglik(z, counts, chart, cap, rule),
        gr = function(z) d99_finite_rule_gradient(z, counts, chart, cap, rule), method = "BFGS", control = control)
      return(list(theta = ans$par, phase = list(code = ans$convergence, message = ans$message, value = ans$value), warnings = warnings))
    }
    rule <- if (identical(task$task_class, "B-H15")) h15 else h31
    maxit <- if (identical(task$task_class, "B-H15")) 100L else 50L
    ans <- d99_damped_newton_score(theta0, counts, chart, cap, rule, maxit = maxit)
    if (!isTRUE(ans$healthy)) stop(ans$error, call. = FALSE)
    list(theta = ans$theta, phase = list(code = 0L, scaled_norm = ans$scaled_norm, trace = ans$trace), warnings = warnings)
  }, warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") })
}
d99_endpoint <- function(theta, phase) {
  if (!exists("d99_certify_endpoint", mode = "function")) {
    stop("Required d99_certify_endpoint() is unavailable; do not duplicate certification mechanics in the worker", call. = FALSE)
  }
  counts <- d99_counts_from_input(input, task$n); cap <- as.numeric(sub("^cap", "", task$guard))
  certificate <- d99_certify_endpoint(theta, counts, task$chart, cap,
    d99_rule_from_input(input, "H21"), d99_rule_from_input(input, "H31"))
  value <- certificate$evaluations$H31$chart_value
  list(theta = theta, phase = phase, beta = value$beta, Lambda = value$Lambda,
       invariants = certificate$invariant,
       health = list(ok = isTRUE(certificate$healthy), metrics = c(certificate$metrics, list(objective_h31 = certificate$loglik))),
       certification = certificate, task = task[c("n", "route", "chart", "start", "guard")])
}

result <- tryCatch({ phase <- d99_phase(); endpoint <- d99_endpoint(phase$theta, phase$phase); list(ok = isTRUE(endpoint$health$ok), endpoint = endpoint, warnings = phase$warnings) }, error = identity)
if (inherits(result, "error")) {
  d99_write_log_chunk(root, task$task_id, "stderr", 1L, conditionMessage(result))
  d99_write_terminal(root, task, d99_error_status(result), ih, list(started_at = started, mode = d99_or(input$mode, "NON_EVIDENCE"), error = conditionMessage(result), dependency_ids = task$dependencies))
} else {
  d99_write_payload(root, task$task_id, result$endpoint)
  d99_write_heartbeat(root, task$task_id, 2L, "finished")
  d99_write_terminal(root, task, if (result$ok) "PASS" else "OPTIMIZER_HEALTH_STOP", ih,
    list(started_at = started, mode = d99_or(input$mode, "NON_EVIDENCE"), dependencies = task$dependencies,
         payload_hash = d99_sha256_file(d99_payload_path(root, task$task_id)), warnings = result$warnings))
}
