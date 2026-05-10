# Generic random intercepts `(1 | group)` for the multivariate engine.
# These tests target the gllvmTMB() multi engine specifically; the
# pre-existing test-random-intercepts.R file targets the single-response
# sdmTMB engine and is unrelated.
#
# Strategy: simulate from a DGP that adds a per-row group offset
# u_g ~ N(0, sigma_g^2), fit, and check that sigma_g is recovered to
# within a tolerance that is loose enough to absorb the usual ML
# variance-component small-sample bias but tight enough to detect a
# sign or scale error.

simulate_re_int <- function(seed, n_studies = 25, sigma_g = 0.7,
                            n_sites = 30, n_species = 6, n_traits = 3,
                            mean_species_per_site = 4,
                            extra_studies = NULL) {
  set.seed(seed)
  sim <- simulate_site_trait(
    n_sites = n_sites, n_species = n_species, n_traits = n_traits,
    mean_species_per_site = mean_species_per_site, seed = seed
  )
  df <- sim$data
  n <- nrow(df)
  df$study <- factor(sample(seq_len(n_studies), n, replace = TRUE))
  RE_vals <- stats::rnorm(n_studies, 0, sigma_g)
  df$value <- df$value + RE_vals[df$study]
  list(data = df, RE_vals = RE_vals, sigma_g = sigma_g, sim = sim)
}

test_that("(1 | group): single random-intercept term recovers sigma_g", {
  s <- simulate_re_int(seed = 7, n_studies = 25, sigma_g = 0.7)
  fit <- gllvmTMB(value ~ 0 + trait + (1 | study), data = s$data)
  expect_equal(fit$opt$convergence, 0L)
  expect_true(fit$use$re_int)
  sigma_hat <- exp(fit$report$log_sigma_re_int)
  expect_length(sigma_hat, 1L)
  ## Compare against the empirical sd of the simulated REs (not against
  ## sigma_g) — that's what an ML estimator targets for finite n.
  expect_equal(as.numeric(sigma_hat), stats::sd(s$RE_vals), tolerance = 0.1)
})

test_that("(1 | group): two random-intercept terms recover both variances", {
  set.seed(42)
  sim <- simulate_site_trait(n_sites = 50, n_species = 6, n_traits = 3,
                             mean_species_per_site = 5, seed = 42)
  df <- sim$data
  n <- nrow(df)
  n_studies <- 25; n_dataset <- 30
  df$study   <- factor(sample(seq_len(n_studies), n, replace = TRUE))
  df$dataset <- factor(sample(seq_len(n_dataset), n, replace = TRUE))
  RE1 <- stats::rnorm(n_studies, 0, 0.5)
  RE2 <- stats::rnorm(n_dataset, 0, 0.3)
  df$value <- df$value + RE1[df$study] + RE2[df$dataset]

  fit <- gllvmTMB(value ~ 0 + trait + (1 | study) + (1 | dataset), data = df)
  expect_equal(fit$opt$convergence, 0L)
  expect_true(fit$use$re_int)
  expect_equal(fit$re_int$groups,   c("study", "dataset"))
  expect_equal(fit$re_int$n_groups, c(n_studies, n_dataset))
  expect_equal(fit$re_int$offsets,  c(0L, n_studies))

  sigmas <- exp(fit$report$log_sigma_re_int)
  expect_length(sigmas, 2L)
  ## Two-term variance components shrink more aggressively under ML;
  ## a 25% relative tolerance is enough to catch a wrong sign or scale.
  expect_equal(sigmas[1], stats::sd(RE1), tolerance = 0.25)
  expect_equal(sigmas[2], stats::sd(RE2), tolerance = 0.25)
})

test_that("(1 | group) combined with rr() works and both recover", {
  set.seed(2026)
  Lambda_B <- matrix(c(0.8, 0.5, -0.2, 0.3,
                       0.2, -0.4, 0.6, 0.1), nrow = 4, ncol = 2)
  sim <- simulate_site_trait(n_sites = 60, n_species = 8, n_traits = 4,
                             mean_species_per_site = 5,
                             Lambda_B = Lambda_B,
                             seed = 2026)
  df <- sim$data
  n <- nrow(df)
  n_studies <- 30
  df$study <- factor(sample(seq_len(n_studies), n, replace = TRUE))
  RE_vals <- stats::rnorm(n_studies, 0, 0.6)
  df$value <- df$value + RE_vals[df$study]

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) + (1 | study),
    data = df
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(fit$use$rr_B && fit$use$re_int)
  expect_equal(dim(fit$report$Lambda_B), c(4, 2))
  sigma_hat <- exp(fit$report$log_sigma_re_int)
  expect_equal(as.numeric(sigma_hat), stats::sd(RE_vals), tolerance = 0.15)
})

test_that("(1 | group) is reproducible under fixed seed", {
  s1 <- simulate_re_int(seed = 99, n_studies = 25, sigma_g = 0.5)
  s2 <- simulate_re_int(seed = 99, n_studies = 25, sigma_g = 0.5)
  expect_identical(s1$data$value, s2$data$value)
  fit1 <- gllvmTMB(value ~ 0 + trait + (1 | study), data = s1$data)
  fit2 <- gllvmTMB(value ~ 0 + trait + (1 | study), data = s2$data)
  expect_equal(fit1$opt$objective, fit2$opt$objective, tolerance = 1e-8)
  expect_equal(fit1$report$log_sigma_re_int,
               fit2$report$log_sigma_re_int, tolerance = 1e-6)
})

test_that("(1 | group) errors when group column is missing from data", {
  s <- simulate_re_int(seed = 5)
  expect_error(
    gllvmTMB(value ~ 0 + trait + (1 | nope), data = s$data),
    regexp = "nope.*not a column"
  )
})

test_that("Random slopes (0 + x | g) error gracefully (not yet implemented)", {
  s <- simulate_re_int(seed = 5)
  expect_error(
    gllvmTMB(value ~ 0 + trait + (0 + trait | study), data = s$data),
    regexp = "not yet implemented"
  )
  expect_error(
    gllvmTMB(value ~ 0 + trait + (1 + env_1 | study), data = s$data),
    regexp = "not yet implemented"
  )
})

test_that("BLUPs are well correlated with true REs", {
  s <- simulate_re_int(seed = 11, n_studies = 25, sigma_g = 0.7)
  fit <- gllvmTMB(value ~ 0 + trait + (1 | study), data = s$data)
  u <- fit$tmb_obj$env$parList()$u_re_int
  expect_length(u, 25L)
  ## BLUPs are shrunk; correlation with truth should still be high.
  expect_gt(stats::cor(u, s$RE_vals), 0.85)
})
