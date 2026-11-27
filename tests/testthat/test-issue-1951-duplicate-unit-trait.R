test_that("duplicate (unit, trait) Gaussian rows are refused (#1951, #1907)", {
  skip_on_cran()
  set.seed(42)
  sim <- simulate_unit_trait(n_units = 8, n_obs_per_unit = 1, n_traits = 2, seed = 42)
  d <- sim$data
  dup <- rbind(d, d[1, ])

  expect_error(
    suppressMessages(gllvmTMB(value ~ indep(1 | unit), data = dup, unit = "unit")),
    "same unit-trait cell"
  )

  set.seed(1126)
  sim2 <- simulate_site_trait(
    n_sites = 20, n_species = 5, n_traits = 2,
    mean_species_per_site = 4, n_predictors = 0, seed = 18
  )
  d2 <- rbind(sim2$data, sim2$data[1, , drop = FALSE])
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 1),
      data = d2,
      family = gaussian()
    ))),
    "same unit-trait cell"
  )
})