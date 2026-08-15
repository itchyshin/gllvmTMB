#!/usr/bin/env Rscript
## Private child for the non-scientific SPDE-slope gauge no-fit gate.
## It has no optimiser, fitter, recovery extractor, or scientific result root.

args <- commandArgs(trailingOnly = TRUE)
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
if (length(file_arg) != 1L) stop("runner must be invoked by Rscript --file", call. = FALSE)
script_path <- normalizePath(sub("^--file=", "", file_arg), mustWork = TRUE)
script_dir <- dirname(script_path)
source(file.path(script_dir, "spde-slope-gauge-contract.R"), local = TRUE)
source(file.path(script_dir, "spde-slope-gauge-nofit-contract.R"), local = TRUE)

.spde_slope_gauge_nofit_gate_base <- function() {
  normalizePath(file.path(script_dir, "results"), mustWork = FALSE)
}

.spde_slope_gauge_nofit_stage_token <- function(parent, parent_pid) {
  token_path <- file.path(parent, ".parent-stage.rds")
  token <- if (file.exists(token_path) && identical(Sys.readlink(token_path), "")) {
    tryCatch(readRDS(token_path), error = function(e) NULL)
  } else NULL
  fields <- c("schema", "gate_base", "stage", "parent_pid", "child_output")
  stage <- tryCatch(normalizePath(parent, mustWork = TRUE), error = function(e) NA_character_)
  is.list(token) && identical(names(token), fields) &&
    identical(token$schema, "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_PARENT_STAGE_V1") &&
    identical(token$gate_base, .spde_slope_gauge_nofit_gate_base()) &&
    identical(dirname(stage), token$gate_base) &&
    grepl("^\\.PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-", basename(stage)) &&
    identical(token$stage, stage) && identical(token$parent_pid, as.integer(parent_pid)) &&
    identical(token$child_output, file.path(stage, "child-result.rds")) &&
    identical(list.files(parent, all.files = TRUE, no.. = TRUE), ".parent-stage.rds")
}

.spde_slope_gauge_nofit_atomic_rds <- function(x, path, parent_pid) {
  parent <- dirname(path)
  output_link <- Sys.readlink(path)
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !identical(basename(path), "child-result.rds") ||
      !grepl("^\\.PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-", basename(parent)) ||
      !dir.exists(parent) || !identical(Sys.readlink(parent), "") ||
      file.exists(path) || (!is.na(output_link) && nzchar(output_link)) ||
      !isTRUE(.spde_slope_gauge_nofit_stage_token(parent, parent_pid))) {
    stop("child output path is invalid", call. = FALSE)
  }
  tmp <- tempfile(".spde-slope-gauge-nofit-", tmpdir = parent)
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, version = 3)
  if (!file.rename(tmp, path)) stop("could not atomically materialize child result", call. = FALSE)
  invisible(path)
}

.spde_slope_gauge_nofit_expected_dll <- function(locked) {
  repo <- dirname(dirname(dirname(dirname(locked$root))))
  path <- file.path(repo, "src", "gllvmTMB.so")
  if (!file.exists(path)) stop("frozen predecessor DLL is absent", call. = FALSE)
  list(path = normalizePath(path, mustWork = TRUE),
    md5 = unname(tools::md5sum(path))[[1L]])
}

.spde_slope_gauge_nofit_runtime_dll <- function(expected) {
  loaded <- getLoadedDLLs()
  paths <- vapply(loaded, function(x) as.character(x[["path"]]), character(1L))
  if (any(basename(paths) == "gllvmTMB.so")) {
    stop("a same-basename gllvmTMB DLL is already loaded", call. = FALSE)
  }
  dyn.load(expected$path)
  active <- getLoadedDLLs()[["gllvmTMB"]]
  if (is.null(active) || !file.exists(active[["path"]])) {
    stop("exact gllvmTMB DLL did not activate", call. = FALSE)
  }
  observed_path <- normalizePath(active[["path"]], mustWork = TRUE)
  observed_md5 <- unname(tools::md5sum(observed_path))[[1L]]
  if (!identical(observed_path, expected$path) || !identical(observed_md5, expected$md5)) {
    stop("active gllvmTMB DLL does not match frozen predecessor", call. = FALSE)
  }
  list(path = observed_path, md5 = observed_md5)
}

.spde_slope_gauge_nofit_release_object <- function(object, expected_dll) {
  if (!is.list(object) || !is.environment(object$env)) return(FALSE)
  env <- object$env
  cleared <- FALSE
  for (name in c("ADFun", "ADGrad", "Fun")) {
    if (exists(name, envir = env, inherits = FALSE)) {
      cleared <- TRUE
      assign(name, NULL, envir = env)
    }
  }
  object <- NULL
  invisible(gc(verbose = FALSE))
  active <- getLoadedDLLs()[["gllvmTMB"]]
  isTRUE(cleared) && !is.null(active) && file.exists(active[["path"]]) &&
    identical(normalizePath(active[["path"]], mustWork = TRUE), expected_dll$path) &&
    identical(unname(tools::md5sum(active[["path"]]))[[1L]], expected_dll$md5)
}

.spde_slope_gauge_nofit_historical_contract <- function(locked) {
  repo <- dirname(dirname(dirname(dirname(locked$root))))
  path <- file.path(repo, "dev", "isdm-package-recovery", "matched-spde-smoke-contract.R")
  if (!file.exists(path)) stop("historical MSPDE V3 contract is absent", call. = FALSE)
  env <- new.env(parent = baseenv())
  source(path, local = env)
  env
}

.spde_slope_gauge_nofit_audit_ok <- function(audit, nofit) {
  records <- if (is.list(nofit)) nofit$finite_difference else NULL
  if (!is.list(audit) || !is.list(nofit) || !is.list(records) || length(records) != 22L ||
      !is.list(audit$objective) || length(audit$objective) != 45L ||
      !is.list(audit$gradient) || length(audit$gradient) != 1L ||
      !is.numeric(nofit$raw_theta) || !is.numeric(nofit$raw_gradient) ||
      !all(vapply(audit$objective, function(record) {
        is.list(record) && identical(names(record), c("input", "value"))
      }, logical(1L))) ||
      !is.list(audit$gradient[[1L]]) || !identical(names(audit$gradient[[1L]]),
        c("input", "raw_gradient", "supplied_names", "named_gradient")) ||
      !identical(audit$objective[[1L]]$input, nofit$raw_theta) ||
      !identical(audit$objective[[1L]]$value, nofit$objective) ||
      !identical(audit$gradient[[1L]]$input, nofit$raw_theta) ||
      !identical(audit$gradient[[1L]]$raw_gradient, unname(nofit$raw_gradient)) ||
      !(is.null(audit$gradient[[1L]]$supplied_names) ||
        identical(audit$gradient[[1L]]$supplied_names, names(nofit$raw_gradient))) ||
      !identical(audit$gradient[[1L]]$named_gradient, nofit$raw_gradient)) return(FALSE)
  expected <- unlist(lapply(records, function(record) list(
    list(input = record$theta_plus, value = record$objective_plus),
    list(input = record$theta_minus, value = record$objective_minus)
  )), recursive = FALSE)
  all(vapply(seq_along(expected), function(i) {
    identical(audit$objective[[i + 1L]]$input, expected[[i]]$input) &&
      identical(audit$objective[[i + 1L]]$value, expected[[i]]$value)
  }, logical(1L)))
}

.spde_slope_gauge_nofit_stage_reason <- function(stage, message) {
  if (grepl("time limit|elapsed", message, ignore.case = TRUE)) return("time_limit_exceeded")
  switch(stage,
    predecessor_bytes = "predecessor_bytes_invalid",
    dll = "dll_identity_failure",
    historical = "historical_v3_replay_failure",
    factory = "fresh_object_unavailable",
    callback = "callback_or_finite_difference_failure",
    audit = "callback_audit_invalid",
    release = "object_release_failure",
    "child_unexpected_failure"
  )
}

.spde_slope_gauge_nofit_child_result <- function(output, parent_pid) {
  started <- Sys.time()
  deadline_s <- 1800
  setTimeLimit(elapsed = deadline_s, transient = TRUE)
  on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)
  locked <- spde_slope_gauge_nofit_locked_predecessor()
  stage <- "predecessor_bytes"
  predecessor <- NULL
  expected_dll <- NULL
  runtime_dll <- NULL
  callbacks <- NULL
  nofit <- NULL
  audit <- NULL
  object <- NULL
  created <- 0L
  released <- 0L
  release_pending <- function() {
    if (is.null(object)) return(identical(released, created))
    released <<- as.integer(isTRUE(.spde_slope_gauge_nofit_release_object(object, expected_dll)))
    object <<- NULL
    identical(released, created)
  }
  on.exit(release_pending(), add = TRUE)
  base <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_CHILD_V1",
    parent_pid = as.integer(parent_pid), child_pid = as.integer(Sys.getpid()),
    started_at = format(started, tz = "UTC", usetz = TRUE), deadline_s = as.integer(deadline_s)
  )
  result <- tryCatch({
    predecessor <- spde_slope_gauge_nofit_validate_predecessor_bytes(locked$root, locked)
    if (!isTRUE(predecessor$valid)) stop(predecessor$reason, call. = FALSE)
    stage <- "dll"
    expected_dll <- .spde_slope_gauge_nofit_expected_dll(locked)
    runtime_dll <- .spde_slope_gauge_nofit_runtime_dll(expected_dll)
    stage <- "historical"
    historical <- .spde_slope_gauge_nofit_historical_contract(locked)
    historical_ledger <- readRDS(file.path(locked$root, "all-attempt-ledger.rds"))
    historical_check <- historical$mspde_smoke_validate_closeout_ledger(
      historical_ledger, locked$root, locked$commit
    )
    if (!isTRUE(historical_check$valid) || !identical(historical_check$reason, "closeout_recomputed")) {
      stop("historical MSPDE V3 live terminal replay did not pass", call. = FALSE)
    }
    historical <- NULL
    historical_ledger <- NULL
    invisible(gc(verbose = FALSE))
    state <- predecessor$state
    stage <- "factory"
    object <- TMB::MakeADFun(data = state$data, parameters = state$parameters,
      map = state$map, random = state$random, DLL = "gllvmTMB", silent = TRUE)
    created <- 1L
    stage <- "callback"
    callbacks <- spde_slope_gauge_nofit_wrap_object_callbacks(
      object, state, 1L, runtime_dll$path, runtime_dll$md5, locked
    )
    nofit <- spde_slope_gauge_validate_no_fit_state(
      state[c("theta", "objective", "gradient")], callbacks$objective_fn, callbacks$gradient_fn
    )
    audit <- callbacks$evaluation_audit()
    complete_replay <- isTRUE(nofit$valid) || identical(nofit$reason, "no_fit_state_replay_failed")
    if (complete_replay && !.spde_slope_gauge_nofit_audit_ok(audit, nofit)) {
      stage <- "audit"
      stop("complete callback audit is inconsistent with no-fit evidence", call. = FALSE)
    }
    stage <- "release"
    if (!isTRUE(release_pending())) stop("fresh no-fit object release or resident DLL check failed", call. = FALSE)
    list(
      status = if (isTRUE(nofit$valid)) "SPDE_SLOPE_GAUGE_NOFIT_VALID" else if
        (identical(nofit$reason, "no_fit_state_replay_failed")) "SPDE_SLOPE_GAUGE_NOFIT_REPLAY_HOLD" else
        "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD",
      reason = nofit$reason, predecessor = list(
        root = locked$root, commit = locked$commit, state_md5 = predecessor$state_md5,
        historical_reason = historical_check$reason, post_replay_gc = TRUE
      ),
      dll = runtime_dll, object = list(created = created, released = released,
        block_labels = callbacks$block_labels, parameter_order = callbacks$parameter_order),
      nofit = nofit, callback_audit = audit, error = NA_character_
    )
  }, error = function(e) {
    if (!is.null(callbacks)) audit <- tryCatch(callbacks$evaluation_audit(), error = function(x) NULL)
    release_pending()
    list(
    status = "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD",
    reason = .spde_slope_gauge_nofit_stage_reason(stage, conditionMessage(e)),
    predecessor = if (isTRUE(predecessor$valid)) list(
      root = locked$root, commit = locked$commit, state_md5 = predecessor$state_md5
    ) else NULL,
    dll = runtime_dll, object = list(created = created, released = released),
    nofit = nofit, callback_audit = audit, error = conditionMessage(e)
  )})
  ended <- Sys.time()
  child <- c(base, result, list(
    ended_at = format(ended, tz = "UTC", usetz = TRUE),
    elapsed_s = as.double(difftime(ended, started, units = "secs"))
  ))
  .spde_slope_gauge_nofit_atomic_rds(child, output, parent_pid)
  invisible(child)
}

if (length(args) == 1L && identical(args[[1L]], "validate")) {
  verdict <- spde_slope_gauge_nofit_validate_predecessor_bytes()
  if (!isTRUE(verdict$valid)) stop(verdict$reason, call. = FALSE)
  cat("SPDE_SLOPE_GAUGE_NOFIT_PREDECESSOR_BYTES_PASS\n")
  quit(status = 0L)
}

if (length(args) == 3L && identical(args[[1L]], "child")) {
  output <- args[[2L]]
  parent_pid <- suppressWarnings(as.integer(args[[3L]]))
  if (is.na(parent_pid) || parent_pid < 1L) stop("child parent PID is invalid", call. = FALSE)
  .spde_slope_gauge_nofit_child_result(output, parent_pid)
  quit(status = 0L)
}

stop("usage: run-paper1-spde-slope-gauge-nofit.R validate | child <output.rds> <parent-pid>",
  call. = FALSE)
