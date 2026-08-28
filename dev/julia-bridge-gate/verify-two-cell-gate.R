#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("usage: verify-two-cell-gate.R ARTIFACT_ROOT CHECK", call. = FALSE)
}
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE)
source(file.path(dirname(script_path), "two-cell-gate-lib.R"), local = TRUE)

marker <- bridge_gate_verify_artifacts(
  normalizePath(args[[1L]], mustWork = TRUE),
  args[[2L]]
)
cat(marker, "\n", sep = "")
