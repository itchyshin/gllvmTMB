## #1907: duplicate long-format observation keys must error by default.

test_that("#1907 duplicate unit-trait-unit_obs rows abort by default", {
  skip_on_cran()
  skip_if_not_installed("gllvmTMB")
  suppressPackageStartupMessages(library(gllvmTMB))

  sim <- simulate_site_trait(
    n_sites = 20, n_species = 5, n_traits = 2,
    mean_species_per_site = 4, n_predictors = 0, seed = 18
  )
  d <- sim$data
  d_dup <- rbind(d, d[1L, , drop = FALSE])

  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 1),
      data = d_dup,
      family = gaussian(),
      silent = TRUE
    ))),
    class = "gllvmTMB_duplicate_observation_keys"
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = d_dup,
    family = gaussian(),
    repeated_measures = TRUE,
    silent = TRUE
  )))
  expect_equal(nobs(fit), nrow(d_dup))
})

test_that("#1907 distinct unit_obs allows multiple rows per unit and trait", {
  skip_on_cran()
  suppressPackageStartupMessages(library(gllvmTMB))
  d <- data.frame(
    unit = factor(rep(1:3, each = 4)),
    trait = factor(rep(c("a", "b"), times = 6)),
    unit_obs = factor(paste0("r", seq_len(12))),
    value = rnorm(12)
  )
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = d,
      unit = "unit",
      trait = "trait",
      unit_obs = "unit_obs",
      silent = TRUE
    ))),
    NA
  )
})