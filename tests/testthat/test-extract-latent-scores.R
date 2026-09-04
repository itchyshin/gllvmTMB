# extract_latent_scores(): fitted posterior modes and simulation generating scores
# (design: docs/dev-log/design-notes/2026-09-04-latent-score-accessor.md)

skip_on_cran()

.els_fit_K1 <- local({
  set.seed(2101)
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 5, n_traits = 4, mean_species_per_site = 4,
    Lambda_B = matrix(c(0.9, 0.6, -0.4, 0.5), nrow = 4, ncol = 1),
    psi_B = rep(0.3, 4),
    seed = 2101
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = sim$data
  )))
  stopifnot(isTRUE(fit$sd_report$pdHess))
  fit
})

.els_fit_K2 <- local({
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 80, n_species = 12, n_traits = 4, mean_species_per_site = 6,
    Lambda_B = matrix(
      c(1.0, 0.7, -0.3, 0.5, 0.3, -0.5, 0.8, 0.2),
      nrow = 4, ncol = 2
    ),
    psi_B = c(0.3, 0.3, 0.3, 0.3),
    seed = 2025
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data
  )))
  stopifnot(isTRUE(fit$sd_report$pdHess))
  fit
})

test_that("extract_latent_scores() on a fit matches ordination_uncertainty(), getLV(), extract_ordination() (K = 1)", {
  fit <- .els_fit_K1
  z <- extract_latent_scores(fit, level = "unit")
  u <- ordination_uncertainty(fit, level = "unit")
  ord <- extract_ordination(fit, level = "unit", component = "innovation")

  expect_equal(z, u$scores, tolerance = 1e-10)
  expect_equal(z, getLV(fit, level = "unit"), tolerance = 1e-10)
  expect_equal(z, ord$scores, tolerance = 1e-10)
  expect_equal(dim(z), c(fit$n_sites, 1L))
})

test_that("extract_latent_scores() on a fit matches ordination_uncertainty() and getLV() (K = 2)", {
  fit <- .els_fit_K2
  z <- extract_latent_scores(fit, level = "unit")
  u <- ordination_uncertainty(fit, level = "unit")

  expect_equal(z, u$scores, tolerance = 1e-10)
  expect_equal(z, getLV(fit, level = "unit"), tolerance = 1e-10)
  expect_equal(dim(z), c(fit$n_sites, 2L))
})

test_that("extract_latent_scores() dimnames match extract_ordination() / ordination_uncertainty()", {
  fit <- .els_fit_K2
  z <- extract_latent_scores(fit, level = "unit")
  u <- ordination_uncertainty(fit, level = "unit")
  ord <- extract_ordination(fit, level = "unit", component = "innovation")

  expect_identical(dimnames(z), dimnames(u$scores))
  expect_identical(dimnames(z), dimnames(ord$scores))
  expect_identical(colnames(z), c("LV1", "LV2"))
})

test_that("extract_latent_scores() returns NULL when there is no rr term at that level", {
  set.seed(17)
  sim <- simulate_site_trait(
    n_sites = 15, n_species = 5, n_traits = 3, mean_species_per_site = 4,
    psi_B = rep(0.3, 3), seed = 17
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site),
    data = sim$data
  )))
  expect_null(extract_latent_scores(fit, level = "unit"))
  expect_null(extract_latent_scores(sim, level = "unit"))
})

test_that("extract_latent_scores() on simulate_site_trait() returns stored truth$z_B", {
  sim <- simulate_site_trait(
    n_sites = 25, n_species = 8, n_traits = 3, mean_species_per_site = 5,
    Lambda_B = matrix(c(0.8, 0.5, -0.2), nrow = 3, ncol = 1),
    seed = 4242
  )
  z <- extract_latent_scores(sim, level = "unit")
  expect_s3_class(sim, "gllvmTMB_site_trait_sim")
  expect_equal(dim(z), c(25L, 1L))
  expect_identical(rownames(z), levels(sim$data$site))
  expect_identical(z, sim$truth$z_B)
  expect_equal(
    extract_latent_scores(sim, level = "unit"),
    extract_latent_scores(sim, level = "unit")
  )
})

test_that("extract_latent_scores() on simulate_site_trait() stores and returns truth$z_W at unit_obs", {
  sim <- simulate_site_trait(
    n_sites = 12, n_species = 6, n_traits = 3, mean_species_per_site = 4,
    Lambda_W = matrix(c(0.6, 0.4, 0.2, 0.5, -0.3, 0.1), nrow = 3, ncol = 2),
    seed = 5151
  )
  z <- extract_latent_scores(sim, level = "unit_obs")
  expect_equal(dim(z), c(length(levels(sim$data$site_species)), 2L))
  expect_identical(rownames(z), levels(sim$data$site_species))
  expect_identical(z, sim$truth$z_W)
})

test_that("extract_latent_scores() errors clearly on unsupported objects", {
  expect_error(
    extract_latent_scores(data.frame(x = 1)),
    "No method for"
  )
})
