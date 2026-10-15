## Issue #1348: engine = "julia" kernel_latent() required a bit-exactly
## symmetric K (isSymmetric(tol = 0)), rejecting a kernel symmetric to rounding.
## Contract: K is symmetrised with (K + t(K)) / 2 only when
## isSymmetric(K, tol = sqrt(.Machine$double.eps)); a clearly asymmetric K
## still stops with the gate error. The mocked tests stop at gllvm_julia_fit(),
## so the gate runs first and no Julia is started; the live test is gated.

.kernel_1348_fixture <- function(asym = 0, rounding = FALSE) {
  set.seed(1)
  n <- 40L
  df <- expand.grid(
    unit = factor(seq_len(n)),
    trait = factor(paste0("t", 1:4)),
    KEEP.OUT.ATTRS = FALSE
  )
  df$value <- rnorm(nrow(df))
  df$group <- factor(as.integer(df$unit) %% 3L + 1L)
  A <- matrix(rnorm(9), 3)
  K0 <- crossprod(A) + diag(3)
  K <- if (rounding) solve(solve(K0)) else K0 # == K0 up to rounding
  K[1, 2] <- K[1, 2] + asym
  dimnames(K) <- list(levels(df$group), levels(df$group))
  list(df = df, K = K)
}

.kernel_1348_fit <- function(df, K) {
  gllvmTMB(
    value ~ 0 + trait + kernel_latent(group, K = K, d = 1, unique = TRUE),
    data = df, unit = "unit", trait = "trait",
    family = gaussian(), engine = "julia"
  )
}

skip_if_no_julia_1348 <- function() {
  testthat::skip_if_not_installed("JuliaCall")
  if (!nzchar(.gllvm_julia_project_path())) {
    testthat::skip("GLLVModels.jl path not configured (GLLVMODELS_JL_PATH).")
  }
}

test_that("julia kernel_latent() symmetrises a kernel symmetric to rounding before the bridge", {
  fx <- .kernel_1348_fixture(rounding = TRUE)
  ## Premise: the fixture really is asymmetric at the bit level.
  expect_false(isSymmetric(unname(fx$K), tol = 0))
  expect_true(isSymmetric(unname(fx$K), tol = sqrt(.Machine$double.eps)))

  withr::local_envvar(GLLVMODELS_JL_PATH = tempdir())
  sent <- NULL
  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(y, ...) {
      sent <<- list(...)
      stop("STUB: reached gllvm_julia_fit")
    }
  )
  err <- tryCatch(.kernel_1348_fit(fx$df, fx$K), error = function(e) e)
  expect_match(conditionMessage(err), "STUB: reached gllvm_julia_fit", fixed = TRUE)
  expect_false(grepl("GJL-GATE", conditionMessage(err)))
  cov_sent <- sent$sources[[1L]]$covariance
  expect_true(isSymmetric(cov_sent, tol = 0))
  expect_equal(cov_sent, (unname(fx$K) + t(unname(fx$K))) / 2, tolerance = 0)
})

test_that("julia kernel_latent() still stops on a clearly asymmetric kernel (1e-3)", {
  fx <- .kernel_1348_fixture(asym = 1e-3)
  expect_false(isSymmetric(unname(fx$K), tol = sqrt(.Machine$double.eps)))
  withr::local_envvar(GLLVMODELS_JL_PATH = tempdir())
  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(y, ...) stop("STUB: reached gllvm_julia_fit")
  )
  expect_error(
    .kernel_1348_fit(fx$df, fx$K),
    "GJL-GATE-STRUCTURED-TERMS.*kernel K must be exactly symmetric.*max\\|K - t\\(K\\)\\| = 0\\.001"
  )
})

test_that("engine = 'julia' kernel_latent() fits end to end with 1e-12 asymmetry", {
  skip_if_no_julia_1348()
  fx <- .kernel_1348_fixture(asym = 1e-12)
  expect_false(isSymmetric(unname(fx$K), tol = 0))
  K_sym <- (fx$K + t(fx$K)) / 2
  fit <- .kernel_1348_fit(fx$df, fx$K)
  ref <- .kernel_1348_fit(fx$df, K_sym)
  expect_true(is.finite(as.numeric(stats::logLik(fit))))
  ## The bridge receives the same symmetrised kernel either way.
  expect_equal(
    as.numeric(stats::logLik(fit)), as.numeric(stats::logLik(ref)),
    tolerance = 1e-8
  )
})
