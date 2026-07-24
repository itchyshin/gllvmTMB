#!/usr/bin/env Rscript
d99_args <- commandArgs(trailingOnly = TRUE)
d99_arg <- function(flag, default = NULL) { i <- match(flag, d99_args); if (is.na(i)) default else d99_args[[i + 1L]] }
d99_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
d99_here <- normalizePath(file.path(dirname(d99_file), ".."), mustWork = TRUE)
source(file.path(d99_here, "R", "records.R"))
root <- d99_arg("--output-root")
if (is.null(root) || identical(d99_arg("--mode"), "REAL_RUN")) stop("Preflight is control-only; no REAL_RUN may be created here", call. = FALSE)
task <- list(task_id = "preflight", task_class = "preflight", run_id = d99_arg("--run-id", "NON_EVIDENCE"))
input <- list(schema = "d99-preflight-input-v1", task_id = "preflight", task_class = "preflight", run_id = task$run_id,
              dependencies = list(), contract_hash = d99_arg("--contract-hash", "NON_EVIDENCE"), source_hashes = list(),
              runtime = d99_runtime_metadata(), mode = "NON_EVIDENCE")
ih <- d99_sha256_object(input)
d99_write_terminal(root, task, "PASS", ih, list(mode = "NON_EVIDENCE", preflight_only = TRUE))
