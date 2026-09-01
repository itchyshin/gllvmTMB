## Append-only worker receipts and non-overwriting coordinator dispositions.

ISDM_RESPINFO_RECORD_SCHEMA <- "isdm-response-information-record-v3"
ISDM_RESPINFO_COORDINATOR_SCHEMA <- "isdm-response-information-coordinator-v1"

.isdm_respinfo_record_abort <- function(message, class = "isdm_respinfo_record_error") {
  stop(structure(list(message = message, call = NULL), class = c(class, "error", "condition")))
}

isdm_respinfo_atomic_save <- function(object, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(path)) .isdm_respinfo_record_abort("receipt already exists", "isdm_respinfo_receipt_exists")
  temporary <- tempfile(paste0(".", basename(path)), tmpdir = dirname(path)); on.exit(unlink(temporary), add = TRUE)
  saveRDS(object, temporary, version = 3)
  if (!file.rename(temporary, path)) .isdm_respinfo_record_abort("atomic receipt write failed", "isdm_respinfo_receipt_write_failed")
  invisible(path)
}

isdm_respinfo_leaf <- function(task_id) sprintf("task-%06d.rds", as.integer(task_id))

isdm_respinfo_started_record <- function(task, qualification) {
  list(schema = ISDM_RESPINFO_RECORD_SCHEMA, task_id = as.integer(task$task_id[[1L]]),
       task = as.list(task[1L, , drop = FALSE]), status = "started",
       started_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
       source_sha = qualification$source_sha, source_tree = qualification$source_tree,
       harness_manifest_sha256 = qualification$harness_manifest_sha256)
}

isdm_respinfo_terminal_record <- function(started, status, runtime_s, payload = list(), condition = NULL,
                                          optimizer_entered = FALSE, disposition_source = "worker") {
  if (!status %in% c("fit_returned", "error", "interrupted", "unavailable") || !disposition_source %in% c("worker", "coordinator")) .isdm_respinfo_record_abort("unknown terminal status or source")
  out <- c(started[setdiff(names(started), "status")], list(
    status = status, finished_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    runtime_s = as.numeric(runtime_s), optimizer_entered = optimizer_entered,
    disposition_source = disposition_source), payload)
  if (!is.null(condition)) { out$error_class <- class(condition); out$error_message <- conditionMessage(condition) }
  out
}

isdm_respinfo_write_started <- function(task, output_dir, qualification) {
  out <- isdm_respinfo_started_record(task, qualification)
  isdm_respinfo_atomic_save(out, file.path(output_dir, "started", isdm_respinfo_leaf(out$task_id)))
  out
}

isdm_respinfo_validate_terminal_record <- function(record, worker_only = FALSE) {
  required <- c("schema", "task_id", "task", "status", "runtime_s", "disposition_source", "source_sha", "source_tree", "harness_manifest_sha256")
  valid_source <- record$disposition_source %in% c("worker", "coordinator")
  if (!is.list(record) || !all(required %in% names(record)) || !identical(record$schema, ISDM_RESPINFO_RECORD_SCHEMA) ||
      !is.list(record$task) || length(record$task_id) != 1L || !identical(as.integer(record$task_id), as.integer(record$task$task_id)) ||
      !record$status %in% c("fit_returned", "error", "interrupted", "unavailable") || !valid_source ||
      (worker_only && !identical(record$disposition_source, "worker")) || !is.numeric(record$runtime_s) || length(record$runtime_s) != 1L ||
      (identical(record$disposition_source, "worker") && (!is.finite(record$runtime_s) || record$runtime_s < 0)) ||
      (identical(record$disposition_source, "coordinator") && !is.na(record$runtime_s))) .isdm_respinfo_record_abort("terminal receipt is malformed", "isdm_respinfo_terminal_invalid")
  invisible(TRUE)
}

isdm_respinfo_write_terminal <- function(record, output_dir) {
  isdm_respinfo_validate_terminal_record(record, worker_only = TRUE)
  isdm_respinfo_atomic_save(record, file.path(output_dir, "attempts", isdm_respinfo_leaf(record$task_id)))
}

isdm_respinfo_reconcile <- function(plan, output_dir, qualification, reason = "coordinator stopped before terminal receipt") {
  isdm_respinfo_validate_plan(plan)
  worker <- list.files(file.path(output_dir, "attempts"), pattern = "^task-[0-9]{6}[.]rds$", full.names = TRUE)
  worker_ids <- if (length(worker)) vapply(worker, function(x) as.integer(readRDS(x)$task_id), integer(1L)) else integer()
  if (anyDuplicated(worker_ids)) .isdm_respinfo_record_abort("duplicate worker terminal receipts")
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    task <- plan[i, , drop = FALSE]; id <- task$task_id[[1L]]
    if (id %in% worker_ids) return(NULL)
    started_path <- file.path(output_dir, "started", isdm_respinfo_leaf(id))
    started <- if (file.exists(started_path)) readRDS(started_path) else isdm_respinfo_started_record(task, qualification)
    isdm_respinfo_terminal_record(started, if (file.exists(started_path)) "interrupted" else "unavailable", NA_real_,
      condition = structure(list(message = reason, call = NULL), class = c("isdm_respinfo_coordinator_stop", "error", "condition")),
      optimizer_entered = NA, disposition_source = "coordinator")
  })
  rows <- Filter(Negate(is.null), rows)
  receipt <- list(schema = ISDM_RESPINFO_COORDINATOR_SCHEMA, created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
                  planned = nrow(plan), worker_terminal = length(worker_ids), reason = reason, dispositions = rows)
  isdm_respinfo_atomic_save(receipt, file.path(output_dir, "coordinator", paste0("reconciliation-", format(Sys.time(), "%Y%m%dT%H%M%S"), ".rds")))
  receipt
}

isdm_respinfo_terminal_dispositions <- function(plan, output_dir) {
  isdm_respinfo_validate_plan(plan)
  worker_paths <- list.files(file.path(output_dir, "attempts"), pattern = "^task-[0-9]{6}[.]rds$", full.names = TRUE)
  worker <- lapply(worker_paths, readRDS)
  coordinator_paths <- list.files(file.path(output_dir, "coordinator"), pattern = "^reconciliation-.*[.]rds$", full.names = TRUE)
  coordinator <- unlist(lapply(coordinator_paths, function(path) { x <- readRDS(path); if (!identical(x$schema, ISDM_RESPINFO_COORDINATOR_SCHEMA)) .isdm_respinfo_record_abort("invalid coordinator receipt"); x$dispositions }), recursive = FALSE)
  records <- c(worker, coordinator); ids <- vapply(records, function(x) as.integer(x$task_id), integer(1L))
  if (length(records) != nrow(plan) || anyDuplicated(ids) || !identical(sort(ids), as.integer(plan$task_id))) .isdm_respinfo_record_abort("planned identities do not have exactly one terminal disposition", "isdm_respinfo_disposition_invalid")
  lapply(records, isdm_respinfo_validate_terminal_record)
  records[match(plan$task_id, ids)]
}

## A retained pilot is a frozen 16-row subset of the scientific plan, not a
## prematurely reconciled 800-row study.  Read only its worker terminals.
isdm_respinfo_pilot_dispositions <- function(pilot_plan, output_dir) {
  expected <- isdm_respinfo_pilot_plan(isdm_respinfo_plan())
  if (!identical(pilot_plan, expected)) {
    .isdm_respinfo_record_abort("pilot plan is not the frozen scientific subset", "isdm_respinfo_pilot_plan_invalid")
  }
  paths <- file.path(output_dir, "attempts", isdm_respinfo_leaf(expected$task_id))
  if (any(!file.exists(paths))) {
    .isdm_respinfo_record_abort("pilot identities do not all have worker terminal receipts", "isdm_respinfo_disposition_invalid")
  }
  records <- lapply(paths, readRDS)
  ids <- vapply(records, function(x) as.integer(x$task_id), integer(1L))
  if (anyDuplicated(ids) || !identical(ids, as.integer(expected$task_id))) {
    .isdm_respinfo_record_abort("pilot terminal receipts do not match frozen identities", "isdm_respinfo_disposition_invalid")
  }
  lapply(records, isdm_respinfo_validate_terminal_record, worker_only = TRUE)
  records
}
