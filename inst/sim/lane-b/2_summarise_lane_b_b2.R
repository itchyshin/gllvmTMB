#!/usr/bin/env Rscript
args0 <- commandArgs(trailingOnly = FALSE)
self <- sub("^--file=", "", args0[grepl("^--file=", args0)])[[1L]]
source(file.path(dirname(normalizePath(self)), "lane-b-b2-runner.R"))
lane_b_main(c("aggregate", commandArgs(trailingOnly = TRUE)))
