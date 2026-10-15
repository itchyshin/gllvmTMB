## Issue #1348: engine = "julia" kernel_latent() required a bit-exactly
## symmetric K (isSymmetric(tol = 0)), rejecting a kernel symmetric to rounding.
## gllvm_julia_fit() is mocked, so no Julia is started: the gate runs first.

.kernel_1348_fixture <- function() {
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
  K <- solve(solve(K0)) # equals K0 up to rounding, not bit-symmetric
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

test_that("julia kernel_latent() accepts a kernel symmetric to rounding and symmetrises it", {
  fx <- .kernel_1348_fixture()
  ## Premise: the fixture really is asymmetric at the bit level.
  expect_false(isSymmetric(unname(fx$K), tol = 0))
  expect_lt(max(abs(fx$K - t(fx$K))), 1e-12)

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
  expect_equal(cov_sent, unname(fx$K), tolerance = 1e-12)
})

test_that("julia kernel_latent() still aborts on a genuinely asymmetric kernel, naming the size", {
  fx <- .kernel_1348_fixture()
  K <- fx$K
  K[1, 2] <- K[1, 2] + 0.1
  withr::local_envvar(GLLVMODELS_JL_PATH = tempdir())
  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(y, ...) stop("STUB: reached gllvm_julia_fit")
  )
  expect_error(
    .kernel_1348_fit(fx$df, K),
    "GJL-GATE-STRUCTURED-TERMS.*max\\|K - t\\(K\\)\\| = 0\\.1.*\\(K \\+ t\\(K\\)\\) / 2"
  )
})
