## Retained-record primitives for integrated-JSDM requalification.
## Fit-specific code is deliberately separate; these helpers are testable
## without compiling or loading gllvmTMB.

ISDM_RECEIPT_SCHEMA <- "isdm-requalification-attempt-v1"

isdm_identity_matches <- function(observed, expected) {
  fields <- c("source_sha", "source_tree", "source_hashes", "package_path",
              "library_paths", "package_version", "package_hashes",
              "dll_path", "dll_sha256")
  is.list(observed) && is.list(expected) &&
    all(fields %in% names(observed)) && all(fields %in% names(expected)) &&
    all(vapply(fields, function(field) identical(observed[[field]], expected[[field]]),
               logical(1L))) &&
    identical(observed$worktree_status %||% character(),
              expected$worktree_status %||% character())
}

isdm_source_contract_valid <- function(contract) {
  if (!is.list(contract)) return(FALSE)
  ci <- contract$ci_receipt
  install <- contract$install_receipt
  platforms <- c(linux = "success", macos = "success", windows = "success")
  identity_fields <- c("source_sha", "source_tree", "source_hashes",
                       "package_path", "library_paths", "package_version",
                       "package_hashes", "dll_path", "dll_sha256")
  install_fields <- c("source_sha", "source_tree", "package_path",
                      "package_version", "package_hashes", "dll_path",
                      "dll_sha256")
  identical(contract$schema, "isdm-source-contract-v2") &&
    all(identity_fields %in% names(contract)) &&
    is.list(ci) && identical(ci$schema, "isdm-ci-receipt-v1") &&
    identical(ci$verified, TRUE) && identical(ci$conclusion, "success") &&
    identical(ci$head_sha, contract$source_sha) &&
    identical(ci$platform_conclusions, platforms) &&
    is.character(ci$run_url) && length(ci$run_url) == 1L &&
    !is.na(ci$run_url) &&
    grepl("^https?://github\\.com/[^/[:space:]]+/[^/[:space:]]+/actions/runs/[0-9]+(/[^[:space:]]*)?$",
          ci$run_url) && identical(contract$ci_url, ci$run_url) &&
    identical(contract$ci_conclusion, ci$conclusion) &&
    is.list(install) && identical(install$schema, "isdm-install-receipt-v1") &&
    all(vapply(install_fields, function(field) {
      identical(install[[field]], contract[[field]])
    }, logical(1L))) && length(contract$package_hashes) > 0L
}

.isdm_abort <- function(message, class) {
  condition <- structure(
    list(message = message, call = NULL),
    class = c(class, "error", "condition")
  )
  stop(condition)
}

isdm_atomic_save <- function(object, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  lock <- paste0(path, ".lock")
  if (!dir.create(lock, showWarnings = FALSE)) {
    .isdm_abort("attempt_write_locked: refusing concurrent write",
                "isdm_attempt_write_locked")
  }
  on.exit(unlink(lock, recursive = TRUE, force = TRUE), add = TRUE)
  if (file.exists(path)) {
    .isdm_abort("attempt_already_exists: refusing to overwrite",
                "isdm_attempt_already_exists")
  }
  temporary <- tempfile(paste0(".", basename(path)), tmpdir = dirname(path))
  on.exit(if (file.exists(temporary)) unlink(temporary), add = TRUE)
  saveRDS(object, temporary)
  if (!file.rename(temporary, path)) {
    .isdm_abort("atomic retained-record rename failed",
                "isdm_atomic_rename_failed")
  }
  invisible(path)
}

isdm_terminal_record <- function(started, status, runtime_s, payload = list(),
                                 condition = NULL) {
  allowed <- c("fit_returned", "error", "interrupted", "unavailable")
  if (!status %in% allowed) {
    .isdm_abort(paste0("unknown terminal status: ", status),
                "isdm_terminal_status_invalid")
  }
  if (is.null(started$failure_phase)) {
    started$failure_phase <- if (status %in% c("fit_returned", "error",
                                               "interrupted")) "fit" else
      "preparation"
  }
  record <- c(
    list(schema = ISDM_RECEIPT_SCHEMA),
    started[setdiff(names(started), c("schema", "status"))],
    list(
      status = status,
      finished_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
      runtime_s = as.numeric(runtime_s)
    ),
    payload
  )
  if (!is.null(condition)) {
    record$error_class <- class(condition)
    record$error_message <- conditionMessage(condition)
  }
  record
}

.isdm_read_receipt <- function(path) {
  tryCatch(readRDS(path), error = function(e) {
    list(status = "unreadable_terminal", error_class = class(e),
         error_message = conditionMessage(e))
  })
}

.isdm_terminal_valid <- function(record, task_id, seed = NULL, task_spec = NULL,
                                 source_contract = NULL) {
  if (!is.list(record)) return(FALSE)
  spec_ok <- TRUE
  if (!is.null(task_spec)) {
    keys <- names(task_spec)
    spec_ok <- is.list(record$task_spec) && all(vapply(keys, function(key) {
      identical(record$task_spec[[key]], task_spec[[key]])
    }, logical(1L)))
  }
  phase <- record$failure_phase
  phase_ok <- is.character(phase) && length(phase) == 1L && !is.na(phase) &&
    phase %in% c("source_contract", "identity", "preparation", "fit")
  fit_bound <- identical(record$status, "fit_returned") ||
    identical(record$status, "error") ||
    (identical(record$status, "interrupted") && identical(phase, "fit"))
  identity_ok <- is.null(source_contract) || if (fit_bound) {
    isdm_identity_matches(record, source_contract) &&
      identical(record$expected_identity, source_contract)
  } else {
    identical(record$expected_identity, source_contract) ||
      identical(phase, "source_contract")
  }
  identical(record$schema, ISDM_RECEIPT_SCHEMA) &&
    identical(as.integer(record$task_id), as.integer(task_id)) &&
    length(record$seed) == 1L && is.finite(record$seed) &&
    (is.null(seed) || identical(as.integer(record$seed), as.integer(seed))) &&
    spec_ok && phase_ok && identity_ok && length(record$status) == 1L &&
    !is.na(record$status) &&
    record$status %in% c("fit_returned", "error", "interrupted", "unavailable")
}

isdm_reconcile_attempts <- function(output_dir, planned_task_ids,
                                    planned_seeds = NULL, planned_specs = NULL,
                                    source_contract = NULL) {
  planned_task_ids <- as.integer(planned_task_ids)
  rows <- lapply(seq_along(planned_task_ids), function(j) {
    task_id <- planned_task_ids[[j]]
    leaf <- sprintf("task-%06d.rds", task_id)
    started_path <- file.path(output_dir, "started", leaf)
    terminal_path <- file.path(output_dir, "attempts", leaf)
    has_started <- file.exists(started_path)
    terminal_exists <- file.exists(terminal_path)
    terminal <- if (terminal_exists) .isdm_read_receipt(terminal_path) else NULL
    has_terminal <- terminal_exists && isTRUE(.isdm_terminal_valid(
      terminal, task_id,
      seed = if (is.null(planned_seeds)) NULL else planned_seeds[[j]],
      task_spec = if (is.null(planned_specs)) NULL else
        as.list(planned_specs[j, , drop = FALSE]),
      source_contract = source_contract
    ))
    status <- if (has_terminal) {
      terminal$status %||% "unreadable_terminal"
    } else if (terminal_exists) {
      "invalid_terminal"
    } else if (has_started) {
      "interrupted_missing_terminal"
    } else {
      "planned_not_started"
    }
    data.frame(
      task_id = task_id,
      attempted = has_started || terminal_exists,
      terminal = has_terminal,
      status = status,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
