#!/usr/bin/env Rscript
## Private V2 child for the SPDE-slope gauge no-fit gate.
## It creates one fresh TMB object, makes no optimizer call, and writes only to
## the parent-created V2 staging location authenticated by .parent-stage.rds.

args <- commandArgs(trailingOnly = TRUE)
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
source_only <- identical(
  Sys.getenv("SPDE_SLOPE_GAUGE_NOFIT_V2_SOURCE_ONLY"),
  "1"
)
if (length(file_arg) != 1L && !source_only) {
  stop("runner must be invoked by Rscript --file", call. = FALSE)
}
script_path <- if (source_only) {
  Sys.getenv("SPDE_SLOPE_GAUGE_NOFIT_V2_RUNNER_PATH")
} else {
  sub("^--file=", "", file_arg)
}
if (!nzchar(script_path)) {
  stop("source-only runner path is missing", call. = FALSE)
}
script_path <- normalizePath(script_path, mustWork = TRUE)
script_dir <- dirname(script_path)
source(file.path(script_dir, "spde-slope-gauge-contract.R"), local = TRUE)
source(file.path(script_dir, "spde-slope-gauge-nofit-contract.R"), local = TRUE)

.spde_slope_gauge_nofit_v2_gate_base <- function() {
  normalizePath(file.path(script_dir, "results"), mustWork = FALSE)
}

.spde_slope_gauge_nofit_v2_stage_token_ok <- function(parent, parent_pid) {
  token_path <- file.path(parent, ".parent-stage.rds")
  token <- if (
    file.exists(token_path) && identical(Sys.readlink(token_path), "")
  ) {
    tryCatch(readRDS(token_path), error = function(e) NULL)
  } else {
    NULL
  }
  stage <- tryCatch(
    normalizePath(parent, mustWork = TRUE),
    error = function(e) NA_character_
  )
  fields <- c("schema", "gate_base", "stage", "parent_pid", "child_output")
  .spde_slope_gauge_nofit_exact_names(token, fields) &&
    identical(
      token$schema,
      "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2_PARENT_STAGE_V1"
    ) &&
    identical(token$gate_base, .spde_slope_gauge_nofit_v2_gate_base()) &&
    identical(dirname(stage), token$gate_base) &&
    grepl("^\\.PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-", basename(stage)) &&
    identical(token$stage, stage) &&
    identical(token$parent_pid, as.integer(parent_pid)) &&
    identical(token$child_output, file.path(stage, "child-result.rds")) &&
    identical(
      list.files(stage, all.files = TRUE, no.. = TRUE),
      ".parent-stage.rds"
    )
}

.spde_slope_gauge_nofit_v2_atomic_rds <- function(x, path, parent_pid) {
  parent <- dirname(path)
  link <- Sys.readlink(path)
  if (
    !is.character(path) ||
      length(path) != 1L ||
      is.na(path) ||
      !identical(basename(path), "child-result.rds") ||
      !dir.exists(parent) ||
      !identical(Sys.readlink(parent), "") ||
      file.exists(path) ||
      (!is.na(link) && nzchar(link)) ||
      !isTRUE(.spde_slope_gauge_nofit_v2_stage_token_ok(parent, parent_pid))
  ) {
    stop("V2 child output path is invalid", call. = FALSE)
  }
  tmp <- tempfile(".spde-slope-gauge-nofit-v2-", tmpdir = parent)
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, version = 3)
  if (!file.rename(tmp, path)) {
    stop("could not atomically materialize V2 child result", call. = FALSE)
  }
  invisible(path)
}

.spde_slope_gauge_nofit_v2_expected_dll <- function(locked) {
  path <- file.path(
    dirname(dirname(dirname(dirname(locked$root)))),
    "src",
    "gllvmTMB.so"
  )
  if (!file.exists(path)) {
    stop("frozen predecessor DLL is absent", call. = FALSE)
  }
  list(
    path = normalizePath(path, mustWork = TRUE),
    md5 = unname(tools::md5sum(path))[[1L]]
  )
}

.spde_slope_gauge_nofit_v2_runtime_dll <- function(expected) {
  paths <- vapply(
    getLoadedDLLs(),
    function(x) as.character(x[["path"]]),
    character(1L)
  )
  if (any(basename(paths) == "gllvmTMB.so")) {
    stop("a same-basename gllvmTMB DLL is already loaded", call. = FALSE)
  }
  dyn.load(expected$path)
  active <- getLoadedDLLs()[["gllvmTMB"]]
  observed <- if (is.null(active)) {
    NA_character_
  } else {
    normalizePath(active[["path"]], mustWork = TRUE)
  }
  md5 <- if (is.na(observed)) {
    NA_character_
  } else {
    unname(tools::md5sum(observed))[[1L]]
  }
  if (!identical(observed, expected$path) || !identical(md5, expected$md5)) {
    stop("active DLL mismatch", call. = FALSE)
  }
  list(path = observed, md5 = md5)
}

.spde_slope_gauge_nofit_v2_release_object <- function(object, expected) {
  if (!is.list(object) || !is.environment(object$env)) {
    return(FALSE)
  }
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
  isTRUE(cleared) &&
    !is.null(active) &&
    identical(
      normalizePath(active[["path"]], mustWork = TRUE),
      expected$path
    ) &&
    identical(unname(tools::md5sum(active[["path"]]))[[1L]], expected$md5)
}

.spde_slope_gauge_nofit_v2_historical_contract <- function(locked) {
  if (
    !.spde_slope_gauge_nofit_regular_file(locked$historical_contract_path) ||
      !identical(
        unname(tools::md5sum(locked$historical_contract_path))[[1L]],
        locked$historical_contract_md5
      )
  ) {
    stop("historical MSPDE V3 contract bytes are not frozen", call. = FALSE)
  }
  env <- new.env(parent = baseenv())
  source(locked$historical_contract_path, local = env)
  env
}

.spde_slope_gauge_nofit_v2_stage_reason <- function(stage, message) {
  if (grepl("time limit|elapsed", message, ignore.case = TRUE)) {
    return("time_limit_exceeded")
  }
  switch(
    stage,
    v1_forensic = "v1_forensic_invalid",
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

.spde_slope_gauge_nofit_v2_partial_failure <- function(
  reason,
  stage,
  error,
  v1,
  v3,
  runtime_dll,
  created,
  released
) {
  if (
    !is.integer(created) ||
      length(created) != 1L ||
      created < 0L ||
      !is.integer(released) ||
      length(released) != 1L ||
      released < 0L ||
      created < released ||
      !.spde_slope_gauge_nofit_scalar_character(error)
  ) {
    stop("V2 child failure projection is malformed", call. = FALSE)
  }
  if (
    !identical(created, released) &&
      identical(created, 1L) &&
      identical(released, 0L)
  ) {
    reason <- "object_release_failure"
    stage <- "release"
  }
  timeout_stage <- identical(reason, "time_limit_exceeded")
  post_dll <- identical(reason, "historical_v3_replay_failure") ||
    reason %in%
      c(
        "fresh_object_unavailable",
        "callback_or_finite_difference_failure",
        "callback_audit_invalid",
        "object_release_failure"
      ) ||
    (timeout_stage &&
      stage %in% c("historical", "factory", "callback", "audit", "release"))
  early_timeout <- timeout_stage &&
    stage %in% c("v1_forensic", "predecessor_bytes", "dll")
  predecessor <- if (isTRUE(v1$valid) && isTRUE(v3$valid) && !early_timeout) {
    c(
      v3[c("root", "commit", "receipt", "state_md5")],
      list(
        v1_forensic = v1[c(
          "root",
          "commit",
          "receipt",
          "files",
          "status",
          "terminal_reason"
        )],
        historical_reason = if (stage == "historical") {
          NA_character_
        } else {
          "closeout_recomputed"
        },
        post_replay_gc = !identical(stage, "historical")
      )
    )
  } else {
    NULL
  }
  list(
    status = "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD",
    reason = reason,
    stage = stage,
    predecessor = predecessor,
    dll = if (post_dll) runtime_dll else NULL,
    object = list(created = created, released = released),
    nofit = NULL,
    callback_audit = NULL,
    error = error
  )
}

.spde_slope_gauge_nofit_v2_child_result <- function(output, parent_pid) {
  started <- Sys.time()
  deadline_s <- 1800
  setTimeLimit(elapsed = deadline_s, transient = TRUE)
  on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)
  locked_v3 <- spde_slope_gauge_nofit_locked_predecessor()
  stage <- "v1_forensic"
  v1 <- NULL
  v3 <- NULL
  historical_reason <- NA_character_
  post_replay_gc <- FALSE
  expected_dll <- NULL
  runtime_dll <- NULL
  callbacks <- NULL
  nofit <- NULL
  audit <- NULL
  object <- NULL
  created <- 0L
  released <- 0L
  release_pending <- function() {
    if (is.null(object)) {
      return(identical(released, created))
    }
    released <<- as.integer(isTRUE(.spde_slope_gauge_nofit_v2_release_object(
      object,
      expected_dll
    )))
    object <<- NULL
    identical(released, created)
  }
  on.exit(release_pending(), add = TRUE)
  base <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2_CHILD_V1",
    parent_pid = as.integer(parent_pid),
    child_pid = as.integer(Sys.getpid()),
    started_at = format(started, tz = "UTC", usetz = TRUE),
    deadline_s = as.integer(deadline_s)
  )
  result <- tryCatch(
    {
      v1 <- spde_slope_gauge_nofit_v2_validate_v1_forensic()
      if (!isTRUE(v1$valid)) {
        stop(v1$reason, call. = FALSE)
      }
      stage <- "predecessor_bytes"
      v3 <- spde_slope_gauge_nofit_validate_predecessor_bytes(
        locked_v3$root,
        locked_v3
      )
      if (!isTRUE(v3$valid)) {
        stop(v3$reason, call. = FALSE)
      }
      stage <- "dll"
      expected_dll <- .spde_slope_gauge_nofit_v2_expected_dll(locked_v3)
      runtime_dll <- .spde_slope_gauge_nofit_v2_runtime_dll(expected_dll)
      stage <- "historical"
      historical <- .spde_slope_gauge_nofit_v2_historical_contract(locked_v3)
      historical_ledger <- readRDS(file.path(
        locked_v3$root,
        "all-attempt-ledger.rds"
      ))
      historical_check <- historical$mspde_smoke_validate_closeout_ledger(
        historical_ledger,
        locked_v3$root,
        locked_v3$commit
      )
      if (
        !isTRUE(historical_check$valid) ||
          !identical(historical_check$reason, "closeout_recomputed")
      ) {
        stop(
          "historical MSPDE V3 live terminal replay did not pass",
          call. = FALSE
        )
      }
      historical_reason <- historical_check$reason
      historical <- NULL
      historical_ledger <- NULL
      invisible(gc(verbose = FALSE))
      post_replay_gc <- TRUE
      state <- v3$state
      stage <- "factory"
      object <- TMB::MakeADFun(
        data = state$data,
        parameters = state$parameters,
        map = state$map,
        random = state$random,
        DLL = "gllvmTMB",
        silent = TRUE
      )
      created <- 1L
      stage <- "callback"
      callbacks <- spde_slope_gauge_nofit_wrap_object_callbacks(
        object,
        state,
        1L,
        runtime_dll$path,
        runtime_dll$md5,
        locked_v3
      )
      nofit <- spde_slope_gauge_validate_no_fit_state(
        state[c("theta", "objective", "gradient")],
        callbacks$objective_fn,
        callbacks$gradient_fn
      )
      audit <- callbacks$evaluation_audit()
      complete_replay <- isTRUE(nofit$valid) ||
        identical(nofit$reason, "no_fit_state_replay_failed")
      if (complete_replay && !spde_slope_gauge_nofit_audit_ok(audit, nofit)) {
        stage <- "audit"
        stop(
          "complete callback audit is inconsistent with no-fit evidence",
          call. = FALSE
        )
      }
      stage <- "release"
      if (!isTRUE(release_pending())) {
        stop(
          "fresh no-fit object release or resident DLL check failed",
          call. = FALSE
        )
      }
      stage <- "complete"
      list(
        status = if (isTRUE(nofit$valid)) {
          "SPDE_SLOPE_GAUGE_NOFIT_VALID"
        } else if (identical(nofit$reason, "no_fit_state_replay_failed")) {
          "SPDE_SLOPE_GAUGE_NOFIT_REPLAY_HOLD"
        } else {
          "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
        },
        reason = nofit$reason,
        stage = stage,
        predecessor = c(
          v3[c("root", "commit", "receipt", "state_md5")],
          list(
            v1_forensic = v1[c(
              "root",
              "commit",
              "receipt",
              "files",
              "status",
              "terminal_reason"
            )],
            historical_reason = historical_reason,
            post_replay_gc = post_replay_gc
          )
        ),
        dll = runtime_dll,
        object = list(
          created = created,
          released = released,
          block_labels = callbacks$block_labels,
          parameter_order = callbacks$parameter_order
        ),
        nofit = nofit,
        callback_audit = audit,
        error = NA_character_
      )
    },
    error = function(e) {
      reason <- .spde_slope_gauge_nofit_v2_stage_reason(
        stage,
        conditionMessage(e)
      )
      release_pending()
      .spde_slope_gauge_nofit_v2_partial_failure(
        reason,
        stage,
        conditionMessage(e),
        v1,
        v3,
        runtime_dll,
        created,
        released
      )
    }
  )
  ended <- Sys.time()
  child <- c(
    base,
    result,
    list(
      ended_at = format(ended, tz = "UTC", usetz = TRUE),
      elapsed_s = as.double(difftime(ended, started, units = "secs"))
    )
  )
  .spde_slope_gauge_nofit_v2_atomic_rds(child, output, parent_pid)
  invisible(child)
}

if (!source_only) {
  if (length(args) == 1L && identical(args[[1L]], "validate")) {
    v1 <- spde_slope_gauge_nofit_v2_validate_v1_forensic()
    v3 <- spde_slope_gauge_nofit_validate_predecessor_bytes()
    if (!isTRUE(v1$valid) || !isTRUE(v3$valid)) {
      stop("V2 predecessor bytes are invalid", call. = FALSE)
    }
    cat("SPDE_SLOPE_GAUGE_NOFIT_V2_PREDECESSOR_BYTES_PASS\n")
    quit(status = 0L)
  }
  if (length(args) == 3L && identical(args[[1L]], "child")) {
    parent_pid <- suppressWarnings(as.integer(args[[3L]]))
    if (is.na(parent_pid) || parent_pid < 1L) {
      stop("child parent PID is invalid", call. = FALSE)
    }
    .spde_slope_gauge_nofit_v2_child_result(args[[2L]], parent_pid)
    quit(status = 0L)
  }
  stop(
    "usage: run-paper1-spde-slope-gauge-nofit-v2.R validate | child <output.rds> <parent-pid>",
    call. = FALSE
  )
}
