test_that("confint(Sigma_unit) names dep() tier on dep fits (refs #2014)", {
  skip_on_cran()
  set.seed(11)
  sim <- simulate_unit_trait(
    n_units = 25,
    n_obs_per_unit = 1,
    n_traits = 2,
    Lambda_B = matrix(c(0, 0), ncol = 1),
    psi_B = 0.35,
    sigma2_eps = 0.2
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + dep(0 + trait | unit),
    data = sim$data,
    trait = "trait",
    unit = "unit"
  )))
  expect_true(isTRUE(fit$covstructs[[1]]$extra$.dep))
  expect_equal(gllvmTMB:::.sigma_rr_tier_label(fit), "dep")
  out <- suppressMessages(confint(fit, parm = "Sigma_unit", method = "wald"))
  expect_true(all(is.na(out$lower) & is.na(out$upper)))
})