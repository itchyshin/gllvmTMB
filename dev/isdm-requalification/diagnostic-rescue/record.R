DIAGNOSTIC_SCHEMA <- "isdm-identifiability-diagnostic-v1"

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

diagnostic_abort <- function(message, class = "isdm_diagnostic_error") {
  stop(structure(list(message = message, call = NULL),
                 class = c(class, "error", "condition")))
}

diagnostic_sha256 <- function(paths) {
  paths <- normalizePath(paths, mustWork = TRUE)
  command <- if (nzchar(Sys.which("sha256sum"))) "sha256sum" else "shasum"
  args <- if (command == "shasum") c("-a", "256", paths) else paths
  out <- system2(command, args, stdout = TRUE, stderr = TRUE)
  if (!identical(as.integer(attr(out, "status") %||% 0L), 0L) ||
      length(out) != length(paths)) {
    diagnostic_abort("SHA-256 command failed", "isdm_diagnostic_hash_error")
  }
  hashes <- sub("[[:space:]].*$", "", out)
  if (any(!grepl("^[[:xdigit:]]{64}$", hashes))) {
    diagnostic_abort("malformed SHA-256 output", "isdm_diagnostic_hash_error")
  }
  stats::setNames(hashes, paths)
}

diagnostic_object_hash <- function(object) {
  path <- tempfile(fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(object, path, version = 3)
  unname(diagnostic_sha256(path))
}

diagnostic_atomic_save <- function(object, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  lock <- paste0(path, ".lock")
  if (!dir.create(lock, showWarnings = FALSE)) {
    diagnostic_abort("record path is locked", "isdm_diagnostic_write_locked")
  }
  on.exit(unlink(lock, recursive = TRUE, force = TRUE), add = TRUE)
  if (file.exists(path)) {
    diagnostic_abort("record already exists", "isdm_diagnostic_record_exists")
  }
  temporary <- tempfile(paste0(".", basename(path)), tmpdir = dirname(path))
  on.exit(if (file.exists(temporary)) unlink(temporary), add = TRUE)
  saveRDS(object, temporary, version = 3)
  if (!file.rename(temporary, path)) {
    diagnostic_abort("atomic record rename failed",
                     "isdm_diagnostic_atomic_rename_failed")
  }
  invisible(path)
}

diagnostic_started_record <- function(task, qualification) {
  list(
    schema = DIAGNOSTIC_SCHEMA,
    task_id = as.integer(task$task_id[[1L]]),
    task = as.list(task[1L, , drop = FALSE]),
    status = "started",
    started_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    source_sha = qualification$source_sha,
    source_tree = qualification$source_tree,
    harness_manifest_sha256 = qualification$harness_manifest_sha256
  )
}

diagnostic_terminal_record <- function(started, status, runtime_s,
                                       payload = list(), condition = NULL,
                                       optimizer_entered = FALSE,
                                       public_fit_call_entered = FALSE,
                                       disposition_source = "worker") {
  allowed <- c("fit_returned", "error", "interrupted", "unavailable")
  if (!status %in% allowed) diagnostic_abort("invalid terminal status")
  out <- c(started[setdiff(names(started), "status")], list(
    status = status,
    finished_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    runtime_s = as.numeric(runtime_s),
    optimizer_entered = if (length(optimizer_entered) == 1L &&
                             is.na(optimizer_entered)) NA else
      isTRUE(optimizer_entered),
    public_fit_call_entered = if (length(public_fit_call_entered) == 1L &&
                                   is.na(public_fit_call_entered)) NA else
      isTRUE(public_fit_call_entered),
    disposition_source = disposition_source
  ), payload)
  if (!is.null(condition)) {
    out$error_class <- class(condition)
    out$error_message <- conditionMessage(condition)
  }
  out$session_info <- capture.output(utils::sessionInfo())
  out
}

diagnostic_leaf <- function(task_id) sprintf("task-%06d.rds", as.integer(task_id))

diagnostic_write_started <- function(task, output_dir, qualification) {
  record <- diagnostic_started_record(task, qualification)
  diagnostic_atomic_save(
    record, file.path(output_dir, "started", diagnostic_leaf(task$task_id[[1L]]))
  )
  record
}

diagnostic_write_terminal <- function(record, output_dir) {
  diagnostic_atomic_save(
    record, file.path(output_dir, "attempts", diagnostic_leaf(record$task_id))
  )
}

diagnostic_reconcile <- function(plan, output_dir, qualification,
                                 reason = "supervisor stopped before completion") {
  prior_paths <- list.files(file.path(output_dir, "coordinator"),
                            pattern = "^reconciliation-.*[.]rds$",
                            full.names = TRUE)
  prior <- unlist(lapply(prior_paths, function(path) {
    readRDS(path)$dispositions %||% list()
  }), recursive = FALSE)
  prior_ids <- vapply(prior, function(x) as.integer(x$task_id), integer(1L))
  if (anyDuplicated(prior_ids)) {
    diagnostic_abort("prior coordinator receipts contain duplicate dispositions",
                     "isdm_diagnostic_disposition_error")
  }
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    task <- plan[i, , drop = FALSE]
    leaf <- diagnostic_leaf(task$task_id[[1L]])
    started_path <- file.path(output_dir, "started", leaf)
    terminal_path <- file.path(output_dir, "attempts", leaf)
    if (file.exists(terminal_path) || task$task_id[[1L]] %in% prior_ids) {
      return(NULL)
    }
    started <- if (file.exists(started_path)) readRDS(started_path) else
      diagnostic_started_record(task, qualification)
    status <- if (file.exists(started_path)) "interrupted" else "unavailable"
    diagnostic_terminal_record(
      started, status = status, runtime_s = NA_real_,
      condition = structure(list(message = reason, call = NULL),
                            class = c("isdm_diagnostic_supervisor_stop",
                                      "error", "condition")),
      ## A started receipt precedes source verification and optimizer entry.
      ## After a supervisor stop we cannot recover which side of that boundary
      ## the killed process reached, so retain unknown rather than invent TRUE.
      optimizer_entered = if (file.exists(started_path)) NA else FALSE,
      public_fit_call_entered = if (file.exists(started_path)) NA else FALSE,
      disposition_source = "coordinator"
    )
  })
  rows <- Filter(Negate(is.null), rows)
  receipt <- list(
    schema = "isdm-diagnostic-coordinator-reconciliation-v1",
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    planned = nrow(plan), reconciled = length(rows), reason = reason,
    dispositions = rows
  )
  path <- file.path(output_dir, "coordinator",
                    paste0("reconciliation-", format(Sys.time(), "%Y%m%dT%H%M%S"),
                           ".rds"))
  diagnostic_atomic_save(receipt, path)
  ## A reconciliation is not terminal until the all-attempt ledger resolves.
  dispositions <- diagnostic_terminal_dispositions(plan, output_dir)
  if (length(dispositions) != nrow(plan)) {
    diagnostic_abort("reconciliation did not resolve every planned identity",
                     "isdm_diagnostic_disposition_error")
  }
  receipt
}

diagnostic_terminal_dispositions <- function(plan, output_dir) {
  coordinator <- list.files(file.path(output_dir, "coordinator"),
                            pattern = "^reconciliation-.*[.]rds$",
                            full.names = TRUE)
  coordinator_records <- unlist(lapply(coordinator, function(path) {
    x <- readRDS(path)
    x$dispositions %||% list()
  }), recursive = FALSE)
  lapply(plan$task_id, function(id) {
    worker <- file.path(output_dir, "attempts", diagnostic_leaf(id))
    candidates <- c(if (file.exists(worker)) 1L else 0L,
                    sum(vapply(coordinator_records, function(x) {
                      identical(as.integer(x$task_id), as.integer(id))
                    }, logical(1L))))
    if (sum(candidates) != 1L) {
      diagnostic_abort(paste("task", id, "does not have exactly one disposition"),
                       "isdm_diagnostic_disposition_error")
    }
    if (file.exists(worker)) readRDS(worker) else coordinator_records[[which(
      vapply(coordinator_records, function(x) {
        identical(as.integer(x$task_id), as.integer(id))
      }, logical(1L))
    )[[1L]]]]
  })
}
