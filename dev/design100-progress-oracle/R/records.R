# Private Design-100 immutable progress-record helpers.
# This file deliberately has no fixture, UUID, optimizer, information-ladder,
# estimator, package, or compute implementation.

d100_status_taxonomy <- list(
  PROGRESS_COMPLETE = "ALL_COMPONENTS_RECORDED",
  COST_BENCHMARK_STOP = c("COST_BENCHMARK_EXCEEDED", "COST_BENCHMARK_UNAVAILABLE"),
  PROVENANCE_STOP = c("CONTRACT_HASH_MISMATCH", "IMMUTABLE_WRITE_CONFLICT"),
  SCOPE_STOP = c("FENCED_FIELD_PRESENT", "UNAPPROVED_MODE"),
  MECHANICAL_STOP = c("MALFORMED_RECORD", "LAUNCH_RECORD_INVALID", "NON_MONOTONE_PROGRESS"),
  INFRASTRUCTURE_INCOMPLETE = c("MISSING_TERMINAL", "MALFORMED_TERMINAL", "LIVENESS_EXPIRED"),
  LAUNCH_FAILURE = "PROCESS_LAUNCH_FAILED",
  TIMEOUT = "LIVENESS_TIMEOUT",
  ORPHAN = "PARENT_PROCESS_EXITED",
  INTERRUPTED = "USER_INTERRUPT",
  CRASH = "UNHANDLED_ERROR",
  SIGNALED = "PROCESS_SIGNAL",
  DEPENDENCY_BLOCKED = "UPSTREAM_TERMINAL_NOT_COMPLETE",
  TECHNICAL_INCOMPLETE = "REQUIRED_RECORD_MISSING"
)

d100_task_kinds <- c("pattern", "component")
d100_launch_modes <- c("RECORD_ONLY", "COST_PRECHECK")
# Progress is evidence of completed units only.  A worker heartbeat is a
# separate observational record: it must never advance progress or reset a
# hard deadline.
d100_progress_states <- "progress"
d100_liveness_states <- "alive"

d100_json <- function(x, pretty = FALSE) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Design-100 records require jsonlite", call. = FALSE)
  }
  jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", pretty = pretty,
                   digits = 17, POSIXt = "ISO8601")
}

d100_now <- function() format(Sys.time(), tz = "UTC", usetz = TRUE)
d100_host <- function() unname(Sys.info()[["nodename"]])
d100_nonempty_scalar <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}

# Record task ids and run labels become directory/file-name components.  Keep
# the path boundary explicit rather than relying on a later `file.path()` call
# to make malformed or traversal-like values harmless.
d100_path_token <- function(x) {
  d100_nonempty_scalar(x) &&
    !x %in% c(".", "..") &&
    !grepl("[/\\\\]", x) &&
    !grepl("(^|[/\\\\])\\.\\.?($|[/\\\\])", x) &&
    grepl("^[[:alnum:]][[:alnum:]_.-]*$", x)
}

d100_require_path_token <- function(x, name) {
  if (!d100_path_token(x)) {
    stop(name, " must be a safe Design-100 path token", call. = FALSE)
  }
  x
}

d100_path_kind <- function(x) {
  d100_nonempty_scalar(x) &&
    all(vapply(strsplit(x, "[/\\\\]", perl = TRUE)[[1L]], d100_path_token, logical(1)))
}

d100_path <- function(root, kind, id, ext = "json") {
  if (!d100_path_kind(kind)) {
    stop("Record path kind must contain only safe path tokens", call. = FALSE)
  }
  d100_require_path_token(id, "record id")
  file.path(root, kind, paste0(id, ".", ext))
}

d100_hash <- function(x) {
  d100_nonempty_scalar(x) && grepl("^[[:xdigit:]]{64}$", x)
}

# `run_label` is an opaque human-controlled label, deliberately not a UUID or
# a surrogate fixture identity.  Keep this check separate from the generic
# token grammar so every record type applies the same boundary.
d100_run_label <- function(x) {
  d100_path_token(x) &&
    !grepl(
      "^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$",
      x
    )
}

d100_integer_at_least <- function(x, lower = 0L) {
  is.numeric(x) && length(x) == 1L && is.finite(x) && x == as.integer(x) && x >= lower
}

d100_named_hashes <- function(x, allow_empty = FALSE) {
  is.list(x) && ((allow_empty && !length(x)) ||
    (length(x) > 0L && !is.null(names(x)) && all(nzchar(names(x))) &&
      all(vapply(x, d100_hash, logical(1)))))
}

d100_fenced_names <- c(
  "fixture", "uuid", "optimizer", "optimiser", "information_ladder",
  "quadrature", "integration", "integral", "aghq", "variational", "elbo",
  "laplace", "package", "compute", "totoro", "drac", "github_actions",
  "va", "jj", "eva"
)

d100_has_fenced_fields <- function(x) {
  if (!is.list(x)) return(FALSE)
  nms <- names(x)
  own <- !is.null(nms) && any(vapply(d100_fenced_names, function(term) {
    any(grepl(term, nms, ignore.case = TRUE))
  }, logical(1)))
  own || any(vapply(unname(x), function(value) {
    is.list(value) && d100_has_fenced_fields(value)
  }, logical(1)))
}

d100_valid_status_reason <- function(status, reason_code) {
  d100_nonempty_scalar(status) && d100_nonempty_scalar(reason_code) &&
    status %in% names(d100_status_taxonomy) &&
    reason_code %in% d100_status_taxonomy[[status]]
}

d100_validate_launch <- function(x) {
  required <- c(
    "schema", "record_type", "task_id", "task_kind", "run_label",
    "contract_hash", "input_hash", "launched_at", "host", "parent_pid",
    "mode", "liveness_timeout_s"
  )
  is.list(x) && identical(x$schema, "d100-launch-v1") &&
    identical(x$record_type, "launch") && !length(setdiff(required, names(x))) &&
    !d100_has_fenced_fields(x) && d100_path_token(x$task_id) &&
    d100_nonempty_scalar(x$task_kind) && x$task_kind %in% d100_task_kinds &&
    d100_run_label(x$run_label) &&
    d100_hash(x$contract_hash) && d100_hash(x$input_hash) &&
    d100_nonempty_scalar(x$launched_at) && d100_nonempty_scalar(x$host) &&
    d100_integer_at_least(x$parent_pid, 1L) && d100_nonempty_scalar(x$mode) &&
    x$mode %in% d100_launch_modes &&
    d100_integer_at_least(x$liveness_timeout_s, 1L)
}

d100_validate_progress_event <- function(x, launch = NULL) {
  required <- c(
    "schema", "record_type", "task_id", "run_label", "sequence", "state",
    "at", "host", "pid", "completed", "total"
  )
  valid <- is.list(x) && identical(x$schema, "d100-progress-v1") &&
    identical(x$record_type, "progress") && !length(setdiff(required, names(x))) &&
    !d100_has_fenced_fields(x) && d100_path_token(x$task_id) &&
    d100_run_label(x$run_label) && d100_integer_at_least(x$sequence, 1L) &&
    d100_nonempty_scalar(x$state) && x$state %in% d100_progress_states &&
    d100_nonempty_scalar(x$at) &&
    d100_nonempty_scalar(x$host) && d100_integer_at_least(x$pid, 1L) &&
    d100_integer_at_least(x$completed) && d100_integer_at_least(x$total, 1L) &&
    x$completed <= x$total
  if (!valid || is.null(launch)) return(valid)
  d100_validate_launch(launch) && identical(x$task_id, launch$task_id) &&
    identical(x$run_label, launch$run_label)
}

# Liveness is deliberately not a `d100-progress-v1` state.  The record carries
# no completed/total counters, and no progress or terminal validator consumes
# it.  A future supervisor may use the launch's liveness policy to report a
# missing heartbeat, but cannot use a heartbeat to extend a hard timeout.
d100_validate_liveness_event <- function(x, launch = NULL) {
  required <- c(
    "schema", "record_type", "task_id", "run_label", "sequence", "state",
    "at", "host", "pid"
  )
  valid <- is.list(x) && identical(x$schema, "d100-liveness-v1") &&
    identical(x$record_type, "liveness") && !length(setdiff(required, names(x))) &&
    !d100_has_fenced_fields(x) && d100_path_token(x$task_id) &&
    d100_run_label(x$run_label) && d100_integer_at_least(x$sequence, 1L) &&
    d100_nonempty_scalar(x$state) && x$state %in% d100_liveness_states &&
    d100_nonempty_scalar(x$at) && d100_nonempty_scalar(x$host) &&
    d100_integer_at_least(x$pid, 1L)
  if (!valid || is.null(launch)) return(valid)
  d100_validate_launch(launch) && identical(x$task_id, launch$task_id) &&
    identical(x$run_label, launch$run_label)
}

d100_validate_liveness_series <- function(events, launch = NULL) {
  if (!is.list(events) || !length(events) ||
      !all(vapply(events, d100_validate_liveness_event, logical(1), launch = launch))) {
    return(FALSE)
  }
  sequence <- vapply(events, `[[`, numeric(1), "sequence")
  task_ids <- vapply(events, `[[`, character(1), "task_id")
  run_labels <- vapply(events, `[[`, character(1), "run_label")
  all(diff(sequence) > 0) && length(unique(task_ids)) == 1L &&
    length(unique(run_labels)) == 1L
}

d100_validate_progress_series <- function(events, launch = NULL) {
  if (!is.list(events) || !length(events) ||
      !all(vapply(events, d100_validate_progress_event, logical(1), launch = launch))) {
    return(FALSE)
  }
  sequence <- vapply(events, `[[`, numeric(1), "sequence")
  completed <- vapply(events, `[[`, numeric(1), "completed")
  total <- vapply(events, `[[`, numeric(1), "total")
  task_ids <- vapply(events, `[[`, character(1), "task_id")
  run_labels <- vapply(events, `[[`, character(1), "run_label")
  all(diff(sequence) > 0) && all(diff(completed) >= 0) &&
    length(unique(total)) == 1L && length(unique(task_ids)) == 1L &&
    length(unique(run_labels)) == 1L
}

d100_validate_terminal <- function(x, launch = NULL) {
  required <- c(
    "schema", "record_type", "task_id", "task_kind", "run_label",
    "contract_hash", "input_hash", "launch_hash", "status", "reason_code",
    "started_at", "finished_at", "host", "pid", "exit_status", "telemetry"
  )
  valid <- is.list(x) && identical(x$schema, "d100-terminal-v1") &&
    !length(setdiff(required, names(x))) && d100_nonempty_scalar(x$record_type) &&
    x$record_type %in% d100_task_kinds &&
    !d100_has_fenced_fields(x) && d100_path_token(x$task_id) &&
    d100_nonempty_scalar(x$task_kind) && identical(x$record_type, x$task_kind) &&
    x$task_kind %in% d100_task_kinds &&
    d100_run_label(x$run_label) && d100_hash(x$contract_hash) &&
    d100_hash(x$input_hash) && d100_hash(x$launch_hash) &&
    d100_valid_status_reason(x$status, x$reason_code) &&
    d100_nonempty_scalar(x$started_at) && d100_nonempty_scalar(x$finished_at) &&
    d100_nonempty_scalar(x$host) && d100_integer_at_least(x$pid, 1L) &&
    is.numeric(x$exit_status) && length(x$exit_status) == 1L &&
    is.list(x$telemetry) &&
    all(c("wall_time_s", "progress_event_count", "last_progress_sequence") %in% names(x$telemetry)) &&
    is.numeric(x$telemetry$wall_time_s) && length(x$telemetry$wall_time_s) == 1L &&
    !is.na(x$telemetry$wall_time_s) && x$telemetry$wall_time_s >= 0 &&
    d100_integer_at_least(x$telemetry$progress_event_count) &&
    d100_integer_at_least(x$telemetry$last_progress_sequence)
  if (!valid) return(FALSE)

  component_ids <- if (is.character(x$component_ids)) {
    x$component_ids
  } else if (is.list(x$component_ids)) {
    unlist(x$component_ids, use.names = FALSE)
  } else {
    character()
  }
  task_valid <- if (identical(x$task_kind, "pattern")) {
    pattern_required <- c(
      "pattern_id", "pattern_hash", "pattern_index", "pattern_n_obs",
      "component_ids", "component_terminal_hashes"
    )
    all(pattern_required %in% names(x)) && d100_nonempty_scalar(x$pattern_id) &&
      d100_hash(x$pattern_hash) && d100_integer_at_least(x$pattern_index, 1L) &&
      d100_integer_at_least(x$pattern_n_obs) && is.character(component_ids) &&
      length(component_ids) > 0L && all(nzchar(component_ids)) &&
      d100_named_hashes(x$component_terminal_hashes) &&
      identical(sort(component_ids), sort(names(x$component_terminal_hashes)))
  } else {
    component_required <- c(
      "pattern_id", "component_id", "component_kind", "component_input_hash",
      "attempt_index", "progress_event_hashes", "result_hash"
    )
    all(component_required %in% names(x)) && d100_nonempty_scalar(x$pattern_id) &&
      d100_nonempty_scalar(x$component_id) && d100_nonempty_scalar(x$component_kind) &&
      d100_hash(x$component_input_hash) && d100_integer_at_least(x$attempt_index, 1L) &&
      d100_named_hashes(x$progress_event_hashes, allow_empty = TRUE) &&
      d100_hash(x$result_hash)
  }
  if (!task_valid || is.null(launch)) return(task_valid)
  d100_validate_launch(launch) && identical(x$task_id, launch$task_id) &&
    identical(x$task_kind, launch$task_kind) &&
    identical(x$run_label, launch$run_label) &&
    identical(x$contract_hash, launch$contract_hash) && identical(x$input_hash, launch$input_hash)
}

# "wx" deliberately refuses an overwrite.  A partial file is invalid evidence,
# never a reason to silently replace an immutable record.
d100_write_exclusive_text <- function(path, text) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- tryCatch(suppressWarnings(file(path, open = "wx", encoding = "UTF-8")),
                  error = function(e) NULL)
  if (is.null(con)) {
    stop("Refusing to overwrite immutable Design-100 record: ", path, call. = FALSE)
  }
  ok <- tryCatch({ writeLines(enc2utf8(text), con, useBytes = TRUE); TRUE },
                 error = function(e) FALSE)
  try(close(con), silent = TRUE)
  if (!ok) stop("Exclusive record creation was interrupted: ", path, call. = FALSE)
  invisible(path)
}

d100_write_exclusive_json <- function(path, value) {
  d100_write_exclusive_text(path, d100_json(value, pretty = TRUE))
}

d100_read_json <- function(path) {
  if (!file.exists(path) || !requireNamespace("jsonlite", quietly = TRUE)) return(NULL)
  tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE), error = function(e) NULL)
}

d100_launch_path <- function(root, task_id) {
  d100_require_path_token(task_id, "task_id")
  d100_path(root, "launches", task_id)
}
d100_terminal_path <- function(root, task_id) {
  d100_require_path_token(task_id, "task_id")
  d100_path(root, "terminals", task_id)
}
d100_progress_path <- function(root, task_id, sequence) {
  d100_require_path_token(task_id, "task_id")
  if (!d100_integer_at_least(sequence, 1L)) stop("Progress sequence must be positive", call. = FALSE)
  d100_path(file.path(root, "progress"), task_id, sprintf("%08d", as.integer(sequence)))
}
d100_liveness_path <- function(root, task_id, sequence) {
  d100_require_path_token(task_id, "task_id")
  if (!d100_integer_at_least(sequence, 1L)) stop("Liveness sequence must be positive", call. = FALSE)
  d100_path(file.path(root, "liveness"), task_id, sprintf("%08d", as.integer(sequence)))
}

# `dir.create()` is an atomic per-task reservation on the filesystems used for
# these private records.  We deliberately do not reclaim an existing lock:
# a stale or competing writer is ambiguous evidence and must fail closed.
d100_with_task_lock <- function(root, task_id, action) {
  if (!d100_path_token(task_id) || !is.function(action)) {
    stop("A task lock requires one task id and one action.", call. = FALSE)
  }
  lock <- file.path(root, "locks", paste0(task_id, ".lock"))
  dir.create(dirname(lock), recursive = TRUE, showWarnings = FALSE)
  acquired <- isTRUE(suppressWarnings(dir.create(lock, mode = "0700")))
  if (!acquired) {
    stop("Refusing concurrent or stale Design-100 task writer: ", task_id,
         call. = FALSE)
  }
  on.exit({
    if (unlink(lock, recursive = TRUE) != 0L) {
      stop("Could not release Design-100 task lock: ", task_id, call. = FALSE)
    }
  }, add = TRUE)
  action()
}

d100_write_launch <- function(root, record) {
  if (!d100_validate_launch(record)) stop("Invalid Design-100 launch record", call. = FALSE)
  d100_write_exclusive_json(d100_launch_path(root, record$task_id), record)
}

d100_read_progress_events <- function(root, task_id, launch = NULL) {
  d100_require_path_token(task_id, "task_id")
  directory <- file.path(root, "progress", task_id)
  if (!dir.exists(directory)) return(list())
  paths <- sort(list.files(directory, pattern = "\\.json$", full.names = TRUE))
  if (!length(paths)) return(list())

  events <- lapply(paths, d100_read_json)
  if (any(vapply(events, is.null, logical(1)))) {
    stop("Malformed existing Design-100 progress record", call. = FALSE)
  }
  if (!d100_validate_progress_series(events, launch)) {
    stop("Malformed existing Design-100 progress history", call. = FALSE)
  }
  expected_names <- sprintf("%08d.json", vapply(events, `[[`, numeric(1), "sequence"))
  if (!identical(basename(paths), expected_names)) {
    stop("Malformed existing Design-100 progress history", call. = FALSE)
  }
  events
}

d100_read_liveness_events <- function(root, task_id, launch = NULL) {
  d100_require_path_token(task_id, "task_id")
  directory <- file.path(root, "liveness", task_id)
  if (!dir.exists(directory)) return(list())
  paths <- sort(list.files(directory, pattern = "\\.json$", full.names = TRUE))
  if (!length(paths)) return(list())

  events <- lapply(paths, d100_read_json)
  if (any(vapply(events, is.null, logical(1)))) {
    stop("Malformed existing Design-100 liveness record", call. = FALSE)
  }
  if (!d100_validate_liveness_series(events, launch)) {
    stop("Malformed existing Design-100 liveness history", call. = FALSE)
  }
  expected_names <- sprintf("%08d.json", vapply(events, `[[`, numeric(1), "sequence"))
  if (!identical(basename(paths), expected_names)) {
    stop("Malformed existing Design-100 liveness history", call. = FALSE)
  }
  events
}

d100_write_progress_event <- function(root, event, launch = NULL) {
  if (!d100_validate_progress_event(event, launch)) {
    stop("Invalid Design-100 progress event", call. = FALSE)
  }
  d100_with_task_lock(root, event$task_id, function() {
    prior <- d100_read_progress_events(root, event$task_id, launch = launch)
    series <- c(prior, list(event))
    if (!d100_validate_progress_series(series, launch)) {
      stop("Design-100 progress events must be monotone", call. = FALSE)
    }
    d100_write_exclusive_json(d100_progress_path(root, event$task_id, event$sequence), event)
  })
}

d100_write_liveness_event <- function(root, event, launch = NULL) {
  if (!d100_validate_liveness_event(event, launch)) {
    stop("Invalid Design-100 liveness event", call. = FALSE)
  }
  d100_with_task_lock(root, event$task_id, function() {
    prior <- d100_read_liveness_events(root, event$task_id, launch = launch)
    series <- c(prior, list(event))
    if (!d100_validate_liveness_series(series, launch)) {
      stop("Design-100 liveness events must be monotone", call. = FALSE)
    }
    d100_write_exclusive_json(d100_liveness_path(root, event$task_id, event$sequence), event)
  })
}

d100_write_terminal <- function(root, record, launch = NULL) {
  if (!d100_validate_terminal(record, launch)) stop("Invalid Design-100 terminal record", call. = FALSE)
  d100_write_exclusive_json(d100_terminal_path(root, record$task_id), record)
}
