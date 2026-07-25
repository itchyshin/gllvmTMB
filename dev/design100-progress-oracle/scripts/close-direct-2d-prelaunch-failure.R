#!/usr/bin/env Rscript

# Close the one launched Design-100-B attempt without retrying it.  This script
# records the already-observed pre-evaluation schema failure only; it never
# sources the direct worker or performs numerical evaluation.

root <- "/private/tmp/gllvmtmb-design100b-direct2d-output"
source("dev/design100-progress-oracle/R/records.R", local = globalenv())

d100b_sha256_file <- function(path) {
  output <- system2("shasum", c("-a", "256", path), stdout = TRUE, stderr = TRUE)
  if (length(output) != 1L || !grepl("^[[:xdigit:]]{64} ", output)) {
    stop("cannot obtain SHA-256 file hash", call. = FALSE)
  }
  tolower(sub(" .*", "", output))
}

approval <- d100_read_json(file.path(root, "approval", "execution-approval.json"))
launch_path <- d100_launch_path(root, "d100b-pattern-001")
launch <- d100_read_json(launch_path)
if (is.null(approval) || is.null(launch) || file.exists(d100_terminal_path(root, "d100b-pattern-001"))) {
  stop("failure closeout requires one existing unclosed launch", call. = FALSE)
}

failure <- list(
  schema = "d100b-failure-v1", record_type = "pre_evaluation_failure",
  task_id = "d100b-pattern-001", run_label = launch$run_label,
  observed_at = d100_now(), stage = "worker_input_validation",
  status = "CRASH", reason_code = "UNHANDLED_ERROR",
  message = "theta must be finite beta[6] and lambda[6, 2]",
  numerical_evaluation_started = FALSE,
  retry_performed = FALSE
)
failure_path <- d100_path(root, "failures", "d100b-pattern-001")
d100_write_exclusive_json(failure_path, failure)
progress_path <- d100_progress_path(root, "d100b-pattern-001", 1L)
terminal <- list(
  schema = "d100-terminal-v1", record_type = "component", task_id = "d100b-pattern-001",
  task_kind = "component", run_label = launch$run_label,
  contract_hash = approval$preflight_hash, input_hash = approval$manifest_hash,
  launch_hash = d100b_sha256_file(launch_path), status = "CRASH",
  reason_code = "UNHANDLED_ERROR", started_at = launch$launched_at,
  finished_at = d100_now(), host = d100_host(), pid = Sys.getpid(), exit_status = 1L,
  telemetry = list(wall_time_s = 0, progress_event_count = 1L, last_progress_sequence = 1L),
  pattern_id = "pattern-001", component_id = "d100b-pattern-001::direct-2d",
  component_kind = "direct-2d", component_input_hash = approval$manifest_hash,
  attempt_index = 1L,
  progress_event_hashes = list("00000001" = d100b_sha256_file(progress_path)),
  result_hash = d100b_sha256_file(failure_path)
)
if (!d100_validate_terminal(terminal)) stop("invalid component failure terminal", call. = FALSE)
terminal_path <- d100_terminal_path(root, "d100b-pattern-001")
d100_write_exclusive_json(terminal_path, terminal)

gate_launch <- d100_launch_path(root, "d100b-pattern-gate")
gate_terminal <- list(
  schema = "d100-terminal-v1", record_type = "pattern", task_id = "d100b-pattern-gate",
  task_kind = "pattern", run_label = launch$run_label,
  contract_hash = approval$preflight_hash, input_hash = approval$manifest_hash,
  launch_hash = d100b_sha256_file(gate_launch), status = "INFRASTRUCTURE_INCOMPLETE",
  reason_code = "MISSING_TERMINAL", started_at = launch$launched_at,
  finished_at = d100_now(), host = d100_host(), pid = Sys.getpid(), exit_status = 1L,
  telemetry = list(wall_time_s = 0, progress_event_count = 1L, last_progress_sequence = 1L),
  pattern_id = "d100b-pattern-gate", pattern_hash = approval$manifest_hash,
  pattern_index = 1L, pattern_n_obs = 0L,
  component_ids = "d100b-pattern-001::direct-2d",
  component_terminal_hashes = list("d100b-pattern-001::direct-2d" = d100b_sha256_file(terminal_path))
)
if (!d100_validate_terminal(gate_terminal)) stop("invalid gate failure terminal", call. = FALSE)
d100_write_exclusive_json(d100_terminal_path(root, "d100b-pattern-gate"), gate_terminal)
cat("D100B_FAILURE_TERMINALS_COMPLETE\n")
