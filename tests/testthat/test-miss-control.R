# Tests for miss_control() -- the missing-data control-list factory.
# Phase 1, sub-slice 1 (issue #334), updated for Phase 2a (design 67):
# predictor = "fail" (default) and predictor = "model" (the mi() Gaussian
# missing-predictor surface) are both accepted; engine = "laplace" only with
# "em"/"profile" reserved names; there is NO estimator argument. response =
# "drop" is the default and equals today's complete-case behaviour.

# ---- defaults -------------------------------------------------------------

test_that("miss_control(): defaults are response='drop', predictor='fail', engine='laplace'", {
  mc <- miss_control()
  expect_type(mc, "list")
  expect_identical(mc$response, "drop")
  expect_identical(mc$predictor, "fail")
  expect_identical(mc$engine, "laplace")
})

test_that("miss_control(): response='include' is accepted and recorded", {
  mc <- miss_control(response = "include")
  expect_identical(mc$response, "include")
  expect_identical(mc$predictor, "fail")
  expect_identical(mc$engine, "laplace")
})

# ---- response / predictor / engine validation -----------------------------

test_that("miss_control(): unknown response errors via match.arg", {
  expect_error(miss_control(response = "impute"), regexp = "should be one of")
})

test_that("miss_control(): predictor='model' is accepted (Phase 2a mi() surface)", {
  # Phase 2a (design 67) implements predictor = "model": the mi() latent-
  # covariate grammar for one continuous Gaussian missing predictor. It is now
  # a valid value (was reserved-but-not-yet in Phase 1 sub-slice 1).
  mc <- miss_control(predictor = "model")
  expect_identical(mc$predictor, "model")
  expect_identical(mc$response, "drop")
  expect_identical(mc$engine, "laplace")
})

test_that("miss_control(): unknown predictor errors via match.arg", {
  expect_error(miss_control(predictor = "drop"), regexp = "should be one of")
})

test_that("miss_control(): engine='em' is reserved, not yet supported", {
  expect_error(
    miss_control(engine = "em"),
    regexp = "(?i)reserved|not yet supported",
    perl = TRUE
  )
})

test_that("miss_control(): engine='profile' is reserved, not yet supported", {
  expect_error(
    miss_control(engine = "profile"),
    regexp = "(?i)reserved|not yet supported",
    perl = TRUE
  )
})

test_that("miss_control(): unknown engine errors", {
  expect_error(miss_control(engine = "mcmc"))
})

# ---- estimator is NOT a public v1 argument --------------------------------

test_that("miss_control(): estimator= is rejected with a clear error", {
  # ML is the internal default; the public estimator= arg is deferred (design
  # 59 sec.4 / sec.10). Passing it must error, not be silently swallowed.
  expect_error(
    miss_control(estimator = "REML"),
    regexp = "(?i)estimator",
    perl = TRUE
  )
  expect_error(
    miss_control(estimator = "ML"),
    regexp = "(?i)estimator",
    perl = TRUE
  )
})
