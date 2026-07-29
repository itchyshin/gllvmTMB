## The profile search budget must be coupled to the requested level.
##
## Regression guard for a defect found 2026-07-28: `ytol` was hard-coded to 2 at
## every call site while the crossing threshold is `crit = qchisq(level, 1) / 2`,
## which reaches 2.0 at level 0.9545. Above that the deviance trace could never
## reach the threshold, so `.profile_bounds()` returned +/-Inf -- silently, and
## documented as "the bound is at the natural boundary of the parameter space".
## Measured on a 4-trait Gaussian fit: level 0.99 lost 4 of 10 bounds to
## non-finite while 0.80/0.90/0.95 lost none.
##
## Exceeding `crit` is NOT sufficient: the root-finder interpolates a sign change
## on EACH side, so the budget needs headroom beyond `crit`, not equality with it.
## Measured: crit(0.99) = 3.3174; ytol = 3 still yielded 0/4 finite, ytol = 4 gave 4/4.

test_that(".profile_ytol leaves headroom above the crossing threshold", {
  for (level in c(0.5, 0.8, 0.9, 0.95, 0.9545, 0.96, 0.99, 0.999)) {
    crit <- gllvmTMB:::.qchisq_threshold(level)
    ytol <- gllvmTMB:::.profile_ytol(level)
    expect_gt(ytol, crit)
  }
})

test_that(".profile_ytol is monotone in level and beats the old constant where it mattered", {
  levels <- c(0.8, 0.9, 0.95, 0.99)
  ytols <- vapply(levels, gllvmTMB:::.profile_ytol, numeric(1))
  expect_true(all(diff(ytols) > 0))
  ## the old hard-coded budget was 2; at level 0.99 that was below crit = 3.3174
  expect_gt(gllvmTMB:::.profile_ytol(0.99), 2)
  expect_gt(gllvmTMB:::.profile_ytol(0.99), gllvmTMB:::.qchisq_threshold(0.99))
})

test_that("profile CIs stay finite and nest as the level rises", {
  skip_on_cran()
  set.seed(11)
  n <- 80L
  p <- 3L
  b <- rnorm(p, 0.5, 0.2)
  u <- rnorm(n)
  lam <- c(0.9, 0.7, -0.6)
  eta <- outer(u, lam) + rep(b, each = n)
  Y <- matrix(rnorm(n * p, eta, 1), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y)
  df$site <- factor(seq_len(n))

  fit <- gllvmTMB(
    traits(sp1, sp2, sp3) ~ 1 + indep(1 | site),
    data = df, family = gaussian(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
  )

  get_ci <- function(level) {
    suppressMessages(as.data.frame(
      confint(fit, parm = "Sigma_unit", method = "profile", level = level)
    ))
  }
  ci95 <- get_ci(0.95)
  ci99 <- get_ci(0.99)

  ## A 99% profile interval must not silently become unbounded where the 95% one
  ## was finite -- that is the defect this file guards.
  finite95 <- is.finite(ci95$lower) & is.finite(ci95$upper)
  finite99 <- is.finite(ci99$lower) & is.finite(ci99$upper)
  expect_equal(sum(finite99), sum(finite95))

  ## and where both are finite, the wider level must contain the narrower one
  both <- finite95 & finite99
  skip_if(!any(both), "no rows with finite bounds at both levels")
  expect_true(all(ci99$lower[both] <= ci95$lower[both] + 1e-8))
  expect_true(all(ci99$upper[both] >= ci95$upper[both] - 1e-8))
})
