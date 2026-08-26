#!/usr/bin/env Rscript

interval_parse_sbatch_job_id <- function(x) {
  lines <- unlist(strsplit(as.character(x), "\n", fixed = TRUE), use.names = FALSE)
  lines <- trimws(lines)
  job_ids <- lines[grepl("^[0-9]+$", lines)]
  if (length(job_ids) != 1L) {
    stop(
      "sbatch output must contain exactly one numeric job-id line",
      call. = FALSE
    )
  }
  job_ids[[1L]]
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L || !file.exists(args[[1L]])) {
    stop("usage: parse-sbatch-job-id.R SBATCH_OUTPUT", call. = FALSE)
  }
  cat(interval_parse_sbatch_job_id(readLines(args[[1L]], warn = FALSE)), "\n")
}
