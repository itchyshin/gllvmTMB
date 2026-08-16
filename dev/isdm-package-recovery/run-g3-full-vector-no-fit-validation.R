#!/usr/bin/env Rscript
## Validate G3 design text and pure-logic contract only.
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), mustWork = TRUE)
base <- dirname(script)
source(file.path(base, "g3-full-vector-polish-contract.R"), local = TRUE)
design <- file.path(base, "2026-08-13-g3-full-vector-numerical-admission-design.md")
if (!file.exists(design)) stop("missing G3 design", call. = FALSE)
text <- paste(readLines(design, warn = FALSE), collapse = "\n")
stopifnot(grepl("Case-D", text), grepl("Case C", text), grepl("1e-3", text),
          identical(g3_trial_alphas, 2^-(0:8)))
cat("G3_FULL_VECTOR_NO_FIT_CONTRACT_PASS\n")
