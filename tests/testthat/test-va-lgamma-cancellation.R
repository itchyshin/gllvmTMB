## #1482: the VA template (inst/tmb/gllvmTMB_va_r3.cpp, a separate tape) formed
## the same cancelling lgamma sums that #1479 fixed in the Laplace template.
## At large dispersion each lgamma carries ~1e-3 absolute rounding error while
## the true difference tends to 0. Each test sends one observation through the
## compiled VA row log-likelihood with the latent variance at 0 (so the row
## value is the plain density at eta = mu) and compares it with a reference
## built from log1p sums, which never form an O(x log x) term.

skip_on_cran()

.va_lg_row <- function(family_id, y, mu, par_name, par_value, n = 1) {
  validated <- .va_r3_validate_data(
    y = y, n_trials = n, X = matrix(1, 1L, 1L), unit_id = 1L, trait_id = 1L,
    q = 1L, N = 1L, T = 1L, family_codes = family_id, link_ids = 0L,
    n_ordinal_cuts_per_trait = 0L, ordinal_offset_per_trait = 0L,
    ordinal_log_increments_start = numeric(0)
  )
  parameters <- .va_r3_default_parameters(validated)
  parameters$beta[] <- mu
  parameters$theta_rr[] <- 0
  parameters$m[] <- 0
  parameters$log_L_diag[] <- 0
  parameters[[par_name]][] <- log(par_value)
  obj <- tryCatch(
    .va_r3_make_objective(validated, H = 7L, parameters = parameters,
                          eval_method = "gh", rebuild = FALSE, silent = TRUE),
    error = function(e) NULL
  )
  if (is.null(obj)) testthat::skip("VA template does not compile")
  unname(obj$report(obj$par)$expected_loglik_by_obs[[1L]])
}

## sum_{k < n} log1p(k / x) = lgamma(x + n) - lgamma(x) - n log(x), n integer.
.va_lg_shift <- function(log_x, n) {
  if (n == 0) return(0)
  k <- 0:(n - 1)
  sum(log1p(k / exp(log_x)))
}

test_that("VA NB2 row matches dnbinom/dpois at size 1e3, 1e8, 1e12 (#1482)", {
  mu <- 1.2
  for (y in c(0, 3)) {
    for (phi in c(1e3, 1e8, 1e12)) {
      got <- .va_lg_row(5L, y, mu, "log_phi_nbinom2", phi)
      ref <- stats::dnbinom(y, mu = exp(mu), size = phi, log = TRUE)
      expect_lt(abs(got - ref), 1e-8)
    }
    expect_lt(abs(.va_lg_row(5L, y, mu, "log_phi_nbinom2", 1e12) -
                    stats::dpois(y, exp(mu), log = TRUE)), 1e-8)
  }
})

test_that("VA beta-binomial row matches a log1p-sum reference at large phi (#1482)", {
  mu <- 0.3
  n <- 7
  y <- 3
  log_p <- -log1p(exp(-mu))
  log_1mp <- -log1p(exp(mu))
  for (phi in c(1e2, 1e8, 1e12)) {
    lp <- log(phi)
    ref <- lchoose(n, y) + .va_lg_shift(lp + log_p, y) + y * (lp + log_p) +
      .va_lg_shift(lp + log_1mp, n - y) + (n - y) * (lp + log_1mp) -
      .va_lg_shift(lp, n) - n * lp
    got <- .va_lg_row(8L, y, mu, "log_phi_betabinom", phi, n = n)
    expect_lt(abs(got - ref), 1e-8)
  }
})

test_that("VA beta row matches a Stirling-difference reference at large phi (#1482)", {
  mu <- 0.3
  y <- 0.35
  ## The template floors the latent variance at 1e-12 and always integrates
  ## over the 7-node Gauss-Hermite rule, so the reference does the same.
  H <- 7L
  jac <- matrix(0, H, H)
  jac[cbind(1:(H - 1), 2:H)] <- jac[cbind(2:H, 1:(H - 1))] <- sqrt((1:(H - 1)) / 2)
  ev <- eigen(jac, symmetric = TRUE)
  nodes <- ev$values
  weights <- sqrt(pi) * ev$vectors[1L, ]^2
  one_node <- function(eta, phi) {
    p <- plogis(eta)
    a <- phi * p
    b <- phi * (1 - p)
    ## lgamma(phi) - lgamma(a) - lgamma(b), Stirling with a + b = phi.
    lg <- 0.5 * log(phi) - 0.5 * log(2 * pi) - (a - 0.5) * plogis(eta, log.p = TRUE) -
      (b - 0.5) * plogis(-eta, log.p = TRUE) +
      (1 / phi - 1 / a - 1 / b) / 12 - (1 / phi^3 - 1 / a^3 - 1 / b^3) / 360
    lg + (a - 1) * log(y) + (b - 1) * log1p(-y)
  }
  for (phi in c(1e3, 1e5, 1e8)) {
    ref <- sum(weights * vapply(mu + sqrt(2e-12) * nodes, one_node, 0, phi = phi)) /
      sqrt(pi)
    got <- .va_lg_row(7L, y, mu, "log_phi_beta", phi)
    ## the data terms are O(phi): allow their own rounding floor.
    expect_lt(abs(got - ref), 1e-8 + 1e-15 * phi)
  }
})

test_that("VA lgamma kernels keep moderate-phi values (#1482)", {
  ## reference computed from the pre-fix direct lgamma formulas
  mu <- 0.4; phi <- 3.5
  expect_equal(.va_lg_row(5L, 2, mu, "log_phi_nbinom2", phi),
               stats::dnbinom(2, mu = exp(mu), size = phi, log = TRUE),
               tolerance = 1e-12)
  expect_equal(.va_lg_row(8L, 3, mu, "log_phi_betabinom", phi, n = 7),
               {
                 a <- phi * plogis(mu); b <- phi * plogis(-mu)
                 lchoose(7, 3) + lgamma(3 + a) + lgamma(4 + b) - lgamma(a) -
                   lgamma(b) - lgamma(7 + phi) + lgamma(phi)
               },
               tolerance = 1e-12)
})
