# Design-100 progress-oracle task graph.
#
# This is intentionally a small, private abstraction: its graph is frozen before
# any worker is launched, and scheduling is a deterministic projection of that
# frozen graph.  It does not infer work from a live oracle response.

d100_abort <- function(message) {
  stop(message, call. = FALSE)
}

d100_epoch <- function(x, name) {
  if (inherits(x, "POSIXt")) {
    x <- as.numeric(x)
  }
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
    d100_abort(sprintf("%s must be one finite POSIX epoch value", name))
  }
  as.numeric(x)
}

d100_nonempty_character <- function(x, name) {
  if (!is.character(x) || length(x) != 1L || !nzchar(x)) {
    d100_abort(sprintf("%s must be one non-empty character value", name))
  }
  x
}

# `task_id` becomes part of a record path downstream.  Reject separators and
# dot segments while freezing the graph, before any component id is composed.
d100_path_token <- function(x, name) {
  x <- d100_nonempty_character(x, name)
  if (x %in% c(".", "..") || grepl("[/\\\\]", x) ||
      grepl("(^|[/\\\\])\\.\\.?($|[/\\\\])", x) ||
      !grepl("^[[:alnum:]][[:alnum:]_.-]*$", x)) {
    d100_abort(sprintf("%s must be a safe path token", name))
  }
  x
}

# SHA-256 values are supplied by the separately approved record workflow.  This
# private graph verifies the binding; it does not manufacture content to hash.
d100_sha256 <- function(x, name) {
  x <- d100_nonempty_character(x, name)
  if (!grepl("^[[:xdigit:]]{64}$", x)) {
    d100_abort(sprintf("%s must be a SHA-256 hexadecimal value", name))
  }
  tolower(x)
}

d100_non_evidence_identity <- function(x, name) {
  x <- d100_nonempty_character(x, name)
  uuid <- "^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$"
  if (!grepl("^[[:alnum:]][[:alnum:]._-]*$", x) ||
      grepl(uuid, x, ignore.case = TRUE) ||
      grepl("fixture|uuid", x, ignore.case = TRUE)) {
    d100_abort(sprintf("%s must be a non-UUID, non-fixture identity", name))
  }
  x
}

# Validate the sole approval accepted by a later launcher.  The receipt is a
# frozen declaration, not a cost result: it binds supplied SHA-256 hashes to a
# non-executable NON_EVIDENCE record and refuses fixture/UUID identities.
d100_validate_cost_precheck_receipt <- function(receipt, contract_hash, graph_hash) {
  required <- c(
    "schema", "receipt_type", "receipt_identity", "run_class", "status",
    "contract_hash", "graph_hash", "immutable", "executable",
    "numeric_benchmark_created", "numeric_benchmark_executed"
  )
  if (!is.list(receipt) || !identical(sort(names(receipt)), sort(required))) return(FALSE)
  valid <- tryCatch({
    identical(receipt$schema, "d100-cost-precheck-receipt-v1") &&
      identical(receipt$receipt_type, "cost_precheck") &&
      identical(receipt$run_class, "NON_EVIDENCE") &&
      identical(receipt$status, "PASS") &&
      identical(receipt$immutable, TRUE) &&
      identical(receipt$executable, FALSE) &&
      identical(receipt$numeric_benchmark_created, FALSE) &&
      identical(receipt$numeric_benchmark_executed, FALSE) &&
      identical(d100_non_evidence_identity(receipt$receipt_identity, "receipt_identity"),
                receipt$receipt_identity) &&
      identical(d100_sha256(receipt$contract_hash, "receipt contract_hash"), contract_hash) &&
      identical(d100_sha256(receipt$graph_hash, "receipt graph_hash"), graph_hash)
  }, error = function(error) FALSE)
  isTRUE(valid)
}

# The receipt schema has no mutable payload: its identity and the two supplied
# SHA-256 bindings are therefore the complete immutable receipt fingerprint.
d100_cost_precheck_receipt_snapshot <- function(receipt) {
  list(
    receipt_identity = receipt$receipt_identity,
    contract_hash = receipt$contract_hash,
    graph_hash = receipt$graph_hash
  )
}

d100_validate_cost_precheck_receipt_snapshot <- function(snapshot,
                                                         contract_hash, graph_hash) {
  is.list(snapshot) &&
    identical(sort(names(snapshot)), sort(c("receipt_identity", "contract_hash", "graph_hash"))) &&
    isTRUE(tryCatch({
      identical(d100_non_evidence_identity(snapshot$receipt_identity, "receipt_identity"),
                snapshot$receipt_identity) &&
        identical(d100_sha256(snapshot$contract_hash, "receipt snapshot contract_hash"), contract_hash) &&
        identical(d100_sha256(snapshot$graph_hash, "receipt snapshot graph_hash"), graph_hash)
    }, error = function(error) FALSE))
}

d100_deadline_offsets <- function(deadlines) {
  required <- c(
    "component_sec", "pattern_sec", "stale_progress_sec", "liveness_sec", "whole_gate_sec"
  )
  if (!is.list(deadlines) || !identical(sort(names(deadlines)), sort(required))) {
    d100_abort(sprintf("deadlines must contain exactly: %s", paste(required, collapse = ", ")))
  }
  values <- unlist(deadlines[required], use.names = TRUE)
  if (!is.numeric(values) || any(!is.finite(values)) || any(values <= 0)) {
    d100_abort("all prospective deadline offsets must be positive finite seconds")
  }
  as.list(values)
}

# Components may be nested.  A child is made dependent on its parent so the
# tree remains meaningful after flattening; explicit dependencies use frozen,
# fully-qualified component ids (for example, "task-a::prepare/input").
d100_flatten_components <- function(task_id, components, parent_path = character(),
                                    parent_id = NULL) {
  if (!is.list(components) || !length(components)) {
    d100_abort(sprintf("task %s must contain at least one component", task_id))
  }

  out <- list()
  for (node in components) {
    if (!is.list(node)) {
      d100_abort(sprintf("task %s contains a non-list component", task_id))
    }
    node_id <- d100_nonempty_character(node$id, "component$id")
    path <- c(parent_path, node_id)
    component_id <- paste(task_id, paste(path, collapse = "/"), sep = "::")
    explicit_deps <- node$depends_on %||% character()
    if (!is.character(explicit_deps)) {
      d100_abort(sprintf("component %s depends_on must be character", component_id))
    }
    dependencies <- unique(c(parent_id, explicit_deps))
    out[[length(out) + 1L]] <- list(
      component_id = component_id,
      task_id = task_id,
      component_path = paste(path, collapse = "/"),
      dependencies = dependencies
    )
    children <- node$components %||% list()
    if (length(children)) {
      out <- c(out, d100_flatten_components(task_id, children, path, component_id))
    }
  }
  out
}

# Local equivalent of rlang's %||% keeps this private script dependency-free.
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

d100_validate_dependencies <- function(components) {
  ids <- vapply(components, `[[`, character(1), "component_id")
  if (anyDuplicated(ids)) {
    d100_abort("frozen component ids must be unique")
  }
  for (component in components) {
    unknown <- setdiff(component$dependencies, ids)
    if (length(unknown)) {
      d100_abort(sprintf(
        "component %s has unknown frozen dependency: %s",
        component$component_id, paste(unknown, collapse = ", ")
      ))
    }
  }

  # Kahn's algorithm is only a validation step.  Scheduling itself is ordered
  # later from immutable identifiers, never from timing or worker liveness.
  remaining <- ids
  resolved <- character()
  while (length(remaining)) {
    ready <- vapply(remaining, function(id) {
      deps <- components[[match(id, ids)]]$dependencies
      all(deps %in% resolved)
    }, logical(1))
    if (!any(ready)) {
      d100_abort("component dependencies must be acyclic")
    }
    resolved <- c(resolved, sort(remaining[ready]))
    remaining <- remaining[!ready]
  }
  invisible(TRUE)
}

#' Freeze direct-oracle pattern/backend work before worker launch.
#'
#' The input task list has task_id, pattern_id, backend_id, oracle = "direct",
#' and nested components.  `cost_precheck_receipt` is an immutable,
#' non-executable NON_EVIDENCE approval binding this frozen graph and contract
#' to supplied SHA-256 hashes.  An arbitrary approval token is never accepted.
#' All deadlines are converted to absolute epochs here.  No supervisor
#' operation is permitted to replace a hard deadline or this receipt.
d100_freeze_task_graph <- function(tasks, max_workers, deadlines,
                                   contract_hash, graph_hash, cost_precheck_receipt,
                                   created_at = Sys.time()) {
  if (!is.list(tasks) || !length(tasks)) {
    d100_abort("tasks must be a non-empty list")
  }
  if (!is.numeric(max_workers) || length(max_workers) != 1L ||
      !is.finite(max_workers) || max_workers < 1 || max_workers != as.integer(max_workers)) {
    d100_abort("max_workers must be one positive integer")
  }
  created_at <- d100_epoch(created_at, "created_at")
  offsets <- d100_deadline_offsets(deadlines)
  contract_hash <- d100_sha256(contract_hash, "contract_hash")
  graph_hash <- d100_sha256(graph_hash, "graph_hash")
  if (!d100_validate_cost_precheck_receipt(
    cost_precheck_receipt, contract_hash, graph_hash
  )) {
    d100_abort("cost_precheck_receipt must be an immutable valid NON_EVIDENCE PASS receipt")
  }
  liveness_sec <- offsets$liveness_sec
  if (is.null(liveness_sec)) {
    d100_abort("deadlines must declare liveness_sec")
  }
  liveness_sec <- as.numeric(liveness_sec)

  components <- list()
  task_rows <- list()
  for (task in tasks) {
    if (!is.list(task)) d100_abort("each task must be a list")
    task_id <- d100_path_token(task$task_id, "task$task_id")
    pattern_id <- d100_nonempty_character(task$pattern_id, "task$pattern_id")
    backend_id <- d100_nonempty_character(task$backend_id, "task$backend_id")
    if (!identical(task$oracle, "direct")) {
      d100_abort(sprintf("task %s must declare oracle = 'direct'", task_id))
    }
    task_rows[[length(task_rows) + 1L]] <- list(
      task_id = task_id, pattern_id = pattern_id, backend_id = backend_id
    )
    flattened <- d100_flatten_components(task_id, task$components)
    for (component in flattened) {
      component$pattern_id <- pattern_id
      component$backend_id <- backend_id
      components[[length(components) + 1L]] <- component
    }
  }
  d100_validate_dependencies(components)

  component_ids <- vapply(components, `[[`, character(1), "component_id")
  task_ids <- vapply(task_rows, `[[`, character(1), "task_id")
  if (anyDuplicated(task_ids)) {
    d100_abort("frozen task ids must be unique")
  }
  pattern_ids <- sort(unique(vapply(components, `[[`, character(1), "pattern_id")))
  queue <- order(
    vapply(components, `[[`, character(1), "pattern_id"),
    vapply(components, `[[`, character(1), "backend_id"),
    vapply(components, `[[`, character(1), "task_id"),
    vapply(components, `[[`, character(1), "component_path")
  )
  component_deadlines <- stats::setNames(
    rep(created_at + offsets$component_sec, length(component_ids)), component_ids
  )
  pattern_deadlines <- stats::setNames(
    rep(created_at + offsets$pattern_sec, length(pattern_ids)), pattern_ids
  )
  whole_gate_deadline <- created_at + offsets$whole_gate_sec
  # A task freshness deadline is prospective and is capped by every hard
  # deadline that can stop one of its components.  Later actual progress may
  # move only this per-task freshness deadline, never a hard deadline.
  task_hard_deadlines <- vapply(task_ids, function(task_id) {
    task_components <- Filter(function(component) {
      identical(component$task_id, task_id)
    }, components)
    min(c(
      unname(component_deadlines[vapply(task_components, `[[`, character(1), "component_id")]),
      unname(pattern_deadlines[[task_components[[1L]]$pattern_id]]),
      whole_gate_deadline
    ))
  }, numeric(1))
  names(task_hard_deadlines) <- task_ids
  stale_progress_deadlines <- pmin(
    rep(created_at + offsets$stale_progress_sec, length(task_ids)),
    task_hard_deadlines
  )
  names(stale_progress_deadlines) <- task_ids

  graph <- list(
    version = "design100-direct-oracle-v1",
    frozen = TRUE,
    created_at = created_at,
    max_workers = as.integer(max_workers),
    contract_hash = contract_hash,
    graph_hash = graph_hash,
    cost_precheck_receipt = cost_precheck_receipt,
    cost_precheck_receipt_snapshot = d100_cost_precheck_receipt_snapshot(cost_precheck_receipt),
    liveness_watchdog_sec = liveness_sec,
    progress_freshness_sec = offsets$stale_progress_sec,
    tasks = task_rows,
    components = components,
    queue = component_ids[queue],
    deadline_at = list(
      components = component_deadlines,
      patterns = pattern_deadlines,
      task_hard = task_hard_deadlines,
      stale_progress = stale_progress_deadlines,
      whole_gate = whole_gate_deadline
    )
  )
  class(graph) <- "d100_frozen_task_graph"
  graph
}

# Return the immutable cost-precheck receipt at the point a future launcher
# would be called.  This is deliberately metadata only: it does not perform or
# approve numeric execution by itself.
d100_frozen_cost_precheck_receipt <- function(graph, expected_snapshot = NULL) {
  if (!inherits(graph, "d100_frozen_task_graph") || !isTRUE(graph$frozen)) {
    d100_abort("cost precheck requires a frozen Design-100 task graph")
  }
  contract_hash <- d100_sha256(graph$contract_hash, "frozen contract_hash")
  graph_hash <- d100_sha256(graph$graph_hash, "frozen graph_hash")
  receipt <- graph$cost_precheck_receipt
  snapshot <- graph$cost_precheck_receipt_snapshot
  if (!d100_validate_cost_precheck_receipt(receipt, contract_hash, graph_hash)) {
    d100_abort("frozen cost_precheck_receipt is missing or invalid")
  }
  if (!d100_validate_cost_precheck_receipt_snapshot(snapshot, contract_hash, graph_hash) ||
      !identical(d100_cost_precheck_receipt_snapshot(receipt), snapshot)) {
    d100_abort("frozen cost_precheck_receipt identity/hash replacement detected")
  }
  if (!is.null(expected_snapshot) && !identical(snapshot, expected_snapshot)) {
    d100_abort("supervision cost_precheck_receipt identity/hash replacement detected")
  }
  receipt
}

d100_component <- function(graph, component_id) {
  stopifnot(inherits(graph, "d100_frozen_task_graph"))
  matches <- vapply(graph$components, `[[`, character(1), "component_id") == component_id
  if (sum(matches) != 1L) d100_abort(sprintf("unknown component: %s", component_id))
  graph$components[[which(matches)]]
}

# Deterministic, bounded scheduling.  Every terminal component is excluded, so
# failure, timeout, and launch failure are absorbing and can never be retried.
# Dependencies require terminal successes; failed dependencies never become
# ready.
d100_schedule_next <- function(graph, completed_ids = character(),
                               started_ids = character(),
                               terminal_ids = character()) {
  stopifnot(inherits(graph, "d100_frozen_task_graph"))
  available <- graph$max_workers - length(started_ids)
  if (available <= 0L) return(character())
  candidates <- setdiff(graph$queue, c(completed_ids, started_ids, terminal_ids))
  ready <- vapply(candidates, function(component_id) {
    all(d100_component(graph, component_id)$dependencies %in% completed_ids)
  }, logical(1))
  head(candidates[ready], available)
}
