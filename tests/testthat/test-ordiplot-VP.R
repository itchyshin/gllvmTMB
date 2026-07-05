# Tests for the plot helpers ordiplot() and the variance-partition VP().

# ---- helpers -------------------------------------------------------------

make_rrB_fit <- function(seed = 1, d = 2, n_traits = 3) {
  set.seed(seed)
  Lam <- matrix(c(1.0, 0.5, -0.4, 0.3,
                  0.0, 0.8, 0.4, -0.2,
                  0.5, -0.2, 0.6, 0.1)[seq_len(n_traits * d)],
                n_traits, d)
  sim <- simulate_site_trait(
    n_sites = 25, n_species = 5, n_traits = n_traits,
    mean_species_per_site = 3,
    Lambda_B = Lam, psi_B = rep(0.3, n_traits), seed = seed
  )
  fmla <- stats::as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | site, d = %d)",
    d
  ))
  suppressMessages(suppressWarnings(gllvmTMB(fmla, data = sim$data)))
}

make_fake_vp_fit <- function(family_ids, sd_B = rep(1, length(family_ids)),
                             sigma_eps = 1) {
  trait_levels <- paste0("trait_", seq_along(family_ids))
  data <- data.frame(
    trait = factor(rep(trait_levels, each = 2L), levels = trait_levels)
  )
  list(
    use = list(
      rr_B = FALSE,
      diag_B = TRUE,
      rr_W = FALSE,
      diag_W = FALSE,
      diag_species = FALSE,
      phylo_rr = FALSE,
      phylo_diag = FALSE,
      propto = FALSE
    ),
    report = list(
      sd_B = sd_B,
      sigma_eps = sigma_eps
    ),
    n_traits = length(family_ids),
    data = data,
    trait_col = "trait",
    tmb_data = list(
      family_id_vec = rep(as.integer(family_ids), each = 2L),
      link_id_vec = rep(0L, length(family_ids) * 2L),
      trait_id = rep(seq_along(family_ids) - 1L, each = 2L)
    )
  )
}

# =================== ordiplot ===========================================

test_that("ordiplot(): runs and returns scores+loadings invisibly", {
  fit <- make_rrB_fit(seed = 5, d = 2)
  pdf(NULL)   # capture plot output
  on.exit(dev.off(), add = TRUE)
  out <- suppressMessages(ordiplot(fit, level = "unit"))
  expect_named(out, c("scores", "loadings"))
  expect_equal(ncol(out$scores), 2L)
  expect_equal(ncol(out$loadings), 2L)
})

test_that("ordiplot(): biplot = FALSE still runs", {
  fit <- make_rrB_fit(seed = 7, d = 2)
  pdf(NULL); on.exit(dev.off(), add = TRUE)
  expect_no_error(
    suppressMessages(ordiplot(fit, level = "unit", biplot = FALSE))
  )
})

test_that("ordiplot(): axes wrong length errors", {
  fit <- make_rrB_fit(seed = 11, d = 2)
  pdf(NULL); on.exit(dev.off(), add = TRUE)
  expect_error(suppressMessages(ordiplot(fit, level = "unit", axes = c(1, 2, 3))),
               regexp = "length 2")
})

test_that("ordiplot(): axes index out of range errors", {
  fit <- make_rrB_fit(seed = 13, d = 2)
  pdf(NULL); on.exit(dev.off(), add = TRUE)
  expect_error(
    suppressMessages(ordiplot(fit, level = "unit", axes = c(1, 5))),
    regexp = "Not enough latent axes"
  )
})

test_that("ordiplot(): unknown rotate via match.arg errors", {
  fit <- make_rrB_fit(seed = 17, d = 2)
  pdf(NULL); on.exit(dev.off(), add = TRUE)
  expect_error(
    suppressMessages(ordiplot(fit, level = "unit", rotate = "oblimin")),
    regexp = "should be one of"
  )
})

test_that("ordiplot(): rotate = 'varimax' returns rotated scores", {
  fit <- make_rrB_fit(seed = 19, d = 2)
  pdf(NULL); on.exit(dev.off(), add = TRUE)
  out <- ordiplot(fit, level = "unit", rotate = "varimax")
  ## Should match getLV / getLoadings under varimax
  expect_equal(out$scores, getLV(fit, "unit", "varimax"))
  expect_equal(out$loadings, getLoadings(fit, "unit", "varimax"))
})

# =================== VP =================================================

test_that("VP(): rows sum to 1 (variance shares)", {
  fit <- make_rrB_fit(seed = 21, d = 2)
  M <- VP(fit)
  expect_true(is.matrix(M))
  expect_equal(unname(rowSums(M)), rep(1, nrow(M)), tolerance = 1e-8)
})

test_that("VP(): rownames are trait levels", {
  fit <- make_rrB_fit(seed = 23, d = 2)
  M <- VP(fit)
  expect_equal(rownames(M), levels(fit$data[[fit$trait_col]]))
})

test_that("VP(): only active components are columns", {
  ## Fit with only diag_B + diag_W: rr_B / rr_W columns must be absent
  sim <- simulate_site_trait(
    n_sites = 25, n_species = 5, n_traits = 3, mean_species_per_site = 3,
    psi_B = c(0.3, 0.3, 0.3), psi_W = c(0.3, 0.3, 0.3), seed = 7
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site) + indep(0 + trait | site_species),
    data = sim$data
  )
  M <- VP(fit)
  expect_true("diag_B" %in% colnames(M))
  expect_true("diag_W" %in% colnames(M))
  expect_false("rr_B" %in% colnames(M))
  expect_false("rr_W" %in% colnames(M))
})

test_that("VP(): residual column is present for Gaussian noise", {
  fit <- make_rrB_fit(seed = 29, d = 2)
  M <- VP(fit)
  expect_true("residual" %in% colnames(M))
})

test_that("VP(): pure Poisson fit does not add a fake Gaussian residual", {
  fit <- make_fake_vp_fit(family_ids = c(2L, 2L), sd_B = c(1, 2), sigma_eps = 1)
  M <- VP(fit)
  expect_false("residual" %in% colnames(M))
  expect_equal(colnames(M), "diag_B")
  expect_equal(unname(M[, "diag_B"]), c(1, 1))
})

test_that("VP(): mixed Gaussian and Poisson residual shares are trait-specific", {
  fit <- make_fake_vp_fit(family_ids = c(0L, 2L), sd_B = c(1, 2), sigma_eps = 1)
  M <- VP(fit)
  expect_true("residual" %in% colnames(M))
  expect_equal(M["trait_1", "diag_B"], 0.5)
  expect_equal(M["trait_1", "residual"], 0.5)
  expect_equal(M["trait_2", "diag_B"], 1)
  expect_equal(M["trait_2", "residual"], 0)
})

test_that("VP(): lognormal uses sigma_eps as the observation residual", {
  fit <- make_fake_vp_fit(family_ids = 3L, sd_B = 1, sigma_eps = 1)
  M <- VP(fit)
  expect_equal(M["trait_1", "diag_B"], 0.5)
  expect_equal(M["trait_1", "residual"], 0.5)
})

test_that("VP(): rr_B + diag_B fit has both columns", {
  fit <- make_rrB_fit(seed = 31, d = 2)
  M <- VP(fit)
  expect_true("rr_B" %in% colnames(M))
  expect_true("diag_B" %in% colnames(M))
})

test_that("VP(): n_traits rows, columns >= 1", {
  fit <- make_rrB_fit(seed = 35, d = 2)
  M <- VP(fit)
  expect_equal(nrow(M), fit$n_traits)
  expect_true(ncol(M) >= 1L)
})

test_that("VP(): all entries are non-negative", {
  fit <- make_rrB_fit(seed = 37, d = 2)
  M <- VP(fit)
  expect_true(all(M >= 0 - 1e-12))
})
