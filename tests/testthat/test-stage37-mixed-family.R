# Stage 37: per-row mixed response families.
# Same package call can fit Gaussian + binomial + Poisson rows in one shot
# by passing family = list(gaussian(), binomial(), poisson()) plus a
# family_var column in data that picks family per row.

test_that("Stage 37: family = list(...) drives per-row family_id_vec", {
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 10, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(1, 0.7, -0.3, 0.3, -0.5, 0.8), nrow = 3, ncol = 2),
    psi_B = c(0.3, 0.3, 0.3),
    seed = 2025
  )
  df <- sim$data
  df$family <- factor(with(df, ifelse(trait == "trait_1", "g",
                                ifelse(trait == "trait_2", "b", "p"))),
                       levels = c("g", "b", "p"))
  df$value[df$family == "b"] <- as.integer(df$value[df$family == "b"] > 0)
  df$value[df$family == "p"] <- pmax(0L,
                                     as.integer(round(df$value[df$family == "p"] + 1)))

  family_list <- list(gaussian(), binomial(), poisson())
  attr(family_list, "family_var") <- "family"

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = df, family = family_list
  )
  expect_equal(fit$opt$convergence, 0L)
  ## family_id_vec assigns 0 = Gaussian, 1 = binomial, 2 = Poisson rows.
  fid <- fit$tmb_data$family_id_vec
  expect_true(all(fid[df$family == "g"] == 0L))
  expect_true(all(fid[df$family == "b"] == 1L))
  expect_true(all(fid[df$family == "p"] == 2L))
})

test_that("Stage 37: named mixed-family lists align by selector level", {
  family_list <- list(p = poisson(), g = gaussian(), b = binomial())
  attr(family_list, "family_var") <- "family"

  aligned <- gllvmTMB:::.align_mixed_family_list(
    family_list,
    fam_levels = c("g", "b", "p"),
    fam_var = "family"
  )
  expect_named(aligned, c("g", "b", "p"))
  expect_identical(attr(aligned, "family_var"), "family")

  set.seed(2031)
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 8, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.5, -0.2, 0.2, -0.4, 0.7), nrow = 3, ncol = 2),
    psi_B = c(0.3, 0.3, 0.3),
    seed = 2031
  )
  df <- sim$data
  df$family <- factor(with(df, ifelse(trait == "trait_1", "g",
                                ifelse(trait == "trait_2", "b", "p"))),
                       levels = c("g", "b", "p"))
  df$value[df$family == "b"] <- as.integer(df$value[df$family == "b"] > 0)
  df$value[df$family == "p"] <- pmax(0L,
                                     as.integer(round(df$value[df$family == "p"] + 1)))

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = df, family = family_list
  )
  expect_equal(fit$opt$convergence, 0L)
  fid <- fit$tmb_data$family_id_vec
  expect_true(all(fid[df$family == "g"] == 0L))
  expect_true(all(fid[df$family == "b"] == 1L))
  expect_true(all(fid[df$family == "p"] == 2L))
})

test_that("Stage 37: partial mixed-family list names fail loudly", {
  family_list <- list(g = gaussian(), binomial())
  expect_error(
    gllvmTMB:::.align_mixed_family_list(
      family_list,
      fam_levels = c("g", "b"),
      fam_var = "family"
    ),
    "fully named or fully unnamed"
  )
})

test_that("Stage 37: scalar family still works (backward compatible)", {
  set.seed(7)
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 8, n_traits = 3,
    mean_species_per_site = 4, seed = 7
  )
  fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
                  data = sim$data, family = gaussian())
  expect_equal(fit$opt$convergence, 0L)
  expect_true(all(fit$tmb_data$family_id_vec == 0L))
})
