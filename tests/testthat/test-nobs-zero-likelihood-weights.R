test_that("nobs() excludes zero likelihood-weight rows (refs #1905)", {
  skip_if_not_installed("gllvmTMB")

  set.seed(47)
  sim <- simulate_site_trait(
    n_sites = 11,
    n_species = 3,
    n_traits = 2,
    mean_species_per_site = 3,
    seed = 47
  )
  w <- rep(1, nrow(sim$data))
  w[1:5] <- 0

  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait,
    data = sim$data,
    unit = "site",
    weights = w
  ))

  expect_true(isTRUE(fit$likelihood_weights$active))
  n_pos <- sum(w > 0)
  expect_identical(stats::nobs(fit), n_pos)
  expect_identical(fit$missing_data$counts$likelihood_rows, n_pos)
  expect_lt(n_pos, nrow(sim$data))
})