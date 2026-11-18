# Issue #985: the VA start-adjudicator's objective-agreement bound is scaled
# by the objective magnitude. It used to be an ABSOLUTE 1e-6 range bound,
# which at |objective| ~ 1e3 demands ~1e-9 relative agreement -- a bar no
# optimiser clears reproducibly across BLAS implementations, so the
# light-fit health gate was green on macOS and `failed_health_gate` on
# ubuntu CI for identical fits.
#
# These tests exercise `.va_r3_adjudicate_starts()` directly rather than a
# platform difference: the defect is in the comparison, and the comparison
# is deterministic.

.mk_start <- function(objective, eligible = TRUE, strict = TRUE) {
  list(objective = objective, agreement_eligible = eligible,
       strictly_converged = strict, convergence = if (strict) 0L else 1L)
}

test_that("agreement tolerance scales with objective magnitude (#985)", {
  ## Best-three range 5e-6 on an objective near 2000. Absolute 1e-6 would
  ## reject; the scaled bound (1e-6 * 2000 = 2e-3) admits.
  big <- lapply(c(2000.000000, 2000.000002, 2000.000005, 2000.010000),
                .mk_start)
  adj_big <- gllvmTMB:::.va_r3_adjudicate_starts(big)
  expect_true(adj_big$agreement)
  expect_lt(adj_big$agreement_range, 1e-5)

  ## The same RELATIVE disagreement at the same scale is still refused:
  ## a range of 5 on an objective of 2000 is 2.5e-3 relative, far beyond
  ## the scaled bound.
  bad <- lapply(c(2000, 2001, 2003, 2005), .mk_start)
  expect_false(gllvmTMB:::.va_r3_adjudicate_starts(bad)$agreement)
})

test_that("O(1) objectives keep the original absolute meaning (#985)", {
  ## max(1, |median|) floors the scale at 1, so small-objective fixtures
  ## are adjudicated exactly as before the fix.
  ok <- lapply(c(0.500000, 0.5000002, 0.5000004, 0.6), .mk_start)
  expect_true(gllvmTMB:::.va_r3_adjudicate_starts(ok)$agreement)

  not_ok <- lapply(c(0.5, 0.5001, 0.5002, 0.6), .mk_start)
  expect_false(gllvmTMB:::.va_r3_adjudicate_starts(not_ok)$agreement)
})

test_that("fewer than three eligible starts never agree (#985)", {
  two <- list(.mk_start(1000), .mk_start(1000.0000001),
              .mk_start(1000.0000002, eligible = FALSE))
  adj <- gllvmTMB:::.va_r3_adjudicate_starts(two)
  expect_false(adj$agreement)
  expect_identical(adj$agreement_range, Inf)
})
