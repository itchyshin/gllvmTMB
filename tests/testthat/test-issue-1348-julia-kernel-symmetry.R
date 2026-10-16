## Issue #1348: engine = "julia" kernel_latent() required a bit-exactly
## symmetric K (isSymmetric(tol = 0)), rejecting a kernel symmetric to rounding.
## Contract: K is symmetrised with (K + t(K)) / 2 only when the entry-wise
## max|K - t(K)| <= sqrt(eps) * max(1, max|K|); a clearly asymmetric K still
## stops with the gate error, however large K is. The mocked tests stop at
## gllvm_julia_fit(), so the gate runs first and no Julia is started; the live
## test is gated.

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
    "GJL-GATE-STRUCTURED-TERMS.*kernel K must be symmetric to rounding.*max\\|K - t\\(K\\)\\| = 0\\.001"
  )
})

## A 200 x 200 kernel that defeats the averaged gate this one replaced,
## isSymmetric(tol = sqrt(eps)). That check first compares rows 1, 2, m - 1 and
## m, then takes the mean relative difference over the UNEQUAL entries only
## (all.equal(countEQ = FALSE)). So one bad entry in an otherwise bit-symmetric
## K is never diluted. It is diluted when rounding has left most entries
## unequal (the #1348 case) and the entry is outside those four rows. Here:
## 2e-3 / (~0.92 * m * (m - 1) * 9) ~ 6e-9 < sqrt(eps) ~ 1.5e-8.
.kernel_1348_large <- function(bad = 0) {
  m <- 200L
  lv <- sprintf("g%03d", seq_len(m)) # sorts the same in every locale
  K <- 10 * (0.1 * diag(m) + 0.9) # diagonal 10, off-diagonal 9; PD
  K <- K + 1e-14 * matrix(sin(seq_len(m * m)), m) # rounding-level asymmetry
  K[100, 101] <- K[100, 101] + bad
  dimnames(K) <- list(lv, lv)
  set.seed(2)
  df <- expand.grid(
    unit = factor(seq_len(m)), trait = factor(paste0("t", 1:3)),
    KEEP.OUT.ATTRS = FALSE
  )
  df$value <- rnorm(nrow(df))
  df$group <- factor(lv[df$unit], levels = lv)
  list(df = df, K = K)
}

test_that("julia kernel_latent() symmetrises a 200 x 200 kernel with rounding-level asymmetry in every entry", {
  ## Control for the next test: the background alone passes the gate.
  fx <- .kernel_1348_large()
  expect_false(isSymmetric(unname(fx$K), tol = 0))
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
  cov_sent <- sent$sources[[1L]]$covariance
  expect_true(isSymmetric(cov_sent, tol = 0))
  expect_equal(cov_sent, (unname(fx$K) + t(unname(fx$K))) / 2, tolerance = 0)
})

test_that("julia kernel_latent() stops on one 1e-3 entry in a 200 x 200 kernel that isSymmetric() passes", {
  ## No skip: gllvm_julia_fit is mocked, so the gate is exercised without Julia.
  fx <- .kernel_1348_large(bad = 1e-3)
  ## Premise: the averaged check is fooled, the entry-wise one is not. Without
  ## the first line this test could not fail against the old gate.
  expect_true(isSymmetric(unname(fx$K), tol = sqrt(.Machine$double.eps)))
  expect_gt(
    max(abs(fx$K - t(fx$K))),
    sqrt(.Machine$double.eps) * max(1, max(abs(fx$K)))
  )
  withr::local_envvar(GLLVMODELS_JL_PATH = tempdir())
  reached <- FALSE
  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(y, ...) {
      reached <<- TRUE
      stop("STUB: reached gllvm_julia_fit")
    }
  )
  expect_error(
    .kernel_1348_fit(fx$df, fx$K),
    "GJL-GATE-STRUCTURED-TERMS.*kernel K must be symmetric to rounding.*max\\|K - t\\(K\\)\\| = 0\\.001"
  )
  expect_false(reached)
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
