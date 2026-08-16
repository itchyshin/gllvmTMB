## Arc0 masked-cell accuracy probe -- DGP + mask generators.
## Sourced by dev/missing-accuracy-arc0-recovery.R. Uses the INSTALLED
## gllvmTMB package only (no devtools::load_all -- see driver header).
##
## Wide-data grammar copied from tests/testthat/test-missing-response-traits.R
## (traits(...) ~ ... , unit = <site col>, family = <fam>()) and the
## `latent(1 | unit, d = K, unique = FALSE)` loadings-only spelling from
## tests/testthat/test-missing-response-nongaussian.R's long-format analogue
## (`latent(0 + trait | unit, d = 1, unique = FALSE)`).

#' Simulate one wide n_units x p_traits dataset from a q_true-factor loading
#' model, for either family.
#'
#' Gaussian: eta = b0 + U %*% t(Lambda); Y = eta + N(0, sigma_j^2), sigma_j
#' drawn per trait from lognormal(meanlog = log(0.5), sdlog = 0.3) --
#' i.e. an ANISOTROPIC (per-trait) residual sd. The model we FIT uses ordinary
#' loadings-only latent() with no diag(psi) term, so its residual noise comes
#' from the family's own (isotropic) gaussian dispersion -- this DGP/fit
#' mismatch is deliberate and is called out in RESULTS.md.
#'
#' Poisson: same latent structure UL = U %*% t(Lambda) (the "same eta"), but
#' the per-trait intercept is solved for directly so that
#' mean_over_units(exp(UL[,j] + b0_pois[j])) hits a per-trait target mean
#' count spanning ~1-12 (log link): b0_pois[j] = log(target_j) -
#' log(mean(exp(UL[,j]))).
simulate_wide_data <- function(family = c("gaussian", "poisson"),
                                n_units = 50L, p_traits = 25L, q_true = 2L,
                                seed) {
  family <- match.arg(family)
  set.seed(seed)

  trait_names <- paste0("t", seq_len(p_traits))
  site_names <- paste0("u", seq_len(n_units))

  Lambda <- matrix(stats::rnorm(p_traits * q_true, sd = 0.7),
                    nrow = p_traits, ncol = q_true)
  U <- matrix(stats::rnorm(n_units * q_true), nrow = n_units, ncol = q_true)
  UL <- U %*% t(Lambda) # n_units x p_traits, shared latent contribution

  if (family == "gaussian") {
    b0 <- stats::rnorm(p_traits, sd = 0.5)
    sigma_j <- stats::rlnorm(p_traits, meanlog = log(0.5), sdlog = 0.3)
    eta <- outer(rep(1, n_units), b0) + UL
    noise <- matrix(stats::rnorm(n_units * p_traits), n_units, p_traits) *
      matrix(sigma_j, n_units, p_traits, byrow = TRUE)
    Y <- eta + noise
  } else {
    target_mean <- seq(1, 12, length.out = p_traits)
    b0 <- log(target_mean) - log(colMeans(exp(UL)))
    eta <- outer(rep(1, n_units), b0) + UL
    mu <- exp(eta)
    Y <- matrix(stats::rpois(n_units * p_traits, mu), n_units, p_traits)
    Y <- matrix(as.double(Y), n_units, p_traits)
  }

  wide <- as.data.frame(Y)
  names(wide) <- trait_names
  wide$site <- factor(site_names, levels = site_names)
  wide <- wide[, c("site", trait_names)]

  list(
    wide = wide, trait_names = trait_names, site_names = site_names,
    Lambda = Lambda, U = U, b0 = b0
  )
}

#' Generate a logical n_units x p_traits mask matrix for one of four
#' mechanisms, retrying with a fresh sub-draw until the per-trait /
#' per-unit observed-cell guards are satisfied.
#'
#' mechanisms:
#'  - "mcar05": 5% of cells, uniform at random.
#'  - "mcar20": 20% of cells, uniform at random.
#'  - "trait_clustered": 10% overall; 60% of that mass concentrated in 5
#'    randomly chosen trait columns, the remaining 40% scattered (MCAR-like)
#'    over the rest of the grid.
#'  - "unit_clustered": 10% overall; 60% of that mass concentrated in a block
#'    of 10 randomly chosen units, the remaining 40% scattered.
#'
#' Guards: every trait keeps >= min_obs_trait observed cells; every unit
#' keeps >= min_obs_unit observed cells.
#'
#' `n_cluster_units` / `n_cluster_traits` size the clustered block for
#' unit_clustered / trait_clustered. Defaults (10 / 5) match the fixed values
#' Arc0 used, so existing Arc0 call sites (and its reproducibility check) are
#' unaffected by this later addition. Arc0b's multinomial arm (p_traits = 1)
#' overrides n_cluster_units so the cluster pool (n_cluster_units * p_traits)
#' can hold the designed cluster count, and overrides min_obs_unit to 0 since
#' a 1-trait grid cannot have "3 observed cells" per unit.
make_mask <- function(mechanism = c("mcar05", "mcar20", "trait_clustered",
                                     "unit_clustered"),
                       n_units, p_traits, seed,
                       min_obs_trait = 5L, min_obs_unit = 3L,
                       max_attempts = 200L,
                       n_cluster_units = 10L, n_cluster_traits = 5L) {
  mechanism <- match.arg(mechanism)
  total <- n_units * p_traits
  target_rate <- switch(
    mechanism,
    mcar05 = 0.05, mcar20 = 0.20,
    trait_clustered = 0.10, unit_clustered = 0.10
  )
  n_mask <- round(target_rate * total)

  for (attempt in seq_len(max_attempts)) {
    ## Deterministic per (seed, attempt); decorrelated from the DGP's own
    ## set.seed(seed) stream (that call already ran and returned by the time
    ## this is invoked).
    set.seed(seed * 97L + attempt)
    mask <- matrix(FALSE, n_units, p_traits)

    if (mechanism %in% c("mcar05", "mcar20")) {
      idx <- sample.int(total, n_mask)
      mask[idx] <- TRUE
    } else if (mechanism == "trait_clustered") {
      n_cluster <- round(0.6 * n_mask)
      n_scatter <- n_mask - n_cluster
      cl_traits <- sample.int(p_traits, n_cluster_traits)
      cluster_pool <- which(as.vector(col(mask)) %in% cl_traits)
      cluster_cells <- sample(cluster_pool, min(n_cluster, length(cluster_pool)))
      remaining_pool <- setdiff(seq_len(total), cluster_cells)
      scatter_cells <- sample(remaining_pool, min(n_scatter, length(remaining_pool)))
      mask[c(cluster_cells, scatter_cells)] <- TRUE
    } else { # unit_clustered
      n_cluster <- round(0.6 * n_mask)
      n_scatter <- n_mask - n_cluster
      cl_units <- sample.int(n_units, n_cluster_units)
      cluster_pool <- which(as.vector(row(mask)) %in% cl_units)
      cluster_cells <- sample(cluster_pool, min(n_cluster, length(cluster_pool)))
      remaining_pool <- setdiff(seq_len(total), cluster_cells)
      scatter_cells <- sample(remaining_pool, min(n_scatter, length(remaining_pool)))
      mask[c(cluster_cells, scatter_cells)] <- TRUE
    }

    obs_per_trait <- n_units - colSums(mask)
    obs_per_unit <- p_traits - rowSums(mask)
    if (all(obs_per_trait >= min_obs_trait) && all(obs_per_unit >= min_obs_unit)) {
      attr(mask, "attempts") <- attempt
      return(mask)
    }
  }
  stop("make_mask: could not satisfy guards after ", max_attempts,
       " attempts for mechanism ", mechanism)
}

#' Apply a logical mask matrix to a wide data frame's trait columns (NA in).
apply_mask <- function(wide, trait_names, mask) {
  wide_masked <- wide
  for (j in seq_along(trait_names)) {
    rows_masked <- which(mask[, j])
    if (length(rows_masked)) wide_masked[[trait_names[j]]][rows_masked] <- NA
  }
  wide_masked
}

#' The designed masked-cell coordinates as (original_row, trait) pairs, for
#' the join-loss assertion and the truth lookup.
mask_cells <- function(mask, trait_names) {
  idx <- which(mask, arr.ind = TRUE)
  data.frame(
    original_row = as.integer(idx[, "row"]),
    trait = trait_names[idx[, "col"]],
    stringsAsFactors = FALSE
  )
}
