## #25: the "Ayumi-shaped" standing fixture.
##
## WHY this exists: every fixture in this suite up to #25 was either small
## (n ~ 30, p ~ 3-4) or unridged (default `aghq_ridge` left at Inf in most
## hand-built test fixtures, even though the package default is 2). Ayumi's
## real corpus fits single-trial Bernoulli GLLVMs with 44-71 traits and the
## ridge ON by default -- a configuration none of our goldens exercised. The
## first user running ridge-on at that scale found in days (#1092's
## penalised-gradient misread of `converged`; #25's B1 boundary-flag false
## positive; B2's missing `fitted()` method) what the suite structurally
## could not, because nothing in it combined "many traits", "ridge on", and
## "single-trial Bernoulli" in one fit. This file is the standing guard
## against that class recurring: a moderate-width (p = 12, n = 60, d = 2),
## ridge-on, single-trial-Bernoulli fit that exercises B1 + B2 + #1092
## together, at a scale a hand-picked p=3 unit test cannot stand in for.
##
## This is a behavioural-contract test, not a recovery test: it asserts the
## fit reports itself converged and coherent, not that it recovers truth.

.ayumi_shaped_fit <- function(seed = 2501L, n = 60L, p = 12L, d = 2L) {
  set.seed(seed)
  L <- matrix(stats::rnorm(p * d), p, d)
  u <- matrix(stats::rnorm(n * d), n, d)
  eta <- u %*% t(L)
  Y <- matrix(stats::rbinom(n * p, 1, stats::plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  dat <- as.data.frame(Y)
  dat$site <- factor(seq_len(n))
  lhs <- paste(colnames(Y), collapse = ", ")
  form <- stats::as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = %d)", lhs, d
  ))
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    form,
    data = dat,
    family = stats::binomial(),
    control = gllvmTMB::gllvmTMBcontrol(
      aghq_ridge = 2, se = FALSE, warn_runaway = FALSE
    )
  )))
}

test_that("#25: Ayumi-shaped fixture (p = 12, n = 60, d = 2, ridge on) is a coherent, converged, fully-instrumented fit", {
  skip_on_cran()

  fit <- .ayumi_shaped_fit()
  n <- 60L
  p <- 12L

  ## (1) fit returns and converged by the optimiser's own account.
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_identical(fit$opt$convergence, 0L)

  ## (2) #1092: the penalised-gradient path is exercised at user scale --
  ## fit_health must judge the RIDGED objective, not the raw one.
  expect_true(isTRUE(fit$aghq$penalised))
  expect_true(isTRUE(fit$fit_health$gradient_is_penalised))
  expect_true(isTRUE(fit$fit_health$converged))

  ## (3) B2: fitted() returns the long data.frame, one row per observation.
  ft <- fitted(fit)
  expect_false(is.null(ft))
  expect_s3_class(ft, "data.frame")
  expect_equal(nrow(ft), n * p)

  ## (4) B1: every trait is single-trial Bernoulli, so the auto-Psi skip
  ## block maps every coordinate off -- the exact diag_B_skip case -- and
  ## none of that plumbing residue may read as a boundary problem.
  expect_true(all(fit$tmb_data$diag_B_skip == 1L))
  expect_false("near_zero_sd_B" %in% fit$fit_health$boundary_flags)
})
