# Exact frozen Design-99 graph.  This declares work; it does not execute it.

d99_timeout <- function(task_class, n = NULL) {
  if (identical(task_class, "preflight")) return(600L)
  if (task_class %in% c("cell-evaluator", "n-evaluator", "finalizer")) return(300L)
  if (identical(task_class, "oracle")) return(1800L)
  if (grepl("^A-H9$", task_class)) return(c(`128` = 1800L, `512` = 3600L, `2048` = 7200L)[[as.character(n)]])
  if (grepl("^(A-H15|A-H31|B-H15|B-H31)$", task_class)) return(c(`128` = 3600L, `512` = 7200L, `2048` = 14400L)[[as.character(n)]])
  stop("Unknown frozen task class", call. = FALSE)
}

d99_task_id <- function(...) paste(..., sep = "-")
d99_new_task <- function(id, cls, run_id, n = NULL, route = NULL, chart = NULL,
                         start = NULL, guard = NULL, dependencies = character()) {
  list(task_id = id, task_class = cls, run_id = run_id, n = n, route = route,
       chart = chart, start = start, guard = guard, dependencies = dependencies,
       timeout_s = d99_timeout(cls, n))
}

d99_build_task_graph <- function(run_id) {
  ns <- c(128L, 512L, 2048L); charts <- c("C12", "C34")
  starts <- c("fixed", "spectral", "truth"); guards <- c("cap4", "cap8")
  out <- list()
  for (n in ns) for (chart in charts) for (start in starts) for (guard in guards) {
    a9 <- d99_task_id("A", n, chart, start, guard, "H9")
    a15 <- d99_task_id("A", n, chart, start, guard, "H15")
    a31 <- d99_task_id("A", n, chart, start, guard, "H31")
    out[[a9]] <- d99_new_task(a9, "A-H9", run_id, n, "A", chart, start, guard)
    out[[a15]] <- d99_new_task(a15, "A-H15", run_id, n, "A", chart, start, guard, a9)
    out[[a31]] <- d99_new_task(a31, "A-H31", run_id, n, "A", chart, start, guard, a15)
    b15 <- d99_task_id("B", n, chart, start, guard, "H15")
    b31 <- d99_task_id("B", n, chart, start, guard, "H31")
    out[[b15]] <- d99_new_task(b15, "B-H15", run_id, n, "B", chart, start, guard)
    out[[b31]] <- d99_new_task(b31, "B-H31", run_id, n, "B", chart, start, guard, b15)
  }
  for (n in ns) for (route in c("A", "B")) for (chart in charts) {
    phase <- if (route == "A") "H31" else "H31"
    grid <- expand.grid(start = starts, guard = guards, stringsAsFactors = FALSE)
    deps <- vapply(seq_len(nrow(grid)), function(i)
      d99_task_id(route, n, chart, grid$start[[i]], grid$guard[[i]], phase), character(1))
    id <- d99_task_id("cell", n, route, chart)
    out[[id]] <- d99_new_task(id, "cell-evaluator", run_id, n, route, chart, dependencies = unname(deps))
    oid <- d99_task_id("oracle", n, route, chart)
    out[[oid]] <- d99_new_task(oid, "oracle", run_id, n, route, chart, dependencies = id)
  }
  for (n in ns) {
    id <- d99_task_id("N", n)
    deps <- unlist(lapply(c("A", "B"), function(route) vapply(charts, function(chart)
      d99_task_id("oracle", n, route, chart), character(1))))
    out[[id]] <- d99_new_task(id, "n-evaluator", run_id, n, dependencies = deps)
  }
  out[["finalizer"]] <- d99_new_task("finalizer", "finalizer", run_id,
                                       dependencies = vapply(ns, function(n) d99_task_id("N", n), character(1)))
  if (length(out) != 208L) stop("Frozen Design-99 graph is not exactly 208 tasks", call. = FALSE)
  out
}

d99_input_for_task <- function(task, contract_hash, source_hashes, quadrature,
                               fixture, run_id = task$run_id) {
  x <- c(list(schema = "d99-input-v1", task_id = task$task_id,
              task_class = task$task_class, run_id = run_id,
              dependencies = unname(task$dependencies), timeout_s = task$timeout_s,
              contract_hash = contract_hash, source_hashes = source_hashes,
              runtime = d99_runtime_metadata(), quadrature = quadrature,
              fixture = fixture), task[c("n", "route", "chart", "start", "guard")])
  if (!d99_validate_input(x)) stop("Invalid Design-99 task input", call. = FALSE)
  x
}

d99_write_task_input <- function(root, input) {
  d99_write_exclusive_json(d99_input_path(root, input$task_id), input)
  d99_sha256_file(d99_input_path(root, input$task_id))
}

d99_dependency_state <- function(root, task, graph) {
  if (!length(task$dependencies)) return(list(state = "ready", records = list()))
  records <- lapply(task$dependencies, function(id) d99_read_terminal(root, graph[[id]]))
  names(records) <- task$dependencies
  if (any(vapply(records, is.null, logical(1)))) return(list(state = "waiting", records = records))
  if (all(vapply(records, function(x) identical(x$status, "PASS"), logical(1)))) return(list(state = "ready", records = records))
  list(state = "blocked", records = records)
}

d99_oracle_interval_gate <- function(agh_score, nested, cubature, n, scale,
                                     score_tolerance = 5e-6,
                                     error_limit = 5e-7) {
  n <- as.numeric(n)
  if (!is.finite(n) || n <= 0) return(list(ok = FALSE, reason = "invalid sample size"))
  agh <- as.numeric(agh_score) / n
  nlo <- as.numeric(nested$chart_score_lower) / n; nhi <- as.numeric(nested$chart_score_upper) / n
  clo <- as.numeric(cubature$chart_score_lower) / n; chi <- as.numeric(cubature$chart_score_upper) / n
  distance <- function(x, lo, hi) pmax(lo - x, 0, x - hi)
  nested_error <- max((nhi - nlo) / 2)
  cubature_error <- max((chi - clo) / 2)
  overlap <- all(pmax(nlo, clo) <= pmin(nhi, chi))
  scaled_distance <- max(as.numeric(scale) * pmax(distance(agh, nlo, nhi), distance(agh, clo, chi)))
  ok <- all(is.finite(c(agh, nlo, nhi, clo, chi, nested_error, cubature_error, scaled_distance))) &&
    overlap && nested_error < error_limit && cubature_error < error_limit && scaled_distance < score_tolerance
  list(ok = ok, intervals_overlap = overlap, nested_error = nested_error,
       cubature_error = cubature_error, scaled_distance = scaled_distance,
       nested = list(lower = nlo, upper = nhi), cubature = list(lower = clo, upper = chi))
}

d99_identification_gate <- function(identification, information) {
  profile <- identification$profile
  valid_profile <- is.list(profile) && length(profile) == 9L && all(vapply(profile, function(x) isTRUE(x$valid) && is.finite(d99_or(x$delta_per_unit, 0)), logical(1)))
  nonzero <- if (valid_profile) vapply(profile, function(x) if (x$displacement == 0) NA_real_ else abs(x$delta_per_unit), numeric(1)) else NA_real_
  checks <- c(
    richardson = is.finite(identification$richardson_relative_error) && identification$richardson_relative_error < 1e-6,
    rank_1e8 = length(identification$rank) >= 2L && identical(as.integer(identification$rank[[2L]]), 17L),
    reciprocal_condition = is.finite(identification$reciprocal_condition) && identification$reciprocal_condition > 1e-8,
    information_finite = all(is.finite(c(information$scaled_matrix, information$eigenvalues, information$condition))),
    information_curvature = length(information$eigenvalues) == 17L && min(information$eigenvalues) >= -1e-8,
    information_condition = is.finite(information$condition) && information$condition < 1e8,
    profile_valid = valid_profile,
    profile_nonflat = valid_profile && max(nonzero, na.rm = TRUE) > 1e-8
  )
  list(ok = all(checks), checks = checks, failed_checks = names(checks)[!checks])
}

d99_classify_terminals <- function(root, graph) {
  scientific <- graph[setdiff(names(graph), "finalizer")]
  if (d99_is_real_run(root)) {
    expected <- names(graph)
    input_ids <- if (dir.exists(file.path(root, "inputs"))) sub("\\.json$", "", list.files(file.path(root, "inputs"), pattern = "\\.json$")) else character()
    launch_ids <- if (dir.exists(file.path(root, "launches"))) sub("\\.json$", "", list.files(file.path(root, "launches"), pattern = "\\.json$")) else character()
    payload_ids <- if (dir.exists(file.path(root, "payloads"))) sub("\\.json$", "", list.files(file.path(root, "payloads"), pattern = "\\.json$")) else character()
    if (!setequal(input_ids, expected) || length(setdiff(launch_ids, expected)) || length(setdiff(payload_ids, expected))) return("TECHNICAL_INCOMPLETE")
  }
  record_files <- if (dir.exists(file.path(root, "records"))) sub("\\.json$", "", list.files(file.path(root, "records"), pattern = "\\.json$")) else character()
  unexpected <- setdiff(record_files, c(names(scientific), "finalizer"))
  if (length(unexpected)) return("TECHNICAL_INCOMPLETE")
  records <- lapply(scientific, function(task) d99_read_terminal(root, task))
  valid <- records[!vapply(records, is.null, logical(1))]
  status <- if (length(valid)) vapply(valid, `[[`, character(1), "status") else character()
  # The only non-PASS dependency block that can survive aggregation is an
  # oracle blocked by its own N128 diagnostic cell.
  allowed_block <- function(id, rec) {
    if (!identical(rec$status, "DEPENDENCY_BLOCKED") || !startsWith(id, "oracle-128-")) return(FALSE)
    cell_id <- sub("^oracle", "cell", id)
    cell <- records[[cell_id]]
    !is.null(cell) && identical(cell$status, "DIAGNOSTIC_N128_NONINTERIOR")
  }
  if (any(status %in% c("PROVENANCE_STOP", "SCOPE_STOP"))) return("PROVENANCE_STOP")
  if (any(status %in% c("INFRASTRUCTURE_FAILURE", "TIMEOUT", "ORPHAN", "INTERRUPTED", "CRASH", "SIGNALED", "LAUNCH_FAILURE"))) return("INFRASTRUCTURE_INCOMPLETE")
  if (any(vapply(records, is.null, logical(1)))) return("TECHNICAL_INCOMPLETE")
  blocked <- names(records)[vapply(records, function(x) identical(x$status, "DEPENDENCY_BLOCKED"), logical(1))]
  if (length(blocked) && !all(vapply(blocked, function(id) allowed_block(id, records[[id]]), logical(1)))) return("TECHNICAL_INCOMPLETE")
  if (any(status %in% c("MALFORMED", "MISSING_DEPENDENCY", "TECHNICAL_INCOMPLETE"))) return("TECHNICAL_INCOMPLETE")
  if (any(status %in% c("MECHANICAL_STOP"))) return("MECHANICAL_STOP")
  if (any(status %in% c("QUADRATURE_STABILITY_STOP"))) return("QUADRATURE_STABILITY_STOP")
  if (any(status %in% c("WEAK_OR_NONIDENTIFIED_REFERENCE"))) return("WEAK_OR_NONIDENTIFIED_REFERENCE")
  allowed_n128_optimizer <- function(id, rec) {
    task <- scientific[[id]]
    if (!identical(rec$status, "OPTIMIZER_HEALTH_STOP") || !identical(as.integer(task$n), 128L) || is.null(task$route) || is.null(task$chart)) return(FALSE)
    cell <- records[[d99_task_id("cell", 128L, task$route, task$chart)]]
    !is.null(cell) && identical(cell$status, "DIAGNOSTIC_N128_NONINTERIOR")
  }
  optimizer_stops <- names(records)[vapply(records, function(x) identical(x$status, "OPTIMIZER_HEALTH_STOP"), logical(1))]
  if (length(optimizer_stops) && !all(vapply(optimizer_stops, function(id) allowed_n128_optimizer(id, records[[id]]), logical(1)))) return("OPTIMIZER_HEALTH_STOP")
  allowed_n128 <- names(records)[vapply(records, function(x) identical(x$status, "DIAGNOSTIC_N128_NONINTERIOR"), logical(1))]
  if (length(allowed_n128) && any(!grepl("^(cell-128-|N-128$)", allowed_n128))) return("TECHNICAL_INCOMPLETE")
  tolerated <- vapply(names(records), function(id) {
    rec <- records[[id]]
    identical(rec$status, "PASS") || identical(rec$status, "DIAGNOSTIC_N128_NONINTERIOR") ||
      allowed_block(id, rec) || allowed_n128_optimizer(id, rec)
  }, logical(1))
  if (all(tolerated)) "BOUNDED_ORACLE_PASS" else "TECHNICAL_INCOMPLETE"
}

d99_reconcile_unfinished_launches <- function(root, graph, reason = "ORPHAN") {
  # Resume never relaunches an unfinished process: an old immutable launch with
  # no immutable terminal is itself evidence of an interrupted parent/process.
  for (task in graph) {
    launch_path <- d99_launch_path(root, task$task_id)
    if (!file.exists(launch_path) || file.exists(d99_terminal_path(root, task$task_id))) next
    launch <- d99_read_json(launch_path)
    # Resume retains an old, schema-valid launch as an orphan rather than
    # manufacturing a second launch.  New launches are validated strictly by
    # the supervisor before they are ever written.
    task_reason <- if (is.null(launch) || !identical(launch$schema, "d99-launch-v1")) "INFRASTRUCTURE_FAILURE" else reason
    d99_write_terminal(root, task, task_reason, d99_or(launch$input_hash, "UNKNOWN"),
                       list(interrupted_parent = d99_or(launch$parent_pid, NA_integer_), resumed_at = d99_now()))
  }
  invisible(TRUE)
}
