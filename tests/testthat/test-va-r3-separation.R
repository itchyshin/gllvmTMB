test_that("R3 admits a non-separated binomial design and reports its diagnostic", {
  set.seed(20260730L)
  n <- 60L
  X <- cbind(1, stats::rnorm(n))
  eta <- drop(X %*% c(0.2, 0.5))
  n_trials <- rep(5L, n)
  y <- stats::rbinom(n, n_trials, stats::plogis(eta))

  diag <- .va_r3_check_separation(y, n_trials, X)

  expect_true(is.finite(diag$max_abs_eta))
  expect_lt(diag$drift, diag$drift_limit)
  expect_lt(diag$max_abs_eta, diag$eta_limit)
})

test_that("R3 refuses a completely separated Bernoulli design", {
  ## The regime the n_trials >= 1 relaxation admitted: pure 0/1 responses whose
  ## fixed-effect design predicts them perfectly, so the marginal MLE is at
  ## infinity and only the optimiser's tolerance decides where it stops.
  n <- 40L
  z <- rep(c(0, 1), each = n / 2L)
  X <- cbind(1, z)
  y <- as.integer(z)
  n_trials <- rep(1L, n)

  expect_error(.va_r3_check_separation(y, n_trials, X), "separat")
})

test_that("the separation guard is wired into binomial validation, not merely defined", {
  n <- 40L
  z <- rep(c(0, 1), each = n / 2L)
  X <- cbind(1, z)
  y <- as.integer(z)

  expect_error(
    .va_r3_validate_data(
      y = y, n_trials = rep(1L, n), X = X,
      unit_id = rep(seq_len(n / 2L), each = 2L),
      trait_id = rep(seq_len(2L), times = n / 2L),
      q = 1L, family = "binomial", link = "logit"
    ),
    "separat"
  )
})

test_that("detection is by divergence, so a large but finite design is admitted", {
  ## eta_limit alone is only a backstop; a design with genuinely large finite
  ## coefficients must NOT be refused just for being large.
  set.seed(11L)
  n <- 200L
  X <- cbind(1, stats::rnorm(n))
  eta <- drop(X %*% c(0, 3))
  n_trials <- rep(10L, n)
  y <- stats::rbinom(n, n_trials, stats::plogis(eta))

  expect_no_error(.va_r3_check_separation(y, n_trials, X))
})
