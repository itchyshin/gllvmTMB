#!/usr/bin/env Rscript

# Design-100-B one-shot private runner.  It is intentionally limited to the
# approved four-pattern, fixed-rule direct calculation.  It does not fit,
# optimise, adapt nodes, benchmark, or call the package.

d100b_root <- function() {
  script <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grepl(
    "^--file=", commandArgs(trailingOnly = FALSE)
  )])
  if (length(script) != 1L) stop("run with Rscript", call. = FALSE)
  normalizePath(file.path(dirname(script), ".."), mustWork = TRUE)
}

d100b_sha256_file <- function(path) {
  output <- system2("shasum", c("-a", "256", path), stdout = TRUE, stderr = TRUE)
  if (length(output) != 1L || !grepl("^[[:xdigit:]]{64} ", output)) {
    stop("cannot obtain SHA-256 file hash", call. = FALSE)
  }
  tolower(sub(" .*", "", output))
}

d100b_require <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
}

root <- d100b_root()
source(file.path(root, "R", "records.R"), local = globalenv())
source(file.path(root, "scripts", "direct-2d-worker.R"), local = globalenv())

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop("usage: run-direct-2d-non-evidence.R <manifest.json> <approval.json>", call. = FALSE)
}
manifest_path <- normalizePath(arguments[[1L]], mustWork = TRUE)
approval_path <- normalizePath(arguments[[2L]], mustWork = TRUE)
manifest <- d100_read_json(manifest_path)
approval <- d100_read_json(approval_path)
d100b_require(!is.null(manifest) && !is.null(approval), "missing approved input")
d100b_require(is.character(approval$schema) && length(approval$schema) == 1L &&
  grepl("^d100[[:alnum:]]+-execution-approval-v1$", approval$schema), "invalid approval schema")
d100b_require(identical(approval$run_class, "NON_EVIDENCE") && isTRUE(approval$executable),
  "non-evidence execution approval missing")
d100b_require(identical(approval$manifest_hash, d100b_sha256_file(manifest_path)),
  "manifest hash differs from approval")
d100b_require(identical(approval$worker_hash,
  d100b_sha256_file(file.path(root, "scripts", "direct-2d-worker.R"))),
  "worker hash differs from approval")
d100b_require(is.character(approval$preflight_path) && length(approval$preflight_path) == 1L &&
  !grepl("[/\\\\]", approval$preflight_path), "unsafe preflight path")
d100b_require(identical(approval$preflight_hash,
  d100b_sha256_file(file.path(root, approval$preflight_path))),
  "preflight hash differs from approval")
d100b_require(identical(manifest$worker_id, "direct-2d-original-u-v1") &&
  identical(manifest$coordinate_rule, "normal-gh5-original-u-v1"), "wrong frozen worker/rule")
d100b_pattern_ids <- unlist(manifest$pattern_ids, use.names = FALSE)
d100b_require(identical(d100b_pattern_ids,
  c("pattern-001", "pattern-002", "pattern-003", "pattern-004")), "wrong frozen pattern order")

output_root <- approval$output_root
d100b_require(output_root %in% c(
  "/private/tmp/gllvmtmb-design100b-direct2d-output",
  "/private/tmp/gllvmtmb-design100c-direct2d-output",
  "/private/tmp/gllvmtmb-design100d-direct2d-output"
), "wrong output root")
if (dir.exists(output_root) || file.exists(output_root)) {
  stop("output root already exists; refusing to overwrite a one-shot run", call. = FALSE)
}

theta <- list(beta = as.numeric(unlist(manifest$beta, use.names = FALSE)),
  lambda = do.call(rbind, lapply(manifest$lambda, function(row) {
    as.numeric(unlist(row, use.names = FALSE))
  })))
if (!identical(dim(theta$lambda), c(6L, 2L))) stop("invalid lambda manifest shape", call. = FALSE)
task_prefix <- approval$task_prefix
d100b_require(is.character(task_prefix) && length(task_prefix) == 1L &&
  d100_path_token(task_prefix), "unsafe task prefix")
gate_task_id <- paste0(task_prefix, "-pattern-gate")

started_at <- d100_now()
whole_started <- Sys.time()
d100_write_exclusive_json(file.path(output_root, "approval", "execution-approval.json"), approval)
pattern_launch <- list(
  schema = approval$launch_schema, record_type = "launch", task_id = gate_task_id,
  run_label = manifest$run_label, pattern_id = gate_task_id,
  worker_id = manifest$worker_id, manifest_hash = approval$manifest_hash,
  launched_at = started_at, host = d100_host(), parent_pid = Sys.getpid(),
  max_workers = approval$max_workers, component_deadline_s = approval$deadlines_s$component,
  pattern_deadline_s = approval$deadlines_s$pattern, whole_gate_deadline_s = approval$deadlines_s$whole_gate
)
d100_write_exclusive_json(d100_launch_path(output_root, gate_task_id), pattern_launch)
setTimeLimit(elapsed = approval$deadlines_s$whole_gate, transient = FALSE)
on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)

terminal_hashes <- list()
for (index in seq_along(d100b_pattern_ids)) {
  pattern_id <- d100b_pattern_ids[[index]]
  task_id <- paste0(task_prefix, "-", pattern_id)
  component_id <- paste0(task_id, "::direct-2d")
  now <- d100_now()
  launch <- list(
    schema = "d100b-launch-v1", record_type = "launch", task_id = task_id,
    run_label = manifest$run_label, pattern_id = pattern_id,
    worker_id = manifest$worker_id, manifest_hash = approval$manifest_hash,
    launched_at = now, host = d100_host(), parent_pid = Sys.getpid(),
    max_workers = approval$max_workers, component_deadline_s = approval$deadlines_s$component,
    pattern_deadline_s = approval$deadlines_s$pattern, whole_gate_deadline_s = approval$deadlines_s$whole_gate
  )
  d100_write_exclusive_json(d100_launch_path(output_root, task_id), launch)
  liveness_1 <- list(schema = "d100-liveness-v1", record_type = "liveness", task_id = task_id,
    run_label = manifest$run_label, sequence = 1L, state = "alive", at = now,
    host = d100_host(), pid = Sys.getpid())
  progress_1 <- list(schema = "d100-progress-v1", record_type = "progress", task_id = task_id,
    run_label = manifest$run_label, sequence = 1L, state = "progress", at = now,
    host = d100_host(), pid = Sys.getpid(), completed = 0L, total = 1L)
  d100_write_exclusive_json(d100_liveness_path(output_root, task_id, 1L), liveness_1)
  d100_write_exclusive_json(d100_progress_path(output_root, task_id, 1L), progress_1)
  component_started <- Sys.time()
  setTimeLimit(elapsed = approval$deadlines_s$component, transient = TRUE)
  result <- tryCatch(d100b_direct2d_evaluate(theta, pattern_id), error = function(error) error)
  setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE)
  if (inherits(result, "error")) stop(conditionMessage(result), call. = FALSE)
  finished_at <- d100_now()
  liveness_2 <- modifyList(liveness_1, list(sequence = 2L, at = finished_at))
  progress_2 <- modifyList(progress_1, list(sequence = 2L, at = finished_at, completed = 1L))
  d100_write_exclusive_json(d100_liveness_path(output_root, task_id, 2L), liveness_2)
  d100_write_exclusive_json(d100_progress_path(output_root, task_id, 2L), progress_2)
  result_path <- d100_path(output_root, "results", task_id)
  d100_write_exclusive_json(result_path, result)
  progress_hashes <- list(
    "00000001" = d100b_sha256_file(d100_progress_path(output_root, task_id, 1L)),
    "00000002" = d100b_sha256_file(d100_progress_path(output_root, task_id, 2L))
  )
  terminal <- list(
    schema = "d100-terminal-v1", record_type = "component", task_id = task_id,
    task_kind = "component", run_label = manifest$run_label,
    contract_hash = approval$preflight_hash, input_hash = approval$manifest_hash,
    launch_hash = d100b_sha256_file(d100_launch_path(output_root, task_id)),
    status = "PROGRESS_COMPLETE", reason_code = "ALL_COMPONENTS_RECORDED",
    started_at = now, finished_at = finished_at, host = d100_host(), pid = Sys.getpid(), exit_status = 0L,
    telemetry = list(wall_time_s = as.numeric(difftime(Sys.time(), component_started, units = "secs")),
      progress_event_count = 2L, last_progress_sequence = 2L),
    pattern_id = pattern_id, component_id = component_id, component_kind = "direct-2d",
    component_input_hash = approval$manifest_hash, attempt_index = 1L,
    progress_event_hashes = progress_hashes, result_hash = d100b_sha256_file(result_path)
  )
  d100b_require(d100_validate_terminal(terminal), "invalid component terminal")
  terminal_path <- d100_terminal_path(output_root, task_id)
  d100_write_exclusive_json(terminal_path, terminal)
  terminal_hashes[[component_id]] <- d100b_sha256_file(terminal_path)
  if (as.numeric(difftime(Sys.time(), whole_started, units = "secs")) >= approval$deadlines_s$whole_gate) {
    stop("whole-gate deadline reached", call. = FALSE)
  }
}

pattern_terminal <- list(
  schema = "d100-terminal-v1", record_type = "pattern", task_id = gate_task_id,
  task_kind = "pattern", run_label = manifest$run_label,
  contract_hash = approval$preflight_hash, input_hash = approval$manifest_hash,
  launch_hash = d100b_sha256_file(d100_launch_path(output_root, gate_task_id)), status = "PROGRESS_COMPLETE",
  reason_code = "ALL_COMPONENTS_RECORDED", started_at = started_at, finished_at = d100_now(),
  host = d100_host(), pid = Sys.getpid(), exit_status = 0L,
  telemetry = list(wall_time_s = as.numeric(difftime(Sys.time(), whole_started, units = "secs")),
    progress_event_count = 8L, last_progress_sequence = 2L),
  pattern_id = gate_task_id, pattern_hash = approval$manifest_hash,
  pattern_index = 1L, pattern_n_obs = 0L, component_ids = names(terminal_hashes),
  component_terminal_hashes = terminal_hashes
)
d100b_require(d100_validate_terminal(pattern_terminal), "invalid pattern terminal")
d100_write_exclusive_json(d100_terminal_path(output_root, gate_task_id), pattern_terminal)
cat("D100_NON_EVIDENCE_DIRECT2D_COMPLETE\n")
