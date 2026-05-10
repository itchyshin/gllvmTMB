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
    Lambda_B = Lam, S_B = rep(0.3, n_traits), seed = seed
  )
  fmla <- stats::as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | site, d = %d) + unique(0 + trait | site)",
    d
  ))
  suppressMessages(suppressWarnings(gllvmTMB(fmla, data = sim$data)))
}

# =================== ordiplot ===========================================

test_that("ordiplot(): runs and returns scores+loadings invisibly", {
  fit <- make_rrB_fit(seed = 5, d = 2)
  pdf(NULL)   # capture plot output
  on.exit(dev.off(), add = TRUE)
  out <- suppressMessages(ordiplot(fit, level = "B"))
  expect_named(out, c("scores", "loadings"))
  expect_equal(ncol(out$scores), 2L)
  expect_equal(ncol(out$loadings), 2L)
})

test_that("ordiplot(): biplot = FALSE still runs", {
  fit <- make_rrB_fit(seed = 7, d = 2)
  pdf(NULL); on.exit(dev.off(), add = TRUE)
  expect_no_error(
    suppressMessages(ordiplot(fit, level = "B", biplot = FALSE))
  )
})

test_that("ordiplot(): axes wrong length errors", {
  fit <- make_rrB_fit(seed = 11, d = 2)
  pdf(NULL); on.exit(dev.off(), add = TRUE)
  expect_error(suppressMessages(ordiplot(fit, level = "B", axes = c(1, 2, 3))),
               regexp = "length 2")
})

test_that("ordiplot(): axes index out of range errors", {
  fit <- make_rrB_fit(seed = 13, d = 2)
  pdf(NULL); on.exit(dev.off(), add = TRUE)
  expect_error(
    suppressMessages(ordiplot(fit, level = "B", axes = c(1, 5))),
    regexp = "Not enough latent axes"
  )
})

test_that("ordiplot(): unknown rotate via match.arg errors", {
  fit <- make_rrB_fit(seed = 17, d = 2)
  pdf(NULL); on.exit(dev.off(), add = TRUE)
  expect_error(
    suppressMessages(ordiplot(fit, level = "B", rotate = "oblimin")),
    regexp = "should be one of"
  )
})

test_that("ordiplot(): rotate = 'varimax' returns rotated scores", {
  fit <- make_rrB_fit(seed = 19, d = 2)
  pdf(NULL); on.exit(dev.off(), add = TRUE)
  out <- ordiplot(fit, level = "B", rotate = "varimax")
  ## Should match getLV / getLoadings under varimax
  expect_equal(out$scores, getLV(fit, "B", "varimax"))
  expect_equal(out$loadings, getLoadings(fit, "B", "varimax"))
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
    S_B = c(0.3, 0.3, 0.3), S_W = c(0.3, 0.3, 0.3), seed = 7
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | site) + unique(0 + trait | site_species),
    data = sim$data
  )
  M <- VP(fit)
  expect_true("diag_B" %in% colnames(M))
  expect_true("diag_W" %in% colnames(M))
  expect_false("rr_B" %in% colnames(M))
  expect_false("rr_W" %in% colnames(M))
})

test_that("VP(): residual column always present (Gaussian noise)", {
  fit <- make_rrB_fit(seed = 29, d = 2)
  M <- VP(fit)
  expect_true("residual" %in% colnames(M))
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
