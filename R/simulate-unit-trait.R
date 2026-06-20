#' Simulate a generic stacked-trait GLLVM dataset (units x observations x traits)
#'
#' Simulates a long-format dataset from the generic `(unit, observation,
#' trait)` stacked-trait GLLVM that the package supports. A `unit` is any
#' grouping over which a between-unit covariance structure applies
#' (individual, site, species, paper, ...) and each unit carries
#' `n_obs_per_unit` within-unit observations:
#' \deqn{y_{uot} = \alpha_t + b_{ut} + w_{uot} + e_{uot}}
#' where \eqn{b_{ut}} is the between-unit signal (reduced-rank
#' `Lambda_B` plus diagonal `psi_B`), \eqn{w_{uot}} the within-unit
#' observation-level signal (reduced-rank `Lambda_W` plus diagonal
#' `psi_W`), and \eqn{e_{uot}} a row-level residual.
#'
#' This is the generic sibling of [simulate_site_trait()]. Use this
#' function when the design is an abstract `(unit, observation, trait)`
#' layout with no phylogenetic or spatial structure. Use
#' [simulate_site_trait()] when you need the domain-specific
#' functional-biogeography `(site, species, trait)` cube with
#' phylogenetic species correlation and spatial site coordinates baked
#' into the DGP.
#'
#' Each component can be turned on or off via the corresponding variance /
#' loading argument. The all-`NULL` default settings produce a
#' fixed-effects-only dataset (trait intercepts plus row-level residual)
#' suitable for fast regression fixtures.
#'
#' @param n_units Integer; number of units \eqn{U}.
#' @param n_obs_per_unit Integer; number of within-unit observations \eqn{O}
#'   per unit.
#' @param n_traits Integer; number of traits \eqn{T}.
#' @param alpha Optional length-`n_traits` vector of trait intercepts; random
#'   if `NULL`.
#' @param Lambda_B Optional `n_traits` x `d_B` between-unit loading matrix for
#'   the reduced-rank between-unit component. Set to `NULL` (default) to omit.
#' @param Lambda_W Optional `n_traits` x `d_W` within-unit loading matrix for
#'   the reduced-rank observation-level component (matching a default
#'   `latent()` term, or an explicit compatibility `unique()` term, on the
#'   within-unit grouping). Set to `NULL` (default) to omit.
#' @param psi_B Optional length-`n_traits` vector of trait-specific
#'   between-unit variances. (Lowercase psi matches the factor-analysis
#'   convention -- `\boldsymbol\Psi_B = diag(psi_B)`; see `decisions.md`
#'   2026-05-14 notation reversal.)
#' @param psi_W Optional length-`n_traits` vector of trait-specific
#'   within-unit (observation-level) variances --
#'   `\boldsymbol\Psi_W = diag(psi_W)`.
#' @param sigma2_eps Row-level residual variance. Default 0.5.
#' @param seed Optional RNG seed.
#' @param ... Reserved for future extensions; currently ignored.
#'
#' @return A list with components:
#' \describe{
#'   \item{`data`}{Long-format data frame with one row per (unit,
#'     observation, trait): columns `unit`, `observation`, `trait`, `value`,
#'     and `unit_observation` -- the row id used for a per-observation
#'     diagonal within-unit grouping (one level per unit-observation cell).}
#'   \item{`truth`}{Named list of true parameter values: `alpha`, `Lambda_B`,
#'     `Lambda_W`, `psi_B`, `psi_W`, `sigma2_eps`.}
#' }
#'
#' @seealso [simulate_site_trait()] for the domain-specific
#'   `(site, species, trait)` functional-biogeography simulator with
#'   phylogenetic and spatial machinery.
#'
#' @export
#' @examples
#' set.seed(1)
#' ## Fixed-effects-only default (all structure NULL):
#' sim0 <- simulate_unit_trait(n_units = 20, n_obs_per_unit = 3, n_traits = 4)
#' head(sim0$data)
#' sim0$truth$alpha
#'
#' ## With a between-unit reduced-rank loading and diagonal within-unit term:
#' Lambda_B <- matrix(c(0.9, 0.7, -0.4, 0.2,
#'                      0.1, -0.2, 0.6, 0.8), nrow = 4, ncol = 2)
#' sim <- simulate_unit_trait(n_units = 40, n_obs_per_unit = 3, n_traits = 4,
#'                            Lambda_B = Lambda_B, psi_W = 0.3, seed = 1)
#' str(sim$truth)
simulate_unit_trait <- function(n_units        = 50L,
                                n_obs_per_unit = 3L,
                                n_traits       = 5L,
                                alpha          = NULL,
                                Lambda_B       = NULL,
                                Lambda_W       = NULL,
                                psi_B          = NULL,
                                psi_W          = NULL,
                                sigma2_eps     = 0.5,
                                seed           = NULL,
                                ...) {
  if (!is.null(seed)) set.seed(seed)

  n_units        <- as.integer(n_units)
  n_obs_per_unit <- as.integer(n_obs_per_unit)
  n_traits       <- as.integer(n_traits)

  ## ---- Truth defaults ------------------------------------------------------
  if (is.null(alpha)) alpha <- stats::rnorm(n_traits, mean = 0, sd = 1)
  stopifnot(length(alpha) == n_traits)

  ## ---- Between-unit b_{ut}: reduced-rank Lambda_B + diagonal psi_B ---------
  b_mat <- matrix(0, nrow = n_units, ncol = n_traits)
  if (!is.null(Lambda_B)) {
    stopifnot(nrow(Lambda_B) == n_traits)
    Z_B <- matrix(stats::rnorm(n_units * ncol(Lambda_B)),
                  nrow = n_units, ncol = ncol(Lambda_B))
    b_mat <- b_mat + Z_B %*% t(Lambda_B)
  }
  if (!is.null(psi_B)) {
    psi_B <- rep_len(psi_B, n_traits)
    for (t in seq_len(n_traits))
      b_mat[, t] <- b_mat[, t] + stats::rnorm(n_units, sd = sqrt(psi_B[t]))
  }

  ## ---- Build long-format data ---------------------------------------------
  rows <- list()
  for (u in seq_len(n_units)) {
    for (o in seq_len(n_obs_per_unit)) {
      ## Within-unit observation-level w_{uot}: reduced-rank + diagonal.
      w_uot <- numeric(n_traits)
      if (!is.null(Lambda_W)) {
        stopifnot(nrow(Lambda_W) == n_traits)
        z_W   <- stats::rnorm(ncol(Lambda_W))
        w_uot <- as.numeric(Lambda_W %*% z_W)
      }
      if (!is.null(psi_W)) {
        psi_W <- rep_len(psi_W, n_traits)
        w_uot <- w_uot + stats::rnorm(n_traits, sd = sqrt(psi_W))
      }

      for (t in seq_len(n_traits)) {
        eta <- alpha[t] + b_mat[u, t] + w_uot[t]
        ## Gaussian response only at this stage.
        y <- eta + stats::rnorm(1, sd = sqrt(sigma2_eps))
        rows[[length(rows) + 1L]] <- data.frame(
          unit             = u,
          observation      = o,
          unit_observation = paste(u, o, sep = "_"),
          trait            = paste0("trait_", t),
          value            = y,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  dat <- do.call(rbind, rows)

  dat$unit             <- factor(dat$unit, levels = seq_len(n_units))
  dat$observation      <- factor(dat$observation, levels = seq_len(n_obs_per_unit))
  dat$unit_observation <- factor(dat$unit_observation)
  dat$trait            <- factor(dat$trait, levels = paste0("trait_", seq_len(n_traits)))
  ## Column order: ids first, then trait/value, then the unique() row id.
  dat <- dat[, c("unit", "observation", "trait", "value", "unit_observation")]

  ## psi recycling reflected in truth (matching simulate_site_trait()).
  truth <- list(
    alpha      = alpha,
    Lambda_B   = Lambda_B,
    Lambda_W   = Lambda_W,
    psi_B      = if (is.null(psi_B)) NULL else rep_len(psi_B, n_traits),
    psi_W      = if (is.null(psi_W)) NULL else rep_len(psi_W, n_traits),
    sigma2_eps = sigma2_eps
  )
  list(data  = dat,
       truth = truth)
}
