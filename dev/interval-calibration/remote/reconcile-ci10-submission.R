#!/usr/bin/env Rscript

if (!exists("interval_parse_sbatch_job_id", inherits = FALSE)) {
  sys.source("dev/interval-calibration/remote/parse-sbatch-job-id.R")
}

interval_reconciliation_sha256 <- function(path) {
  out <- system2("sha256sum", path, stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    stop("sha256sum failed for reconciliation input: ", path, call. = FALSE)
  }
  sub("[[:space:]].*$", "", out[[1L]])
}

interval_reconciliation_tsv <- function(path) {
  x <- utils::read.delim(
    path,
    header = FALSE,
    col.names = c("key", "value"),
    stringsAsFactors = FALSE,
    quote = "",
    check.names = FALSE
  )
  value <- function(key) {
    hit <- x$value[x$key == key]
    if (length(hit) != 1L || !nzchar(hit)) {
      stop("ambiguous submission receipt has invalid key: ", key, call. = FALSE)
    }
    hit[[1L]]
  }
  value
}

interval_reconcile_ci10_submission <- function(root, sacct_lines) {
  root <- normalizePath(root, mustWork = TRUE)
  operations <- file.path(root, "operations")
  ambiguous <- file.path(
    operations,
    "ci10-cost-array-submission-ambiguous.tsv"
  )
  output <- file.path(root, "slurm", "submission-output.txt")
  receipt <- file.path(
    operations,
    "ci10-cost-array-submission-reconciled.tsv"
  )
  if (file.exists(receipt)) {
    stop("reconciliation receipt already exists", call. = FALSE)
  }
  if (!file.exists(ambiguous) || !file.exists(output)) {
    stop("reconciliation requires the ambiguous receipt and raw sbatch output", call. = FALSE)
  }
  value <- interval_reconciliation_tsv(ambiguous)
  job_id <- interval_parse_sbatch_job_id(
    readLines(output, warn = FALSE)
  )
  if (
    !identical(
      value("schema"),
      "INTERVAL_CALIBRATION_CI10_SUBMISSION_AMBIGUOUS_V1"
    ) ||
      !identical(value("packet"), "CI10_COST") ||
      !grepl("^[0-9a-f]{40}$", value("source_sha")) ||
      !grepl("^[0-9a-f]{64}$", value("task_manifest_sha256")) ||
      !identical(value("output_root"), root) ||
      !identical(value("submission_exit_status"), "0") ||
      !identical(normalizePath(value("submission_output"), mustWork = TRUE), output)
  ) {
    stop("ambiguous submission receipt conflicts with the campaign root", call. = FALSE)
  }

  records <- strsplit(
    trimws(sacct_lines[nzchar(trimws(sacct_lines))]),
    "|",
    fixed = TRUE
  )
  matches <- vapply(
    records,
    function(fields) {
      length(fields) >= 3L &&
        identical(fields[[1L]], job_id) &&
        identical(fields[[2L]], "gllvmtmb-ci10-cost")
    },
    logical(1)
  )
  if (sum(matches) != 1L) {
    stop("sacct evidence must contain exactly one matching CI-10 array job", call. = FALSE)
  }
  record <- records[[which(matches)]]
  if (!nzchar(record[[3L]]) || identical(record[[3L]], "UNKNOWN")) {
    stop("sacct evidence has no usable job state", call. = FALSE)
  }

  lines <- c(
    "schema\tINTERVAL_CALIBRATION_CI10_SUBMISSION_RECONCILED_V1",
    "packet\tCI10_COST",
    paste0("source_sha\t", value("source_sha")),
    paste0("task_manifest_sha256\t", value("task_manifest_sha256")),
    paste0("output_root\t", root),
    "submission_exit_status\t0",
    paste0("job_id\t", job_id),
    paste0("sacct_job_name\t", record[[2L]]),
    paste0("sacct_state_at_reconciliation\t", record[[3L]]),
    paste0("sacct_record\t", paste(record, collapse = "|")),
    paste0(
      "ambiguous_receipt_sha256\t",
      interval_reconciliation_sha256(ambiguous)
    ),
    paste0("submission_output_sha256\t", interval_reconciliation_sha256(output)),
    paste0(
      "recorded_at_utc\t",
      format(Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
    )
  )
  tmp <- paste0(receipt, ".tmp.", Sys.getpid())
  writeLines(lines, tmp, useBytes = TRUE)
  if (!file.rename(tmp, receipt)) {
    unlink(tmp)
    stop("failed to atomically write reconciliation receipt", call. = FALSE)
  }
  receipt
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L || !file.exists(args[[2L]])) {
    stop(
      "usage: reconcile-ci10-submission.R CAMPAIGN_ROOT SACCT_EVIDENCE",
      call. = FALSE
    )
  }
  cat(
    "INTERVAL_CI10_SUBMISSION_RECONCILED ",
    interval_reconcile_ci10_submission(
      args[[1L]],
      readLines(args[[2L]], warn = FALSE)
    ),
    "\n",
    sep = ""
  )
}
