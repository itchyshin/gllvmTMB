#' Simulate a stacked-trait, site-by-species GLLVM dataset
#'
#' Simulates data from the Nakagawa et al. (in prep) functional-biogeography
#' model:
#' \deqn{y_{sit} = \alpha_t + x_s'\beta_t + r_{st} + u_{st} + e_{sit} + p_{it} + q_{it}}
#'
#' Each component can be turned on or off via the corresponding variance /
#' loading argument. The default settings produce a fixed-effects-only dataset
#' suitable for Stage-1 regression tests.
#'
#' @param n_sites Integer; number of sites \eqn{S}.
#' @param n_species Integer; number of species \eqn{I} in the regional pool.
#' @param n_traits Integer; number of traits \eqn{T}.
#' @param mean_species_per_site Average number of species observed per site
#'   (Poisson with this mean, truncated at \eqn{n_{species}}). Default 5.
#' @param n_predictors Integer; number of site-level predictors. Default 2.
#' @param alpha Optional length-`n_traits` vector of trait intercepts; random
#'   if `NULL`.
#' @param beta Optional `n_traits` x `n_predictors` matrix of trait-specific
#'   slopes; random if `NULL`.
#' @param sigma2_eps Residual variance (`s_W` only term in fixed-effects-only
#'   simulator). Default 0.5.
#' @param Lambda_B,Lambda_W Optional `n_traits` x `d_B` / `n_traits` x `d_W`
#'   loading matrices for between-site / within-site reduced-rank components.
#'   Set to `NULL` (default) to omit.
#' @param S_B,S_W Optional length-`n_traits` vectors of trait-specific specific
#'   variances at the global / local level.
#' @param sigma2_phy,sigma2_sp Optional length-`n_traits` vectors of
#'   phylogenetic and non-phylogenetic species variance. `Cphy` is required
#'   if `sigma2_phy` is supplied.
#' @param Cphy Optional `n_species` x `n_species` phylogenetic correlation
#'   matrix. If supplied, used to draw `p_it`.
#' @param spatial_range,sigma2_spa Optional spatial range and per-trait
#'   variance for an exponential spatial residual `r_st`. If both supplied
#'   and `coords` is `NULL`, sites are placed uniformly in `[0, 1]^2`.
#' @param coords Optional `n_sites` x 2 matrix of site coordinates (used when
#'   `spatial_range` is supplied).
#' @param seed Optional RNG seed.
#'
#' @return A list with components:
#' \describe{
#'   \item{`data`}{Long-format data frame with one row per (site, species,
#'     trait) observation: columns `site`, `species`, `trait`, `value`,
#'     `site_species`, predictors `env_1`, …, `env_n_predictors`, plus `lon`
#'     and `lat` if coords were generated.}
#'   \item{`truth`}{Named list of true parameter values (alpha, beta,
#'     Lambda_B, Lambda_W, S_B, S_W, sigma2_phy, sigma2_sp, sigma2_spa,
#'     spatial_range, sigma2_eps).}
#'   \item{`Cphy`}{The phylogenetic correlation matrix used (or `NULL`).}
#'   \item{`coords`}{Site coordinates used (or `NULL`).}
#' }
#'
#' @export
#' @examples
#' set.seed(1)
#' sim <- simulate_site_trait(n_sites = 30, n_species = 8, n_traits = 3,
#'                            mean_species_per_site = 4)
#' head(sim$data)
#' sim$truth$alpha
simulate_site_trait <- function(n_sites = 50,
                                n_species = 20,
                                n_traits = 3,
                                mean_species_per_site = 5,
                                n_predictors = 2,
                                alpha = NULL,
                                beta = NULL,
                                sigma2_eps = 0.5,
                                Lambda_B = NULL,
                                Lambda_W = NULL,
                                S_B = NULL,
                                S_W = NULL,
                                sigma2_phy = NULL,
                                sigma2_sp = NULL,
                                Cphy = NULL,
                                spatial_range = NULL,
                                sigma2_spa = NULL,
                                coords = NULL,
                                seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  ## ---- Truth defaults ------------------------------------------------------
  if (is.null(alpha)) alpha <- stats::rnorm(n_traits, mean = 0, sd = 1)
  if (is.null(beta))  beta  <- matrix(stats::rnorm(n_traits * n_predictors, sd = 0.5),
                                      nrow = n_traits, ncol = n_predictors)
  stopifnot(length(alpha) == n_traits,
            nrow(beta) == n_traits, ncol(beta) == n_predictors)

  ## ---- Site-level predictors ----------------------------------------------
  X <- matrix(stats::rnorm(n_sites * n_predictors), nrow = n_sites, ncol = n_predictors,
              dimnames = list(NULL, paste0("env_", seq_len(n_predictors))))

  ## ---- Spatial r_{st} (optional) ------------------------------------------
  r_mat <- matrix(0, nrow = n_sites, ncol = n_traits)
  if (!is.null(spatial_range) && !is.null(sigma2_spa)) {
    if (is.null(coords)) coords <- cbind(lon = stats::runif(n_sites),
                                         lat = stats::runif(n_sites))
    D <- as.matrix(stats::dist(coords))
    K <- exp(-D / spatial_range)
    sigma2_spa <- rep_len(sigma2_spa, n_traits)
    for (t in seq_len(n_traits)) {
      L <- chol(sigma2_spa[t] * K + 1e-8 * diag(n_sites))
      r_mat[, t] <- as.numeric(t(L) %*% stats::rnorm(n_sites))
    }
  }

  ## ---- Reduced-rank between-site u_{st} -----------------------------------
  u_mat <- matrix(0, nrow = n_sites, ncol = n_traits)
  if (!is.null(Lambda_B)) {
    stopifnot(nrow(Lambda_B) == n_traits)
    Z_B <- matrix(stats::rnorm(n_sites * ncol(Lambda_B)),
                  nrow = n_sites, ncol = ncol(Lambda_B))
    u_mat <- u_mat + Z_B %*% t(Lambda_B)
  }
  if (!is.null(S_B)) {
    S_B <- rep_len(S_B, n_traits)
    for (t in seq_len(n_traits))
      u_mat[, t] <- u_mat[, t] + stats::rnorm(n_sites, sd = sqrt(S_B[t]))
  }

  ## ---- Species-level p_{it} (phylo) and q_{it} (non-phylo) ----------------
  p_mat <- matrix(0, nrow = n_species, ncol = n_traits)
  q_mat <- matrix(0, nrow = n_species, ncol = n_traits)
  if (!is.null(Cphy)) {
    stopifnot(nrow(Cphy) == n_species, ncol(Cphy) == n_species)
    sigma2_phy <- if (is.null(sigma2_phy)) rep(1, n_traits) else rep_len(sigma2_phy, n_traits)
    Lphy <- chol(Cphy + 1e-8 * diag(n_species))
    for (t in seq_len(n_traits)) {
      p_mat[, t] <- sqrt(sigma2_phy[t]) * as.numeric(t(Lphy) %*% stats::rnorm(n_species))
    }
  }
  if (!is.null(sigma2_sp)) {
    sigma2_sp <- rep_len(sigma2_sp, n_traits)
    for (t in seq_len(n_traits))
      q_mat[, t] <- stats::rnorm(n_species, sd = sqrt(sigma2_sp[t]))
  }

  ## ---- Pick which species occur at which sites ----------------------------
  occur <- vector("list", n_sites)
  for (s in seq_len(n_sites)) {
    n_obs <- max(1L, min(n_species,
                         stats::rpois(1, mean_species_per_site)))
    occur[[s]] <- sort(sample.int(n_species, n_obs, replace = FALSE))
  }

  ## ---- Build long-format data --------------------------------------------
  rows <- list()
  for (s in seq_len(n_sites)) {
    for (i in occur[[s]]) {
      ## Within-site reduced-rank e_{sit}
      e_sit <- numeric(n_traits)
      if (!is.null(Lambda_W)) {
        stopifnot(nrow(Lambda_W) == n_traits)
        z_W <- stats::rnorm(ncol(Lambda_W))
        e_sit <- as.numeric(Lambda_W %*% z_W)
      }
      if (!is.null(S_W)) {
        S_W <- rep_len(S_W, n_traits)
        e_sit <- e_sit + stats::rnorm(n_traits, sd = sqrt(S_W))
      }

      for (t in seq_len(n_traits)) {
        eta_st <- alpha[t] + sum(X[s, ] * beta[t, ])
        eta <- eta_st + r_mat[s, t] + u_mat[s, t] + e_sit[t] +
          p_mat[i, t] + q_mat[i, t]
        ## Gaussian response only at this stage; non-Gaussian comes later
        y <- eta + stats::rnorm(1, sd = sqrt(sigma2_eps))
        rows[[length(rows) + 1L]] <- data.frame(
          site         = s,
          species      = i,
          site_species = paste(s, i, sep = "_"),
          trait        = paste0("trait_", t),
          value        = y,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  dat <- do.call(rbind, rows)
  ## Attach site predictors and (if used) coords
  for (k in seq_len(n_predictors)) dat[[paste0("env_", k)]] <- X[dat$site, k]
  if (!is.null(coords)) {
    dat$lon <- coords[dat$site, 1]
    dat$lat <- coords[dat$site, 2]
  }
  dat$site         <- factor(dat$site, levels = seq_len(n_sites))
  dat$species      <- factor(dat$species, levels = seq_len(n_species))
  dat$site_species <- factor(dat$site_species)
  dat$trait        <- factor(dat$trait, levels = paste0("trait_", seq_len(n_traits)))

  truth <- list(
    alpha          = alpha,
    beta           = beta,
    sigma2_eps     = sigma2_eps,
    Lambda_B       = Lambda_B,
    Lambda_W       = Lambda_W,
    S_B            = S_B,
    S_W            = S_W,
    sigma2_phy     = sigma2_phy,
    sigma2_sp      = sigma2_sp,
    sigma2_spa     = sigma2_spa,
    spatial_range  = spatial_range
  )
  list(data   = dat,
       truth  = truth,
       Cphy   = Cphy,
       coords = coords)
}
