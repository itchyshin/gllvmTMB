# Stage 1: stacked-trait long-format fixed effects only.
# The acceptance test is parameter recovery — given simulated data with
# known trait-specific intercepts and slopes, gllvmTMB() must recover them
# within a sensible tolerance.

test_that("simulate_site_trait builds a coherent long-format dataset", {
  sim <- simulate_site_trait(
    n_sites             = 30,
    n_species           = 8,
    n_traits            = 3,
    mean_species_per_site = 4,
    n_predictors        = 2,
    seed                = 42
  )
  expect_s3_class(sim$data$trait, "factor")
  expect_s3_class(sim$data$site,  "factor")
  expect_s3_class(sim$data$species, "factor")
  expect_true(all(c("value", "env_1", "env_2", "site_species") %in% names(sim$data)))
  expect_equal(nlevels(sim$data$trait), 3)
  expect_equal(nlevels(sim$data$site), 30)
  expect_equal(nlevels(sim$data$species), 8)
  ## Each (site, species) pair contributes exactly n_traits rows
  expect_equal(table(sim$data$site_species)[1] |> as.numeric(), 3)
})

test_that("gllvmTMB() routes covstruct formulas to gllvmTMB_multi_fit()", {
  sim <- simulate_site_trait(n_sites = 20, n_species = 5, n_traits = 2,
                             mean_species_per_site = 3, seed = 1)
  ## rr() should fit; the result must be a gllvmTMB_multi object (not the
  ## single-response Stage 1 object).
  fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2),
                  data = sim$data)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
})

test_that("gllvmTMB() recovers trait-specific intercepts and slopes (Gaussian)", {
  skip("0.2.0: this test exercised the no-covstruct sdmTMB() fallback path that was removed.")
  set.seed(2025)
  alpha_true <- c(-1, 0, 1)              # 3 trait intercepts
  beta_true  <- matrix(c( 0.5,  0.0,
                          0.0,  0.5,
                         -0.4,  0.3), byrow = TRUE, nrow = 3, ncol = 2)
  sim <- simulate_site_trait(
    n_sites               = 80,
    n_species             = 12,
    n_traits              = 3,
    mean_species_per_site = 6,
    n_predictors          = 2,
    alpha                 = alpha_true,
    beta                  = beta_true,
    sigma2_eps            = 0.4,
    seed                  = 2025
  )

  fit <- gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 + (0 + trait):env_2,
    data   = sim$data,
    family = gaussian()
  )

  expect_s3_class(fit, "gllvmTMB")
  expect_false(inherits(fit, "gllvmTMB_multi"))
  expect_equal(fit$model$convergence, 0L)

  ## Pull the fixed-effects coefficient table.
  td <- as.data.frame(tidy(fit, "fixed", conf.int = TRUE))
  ## Trait intercepts: rows whose term is exactly the trait factor level.
  trait_levels <- levels(sim$data$trait)
  alpha_hat <- vapply(trait_levels, function(tl) {
    td$estimate[td$term == paste0("trait", tl)]
  }, numeric(1))
  expect_equal(unname(alpha_hat), alpha_true, tolerance = 0.25)

  ## env_1 slopes per trait.
  beta1_hat <- vapply(trait_levels, function(tl) {
    pat <- paste0("trait", tl, ":env_1")
    val <- td$estimate[td$term == pat]
    if (length(val) == 0) val <- td$estimate[td$term == paste0("env_1:trait", tl)]
    val
  }, numeric(1))
  expect_equal(unname(beta1_hat), beta_true[, 1], tolerance = 0.25)

  beta2_hat <- vapply(trait_levels, function(tl) {
    pat <- paste0("trait", tl, ":env_2")
    val <- td$estimate[td$term == pat]
    if (length(val) == 0) val <- td$estimate[td$term == paste0("env_2:trait", tl)]
    val
  }, numeric(1))
  expect_equal(unname(beta2_hat), beta_true[, 2], tolerance = 0.25)
})
