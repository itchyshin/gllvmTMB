## Limit behaviour of the exact randomized-quantile residuals
## (`.gllvmTMB_exact_rq_residuals()` in R/predictive-diagnostics.R):
##   * #1490: beta-binomial shapes at large |eta| (1 - plogis(eta) == 0
##     for eta >= 37 zeroed `b` and the CDF came back NaN);
##   * #1491: an infinite reported dispersion is the Poisson / zero-truncated
##     Poisson / normal limit in the engine, not a missing parameter.
##
## No model is fitted: the residual function only reads a handful of fields
## from the fit, so a minimal fit-shaped list pins the contract directly and
## lets each row carry an arbitrary eta / dispersion.

fake_limit_fit <- function(family_id, y, eta, report = list(), n_trials = NULL) {
  n <- length(y)
  structure(
    list(
      tmb_data = list(
        y = y,
        family_id_vec = rep(as.integer(family_id), n),
        link_id_vec = rep(0L, n),
        trait_id = rep(0L, n),
        n_trials = if (is.null(n_trials)) rep(1, n) else rep(n_trials, n)
      ),
      report = c(list(eta = eta), report),
      data = data.frame(trait = rep("t1", n)),
      trait_col = "trait",
      use = list()
    ),
    class = c("gllvmTMB_multi", "gllvmTMB")
  )
}

exact_limit <- function(fit, seed = 1L) {
  gllvmTMB:::.gllvmTMB_exact_rq_residuals(fit, seed = seed)
}

test_that("beta-binomial residuals stay finite where 1 - plogis(eta) is 0 (#1490)", {
  N <- 5
  ## plogis(37) is exactly 1 in double; 1 - plogis(37) is 0.
  expect_identical(stats::plogis(37), 1)
  eta <- c(-40, -37, 0, 37, 40, 100)
  fit <- fake_limit_fit(
    8L, y = c(0, 0, 2, 5, 5, 5), eta = eta,
    report = list(phi_betabinom = 10), n_trials = N
  )
  res <- exact_limit(fit)

  expect_equal(res$status, rep("ok", length(eta)))
  expect_true(all(is.finite(res$residual)))
  expect_true(all(is.finite(res$cdf_lower) & is.finite(res$cdf_upper)))
  expect_true(all(res$cdf_lower >= 0 & res$cdf_upper <= 1 + 1e-12))
  expect_true(all(res$cdf_lower <= res$cdf_upper))

  ## At the saturated end y = N has probability ~ 1, so the interval is
  ## [~0, 1] (cdf_lower = P(Y <= N - 1) is tiny); at the other end y = 0 has
  ## probability ~ 1, so it is [0, ~1].
  expect_equal(res$cdf_upper[c(4, 5, 6)], rep(1, 3), tolerance = 1e-12)
  expect_lt(res$cdf_lower[6], 1e-6)
  expect_equal(res$cdf_lower[1], 0)
  expect_equal(res$cdf_upper[1], 1, tolerance = 1e-12)
})

test_that("beta-binomial residual at large eta matches the binomial limit (#1490)", {
  ## For phi >> 1 the beta-binomial pmf tends to the binomial pmf, so the
  ## upper CDF at an interior y must agree with pbinom to ~ 1/phi even where
  ## the old `1 - plogis(eta)` form was already 0.
  N <- 10
  fit <- fake_limit_fit(
    8L, y = 9, eta = 36,
    report = list(phi_betabinom = 1e8), n_trials = N
  )
  res <- exact_limit(fit)
  expect_equal(res$status, "ok")
  expect_equal(res$cdf_upper, stats::pbinom(9, N, stats::plogis(36)),
    tolerance = 1e-6
  )
  ## and the symmetric form is what keeps the boundary shape representable
  expect_gt(stats::plogis(-37) * 10, 0)
})

test_that("beta-binomial rows whose shape underflows get an explicit status (#1490)", {
  ## plogis(-1000) is 0 in double, so no representable shape exists.
  fit <- fake_limit_fit(
    8L, y = c(5, 0), eta = c(1000, -1000),
    report = list(phi_betabinom = 10), n_trials = 5
  )
  res <- exact_limit(fit)
  expect_equal(res$status, rep("nonfinite_residual", 2))
  expect_true(all(is.na(res$residual)))
})

test_that("infinite NB2 dispersion is the Poisson limit, not missing_phi (#1491)", {
  eta <- c(0.3, 0.9, 1.2)
  y <- c(0, 2, 5)
  fit <- fake_limit_fit(5L, y = y, eta = eta, report = list(phi_nbinom2 = Inf))
  res <- exact_limit(fit)
  expect_equal(res$status, rep("ok", 3))

  mu <- exp(eta)
  expect_equal(res$cdf_upper, stats::ppois(y, mu))
  expect_equal(res$cdf_lower, c(0, stats::ppois(y[-1] - 1, mu[-1])))
  ## large finite size agrees with the infinite one
  big <- exact_limit(
    fake_limit_fit(5L, y = y, eta = eta, report = list(phi_nbinom2 = 1e300))
  )
  expect_equal(big$cdf_upper, res$cdf_upper)
})

test_that("infinite zero-truncated NB2 dispersion is the ZT-Poisson limit (#1491)", {
  eta <- c(0.3, 0.9, 1.2)
  y <- c(1, 2, 5)
  fit <- fake_limit_fit(11L, y = y, eta = eta, report = list(phi_truncnb2 = Inf))
  res <- exact_limit(fit)
  expect_equal(res$status, rep("ok", 3))

  mu <- exp(eta)
  p0 <- exp(-mu)
  expect_equal(res$cdf_upper, (stats::ppois(y, mu) - p0) / (1 - p0))
  expect_equal(
    res$cdf_lower,
    c(0, (stats::ppois(y[-1] - 1, mu[-1]) - p0[-1]) / (1 - p0[-1]))
  )
})

test_that("infinite Student-t df is the normal limit, not missing_phi (#1491)", {
  eta <- c(-0.5, 0, 1)
  y <- c(0.2, 0.1, 2.5)
  fit <- fake_limit_fit(
    9L, y = y, eta = eta,
    report = list(sigma_student = 1.5, df_student = Inf)
  )
  res <- exact_limit(fit)
  expect_equal(res$status, rep("ok", 3))
  expect_equal(res$cdf_upper, stats::pnorm((y - eta) / 1.5))
})

test_that("genuinely missing dispersions still report missing_phi", {
  y <- c(1, 2)
  eta <- c(0.5, 0.5)
  cases <- list(
    list(5L, list(phi_nbinom2 = NaN)),
    list(5L, list(phi_nbinom2 = NA_real_)),
    list(5L, list(phi_nbinom2 = 0)),
    list(5L, list(phi_nbinom2 = -1)),
    list(5L, list(phi_nbinom2 = -Inf)),
    list(11L, list(phi_truncnb2 = NaN)),
    list(11L, list(phi_truncnb2 = 0)),
    list(11L, list(phi_truncnb2 = -Inf)),
    list(9L, list(sigma_student = 1, df_student = NaN)),
    list(9L, list(sigma_student = 1, df_student = 1)),
    list(9L, list(sigma_student = Inf, df_student = 5))
  )
  for (case in cases) {
    res <- exact_limit(fake_limit_fit(case[[1]], y = y, eta = eta, report = case[[2]]))
    expect_equal(res$status, rep("missing_phi", 2), info = deparse(case))
    expect_true(all(is.na(res$residual)), info = deparse(case))
  }
})
