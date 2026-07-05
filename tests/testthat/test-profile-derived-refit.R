test_that(".profile_ci_via_refit skips failed edge probes before bracketing", {
  fit <- list(opt = list(objective = 0, par = c(theta = 0)))
  crit <- gllvmTMB:::.qchisq_threshold(0.95)
  target_fn <- function(par, fit) 0

  excess_curve <- function(q) {
    if (abs(q + 0.3) < 1e-8) {
      return(NA_real_)
    }
    abs(q) / 0.6 - 1
  }

  with_mocked_bindings(
    .fix_and_refit_nll = function(fit, target_fn, q_0, lambda) {
      excess <- excess_curve(q_0)
      if (is.na(excess)) {
        return(NA_real_)
      }
      crit + excess
    },
    .package = "gllvmTMB",
    code = {
      bounds <- gllvmTMB:::.profile_ci_via_refit(
        fit,
        target_fn,
        q_hat = 0,
        level = 0.95,
        q_lo_hint = -0.3,
        q_hi_hint = 0.3,
        q_lo_floor = -0.999,
        q_hi_ceiling = 0.999
      )
    }
  )

  expect_equal(bounds$estimate, 0)
  expect_equal(bounds$lower, -0.6, tolerance = 0.02)
  expect_equal(bounds$upper, 0.6, tolerance = 0.02)
})
