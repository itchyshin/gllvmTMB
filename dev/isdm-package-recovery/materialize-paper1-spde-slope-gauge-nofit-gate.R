#!/usr/bin/env Rscript
## Materialize the non-scientific gauge no-fit gate in a sibling staging root.
## This script is intentionally the only parent that may launch the isolated
## child.  It neither fits an ecological model nor runs an optimizer.

args <- commandArgs(trailingOnly = TRUE)
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
if (length(file_arg) != 1L) stop("materializer must be invoked by Rscript --file", call. = FALSE)
script_path <- normalizePath(sub("^--file=", "", file_arg), mustWork = TRUE)
script_dir <- dirname(script_path)
source(file.path(script_dir, "spde-slope-gauge-contract.R"), local = TRUE)
source(file.path(script_dir, "spde-slope-gauge-nofit-contract.R"), local = TRUE)

.spde_slope_gauge_nofit_materializer_atomic_rds <- function(x, path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || file.exists(path) ||
      (!is.na(Sys.readlink(path)) && nzchar(Sys.readlink(path)))) {
    stop("gate artifact target is not a fresh regular path", call. = FALSE)
  }
  tmp <- tempfile(".spde-slope-gauge-gate-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, version = 3)
  if (!file.rename(tmp, path)) stop("could not atomically write gate artifact", call. = FALSE)
  invisible(path)
}

.spde_slope_gauge_nofit_materializer_atomic_text <- function(lines, path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || file.exists(path) ||
      (!is.na(Sys.readlink(path)) && nzchar(Sys.readlink(path)))) {
    stop("gate text target is not a fresh regular path", call. = FALSE)
  }
  tmp <- tempfile(".spde-slope-gauge-gate-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  writeLines(lines, tmp, useBytes = TRUE)
  if (!file.rename(tmp, path)) stop("could not atomically write gate text", call. = FALSE)
  invisible(path)
}

.spde_slope_gauge_nofit_materializer_sources <- function() {
  locked <- spde_slope_gauge_nofit_locked_predecessor()
  paths <- c(
    child_runner = file.path(script_dir, "run-paper1-spde-slope-gauge-nofit.R"),
    pure_contract = file.path(script_dir, "spde-slope-gauge-contract.R"),
    nofit_contract = file.path(script_dir, "spde-slope-gauge-nofit-contract.R"),
    historical_contract = locked$historical_contract_path,
    design = file.path(script_dir, "2026-08-15-paper1-spde-slope-gauge-coordinate-design.md"),
    materializer = script_path
  )
  if (!all(vapply(paths, .spde_slope_gauge_nofit_regular_file, logical(1L)))) {
    stop("one or more no-fit gate sources are unavailable", call. = FALSE)
  }
  if (!identical(unname(tools::md5sum(paths[["historical_contract"]]))[[1L]],
    locked$historical_contract_md5)) {
    stop("historical MSPDE V3 validator bytes are not frozen", call. = FALSE)
  }
  paths
}

.spde_slope_gauge_nofit_materializer_commit <- function() {
  value <- tryCatch(system2("git", c("-C", dirname(dirname(script_dir)), "rev-parse", "HEAD"),
    stdout = TRUE, stderr = FALSE), error = function(e) character())
  if (!is.character(value) || length(value) != 1L ||
      !grepl("^[[:xdigit:]]{40}$", value)) stop("could not read source commit", call. = FALSE)
  dirty <- tryCatch(system2("git", c("-C", dirname(dirname(script_dir)), "status", "--porcelain"),
    stdout = TRUE, stderr = FALSE), error = function(e) "DIRTY")
  if (length(dirty)) stop("no-fit gate requires a clean committed tree", call. = FALSE)
  value[[1L]]
}

.spde_slope_gauge_nofit_materializer_stage_token <- function(stage, parent_pid) {
  list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1_PARENT_STAGE_V1",
    gate_base = normalizePath(dirname(stage), mustWork = TRUE),
    stage = normalizePath(stage, mustWork = TRUE),
    parent_pid = as.integer(parent_pid),
    child_output = file.path(normalizePath(stage, mustWork = TRUE), "child-result.rds")
  )
}

.spde_slope_gauge_nofit_materializer_manifest <- function(root, files) {
  declared <- setdiff(files, "file-manifest.csv")
  table <- data.frame(path = declared, md5 = unname(tools::md5sum(file.path(root, declared))),
    stringsAsFactors = FALSE)
  tmp <- tempfile(".spde-slope-gauge-manifest-", tmpdir = root)
  on.exit(unlink(tmp), add = TRUE)
  utils::write.csv(table, tmp, row.names = FALSE, quote = TRUE)
  if (!file.rename(tmp, file.path(root, "file-manifest.csv"))) {
    stop("could not atomically materialize gate manifest", call. = FALSE)
  }
  invisible(table)
}

.spde_slope_gauge_nofit_materializer_process <- function(
    command, arguments, parent_pid, started, ended, status, timed_out, stdout_path, stderr_path, child) {
  list(
    schema = .spde_slope_gauge_nofit_process_schema(), command = command, arguments = arguments,
    parent_pid = as.integer(parent_pid),
    child_pid = if (is.list(child) && is.integer(child$child_pid) && length(child$child_pid) == 1L)
      child$child_pid else NA_integer_,
    started_at = format(started, tz = "UTC", usetz = TRUE), ended_at = format(ended, tz = "UTC", usetz = TRUE),
    elapsed_s = as.double(difftime(ended, started, units = "secs")), deadline_s = 1800,
    timed_out = isTRUE(timed_out),
    exit_status = if (is.null(status)) 0L else as.integer(status), signal = NA_character_,
    stdout_md5 = unname(tools::md5sum(stdout_path))[[1L]],
    stderr_md5 = unname(tools::md5sum(stderr_path))[[1L]],
    child_result_md5 = if (is.list(child)) NA_character_ else NA_character_
  )
}

.spde_slope_gauge_nofit_materializer_child <- function(stage, parent_pid, run_fun = NULL) {
  runner <- file.path(script_dir, "run-paper1-spde-slope-gauge-nofit.R")
  output <- file.path(stage, "child-result.rds")
  stdout <- file.path(stage, ".child-stdout.txt")
  stderr <- file.path(stage, ".child-stderr.txt")
  if (is.null(run_fun)) {
    if (!requireNamespace("processx", quietly = TRUE)) {
      stop("processx is required to enforce the no-fit child deadline", call. = FALSE)
    }
    run_fun <- processx::run
  }
  command <- R.home("bin/Rscript")
  arguments <- c("--vanilla", runner, "child", output, as.character(parent_pid))
  started <- Sys.time()
  run <- tryCatch(run_fun(command, arguments, timeout = 1800 * 1000,
    error_on_status = FALSE, echo = FALSE), error = function(e) list(
      status = NA_integer_, stdout = "", stderr = conditionMessage(e),
      timed_out = grepl("timeout|time limit", conditionMessage(e), ignore.case = TRUE)
    ))
  ended <- Sys.time()
  stdout_text <- if (is.character(run$stdout) && length(run$stdout) == 1L) run$stdout else ""
  stderr_text <- if (is.character(run$stderr) && length(run$stderr) == 1L) run$stderr else ""
  writeLines(stdout_text, stdout, useBytes = TRUE)
  writeLines(stderr_text, stderr, useBytes = TRUE)
  status <- if (is.numeric(run$status) && length(run$status) == 1L && !is.na(run$status)) {
    as.integer(run$status)
  } else NA_integer_
  timed_out <- isTRUE(run$timed_out) || (!is.finite(as.double(status)) &&
    grepl("timeout|time limit", stderr_text, ignore.case = TRUE))
  child <- if (identical(status, 0L) && !timed_out && .spde_slope_gauge_nofit_regular_file(output)) {
    tryCatch(readRDS(output), error = function(e) NULL)
  } else NULL
  if (!is.list(child)) child <- NULL
  output_link <- Sys.readlink(output)
  if (is.null(child) && (file.exists(output) || (!is.na(output_link) && nzchar(output_link)))) {
    if (unlink(output) != 0L) stop("could not discard unreadable child output", call. = FALSE)
  }
  process <- .spde_slope_gauge_nofit_materializer_process(
    command, arguments, parent_pid, started, ended, status, timed_out, stdout, stderr, child
  )
  if (is.list(child)) {
    process$child_result_md5 <- unname(tools::md5sum(output))[[1L]]
  }
  unlink(c(stdout, stderr))
  list(process = process, child = child, output = output)
}

.spde_slope_gauge_nofit_materializer_seal <- function(
    stage, root, sources, commit, predecessor, parent_stage, child_run) {
  staged_token <- tryCatch(readRDS(file.path(stage, ".parent-stage.rds")), error = function(e) NULL)
  if (!identical(staged_token, parent_stage)) {
    stop("parent stage token is not intact before sealing", call. = FALSE)
  }
  child <- child_run$child
  has_child <- is.list(child)
  if (has_child) {
    if (!file.rename(child_run$output, file.path(stage, "no-fit-result.rds"))) {
      stop("could not atomically retain child no-fit result", call. = FALSE)
    }
    child_run$process$child_result_md5 <- unname(tools::md5sum(
      file.path(stage, "no-fit-result.rds")
    ))[[1L]]
  }
  unlink(file.path(stage, ".parent-stage.rds"))
  .spde_slope_gauge_nofit_materializer_atomic_rds(child_run$process,
    file.path(stage, "child-receipt.rds"))
  if (!file.copy(sources[["materializer"]], file.path(stage, "materializer.R"), copy.date = TRUE) ||
      !identical(Sys.readlink(file.path(stage, "materializer.R")), "")) {
    stop("could not retain materializer source", call. = FALSE)
  }
  .spde_slope_gauge_nofit_materializer_atomic_rds(utils::sessionInfo(), file.path(stage, "session-info.rds"))
  .spde_slope_gauge_nofit_materializer_atomic_text(c(
    "# SPDE-slope gauge no-fit gate time estimate", "Expected wall time: 3-10 minutes.",
    "Hard child deadline: 30 minutes.", "This is not a numerical-admission or ecological result."
  ), file.path(stage, "time-estimate.md"))
  observed_dll <- if (has_child && is.list(child$dll) &&
      identical(names(child$dll), c("path", "md5"))) child$dll else list(
        path = NA_character_, md5 = NA_character_
      )
  child_evidence_valid <- has_child && isTRUE(.spde_slope_gauge_nofit_child_ok(
    child, predecessor, observed_dll, state = predecessor$state
  ))
  child_status <- if (!has_child) {
    "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
  } else if (child_evidence_valid) {
    child$status
  } else {
    "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
  }
  child_reason <- if (!has_child) "child_process_no_result" else if (child_evidence_valid) {
    child$reason
  } else "child_evidence_invalid"
  dll <- if (child_evidence_valid) observed_dll else list(path = NA_character_, md5 = NA_character_)
  root_receipt <- list(
    schema = .spde_slope_gauge_nofit_gate_schema(), gate = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1",
    root = root, commit = commit, status = child_status, reason = child_reason,
    predecessor = predecessor[c("receipt", "state_md5")],
    sources = stats::setNames(unname(tools::md5sum(sources)), names(sources)), dll = dll,
    controls = spde_slope_gauge_no_fit_controls(), parent_stage = parent_stage, process = child_run$process,
    child_result_md5 = if (has_child) child_run$process$child_result_md5 else NA_character_,
    time_estimate_md5 = unname(tools::md5sum(file.path(stage, "time-estimate.md")))[[1L]]
  )
  .spde_slope_gauge_nofit_materializer_atomic_rds(root_receipt, file.path(stage, "root-receipt.rds"))
  dir.create(file.path(stage, ".attempt-started.claim"), showWarnings = FALSE)
  if (!isTRUE(file.info(file.path(stage, ".attempt-started.claim"))$isdir[[1L]]) ||
      !identical(Sys.readlink(file.path(stage, ".attempt-started.claim")), "")) {
    stop("could not materialize no-fit gate claim directory", call. = FALSE)
  }
  files <- .spde_slope_gauge_nofit_gate_files(has_child)
  .spde_slope_gauge_nofit_materializer_manifest(stage, files)
  if (!file.rename(stage, root)) stop("could not atomically seal no-fit gate root", call. = FALSE)
  stage <- NA_character_
  verdict <- spde_slope_gauge_nofit_validate_gate_root(root, sources, commit = commit)
  if (!isTRUE(verdict$valid)) stop(verdict$reason, call. = FALSE)
  cat(root_receipt$status, "\n", sep = "")
  invisible(verdict)
}

spde_slope_gauge_nofit_materialize_gate <- function() {
  if (!requireNamespace("processx", quietly = TRUE)) {
    stop("processx is required to enforce the no-fit child deadline", call. = FALSE)
  }
  sources <- .spde_slope_gauge_nofit_materializer_sources()
  commit <- .spde_slope_gauge_nofit_materializer_commit()
  predecessor <- spde_slope_gauge_nofit_validate_predecessor_bytes()
  if (!isTRUE(predecessor$valid)) stop(predecessor$reason, call. = FALSE)
  base <- file.path(script_dir, "results")
  if (!dir.exists(base)) dir.create(base, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(base) || !identical(Sys.readlink(base), "")) stop("gate base is invalid", call. = FALSE)
  root <- file.path(base, "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1")
  if (file.exists(root) || !is.na(Sys.readlink(root))) stop("no-fit gate root is already consumed", call. = FALSE)
  stage <- tempfile(".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1-", tmpdir = base)
  if (!dir.create(stage, recursive = FALSE, showWarnings = FALSE)) stop("could not create gate staging root", call. = FALSE)
  stage <- normalizePath(stage, mustWork = TRUE)
  on.exit({
    if (is.character(stage) && length(stage) == 1L && !is.na(stage) && dir.exists(stage)) {
      unlink(stage, recursive = TRUE)
    }
  }, add = TRUE)
  parent_pid <- as.integer(Sys.getpid())
  parent_stage <- .spde_slope_gauge_nofit_materializer_stage_token(stage, parent_pid)
  .spde_slope_gauge_nofit_materializer_atomic_rds(parent_stage,
    file.path(stage, ".parent-stage.rds"))
  child_run <- .spde_slope_gauge_nofit_materializer_child(stage, parent_pid)
  verdict <- .spde_slope_gauge_nofit_materializer_seal(
    stage, root, sources, commit, predecessor, parent_stage, child_run
  )
  stage <- NA_character_
  invisible(verdict)
}

if (length(args) == 1L && identical(args[[1L]], "materialize")) {
  spde_slope_gauge_nofit_materialize_gate()
  quit(status = 0L)
}

stop("usage: materialize-paper1-spde-slope-gauge-nofit-gate.R materialize", call. = FALSE)
