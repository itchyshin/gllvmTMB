# Design-100 private oracle-worker contract (worktree-local).
#
# This file deliberately defines contracts and progress records only. It does
# not integrate, optimise, or call package fitting code.

.d100_scalar_character <- function(x, name, optional = FALSE) {
  if (optional && is.null(x)) {
    return(NULL)
  }

  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    stop(sprintf("`%s` must be one non-empty character value.", name), call. = FALSE)
  }

  x
}

.d100_validate_token <- function(x, name, optional = FALSE) {
  x <- .d100_scalar_character(x, name, optional = optional)
  if (is.null(x)) {
    return(NULL)
  }

  if (!grepl("^[A-Za-z0-9][A-Za-z0-9._:-]*$", x)) {
    stop(
      sprintf("`%s` must use only letters, digits, `.`, `_`, `:`, or `-`.", name),
      call. = FALSE
    )
  }

  x
}

#' Validate the immutable input identity for one private oracle task
#'
#' @param coordinate_hash Immutable coordinate identity.
#' @param pattern_code Immutable pattern identity.
#' @param backend Immutable backend identity.
#' @param component Optional immutable nested-component identity.
#'
#' @return A locked environment of class `d100_oracle_task`.
#' @keywords internal
d100_oracle_task_input <- function(coordinate_hash, pattern_code, backend,
                                   component = NULL) {
  coordinate_hash <- .d100_validate_token(coordinate_hash, "coordinate_hash")
  pattern_code <- .d100_validate_token(pattern_code, "pattern_code")
  backend <- .d100_validate_token(backend, "backend")
  component <- .d100_validate_token(component, "component", optional = TRUE)

  task <- new.env(parent = emptyenv())
  task$coordinate_hash <- coordinate_hash
  task$pattern_code <- pattern_code
  task$backend <- backend
  task$component <- component
  class(task) <- c("d100_oracle_task", "environment")
  lockEnvironment(task, bindings = TRUE)
  task
}

.d100_validate_task <- function(task) {
  if (!inherits(task, "d100_oracle_task") || !is.environment(task)) {
    stop("`task` must be produced by `d100_oracle_task_input()`.", call. = FALSE)
  }

  required <- c("coordinate_hash", "pattern_code", "backend", "component")
  if (!identical(sort(ls(task, all.names = TRUE)), sort(required))) {
    stop("`task` does not have the immutable Design-100 task schema.", call. = FALSE)
  }
  if (!environmentIsLocked(task) ||
      !all(vapply(required, bindingIsLocked, logical(1), env = task))) {
    stop("`task` bindings must be locked.", call. = FALSE)
  }

  invisible(task)
}

#' Describe the only permitted numerical boundary for a future oracle runner
#'
#' This declarative boundary names the original `u` coordinate convention for
#' a future runner. It returns a description only; it neither inspects nor
#' retains coordinates and never evaluates an integrand.
#'
#' @param task A `d100_oracle_task`.
#' @param original_u Reserved original-coordinate boundary declaration. It is
#'   deliberately not inspected or retained by this record-only surface.
#' @param component Component being described; defaults to the task component.
#'
#' @return A boundary descriptor with status `not_executed`.
#' @keywords internal
d100_oracle_direct_original_u_boundary <- function(task, original_u = NULL,
                                                   component = task$component) {
  .d100_validate_task(task)
  component <- .d100_validate_token(component, "component", optional = TRUE)

  list(
    coordinate_hash = task$coordinate_hash,
    pattern_code = task$pattern_code,
    backend = task$backend,
    component = component,
    coordinate_system = "original_u",
    status = "not_executed"
  )
}

.d100_declarative_progress_event <- function(task, phase, boundary, component = NULL) {
  .d100_validate_task(task)
  phase <- match.arg(phase, c("component", "cubature"))
  boundary <- match.arg(boundary, c("before", "after"))
  component <- .d100_validate_token(component, "component", optional = TRUE)

  list(
    record_type = "declarative_progress_plan",
    coordinate_hash = task$coordinate_hash,
    pattern_code = task$pattern_code,
    backend = task$backend,
    component = component,
    phase = phase,
    boundary = boundary
  )
}

#' Emit declarative plan events around each nested component and its cubature
#'
#' The callback receives plan events before and after a component, and before
#' and after the cubature nested within that component. These are not
#' `d100-progress-v1` records: they lack a launch binding and do not attest to
#' liveness or completed numerical work.
#'
#' @param task A `d100_oracle_task` without a fixed component.
#' @param components Non-empty character vector of nested component identities.
#' @param emit Callback receiving one progress event.
#'
#' @return A list of all emitted declarative plan events, invisibly.
#' @keywords internal
d100_oracle_emit_progress <- function(task, components, emit = identity) {
  .d100_validate_task(task)
  if (!is.function(emit)) {
    stop("`emit` must be a function.", call. = FALSE)
  }
  if (!is.character(components) || !length(components) ||
      anyNA(components) || any(!nzchar(components))) {
    stop("`components` must be a non-empty character vector.", call. = FALSE)
  }
  components <- vapply(
    components,
    .d100_validate_token,
    character(1),
    name = "component",
    optional = FALSE
  )
  if (anyDuplicated(components)) {
    stop("`components` must not contain duplicates.", call. = FALSE)
  }

  events <- vector("list", length(components) * 4L)
  cursor <- 0L
  for (component in components) {
    for (event in list(
      .d100_declarative_progress_event(task, "component", "before", component),
      .d100_declarative_progress_event(task, "cubature", "before", component),
      .d100_declarative_progress_event(task, "cubature", "after", component),
      .d100_declarative_progress_event(task, "component", "after", component)
    )) {
      cursor <- cursor + 1L
      emit(event)
      events[[cursor]] <- event
    }
  }

  invisible(events)
}

#' Create a nonterminal component plan for a later approved executor
#'
#' @param task A `d100_oracle_task`.
#' @param component Nested component identity.
#'
#' @return A `d100_oracle_component_plan` declarative plan.
#' @keywords internal
d100_oracle_component_plan <- function(task, component) {
  .d100_validate_task(task)
  component <- .d100_validate_token(component, "component")

  structure(
    list(
      coordinate_hash = task$coordinate_hash,
      pattern_code = task$pattern_code,
      backend = task$backend,
      component = component,
      record_type = "declarative_component_plan",
      status = "not_executed",
      is_terminal = FALSE
    ),
    class = "d100_oracle_component_plan"
  )
}

#' Refuse terminal construction from the contract-only planning surface
#'
#' @param ... Reserved for a separately approved executor.
#'
#' @return Never returns.
#' @keywords internal
d100_oracle_component_terminal <- function(...) {
  stop(
    "This contract-only planner cannot construct a component terminal; a future approved executor must supply a validated d100-terminal-v1 record.",
    call. = FALSE
  )
}

#' Construct one completed per-pattern aggregate from completed component terminals
#'
#' @param task A `d100_oracle_task`.
#' @param component_terminals Non-empty list of completed component terminal records.
#'
#' @return A `d100_oracle_pattern_aggregate` record.
#' @keywords internal
d100_oracle_aggregate_pattern <- function(task, component_terminals) {
  .d100_validate_task(task)
  if (!is.list(component_terminals) || !length(component_terminals)) {
    stop("`component_terminals` must be a non-empty list.", call. = FALSE)
  }
  for (terminal in component_terminals) {
    if (!d100_validate_terminal(terminal) ||
        !identical(terminal$schema, "d100-terminal-v1") ||
        !identical(terminal$record_type, "component") ||
        !identical(terminal$task_kind, "component") ||
        !identical(terminal$status, "PROGRESS_COMPLETE") ||
        !identical(terminal$pattern_id, task$pattern_code)) {
      stop("`component_terminals` must contain valid d100-terminal-v1 component terminals for this pattern.",
           call. = FALSE)
    }
  }

  components <- vapply(component_terminals, `[[`, character(1), "component_id")
  if (anyDuplicated(components)) {
    stop("Component terminals must be unique within one pattern.", call. = FALSE)
  }

  structure(
    list(
      coordinate_hash = task$coordinate_hash,
      pattern_code = task$pattern_code,
      backend = task$backend,
      status = "PROGRESS_COMPLETE",
      component_terminals = component_terminals,
      component_count = length(component_terminals)
    ),
    class = "d100_oracle_pattern_aggregate"
  )
}

#' Refuse all numerical execution until a separately approved runner exists
#'
#' @param execute Must remain `FALSE` in this Design-100 placeholder.
#'
#' @return Never returns.
#' @keywords internal
d100_oracle_execution_guard <- function(execute = FALSE) {
  if (!isFALSE(execute)) {
    stop(
      "`--execute` is reserved for a future approved oracle runner; execution is unavailable.",
      call. = FALSE
    )
  }
  stop(
    "This Design-100 oracle worker is contract-only and cannot execute integration.",
    call. = FALSE
  )
}
