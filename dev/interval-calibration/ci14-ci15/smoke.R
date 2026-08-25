#!/usr/bin/env Rscript
## Deliberately unexecuted CI-14/15 smoke plan.  This file does not fit or
## simulate: it records the pre-run boundary that must be timed before a
## campaign approval request.

source("dev/interval-calibration/ci14-ci15/ci1415-kernels.R")
source("dev/interval-calibration/ci14-ci15/smoke-runners.R")

plan <- ci1415_smoke_plan()
stopifnot(
  identical(plan$execution, "not_run"),
  !isTRUE(plan$would_fit),
  !isTRUE(plan$would_simulate),
  isTRUE(plan$estimate_required_before_run)
)
cat("CI1415_SMOKE_NOT_RUN\n")
