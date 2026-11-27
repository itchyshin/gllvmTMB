## #2004: simulate() accepted family= in ... but ignored it with no warning.

test_that("#2004 simulate() warns on family= in ... and still draws from fit family", {
  skip_on_cran()
  set.seed(271127L)
  sim <- simulate_unit_trait(
    n_units = 30L, n_obs_per_unit = 1L, n_traits = 2L,
    Lambda_B = matrix(c(0.45, 0.35), 2L, 1L),
    psi_B = c(0.1, 0.1), seed = 271127L
  )
  sim$data$value <- stats::rpois(nrow(sim$data), lambda = 5)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1L),
    data = sim$data, trait = "trait", unit = "unit",
    family = poisson(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  skip_if_not(fit$fit$convergence == 0L, "fit did not converge")

  s_default <- simulate(fit, nsim = 1L)
  expect_no_warning(simulate(fit, nsim = 1L))

  expect_warning(
    s_binom <- simulate(fit, nsim = 1L, family = binomial()),
    regexp = "family",
    class = "gllvmTMB_simulate_unused_arg"
  )
  expect_gt(max(s_binom), 1)

  expect_warning(
    s_gauss <- simulate(fit, nsim = 1L, family = gaussian()),
    regexp = "fitted",
    class = "gllvmTMB_simulate_unused_arg"
  )
  expect_true(all(s_gauss == floor(s_gauss)))
  expect_equal(dim(s_default), dim(s_binom))
})