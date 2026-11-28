## Issue #2013: summary() and vcov() must match tidy() when pdHess is FALSE.

.issue_2013_fit <- function() {
  set.seed(99)
  sim <- simulate_unit_trait(
    n_units = 18,
    n_obs_per_unit = 1,
    n_traits = 2,
    Lambda_B = matrix(c(0.4, 0.4), ncol = 1),
    psi_B = 0.3,
    sigma2_eps = 0.3
  )
  suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = sim$data,
    unit = "unit"
  )))
}

test_that("summary() and vcov() withhold Wald SEs when pdHess is FALSE", {
  skip_on_cran()
  fit <- .issue_2013_fit()
  if (!isTRUE(fit$sd_report$pdHess)) {
    fit$sd_report$pdHess <- TRUE
  }

  bad <- fit
  bad$sd_report$pdHess <- FALSE
  expect_true(all(is.na(tidy(bad)$std.error)))
  expect_true(all(is.na(summary(bad)$fixef$Std.Err)))
  expect_false(summary(bad)$se_status$available)
  expect_warning(
    V <- vcov(bad),
    class = "gllvmTMB_wald_nonpd_hessian"
  )
  expect_equal(
    attr(V, "inference_status"),
    "non_positive_definite_hessian"
  )
  expect_true(all(is.na(diag(V))))
})