#!/usr/bin/env Rscript
## Parent preflight materializer for PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1.
##
## It creates the unconsumed no-build packet and, once the source gate is
## committed and independently reviewed, can run its separately authorised
## one-shot claim/child/seal path.

args <- commandArgs(trailingOnly = TRUE)
source_only <- identical(Sys.getenv("SPDE_SLOPE_GAUGE_TR_MATERIALIZER_SOURCE_ONLY"), "1")
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
if (!source_only && length(file_arg) != 1L) {
  stop("trust-region materializer must be invoked by Rscript --file", call. = FALSE)
}
script_path <- if (source_only) {
  Sys.getenv("SPDE_SLOPE_GAUGE_TR_MATERIALIZER_PATH")
} else {
  sub("^--file=", "", file_arg)
}
if (!is.character(script_path) || length(script_path) != 1L || !nzchar(script_path)) {
  stop("trust-region materializer path is missing", call. = FALSE)
}
script_path <- normalizePath(script_path, mustWork = TRUE)
script_dir <- dirname(script_path)
source(file.path(script_dir, "spde-slope-gauge-contract.R"), local = TRUE)
source(file.path(script_dir, "spde-slope-gauge-trust-region-contract.R"), local = TRUE)
source(file.path(script_dir, "spde-slope-gauge-trust-region-smoke-contract.R"), local = TRUE)

.spde_slope_gauge_tr_materializer_fail <- function(message) stop(message, call. = FALSE)

.spde_slope_gauge_tr_materializer_root <- function() {
  normalizePath(file.path(script_dir, "results", "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1"),
    mustWork = FALSE)
}

.spde_slope_gauge_tr_materializer_files <- function() {
  c(
    "control.rds", "file-manifest.csv", "materializer.R", "predecessor-v3-ledger.rds",
    "predecessor-v3-marker.rds", "predecessor-v3-receipt.rds", "root-receipt.rds",
    "session-info.rds", "time-estimate.md", "v3-materialized-state.rds"
  )
}

.spde_slope_gauge_tr_materializer_terminal_files <- function(ledger) {
  base <- .spde_slope_gauge_tr_materializer_files()
  extra <- "all-attempt-ledger.rds"
  if (is.list(ledger$marker)) extra <- c(extra, "attempt-started.rds")
  if (is.list(ledger$v3_live_child)) extra <- c(extra, "v3-live-child.rds")
  if (is.list(ledger$worker)) extra <- c(extra, "worker-result.rds")
  unique(c(base, extra))
}

.spde_slope_gauge_tr_materializer_marker_ok <- function(marker, receipt, root, commit) {
  fields <- c("schema", "gate", "root", "commit", "parent_pid", "receipt_md5", "started_at")
  .spde_slope_gauge_tr_smoke_exact_names(marker, fields) &&
    identical(marker$schema, "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_ATTEMPT_STARTED_V1") &&
    identical(marker$gate, "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1") &&
    identical(marker$root, root) && identical(marker$commit, commit) &&
    .spde_slope_gauge_tr_smoke_pid(marker$parent_pid) &&
    identical(marker$receipt_md5, unname(tools::md5sum(file.path(root, "root-receipt.rds")))[[1L]]) &&
    is.character(marker$started_at) && length(marker$started_at) == 1L &&
    !is.na(marker$started_at) && nzchar(marker$started_at) && identical(receipt$root, root)
}

.spde_slope_gauge_tr_materializer_expected_dll <- function(locked) {
  path <- file.path(dirname(dirname(dirname(dirname(locked$root)))), "src", "gllvmTMB.so")
  if (!.spde_slope_gauge_tr_smoke_regular_file(path)) return(NULL)
  list(path = normalizePath(path, mustWork = TRUE), md5 = unname(tools::md5sum(path))[[1L]])
}

.spde_slope_gauge_tr_materializer_process_for_child_ok <- function(
  process,
  child,
  runner,
  mode,
  result_path,
  parent_pid
) {
  arguments <- process$arguments
  is.list(child) && is.character(arguments) && length(arguments) == 5L &&
    identical(arguments[[1L]], "--vanilla") && identical(arguments[[2L]], runner) &&
    identical(arguments[[3L]], mode) && identical(basename(arguments[[4L]]), basename(result_path)) &&
    identical(arguments[[5L]], as.character(parent_pid)) &&
    identical(basename(process$command), "Rscript") &&
    isTRUE(spde_slope_gauge_trust_region_validate_process_receipt(
      process, process$command, arguments, parent_pid, child$child_pid
    )) && identical(process$exit_status, 0L) &&
    identical(process$child_result_md5, unname(tools::md5sum(result_path))[[1L]])
}

.spde_slope_gauge_tr_materializer_process_no_result_ok <- function(
  process,
  runner,
  mode,
  output,
  parent_pid
) {
  fields <- c(
    "schema", "command", "arguments", "parent_pid", "child_pid", "started_at", "ended_at",
    "elapsed_s", "deadline_s", "timed_out", "exit_status", "signal", "error"
  )
  pid_or_na <- function(x) is.integer(x) && length(x) == 1L && (is.na(x) || x > 0L)
  exit_or_na <- function(x) is.integer(x) && length(x) == 1L && (is.na(x) || x >= 0L)
  .spde_slope_gauge_tr_smoke_exact_names(process, fields) &&
    identical(process$schema, "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PROCESS_NO_RESULT_V1") &&
    identical(basename(process$command), "Rscript") && is.character(process$arguments) &&
    length(process$arguments) == 5L && identical(process$arguments[[1L]], "--vanilla") &&
    identical(process$arguments[[2L]], runner) && identical(process$arguments[[3L]], mode) &&
    identical(basename(process$arguments[[4L]]), output) &&
    identical(process$arguments[[5L]], as.character(parent_pid)) &&
    identical(process$parent_pid, parent_pid) && pid_or_na(process$child_pid) &&
    is.character(process$started_at) && length(process$started_at) == 1L && nzchar(process$started_at) &&
    is.character(process$ended_at) && length(process$ended_at) == 1L && nzchar(process$ended_at) &&
    is.double(process$elapsed_s) && length(process$elapsed_s) == 1L &&
    is.finite(process$elapsed_s) && process$elapsed_s >= 0 &&
    is.integer(process$deadline_s) && identical(process$deadline_s, 1800L) &&
    is.logical(process$timed_out) && length(process$timed_out) == 1L && !is.na(process$timed_out) &&
    exit_or_na(process$exit_status) && is.character(process$signal) && length(process$signal) == 1L &&
    (is.na(process$signal) || nzchar(process$signal)) && is.character(process$error) &&
    length(process$error) == 1L && !is.na(process$error) && nzchar(process$error) &&
    if (isTRUE(process$timed_out)) is.na(process$exit_status) else TRUE
}

.spde_slope_gauge_tr_materializer_no_result_process <- function(
  launch,
  command,
  arguments,
  parent_pid
) {
  fields <- c("exit_status", "child_pid", "timed_out", "error", "started_at", "ended_at", "elapsed_s")
  if (!is.list(launch) || !all(fields %in% names(launch))) {
    .spde_slope_gauge_tr_materializer_fail("child launch outcome is malformed")
  }
  list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PROCESS_NO_RESULT_V1",
    command = command, arguments = arguments, parent_pid = parent_pid,
    child_pid = launch$child_pid, started_at = launch$started_at, ended_at = launch$ended_at,
    elapsed_s = launch$elapsed_s, deadline_s = 1800L, timed_out = launch$timed_out,
    exit_status = launch$exit_status, signal = NA_character_, error = launch$error
  )
}

.spde_slope_gauge_tr_materializer_success_process <- function(
  launch,
  command,
  arguments,
  parent_pid,
  child,
  retained_result_path
) {
  fields <- c("exit_status", "child_pid", "timed_out", "error", "started_at", "ended_at", "elapsed_s")
  if (!is.list(launch) || !all(fields %in% names(launch)) || !is.list(child) ||
      !.spde_slope_gauge_tr_smoke_regular_file(retained_result_path) ||
      !identical(launch$exit_status, 0L) || isTRUE(launch$timed_out) ||
      !identical(launch$error, NA_character_) || !identical(launch$child_pid, child$child_pid)) {
    .spde_slope_gauge_tr_materializer_fail("successful child process evidence is inconsistent")
  }
  list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PROCESS_V1",
    command = command, arguments = arguments, parent_pid = parent_pid,
    child_pid = child$child_pid, started_at = launch$started_at, ended_at = launch$ended_at,
    elapsed_s = launch$elapsed_s, deadline_s = 1800L, timed_out = FALSE,
    exit_status = 0L, signal = NA_character_, stdout_md5 = NA_character_, stderr_md5 = NA_character_,
    child_result_md5 = unname(tools::md5sum(retained_result_path))[[1L]]
  )
}

.spde_slope_gauge_tr_materializer_rscript <- function() {
  path <- file.path(R.home("bin"), "Rscript")
  if (!.spde_slope_gauge_tr_smoke_regular_file(path)) {
    .spde_slope_gauge_tr_materializer_fail("Rscript executable is unavailable")
  }
  normalizePath(path, mustWork = TRUE)
}

.spde_slope_gauge_tr_materializer_launch_child <- function(command, arguments, deadline_s = 1800L) {
  if (!is.character(command) || length(command) != 1L || is.na(command) || !nzchar(command) ||
      !is.character(arguments) || anyNA(arguments) || !is.integer(deadline_s) ||
      length(deadline_s) != 1L || is.na(deadline_s) || deadline_s < 1L) {
    .spde_slope_gauge_tr_materializer_fail("isolated child launch inputs are invalid")
  }
  if (!requireNamespace("processx", quietly = TRUE)) {
    .spde_slope_gauge_tr_materializer_fail("processx is required for the isolated child deadline")
  }
  started <- Sys.time()
  run <- tryCatch(processx::process$new(
    ## The isolated Rscript is the only process we launch.  We terminate that
    ## direct child on deadline below; process-tree cleanup is deliberately not
    ## delegated to platform-specific process enumeration.
    command, arguments, stdout = "|", stderr = "|", cleanup_tree = FALSE
  ), error = function(e) e)
  if (!inherits(run, "error")) {
    run$wait(as.double(deadline_s) * 1000)
  }
  if (inherits(run, "error")) {
    ended <- Sys.time()
    message <- conditionMessage(run)
    return(list(
      exit_status = NA_integer_,
      child_pid = NA_integer_,
      timed_out = grepl("timeout|time limit", message, ignore.case = TRUE),
      stdout = NA_character_, stderr = NA_character_, error = message,
      started_at = format(started, tz = "UTC", usetz = TRUE),
      ended_at = format(ended, tz = "UTC", usetz = TRUE),
      elapsed_s = as.double(difftime(ended, started, units = "secs"))
    ))
  }
  timed_out <- isTRUE(run$is_alive())
  if (timed_out) {
    killed <- tryCatch({
      run$kill()
      TRUE
    }, error = function(e) FALSE)
    if (!isTRUE(killed) && isTRUE(run$is_alive())) {
      killed <- tryCatch({
        run$kill_tree()
        TRUE
      }, error = function(e) FALSE)
    }
    if (!isTRUE(killed) && isTRUE(run$is_alive())) {
      ended <- Sys.time()
      return(list(
        exit_status = NA_integer_, child_pid = as.integer(run$get_pid()), timed_out = TRUE,
        stdout = NA_character_, stderr = NA_character_,
        error = "parent child deadline exceeded and child termination failed",
        started_at = format(started, tz = "UTC", usetz = TRUE),
        ended_at = format(ended, tz = "UTC", usetz = TRUE),
        elapsed_s = as.double(difftime(ended, started, units = "secs"))
      ))
    }
  }
  run$wait(1000)
  ended <- Sys.time()
  stdout <- tryCatch(as.character(run$read_all_output()), error = function(e) NA_character_)
  stderr <- tryCatch(as.character(run$read_all_error()), error = function(e) NA_character_)
  list(
    exit_status = if (timed_out) NA_integer_ else as.integer(run$get_exit_status()),
    child_pid = as.integer(run$get_pid()), timed_out = timed_out,
    stdout = stdout, stderr = stderr,
    error = if (timed_out) "parent child deadline exceeded" else NA_character_,
    started_at = format(started, tz = "UTC", usetz = TRUE),
    ended_at = format(ended, tz = "UTC", usetz = TRUE),
    elapsed_s = as.double(difftime(ended, started, units = "secs"))
  )
}

.spde_slope_gauge_tr_materializer_parent_stage <- function(base, parent_pid) {
  normal_base <- tryCatch(normalizePath(base, mustWork = TRUE), error = function(e) NA_character_)
  if (is.na(normal_base) || !.spde_slope_gauge_tr_smoke_pid(parent_pid)) {
    .spde_slope_gauge_tr_materializer_fail("parent child stage inputs are invalid")
  }
  stage <- tempfile(".PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1-", tmpdir = normal_base)
  if (!dir.create(stage)) .spde_slope_gauge_tr_materializer_fail("could not create parent child stage")
  stage <- normalizePath(stage, mustWork = TRUE)
  token <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PARENT_STAGE_V1",
    gate_base = dirname(stage), stage = stage, parent_pid = parent_pid,
    v3_live_output = file.path(stage, "v3-live-child.rds"),
    worker_output = file.path(stage, "worker-result.rds")
  )
  .spde_slope_gauge_tr_materializer_atomic_rds(token, file.path(stage, ".parent-stage.rds"))
  list(stage = stage, token = token)
}

.spde_slope_gauge_tr_materializer_run_staged_child <- function(
  token,
  runner,
  mode,
  launch = .spde_slope_gauge_tr_materializer_launch_child
) {
  if (!.spde_slope_gauge_tr_smoke_exact_names(
    token, c("schema", "gate_base", "stage", "parent_pid", "v3_live_output", "worker_output")
  ) || !.spde_slope_gauge_tr_smoke_regular_file(file.path(token$stage, ".parent-stage.rds")) ||
      !is.character(runner) || length(runner) != 1L || !nzchar(runner) || !is.function(launch)) {
    .spde_slope_gauge_tr_materializer_fail("parent child stage token or runner is invalid")
  }
  output <- switch(mode,
    "v3-live-child" = token$v3_live_output,
    "worker-child" = token$worker_output,
    .spde_slope_gauge_tr_materializer_fail("parent child mode is invalid")
  )
  command <- .spde_slope_gauge_tr_materializer_rscript()
  arguments <- c("--vanilla", runner, mode, output, as.character(token$parent_pid))
  launch_outcome <- launch(command, arguments, 1800L)
  list(
    command = command, arguments = arguments, output = output,
    launch = launch_outcome,
    child = if (.spde_slope_gauge_tr_smoke_regular_file(output)) {
      tryCatch(readRDS(output), error = function(e) NULL)
    } else {
      NULL
    }
  )
}

spde_slope_gauge_trust_region_terminal_from_worker <- function(
  root,
  commit,
  receipt,
  marker,
  v3_live_child,
  controls,
  timing,
  processes = list(v3_live = NULL, worker = NULL),
  worker = NULL,
  fallback_reason = "worker_process_no_result",
  fallback_error = "the isolated worker returned no retained receipt"
) {
  checks <- spde_slope_gauge_trust_region_checks()
  if (is.null(worker)) {
    return(list(
      schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_ALL_ATTEMPT_V1",
      gate = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1", root = root, commit = commit,
      terminal = TRUE, receipt = receipt, marker = marker, worker = NULL,
      v3_live_child = v3_live_child, processes = processes,
      predecessor = receipt$predecessor, controls = controls,
      trust_region = NULL,
      checks = stats::setNames(c(TRUE, FALSE, FALSE, FALSE), checks),
      status = "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD", reason = fallback_reason,
      error = fallback_error, timing = timing
    ))
  }
  worker_status <- if (is.character(worker$status) && length(worker$status) == 1L) {
    worker$status
  } else {
    "GAUGE_TRUST_REGION_TERMINAL_EVIDENCE_HOLD"
  }
  worker_reason <- if (is.character(worker$reason) && length(worker$reason) == 1L) {
    worker$reason
  } else {
    "terminal_evidence_inconsistent"
  }
  worker_error <- if (is.character(worker$error) && length(worker$error) == 1L) {
    worker$error
  } else {
    "worker receipt has no scalar error field"
  }
  ledger <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_ALL_ATTEMPT_V1",
    gate = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1", root = root, commit = commit,
    terminal = TRUE, receipt = receipt, marker = marker, worker = worker,
    v3_live_child = v3_live_child, processes = processes,
    predecessor = receipt$predecessor, controls = controls,
    trust_region = worker$trust_region,
    checks = stats::setNames(c(
      TRUE,
      !identical(worker_status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD"),
      identical(worker_status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION"), FALSE
    ), checks),
    status = worker_status, reason = worker_reason, error = worker_error, timing = timing
  )
  normal_root <- tryCatch(normalizePath(root, mustWork = TRUE), error = function(e) NA_character_)
  state <- if (is.na(normal_root)) NULL else tryCatch(
    readRDS(file.path(normal_root, "v3-materialized-state.rds")), error = function(e) NULL
  )
  evidence <- spde_slope_gauge_trust_region_validate_terminal_evidence(ledger, state = state)
  if (isTRUE(evidence$valid)) return(ledger)
  ledger["checks"] <- list(stats::setNames(c(TRUE, FALSE, FALSE, FALSE), checks))
  ledger["status"] <- list(spde_slope_gauge_trust_region_terminal_evidence_hold())
  ledger["reason"] <- list("terminal_evidence_inconsistent")
  ledger["error"] <- list(paste0("terminal evidence: ", evidence$reason))
  ledger
}

.spde_slope_gauge_tr_materializer_sources <- function() {
  locked <- spde_slope_gauge_trust_region_locked_predecessor()
  paths <- c(
    runner = file.path(script_dir, "run-paper1-spde-slope-gauge-trust-region.R"),
    gauge_contract = file.path(script_dir, "spde-slope-gauge-contract.R"),
    sign_contract = file.path(script_dir, "spde-slope-gauge-sign-contract.R"),
    trust_contract = file.path(script_dir, "spde-slope-gauge-trust-region-contract.R"),
    adapter = file.path(script_dir, "spde-slope-gauge-trust-region-adapter.R"),
    smoke_contract = file.path(script_dir, "spde-slope-gauge-trust-region-smoke-contract.R"),
    design = file.path(script_dir, "2026-08-15-paper1-spde-slope-gauge-trust-region-execution-design.md"),
    materializer = script_path,
    historical_contract = locked$historical_contract_path
  )
  if (!all(vapply(paths, .spde_slope_gauge_tr_smoke_regular_file, logical(1L))) ||
      !identical(
        unname(tools::md5sum(paths[["historical_contract"]]))[[1L]],
        locked$historical_contract_md5
      )) {
    .spde_slope_gauge_tr_materializer_fail("trust-region sources or historical validator are unavailable")
  }
  paths
}

.spde_slope_gauge_tr_materializer_commit <- function() {
  repo <- dirname(dirname(script_dir))
  commit <- tryCatch(system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(e) character())
  dirty <- tryCatch(system2("git", c("-C", repo, "status", "--porcelain"), stdout = TRUE, stderr = FALSE),
    error = function(e) "DIRTY")
  if (!is.character(commit) || length(commit) != 1L || !grepl("^[[:xdigit:]]{40}$", commit) || length(dirty)) {
    .spde_slope_gauge_tr_materializer_fail("preflight requires a clean committed tree")
  }
  commit
}

.spde_slope_gauge_tr_materializer_atomic_rds <- function(x, path) {
  if (file.exists(path) || (!is.na(Sys.readlink(path)) && nzchar(Sys.readlink(path)))) {
    .spde_slope_gauge_tr_materializer_fail("artifact target is not fresh")
  }
  tmp <- tempfile(".spde-slope-gauge-tr-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, version = 3)
  if (!file.rename(tmp, path)) .spde_slope_gauge_tr_materializer_fail("could not atomically write artifact")
  invisible(path)
}

.spde_slope_gauge_tr_materializer_atomic_text <- function(lines, path) {
  if (file.exists(path) || (!is.na(Sys.readlink(path)) && nzchar(Sys.readlink(path)))) {
    .spde_slope_gauge_tr_materializer_fail("text target is not fresh")
  }
  tmp <- tempfile(".spde-slope-gauge-tr-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  writeLines(lines, tmp, useBytes = TRUE)
  if (!file.rename(tmp, path)) .spde_slope_gauge_tr_materializer_fail("could not atomically write text")
  invisible(path)
}

.spde_slope_gauge_tr_materializer_atomic_copy <- function(source, path) {
  if (!.spde_slope_gauge_tr_smoke_regular_file(source) || file.exists(path) ||
      (!is.na(Sys.readlink(path)) && nzchar(Sys.readlink(path)))) {
    .spde_slope_gauge_tr_materializer_fail("copy source or target is invalid")
  }
  tmp <- tempfile(".spde-slope-gauge-tr-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  if (!file.copy(source, tmp, copy.date = TRUE) || !file.rename(tmp, path)) {
    .spde_slope_gauge_tr_materializer_fail("could not atomically copy artifact")
  }
  invisible(path)
}

.spde_slope_gauge_tr_materializer_manifest <- function(root, files) {
  declared <- setdiff(files, "file-manifest.csv")
  table <- data.frame(path = declared, md5 = unname(tools::md5sum(file.path(root, declared))),
    stringsAsFactors = FALSE)
  path <- file.path(root, "file-manifest.csv")
  tmp <- tempfile(".spde-slope-gauge-tr-manifest-", tmpdir = root)
  on.exit(unlink(tmp), add = TRUE)
  utils::write.csv(table, tmp, row.names = FALSE, quote = TRUE)
  if (file.exists(path) || (!is.na(Sys.readlink(path)) && nzchar(Sys.readlink(path))) || !file.rename(tmp, path)) {
    .spde_slope_gauge_tr_materializer_fail("could not atomically write preflight manifest")
  }
  invisible(table)
}

 .spde_slope_gauge_tr_materializer_preflight_bindings_ok <- function(
  root,
  source_paths,
  commit,
  expected_root = .spde_slope_gauge_tr_materializer_root(),
  locked = spde_slope_gauge_trust_region_locked_predecessor()
) {
  normal_root <- tryCatch(normalizePath(root, mustWork = TRUE), error = function(e) NA_character_)
  canonical_root <- normalizePath(expected_root, mustWork = FALSE)
  if (is.na(normal_root) || !is.character(source_paths) ||
      !all(vapply(source_paths, .spde_slope_gauge_tr_smoke_regular_file, logical(1L))) ||
      !is.character(commit) || length(commit) != 1L || !grepl("^[[:xdigit:]]{40}$", commit)) {
    return(list(valid = FALSE, reason = "preflight_receipt_or_predecessor_invalid"))
  }
  predecessor <- spde_slope_gauge_trust_region_validate_predecessor_bytes(locked$root, locked)
  receipt <- tryCatch(readRDS(file.path(normal_root, "root-receipt.rds")), error = function(e) NULL)
  controls <- tryCatch(readRDS(file.path(normal_root, "control.rds")), error = function(e) NULL)
  expected_sources <- stats::setNames(unname(tools::md5sum(source_paths)), names(source_paths))
  fields <- c("schema", "gate", "root", "commit", "sources", "predecessor", "control_md5", "state_md5",
    "session_info_md5", "time_estimate_md5")
  copies <- c(
    "predecessor-v3-ledger.rds" = "all-attempt-ledger.rds",
    "predecessor-v3-marker.rds" = "attempt-started.rds",
    "predecessor-v3-receipt.rds" = "root-receipt.rds",
    "v3-materialized-state.rds" = "v2-materialized-state.rds"
  )
  copies_ok <- all(vapply(names(copies), function(name) identical(
    unname(tools::md5sum(file.path(normal_root, name)))[[1L]], locked$files[[copies[[name]]]]
  ), logical(1L)))
  receipt_ok <- .spde_slope_gauge_tr_smoke_exact_names(receipt, fields) &&
    identical(receipt$schema, "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PREFLIGHT_V1") &&
    identical(receipt$gate, "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1") &&
    identical(receipt$root, canonical_root) && identical(receipt$commit, commit) &&
    identical(receipt$sources, expected_sources) &&
    identical(receipt$predecessor, predecessor[c("root", "commit", "receipt", "state_md5")]) &&
    identical(receipt$control_md5, unname(tools::md5sum(file.path(normal_root, "control.rds")))[[1L]]) &&
    identical(receipt$state_md5, locked$files[["v2-materialized-state.rds"]]) &&
    identical(receipt$session_info_md5, unname(tools::md5sum(file.path(normal_root, "session-info.rds")))[[1L]]) &&
    identical(
      receipt$time_estimate_md5,
      unname(tools::md5sum(file.path(normal_root, "time-estimate.md")))[[1L]]
    ) &&
    identical(controls, spde_slope_gauge_trust_region_controls())
  list(valid = isTRUE(predecessor$valid) && copies_ok && receipt_ok,
    reason = if (isTRUE(predecessor$valid) && copies_ok && receipt_ok) {
      "trust_region_preflight_valid"
    } else {
      "preflight_receipt_or_predecessor_invalid"
    })
}

spde_slope_gauge_trust_region_validate_preflight_packet <- function(
  root,
  source_paths,
  commit,
  expected_root = .spde_slope_gauge_tr_materializer_root(),
  locked = spde_slope_gauge_trust_region_locked_predecessor()
) {
  normal_root <- tryCatch(normalizePath(root, mustWork = TRUE), error = function(e) NA_character_)
  files <- .spde_slope_gauge_tr_materializer_files()
  if (is.na(normal_root) || !isTRUE(spde_slope_gauge_trust_region_manifest_ok(normal_root, files))) {
    return(list(valid = FALSE, reason = "preflight_packet_bytes_invalid"))
  }
  .spde_slope_gauge_tr_materializer_preflight_bindings_ok(
    normal_root, source_paths, commit, expected_root, locked
  )
}

spde_slope_gauge_trust_region_validate_terminal_packet <- function(
  root,
  source_paths,
  commit,
  expected_root = .spde_slope_gauge_tr_materializer_root(),
  locked = spde_slope_gauge_trust_region_locked_predecessor(),
  expected_dll = .spde_slope_gauge_tr_materializer_expected_dll(locked)
) {
  normal_root <- tryCatch(normalizePath(root, mustWork = TRUE), error = function(e) NA_character_)
  if (is.na(normal_root) || !.spde_slope_gauge_tr_smoke_regular_file(
    file.path(normal_root, "all-attempt-ledger.rds")
  )) {
    return(list(valid = FALSE, reason = "terminal_packet_bytes_invalid"))
  }
  ledger <- tryCatch(readRDS(file.path(normal_root, "all-attempt-ledger.rds")), error = function(e) NULL)
  terminal_shape <- spde_slope_gauge_trust_region_validate_terminal_ledger(ledger)
  if (!isTRUE(terminal_shape$valid) || !identical(ledger$root, normalizePath(expected_root, mustWork = FALSE)) ||
      !identical(ledger$commit, commit)) {
    return(list(valid = FALSE, reason = "terminal_ledger_invalid"))
  }
  files <- .spde_slope_gauge_tr_materializer_terminal_files(ledger)
  if (!isTRUE(spde_slope_gauge_trust_region_manifest_ok(
    normal_root, files, ".attempt-started.claim"
  ))) {
    return(list(valid = FALSE, reason = "terminal_packet_bytes_invalid"))
  }
  binding <- .spde_slope_gauge_tr_materializer_preflight_bindings_ok(
    normal_root, source_paths, commit, expected_root, locked
  )
  if (!isTRUE(binding$valid)) return(binding)
  receipt <- tryCatch(readRDS(file.path(normal_root, "root-receipt.rds")), error = function(e) NULL)
  controls <- tryCatch(readRDS(file.path(normal_root, "control.rds")), error = function(e) NULL)
  if (!identical(ledger$receipt, receipt) || !identical(ledger$predecessor, receipt$predecessor) ||
      !identical(ledger$controls, controls)) {
    return(list(valid = FALSE, reason = "terminal_packet_bindings_invalid"))
  }
  marker_path <- file.path(normal_root, "attempt-started.rds")
  child_path <- file.path(normal_root, "v3-live-child.rds")
  if (is.null(ledger$marker)) {
    if (file.exists(marker_path)) {
      return(list(valid = FALSE, reason = "terminal_marker_projection_invalid"))
    }
  } else {
    marker <- tryCatch(readRDS(marker_path), error = function(e) NULL)
    if (!identical(ledger$marker, marker) ||
        !isTRUE(.spde_slope_gauge_tr_materializer_marker_ok(marker, receipt, normal_root, commit))) {
      return(list(valid = FALSE, reason = "terminal_marker_projection_invalid"))
    }
  }
  if (is.null(ledger$v3_live_child)) {
    if (file.exists(child_path) || !is.null(ledger$processes$v3_live)) {
      return(list(valid = FALSE, reason = "terminal_v3_child_projection_invalid"))
    }
  } else {
    child <- tryCatch(readRDS(child_path), error = function(e) NULL)
    v3_parent_pid <- if (is.list(ledger$marker)) ledger$marker$parent_pid else child$parent_pid
    if (is.null(expected_dll) || !identical(ledger$v3_live_child, child) ||
        !isTRUE(spde_slope_gauge_trust_region_v3_live_child_ok(
          child, ledger$predecessor, expected_dll
        )) || !isTRUE(.spde_slope_gauge_tr_materializer_process_for_child_ok(
          ledger$processes$v3_live, child, source_paths[["runner"]], "v3-live-child",
          child_path, v3_parent_pid
        ))) {
      return(list(valid = FALSE, reason = "terminal_v3_child_projection_invalid"))
    }
  }
  worker_path <- file.path(normal_root, "worker-result.rds")
  if (is.null(ledger$worker)) {
    worker_process <- ledger$processes$worker
    worker_process_ok <- is.null(worker_process) || isTRUE(
      .spde_slope_gauge_tr_materializer_process_no_result_ok(
        worker_process, source_paths[["runner"]], "worker-child", "worker-result.rds",
        ledger$marker$parent_pid
      )
    )
    if (file.exists(worker_path) || !worker_process_ok ||
        (!is.null(worker_process) && !identical(ledger$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD")) ||
        !identical(ledger$reason, if (is.null(worker_process)) "parent_unwind" else "worker_process_no_result")) {
      return(list(valid = FALSE, reason = "terminal_worker_projection_invalid"))
    }
  } else {
    worker <- tryCatch(readRDS(worker_path), error = function(e) NULL)
    if (!identical(ledger$worker, worker) || !isTRUE(.spde_slope_gauge_tr_materializer_process_for_child_ok(
      ledger$processes$worker, worker, source_paths[["runner"]], "worker-child",
      worker_path, ledger$marker$parent_pid
    ))) {
      return(list(valid = FALSE, reason = "terminal_worker_projection_invalid"))
    }
  }
  state <- tryCatch(readRDS(file.path(normal_root, "v3-materialized-state.rds")), error = function(e) NULL)
  evidence <- spde_slope_gauge_trust_region_validate_terminal_evidence(ledger, state = state)
  if (!isTRUE(evidence$valid)) {
    return(list(valid = FALSE, reason = evidence$reason))
  }
  list(valid = TRUE, reason = evidence$reason)
}

.spde_slope_gauge_tr_materializer_replace_manifest <- function(root, files) {
  path <- file.path(root, "file-manifest.csv")
  if (!.spde_slope_gauge_tr_smoke_regular_file(path)) {
    .spde_slope_gauge_tr_materializer_fail("terminal manifest target is absent or invalid")
  }
  declared <- setdiff(files, "file-manifest.csv")
  table <- data.frame(
    path = declared, md5 = unname(tools::md5sum(file.path(root, declared))),
    stringsAsFactors = FALSE
  )
  tmp <- tempfile(".spde-slope-gauge-tr-terminal-manifest-", tmpdir = root)
  on.exit(unlink(tmp), add = TRUE)
  utils::write.csv(table, tmp, row.names = FALSE, quote = TRUE)
  if (!file.rename(tmp, path)) {
    .spde_slope_gauge_tr_materializer_fail("could not atomically replace terminal manifest")
  }
  invisible(table)
}

spde_slope_gauge_trust_region_seal_terminal <- function(
  root,
  ledger,
  source_paths,
  commit,
  expected_root = .spde_slope_gauge_tr_materializer_root(),
  locked = spde_slope_gauge_trust_region_locked_predecessor(),
  expected_dll = .spde_slope_gauge_tr_materializer_expected_dll(locked)
) {
  normal_root <- tryCatch(normalizePath(root, mustWork = TRUE), error = function(e) NA_character_)
  if (is.na(normal_root) || file.exists(file.path(normal_root, "all-attempt-ledger.rds"))) {
    .spde_slope_gauge_tr_materializer_fail("terminal ledger target is not fresh")
  }
  shape <- spde_slope_gauge_trust_region_validate_terminal_ledger(ledger)
  if (!isTRUE(shape$valid) || !identical(ledger$root, normalizePath(expected_root, mustWork = FALSE)) ||
      !identical(ledger$commit, commit)) {
    .spde_slope_gauge_tr_materializer_fail("terminal ledger cannot be sealed")
  }
  files <- .spde_slope_gauge_tr_materializer_terminal_files(ledger)
  .spde_slope_gauge_tr_materializer_atomic_rds(
    ledger, file.path(normal_root, "all-attempt-ledger.rds")
  )
  .spde_slope_gauge_tr_materializer_replace_manifest(normal_root, files)
  sealed <- spde_slope_gauge_trust_region_validate_terminal_packet(
    normal_root, source_paths, commit, expected_root, locked, expected_dll
  )
  if (!isTRUE(sealed$valid)) .spde_slope_gauge_tr_materializer_fail(sealed$reason)
  invisible(sealed)
}

spde_slope_gauge_trust_region_preflight <- function() {
  root <- .spde_slope_gauge_tr_materializer_root()
  base <- dirname(root)
  if (!dir.exists(base) || file.exists(root) || (!is.na(Sys.readlink(root)) && nzchar(Sys.readlink(root)))) {
    .spde_slope_gauge_tr_materializer_fail("trust-region root is already consumed or unavailable")
  }
  commit <- .spde_slope_gauge_tr_materializer_commit()
  sources <- .spde_slope_gauge_tr_materializer_sources()
  locked <- spde_slope_gauge_trust_region_locked_predecessor()
  predecessor <- spde_slope_gauge_trust_region_validate_predecessor_bytes(locked$root, locked)
  if (!isTRUE(predecessor$valid)) .spde_slope_gauge_tr_materializer_fail(predecessor$reason)
  stage <- tempfile(".PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1-", tmpdir = base)
  if (!dir.create(stage)) .spde_slope_gauge_tr_materializer_fail("could not create preflight stage")
  on.exit(if (dir.exists(stage)) unlink(stage, recursive = TRUE), add = TRUE)
  files <- .spde_slope_gauge_tr_materializer_files()
  .spde_slope_gauge_tr_materializer_atomic_rds(
    spde_slope_gauge_trust_region_controls(), file.path(stage, "control.rds")
  )
  for (pair in c(
    "predecessor-v3-ledger.rds=all-attempt-ledger.rds",
    "predecessor-v3-marker.rds=attempt-started.rds",
    "predecessor-v3-receipt.rds=root-receipt.rds",
    "v3-materialized-state.rds=v2-materialized-state.rds"
  )) {
    parts <- strsplit(pair, "=", fixed = TRUE)[[1L]]
    .spde_slope_gauge_tr_materializer_atomic_copy(
      file.path(locked$root, parts[[2L]]), file.path(stage, parts[[1L]])
    )
  }
  .spde_slope_gauge_tr_materializer_atomic_copy(sources[["materializer"]], file.path(stage, "materializer.R"))
  .spde_slope_gauge_tr_materializer_atomic_rds(utils::sessionInfo(), file.path(stage, "session-info.rds"))
  .spde_slope_gauge_tr_materializer_atomic_text(
    c("Estimated one-shot trust-region smoke: 3-10 minutes.", "Hard process deadline: 1800 seconds."),
    file.path(stage, "time-estimate.md")
  )
  receipt <- list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_PREFLIGHT_V1",
    gate = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1",
    root = root,
    commit = commit,
    sources = stats::setNames(unname(tools::md5sum(sources)), names(sources)),
    predecessor = predecessor[c("root", "commit", "receipt", "state_md5")],
    control_md5 = unname(tools::md5sum(file.path(stage, "control.rds")))[[1L]],
    state_md5 = locked$files[["v2-materialized-state.rds"]],
    session_info_md5 = unname(tools::md5sum(file.path(stage, "session-info.rds")))[[1L]],
    time_estimate_md5 = unname(tools::md5sum(file.path(stage, "time-estimate.md")))[[1L]]
  )
  .spde_slope_gauge_tr_materializer_atomic_rds(receipt, file.path(stage, "root-receipt.rds"))
  .spde_slope_gauge_tr_materializer_manifest(stage, files)
  staged <- spde_slope_gauge_trust_region_validate_preflight_packet(
    stage, sources, commit, expected_root = root, locked = locked
  )
  if (!isTRUE(staged$valid) || !file.rename(stage, root)) {
    .spde_slope_gauge_tr_materializer_fail("could not validate and promote trust-region preflight")
  }
  sealed <- spde_slope_gauge_trust_region_validate_preflight_packet(root, sources, commit, expected_root = root, locked = locked)
  if (!isTRUE(sealed$valid)) .spde_slope_gauge_tr_materializer_fail(sealed$reason)
  invisible(sealed)
}

spde_slope_gauge_trust_region_smoke <- function(
  launch = .spde_slope_gauge_tr_materializer_launch_child
) {
  root <- .spde_slope_gauge_tr_materializer_root()
  sources <- .spde_slope_gauge_tr_materializer_sources()
  commit <- .spde_slope_gauge_tr_materializer_commit()
  locked <- spde_slope_gauge_trust_region_locked_predecessor()
  expected_dll <- .spde_slope_gauge_tr_materializer_expected_dll(locked)
  preflight <- spde_slope_gauge_trust_region_validate_preflight_packet(
    root, sources, commit, expected_root = root, locked = locked
  )
  if (!isTRUE(preflight$valid) || is.null(expected_dll)) {
    .spde_slope_gauge_tr_materializer_fail(preflight$reason)
  }
  parent_pid <- as.integer(Sys.getpid())
  started <- Sys.time()
  stage <- .spde_slope_gauge_tr_materializer_parent_stage(dirname(root), parent_pid)
  on.exit(if (dir.exists(stage$stage)) unlink(stage$stage, recursive = TRUE), add = TRUE)
  v3_run <- .spde_slope_gauge_tr_materializer_run_staged_child(
    stage$token, sources[["runner"]], "v3-live-child", launch
  )
  receipt <- readRDS(file.path(root, "root-receipt.rds"))
  controls <- readRDS(file.path(root, "control.rds"))
  predecessor <- receipt$predecessor
  if (!isTRUE(spde_slope_gauge_trust_region_v3_live_child_ok(
    v3_run$child, predecessor, expected_dll
  ))) {
    .spde_slope_gauge_tr_materializer_fail("disposable V3 live-child did not return valid evidence")
  }
  claimed <- FALSE
  marker <- NULL
  v3_live_child <- NULL
  worker <- NULL
  processes <- list(v3_live = NULL, worker = NULL)
  sealed <- FALSE
  unwind_error <- "parent smoke unwound after claim"
  on.exit({
    if (isTRUE(claimed) && !isTRUE(sealed) && !file.exists(file.path(root, "all-attempt-ledger.rds"))) {
      worker_path <- file.path(root, "worker-result.rds")
      if (file.exists(worker_path)) unlink(worker_path)
      worker <- NULL
      processes$worker <- NULL
      ledger <- spde_slope_gauge_trust_region_terminal_from_worker(
        root, commit, receipt, marker, v3_live_child, controls,
        timing = list(total_s = as.double(difftime(Sys.time(), started, units = "secs")),
          predecessor_s = NA_real_, worker_s = NA_real_),
        processes = processes, worker = worker,
        fallback_reason = "parent_unwind", fallback_error = unwind_error
      )
      spde_slope_gauge_trust_region_seal_terminal(
        root, ledger, sources, commit, expected_root = root, locked = locked,
        expected_dll = expected_dll
      )
    }
  }, add = TRUE)
  claim <- file.path(root, ".attempt-started.claim")
  if (dir.exists(claim) || !isTRUE(claimed <- dir.create(claim))) {
    .spde_slope_gauge_tr_materializer_fail("trust-region root is already claimed")
  }
  completed <- tryCatch({
    .spde_slope_gauge_tr_materializer_atomic_copy(
      v3_run$output, file.path(root, "v3-live-child.rds")
    )
    v3_live_child <- readRDS(file.path(root, "v3-live-child.rds"))
    processes$v3_live <- .spde_slope_gauge_tr_materializer_success_process(
      v3_run$launch, v3_run$command, v3_run$arguments, parent_pid,
      v3_live_child, file.path(root, "v3-live-child.rds")
    )
    marker <- list(
      schema = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_ATTEMPT_STARTED_V1",
      gate = "PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1", root = root, commit = commit,
      parent_pid = parent_pid,
      receipt_md5 = unname(tools::md5sum(file.path(root, "root-receipt.rds")))[[1L]],
      started_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
    )
    .spde_slope_gauge_tr_materializer_atomic_rds(marker, file.path(root, "attempt-started.rds"))
    worker_run <- .spde_slope_gauge_tr_materializer_run_staged_child(
      stage$token, sources[["runner"]], "worker-child", launch
    )
    if (is.list(worker_run$child) && isTRUE(
      spde_slope_gauge_trust_region_worker_ok(worker_run$child, predecessor)
    )) {
      .spde_slope_gauge_tr_materializer_atomic_copy(
        worker_run$output, file.path(root, "worker-result.rds")
      )
      worker <- readRDS(file.path(root, "worker-result.rds"))
      processes$worker <- .spde_slope_gauge_tr_materializer_success_process(
        worker_run$launch, worker_run$command, worker_run$arguments, parent_pid,
        worker, file.path(root, "worker-result.rds")
      )
    } else {
      failure <- worker_run$launch
      if (is.null(failure$error) || is.na(failure$error) || !nzchar(failure$error)) {
        failure$error <- "worker child did not return a valid typed receipt"
      }
      processes$worker <- .spde_slope_gauge_tr_materializer_no_result_process(
        failure, worker_run$command, worker_run$arguments, parent_pid
      )
    }
    ledger <- spde_slope_gauge_trust_region_terminal_from_worker(
      root, commit, receipt, marker, v3_live_child, controls,
      timing = list(total_s = as.double(difftime(Sys.time(), started, units = "secs")),
        predecessor_s = NA_real_, worker_s = as.double(worker_run$launch$elapsed_s)),
      processes = processes, worker = worker,
      fallback_reason = if (is.null(worker)) "worker_process_no_result" else "parent_unwind",
      fallback_error = if (is.null(worker)) processes$worker$error else "parent smoke unwound"
    )
    sealed <- spde_slope_gauge_trust_region_seal_terminal(
      root, ledger, sources, commit, expected_root = root, locked = locked,
      expected_dll = expected_dll
    )$valid
    sealed
  }, error = function(e) {
    unwind_error <<- conditionMessage(e)
    FALSE
  })
  if (!isTRUE(completed) || !isTRUE(sealed)) {
    .spde_slope_gauge_tr_materializer_fail(unwind_error)
  }
  invisible(list(valid = TRUE, reason = "trust_region_terminal_sealed"))
}

if (!source_only) {
  if (length(args) == 1L && identical(args[[1L]], "preflight")) {
    spde_slope_gauge_trust_region_preflight()
    cat("GAUGE_TRUST_REGION_PREFLIGHT_PASS (no TMB build)\n")
    quit(status = 0L)
  }
  if (length(args) == 1L && identical(args[[1L]], "smoke")) {
    spde_slope_gauge_trust_region_smoke()
    cat("GAUGE_TRUST_REGION_SMOKE_SEALED\n")
    quit(status = 0L)
  }
  stop("usage: materialize-paper1-spde-slope-gauge-trust-region.R preflight|smoke", call. = FALSE)
}
