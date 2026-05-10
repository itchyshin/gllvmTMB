## Per-cell weights matrix support in gllvmTMB_wide().
##
## Knuth's lme4-style weights port (commit 8a323197) made the long-format
## engine accept a per-row likelihood multiplier (`weights = w` in
## gllvmTMB()). This file pins the corresponding wide-format API: the
## user supplies weights parallel to Y, the wrapper pivots column-major
## in lockstep with Y, drops NA-aligned cells, validates non-negativity /
## finiteness, and dispatches to gllvmTMB() with the long-format weights
## vector.
##
## Contract:
##   * `weights = NULL` (default): unit weights; byte-identical to the
##     pre-port behaviour.
##   * `weights = numeric(nrow(Y))`: row-vector. Each cell (i, j) inherits
##     weights[i] for every column j. Common per-row case.
##   * `weights = matrix` of dim(Y): per-cell likelihood multiplier
##     (meta-analytic case).
##   * `weights = scalar`: broadcast to a constant matrix.
##   * Anything else: cli::cli_abort.
##   * NA-mask of weights matrix MUST match NA-mask of Y, else abort.
##
## Disambiguation when nrow(Y) == ncol(Y): `length(dim(weights))` decides.
## `NULL` (1-d) → vector / row-broadcast; `c(n, m)` (2-d) → per-cell.
##
## At wide level the semantic is always lme4-style multiplier. For
## binomial trial counts, users should still use the long-format API.

skip_if_not_installed("gllvmTMB")

# ---- shared simulated data -----------------------------------------------
make_small_Y <- function(n_sites = 25, n_species = 6, seed = 1) {
  set.seed(seed)
  matrix(rnorm(n_sites * n_species), n_sites, n_species,
         dimnames = list(paste0("S", seq_len(n_sites)),
                         paste0("sp", seq_len(n_species))))
}

# ---- Test 1: weights argument exists and accepts a matrix --------------
test_that("gllvmTMB_wide() accepts a per-cell weights matrix", {
  Y <- make_small_Y(n_sites = 25, n_species = 5)
  W <- matrix(1, nrow = nrow(Y), ncol = ncol(Y))
  fit <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = W)
  ))
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
})

# ---- Test 2: weights = NULL byte-identical to unit-weights matrix ------
test_that("weights = NULL byte-identical to weights = matrix(1, n, p)", {
  Y <- make_small_Y(n_sites = 25, n_species = 5, seed = 11)
  fit_null <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB_wide(Y, d = 1)
  ))
  fit_unit <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB_wide(Y, d = 1,
                            weights = matrix(1, nrow(Y), ncol(Y)))
  ))
  expect_equal(fit_null$opt$convergence, 0L)
  expect_equal(fit_unit$opt$convergence, 0L)
  expect_equal(fit_unit$opt$objective, fit_null$opt$objective,
               tolerance = 1e-10)
})

# ---- Test 3: column-major pivot correctness ----------------------------
# The wide → long pivot must be column-major (matching as.numeric(Y)).
# If we pass a weights matrix with distinct values per cell, the engine's
# weights_i vector must equal as.numeric(W) cell-for-cell.
#
# (Aside: the long-format SE-shrinkage / b_fix-invariance pattern that
# test-lme4-style-weights.R uses is structurally muted in the wide
# wrapper because the default formula includes `unique(0 + trait | site)`,
# a per-(site,trait) random intercept that saturates the residual when
# there is exactly one observation per cell. The long-format file already
# pins those downstream behaviours; here we pin the conversion.)
test_that("Weights matrix pivots column-major to weights_i", {
  Y <- make_small_Y(n_sites = 10, n_species = 4, seed = 13)
  W <- matrix(seq_len(nrow(Y) * ncol(Y)) / 10,
              nrow = nrow(Y), ncol = ncol(Y),
              dimnames = dimnames(Y))
  fit <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = W)
  ))
  expect_equal(fit$tmb_data$weights_i, as.numeric(W),
               tolerance = 1e-12)
})

# ---- Test 4: wide vs hand-pivoted long give the same fit ---------------
# The wide-format weights pipeline must be byte-equivalent to manually
# pivoting Y and W to long format and calling gllvmTMB() directly.
# This pins both the column-major pivot AND the equivalence to the long-
# format engine call — covering the actual conversion job of this PR.
test_that("Wide weights matrix matches hand-pivoted long-format fit", {
  Y <- make_small_Y(n_sites = 20, n_species = 4, seed = 14)
  set.seed(140)
  W <- matrix(runif(nrow(Y) * ncol(Y), 0.3, 3),
              nrow = nrow(Y), ncol = ncol(Y),
              dimnames = dimnames(Y))
  fit_wide <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = W)
  ))
  ## Hand-pivoted long-format fit using the EXACT layout gllvmTMB_wide
  ## constructs. Order: site varies fastest within species (column-major),
  ## matching as.numeric(Y).
  n_sites <- nrow(Y); n_species <- ncol(Y)
  long_df <- data.frame(
    site         = factor(rep(rownames(Y), n_species), levels = rownames(Y)),
    species      = factor(rep(colnames(Y), each = n_sites), levels = colnames(Y)),
    value        = as.numeric(Y),
    stringsAsFactors = FALSE
  )
  long_df$trait        <- long_df$species
  long_df$site_species <- factor(paste(long_df$site, long_df$species, sep = "_"))
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 1) +
            unique(0 + trait | site),
    data    = long_df,
    weights = as.numeric(W),
    silent  = TRUE
  )))
  expect_equal(fit_wide$opt$objective, fit_long$opt$objective,
               tolerance = 1e-8)
})

# ---- Test 5: NA handling ------------------------------------------------
test_that("NA cells in Y must be NA in weights, and rows are dropped", {
  Y <- make_small_Y(n_sites = 30, n_species = 5, seed = 5)
  ## Strategic NA cells: 6 cells.
  na_idx <- cbind(c(1L, 5L, 12L, 17L, 22L, 28L),
                  c(2L, 4L, 1L,  3L,  5L, 2L))
  Y[na_idx] <- NA_real_
  W <- matrix(1, nrow(Y), ncol(Y))
  W[na_idx] <- NA_real_
  fit <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = W)
  ))
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
  ## n_obs in the engine should be (n_sites * n_species) - n_NA.
  n_obs_expected <- nrow(Y) * ncol(Y) - nrow(na_idx)
  expect_equal(length(fit$tmb_data$weights_i), n_obs_expected)
  ## And the engine's weights_i must all be 1 (the unit cells we passed).
  expect_true(all(fit$tmb_data$weights_i == 1))
})

# ---- Test 6: error paths ------------------------------------------------
test_that("weights matrix wrong shape errors", {
  Y <- make_small_Y(n_sites = 20, n_species = 4, seed = 6)
  W_wrong <- matrix(1, nrow = 19, ncol = 4)
  expect_error(
    suppressMessages(gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = W_wrong)),
    regexp = "shape|dim|same shape|matrix"
  )
})

test_that("Negative weights at non-NA Y cells error", {
  Y <- make_small_Y(n_sites = 20, n_species = 4, seed = 7)
  W <- matrix(1, nrow(Y), ncol(Y))
  W[3, 2] <- -0.5
  expect_error(
    suppressMessages(gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = W)),
    regexp = "non-negative|negative"
  )
})

test_that("NA in weights at a non-NA Y cell errors (NA-mask mismatch)", {
  Y <- make_small_Y(n_sites = 20, n_species = 4, seed = 8)
  W <- matrix(1, nrow(Y), ncol(Y))
  W[3, 2] <- NA_real_   # Y[3,2] is non-NA, so weight NA is illegal
  expect_error(
    suppressMessages(gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = W)),
    regexp = "NA"
  )
})

test_that("Missing NA in weights when Y is NA errors", {
  Y <- make_small_Y(n_sites = 20, n_species = 4, seed = 9)
  Y[3, 2] <- NA_real_
  W <- matrix(1, nrow(Y), ncol(Y))   # weights[3,2] is non-NA but Y[3,2] is NA
  expect_error(
    suppressMessages(gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = W)),
    regexp = "NA"
  )
})

test_that("Non-numeric weights error with informative message", {
  Y <- make_small_Y(n_sites = 20, n_species = 4, seed = 10)
  expect_error(
    suppressMessages(gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = "a")),
    regexp = "matrix|numeric|scalar"
  )
})

# ---- Test 7: scalar broadcast ------------------------------------------
test_that("Scalar weights broadcast to a constant matrix", {
  Y <- make_small_Y(n_sites = 25, n_species = 5, seed = 12)
  fit_scalar <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = 0.5)
  ))
  fit_matrix <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB_wide(Y, d = 1,
                            weights = matrix(0.5, nrow(Y), ncol(Y)))
  ))
  expect_equal(fit_scalar$opt$convergence, 0L)
  expect_equal(fit_matrix$opt$convergence, 0L)
  expect_equal(fit_scalar$opt$objective, fit_matrix$opt$objective,
               tolerance = 1e-10)
})

# ---- Test 8: vector broadcast (per-row) --------------------------------
# weights = numeric(nrow(Y)) should be broadcast across columns of Y
# (each cell (i, j) inherits weights[i]). Byte-identical to a manually
# row-broadcast matrix. This is the common case (per-row sample size,
# per-individual study weight, etc.).
test_that("Vector weights are broadcast row-wise across columns", {
  Y <- make_small_Y(n_sites = 25, n_species = 5, seed = 15)
  set.seed(150)
  w_row <- runif(nrow(Y), 0.5, 2)
  fit_vec <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = w_row)
  ))
  ## Hand-broadcast equivalent: each column of W copies w_row.
  W_full <- matrix(rep(w_row, ncol(Y)), nrow = nrow(Y), ncol = ncol(Y))
  fit_mat <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = W_full)
  ))
  expect_equal(fit_vec$opt$convergence, 0L)
  expect_equal(fit_mat$opt$convergence, 0L)
  expect_equal(fit_vec$opt$objective, fit_mat$opt$objective,
               tolerance = 1e-10)
  ## And the resulting weights_i must match: W_full as.numeric() is
  ## column-major, which equals rep(w_row, n_species) for the broadcast
  ## case. Confirm cell-for-cell.
  expect_equal(fit_vec$tmb_data$weights_i,
               as.numeric(W_full), tolerance = 1e-12)
})

# ---- Test 9: vector length validation ----------------------------------
test_that("Vector weights with wrong length error", {
  Y <- make_small_Y(n_sites = 25, n_species = 5, seed = 16)
  w_wrong <- runif(nrow(Y) - 3)   # length mismatch
  expect_error(
    suppressMessages(gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = w_wrong)),
    regexp = "length|nrow|shape"
  )
  ## And a length matching ncol(Y) but not nrow(Y) on a non-square
  ## matrix must also error (caught by the "must equal nrow(Y)" rule).
  expect_error(
    suppressMessages(
      gllvmTMB::gllvmTMB_wide(Y, d = 1, weights = runif(ncol(Y)))
    ),
    regexp = "length|nrow|shape"
  )
})
