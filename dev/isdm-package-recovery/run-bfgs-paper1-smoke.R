#!/usr/bin/env Rscript
## Paper-1 entry point for the shared private exact-gradient BFGS runner.

Sys.setenv(GLLVM_BFGS_SMOKE_PAPER = "paper1")
script <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
  mustWork = TRUE
)
source(file.path(dirname(script), "run-bfgs-paper2-smoke.R"), local = globalenv())
