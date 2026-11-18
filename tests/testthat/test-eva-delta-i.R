## Issue #938: the per-observation EVA Taylor error Delta_i, computed at a
## fitted EVA solution.  Delta_i = E_GH[log p(y | eta)] - EVA surrogate, on the
## SAME variational q (eta ~ N(mu, v)).

test_that("Delta_i is zero when v = 0 and for the Taylor-exact Gaussian family", {
  mu <- c(-1.2, 0, 0.7, 2)
  y <- c(0.3, -0.5, 1.1, 2.5)
  expect_equal(
    .eva_delta_i(y, rep(1, 4), mu, v = rep(0, 4), family = 0L, gaussian_sd = 0.8),
    rep(0, 4), tolerance = 1e-12
  )
  expect_equal(
    .eva_delta_i(y, rep(1, 4), mu, v = c(0.1, 1, 3, 7), family = 0L, gaussian_sd = 0.8),
    rep(0, 4), tolerance = 1e-10
  )
  expect_equal(
    .eva_delta_i(c(0, 1, 1, 0), rep(1, 4), mu, v = rep(0, 4), family = 1L),
    rep(0, 4), tolerance = 1e-12
  )
})

test_that("Poisson Delta_i matches the closed form", {
  ## E[exp(eta)] = exp(mu + v/2), so
  ## Delta = -exp(mu) * (exp(v/2) - 1 - v/2)  (always <= 0).
  mu <- c(-0.5, 0.2, 1.0, 0.3)
  v <- c(0.05, 0.4, 1.5, 0)
  y <- c(0, 2, 5, 1)
  got <- .eva_delta_i(y, rep(1, 4), mu, v, family = 2L, H = 41L)
  expect_equal(got, -exp(mu) * (exp(v / 2) - 1 - v / 2), tolerance = 1e-10)
  expect_true(all(got <= 0))
})

test_that("binomial Delta_i matches independent numerical integration", {
  mu <- c(-1, 0.5, 2, 0)
  v <- c(0.3, 1.2, 2.5, 4)
  y <- c(0, 1, 3, 2)
  n <- c(1, 1, 4, 5)
  ref <- vapply(seq_along(mu), function(i) {
    ell <- function(e) y[i] * e - n[i] * (pmax(e, 0) + log1p(exp(-abs(e))))
    lc <- lchoose(n[i], y[i])
    p <- plogis(mu[i])
    expected <- stats::integrate(function(e) (lc + ell(e)) * dnorm(e, mu[i], sqrt(v[i])),
                                 mu[i] - 12 * sqrt(v[i]), mu[i] + 12 * sqrt(v[i]),
                                 rel.tol = 1e-12)$value
    surrogate <- lc + ell(mu[i]) - 0.5 * v[i] * n[i] * p * (1 - p)
    expected - surrogate
  }, numeric(1))
  got <- .eva_delta_i(y, n, mu, v, family = 1L, H = 61L)
  expect_equal(got, ref, tolerance = 1e-8)
  expect_true(all(abs(got) > 1e-6))
})

test_that("Delta_i shrinks like v^2 (the dropped l'''' term)", {
  d <- function(v) .eva_delta_i(1, 1, 0.4, v, family = 1L, H = 21L)
  expect_equal(d(0.02) / d(0.01), 4, tolerance = 0.02)
})

test_that(".eva_delta_i() validates its input", {
  expect_error(.eva_delta_i(1, 1, 0, v = -1, family = 1L), "non-negative")
  expect_error(.eva_delta_i(1, 1, c(0, 1), v = 1, family = 1L), "length")
  expect_error(.eva_delta_i(1, 1, 0, v = 1, family = 9L), "family")
})

test_that(".eva_delta_summary() reports tails and concentration", {
  delta <- c(rep(0, 90), rep(-0.001, 9), -1)
  s <- .eva_delta_summary(delta)
  expect_identical(s$n, 100L)
  expect_equal(s$max_abs, 1)
  expect_identical(s$which_max, 100L)
  expect_equal(s$total, sum(delta))
  expect_equal(unname(s$quantiles["100%"]), 1)
  ## One observation carries ~99% of the absolute error.
  expect_gt(s$top_decile_share, 0.99)
  expect_identical(s$n_for_half, 1L)

  diffuse <- .eva_delta_summary(rep(-0.01, 50))
  expect_equal(diffuse$top_decile_share, 0.1)
  expect_identical(diffuse$n_for_half, 25L)

  expect_equal(.eva_delta_summary(rep(0, 5))$top_decile_share, NA_real_)
})

test_that("Delta_i is computable from a fitted EVA solution and ties to the objective", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("jsonlite")
  set.seed(938)
  N <- 25L; T <- 4L
  Lam <- c(1.0, 0.7, -0.5, 0.9)
  z <- rnorm(N)
  unit_id <- rep(seq_len(N) - 1L, each = T)
  trait_id <- rep(seq_len(T) - 1L, times = N)
  eta <- -0.3 + Lam[trait_id + 1L] * z[unit_id + 1L]
  y <- rpois(N * T, exp(eta))
  X <- matrix(1, N * T, 1L)
  fit <- .eva_fit(y, rep(1, N * T), X, unit_id, trait_id, q = 1L, family = "poisson")
  expect_true(fit$status %in% c("healthy", "failed_health_gate"))

  d <- .eva_delta_from_fit(fit, H = 31L)
  expect_s3_class(d$data, "data.frame")
  expect_identical(nrow(d$data), N * T)
  expect_true(all(is.finite(d$data$delta)))
  expect_true(all(d$data$delta <= 1e-12))   # Poisson: Taylor error is one-signed
  expect_identical(d$summary$n, N * T)

  ## The surrogate rebuilt here must equal the C++ expected log-likelihood.
  rep <- fit$report
  surrogate <- y * rep$mu_by_obs - exp(rep$mu_by_obs) - lgamma(y + 1) -
    0.5 * rep$v_by_obs * exp(rep$mu_by_obs)
  expect_equal(sum(surrogate), rep$expected_loglik, tolerance = 1e-9)
  expect_equal(d$data$surrogate, surrogate, tolerance = 1e-12)

  bad <- fit; bad$report <- NULL
  expect_error(.eva_delta_from_fit(bad), "report")
})
