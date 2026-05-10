# Stage 8: biological-summary extractors.

test_that("extract_Sigma_B / Sigma_W return correlation matrices on the diagonal", {
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 80, n_species = 12, n_traits = 4,
    mean_species_per_site = 6,
    Lambda_B = matrix(c(1.0, 0.7, -0.3, 0.5,
                        0.3, -0.5, 0.8, 0.2), nrow = 4, ncol = 2),
    S_B = c(0.3, 0.3, 0.3, 0.3),
    Lambda_W = matrix(c(0.8, 0.4, -0.2, 0.5), nrow = 4, ncol = 1),
    S_W = c(0.4, 0.4, 0.4, 0.4),
    seed = 2025
  )
  fit <- gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2) + unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1) + unique(0 + trait | site_species),
    data = sim$data
  )
  B <- extract_Sigma_B(fit)
  W <- extract_Sigma_W(fit)
  expect_named(B, c("Sigma_B", "R_B"))
  expect_named(W, c("Sigma_W", "R_W"))
  expect_equal(unname(diag(B$R_B)), rep(1, 4))
  expect_equal(unname(diag(W$R_W)), rep(1, 4))
  expect_true(all(abs(B$R_B) <= 1 + 1e-10))
  expect_true(all(diag(B$Sigma_B) > 0))
  expect_true(all(diag(W$Sigma_W) > 0))
})

test_that("ICC_site is in (0, 1) when both Sigma_B and Sigma_W are present", {
  set.seed(7)
  sim <- simulate_site_trait(
    n_sites = 80, n_species = 12, n_traits = 3,
    mean_species_per_site = 6,
    Lambda_B = matrix(c(0.8, 0.5, -0.2,
                        0.2, -0.4, 0.6), nrow = 3, ncol = 2),
    S_B = c(0.3, 0.3, 0.3),
    Lambda_W = matrix(c(0.6, 0.3, -0.2), nrow = 3, ncol = 1),
    S_W = c(0.3, 0.3, 0.3),
    seed = 7
  )
  fit <- gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2) + unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1) + unique(0 + trait | site_species),
    data = sim$data
  )
  icc <- extract_ICC_site(fit)
  expect_length(icc, 3)
  expect_true(all(icc > 0))
  expect_true(all(icc < 1))
})

test_that("Communalities are in (0, 1]", {
  set.seed(11)
  sim <- simulate_site_trait(
    n_sites = 60, n_species = 10, n_traits = 4,
    mean_species_per_site = 5,
    Lambda_B = matrix(c(1.0, 0.7, -0.3, 0.5,
                        0.3, -0.5, 0.8, 0.2), nrow = 4, ncol = 2),
    S_B = c(0.4, 0.4, 0.4, 0.4),
    seed = 11
  )
  fit <- gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2) + unique(0 + trait | site),
    data = sim$data
  )
  c_B <- extract_communality(fit, "B")
  expect_length(c_B, 4)
  expect_true(all(c_B > 0 & c_B <= 1))
  ## Communality of W is NULL because no rr_W in formula
  expect_null(extract_communality(fit, "W"))
})

test_that("Ordination returns sensible shapes", {
  sim <- simulate_site_trait(
    n_sites = 50, n_species = 10, n_traits = 4,
    mean_species_per_site = 5,
    Lambda_B = matrix(c(1.0, 0.7, -0.3, 0.5,
                        0.3, -0.5, 0.8, 0.2), nrow = 4, ncol = 2),
    seed = 13
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data
  )
  ord <- extract_ordination(fit, "B")
  expect_named(ord, c("scores", "loadings", "row_id"))
  expect_equal(ncol(ord$scores), 2)
  expect_equal(nrow(ord$scores), nlevels(sim$data$site))
  expect_equal(dim(ord$loadings), c(4, 2))
})
