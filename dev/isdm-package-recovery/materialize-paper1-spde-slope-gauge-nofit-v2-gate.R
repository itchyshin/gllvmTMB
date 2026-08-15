#!/usr/bin/env Rscript
## The sole parent for the non-scientific V2 SPDE-slope gauge no-fit gate.
## It launches exactly one isolated child, stages every artifact beside the
## final root, and validates the reread packet before any status is printed.

args <- commandArgs(trailingOnly = TRUE)
source_only <- identical(
  Sys.getenv("SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_SOURCE_ONLY"),
  "1"
)
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
if (!source_only && length(file_arg) != 1L) {
  stop("V2 materializer must be invoked by Rscript --file", call. = FALSE)
}
script_path <- if (source_only) {
  normalizePath(
    Sys.getenv("SPDE_SLOPE_GAUGE_NOFIT_V2_MATERIALIZER_PATH"),
    mustWork = TRUE
  )
} else {
  normalizePath(sub("^--file=", "", file_arg), mustWork = TRUE)
}
script_dir <- dirname(script_path)
source(file.path(script_dir, "spde-slope-gauge-contract.R"), local = TRUE)
source(file.path(script_dir, "spde-slope-gauge-nofit-contract.R"), local = TRUE)

.spde_slope_gauge_nofit_v2_atomic_rds <- function(x, path) {
  if (
    !is.character(path) ||
      length(path) != 1L ||
      is.na(path) ||
      file.exists(path) ||
      (!is.na(Sys.readlink(path)) && nzchar(Sys.readlink(path))) ||
      file.exists(paste0(path, ".replace-backup")) ||
      (!is.na(Sys.readlink(paste0(path, ".replace-backup"))) &&
        nzchar(Sys.readlink(paste0(path, ".replace-backup"))))
  ) {
    stop("V2 artifact target is not a fresh regular path", call. = FALSE)
  }
  tmp <- tempfile(".spde-slope-gauge-v2-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, version = 3)
  if (!file.rename(tmp, path)) {
    stop("could not atomically write V2 artifact", call. = FALSE)
  }
  invisible(path)
}

.spde_slope_gauge_nofit_v2_portable_replace <- function(tmp, path, label) {
  # Windows cannot rename over an existing destination.  Move the existing
  # regular file aside first, then restore it if promotion fails.  A crash in
  # this small two-rename window leaves a visible ``.replace-backup`` marker;
  # the packet validator rejects that extra file rather than accepting a
  # partly replaced terminal.
  if (!.spde_slope_gauge_nofit_regular_file(path)) {
    stop(
      sprintf("V2 %s replacement target is not regular", label),
      call. = FALSE
    )
  }
  backup <- paste0(path, ".replace-backup")
  if (
    file.exists(backup) ||
      (!is.na(Sys.readlink(backup)) && nzchar(Sys.readlink(backup)))
  ) {
    stop(
      sprintf("V2 %s replacement backup already exists", label),
      call. = FALSE
    )
  }
  if (!file.rename(path, backup)) {
    stop(sprintf("could not prepare V2 %s replacement", label), call. = FALSE)
  }
  promoted <- file.rename(tmp, path)
  if (!promoted) {
    restored <- file.rename(backup, path)
    if (!restored) {
      stop(
        sprintf("could not promote or restore V2 %s replacement", label),
        call. = FALSE
      )
    }
    stop(sprintf("could not replace V2 %s", label), call. = FALSE)
  }
  if (unlink(backup) != 0L) {
    stop(
      sprintf("could not remove V2 %s replacement backup", label),
      call. = FALSE
    )
  }
  invisible(path)
}

.spde_slope_gauge_nofit_v2_atomic_replace_rds <- function(x, path) {
  if (!.spde_slope_gauge_nofit_regular_file(path)) {
    return(.spde_slope_gauge_nofit_v2_atomic_rds(x, path))
  }
  tmp <- tempfile(".spde-slope-gauge-v2-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, version = 3)
  .spde_slope_gauge_nofit_v2_portable_replace(tmp, path, "artifact")
  invisible(path)
}

.spde_slope_gauge_nofit_v2_atomic_text <- function(lines, path) {
  if (
    !is.character(path) ||
      length(path) != 1L ||
      is.na(path) ||
      file.exists(path) ||
      (!is.na(Sys.readlink(path)) && nzchar(Sys.readlink(path))) ||
      file.exists(paste0(path, ".replace-backup")) ||
      (!is.na(Sys.readlink(paste0(path, ".replace-backup"))) &&
        nzchar(Sys.readlink(paste0(path, ".replace-backup"))))
  ) {
    stop("V2 text target is not a fresh regular path", call. = FALSE)
  }
  tmp <- tempfile(".spde-slope-gauge-v2-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  writeLines(lines, tmp, useBytes = TRUE)
  if (!file.rename(tmp, path)) {
    stop("could not atomically write V2 text", call. = FALSE)
  }
  invisible(path)
}

.spde_slope_gauge_nofit_v2_atomic_replace_text <- function(lines, path) {
  if (!.spde_slope_gauge_nofit_regular_file(path)) {
    return(.spde_slope_gauge_nofit_v2_atomic_text(lines, path))
  }
  tmp <- tempfile(".spde-slope-gauge-v2-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  writeLines(lines, tmp, useBytes = TRUE)
  .spde_slope_gauge_nofit_v2_portable_replace(tmp, path, "text")
  invisible(path)
}

.spde_slope_gauge_nofit_v2_sources <- function() {
  locked <- spde_slope_gauge_nofit_locked_predecessor()
  paths <- c(
    child_runner = file.path(
      script_dir,
      "run-paper1-spde-slope-gauge-nofit-v2.R"
    ),
    pure_contract = file.path(script_dir, "spde-slope-gauge-contract.R"),
    nofit_contract = file.path(script_dir, "spde-slope-gauge-nofit-contract.R"),
    historical_contract = locked$historical_contract_path,
    design = file.path(
      script_dir,
      "2026-08-15-paper1-spde-slope-gauge-coordinate-design.md"
    ),
    materializer = script_path
  )
  if (
    !all(vapply(paths, .spde_slope_gauge_nofit_regular_file, logical(1L))) ||
      !identical(
        unname(tools::md5sum(paths[["historical_contract"]]))[[1L]],
        locked$historical_contract_md5
      )
  ) {
    stop(
      "V2 no-fit sources are unavailable or the historical validator drifted",
      call. = FALSE
    )
  }
  paths
}

.spde_slope_gauge_nofit_v2_commit <- function() {
  repo <- dirname(dirname(script_dir))
  commit <- tryCatch(
    system2(
      "git",
      c("-C", repo, "rev-parse", "HEAD"),
      stdout = TRUE,
      stderr = FALSE
    ),
    error = function(e) character()
  )
  dirty <- tryCatch(
    system2(
      "git",
      c("-C", repo, "status", "--porcelain"),
      stdout = TRUE,
      stderr = FALSE
    ),
    error = function(e) "DIRTY"
  )
  if (
    !.spde_slope_gauge_nofit_scalar_character(commit) ||
      !grepl("^[[:xdigit:]]{40}$", commit) ||
      length(dirty)
  ) {
    stop(
      "V2 no-fit materialization requires a clean committed tree",
      call. = FALSE
    )
  }
  commit
}

.spde_slope_gauge_nofit_v2_stage_token <- function(stage, parent_pid) {
  stage <- normalizePath(stage, mustWork = TRUE)
  list(
    schema = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2_PARENT_STAGE_V1",
    gate_base = normalizePath(dirname(stage), mustWork = TRUE),
    stage = stage,
    parent_pid = as.integer(parent_pid),
    child_output = file.path(stage, "child-result.rds")
  )
}

.spde_slope_gauge_nofit_v2_stale_stages <- function(base) {
  candidates <- list.files(
    base,
    pattern = "^\\.PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-",
    full.names = TRUE,
    recursive = FALSE,
    all.files = TRUE
  )
  candidates[vapply(
    candidates,
    function(path) {
      isTRUE(file.info(path)$isdir[[1L]]) && identical(Sys.readlink(path), "")
    },
    logical(1L)
  )]
}

.spde_slope_gauge_nofit_v2_manifest <- function(root, files) {
  declared <- setdiff(files, "file-manifest.csv")
  table <- data.frame(
    path = declared,
    md5 = unname(tools::md5sum(file.path(root, declared))),
    stringsAsFactors = FALSE
  )
  tmp <- tempfile(".spde-slope-gauge-v2-manifest-", tmpdir = root)
  on.exit(unlink(tmp), add = TRUE)
  utils::write.csv(table, tmp, row.names = FALSE, quote = TRUE)
  manifest <- file.path(root, "file-manifest.csv")
  if (.spde_slope_gauge_nofit_regular_file(manifest)) {
    .spde_slope_gauge_nofit_v2_portable_replace(tmp, manifest, "manifest")
  } else if (
    file.exists(manifest) ||
      (!is.na(Sys.readlink(manifest)) && nzchar(Sys.readlink(manifest)))
  ) {
    stop("V2 manifest target is not a fresh regular path", call. = FALSE)
  } else if (!file.rename(tmp, manifest)) {
    stop("could not atomically write V2 manifest", call. = FALSE)
  }
  invisible(table)
}

.spde_slope_gauge_nofit_v2_launch_child <- function(
  stage,
  parent_pid,
  run_fun = NULL
) {
  if (is.null(run_fun)) {
    if (!requireNamespace("processx", quietly = TRUE)) {
      stop("processx is required for V2 child supervision", call. = FALSE)
    }
    run_fun <- function(command, arguments, timeout, ...) {
      process <- processx::process$new(
        command,
        arguments,
        stdout = "|",
        stderr = "|",
        cleanup = FALSE
      )
      process$wait(timeout)
      timed_out <- process$is_alive()
      if (timed_out) {
        process$kill()
        process$wait()
      }
      list(
        status = process$get_exit_status(),
        stdout = process$read_output(),
        stderr = process$read_error(),
        timed_out = timed_out,
        pid = process$get_pid()
      )
    }
  }
  runner <- file.path(script_dir, "run-paper1-spde-slope-gauge-nofit-v2.R")
  output <- file.path(stage, "child-result.rds")
  command <- R.home("bin/Rscript")
  arguments <- c("--vanilla", runner, "child", output, as.character(parent_pid))
  started <- Sys.time()
  run <- tryCatch(
    run_fun(
      command,
      arguments,
      timeout = 1800 * 1000,
      error_on_status = FALSE,
      echo = FALSE
    ),
    error = function(e) {
      list(
        status = NA_integer_,
        stdout = "",
        stderr = conditionMessage(e),
        timed_out = grepl(
          "timeout|time limit",
          conditionMessage(e),
          ignore.case = TRUE
        )
      )
    }
  )
  ended <- Sys.time()
  stdout <- file.path(stage, "child-stdout.txt")
  stderr <- file.path(stage, "child-stderr.txt")
  .spde_slope_gauge_nofit_v2_atomic_text(
    if (is.character(run$stdout) && length(run$stdout) == 1L) {
      run$stdout
    } else {
      ""
    },
    stdout
  )
  .spde_slope_gauge_nofit_v2_atomic_text(
    if (is.character(run$stderr) && length(run$stderr) == 1L) {
      run$stderr
    } else {
      ""
    },
    stderr
  )
  status <- if (
    is.numeric(run$status) && length(run$status) == 1L && !is.na(run$status)
  ) {
    as.integer(run$status)
  } else {
    NA_integer_
  }
  timed_out <- isTRUE(run$timed_out) ||
    (!is.finite(as.double(status)) &&
      grepl(
        "timeout|time limit",
        paste(readLines(stderr, warn = FALSE), collapse = "\n"),
        ignore.case = TRUE
      ))
  child <- if (
    identical(status, 0L) &&
      !timed_out &&
      .spde_slope_gauge_nofit_regular_file(output)
  ) {
    tryCatch(readRDS(output), error = function(e) NULL)
  } else {
    NULL
  }
  if (
    !is.list(child) && (file.exists(output) || nzchar(Sys.readlink(output)))
  ) {
    if (unlink(output) != 0L) {
      stop("could not discard invalid V2 child output", call. = FALSE)
    }
  }
  process <- list(
    schema = .spde_slope_gauge_nofit_v2_process_schema(),
    command = command,
    arguments = arguments,
    parent_pid = as.integer(parent_pid),
    child_pid = if (
      is.list(child) &&
        is.integer(child$child_pid) &&
        length(child$child_pid) == 1L
    ) {
      child$child_pid
    } else {
      NA_integer_
    },
    observed_child_pid = if (
      is.numeric(run$pid) &&
        length(run$pid) == 1L &&
        is.finite(run$pid) &&
        run$pid > 0
    ) {
      as.integer(run$pid)
    } else {
      NA_integer_
    },
    started_at = format(started, tz = "UTC", usetz = TRUE),
    ended_at = format(ended, tz = "UTC", usetz = TRUE),
    elapsed_s = as.double(difftime(ended, started, units = "secs")),
    deadline_s = 1800,
    timed_out = timed_out,
    exit_status = status,
    signal = NA_character_,
    stdout_md5 = unname(tools::md5sum(stdout))[[1L]],
    stderr_md5 = unname(tools::md5sum(stderr))[[1L]],
    child_result_md5 = if (is.list(child)) {
      unname(tools::md5sum(output))[[1L]]
    } else {
      NA_character_
    }
  )
  list(
    process = process,
    child = if (is.list(child)) child else NULL,
    output = output
  )
}

.spde_slope_gauge_nofit_v2_forensic_seal <- function(
  packet,
  root,
  sources,
  commit,
  v1,
  v3,
  token,
  child_run,
  seal_failure,
  validator = spde_slope_gauge_nofit_v2_validate_gate_root,
  v1_locked = .spde_slope_gauge_nofit_v2_locked_v1(),
  v3_locked = spde_slope_gauge_nofit_locked_predecessor()
) {
  if (!dir.exists(packet)) {
    stop("V2 forensic packet directory is unavailable", call. = FALSE)
  }
  output_candidates <- c(
    file.path(packet, "no-fit-result.rds"),
    file.path(packet, "child-result.rds")
  )
  output_candidates <- output_candidates[vapply(
    output_candidates,
    .spde_slope_gauge_nofit_regular_file,
    logical(1L)
  )]
  has_unvalidated <- length(output_candidates) == 1L
  if (has_unvalidated) {
    target <- file.path(packet, "unvalidated-child-result.rds")
    if (
      !identical(output_candidates[[1L]], target) &&
        !file.rename(output_candidates[[1L]], target)
    ) {
      stop("could not retain unvalidated V2 child bytes", call. = FALSE)
    }
  }
  process <- if (is.list(child_run$process)) {
    child_run$process
  } else {
    list(
      schema = .spde_slope_gauge_nofit_v2_process_schema(),
      command = R.home("bin/Rscript"),
      arguments = c(
        "--vanilla",
        sources[["child_runner"]],
        "child",
        token$child_output,
        as.character(token$parent_pid)
      ),
      parent_pid = token$parent_pid,
      child_pid = NA_integer_,
      observed_child_pid = NA_integer_,
      started_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
      ended_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
      elapsed_s = 0,
      deadline_s = 1800,
      timed_out = FALSE,
      exit_status = NA_integer_,
      signal = NA_character_,
      stdout_md5 = NA_character_,
      stderr_md5 = NA_character_,
      child_result_md5 = NA_character_
    )
  }
  process$child_pid <- NA_integer_
  process$child_result_md5 <- NA_character_
  for (stream in c("child-stdout.txt", "child-stderr.txt")) {
    path <- file.path(packet, stream)
    if (!.spde_slope_gauge_nofit_regular_file(path)) {
      .spde_slope_gauge_nofit_v2_atomic_text("", path)
    }
  }
  process$stdout_md5 <- unname(tools::md5sum(file.path(
    packet,
    "child-stdout.txt"
  )))[[1L]]
  process$stderr_md5 <- unname(tools::md5sum(file.path(
    packet,
    "child-stderr.txt"
  )))[[1L]]
  .spde_slope_gauge_nofit_v2_atomic_replace_rds(
    process,
    file.path(packet, "child-receipt.rds")
  )
  if (
    !.spde_slope_gauge_nofit_regular_file(file.path(packet, "materializer.R"))
  ) {
    if (
      !file.copy(sources[["materializer"]], file.path(packet, "materializer.R"))
    ) {
      stop("could not retain V2 fallback materializer", call. = FALSE)
    }
  }
  if (
    !.spde_slope_gauge_nofit_regular_file(file.path(packet, "session-info.rds"))
  ) {
    .spde_slope_gauge_nofit_v2_atomic_rds(
      utils::sessionInfo(),
      file.path(packet, "session-info.rds")
    )
  }
  if (
    !.spde_slope_gauge_nofit_regular_file(file.path(packet, "time-estimate.md"))
  ) {
    .spde_slope_gauge_nofit_v2_atomic_text(
      "V2 no-fit gate ended in parent terminalization failure.",
      file.path(packet, "time-estimate.md")
    )
  }
  unlink(file.path(packet, ".parent-stage.rds"))
  claim <- file.path(packet, ".attempt-started.claim")
  if (!dir.exists(claim)) {
    dir.create(claim, showWarnings = FALSE)
  }
  receipt <- list(
    schema = .spde_slope_gauge_nofit_v2_gate_schema(),
    gate = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2",
    root = root,
    commit = commit,
    status = "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD",
    # This path is entered only after the parent has caught a sealing
    # failure.  Whether a child byte was retained changes the inventory, not
    # the cause: relabelling a parent failure as a child no-result would lose
    # the original terminalization evidence.
    reason = "parent_seal_failure",
    predecessors = .spde_slope_gauge_nofit_v2_predecessor_projection(v1, v3),
    sources = stats::setNames(unname(tools::md5sum(sources)), names(sources)),
    dll = list(path = NA_character_, md5 = NA_character_),
    controls = spde_slope_gauge_no_fit_controls(),
    parent_stage = token,
    process = process,
    child_result_md5 = NA_character_,
    unvalidated_child_md5 = if (has_unvalidated) {
      unname(tools::md5sum(file.path(
        packet,
        "unvalidated-child-result.rds"
      )))[[1L]]
    } else {
      NA_character_
    },
    seal_failure = seal_failure,
    time_estimate_md5 = unname(tools::md5sum(file.path(
      packet,
      "time-estimate.md"
    )))[[1L]]
  )
  .spde_slope_gauge_nofit_v2_atomic_replace_rds(
    receipt,
    file.path(packet, "root-receipt.rds")
  )
  files <- .spde_slope_gauge_nofit_v2_gate_files(FALSE, has_unvalidated)
  .spde_slope_gauge_nofit_v2_manifest(packet, files)
  if (!identical(packet, root)) {
    staged <- validator(
      packet,
      sources,
      commit = commit,
      expected_root = root,
      v1_locked = v1_locked,
      v3_locked = v3_locked
    )
    if (!isTRUE(staged$valid) || !file.rename(packet, root)) {
      stop("could not promote V2 forensic terminal", call. = FALSE)
    }
  }
  verdict <- validator(
    root,
    sources,
    commit = commit,
    expected_root = root,
    v1_locked = v1_locked,
    v3_locked = v3_locked
  )
  if (!isTRUE(verdict$valid)) {
    stop(verdict$reason, call. = FALSE)
  }
  invisible(verdict)
}

.spde_slope_gauge_nofit_v2_seal <- function(
  stage,
  root,
  sources,
  commit,
  v1,
  v3,
  token,
  child_run
) {
  if (
    !identical(
      tryCatch(
        readRDS(file.path(stage, ".parent-stage.rds")),
        error = function(e) NULL
      ),
      token
    )
  ) {
    stop("V2 parent-stage token changed before sealing", call. = FALSE)
  }
  has_child <- is.list(child_run$child)
  if (
    has_child &&
      !file.rename(child_run$output, file.path(stage, "no-fit-result.rds"))
  ) {
    stop("could not retain V2 child result", call. = FALSE)
  }
  if (has_child) {
    child_run$process$child_result_md5 <- unname(tools::md5sum(file.path(
      stage,
      "no-fit-result.rds"
    )))[[1L]]
  }
  unlink(file.path(stage, ".parent-stage.rds"))
  .spde_slope_gauge_nofit_v2_atomic_rds(
    child_run$process,
    file.path(stage, "child-receipt.rds")
  )
  if (
    !file.copy(
      sources[["materializer"]],
      file.path(stage, "materializer.R"),
      copy.date = TRUE
    ) ||
      !identical(Sys.readlink(file.path(stage, "materializer.R")), "")
  ) {
    stop("could not retain V2 materializer", call. = FALSE)
  }
  .spde_slope_gauge_nofit_v2_atomic_rds(
    utils::sessionInfo(),
    file.path(stage, "session-info.rds")
  )
  .spde_slope_gauge_nofit_v2_atomic_text(
    c(
      "# SPDE-slope gauge V2 no-fit gate time estimate",
      "Expected wall time: 3-10 minutes.",
      "Hard child deadline: 30 minutes.",
      "This is not a numerical-admission or ecological result."
    ),
    file.path(stage, "time-estimate.md")
  )
  child_valid <- has_child &&
    isTRUE(.spde_slope_gauge_nofit_v2_child_ok(
      child_run$child,
      v1,
      v3,
      child_run$child$dll
    ))
  evidence_hold <- has_child && !child_valid
  receipt <- list(
    schema = .spde_slope_gauge_nofit_v2_gate_schema(),
    gate = "PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2",
    root = root,
    commit = commit,
    status = if (!has_child || evidence_hold) {
      "SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD"
    } else {
      child_run$child$status
    },
    reason = if (!has_child) {
      "child_process_no_result"
    } else if (evidence_hold) {
      "child_evidence_invalid"
    } else {
      child_run$child$reason
    },
    predecessors = .spde_slope_gauge_nofit_v2_predecessor_projection(v1, v3),
    sources = stats::setNames(unname(tools::md5sum(sources)), names(sources)),
    dll = if (child_valid) {
      child_run$child$dll
    } else {
      list(path = NA_character_, md5 = NA_character_)
    },
    controls = spde_slope_gauge_no_fit_controls(),
    parent_stage = token,
    process = child_run$process,
    child_result_md5 = if (has_child) {
      child_run$process$child_result_md5
    } else {
      NA_character_
    },
    unvalidated_child_md5 = NA_character_,
    seal_failure = NA_character_,
    time_estimate_md5 = unname(tools::md5sum(file.path(
      stage,
      "time-estimate.md"
    )))[[1L]]
  )
  .spde_slope_gauge_nofit_v2_atomic_rds(
    receipt,
    file.path(stage, "root-receipt.rds")
  )
  dir.create(file.path(stage, ".attempt-started.claim"), showWarnings = FALSE)
  if (
    !isTRUE(file.info(file.path(stage, ".attempt-started.claim"))$isdir[[
      1L
    ]]) ||
      !identical(Sys.readlink(file.path(stage, ".attempt-started.claim")), "")
  ) {
    stop("could not create V2 claim directory", call. = FALSE)
  }
  files <- .spde_slope_gauge_nofit_v2_gate_files(has_child)
  .spde_slope_gauge_nofit_v2_manifest(stage, files)
  staged_verdict <- spde_slope_gauge_nofit_v2_validate_gate_root(
    stage,
    sources,
    commit = commit,
    expected_root = root
  )
  if (!isTRUE(staged_verdict$valid)) {
    stop(staged_verdict$reason, call. = FALSE)
  }
  if (!file.rename(stage, root)) {
    stop("could not atomically seal V2 root", call. = FALSE)
  }
  verdict <- spde_slope_gauge_nofit_v2_validate_gate_root(
    root,
    sources,
    commit = commit,
    expected_root = root
  )
  if (!isTRUE(verdict$valid)) {
    stop(verdict$reason, call. = FALSE)
  }
  cat(receipt$status, "\n", sep = "")
  invisible(verdict)
}

spde_slope_gauge_nofit_v2_materialize_gate <- function() {
  if (!requireNamespace("processx", quietly = TRUE)) {
    stop("processx is required for V2 materialization", call. = FALSE)
  }
  sources <- .spde_slope_gauge_nofit_v2_sources()
  commit <- .spde_slope_gauge_nofit_v2_commit()
  v1 <- spde_slope_gauge_nofit_v2_validate_v1_forensic()
  v3 <- spde_slope_gauge_nofit_validate_predecessor_bytes()
  if (!isTRUE(v1$valid) || !isTRUE(v3$valid)) {
    stop("V2 predecessors are invalid", call. = FALSE)
  }
  root <- .spde_slope_gauge_nofit_v2_gate_root()
  base <- dirname(root)
  if (!dir.exists(base)) {
    dir.create(base, recursive = TRUE, showWarnings = FALSE)
  }
  if (
    !dir.exists(base) ||
      !identical(Sys.readlink(base), "") ||
      file.exists(root) ||
      nzchar(Sys.readlink(root))
  ) {
    stop("V2 gate root is unavailable or already consumed", call. = FALSE)
  }
  if (length(.spde_slope_gauge_nofit_v2_stale_stages(base))) {
    stop(
      "V2 gate has retained post-launch staging evidence and cannot be rerun",
      call. = FALSE
    )
  }
  stage <- tempfile(".PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2-", tmpdir = base)
  if (!dir.create(stage, recursive = FALSE, showWarnings = FALSE)) {
    stop("could not create V2 staging root", call. = FALSE)
  }
  stage <- normalizePath(stage, mustWork = TRUE)
  child_launched <- FALSE
  on.exit(
    if (
      is.character(stage) &&
        length(stage) == 1L &&
        !is.na(stage) &&
        dir.exists(stage) &&
        !child_launched
    ) {
      unlink(stage, recursive = TRUE)
    },
    add = TRUE
  )
  token <- .spde_slope_gauge_nofit_v2_stage_token(
    stage,
    as.integer(Sys.getpid())
  )
  .spde_slope_gauge_nofit_v2_atomic_rds(
    token,
    file.path(stage, ".parent-stage.rds")
  )
  child_launched <- TRUE
  # A launcher error can occur after the child has started (for example while
  # retaining its streams).  It is post-claim evidence and must therefore
  # follow the same forensic-terminal path as a later sealing error.
  child_run <- tryCatch(
    .spde_slope_gauge_nofit_v2_launch_child(stage, token$parent_pid),
    error = function(e) {
      list(
        process = NULL,
        child = NULL,
        output = token$child_output,
        launch_error = conditionMessage(e)
      )
    }
  )
  verdict <- tryCatch(
    {
      if (
        is.character(child_run$launch_error) &&
          length(child_run$launch_error) == 1L &&
          !is.na(child_run$launch_error)
      ) {
        stop(child_run$launch_error, call. = FALSE)
      }
      .spde_slope_gauge_nofit_v2_seal(
        stage,
        root,
        sources,
        commit,
        v1,
        v3,
        token,
        child_run
      )
    },
    error = function(e) {
      packet <- if (dir.exists(root)) root else stage
      .spde_slope_gauge_nofit_v2_forensic_seal(
        packet,
        root,
        sources,
        commit,
        v1,
        v3,
        token,
        child_run,
        conditionMessage(e)
      )
    }
  )
  stage <- NA_character_
  invisible(verdict)
}

if (
  !source_only && length(args) == 1L && identical(args[[1L]], "materialize")
) {
  spde_slope_gauge_nofit_v2_materialize_gate()
} else if (!source_only && length(args)) {
  stop(
    "usage: materialize-paper1-spde-slope-gauge-nofit-v2-gate.R materialize",
    call. = FALSE
  )
}
