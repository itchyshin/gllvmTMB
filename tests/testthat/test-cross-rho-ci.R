## profile_cross_rho_ci(): profile-likelihood interval for the fixed cross-lineage
## rho, derived from a profile_cross_rho() grid. Tested on synthetic profiles so the
## interval math is checked without heavy coevolution refits (COE-04 rho-interval gate).

test_that("profile_cross_rho_ci recovers a quadratic profile interval", {
  ## A perfect quadratic profile delta_deviance = a*(rho - rho0)^2 has the analytic
  ## level-CI rho0 +/- sqrt(qchisq(level, 1) / a).
  rho0 <- 0.4
  a <- 30
  grid <- seq(-0.2, 0.95, by = 0.01)
  prof <- data.frame(
    rho = grid,
    logLik = -a / 2 * (grid - rho0)^2,
    delta_deviance = a * (grid - rho0)^2,
    is_best = FALSE
  )
  prof$is_best[which.min(prof$delta_deviance)] <- TRUE

  ci <- profile_cross_rho_ci(prof, level = 0.95)
  crit <- stats::qchisq(0.95, df = 1)

  expect_equal(ci$estimate, rho0, tolerance = 0.011)
  expect_true(ci$lower_bounded && ci$upper_bounded)
  expect_equal(ci$lower, rho0 - sqrt(crit / a), tolerance = 0.015)
  expect_equal(ci$upper, rho0 + sqrt(crit / a), tolerance = 0.015)
  expect_lt(ci$lower, ci$estimate)
  expect_lt(ci$estimate, ci$upper)
  expect_equal(ci$threshold, crit)
})

test_that("profile_cross_rho_ci widens with the confidence level", {
  rho0 <- 0.3
  a <- 25
  grid <- seq(-0.5, 0.95, by = 0.01)
  prof <- data.frame(
    rho = grid,
    logLik = -a / 2 * (grid - rho0)^2,
    delta_deviance = a * (grid - rho0)^2
  )
  ci95 <- profile_cross_rho_ci(prof, level = 0.95)
  ci80 <- profile_cross_rho_ci(prof, level = 0.80)
  # the 95% interval is strictly wider than the 80% interval on both sides
  expect_lt(ci95$lower, ci80$lower)
  expect_gt(ci95$upper, ci80$upper)
  expect_gt(ci95$threshold, ci80$threshold)
})

test_that("profile_cross_rho_ci flags an unbounded side and clamps to [-1, 1]", {
  ## Best at the upper grid edge: bounded below, open (unbounded) above.
  grid <- seq(0, 0.9, by = 0.1)
  prof <- data.frame(
    rho = grid,
    delta_deviance = 20 * (grid - 0.9)^2,
    logLik = -10 * (grid - 0.9)^2
  )
  ci <- profile_cross_rho_ci(prof)
  expect_true(ci$lower_bounded)
  expect_false(ci$upper_bounded)
  expect_equal(ci$upper, 0.9)
  expect_gte(ci$lower, -1)
  expect_lte(ci$upper, 1)
})

test_that("profile_cross_rho_ci validates its inputs", {
  good <- data.frame(rho = c(0, 0.5), delta_deviance = c(5, 0))
  expect_error(profile_cross_rho_ci(data.frame(x = 1)), "profile_cross_rho")
  expect_error(profile_cross_rho_ci(good, level = 1.5), "level")
  expect_error(profile_cross_rho_ci(good, level = 0), "level")
  expect_error(
    profile_cross_rho_ci(data.frame(rho = 0.2, delta_deviance = 0)),
    "two finite profile points"
  )
})
