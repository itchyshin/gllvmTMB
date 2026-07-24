# Static contract tests only: this file does not source, launch, or benchmark.

root <- normalizePath(file.path(getwd(), "dev/design100-progress-oracle"), mustWork = FALSE)
if (!dir.exists(root)) root <- normalizePath(file.path(getwd(), ".."), mustWork = FALSE)

read_design100 <- function(...) {
  paste(readLines(file.path(root, ...), warn = FALSE), collapse = "\n")
}

task_graph <- read_design100("R", "task-graph.R")
records <- read_design100("R", "records.R")
supervisor <- read_design100("scripts", "supervise.R")
benchmark <- read_design100("scripts", "benchmark-non-evidence.R")

stopifnot(
  grepl("d100_freeze_task_graph", task_graph, fixed = TRUE),
  grepl("max_workers", task_graph, fixed = TRUE),
  grepl("component_sec", task_graph, fixed = TRUE),
  grepl("pattern_sec", task_graph, fixed = TRUE),
  grepl("stale_progress_sec", task_graph, fixed = TRUE),
  grepl("liveness_sec", task_graph, fixed = TRUE),
  grepl("whole_gate_sec", task_graph, fixed = TRUE),
  grepl("d100_schedule_next", task_graph, fixed = TRUE),
  grepl("terminal_ids", task_graph, fixed = TRUE),
  grepl("c(completed_ids, started_ids, terminal_ids)", task_graph, fixed = TRUE),
  grepl("d100_validate_cost_precheck_receipt", task_graph, fixed = TRUE),
  grepl("d100_frozen_cost_precheck_receipt", task_graph, fixed = TRUE),
  grepl("d100_cost_precheck_receipt_snapshot", task_graph, fixed = TRUE),
  grepl("cost_precheck_receipt_snapshot", task_graph, fixed = TRUE),
  grepl("identity/hash replacement detected", task_graph, fixed = TRUE),
  grepl("d100_path_token", task_graph, fixed = TRUE),
  grepl("d100_path_token", records, fixed = TRUE),
  grepl("d100_require_path_token(task_id, \"task_id\")", records, fixed = TRUE),
  grepl("safe Design-100 path token", records, fixed = TRUE),
  grepl("d100-cost-precheck-receipt-v1", task_graph, fixed = TRUE),
  grepl("receipt_identity", task_graph, fixed = TRUE),
  grepl("NON_EVIDENCE", task_graph, fixed = TRUE),
  grepl("status, \"PASS\"", task_graph, fixed = TRUE),
  grepl("contract_hash", task_graph, fixed = TRUE),
  grepl("graph_hash", task_graph, fixed = TRUE),
  grepl("immutable, TRUE", task_graph, fixed = TRUE),
  grepl("executable, FALSE", task_graph, fixed = TRUE),
  !grepl("approval_token", task_graph, fixed = TRUE),
  grepl("task_hard", task_graph, fixed = TRUE),
  grepl("d100_failure_map", supervisor, fixed = TRUE),
  grepl("launch_error", supervisor, fixed = TRUE),
  grepl("worker_crash", supervisor, fixed = TRUE),
  grepl("orphan_detected", supervisor, fixed = TRUE),
  grepl("d100_expire_prospective_deadlines", supervisor, fixed = TRUE),
  grepl("d100_terminal_ids", supervisor, fixed = TRUE),
  grepl("terminal_ids = d100_terminal_ids(state)", supervisor, fixed = TRUE),
  grepl("d100_apply_progress_report", supervisor, fixed = TRUE),
  grepl("actual_progress", supervisor, fixed = TRUE),
  grepl("progress_without_completion", supervisor, fixed = TRUE),
  grepl("progress_freshness_sec", supervisor, fixed = TRUE),
  grepl("freshness$hard_deadline", supervisor, fixed = TRUE),
  grepl("d100_expire_liveness_watchdogs", supervisor, fixed = TRUE),
  grepl("liveness_watchdog_expired", supervisor, fixed = TRUE),
  grepl("liveness_deadline", supervisor, fixed = TRUE),
  grepl("frozen_deadline_at", supervisor, fixed = TRUE),
  grepl("hard_deadline_at$components", supervisor, fixed = TRUE),
  grepl("hard_deadline_at$patterns", supervisor, fixed = TRUE),
  grepl("hard_deadline_at$whole_gate", supervisor, fixed = TRUE),
  grepl("d100_frozen_cost_precheck_receipt", supervisor, fixed = TRUE),
  grepl("cost_precheck_receipt_snapshot", supervisor, fixed = TRUE),
  grepl("expected_snapshot = state$cost_precheck_receipt_snapshot", supervisor, fixed = TRUE),
  grepl("invalid_cost_precheck_receipt", supervisor, fixed = TRUE),
  grepl("cost_precheck_receipt", supervisor, fixed = TRUE),
  !grepl("approval_token", supervisor, fixed = TRUE),
  grepl("D100_BENCHMARK_CLASS <- \"NON_EVIDENCE\"", benchmark, fixed = TRUE),
  grepl("REAL_RUN|fixture|uuid", benchmark, fixed = TRUE),
  grepl("worker_timing", benchmark, fixed = TRUE),
  grepl("d100_record_non_evidence_worker_timing", benchmark, fixed = TRUE),
  grepl("d100_make_non_evidence_cost_precheck_receipt", benchmark, fixed = TRUE),
  grepl("d100_validate_cost_precheck_receipt", benchmark, fixed = TRUE),
  grepl("receipt_identity", benchmark, fixed = TRUE),
  grepl("contract_hash", benchmark, fixed = TRUE),
  grepl("graph_hash", benchmark, fixed = TRUE),
  grepl("immutable = TRUE", benchmark, fixed = TRUE),
  grepl("executable = FALSE", benchmark, fixed = TRUE),
  grepl("status = \"PASS\"", benchmark, fixed = TRUE),
  !grepl("approval_token", benchmark, fixed = TRUE),
  grepl("numeric_benchmark_executed = FALSE", benchmark, fixed = TRUE)
)
