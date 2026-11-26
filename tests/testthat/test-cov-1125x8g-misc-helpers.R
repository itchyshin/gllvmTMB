## Coverage (cursor-cloud-1125x8g): slope-ci helpers, simulate_site_trait smoke, unique().

test_that(".slope_ci_natural_to_log handles bad scales", {
  ok <- gllvmTMB:::.slope_ci_natural_to_log(2, 0.1)
  expect_equal(ok$theta, log(2))
  expect_true(is.finite(ok$se_theta))
  bad <- gllvmTMB:::.slope_ci_natural_to_log(0, 0.1)
  expect_true(is.na(bad$theta))
  expect_true(is.na(bad$se_theta))
})

test_that(".slope_ci_adreport_lookup refuses empty sdreport", {
  fit <- list(sd_report = NULL)
  miss <- gllvmTMB:::.slope_ci_adreport_lookup(fit, "sd_B_slope", 2L)
  expect_false(miss$ok)
  expect_equal(miss$reason, "no_sdreport")
})

test_that("simulate_site_trait default is fixed-effects only", {
  set.seed(11)
  sim <- simulate_site_trait(
    n_sites = 6L, n_species = 4L, n_traits = 2L,
    mean_species_per_site = 2, n_predictors = 0
  )
  expect_type(sim$data, "list")
  expect_true(nrow(sim$data) > 0L)
  expect_true("alpha" %in% names(sim$truth))
  expect_length(sim$truth$alpha, 2L)
  expect_null(sim$Cphy)
})

test_that("temporal markers build typed formula hooks", {
  a <- temporal_indep(0 + trait | series, time = occasion)
  expect_s3_class(a, "gllvmTMB_temporal_indep")
  d <- temporal_dep(0 + trait | series, time = occasion, structure = "ou")
  expect_s3_class(d, "gllvmTMB_temporal_dep")
  l <- temporal_latent(0 + trait | series, time = occasion, d = 1)
  expect_s3_class(l, "gllvmTMB_temporal_latent")
  expect_equal(l$d, 1L)
})

test_that(".gllvmTMB_single_trait_warmup returns defaults on tiny data", {
  trait_vec <- c(1L, 1L, 2L, 2L)
  y <- c(1, 2, 3, 4)
  fam <- rep(list(poisson()), 4L)
  out <- gllvmTMB:::.gllvmTMB_single_trait_warmup(trait_vec, y, fam, n_traits = 2L)
  expect_type(out, "list")
  expect_length(out$log_phi_nbinom2, 2L)
  expect_true(all(out$log_phi_nbinom2 == 0))
})