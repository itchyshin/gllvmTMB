#!/usr/bin/env Rscript
## Local runner for the canonical bounded q = 2 O3 helper.
source(file.path("tests", "testthat", "helper-aghq-o3.R"))
if (sys.nframe() == 0L && !interactive()) print(o3_q2_gllvm_unit_self_test())
