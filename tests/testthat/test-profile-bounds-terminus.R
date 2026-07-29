## A profile that never crossed its threshold has TWO possible meanings, and the
## package used to report only one of them.
##
## `.profile_bounds()` returned +/-Inf whenever no profile point exceeded the
## threshold, and the roxygen asserted that meant "the bound is at the natural
## boundary of the parameter space, not unknown". That is true only when the
## profile has ASYMPTOTED -- flattened out, so no finite bound exists. It is
## false when the search simply ran out of road while the deviance was still
## climbing, in which case the bound is UNKNOWN, not infinite.
##
## The two are distinguishable from the two columns tmbprofile() returns: an
## asymptoting profile's outward slope decays toward zero, a truncated one's
## does not. Guard added 2026-07-28.

mk_prof <- function(par, value) data.frame(par = par, value = value)

test_that("a genuine crossing still interpolates a finite bound", {
  ## symmetric quadratic well around 0, crossing crit = 1.92 on both sides
  p <- seq(-4, 4, by = 0.25)
  v <- 100 + 0.5 * p^2
  b <- gllvmTMB:::.profile_bounds(mk_prof(p, v), mle_val = 100, mle_par = 0, crit = 1.92)
  expect_true(is.finite(b$lower))
  expect_true(is.finite(b$upper))
  expect_lt(b$lower, 0)
  expect_gt(b$upper, 0)
  expect_equal(b$lower_status, "crossed")
  expect_equal(b$upper_status, "crossed")
})

test_that("an ASYMPTOTING profile reports an infinite bound, as before", {
  ## deviance saturates well below the threshold: a real unbounded direction
  p <- seq(-8, 8, by = 0.25)
  v <- 100 + 0.6 * (1 - exp(-abs(p)))          # -> 100.6, never reaches 100 + 1.92
  b <- gllvmTMB:::.profile_bounds(mk_prof(p, v), mle_val = 100, mle_par = 0, crit = 1.92)
  expect_equal(b$lower, -Inf)
  expect_equal(b$upper, Inf)
  expect_equal(b$lower_status, "asymptotic")
  expect_equal(b$upper_status, "asymptotic")
})

test_that("a TRUNCATED profile reports NA, not Inf -- the bound is unknown", {
  ## still climbing steeply at the last point, simply stopped too early
  p <- seq(-1.5, 1.5, by = 0.25)
  v <- 100 + 0.5 * p^2                          # max excess 1.125 < crit 1.92
  b <- gllvmTMB:::.profile_bounds(mk_prof(p, v), mle_val = 100, mle_par = 0, crit = 1.92)
  expect_true(is.na(b$lower))
  expect_true(is.na(b$upper))
  expect_equal(b$lower_status, "truncated")
  expect_equal(b$upper_status, "truncated")
  ## and critically: NOT infinite. That is the whole point of this file.
  expect_false(isTRUE(is.infinite(b$lower)))
  expect_false(isTRUE(is.infinite(b$upper)))
})

test_that("the two non-crossing terminuses are not confused with each other", {
  p <- seq(-8, 8, by = 0.25)
  asym <- gllvmTMB:::.profile_bounds(
    mk_prof(p, 100 + 0.6 * (1 - exp(-abs(p)))), 100, 0, 1.92)
  trunc <- gllvmTMB:::.profile_bounds(
    mk_prof(seq(-1.5, 1.5, by = 0.25), 100 + 0.5 * seq(-1.5, 1.5, by = 0.25)^2), 100, 0, 1.92)
  expect_false(identical(asym$upper_status, trunc$upper_status))
  expect_true(is.infinite(asym$upper))
  expect_true(is.na(trunc$upper))
})
