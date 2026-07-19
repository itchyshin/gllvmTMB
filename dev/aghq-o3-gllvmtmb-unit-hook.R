#!/usr/bin/env Rscript
## Local runner for the canonical O3 gllvmTMB unit-score helper.
source(file.path("tests", "testthat", "helper-aghq-o3.R"))
if (sys.nframe() == 0L && !interactive()) print(o3_gllvm_unit_hook_self_test())
