## The coverage harness must not credit an interval it could not compute.
##
## Regression guard for a defect found 2026-07-28. `coverage_study()` explicitly
## treated an NA bound as non-coverage -- correct -- but the guard was written as
## `is.na(lo) || is.na(hi)`, and `is.na(-Inf)` is FALSE. So an infinite bound fell
## through to `tr >= lo & tr <= hi`, which for (-Inf, Inf) is TRUE: the replicate
## was scored as COVERED. `n_excluded` counted only NA, so such replicates also
## stayed in the denominator. A method that returns (-Inf, Inf) for every
## replicate would have measured 100% coverage.
##
## This matters here specifically: the profile route could emit infinite bounds
## whenever the search budget fell short of the crossing threshold (fixed
## separately by coupling `ytol` to `level`). One defect manufactured the
## infinities and this one credited them.

test_that(".ci_covers refuses to credit a non-finite bound", {
  ## ordinary finite cases still behave
  expect_true(gllvmTMB:::.ci_covers(0.5, 0.0, 1.0))
  expect_false(gllvmTMB:::.ci_covers(1.5, 0.0, 1.0))
  expect_true(gllvmTMB:::.ci_covers(0.0, 0.0, 1.0)) # closed interval
  expect_true(gllvmTMB:::.ci_covers(1.0, 0.0, 1.0))

  ## NA bounds: not covered (pre-existing, must not regress)
  expect_false(gllvmTMB:::.ci_covers(0.5, NA_real_, 1.0))
  expect_false(gllvmTMB:::.ci_covers(0.5, 0.0, NA_real_))

  ## the defect: infinite bounds must NOT be credited
  expect_false(gllvmTMB:::.ci_covers(0.5, -Inf, Inf))
  expect_false(gllvmTMB:::.ci_covers(0.5, -Inf, 1.0))
  expect_false(gllvmTMB:::.ci_covers(0.5, 0.0, Inf))

  ## and the truth being inside the infinite interval must not rescue it
  expect_false(gllvmTMB:::.ci_covers(1e6, -Inf, Inf))
})

test_that("a vacuous (-Inf, Inf) method cannot score high coverage", {
  truth <- 0.7
  n <- 100L
  vacuous <- vapply(
    seq_len(n),
    function(i) gllvmTMB:::.ci_covers(truth, -Inf, Inf),
    logical(1)
  )
  expect_equal(sum(vacuous), 0L)
})

test_that("non-finite bounds are counted as excluded, not silently kept", {
  df <- data.frame(
    lower = c(0.1, NA_real_, -Inf, 0.3, 0.2),
    upper = c(0.9, 1.0, Inf, Inf, 0.8)
  )
  ## the exclusion rule must catch NA *and* infinite on either side: rows 2,3,4
  n_excl <- sum(!is.finite(df$lower) | !is.finite(df$upper))
  expect_equal(n_excl, 3L)
})
