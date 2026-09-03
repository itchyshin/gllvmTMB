options(Matrix.warnDeprecatedCoerce = 2)

library(testthat)
library(gllvmTMB)

# Repository CI shards the full suite across parallel jobs via
# GLLVMTMB_TEST_SHARD ("k/N"); unset means run everything, so a local
# devtools::test() is unchanged. The helper lives under testthat/ so R CMD check
# does not execute it as a test file in its own right, and is sourced here
# because the filter has to exist BEFORE test_check() is called.
#
# This is orthogonal to the GLLVMTMB_HEAVY_TESTS gate in testthat/setup.R:
# that decides WHICH tests run at all, this splits whatever is left across jobs.
source(file.path("testthat", "helper-shard-util.R"), local = TRUE)
gllvm_shard <- gllvm_shard_filter()

if (is.null(gllvm_shard)) {
  test_check("gllvmTMB")
} else {
  test_check("gllvmTMB", filter = gllvm_shard)
}
