## Standard errors for random-effect blocks that have a point estimate but
## no uncertainty accessor. Generalises the mechanism `getLV(se = TRUE)`
## already uses (R/output-methods.R): every quantity below is read from the
## SAME single TMB `sdreport()` call the fit already carries in
## `fit$sd_report` -- `sqrt(diag.cov.random[idx])` for the block's entries
## in `par.random` -- reshaped with the identical column-major
## `matrix(vec, nrow = <TMB-declared first dim>, ncol = <TMB-declared second
## dim>)` convention TMB itself uses to fill `PARAMETER_MATRIX()` slots
## (`src/gllvmTMB.cpp`). No refit and no extra `sdreport()` call are
## required; this is unlocking numbers TMB already computed at fit time.

#' Standard errors of random-effect blocks without a scores accessor
#'
#' [getLV()] exposes standard errors for the ordinary latent-variable score
#' blocks (`z_B` / `z_W`). Several other random-effect families fitted by
#' [gllvmTMB()] have the identical machinery available -- a marginal
#' variance for every random-effect coordinate, already computed by the
#' fit's TMB `sdreport()` -- but no accessor exposed it. `getREsd()` closes
#' that gap for the blocks whose point-estimate reshape convention is
#' already established elsewhere in the package (see `block` below).
#'
#' @param fit A fitted multivariate model returned by [gllvmTMB()].
#' @param block Which random-effect block to read. One of:
#'   \itemize{
#'     \item `"diag_unit"` -- the unit-level (site) diagonal random effect
#'       from an `indep(0 + trait | <unit>)` / `diag()` term (`s_B` in the
#'       TMB template). Returns an `n_traits x n_sites` matrix, matching the
#'       orientation [predict.gllvmTMB_multi()] already uses when it reads
#'       this block's point estimate.
#'     \item `"diag_unit_obs"` -- the within-unit diagonal random effect
#'       from an `indep(0 + trait | <unit_obs>)` term (`s_W`). Returns an
#'       `n_traits x n_site_species` matrix in the same orientation.
#'     \item `"diag_species"` -- the species-level diagonal random effect
#'       from an `indep(0 + trait | <species>)` term (`q_sp`). Returns an
#'       `n_traits x n_species` matrix.
#'     \item `"phylo"` -- the `propto()` per-species phylogenetic random
#'       effect (`p_phy`). Returns an `n_species x n_traits` matrix, matching
#'       the orientation [predict.gllvmTMB_multi()] already uses when it
#'       reads this block's point estimate.
#'     \item `"re_int"` -- the `(1 | group)` random intercept(s) (`u_re_int`).
#'       Returns a named list, one numeric vector per bar term (named by
#'       that term's grouping-column name), because multiple `(1 | group)`
#'       terms are packed into a single flat parameter vector.
#'     \item `"equalto"` -- the `equalto()` known-covariance random effect
#'       (`e_eq`). Returns a plain numeric vector, one entry per observation
#'       row (the block's native shape; there is no unit/trait grid to
#'       reshape into).
#'   }
#' @return As described per `block` above. Standard errors are always
#'   `NA` (with a warning) when the fit's Hessian is not positive-definite.
#'
#' @section What this is, and is not:
#' Every number returned here is a **Wald / `sdreport()` marginal standard
#' error**, propagated through the delta method the same way [getLV()]'s
#' `se = TRUE` already is -- not a resampled, profiled, or simulation-based
#' quantity. Coverage of intervals built from it has not been measured for
#' these blocks; do not describe or advertise it as exact, and do not
#' construct a CI from it and call the CI "certified" without separately
#' measuring its coverage. `diag.cov.random` reflects fixed-effect-uncertainty
#' -propagated marginal variance for each coordinate individually; it does
#' NOT give cross-block or random-vs-fixed covariance (that needs
#' `sdreport(getJointPrecision = TRUE)`, which this fit's single production
#' `sdreport()` call does not request).
#'
#' Because of that fixed-effect-uncertainty propagation, a near-saturated or
#' otherwise degenerate design (e.g. an `indep()` diagonal term at a grouping
#' where every group has one observation, with its residual variance driven
#' to the boundary) can return SEs one or more orders of magnitude larger
#' than the block's own conditional (GMRF) variance would suggest -- in that
#' regime the random effect deterministically tracks the fixed-effect
#' residual, so its delta-method SE inherits the fixed effect's own
#' uncertainty almost entirely. This is correct Wald behaviour, not a bug,
#' but it means the magnitude is not always "the block's own noise" in an
#' intuitive sense; treat a surprisingly large SE as a cue to check whether
#' the corresponding variance component sits at or near a boundary.
#'
#' Blocks not covered here (`s_B_slope`, `s_W_slope`, `r_c2` / diagonal
#' `cluster2`, `g_phy`, `g_phy_diag`, the SPDE spatial fields
#' `omega_spde*`, the dense-kernel blocks `g_kernel*`, every augmented
#' random-slope block, and the missing-predictor latent blocks `x_mis` /
#' `u_mi_group` / `g_x`) are, in principle, reachable the same way -- the
#' underlying `sdreport()` call already covers their marginal variances too
#' -- but either their point-estimate reshape convention is not yet
#' established anywhere else in the package (so getting the row/column
#' order right cannot be cross-checked against existing code), or their
#' dimensions are not carried as top-level fields on the fit object. Adding
#' them safely needs that groundwork first; this function raises a clear
#' error naming the block rather than silently mis-reshaping.
#'
#' @seealso [getLV()] for the ordinary latent-score standard errors this
#'   function generalises.
#' @keywords internal
#' @export
#' @examples
#' \dontrun{
#' getREsd(fit, block = "re_int")
#' getREsd(fit, block = "diag_unit")
#' }
getREsd <- function(
  fit,
  block = c(
    "diag_unit", "diag_unit_obs", "diag_species",
    "phylo", "re_int", "equalto"
  )
) {
  block <- match.arg(block)
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort(
      "{.arg fit} must be a {.cls gllvmTMB_multi} fit (as returned by {.fn gllvmTMB}).",
      class = "gllvmTMB_getREsd_bad_fit"
    )
  }
  sd_rep <- fit$sd_report
  if (is.null(sd_rep)) {
    cli::cli_abort(c(
      "{.fn getREsd} requires the fit's TMB {.fn sdreport}.",
      "i" = "This fit has no {.field sd_report} ({.code gllvmTMBcontrol(se = FALSE)}, or {.fn sdreport} failed at fitting time).",
      ">" = "Refit with {.code control = gllvmTMBcontrol(se = TRUE)} (the default)."
    ), class = "gllvmTMB_getREsd_no_sdreport")
  }

  spec <- switch(
    block,
    diag_unit = list(
      par_name = "s_B", active = isTRUE(fit$use$diag_B),
      nrow = fit$n_traits, ncol = fit$n_sites,
      absent_msg = "{.fn indep} / {.fn diag} on the unit ({.field {fit$unit_col}}) grouping"
    ),
    diag_unit_obs = list(
      par_name = "s_W", active = isTRUE(fit$use$diag_W),
      nrow = fit$n_traits, ncol = fit$n_site_species,
      absent_msg = "{.fn indep} / {.fn diag} on the within-unit ({.field {fit$unit_obs_col}}) grouping"
    ),
    diag_species = list(
      par_name = "q_sp", active = isTRUE(fit$use$diag_species),
      nrow = fit$n_traits, ncol = fit$n_species,
      absent_msg = "{.fn indep} / {.fn diag} on the species ({.field {fit$species_col}}) grouping"
    ),
    phylo = list(
      par_name = "p_phy", active = isTRUE(fit$use$propto),
      nrow = fit$n_species, ncol = fit$n_traits,
      absent_msg = "{.fn propto}"
    ),
    re_int = list(
      par_name = "u_re_int", active = isTRUE(fit$use$re_int),
      nrow = NULL, ncol = NULL,
      absent_msg = "a {.code (1 | group)} term"
    ),
    equalto = list(
      par_name = "e_eq", active = isTRUE(fit$use$equalto),
      nrow = NULL, ncol = NULL,
      absent_msg = "{.fn equalto}"
    )
  )

  if (!isTRUE(spec$active)) {
    cli::cli_abort(c(
      "This fit has no {.field {block}} random-effect block.",
      "i" = "{.code block = \"{block}\"} reads the {.field {spec$par_name}} TMB parameter, which this fit did not use.",
      ">" = "Refit with {spec$absent_msg} in the formula to get this block."
    ), class = "gllvmTMB_getREsd_block_absent")
  }

  par_names <- names(sd_rep$par.random)
  idx <- which(par_names == spec$par_name)
  if (length(idx) == 0L) {
    cli::cli_abort(c(
      "Could not locate the {.field {spec$par_name}} random-effect block in {.code sd_report$par.random}.",
      "i" = "{.field fit$use${block}} is {.code TRUE} but the parameter is absent from the fit's {.field sd_report}.",
      "i" = "This usually means the fit's {.field sd_report} is stale relative to its {.field tmb_obj}; refit and retry."
    ), class = "gllvmTMB_getREsd_block_missing")
  }

  if (!isTRUE(sd_rep$pdHess)) {
    cli::cli_warn(c(
      "Fit's Hessian is not positive-definite at the optimum.",
      "i" = "Returning {.code NA} standard errors -- Wald inference is unavailable for this fit."
    ))
    se_vec <- rep(NA_real_, length(idx))
  } else {
    ## pmax(., 0) guards against floating-point noise producing a
    ## microscopically negative variance for an entry that is truly ~0
    ## (same guard `.getLV_se()` uses, R/output-methods.R).
    se_vec <- sqrt(pmax(sd_rep$diag.cov.random[idx], 0))
  }

  if (block == "re_int") {
    info <- fit$re_int
    out <- vector("list", length(info$groups))
    names(out) <- info$groups
    for (k in seq_along(info$groups)) {
      rng <- (info$offsets[k] + 1L):(info$offsets[k] + info$n_groups[k])
      out[[k]] <- se_vec[rng]
    }
    return(out)
  }
  if (block == "equalto") {
    return(se_vec)
  }

  if (length(idx) != spec$nrow * spec$ncol) {
    cli::cli_abort(c(
      "Could not reshape the {.field {spec$par_name}} standard errors.",
      "i" = "Expected {spec$nrow * spec$ncol} entries ({spec$nrow} x {spec$ncol}); found {length(idx)}.",
      "i" = "This usually means the fit's {.field sd_report} is stale relative to its {.field tmb_obj}; refit and retry."
    ), class = "gllvmTMB_getREsd_block_mismatch")
  }
  matrix(se_vec, nrow = spec$nrow, ncol = spec$ncol)
}
