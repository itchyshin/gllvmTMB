#!/usr/bin/env Rscript
## Local runner for the canonical O3 numerical helper. The helper lives under
## tests/ because dev/ is excluded from R CMD build.
source(file.path("tests", "testthat", "helper-aghq-o3.R"))
if (sys.nframe() == 0L && !interactive()) print(o3_scalar_self_test())
