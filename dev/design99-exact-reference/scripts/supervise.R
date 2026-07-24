#!/usr/bin/env Rscript
# Launch never-started dependency-ready nodes, monitor them out of process,
# emit immutable telemetry, and kill the whole subprocess tree at timeout.
d99_args <- commandArgs(trailingOnly = TRUE); d99_arg <- function(f, d = NULL) { i <- match(f, d99_args); if (is.na(i)) d else d99_args[[i + 1L]] }
d99_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]); d99_here <- normalizePath(file.path(dirname(d99_file), ".."), mustWork = TRUE)
source(file.path(d99_here, "R", "records.R")); source(file.path(d99_here, "R", "task-graph.R"))
root <- d99_arg("--output-root"); run_id <- d99_arg("--run-id"); mode <- d99_arg("--mode", "NON_EVIDENCE")
if (is.null(root) || is.null(run_id)) stop("--output-root and --run-id are required", call. = FALSE)
expected_real_root <- file.path(d99_here, "results")
if (identical(mode, "REAL_RUN") && !d99_validate_real_run(root, run_id, expected_real_root)) stop("REAL_RUN supervision requires the fixed result root and valid sentinel/manifest", call. = FALSE)
test_task <- d99_arg("--test-task-id"); test_worker <- d99_arg("--test-worker-script"); timeout_override <- suppressWarnings(as.numeric(d99_arg("--timeout-override-s", NA_character_)))
heartbeat_s <- suppressWarnings(as.numeric(d99_arg("--heartbeat-interval-s", "5")))
if ((!is.null(test_task) || !is.null(test_worker) || is.finite(timeout_override) || heartbeat_s != 5) && !identical(mode, "NON_EVIDENCE")) stop("Supervisor test overrides are NON_EVIDENCE-only", call. = FALSE)
if (!is.finite(heartbeat_s) || heartbeat_s <= 0) stop("Heartbeat interval must be positive", call. = FALSE)
graph <- d99_build_task_graph(run_id); if ("--resume" %in% d99_args) d99_reconcile_unfinished_launches(root, graph)
tasks <- graph
if ("--exclude-finalizer" %in% d99_args) tasks <- tasks[setdiff(names(tasks), "finalizer")]
if (!is.null(test_task)) { if (is.null(tasks[[test_task]])) stop("Unknown test task", call. = FALSE); tasks <- tasks[test_task] }
d99_script_for <- function(task) switch(task$task_class,
  "A-H9" = "fit-worker.R", "A-H15" = "fit-worker.R", "A-H31" = "fit-worker.R", "B-H15" = "fit-worker.R", "B-H31" = "fit-worker.R",
  "cell-evaluator" = "cell-evaluator.R", "oracle" = "oracle-worker.R", "n-evaluator" = "n-evaluator.R", "finalizer" = "finalize.R", stop("Unknown task class", call. = FALSE))
d99_age_s <- function(x) { t <- suppressWarnings(as.numeric(as.POSIXct(x$launched_at, tz = "UTC"))); if (!is.finite(t)) Inf else max(0, as.numeric(Sys.time()) - t) }
d99_monitor <- function(task, script, input_path, input_hash, timeout_s) {
  if (!requireNamespace("processx", quietly = TRUE)) stop("Package `processx` is required for supervised timeout enforcement", call. = FALSE)
  args <- c("--vanilla", script, "--input", input_path, "--output-root", root, "--run-id", run_id, "--task-id", task$task_id, "--mode", mode)
  process <- processx::process$new(file.path(R.home("bin"), "Rscript"), args, stdout = "|", stderr = "|", cleanup_tree = TRUE)
  began <- Sys.time(); next_heartbeat <- began + heartbeat_s; heartbeat_seq <- 10000000L; out_seq <- 1L; err_seq <- 1L; timed_out <- FALSE
  repeat {
    process$poll_io(100L)
    stdout <- process$read_output_lines(); stderr <- process$read_error_lines()
    if (length(stdout)) { d99_write_log_chunk(root, task$task_id, "stdout", out_seq, paste(stdout, collapse = "\n")); out_seq <- out_seq + 1L }
    if (length(stderr)) { d99_write_log_chunk(root, task$task_id, "stderr", err_seq, paste(stderr, collapse = "\n")); err_seq <- err_seq + 1L }
    now <- Sys.time()
    if (process$is_alive() && now >= next_heartbeat) { heartbeat_seq <- heartbeat_seq + 1L; d99_write_heartbeat(root, task$task_id, heartbeat_seq, "supervised"); next_heartbeat <- now + heartbeat_s }
    elapsed <- as.numeric(difftime(now, began, units = "secs"))
    if (process$is_alive() && elapsed > timeout_s) { timed_out <- TRUE; try(process$kill_tree(), silent = TRUE); process$wait(2000L); break }
    if (!process$is_alive()) break
  }
  stdout <- process$read_all_output_lines(); stderr <- process$read_all_error_lines()
  if (length(stdout)) d99_write_log_chunk(root, task$task_id, "stdout", out_seq, paste(stdout, collapse = "\n"))
  if (length(stderr)) d99_write_log_chunk(root, task$task_id, "stderr", err_seq, paste(stderr, collapse = "\n"))
  list(timed_out = timed_out, exit_status = process$get_exit_status(), elapsed = as.numeric(difftime(Sys.time(), began, units = "secs")))
}
for (task in tasks) {
  launch_path <- d99_launch_path(root, task$task_id); terminal_path <- d99_terminal_path(root, task$task_id)
  if (file.exists(terminal_path)) next
  if (file.exists(launch_path)) {
    launch <- d99_read_json(launch_path)
    if (!d99_validate_launch(launch, task)) d99_write_terminal(root, task, "INFRASTRUCTURE_FAILURE", "UNKNOWN", list(error = "malformed launch record", dependency_ids = task$dependencies))
    else if (d99_age_s(launch) > task$timeout_s) d99_write_terminal(root, task, "TIMEOUT", launch$input_hash, list(error = "supervisor observed elapsed timeout", dependency_ids = task$dependencies, telemetry = list(timeout_s = task$timeout_s, launch_age_s = d99_age_s(launch))))
    next
  }
  state <- d99_dependency_state(root, task, graph); if (identical(state$state, "waiting")) next
  diagnostic_runner <- identical(as.integer(task$n), 128L) && task$task_class %in% c("cell-evaluator", "oracle", "n-evaluator")
  if (identical(state$state, "blocked") && !diagnostic_runner && !identical(task$task_class, "finalizer")) {
    phase_diagnostic <- identical(as.integer(task$n), 128L) && task$task_class %in% c("A-H15", "A-H31", "B-H31")
    blocked_input <- d99_input_path(root, task$task_id)
    blocked_hash <- if (file.exists(blocked_input)) d99_sha256_file(blocked_input) else "MISSING_INPUT"
    d99_write_terminal(root, task, if (phase_diagnostic) "OPTIMIZER_HEALTH_STOP" else "DEPENDENCY_BLOCKED", blocked_hash, list(dependency_ids = task$dependencies, dependency_status = vapply(state$records, function(x) if (is.null(x)) "MISSING" else x$status, character(1)), mode = mode)); next
  }
  input_path <- d99_input_path(root, task$task_id)
  if (!file.exists(input_path)) { d99_write_terminal(root, task, "MALFORMED", "MISSING_INPUT", list(error = "immutable task input is absent", dependency_ids = task$dependencies, mode = mode)); next }
  input_hash <- d99_sha256_file(input_path); input <- d99_read_json(input_path)
  source_ok <- !identical(mode, "REAL_RUN") || d99_validate_source_hashes(input, normalizePath(file.path(d99_here, "..", ".."), mustWork = TRUE))
  if (!d99_validate_input(input) || !identical(input$run_id, run_id) || !identical(input$task_id, task$task_id) || !source_ok || (identical(mode, "REAL_RUN") && (!identical(input$mode, "REAL_RUN") || !identical(input$preflight_hash, d99_sha256_file(file.path(root, "preflight.json")))))) {
    d99_write_terminal(root, task, "MECHANICAL_STOP", input_hash, list(error = "immutable input/run/preflight validation failed", dependency_ids = task$dependencies, mode = mode)); next
  }
  effective_timeout <- if (is.finite(timeout_override)) timeout_override else task$timeout_s
  launch <- list(schema = "d99-launch-v1", task_id = task$task_id, task_class = task$task_class, run_id = run_id, timeout_s = effective_timeout,
    launched_at = d99_now(), host = d99_host(), parent_pid = Sys.getpid(), mode = mode, input_hash = input_hash)
  d99_write_exclusive_json(launch_path, launch)
  script <- if (!is.null(test_worker)) normalizePath(test_worker, mustWork = TRUE) else file.path(d99_here, "scripts", d99_script_for(task))
  monitored <- tryCatch(d99_monitor(task, script, input_path, input_hash, effective_timeout), error = identity)
  if (!file.exists(terminal_path)) {
    status <- if (inherits(monitored, "error")) "INFRASTRUCTURE_FAILURE" else if (monitored$timed_out) "TIMEOUT" else if (!identical(as.integer(monitored$exit_status), 0L)) "CRASH" else "MALFORMED"
    d99_write_terminal(root, task, status, input_hash, list(error = if (inherits(monitored, "error")) conditionMessage(monitored) else "worker exited without terminal", dependency_ids = task$dependencies, mode = mode,
      exit_status = if (inherits(monitored, "error")) 1L else monitored$exit_status, telemetry = if (inherits(monitored, "error")) list(timeout_s = effective_timeout) else list(supervisor_elapsed_s = monitored$elapsed, timeout_s = effective_timeout)))
  }
}
