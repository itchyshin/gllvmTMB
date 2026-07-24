# Design-100 benchmark receipt schema.
#
# This file deliberately prepares metadata only.  It must never create or run a
# numeric benchmark, fixture replay, direct-oracle run, or evidence artifact.

D100_BENCHMARK_CLASS <- "NON_EVIDENCE"

d100_uuid_pattern <- "(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

d100_benchmark_task_graph_path <- function() {
  candidate <- normalizePath(file.path(getwd(), "dev/design100-progress-oracle/R/task-graph.R"),
    mustWork = FALSE
  )
  if (file.exists(candidate)) return(candidate)
  candidate <- normalizePath(file.path(getwd(), "R/task-graph.R"), mustWork = FALSE)
  if (file.exists(candidate)) return(candidate)
  stop("cannot locate Design-100 task graph", call. = FALSE)
}

# The graph owns the receipt contract so preparation and launch apply exactly
# the same validation.  Loading this pure metadata helper does not launch or
# benchmark anything.
if (!exists("d100_validate_cost_precheck_receipt", mode = "function")) {
  source(d100_benchmark_task_graph_path(), local = FALSE)
}

d100_make_non_evidence_cost_precheck_receipt <- function(receipt_identity,
                                                          contract_hash, graph_hash) {
  receipt <- list(
    schema = "d100-cost-precheck-receipt-v1",
    receipt_type = "cost_precheck",
    receipt_identity = d100_non_evidence_identity(receipt_identity, "receipt_identity"),
    run_class = D100_BENCHMARK_CLASS,
    status = "PASS",
    contract_hash = d100_sha256(contract_hash, "contract_hash"),
    graph_hash = d100_sha256(graph_hash, "graph_hash"),
    immutable = TRUE,
    executable = FALSE,
    numeric_benchmark_created = FALSE,
    numeric_benchmark_executed = FALSE
  )
  if (!d100_validate_cost_precheck_receipt(
    receipt, receipt$contract_hash, receipt$graph_hash
  )) {
    stop("constructed NON_EVIDENCE cost-precheck receipt is invalid", call. = FALSE)
  }
  receipt
}

d100_reject_evidence_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    stop("benchmark path must be one non-empty character value", call. = FALSE)
  }
  forbidden <- grepl("REAL_RUN|fixture|uuid", path, ignore.case = TRUE) ||
    grepl(d100_uuid_pattern, path, perl = TRUE)
  if (forbidden) {
    stop("NON_EVIDENCE benchmark metadata cannot name REAL_RUN, fixture, or UUID paths", call. = FALSE)
  }
  normalizePath(path, mustWork = FALSE)
}

# The projection records fields a real future worker would report, but this
# private slice does not instantiate a worker or assign numeric timings.
d100_benchmark_projection_schema <- function() {
  list(
    run_class = D100_BENCHMARK_CLASS,
    worker_timing = c(
      "worker_id", "launched_at", "started_at", "finished_at",
      "elapsed_seconds", "cpu_seconds", "queue_seconds", "exit_status"
    ),
    projection = c(
      "component_id", "pattern_id", "backend_id", "max_workers",
      "planned_component_deadline", "planned_pattern_deadline",
      "planned_stale_progress_deadline", "planned_whole_gate_deadline",
      "cost_precheck_receipt"
    ),
    evidence_policy = "metadata-only; no numeric benchmark is created or executed"
  )
}

# Store timing fields supplied by an already-observed worker receipt.  This is
# deliberately bookkeeping, not a timer: it neither launches a worker nor
# computes a benchmark result.
d100_record_non_evidence_worker_timing <- function(worker_timing) {
  fields <- d100_benchmark_projection_schema()$worker_timing
  if (!is.list(worker_timing) || !identical(sort(names(worker_timing)), sort(fields))) {
    stop(sprintf("worker_timing must contain exactly: %s", paste(fields, collapse = ", ")),
      call. = FALSE
    )
  }
  list(
    run_class = D100_BENCHMARK_CLASS,
    worker_timing = worker_timing,
    numeric_benchmark_created = FALSE,
    numeric_benchmark_executed = FALSE
  )
}

d100_prepare_non_evidence_benchmark <- function(path, receipt_identity,
                                                 contract_hash, graph_hash,
                                                 run_class = D100_BENCHMARK_CLASS) {
  if (!identical(run_class, D100_BENCHMARK_CLASS)) {
    stop("only NON_EVIDENCE benchmark metadata is permitted", call. = FALSE)
  }
  list(
    run_class = D100_BENCHMARK_CLASS,
    path = d100_reject_evidence_path(path),
    schema = d100_benchmark_projection_schema(),
    cost_precheck_receipt = d100_make_non_evidence_cost_precheck_receipt(
      receipt_identity, contract_hash, graph_hash
    ),
    executable = FALSE,
    numeric_benchmark_created = FALSE,
    numeric_benchmark_executed = FALSE
  )
}
