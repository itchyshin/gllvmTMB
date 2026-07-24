# Design-100 supervision is intentionally callback-driven.  Production wiring
# supplies launch(), inspect_worker(), and terminate_worker(); this file does
# not start processes or manufacture oracle evidence.

d100_script_root <- function() {
  candidate <- normalizePath(file.path(getwd(), "dev/design100-progress-oracle/R/task-graph.R"),
    mustWork = FALSE
  )
  if (file.exists(candidate)) return(candidate)
  candidate <- normalizePath(file.path(getwd(), "R/task-graph.R"), mustWork = FALSE)
  if (file.exists(candidate)) return(candidate)
  stop("cannot locate Design-100 task graph", call. = FALSE)
}

source(d100_script_root(), local = FALSE)

d100_terminal_statuses <- c(
  "succeeded", "failed", "launch_failed", "crashed", "timed_out", "orphaned"
)

# All terminal pathways are explicit.  In particular, a merely-live worker is
# not a success and is never a reason to move a prospective deadline.
d100_failure_map <- c(
  launch_error = "launch_failed",
  invalid_launch = "launch_failed",
  worker_failed = "failed",
  worker_crash = "crashed",
  worker_timeout = "timed_out",
  non_monotone_progress = "failed",
  liveness_watchdog_expired = "timed_out",
  missing_cost_precheck_receipt = "launch_failed",
  invalid_cost_precheck_receipt = "launch_failed",
  component_deadline = "timed_out",
  pattern_deadline = "timed_out",
  stale_progress_deadline = "timed_out",
  whole_gate_deadline = "timed_out",
  orphan_detected = "orphaned"
)

d100_new_supervision_state <- function(graph) {
  if (!inherits(graph, "d100_frozen_task_graph") || !isTRUE(graph$frozen)) {
    stop("supervision requires a frozen Design-100 task graph", call. = FALSE)
  }
  # Reject a graph whose receipt disappeared or changed after freezing before
  # the supervisor can make even its first scheduling decision.
  d100_frozen_cost_precheck_receipt(graph)
  cost_precheck_receipt_snapshot <- graph$cost_precheck_receipt_snapshot
  ids <- graph$queue
  # Snapshot the only hard caps used by supervision. Progress freshness and
  # liveness retain separate state below; neither receives a mutable reference
  # to the component/pattern/whole deadlines frozen in the graph.
  frozen_deadline_at <- list(
    components = graph$deadline_at$components,
    patterns = graph$deadline_at$patterns,
    task_hard = graph$deadline_at$task_hard,
    whole_gate = graph$deadline_at$whole_gate
  )
  components <- stats::setNames(lapply(ids, function(component_id) {
    list(component_id = component_id, status = "pending", reason = NA_character_,
         worker = NULL, launched_at = NA_real_, terminal_at = NA_real_,
         liveness_deadline = NA_real_,
         progress = list(sequence = 0L, completed = 0L, total = NA_integer_))
  }), ids)
  task_ids <- vapply(graph$tasks, `[[`, character(1), "task_id")
  freshness <- stats::setNames(lapply(task_ids, function(task_id) {
    list(
      task_id = task_id,
      stale_deadline = graph$deadline_at$stale_progress[[task_id]],
      hard_deadline = frozen_deadline_at$task_hard[[task_id]]
    )
  }), task_ids)
  list(graph = graph, frozen_deadline_at = frozen_deadline_at,
       cost_precheck_receipt_snapshot = cost_precheck_receipt_snapshot,
       components = components, task_freshness = freshness, event_log = list())
}

d100_is_terminal <- function(status) status %in% d100_terminal_statuses

d100_log_event <- function(state, component_id, event, at) {
  state$event_log[[length(state$event_log) + 1L]] <- list(
    component_id = component_id, event = event, at = as.numeric(at)
  )
  state
}

d100_terminalize <- function(state, component_id, failure_key, now,
                              terminate_worker = function(worker) invisible(NULL)) {
  entry <- state$components[[component_id]]
  if (is.null(entry) || d100_is_terminal(entry$status)) return(state)
  status <- unname(d100_failure_map[[failure_key]])
  if (is.na(status) || !nzchar(status)) {
    stop(sprintf("unknown Design-100 terminal mapping: %s", failure_key), call. = FALSE)
  }
  if (!is.null(entry$worker)) terminate_worker(entry$worker)
  entry$status <- status
  entry$reason <- failure_key
  entry$terminal_at <- as.numeric(now)
  entry$worker <- NULL
  state$components[[component_id]] <- entry
  d100_log_event(state, component_id, failure_key, now)
}

d100_terminalize_many <- function(state, component_ids, failure_key, now,
                                  terminate_worker) {
  for (component_id in component_ids) {
    state <- d100_terminalize(state, component_id, failure_key, now, terminate_worker)
  }
  state
}

d100_active_ids <- function(state) {
  names(Filter(function(entry) identical(entry$status, "launched"), state$components))
}

d100_success_ids <- function(state) {
  names(Filter(function(entry) identical(entry$status, "succeeded"), state$components))
}

d100_terminal_ids <- function(state) {
  names(Filter(function(entry) d100_is_terminal(entry$status), state$components))
}

d100_nonterminal_ids <- function(state) {
  names(Filter(function(entry) !d100_is_terminal(entry$status), state$components))
}

d100_task_nonterminal_ids <- function(state, task_id) {
  component_ids <- vapply(state$graph$components, `[[`, character(1), "component_id")
  task_component_ids <- component_ids[vapply(
    state$graph$components, function(component) identical(component$task_id, task_id),
    logical(1)
  )]
  intersect(task_component_ids, d100_nonterminal_ids(state))
}

d100_expire_hard_deadlines <- function(state, now, terminate_worker) {
  graph <- state$graph
  hard_deadline_at <- state$frozen_deadline_at
  # Hard caps always win and remain fixed even when a worker reports a
  # heartbeat or genuine progress.
  if (now >= hard_deadline_at$whole_gate) {
    return(d100_terminalize_many(
      state, d100_nonterminal_ids(state), "whole_gate_deadline", now, terminate_worker
    ))
  }
  for (component_id in d100_nonterminal_ids(state)) {
    component <- d100_component(graph, component_id)
    if (now >= hard_deadline_at$patterns[[component$pattern_id]]) {
      state <- d100_terminalize(state, component_id, "pattern_deadline", now, terminate_worker)
    } else if (now >= hard_deadline_at$components[[component_id]]) {
      state <- d100_terminalize(state, component_id, "component_deadline", now, terminate_worker)
    }
  }
  state
}

d100_expire_stale_progress_deadlines <- function(state, now, terminate_worker) {
  for (task_id in names(state$task_freshness)) {
    freshness <- state$task_freshness[[task_id]]
    if (now >= freshness$stale_deadline) {
      state <- d100_terminalize_many(
        state, d100_task_nonterminal_ids(state, task_id),
        "stale_progress_deadline", now, terminate_worker
      )
    }
  }
  state
}

# Liveness is an independent, bounded watchdog for an already launched worker.
# It never consumes a heartbeat/progress report and never writes any frozen
# component, pattern, or whole-gate deadline.  The only terminal path here is
# its own expiry; hard caps and progress freshness are handled elsewhere.
d100_expire_liveness_watchdogs <- function(state, now, terminate_worker) {
  for (component_id in d100_active_ids(state)) {
    deadline <- state$components[[component_id]]$liveness_deadline
    if (is.numeric(deadline) && length(deadline) == 1L &&
        is.finite(deadline) && now >= deadline) {
      state <- d100_terminalize(
        state, component_id, "liveness_watchdog_expired", now, terminate_worker
      )
    }
  }
  state
}

d100_expire_prospective_deadlines <- function(state, now, terminate_worker) {
  state <- d100_expire_hard_deadlines(state, now, terminate_worker)
  state <- d100_expire_liveness_watchdogs(state, now, terminate_worker)
  d100_expire_stale_progress_deadlines(state, now, terminate_worker)
}

d100_progress_payload <- function(progress) {
  required <- c("sequence", "completed", "total")
  if (!is.list(progress) || !all(required %in% names(progress))) return(NULL)
  values <- unlist(progress[required], use.names = FALSE)
  if (length(values) != length(required) || !is.numeric(values) ||
      any(!is.finite(values)) || any(values < 0) ||
      any(values != as.integer(values)) || progress$total < 1L ||
      progress$completed > progress$total) {
    return(NULL)
  }
  list(
    sequence = as.integer(progress$sequence),
    completed = as.integer(progress$completed),
    total = as.integer(progress$total)
  )
}

# A worker heartbeat is deliberately ignored here.  Only a strictly increasing
# completed count in a monotone progress payload refreshes its task's stale
# deadline, and that refreshed deadline remains capped by the frozen hard cap.
d100_apply_progress_report <- function(state, component_id, report, now,
                                       terminate_worker) {
  progress <- d100_progress_payload(report$progress)
  if (is.null(progress)) return(state)
  entry <- state$components[[component_id]]
  previous <- entry$progress
  valid <- progress$sequence > previous$sequence &&
    (is.na(previous$total) || identical(progress$total, previous$total)) &&
    progress$completed >= previous$completed
  if (!valid) {
    return(d100_terminalize(
      state, component_id, "non_monotone_progress", now, terminate_worker
    ))
  }
  actual_progress <- progress$completed > previous$completed
  entry$progress <- progress
  state$components[[component_id]] <- entry
  if (!actual_progress) {
    return(d100_log_event(state, component_id, "progress_without_completion", now))
  }
  task_id <- d100_component(state$graph, component_id)$task_id
  freshness <- state$task_freshness[[task_id]]
  freshness$stale_deadline <- min(
    now + state$graph$progress_freshness_sec,
    freshness$hard_deadline
  )
  state$task_freshness[[task_id]] <- freshness
  d100_log_event(state, component_id, "actual_progress", now)
}

d100_apply_worker_reports <- function(state, now, inspect_worker, terminate_worker) {
  for (component_id in d100_active_ids(state)) {
    report <- inspect_worker(state$components[[component_id]]$worker)
    worker_state <- if (is.list(report)) report$state %||% "orphaned" else "orphaned"
    if (is.list(report)) {
      state <- d100_apply_progress_report(
        state, component_id, report, now, terminate_worker
      )
    }
    if (d100_is_terminal(state$components[[component_id]]$status)) next
    if (identical(worker_state, "succeeded")) {
      entry <- state$components[[component_id]]
      entry$status <- "succeeded"
      entry$terminal_at <- as.numeric(now)
      entry$worker <- NULL
      state$components[[component_id]] <- entry
      state <- d100_log_event(state, component_id, "succeeded", now)
    } else if (identical(worker_state, "failed")) {
      state <- d100_terminalize(state, component_id, "worker_failed", now, terminate_worker)
    } else if (identical(worker_state, "crashed")) {
      state <- d100_terminalize(state, component_id, "worker_crash", now, terminate_worker)
    } else if (identical(worker_state, "orphaned")) {
      state <- d100_terminalize(state, component_id, "orphan_detected", now, terminate_worker)
    } else if (!identical(worker_state, "running")) {
      state <- d100_terminalize(state, component_id, "orphan_detected", now, terminate_worker)
    }
  }
  state
}

d100_launch_ready <- function(state, now, launch, terminate_worker) {
  started <- d100_active_ids(state)
  ready <- d100_schedule_next(
    state$graph,
    completed_ids = d100_success_ids(state),
    started_ids = started,
    terminal_ids = d100_terminal_ids(state)
  )
  for (component_id in ready) {
    # This lookup is intentionally immediately before the callback: every
    # future worker launch must consume the required frozen receipt.  A changed
    # or absent receipt rejects all currently-ready launches before callbacks.
    receipt_failure <- if (is.null(state$graph$cost_precheck_receipt)) {
      "missing_cost_precheck_receipt"
    } else {
      "invalid_cost_precheck_receipt"
    }
    cost_precheck_receipt <- tryCatch(
      d100_frozen_cost_precheck_receipt(
        state$graph,
        expected_snapshot = state$cost_precheck_receipt_snapshot
      ),
      error = function(error) NULL
    )
    if (is.null(cost_precheck_receipt)) {
      return(d100_terminalize_many(
        state, ready, receipt_failure, now, terminate_worker
      ))
    }
    worker <- tryCatch(
      launch(
        d100_component(state$graph, component_id), state$graph,
        cost_precheck_receipt
      ),
      error = function(error) structure(list(error = error), class = "d100_launch_error")
    )
    if (inherits(worker, "d100_launch_error") || is.null(worker) || is.null(worker$worker_id)) {
      key <- if (inherits(worker, "d100_launch_error")) "launch_error" else "invalid_launch"
      state <- d100_terminalize(state, component_id, key, now, terminate_worker)
    } else {
      entry <- state$components[[component_id]]
      entry$status <- "launched"
      entry$worker <- worker
      entry$launched_at <- as.numeric(now)
      # The watchdog is fixed at launch and capped by the already-frozen task
      # hard cap.  It is never refreshed by worker liveness or progress.
      task_id <- d100_component(state$graph, component_id)$task_id
      entry$liveness_deadline <- min(
        as.numeric(now) + state$graph$liveness_watchdog_sec,
        state$task_freshness[[task_id]]$hard_deadline
      )
      state$components[[component_id]] <- entry
      state <- d100_log_event(state, component_id, "launched", now)
    }
  }
  state
}

# One pure supervision tick.  `now` is injected to make the deadline policy
# testable.  Hard deadline epochs and the initial per-task freshness deadline
# originate only in d100_freeze_task_graph().
d100_supervise_once <- function(state, now, launch, inspect_worker,
                                terminate_worker = function(worker) invisible(NULL)) {
  now <- d100_epoch(now, "now")
  state <- d100_expire_prospective_deadlines(state, now, terminate_worker)
  if (!length(d100_nonterminal_ids(state))) return(state)
  state <- d100_apply_worker_reports(state, now, inspect_worker, terminate_worker)
  state <- d100_expire_prospective_deadlines(state, now, terminate_worker)
  if (!length(d100_nonterminal_ids(state))) return(state)
  d100_launch_ready(state, now, launch, terminate_worker)
}
