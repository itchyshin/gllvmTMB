# Tests for the wide-matrix entry point gllvmTMB_wide().
# It pivots a site x species matrix Y into long format and dispatches
# to gllvmTMB(). These tests cover argument validation, default factor
# names, and that the fit converges.

make_small_Y <- function(n_sites = 25, n_species = 6, seed = 1) {
  set.seed(seed)
  Y <- matrix(rnorm(n_sites * n_species), n_sites, n_species,
              dimnames = list(paste0("S", seq_len(n_sites)),
                              paste0("sp", seq_len(n_species))))
  Y
}

# ---- argument validation -------------------------------------------------

test_that("gllvmTMB_wide(): Y must be matrix or data.frame", {
  expect_error(gllvmTMB_wide(Y = list(1:3)), regexp = "matrix or data frame")
  expect_error(gllvmTMB_wide(Y = 1:5), regexp = "matrix or data frame")
})

test_that("gllvmTMB_wide(): X with mismatched nrow errors", {
  Y <- make_small_Y(n_sites = 25)
  X <- data.frame(env = rnorm(10))   # off
  expect_error(
    gllvmTMB_wide(Y = Y, X = X, d = 1),
    regexp = "nrow"
  )
})

# ---- default names -------------------------------------------------------

test_that("gllvmTMB_wide(): missing colnames(Y) get sp1..spN defaults", {
  Y <- make_small_Y(n_species = 5)
  colnames(Y) <- NULL
  fit <- gllvmTMB_wide(Y, d = 1)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(all(c("sp1", "sp2", "sp3", "sp4", "sp5") %in%
                  levels(fit$data$species)))
})

test_that("gllvmTMB_wide(): missing rownames(Y) get site1..siteN defaults", {
  Y <- make_small_Y(n_sites = 25)
  rownames(Y) <- NULL
  fit <- gllvmTMB_wide(Y, d = 1)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true("site1" %in% levels(fit$data$site))
})

# ---- d argument ----------------------------------------------------------

test_that("gllvmTMB_wide(): d = 1 produces a rank-1 Lambda_B", {
  Y <- make_small_Y()
  fit <- gllvmTMB_wide(Y, d = 1)
  L <- getLoadings(fit, level = "B")
  expect_equal(ncol(L), 1L)
})

test_that("gllvmTMB_wide(): d = 2 produces a rank-2 Lambda_B", {
  Y <- make_small_Y()
  fit <- suppressMessages(gllvmTMB_wide(Y, d = 2))
  L <- suppressMessages(getLoadings(fit, level = "B"))
  expect_equal(ncol(L), 2L)
})

# ---- formula_extra argument ----------------------------------------------

test_that("gllvmTMB_wide(): formula_extra = ~ env_temp adds a fixed effect", {
  Y <- make_small_Y(n_sites = 30)
  X <- data.frame(env_temp = rnorm(30))
  fit <- gllvmTMB_wide(Y, X = X, d = 1, formula_extra = ~ env_temp)
  expect_s3_class(fit, "gllvmTMB_multi")
  ## The coefficient names should mention env_temp
  expect_true(any(grepl("env_temp", fit$X_fix_names)))
})

test_that("gllvmTMB_wide(): formula_extra = ~ 1 leaves the formula unchanged", {
  Y <- make_small_Y()
  fit <- gllvmTMB_wide(Y, d = 1, formula_extra = ~ 1)
  expect_s3_class(fit, "gllvmTMB_multi")
  ## No 'env_*' columns should be present in the design matrix
  expect_false(any(grepl("env_", fit$X_fix_names)))
})

# ---- family argument propagates ------------------------------------------

test_that("gllvmTMB_wide(): default family is gaussian()", {
  Y <- make_small_Y()
  fit <- gllvmTMB_wide(Y, d = 1)
  expect_equal(fit$family$family, "gaussian")
})

# ---- conversion correctness ----------------------------------------------

test_that("gllvmTMB_wide() and gllvmTMB() on equivalent long-format data give the same logLik", {
  ## Build a Y matrix and then translate it manually to long format,
  ## fit both, and compare log-likelihoods (parameters / Lambda differ
  ## up to rotation, but logLik is invariant).
  Y <- make_small_Y(n_sites = 20, n_species = 5, seed = 42)
  fit_w <- gllvmTMB_wide(Y, d = 1)

  ## Recreate the exact long format used inside gllvmTMB_wide()
  n_sites <- nrow(Y); n_species <- ncol(Y)
  long_df <- data.frame(
    site         = factor(rep(rownames(Y), n_species), levels = rownames(Y)),
    species      = factor(rep(colnames(Y), each = n_sites), levels = colnames(Y)),
    value        = as.numeric(Y),
    stringsAsFactors = FALSE
  )
  long_df$trait        <- long_df$species
  long_df$site_species <- factor(paste(long_df$site, long_df$species, sep = "_"))

  fit_l <- gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 1) +
            unique(0 + trait | site),
    data = long_df
  )
  ll_w <- -fit_w$opt$objective
  ll_l <- -fit_l$opt$objective
  expect_equal(ll_w, ll_l, tolerance = 1e-4)
})

test_that("gllvmTMB_wide(): setting d explicitly propagates to fit", {
  Y <- make_small_Y(n_sites = 25, n_species = 5)
  fit_d2 <- suppressMessages(gllvmTMB_wide(Y, d = 2))
  expect_equal(fit_d2$d_B, 2L)
  fit_d1 <- gllvmTMB_wide(Y, d = 1)
  expect_equal(fit_d1$d_B, 1L)
})
