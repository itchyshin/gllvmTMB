## Interpolate the profile bound on the ZETA scale, not the deviance scale.
##
## zeta = sign(theta - theta_hat) * sqrt(2 * (nll_profile - nll_hat)).
## For an exactly quadratic log-likelihood, zeta is EXACTLY LINEAR in theta, so
## linear interpolation in zeta is exact while linear interpolation in deviance
## carries curvature error that grows with grid spacing.
##
## Design lead: MixedModels.jl builds interpolation splines on the zeta scale
## (`MixedModelProfile`, `profile(m; threshold = 4)`), documented 2026-07-28 in
## docs/dev-log/2026-07-28-mixedmodels-jl-profile-lead.md. Read for design only;
## no code ported.
##
## Note the crossing threshold on the zeta scale is exactly the normal quantile:
##   |zeta| = sqrt(2 * crit) = sqrt(qchisq(level, 1)) = qnorm((1 + level) / 2).

mk_prof <- function(par, value) data.frame(par = par, value = value)

## An exactly quadratic profile: nll = mle + 0.5 * a * (p - phat)^2.
## Crossing where 0.5 * a * (p - phat)^2 = crit  =>  p = phat +/- sqrt(2*crit/a).
quad_prof <- function(a = 2, phat = 0, mle = 100, by = 0.5, span = 4) {
  p <- seq(phat - span, phat + span, by = by)
  mk_prof(p, mle + 0.5 * a * (p - phat)^2)
}

test_that("zeta interpolation recovers the exact bound of a quadratic profile", {
  a <- 2
  crit <- gllvmTMB:::.qchisq_threshold(0.95)
  exact_half_width <- sqrt(2 * crit / a)

  ## deliberately coarse grid: this is where deviance-scale interpolation hurts
  prof <- quad_prof(a = a, by = 0.5, span = 4)
  b <- gllvmTMB:::.profile_bounds(prof, mle_val = 100, mle_par = 0, crit = crit)

  expect_equal(b$upper, exact_half_width, tolerance = 1e-6)
  expect_equal(b$lower, -exact_half_width, tolerance = 1e-6)
  expect_equal(b$upper_status, "crossed")
})

test_that("zeta interpolation beats deviance-scale interpolation on a coarse grid", {
  a <- 2
  crit <- gllvmTMB:::.qchisq_threshold(0.95)
  exact <- sqrt(2 * crit / a)
  prof <- quad_prof(a = a, by = 0.8, span = 4)

  b <- gllvmTMB:::.profile_bounds(prof, mle_val = 100, mle_par = 0, crit = crit)
  err_zeta <- abs(b$upper - exact)

  ## reproduce the OLD rule: linear interpolation of the sign change in excess
  pars <- prof[[1]]
  vals <- prof[[2]]
  thresh <- 100 + crit
  idx <- which(pars > 0)
  e <- vals[idx] - thresh
  tr <- which(diff(sign(e)) != 0)[1]
  p1 <- pars[idx][tr]
  p2 <- pars[idx][tr + 1L]
  e1 <- e[tr]
  e2 <- e[tr + 1L]
  old <- p1 + (0 - e1) * (p2 - p1) / (e2 - e1)
  err_deviance <- abs(old - exact)

  expect_lt(err_zeta, err_deviance)
  ## and the improvement should be substantial, not cosmetic
  expect_lt(err_zeta, err_deviance / 10)
})

test_that("zeta interpolation leaves the non-crossing terminuses alone", {
  crit <- gllvmTMB:::.qchisq_threshold(0.95)
  ## asymptotic: saturates below threshold
  p <- seq(-8, 8, by = 0.25)
  asym <- gllvmTMB:::.profile_bounds(
    mk_prof(p, 100 + 0.6 * (1 - exp(-abs(p)))), 100, 0, crit)
  expect_equal(asym$upper, Inf)
  expect_equal(asym$upper_status, "asymptotic")

  ## truncated: still climbing when it stops
  q <- seq(-1.5, 1.5, by = 0.25)
  trunc <- gllvmTMB:::.profile_bounds(mk_prof(q, 100 + 0.5 * q^2), 100, 0, crit)
  expect_true(is.na(trunc$upper))
  expect_equal(trunc$upper_status, "truncated")
})

test_that("a non-quadratic (asymmetric) profile still brackets correctly", {
  crit <- gllvmTMB:::.qchisq_threshold(0.95)
  p <- seq(-3, 6, by = 0.2)
  ## asymmetric well: steeper on the left than the right
  v <- 100 + ifelse(p < 0, 1.5 * p^2, 0.4 * p^2)
  b <- gllvmTMB:::.profile_bounds(mk_prof(p, v), 100, 0, crit)
  expect_true(is.finite(b$lower) && is.finite(b$upper))
  expect_lt(b$lower, 0)
  expect_gt(b$upper, 0)
  ## the shallower side must give the wider half-width
  expect_gt(abs(b$upper), abs(b$lower))
})
