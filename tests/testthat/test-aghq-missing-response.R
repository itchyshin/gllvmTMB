## The FIML response mask must compose with AGHQ, not just with Laplace.
##
## AGHQ is an active engine direction, so this needs a standing guard. Gaussian
## cannot provide one: Laplace is exact for a Gaussian response with Gaussian
## random effects, so LA and AGHQ agree by construction and an "AGHQ" run that
## silently fell back to Laplace looks identical to one that engaged. Only a
## non-Gaussian family discriminates.
##
## Each test therefore asserts TWO things:
##   (1) ENGAGEMENT -- AGHQ differs from LA on the same complete data
##   (2) FIML       -- under AGHQ, response="drop" and "include" reach the same
##                     optimum, and nobs counts observed CELLS
##
## Without (1), (2) would be vacuous.

.aghq_fit <- function(dat, miss, aghq, fam) {
  suppressMessages(gllvmTMB(
    traits(t1, t2, t3) ~ 1 + z + latent(1 | site, d = 1, unique = FALSE),
    data = dat, unit = "site", family = fam,
    missing = miss,
    control = gllvmTMBcontrol(se = FALSE, aghq = aghq)
  ))
}

test_that("AGHQ engages and the response mask composes with it (Bernoulli)", {
  skip_on_cran()
  skip_if_not_installed("TMB")

  set.seed(5)
  n <- 80
  d <- data.frame(site = factor(seq_len(n)), z = rnorm(n))
  u <- rnorm(n, sd = 0.7)
  d$t1 <- rbinom(n, 1, plogis(0.5 + 0.8 * d$z + 1.5 * u))
  d$t2 <- rbinom(n, 1, plogis(0.2 - 0.6 * d$z + 1.5 * u))
  d$t3 <- rbinom(n, 1, plogis(0.3 + 0.4 * d$z + 1.5 * u))

  # (1) Engagement. Bernoulli is the classic case where Laplace is poor, so the
  # gap is large and unambiguous (~0.27 when this was written). If AGHQ ever
  # silently falls back, this is what catches it.
  la   <- .aghq_fit(d, miss_control(), FALSE, binomial())
  aghq <- .aghq_fit(d, miss_control(), TRUE,  binomial())
  expect_gt(
    abs(as.numeric(stats::logLik(la)) - as.numeric(stats::logLik(aghq))),
    1e-3
  )

  # (2) The mask composes: same optimum whether the missing cells are omitted
  # or masked, and nobs counts observed cells.
  dn <- d
  dn$t1[1:3] <- NA
  ag_drop <- .aghq_fit(dn, miss_control(),                     TRUE, binomial())
  ag_incl <- .aghq_fit(dn, miss_control(response = "include"), TRUE, binomial())

  expect_equal(
    as.numeric(stats::logLik(ag_drop)),
    as.numeric(stats::logLik(ag_incl)),
    tolerance = 1e-5
  )
  expect_identical(nobs(ag_drop), 237L)   # 80 * 3 - 3
  expect_identical(nobs(ag_incl), 237L)
})

test_that("the same holds for a count family (Poisson)", {
  skip_on_cran()
  skip_if_not_installed("TMB")

  set.seed(5)
  n <- 60
  d <- data.frame(site = factor(seq_len(n)), z = rnorm(n))
  u <- rnorm(n, sd = 0.7)
  d$t1 <- rpois(n, exp(0.5 + 0.4 * d$z + u))
  d$t2 <- rpois(n, exp(0.2 - 0.3 * d$z + u))
  d$t3 <- rpois(n, exp(0.3 + 0.2 * d$z + u))

  # Laplace is a better approximation for Poisson than for Bernoulli, so the
  # engagement gap is genuinely smaller here -- but still orders of magnitude
  # above optimizer noise, which shows up at ~1e-9 in the drop/include pair.
  la   <- .aghq_fit(d, miss_control(), FALSE, poisson())
  aghq <- .aghq_fit(d, miss_control(), TRUE,  poisson())
  expect_gt(
    abs(as.numeric(stats::logLik(la)) - as.numeric(stats::logLik(aghq))),
    1e-5
  )

  dn <- d
  dn$t1[1:3] <- NA
  ag_drop <- .aghq_fit(dn, miss_control(),                     TRUE, poisson())
  ag_incl <- .aghq_fit(dn, miss_control(response = "include"), TRUE, poisson())

  expect_equal(
    as.numeric(stats::logLik(ag_drop)),
    as.numeric(stats::logLik(ag_incl)),
    tolerance = 1e-5
  )
  expect_identical(nobs(ag_drop), 177L)   # 60 * 3 - 3
  expect_identical(nobs(ag_incl), 177L)
})
