## Tests for block_V() and fit_site_meta(V = ...) -- block-diagonal
## known-V support for multivariate meta-regression with within-study
## sampling correlation.
## Note: fit_site_meta() is deprecated as of 0.1.1. These tests verify that
## the backward-compatible interface still works; calls are wrapped in
## suppressWarnings() to silence the deprecation notice.

test_that("block_V with rho_within = 0 equals diag(sampling_var)", {
  set.seed(1)
  study <- factor(rep(c("s1", "s2", "s3"), each = 2))
  var   <- c(0.04, 0.05, 0.06, 0.04, 0.05, 0.07)
  V0  <- block_V(study, var, rho_within = 0)
  expect_equal(V0, diag(var), tolerance = 1e-12)
})

test_that("block_V with positive rho creates within-study off-diagonals", {
  study <- factor(rep(c("s1", "s2"), each = 2))
  var   <- c(0.04, 0.04, 0.09, 0.09)
  V <- block_V(study, var, rho_within = 0.5)
  ## Within s1: off-diag = 0.5 * sqrt(0.04 * 0.04) = 0.5 * 0.04 = 0.02
  expect_equal(V[1, 2], 0.02, tolerance = 1e-12)
  expect_equal(V[2, 1], 0.02, tolerance = 1e-12)
  ## Within s2: off-diag = 0.5 * sqrt(0.09 * 0.09) = 0.045
  expect_equal(V[3, 4], 0.045, tolerance = 1e-12)
  ## Across studies: 0
  expect_equal(V[1, 3], 0)
  expect_equal(V[2, 4], 0)
})

test_that("block_V is symmetric and positive-definite", {
  set.seed(2)
  study <- factor(sample(paste0("s", 1:5), 20, replace = TRUE))
  var   <- runif(20, 0.01, 0.1)
  V <- block_V(study, var, rho_within = 0.4)
  expect_equal(V, t(V), tolerance = 1e-12)
  expect_true(all(eigen(V, symmetric = TRUE, only.values = TRUE)$values > 0))
})

test_that("block_V accepts per-study rho_within named vector", {
  study <- factor(rep(c("s1", "s2"), each = 2))
  var   <- c(0.04, 0.04, 0.09, 0.09)
  V <- block_V(study, var, rho_within = c(s1 = 0.2, s2 = 0.8))
  expect_equal(V[1, 2], 0.2 * 0.04, tolerance = 1e-12)
  expect_equal(V[3, 4], 0.8 * 0.09, tolerance = 1e-12)
})

test_that("block_V errors on length mismatch", {
  study <- factor(c("a", "a", "b"))
  expect_error(block_V(study, c(0.1, 0.2)), "must equal")
})

test_that("block_V errors on negative sampling_var", {
  study <- factor(c("a", "b"))
  expect_error(block_V(study, c(0.1, -0.05)), "non-negative")
})

test_that("block_V errors on rho_within out of (-1, 1)", {
  study <- factor(c("a", "b"))
  expect_error(block_V(study, c(0.1, 0.1), rho_within = 1.0), "strictly in")
  expect_error(block_V(study, c(0.1, 0.1), rho_within = -1.0), "strictly in")
})

test_that("block_V errors on missing study in named rho_within", {
  study <- factor(c("a", "a", "b", "b"))
  expect_error(
    block_V(study, c(0.1, 0.1, 0.2, 0.2), rho_within = c(a = 0.5)),
    "Missing rho_within entries"
  )
})

## fit_site_meta() / fit_trait_stage1() were dropped in 0.2.0 (see
## R/two-stage.R header). The tests below were retired with them; users
## now call gllvmTMB() directly with phylo_*/meta_known_V() keywords.
