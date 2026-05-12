## Phase 3: unified weight-shape contract across long, matrix-wide, and
## traits() entry points.

phase3_make_Y <- function(n_sites = 18, n_traits = 3, seed = 913) {
  set.seed(seed)
  matrix(
    rnorm(n_sites * n_traits),
    nrow = n_sites,
    ncol = n_traits,
    dimnames = list(
      paste0("S", seq_len(n_sites)),
      paste0("trait_", seq_len(n_traits))
    )
  )
}

phase3_long_from_Y <- function(Y, X = NULL) {
  n_sites <- nrow(Y)
  n_traits <- ncol(Y)
  long <- data.frame(
    site = factor(rep(rownames(Y), n_traits), levels = rownames(Y)),
    species = factor(rep(colnames(Y), each = n_sites), levels = colnames(Y)),
    value = as.numeric(Y),
    stringsAsFactors = FALSE
  )
  long$trait <- long$species
  long$site_species <- factor(paste(long$site, long$species, sep = "_"))
  if (!is.null(X)) {
    X <- as.data.frame(X)
    X$site <- factor(rownames(Y), levels = rownames(Y))
    x_match <- match(long$site, X$site)
    x_cols <- setdiff(names(X), "site")
    long <- cbind(long, X[x_match, x_cols, drop = FALSE])
  }
  long
}

phase3_fit_long <- function(long, weights = NULL, extra = FALSE) {
  rhs <- if (isTRUE(extra)) {
    value ~ 0 +
      trait +
      (0 + trait):env_temp +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site)
  } else {
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site)
  }
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    rhs,
    data = long,
    weights = weights,
    family = gaussian(),
    silent = TRUE
  )))
}

phase3_expect_engine_equal <- function(
  x,
  y,
  tolerance = sqrt(.Machine$double.eps)
) {
  expect_equal(x$tmb_data$X_fix, y$tmb_data$X_fix, tolerance = tolerance)
  expect_equal(levels(x$data[[x$trait_col]]), levels(y$data[[y$trait_col]]))
  expect_equal(
    x$tmb_data$weights_i,
    y$tmb_data$weights_i,
    tolerance = tolerance
  )
  expect_equal(x$tmb_data$family_id_vec, y$tmb_data$family_id_vec)
  expect_equal(
    x$tmb_obj$fn(x$tmb_obj$par),
    y$tmb_obj$fn(y$tmb_obj$par),
    tolerance = tolerance
  )
}

test_that("normalise_weights() applies the shared shape rules", {
  expect_equal(
    gllvmTMB:::normalise_weights(
      weights = c(2, 3),
      response_shape = "wide_matrix",
      n_obs = 6,
      n_units = 2,
      n_traits = 3
    ),
    as.numeric(matrix(rep(c(2, 3), times = 3), nrow = 2, ncol = 3))
  )

  na_mask <- matrix(FALSE, nrow = 2, ncol = 2)
  na_mask[2, 1] <- TRUE
  expect_equal(
    gllvmTMB:::normalise_weights(
      weights = 0.5,
      response_shape = "wide_matrix",
      n_obs = 3,
      n_units = 2,
      n_traits = 2,
      na_mask = na_mask
    ),
    c(0.5, 0.5, 0.5)
  )

  expect_error(
    gllvmTMB:::normalise_weights(
      weights = matrix(1, 2, 2),
      response_shape = "long",
      n_obs = 4
    ),
    regexp = "gllvmTMB_wide"
  )
  expect_error(
    gllvmTMB:::normalise_weights(
      weights = matrix(1, 2, 2),
      response_shape = "wide_df",
      n_obs = 4,
      n_units = 2,
      n_traits = 2
    ),
    regexp = "gllvmTMB_wide"
  )
})

test_that("plain Gaussian no-weight fits match between long and wide matrix entry points", {
  Y <- phase3_make_Y(seed = 914)
  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB_wide(
    Y,
    d = 1,
    family = gaussian()
  )))
  fit_long <- phase3_fit_long(phase3_long_from_Y(Y))

  phase3_expect_engine_equal(fit_wide, fit_long)
})

test_that("row-broadcast weights match between long and wide matrix entry points", {
  Y <- phase3_make_Y(seed = 915)
  w_row <- seq(0.5, 1.7, length.out = nrow(Y))
  W <- matrix(rep(w_row, times = ncol(Y)), nrow = nrow(Y), ncol = ncol(Y))

  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB_wide(
    Y,
    d = 1,
    family = gaussian(),
    weights = w_row
  )))
  fit_long <- phase3_fit_long(
    phase3_long_from_Y(Y),
    weights = as.numeric(W)
  )

  phase3_expect_engine_equal(fit_wide, fit_long)
})

test_that("per-cell weights match between long and wide matrix entry points", {
  Y <- phase3_make_Y(seed = 916)
  W <- matrix(
    seq(0.4, 2.4, length.out = length(Y)),
    nrow = nrow(Y),
    ncol = ncol(Y),
    dimnames = dimnames(Y)
  )

  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB_wide(
    Y,
    d = 1,
    family = gaussian(),
    weights = W
  )))
  fit_long <- phase3_fit_long(
    phase3_long_from_Y(Y),
    weights = as.numeric(W)
  )

  phase3_expect_engine_equal(fit_wide, fit_long)
})

test_that("wide matrix weights stay aligned when site-level X is attached", {
  Y <- phase3_make_Y(seed = 917)
  X <- data.frame(env_temp = seq(-1, 1, length.out = nrow(Y)))
  w_row <- seq(0.25, 2, length.out = nrow(Y))
  W <- matrix(rep(w_row, times = ncol(Y)), nrow = nrow(Y), ncol = ncol(Y))

  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB_wide(
    Y,
    X = X,
    d = 1,
    formula_extra = ~env_temp,
    weights = w_row,
    family = gaussian()
  )))
  fit_long <- phase3_fit_long(
    phase3_long_from_Y(Y, X),
    weights = as.numeric(W),
    extra = TRUE
  )

  phase3_expect_engine_equal(fit_wide, fit_long)
  expect_equal(fit_wide$tmb_data$weights_i, as.numeric(W))
})

test_that("traits() weights round-trip to an equivalent long-format fit", {
  skip_if_not_installed("tidyr")
  Y <- phase3_make_Y(n_sites = 16, n_traits = 3, seed = 918)
  wide <- data.frame(
    individual = rownames(Y),
    env_temp = seq(-0.5, 0.5, length.out = nrow(Y)),
    Y,
    check.names = FALSE
  )
  trait_cols <- colnames(Y)
  w_row <- seq(0.7, 1.9, length.out = nrow(wide))

  fit_traits <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(tidyselect::all_of(trait_cols)) ~ 0 +
      trait +
      (0 + trait):env_temp +
      latent(0 + trait | individual, d = 1) +
      unique(0 + trait | individual),
    data = wide,
    unit = "individual",
    weights = w_row,
    family = gaussian(),
    silent = TRUE
  )))

  long <- tidyr::pivot_longer(
    wide,
    cols = tidyselect::all_of(trait_cols),
    names_to = "trait",
    values_to = ".y_wide_",
    values_drop_na = TRUE
  )
  long$trait <- factor(long$trait, levels = trait_cols)
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    .y_wide_ ~ 0 +
      trait +
      (0 + trait):env_temp +
      latent(0 + trait | individual, d = 1) +
      unique(0 + trait | individual),
    data = long,
    unit = "individual",
    weights = rep(w_row, each = length(trait_cols)),
    family = gaussian(),
    silent = TRUE
  )))

  phase3_expect_engine_equal(fit_traits, fit_long)
})
