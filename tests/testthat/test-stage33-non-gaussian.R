# Stage 33 — non-Gaussian families (Track D).
# binomial() and poisson() respond to the family_id branch in the multi
# template. Gaussian behaviour is unchanged.

test_that("Stage 33: family = binomial() converges with rr + diag", {
  set.seed(2025)
  T <- 3
  Lam <- matrix(c(1.0, 0.7, -0.3, 0.3, -0.5, 0.8), nrow = T, ncol = 2)
  sim <- simulate_site_trait(
    n_sites = 80, n_species = 12, n_traits = T,
    mean_species_per_site = 6,
    Lambda_B = Lam, psi_B = rep(0.3, T),
    sigma2_eps = 0.01, seed = 2025
  )
  df <- sim$data
  df$value <- as.integer(df$value > 0)

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) + unique(0 + trait | site),
    data = df, family = binomial()
  )
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
  ## In Stage 37, scalar `family_id` became per-row `family_id_vec`.
  ## For a single-family fit, every row's id is the family code (1 = binomial).
  expect_true(all(fit$tmb_data$family_id_vec == 1L))
  expect_true(is.finite(-fit$opt$objective))
})

test_that("Stage 33: family = poisson() converges with rr + diag", {
  set.seed(7)
  T <- 3
  sim <- simulate_site_trait(
    n_sites = 80, n_species = 12, n_traits = T,
    mean_species_per_site = 6,
    Lambda_B = matrix(c(0.5, 0.3, -0.2, 0.2, -0.3, 0.4), nrow = T, ncol = 2),
    psi_B = rep(0.3, T),
    sigma2_eps = 0.01, seed = 7
  )
  df <- sim$data
  ## Map continuous y to a count: round(exp(scaled y))
  df$value <- stats::rpois(nrow(df), exp(0.5 + as.numeric(scale(df$value)) * 0.4))

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) + unique(0 + trait | site),
    data = df, family = poisson()
  )
  expect_equal(fit$opt$convergence, 0L)
  ## Stage 37: per-row family_id_vec; for single-family fits every row is 2 (poisson).
  expect_true(all(fit$tmb_data$family_id_vec == 2L))
  expect_true(is.finite(-fit$opt$objective))
})

test_that("Stage 33: Gamma() default (inverse) link rejected; only log link supported", {
  sim <- simulate_site_trait(n_sites = 30, n_species = 8, n_traits = 3,
                             mean_species_per_site = 4, seed = 1)
  ## Gamma() defaults to inverse link; the engine requires log link.
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
             data = sim$data, family = Gamma()),
    "log link"
  )
  ## A truly unsupported family (e.g., quasi) should error with
  ## "Unsupported family".
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
             data = sim$data, family = quasi()),
    "Unsupported family"
  )
})
