#!/usr/bin/env Rscript
## Isolated process components for PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1.
##
## The parent materializer is intentionally separate.  This runner implements
## disposable historical-V3 validation and the one-object trust-region worker;
## it never writes a scientific result root itself.

args <- commandArgs(trailingOnly = TRUE)
source_only <- identical(Sys.getenv("SPDE_SLOPE_GAUGE_TR_SOURCE_ONLY"), "1")
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
if (!source_only && length(file_arg) != 1L) {
  stop("trust-region runner must be invoked by Rscript --file", call. = FALSE)
}
script_path <- if (source_only) {
  Sys.getenv("SPDE_SLOPE_GAUGE_TR_RUNNER_PATH")
} else {
  sub("^--file=", "", file_arg)
}
if (!is.character(script_path) || length(script_path) != 1L || !nzchar(script_path)) {
  stop("trust-region runner path is missing", call. = FALSE)
}
script_path <- normalizePath(script_path, mustWork = TRUE)
script_dir <- dirname(script_path)
source(file.path(script_dir, "spde-slope-gauge-contract.R"), local = TRUE)
source(file.path(script_dir, "spde-slope-gauge-sign-contract.R"), local = TRUE)
source(file.path(script_dir, "spde-slope-gauge-trust-region-contract.R"), local = TRUE)
source(file.path(script_dir, "spde-slope-gauge-trust-region-adapter.R"), local = TRUE)
source(file.path(script_dir, "spde-slope-gauge-trust-region-smoke-contract.R"), local = TRUE)

.spde_slope_gauge_tr_runner_fail <- function(message) {
  stop(message, call. = FALSE)
}

.spde_slope_gauge_tr_runner_stage_token <- function(stage, parent_pid) {
  token_path <- file.path(stage, ".parent-stage.rds")
  token <- if (.spde_slope_gauge_tr_smoke_regular_file(token_path)) {
    tryCatch(readRDS(token_path), error = function(e) NULL)
  } else {
    NULL
  }
  stage <- tryCatch(normalizePath(stage, mustWork = TRUE), error = function(e) NA_character_)
  fields <- c("schema", "gate_base", "stage", "parent_pid", "v3_live_output", "worker_output")
  .spde_slope_gauge_tr_smoke_exact_names(token, fields) &&
    identical(token$schema, "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PARENT_STAGE_V1") &&
    is.character(stage) && length(stage) == 1L && !is.na(stage) &&
    identical(token$gate_base, dirname(stage)) && identical(token$stage, stage) &&
    identical(token$parent_pid, as.integer(parent_pid)) &&
    identical(token$v3_live_output, file.path(stage, "v3-live-child.rds")) &&
    identical(token$worker_output, file.path(stage, "worker-result.rds")) &&
    identical(list.files(stage, all.files = TRUE, no.. = TRUE), ".parent-stage.rds")
}

.spde_slope_gauge_tr_runner_atomic_rds <- function(x, path, parent_pid) {
  stage <- dirname(path)
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !identical(basename(path), "v3-live-child.rds") || file.exists(path) ||
      (!is.na(Sys.readlink(path)) && nzchar(Sys.readlink(path))) ||
      !isTRUE(.spde_slope_gauge_tr_runner_stage_token(stage, parent_pid))) {
    .spde_slope_gauge_tr_runner_fail("V3 live-child output path or stage token is invalid")
  }
  tmp <- tempfile(".spde-slope-gauge-tr-v3-", tmpdir = stage)
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, version = 3)
  if (!file.rename(tmp, path)) {
    .spde_slope_gauge_tr_runner_fail("could not atomically materialize V3 live-child receipt")
  }
  invisible(path)
}

.spde_slope_gauge_tr_runner_expected_dll <- function(locked) {
  path <- file.path(dirname(dirname(dirname(dirname(locked$root)))), "src", "gllvmTMB.so")
  if (!.spde_slope_gauge_tr_smoke_regular_file(path)) {
    .spde_slope_gauge_tr_runner_fail("retained predecessor DLL is absent")
  }
  list(path = normalizePath(path, mustWork = TRUE), md5 = unname(tools::md5sum(path))[[1L]])
}

.spde_slope_gauge_tr_runner_load_once <- function(expected) {
  loaded <- vapply(getLoadedDLLs(), function(x) as.character(x[["path"]]), character(1L))
  if (any(basename(loaded) == "gllvmTMB.so")) {
    .spde_slope_gauge_tr_runner_fail("same-basename gllvmTMB DLL is already loaded")
  }
  dyn.load(expected$path)
  active <- getLoadedDLLs()[["gllvmTMB"]]
  observed <- if (is.null(active)) NA_character_ else normalizePath(active[["path"]], mustWork = TRUE)
  md5 <- if (is.na(observed)) NA_character_ else unname(tools::md5sum(observed))[[1L]]
  if (!identical(observed, expected$path) || !identical(md5, expected$md5)) {
    .spde_slope_gauge_tr_runner_fail("active retained DLL identity mismatch")
  }
  list(path = observed, md5 = md5)
}

.spde_slope_gauge_tr_runner_historical_validator <- function(locked) {
  if (!.spde_slope_gauge_tr_smoke_regular_file(locked$historical_contract_path) ||
      !identical(unname(tools::md5sum(locked$historical_contract_path))[[1L]],
        locked$historical_contract_md5)) {
    .spde_slope_gauge_tr_runner_fail("historical V3 validator bytes are not frozen")
  }
  env <- new.env(parent = baseenv())
  source(locked$historical_contract_path, local = env)
  env
}

.spde_slope_gauge_tr_runner_stage_reason <- function(stage, message) {
  if (grepl("time limit|elapsed", message, ignore.case = TRUE)) return("time_limit_exceeded")
  switch(stage,
    predecessor = "predecessor_bytes_invalid",
    v3_live = "historical_v3_replay_failure",
    dll = "dll_identity_failure",
    historical = "historical_v3_replay_failure",
    factory = "fresh_object_unavailable",
    no_fit = "frozen_no_fit_replay_failed",
    sign = "sign_orbit_invariance_failed",
    callback_adapter = "callback_or_trust_region_failure",
    trust_region = "callback_or_trust_region_failure",
    audit = "callback_or_trust_region_failure",
    release = "object_release_failure",
    "child_unexpected_failure"
  )
}

spde_slope_gauge_trust_region_v3_live_child <- function(output, parent_pid) {
  if (!is.integer(parent_pid) || length(parent_pid) != 1L || is.na(parent_pid) || parent_pid < 1L) {
    .spde_slope_gauge_tr_runner_fail("parent PID is invalid")
  }
  started <- Sys.time()
  stage <- "predecessor"
  predecessor <- NULL
  runtime_dll <- NULL
  result <- tryCatch({
    locked <- spde_slope_gauge_trust_region_locked_predecessor()
    predecessor <- spde_slope_gauge_trust_region_validate_predecessor_bytes(locked$root, locked)
    if (!isTRUE(predecessor$valid)) .spde_slope_gauge_tr_runner_fail(predecessor$reason)
    stage <- "dll"
    runtime_dll <- .spde_slope_gauge_tr_runner_load_once(
      .spde_slope_gauge_tr_runner_expected_dll(locked)
    )
    stage <- "historical"
    historical <- .spde_slope_gauge_tr_runner_historical_validator(locked)
    historical_ledger <- readRDS(file.path(locked$root, "all-attempt-ledger.rds"))
    check <- historical$mspde_smoke_validate_closeout_ledger(
      historical_ledger, locked$root, locked$commit
    )
    if (!isTRUE(check$valid) || !identical(check$reason, "closeout_recomputed")) {
      .spde_slope_gauge_tr_runner_fail("historical V3 terminal validator did not recompute")
    }
    list(
      status = "GAUGE_TRUST_REGION_V3_LIVE_VALID",
      reason = check$reason,
      predecessor = predecessor[c("root", "commit", "receipt", "state_md5")],
      dll = runtime_dll,
      error = NA_character_
    )
  }, error = function(e) {
    list(
      status = "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD",
      reason = .spde_slope_gauge_tr_runner_stage_reason(stage, conditionMessage(e)),
      predecessor = if (isTRUE(predecessor$valid)) predecessor[c("root", "commit", "receipt", "state_md5")] else NULL,
      dll = runtime_dll,
      error = conditionMessage(e)
    )
  })
  ended <- Sys.time()
  receipt <- c(
    list(
      schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_V3_LIVE_CHILD_V1",
      parent_pid = parent_pid,
      child_pid = as.integer(Sys.getpid()),
      started_at = format(started, tz = "UTC", usetz = TRUE),
      ended_at = format(ended, tz = "UTC", usetz = TRUE),
      elapsed_s = as.double(difftime(ended, started, units = "secs"))
    ), result
  )
  .spde_slope_gauge_tr_runner_atomic_rds(receipt, output, parent_pid)
  invisible(receipt)
}

.spde_slope_gauge_tr_runner_release_object <- function(object, expected_dll) {
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
  isTRUE(cleared) && !is.null(active) &&
    identical(normalizePath(active[["path"]], mustWork = TRUE), expected_dll$path) &&
    identical(unname(tools::md5sum(active[["path"]]))[[1L]], expected_dll$md5)
}

.spde_slope_gauge_tr_runner_atomic_worker_rds <- function(x, path, parent_pid) {
  stage <- dirname(path)
  token_path <- file.path(stage, ".parent-stage.rds")
  token <- if (.spde_slope_gauge_tr_smoke_regular_file(token_path)) {
    tryCatch(readRDS(token_path), error = function(e) NULL)
  } else {
    NULL
  }
  stage <- tryCatch(normalizePath(stage, mustWork = TRUE), error = function(e) NA_character_)
  expected <- c(".parent-stage.rds", "v3-live-child.rds")
  valid <- .spde_slope_gauge_tr_smoke_exact_names(
    token, c("schema", "gate_base", "stage", "parent_pid", "v3_live_output", "worker_output")
  ) && identical(token$schema, "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PARENT_STAGE_V1") &&
    identical(token$stage, stage) && identical(token$parent_pid, parent_pid) &&
    identical(token$worker_output, file.path(stage, "worker-result.rds")) &&
    identical(path, token$worker_output) && identical(list.files(stage, all.files = TRUE, no.. = TRUE), expected)
  if (!isTRUE(valid) || file.exists(path) || (!is.na(Sys.readlink(path)) && nzchar(Sys.readlink(path)))) {
    .spde_slope_gauge_tr_runner_fail("trust-region worker output path or stage token is invalid")
  }
  tmp <- tempfile(".spde-slope-gauge-tr-worker-", tmpdir = stage)
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, version = 3)
  if (!file.rename(tmp, path)) .spde_slope_gauge_tr_runner_fail("could not atomically materialize worker result")
  invisible(path)
}

.spde_slope_gauge_tr_runner_worker_receipt <- function(
  parent_pid, started, predecessor, state_md5, dll, object, sign_orbit,
  nofit, trust_region, audit, status, reason, stage, completed_stage, error
) {
  list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_CHILD_V1",
    parent_pid = parent_pid,
    child_pid = as.integer(Sys.getpid()),
    started_at = format(started, tz = "UTC", usetz = TRUE),
    ended_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    elapsed_s = as.double(difftime(Sys.time(), started, units = "secs")),
    predecessor = predecessor,
    state_md5 = state_md5,
    dll = dll,
    object = object,
    nofit = nofit,
    sign_orbit = sign_orbit,
    trust_region = trust_region,
    audit = audit,
    status = status,
    reason = reason,
    stage = stage,
    completed_stage = completed_stage,
    error = error
  )
}

spde_slope_gauge_trust_region_worker_child <- function(output, parent_pid) {
  if (!is.integer(parent_pid) || length(parent_pid) != 1L || is.na(parent_pid) || parent_pid < 1L) {
    .spde_slope_gauge_tr_runner_fail("parent PID is invalid")
  }
  started <- Sys.time()
  stage <- "predecessor"
  completed_stage <- "none"
  predecessor <- NULL
  state_md5 <- NA_character_
  runtime_dll <- NULL
  object <- NULL
  created <- 0L
  released <- 0L
  nofit <- NULL
  sign_orbit <- NULL
  trust_region <- NULL
  audit <- NULL
  expected_dll <- NULL
  release_pending <- function() {
    if (is.null(object)) return(identical(created, released))
    released <<- if (isTRUE(.spde_slope_gauge_tr_runner_release_object(object, expected_dll))) 1L else 0L
    object <<- NULL
    if (!identical(created, released)) stage <<- "release"
    identical(created, released)
  }
  result <- tryCatch({
    locked <- spde_slope_gauge_trust_region_locked_predecessor()
    predecessor_check <- spde_slope_gauge_trust_region_validate_predecessor_bytes(locked$root, locked)
    if (!isTRUE(predecessor_check$valid)) .spde_slope_gauge_tr_runner_fail(predecessor_check$reason)
    predecessor <- predecessor_check[c("root", "commit", "receipt", "state_md5")]
    state_md5 <- predecessor_check$state_md5
    completed_stage <- "predecessor"
    expected_dll <- .spde_slope_gauge_tr_runner_expected_dll(locked)
    stage <- "v3_live"
    live_child <- tryCatch(readRDS(file.path(dirname(output), "v3-live-child.rds")), error = function(e) NULL)
    if (!isTRUE(spde_slope_gauge_trust_region_v3_live_child_ok(live_child, predecessor, expected_dll))) {
      .spde_slope_gauge_tr_runner_fail("V3 live-child receipt is invalid")
    }
    completed_stage <- "v3_live"
    stage <- "dll"
    runtime_dll <- .spde_slope_gauge_tr_runner_load_once(expected_dll)
    completed_stage <- "dll"
    state <- predecessor_check$state
    phi0 <- spde_slope_gauge_phi_from_theta(state$theta)
    stage <- "factory"
    object <- TMB::MakeADFun(
      data = state$data, parameters = state$parameters, map = state$map,
      random = state$random, DLL = "gllvmTMB", silent = TRUE
    )
    created <- 1L
    completed_stage <- "factory"
    bound <- spde_slope_gauge_trust_region_bind_object_order(
      object, state$parameter_order, state$block_labels
    )
    object <- bound$object
    stage <- "no_fit"
    nofit_gradient <- NULL
    nofit <- spde_slope_gauge_validate_no_fit_state(
      list(theta = state$theta, objective = state$objective, gradient = state$gradient),
      objective_fn = function(theta) object$fn(unname(theta)),
      gradient_fn = function(theta) {
        value <- object$gr(unname(theta))
        supplied_names <- names(value)
        if (!is.numeric(value) || length(value) != length(state$parameter_order) ||
            any(!is.finite(value)) ||
            (!is.null(supplied_names) && !identical(supplied_names, state$parameter_order))) {
          .spde_slope_gauge_tr_runner_fail("no-fit gradient has no verified positional order")
        }
        named <- stats::setNames(as.double(unname(value)), state$parameter_order)
        nofit_gradient <<- list(
          supplied_names = supplied_names,
          raw_values = as.double(unname(value)),
          named_gradient = named,
          mapping = bound$mapping
        )
        named
      }
    )
    nofit["gradient_callback"] <- list(nofit_gradient)
    if (!isTRUE(nofit$valid)) {
      .spde_slope_gauge_tr_runner_fail(sprintf("frozen no-fit replay failed: %s", nofit$reason))
    }
    completed_stage <- "no_fit"
    invisible(object$fn(unname(state$theta)))
    stage <- "sign"
    full <- object$env$last.par
    random_indices <- object$env$random
    sign_orbit <- spde_slope_gauge_validate_sign_orbit(
      parameters = state$parameters, random = state$random, full = full,
      random_indices = random_indices, theta = state$theta,
      conditional_hessian_fn = function(x) object$env$spHess(x, random = TRUE),
      report_fn = function(x) object$report(x),
      marginal_objective_fn = function(x) object$fn(x)
    )
    if (!isTRUE(sign_orbit$valid)) {
      if (!isTRUE(release_pending())) {
        stage <- "release"
        .spde_slope_gauge_tr_runner_fail(
          "sign-orbit failure could not release the clean worker object"
        )
      }
      .spde_slope_gauge_tr_runner_fail("live full-random-effect sign-orbit gate failed")
    }
    completed_stage <- "sign"
    stage <- "callback_adapter"
    callbacks <- spde_slope_gauge_trust_region_callback_adapter(
      object, 1L, runtime_dll$path, runtime_dll$md5,
      function(x, theta) TMB::sdreport(x, par.fixed = unname(theta), getReportCovariance = FALSE)
    )
    completed_stage <- "callback_adapter"
    stage <- "trust_region"
    trust_region <- spde_slope_gauge_trust_region(phi0, callbacks$evaluate, callbacks$covariance)
    completed_stage <- "trust_region"
    stage <- "audit"
    audit <- callbacks$audit()
    completed_stage <- "audit"
    stage <- "release"
    if (!isTRUE(release_pending())) .spde_slope_gauge_tr_runner_fail("worker object release failed")
    completed_stage <- "complete"
    .spde_slope_gauge_tr_runner_worker_receipt(
      parent_pid, started, predecessor, state_md5, runtime_dll,
      list(created = created, released = released), sign_orbit, nofit, trust_region, audit,
      trust_region$status, trust_region$reason, "complete", completed_stage, NA_character_
    )
  }, error = function(e) {
    release_pending()
    .spde_slope_gauge_tr_runner_worker_receipt(
      parent_pid, started, predecessor, state_md5, runtime_dll,
      list(created = created, released = released), sign_orbit, nofit, trust_region, audit,
      "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD",
      .spde_slope_gauge_tr_runner_stage_reason(stage, conditionMessage(e)), stage, completed_stage,
      conditionMessage(e)
    )
  })
  .spde_slope_gauge_tr_runner_atomic_worker_rds(result, output, parent_pid)
  invisible(result)
}

if (!source_only) {
  if (length(args) == 3L && identical(args[[1L]], "v3-live-child")) {
    parent_pid <- suppressWarnings(as.integer(args[[3L]]))
    spde_slope_gauge_trust_region_v3_live_child(args[[2L]], parent_pid)
    quit(status = 0L)
  }
  if (length(args) == 3L && identical(args[[1L]], "worker-child")) {
    parent_pid <- suppressWarnings(as.integer(args[[3L]]))
    spde_slope_gauge_trust_region_worker_child(args[[2L]], parent_pid)
    quit(status = 0L)
  }
  stop("usage: run-paper1-spde-slope-gauge-trust-region.R v3-live-child|worker-child <output.rds> <parent-pid>",
    call. = FALSE)
}
