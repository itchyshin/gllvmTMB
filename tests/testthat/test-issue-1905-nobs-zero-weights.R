## refs #1905 — nobs() / likelihood_rows must exclude zero-weight rows.

test_that("nobs() excludes rows with observation weight zero", {
  skip_on_cran()
  set.seed(47L)
  sim <- simulate_site_trait(
    n_sites = 11L, n_species = 3L, n_traits = 2L,
    mean_species_per_site = 3L, seed = 47L
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
  n_contrib <- sum(w > 0)
  expect_equal(nobs(fit), n_contrib)
  expect_equal(fit$missing_data$counts$likelihood_rows, n_contrib)
  expect_equal(n_contrib, nrow(sim$data) - 5L)
})