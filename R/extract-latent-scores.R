#' Extract latent random-effect scores
#'
#' Returns unit-tier (or within-unit) latent random-effect scores as an
#' `n \times K` matrix. For a fitted object this is the posterior mode of the
#' `z_B` / `z_W` innovation block in native `rotate = "none"` orientation.
#' For output from [simulate_site_trait()], returns the generating draws stored
#' in `truth$z_B` / `truth$z_W`.
#'
#' Point estimates match [extract_ordination()] with
#' `component = "innovation"`, [getLV()] at `rotate = "none"`, and
#' [ordination_uncertainty()] `$scores` when that function succeeds.
#' Score uncertainty (`se`, `cov`) remains [ordination_uncertainty()] /
#' [getLV()] with `se = TRUE`.
#'
#' @param x A fitted `gllvmTMB_multi` / `gllvmTMB_va` / `gllvmTMB_julia`
#'   object, or a `gllvmTMB_site_trait_sim` object from
#'   [simulate_site_trait()].
#' @param level `"unit"` (between-unit, `z_B`) or `"unit_obs"` (within-unit,
#'   `z_W`). Deprecated aliases `"B"` and `"W"` are accepted with a warning.
#' @return An `n \times K` numeric matrix with unit row names and `"LV1"`,
#'   `"LV2"`, … column names; `NULL` when no reduced-rank term exists at the
#'   requested level.
#' @seealso [extract_ordination()], [ordination_uncertainty()], [getLV()],
#'   [simulate_site_trait()]
#' @export
#'
#' @examples
#' \dontrun{
#' sim <- simulate_site_trait(
#'   n_sites = 20, n_species = 6, n_traits = 4,
#'   mean_species_per_site = 4,
#'   Lambda_B = matrix(c(0.9, 0.6, -0.4, 0.5), nrow = 4, ncol = 1),
#'   seed = 1
#' )
#' u_true <- extract_latent_scores(sim, level = "unit")
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 1),
#'   data = sim$data
#' )
#' z_hat <- extract_latent_scores(fit, level = "unit")
#' }
extract_latent_scores <- function(x, level = c("unit", "unit_obs")) {
  UseMethod("extract_latent_scores")
}

#' @export
extract_latent_scores.gllvmTMB_multi <- function(x, level = c("unit", "unit_obs")) {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  ord <- extract_ordination(x, level = level, component = "innovation")
  if (is.null(ord)) {
    return(NULL)
  }
  ord$scores
}

#' @export
extract_latent_scores.gllvmTMB_va <- function(x, level = c("unit", "unit_obs")) {
  extract_latent_scores.gllvmTMB_multi(x, level = level)
}

#' @export
extract_latent_scores.gllvmTMB_site_trait_sim <- function(x, level = c("unit", "unit_obs")) {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  z <- if (level == "B") x$truth$z_B else x$truth$z_W
  if (is.null(z)) {
    return(NULL)
  }
  z
}

#' @export
extract_latent_scores.default <- function(x, level = c("unit", "unit_obs")) {
  cli::cli_abort(c(
    "No method for {.fn extract_latent_scores} for objects of class {.cls {class(x)[1]}}.",
    "i" = paste0(
      "Expected a fitted {.cls gllvmTMB_multi} object or a ",
      "{.cls gllvmTMB_site_trait_sim} from {.fn simulate_site_trait}."
    )
  ))
}
