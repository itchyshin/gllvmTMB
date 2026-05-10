# Stage 4: spde() formula term — the marriage between glmmTMB-style
# covstruct dispatch and sdmTMB's fast sparse SPDE machinery.

simulate_spatial_data <- function(n_sites = 60, n_species = 14, n_traits = 2,
                                  spatial_range = 0.3, sigma2_spa = 0.5,
                                  seed = 7) {
  simulate_site_trait(
    n_sites = n_sites, n_species = n_species, n_traits = n_traits,
    mean_species_per_site = 6,
    spatial_range = spatial_range,
    sigma2_spa = rep(sigma2_spa, n_traits),
    seed = seed
  )
}

test_that("Stage 4: spde() converges and recovers sensible kappa / range", {
  sim <- simulate_spatial_data()
  mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.07)
  fit <- gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait | coords),
    data = sim$data, mesh = mesh
  )
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
  expect_true(fit$use$spde)
  ## kappa > 0 implies range = sqrt(8) / kappa is sensible
  expect_gt(as.numeric(fit$report$kappa), 0)
  range_est <- sqrt(8) / as.numeric(fit$report$kappa)
  expect_gt(range_est, 0.05)
  expect_lt(range_est, 5.0)
})

test_that("Stage 4: spde() + diag combined model converges", {
  sim <- simulate_spatial_data()
  mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.07)
  fit <- gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
            spatial_unique(0 + trait | coords) +
            unique(0 + trait | site_species),
    data = sim$data, mesh = mesh
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(fit$use$spde)
  expect_true(fit$use$diag_W)
  expect_true(is.finite(-fit$opt$objective))
})

test_that("Stage 4: spde() requires mesh", {
  sim <- simulate_spatial_data()
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + spatial_unique(0 + trait | coords),
      data = sim$data, mesh = NULL
    ),
    "mesh"
  )
})

test_that("Stage 4: spde() handles a fixed-rank between-site rr too", {
  sim <- simulate_spatial_data(n_sites = 80, n_traits = 3,
                               spatial_range = 0.3, sigma2_spa = 0.4,
                               seed = 9)
  mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.07)
  fit <- gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait | coords) + latent(0 + trait | site, d = 2),
    data = sim$data, mesh = mesh
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(fit$use$spde && fit$use$rr_B)
  expect_equal(dim(fit$report$Lambda_B), c(3, 2))
})
