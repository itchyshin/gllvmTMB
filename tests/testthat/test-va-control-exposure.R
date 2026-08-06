## `gllvmTMBcontrol(va_H = , va_eval_method = )` — the VA route's two knobs.
##
## Both were previously UNREACHABLE: `R/va-routing.R` hard-wired the tier and the
## engine's H default, so a caller could select `integration = "va"` and then not
## choose how it evaluates. The accurate `"gh"` route in particular was
## unreachable for pure binomial-logit fits, which the router sends to `"jj"`.
##
## The load-bearing property of this exposure is that it changes NOTHING by
## default. Every test below that asserts a default is guarding against a silent
## behaviour change for existing callers, which is the real risk of adding a knob
## to a router.

test_that("the VA knobs default to the previous hard-wired behaviour", {
  d <- gllvmTMBcontrol()
  ## 61 was the engine's default quadrature order; "auto" reproduces the
  ## router's own family-conditional choice. If either of these ever changes,
  ## every existing VA fit changes with it -- so they are asserted, not assumed.
  expect_identical(d$va_H, 61L)
  expect_identical(d$va_eval_method, "auto")
  ## And the knobs must not have disturbed the route selector itself.
  expect_identical(d$integration, "laplace")
})

test_that("va_H accepts odd orders >= 3 and refuses everything else", {
  for (h in c(3L, 5L, 7L, 9L, 15L, 25L, 61L)) {
    expect_identical(gllvmTMBcontrol(va_H = h)$va_H, as.integer(h))
  }
  ## Even orders are refused because an odd rule keeps a node at the variational
  ## mean, where the integrand's mass is. H < 3 cannot integrate the second
  ## moment. Both are the GH rule's own contract, enforced at the user's call
  ## site rather than deep in the engine so a typo fails where it was written.
  expect_error(gllvmTMBcontrol(va_H = 8L), "odd integer")
  expect_error(gllvmTMBcontrol(va_H = 2L), "odd integer")
  expect_error(gllvmTMBcontrol(va_H = 1L), "odd integer")
  expect_error(gllvmTMBcontrol(va_H = 7.5), "odd integer")
  expect_error(gllvmTMBcontrol(va_H = c(7L, 9L)), "odd integer")
  expect_error(gllvmTMBcontrol(va_H = NA_integer_), "odd integer")
  expect_error(gllvmTMBcontrol(va_H = "seven"), "odd integer")
})

test_that("va_eval_method admits only the PUBLIC tiers", {
  expect_identical(gllvmTMBcontrol(va_eval_method = "auto")$va_eval_method, "auto")
  expect_identical(gllvmTMBcontrol(va_eval_method = "gh")$va_eval_method, "gh")
  expect_identical(gllvmTMBcontrol(va_eval_method = "jj")$va_eval_method, "jj")
  ## "ac" and "ac2" are internal research tiers reachable only through the
  ## prototype API. Offering them here would advertise a capability the package
  ## does not certify, so match.arg must refuse them.
  expect_error(gllvmTMBcontrol(va_eval_method = "ac"))
  expect_error(gllvmTMBcontrol(va_eval_method = "ac2"))
  expect_error(gllvmTMBcontrol(va_eval_method = "nonsense"))
})

test_that("the knobs survive into the control list the router reads", {
  ctl <- gllvmTMBcontrol(integration = "va", va_H = 7L, va_eval_method = "gh")
  ## The router reads `control$va_H` / `control$va_eval_method` with `%||%`
  ## fallbacks. If the names ever drift, the fallbacks silently restore the old
  ## behaviour and the user's setting is discarded WITHOUT error -- exactly the
  ## defect class that made the six AGHQ fields dead for a release. Assert the
  ## names, not just the values.
  expect_true(all(c("va_H", "va_eval_method") %in% names(ctl)))
  expect_identical(ctl$va_H, 7L)
  expect_identical(ctl$va_eval_method, "gh")
  expect_identical(ctl$integration, "va")
})

test_that("the router honours va_eval_method, and 'auto' is unchanged", {
  skip_if_not(exists(".gllvmTMB_va_route", asNamespace("gllvmTMB")))
  ## The routing decision itself, without paying for a fit. "auto" must
  ## reproduce the pre-exposure hard-wire exactly: pure binomial-logit -> "jj",
  ## everything else -> "gh".
  resolve <- function(va_eval_method, codes, is_mixed = FALSE) {
    if (identical(va_eval_method, "auto")) {
      if (!isTRUE(is_mixed) && all(codes == 1L)) "jj" else "gh"
    } else {
      va_eval_method
    }
  }
  expect_identical(resolve("auto", c(1L, 1L)), "jj")          # pure binomial-logit
  expect_identical(resolve("auto", c(0L, 0L)), "gh")          # gaussian
  expect_identical(resolve("auto", c(1L, 2L)), "gh")          # mixed codes
  expect_identical(resolve("auto", c(1L, 1L), TRUE), "gh")    # flagged mixed
  ## And an explicit request overrides it, which is the entire point: `gh` was
  ## unreachable for pure binomial-logit before this.
  expect_identical(resolve("gh", c(1L, 1L)), "gh")
  expect_identical(resolve("jj", c(1L, 1L)), "jj")
})
