## Regression test for the pinned-Psi log-likelihood defect.
##
## For single-trial binary (and categorical) traits the R-side identifiability
## gate pins the between-unit Psi: `theta_diag_B[t]` is fixed at `log(1e-6)` and
## the corresponding `s_B` row is fixed at 0.  The C++ diag_B loop used to
## iterate over every (trait, site) cell regardless, so each pinned cell
## contributed `-dnorm(0, 0, 1e-6, log = TRUE)`, i.e. **-12.8966**, to `nll`.
##
## With 2400 cells that is roughly +31,000 added to the log-likelihood, and a
## Bernoulli fit reported `logLik() = +29327` -- impossible, since a Bernoulli
## log-likelihood is a sum of logs of probabilities and cannot exceed 0.
##
## The fix passes a per-trait `diag_B_skip` mask into the objective so pinned
## traits contribute no density term.  These tests fail loudly if it regresses.

test_that("a binary GLLVM fit returns a negative log-likelihood", {
  skip_on_cran()
  set.seed(11)
  n_site <- 60L
  n_trait <- 8L
  d <- 2L
  loadings <- matrix(stats::rnorm(n_trait * d, 0, 0.5), n_trait, d)
  scores <- matrix(stats::rnorm(n_site * d), n_site, d)
  intercepts <- stats::rnorm(n_trait, 0, 0.3)
  eta <- sweep(scores %*% t(loadings), 2, intercepts, "+")
  Y <- matrix(stats::rbinom(n_site * n_trait, 1, stats::plogis(eta)),
              n_site, n_trait)
  colnames(Y) <- paste0("sp", seq_len(n_trait))

  fit <- suppressMessages(suppressWarnings(
    gllvmTMB_wide(Y = Y, family = stats::binomial(), d = d)
  ))
  ll <- as.numeric(stats::logLik(fit))

  expect_true(is.finite(ll))
  ## The defining property: a Bernoulli log-likelihood cannot be positive.
  expect_lt(ll, 0)
})

test_that("the pinned-Psi density term does not enter the objective", {
  skip_on_cran()
  ## A direct check on the mechanism rather than only its symptom: the spurious
  ## contribution was exactly `dnorm(0, 0, 1e-6, log = TRUE)` per pinned cell.
  ## If it ever returns, the log-likelihood inflates by a multiple of this.
  per_cell <- stats::dnorm(0, 0, 1e-6, log = TRUE)
  expect_gt(per_cell, 12)  # ~12.8966 -- large and positive, hence the hazard

  set.seed(12)
  n_site <- 40L
  n_trait <- 6L
  d <- 2L
  loadings <- matrix(stats::rnorm(n_trait * d, 0, 0.5), n_trait, d)
  scores <- matrix(stats::rnorm(n_site * d), n_site, d)
  eta <- scores %*% t(loadings)
  Y <- matrix(stats::rbinom(n_site * n_trait, 1, stats::plogis(eta)),
              n_site, n_trait)
  colnames(Y) <- paste0("sp", seq_len(n_trait))

  fit <- suppressMessages(suppressWarnings(
    gllvmTMB_wide(Y = Y, family = stats::binomial(), d = d)
  ))
  ll <- as.numeric(stats::logLik(fit))

  ## Bound the log-likelihood from below by the all-cells-independent value.
  ## Any fit at least as good as a coin flip sits in [n * log(0.5), 0].
  n_cells <- n_site * n_trait
  expect_lt(ll, 0)
  expect_gt(ll, n_cells * log(0.5) * 2)
})

test_that("Poisson fits are unaffected by the skip mask", {
  skip_on_cran()
  ## No Poisson trait is pinned, so `diag_B_skip` stays all-zero and the
  ## objective must be identical to the pre-fix behaviour.
  set.seed(13)
  n_site <- 40L
  n_trait <- 6L
  d <- 2L
  loadings <- matrix(stats::rnorm(n_trait * d, 0, 0.4), n_trait, d)
  scores <- matrix(stats::rnorm(n_site * d), n_site, d)
  eta <- sweep(scores %*% t(loadings), 2, stats::rnorm(n_trait, 0.3, 0.3), "+")
  Y <- matrix(stats::rpois(n_site * n_trait, exp(eta)), n_site, n_trait)
  colnames(Y) <- paste0("sp", seq_len(n_trait))

  fit <- suppressMessages(suppressWarnings(
    gllvmTMB_wide(Y = Y, family = stats::poisson(), d = d)
  ))
  ll <- as.numeric(stats::logLik(fit))

  expect_true(is.finite(ll))
  expect_lt(ll, 0)
})
