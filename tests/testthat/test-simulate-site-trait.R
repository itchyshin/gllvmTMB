# Argument-by-argument coverage for simulate_site_trait().
# Strategy: small data, vary one argument, verify the output reflects it.

# ---- shape & default factors ---------------------------------------------

test_that("simulate_site_trait(): n_sites controls n_sites in output", {
  s1 <- simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 2,
                            mean_species_per_site = 3, seed = 1)
  expect_equal(nlevels(s1$data$site), 10L)
  s2 <- simulate_site_trait(n_sites = 30, n_species = 4, n_traits = 2,
                            mean_species_per_site = 3, seed = 1)
  expect_equal(nlevels(s2$data$site), 30L)
})

test_that("simulate_site_trait(): n_species controls n_species in output", {
  s <- simulate_site_trait(n_sites = 20, n_species = 8, n_traits = 2,
                           mean_species_per_site = 3, seed = 1)
  expect_equal(nlevels(s$data$species), 8L)
})

test_that("simulate_site_trait(): n_traits controls n_traits in output", {
  s <- simulate_site_trait(n_sites = 20, n_species = 4, n_traits = 5,
                           mean_species_per_site = 3, seed = 1)
  expect_equal(nlevels(s$data$trait), 5L)
})

test_that("simulate_site_trait(): mean_species_per_site changes total rows", {
  ## Higher mean -> more rows
  s_low  <- simulate_site_trait(n_sites = 30, n_species = 10, n_traits = 2,
                                mean_species_per_site = 2, seed = 1)
  s_high <- simulate_site_trait(n_sites = 30, n_species = 10, n_traits = 2,
                                mean_species_per_site = 8, seed = 1)
  expect_gt(nrow(s_high$data), nrow(s_low$data))
})

test_that("simulate_site_trait(): n_predictors adds env_1, env_2, ...", {
  s2 <- simulate_site_trait(n_sites = 20, n_species = 4, n_traits = 2,
                            mean_species_per_site = 3, n_predictors = 2,
                            seed = 1)
  expect_true(all(c("env_1", "env_2") %in% names(s2$data)))
  s3 <- simulate_site_trait(n_sites = 20, n_species = 4, n_traits = 2,
                            mean_species_per_site = 3, n_predictors = 3,
                            seed = 1)
  expect_true(all(c("env_1", "env_2", "env_3") %in% names(s3$data)))
})

# ---- alpha & beta arguments ----------------------------------------------

test_that("simulate_site_trait(): alpha is honoured exactly in truth", {
  alpha_in <- c(-1.5, 0, 2.5, -0.4)
  s <- simulate_site_trait(n_sites = 15, n_species = 4, n_traits = 4,
                           mean_species_per_site = 3, alpha = alpha_in,
                           seed = 1)
  expect_equal(s$truth$alpha, alpha_in)
})

test_that("simulate_site_trait(): beta is honoured exactly in truth", {
  beta_in <- matrix(c(0.5, -0.5, 0.0,
                      0.0,  0.5, -0.5), byrow = TRUE, nrow = 3, ncol = 2)
  s <- simulate_site_trait(n_sites = 15, n_species = 4, n_traits = 3,
                           mean_species_per_site = 3, beta = beta_in,
                           seed = 1)
  expect_equal(s$truth$beta, beta_in)
})

test_that("simulate_site_trait(): wrong-length alpha errors", {
  expect_error(
    simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 3,
                        alpha = c(1, 2),  # length 2 but n_traits 3
                        seed = 1),
    regexp = "alpha"
  )
})

test_that("simulate_site_trait(): wrong-shape beta errors", {
  expect_error(
    simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 3,
                        n_predictors = 2,
                        beta = matrix(0, 2, 2),  # wrong nrow
                        seed = 1),
    regexp = "beta"
  )
})

# ---- sigma2_eps ----------------------------------------------------------

test_that("simulate_site_trait(): sigma2_eps stored in truth", {
  s <- simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 2,
                           mean_species_per_site = 3, sigma2_eps = 1.5,
                           seed = 1)
  expect_equal(s$truth$sigma2_eps, 1.5)
})

# ---- Lambda_B / Lambda_W -------------------------------------------------

test_that("simulate_site_trait(): Lambda_B stored verbatim in truth", {
  L <- matrix(c(1, 0.5, 0.0, 0.3, -0.2, 0.7), nrow = 3, ncol = 2)
  s <- simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 3,
                           mean_species_per_site = 2, Lambda_B = L, seed = 1)
  expect_identical(s$truth$Lambda_B, L)
})

test_that("simulate_site_trait(): Lambda_W stored verbatim in truth", {
  L <- matrix(c(0.6, -0.1, 0.4), nrow = 3, ncol = 1)
  s <- simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 3,
                           mean_species_per_site = 2, Lambda_W = L, seed = 1)
  expect_identical(s$truth$Lambda_W, L)
})

test_that("simulate_site_trait(): wrong-nrow Lambda_B errors", {
  ## n_traits = 3 but Lambda_B has 2 rows
  expect_error(
    simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 3,
                        mean_species_per_site = 2,
                        Lambda_B = matrix(0, 2, 1),
                        seed = 1)
  )
})

# ---- psi_B / psi_W -----------------------------------------------------------

test_that("simulate_site_trait(): psi_B is recycled to length n_traits in truth", {
  ## psi_B = scalar 0.4 -> truth$psi_B should be length n_traits after rep_len
  s <- simulate_site_trait(n_sites = 12, n_species = 4, n_traits = 3,
                           mean_species_per_site = 2, psi_B = 0.4, seed = 1)
  expect_length(s$truth$psi_B, 3L)
  expect_true(all(s$truth$psi_B == 0.4))
})

test_that("simulate_site_trait(): psi_W is recycled to length n_traits in truth", {
  s <- simulate_site_trait(n_sites = 12, n_species = 4, n_traits = 4,
                           mean_species_per_site = 2, psi_W = 0.5, seed = 1)
  expect_length(s$truth$psi_W, 4L)
})

# ---- sigma2_phy + Cphy ---------------------------------------------------

test_that("simulate_site_trait(): Cphy with sigma2_phy stored, Cphy returned", {
  n <- 5
  Cphy <- diag(n)
  s <- simulate_site_trait(n_sites = 12, n_species = n, n_traits = 3,
                           mean_species_per_site = 2,
                           Cphy = Cphy, sigma2_phy = c(0.2, 0.3, 0.4),
                           seed = 1)
  expect_identical(s$Cphy, Cphy)
  expect_length(s$truth$sigma2_phy, 3L)
})

test_that("simulate_site_trait(): Cphy of wrong size errors", {
  expect_error(
    simulate_site_trait(n_sites = 10, n_species = 5, n_traits = 2,
                        mean_species_per_site = 2,
                        Cphy = diag(3), sigma2_phy = c(0.5, 0.5),
                        seed = 1)
  )
})

# ---- spatial coords + sigma2_spa -----------------------------------------

test_that("simulate_site_trait(): spatial generates lon/lat columns", {
  s <- simulate_site_trait(n_sites = 15, n_species = 4, n_traits = 2,
                           mean_species_per_site = 2,
                           spatial_range = 0.5,
                           sigma2_spa = c(0.3, 0.3),
                           seed = 1)
  expect_true(all(c("lon", "lat") %in% names(s$data)))
  expect_false(is.null(s$coords))
})

test_that("simulate_site_trait(): user-supplied coords used verbatim", {
  coords <- cbind(lon = seq(0, 1, length.out = 10),
                  lat = seq(0, 1, length.out = 10))
  s <- simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 2,
                           mean_species_per_site = 2,
                           spatial_range = 0.4,
                           sigma2_spa = c(0.3, 0.3),
                           coords = coords, seed = 1)
  expect_identical(s$coords, coords)
})

test_that("simulate_site_trait(): no spatial term means no coords/lon/lat", {
  s <- simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 2,
                           mean_species_per_site = 2, seed = 1)
  expect_null(s$coords)
  expect_false("lon" %in% names(s$data))
})

test_that("simulate_site_trait(): spatial_range alone errors and names sigma2_spa (#1419)", {
  sim_args <- list(n_sites = 20, n_species = 5, n_traits = 3,
                   mean_species_per_site = 3, seed = 4)
  baseline <- do.call(simulate_site_trait, sim_args)
  err <- expect_error(
    do.call(simulate_site_trait, c(sim_args, list(spatial_range = 0.3))),
    class = "rlang_error"
  )
  expect_match(conditionMessage(err), "sigma2_spa")
  err2 <- expect_error(
    do.call(simulate_site_trait, c(sim_args, list(sigma2_spa = 2))),
    class = "rlang_error"
  )
  expect_match(conditionMessage(err2), "spatial_range")
  with_spatial <- do.call(simulate_site_trait,
                          c(sim_args, list(spatial_range = 0.3, sigma2_spa = 2)))
  expect_false(isTRUE(all.equal(baseline$data, with_spatial$data)))
})

# ---- seed reproducibility ------------------------------------------------

test_that("simulate_site_trait(): same seed produces identical $data", {
  s1 <- simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 2,
                            mean_species_per_site = 3, seed = 99)
  s2 <- simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 2,
                            mean_species_per_site = 3, seed = 99)
  expect_identical(s1$data, s2$data)
})

test_that("simulate_site_trait(): different seed produces different values", {
  s1 <- simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 2,
                            mean_species_per_site = 3, seed = 99)
  s2 <- simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 2,
                            mean_species_per_site = 3, seed = 100)
  expect_false(isTRUE(all.equal(s1$data$value, s2$data$value)))
})

# ---- combined truth list -------------------------------------------------

test_that("simulate_site_trait(): truth list contains all expected names", {
  s <- simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 2,
                           mean_species_per_site = 3, seed = 1)
  expect_named(s, c("data", "truth", "Cphy", "coords"))
  expect_named(
    s$truth,
    c("alpha", "beta", "sigma2_eps", "Lambda_B", "Lambda_W",
      "psi_B", "psi_W", "sigma2_phy", "sigma2_sp", "sigma2_spa", "spatial_range",
      "z_B", "z_W")
  )
})

# ---- edge cases ----------------------------------------------------------

test_that("simulate_site_trait(): n_species = 1 still produces valid data", {
  s <- simulate_site_trait(n_sites = 10, n_species = 1, n_traits = 2,
                           mean_species_per_site = 1, seed = 1)
  expect_equal(nlevels(s$data$species), 1L)
  expect_gt(nrow(s$data), 0)
})

test_that("simulate_site_trait(): n_traits = 1 produces a single-trait dataset", {
  s <- simulate_site_trait(n_sites = 10, n_species = 4, n_traits = 1,
                           mean_species_per_site = 3, seed = 1)
  expect_equal(nlevels(s$data$trait), 1L)
})

test_that("simulate_site_trait(): n_predictors = 0 gives a covariate-free dataset (#1559)", {
  s <- simulate_site_trait(n_sites = 10, n_species = 3, n_traits = 2,
                           n_predictors = 0, seed = 1)
  expect_gt(nrow(s$data), 0)
  expect_false(any(grepl("^env_", names(s$data))))
  expect_equal(dim(s$truth$beta), c(2L, 0L))
  ## Same data-generating process as an explicit all-zero slope matrix.
  s0 <- simulate_site_trait(n_sites = 10, n_species = 3, n_traits = 2,
                            n_predictors = 0, beta = matrix(0, 2, 0), seed = 1)
  expect_equal(s$data, s0$data)
})

test_that("simulate_site_trait(): invalid n_predictors is rejected clearly (#1559)", {
  expect_error(simulate_site_trait(n_predictors = -1), "n_predictors")
  expect_error(simulate_site_trait(n_predictors = 1.5), "n_predictors")
})

# ---- output is unchanged by the vectorised row builder (#1581) -----------
## Reference fingerprints were recorded from the per-row data.frame + rbind
## implementation. rlang::hash() of the whole object is not stable across R
## and rlang versions, so the check uses numeric fingerprints (row count, sum,
## position-weighted sum of `value`, and the sum of numeric truth entries)
## compared with a tolerance. Together they pin the RNG draw order, the row
## order and the values; the column types and levels are checked directly.

test_that("simulate_site_trait(): output is identical to the per-row builder (#1581)", {
  fingerprint <- function(r) {
    d <- r$data
    c(nrow = nrow(d),
      sum  = sum(d$value),
      wsum = sum(d$value * seq_along(d$value)),
      tsum = sum(vapply(r$truth, function(x) if (is.numeric(x)) sum(x) else 0, 0)))
  }
  shapes <- list(
    a = list(n_sites = 30, n_species = 8, n_traits = 3,
             mean_species_per_site = 4, seed = 11),
    b = list(n_sites = 20, n_species = 6, n_traits = 1,
             mean_species_per_site = 3, seed = 12),
    c = list(n_sites = 25, n_species = 7, n_traits = 2,
             mean_species_per_site = 3, alpha = c(0, 1),
             beta = matrix(c(.3, -.2, .1, .4), 2, 2), seed = 13),
    d = list(n_sites = 20, n_species = 6, n_traits = 3,
             mean_species_per_site = 3,
             Lambda_W = matrix(c(.8, .5, .2), 3, 1), psi_W = c(.2, .3, .4),
             Lambda_B = matrix(c(.6, .4, .3), 3, 1), psi_B = .1,
             sigma2_sp = .3, seed = 14),
    e = list(n_sites = 15, n_species = 5, n_traits = 2,
             mean_species_per_site = 2, spatial_range = .5, sigma2_spa = .4,
             sigma2_phy = .5, Cphy = diag(5), seed = 15),
    f = list(n_sites = 10, n_species = 1, n_traits = 2,
             mean_species_per_site = 1, seed = 16)
  )
  expected <- list(
    a = c(nrow = 339, sum = -199.70537643, wsum = -36399.26042864, tsum = -1.18874735),
    b = c(nrow = 62,  sum = -88.39397443,  wsum = -2184.59185211, tsum = -0.67035510),
    c = c(nrow = 154, sum = 60.91846965,   wsum = 4733.93077867,  tsum = 2.10000000),
    d = c(nrow = 141, sum = 125.72984104,  wsum = 9429.80583103,  tsum = -4.13748324),
    e = c(nrow = 62,  sum = 52.28838819,   wsum = 1385.44239138,  tsum = 4.78504861),
    f = c(nrow = 20,  sum = 6.24128598,    wsum = 65.20997237,    tsum = 1.01673560)
  )
  for (nm in names(shapes)) {
    s <- do.call(simulate_site_trait, shapes[[nm]])
    expect_equal(fingerprint(s), expected[[nm]], tolerance = 1e-6, info = nm)
    expect_identical(names(s$data)[1:5],
                     c("site", "species", "site_species", "trait", "value"),
                     info = nm)
    expect_true(all(vapply(s$data[c("site", "species", "site_species", "trait")],
                           is.factor, logical(1))), info = nm)
    expect_identical(levels(s$data$trait),
                     paste0("trait_", seq_len(shapes[[nm]]$n_traits)), info = nm)
    expect_identical(rownames(s$data), as.character(seq_len(nrow(s$data))),
                     info = nm)
  }
})

test_that("simulate_site_trait(): 1.5k rows build quickly (#1581)", {
  skip_on_cran()
  el <- system.time(
    s <- simulate_site_trait(n_sites = 100, n_species = 20, n_traits = 3,
                             mean_species_per_site = 5, seed = 1)
  )[["elapsed"]]
  expect_gt(nrow(s$data), 1000)
  expect_lt(el, 0.15)
})
