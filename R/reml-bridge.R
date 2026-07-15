## ML-vs-REML variance-component bridge diagnostic (Design 80 "Bridge
## diagnostic (cheap, ship in the RE arc)", docs/design/80-nongaussian-re-
## evidence-bars.md sec. "Bridge diagnostic"). Gaussian-only, opt-in: this
## triggers exactly ONE extra refit of the supplied model with the opposite
## REML flag and compares fitted random-effect standard deviations. It is
## deliberately NOT called from check_gllvmTMB()'s default path -- the user
## must compute it and hand it (or attach it to the fit) explicitly.

## Collect the reported random-effect standard-deviation components of a
## fitted gllvmTMB model, named so the ML and REML companion fits can be
## matched up by name. Two sources:
##   (1) bare `(1 | group)` random-intercept terms (R/re-int.R): one sigma
##       per term, from `fit$report$log_sigma_re_int`, labelled by the
##       term's group column (`fit$re_int$groups`).
##   (2) the keyword-grid between/within-unit standard deviations reported
##       by the indep()/latent()/dep() engine tiers -- the same candidate
##       report names `.gllvmTMB_boundary_flags()` (R/diagnose.R) scans.
.gllvmTMB_reml_bridge_components <- function(fit) {
  comps <- list()

  log_sigma_re_int <- fit$report$log_sigma_re_int
  if (!is.null(log_sigma_re_int) && length(log_sigma_re_int) > 0L) {
    sigma <- exp(as.numeric(log_sigma_re_int))
    labs <- fit$re_int$groups
    labs <- if (is.null(labs) || length(labs) != length(sigma)) {
      paste0("re_int", seq_along(sigma))
    } else {
      paste0("re_int(", labs, ")")
    }
    for (i in seq_along(sigma)) comps[[labs[i]]] <- sigma[i]
  }

  for (nm in c("sd_B", "sd_W", "sd_phy", "sd_phy_diag", "sd_spde",
               "sd_b", "sd_spde_b")) {
    val <- fit$report[[nm]]
    if (is.null(val)) next
    val <- as.numeric(val)
    val <- val[is.finite(val)]
    if (length(val) == 0L) next
    if (length(val) == 1L) {
      comps[[nm]] <- val
    } else {
      for (i in seq_along(val)) comps[[paste0(nm, "[", i, "]")]] <- val[i]
    }
  }

  comps
}

#' ML-vs-REML variance-component bridge diagnostic
#'
#' Design 80's "bridge diagnostic": refits a Gaussian [gllvmTMB()] fit with
#' the opposite `REML` flag and compares each reported random-effect
#' standard deviation between the ML and REML companion fits. Maximum
#' likelihood variance components are known to be downward-biased at small
#' cluster counts; a large ML-vs-REML relative gap flags that regime --
#' "turning 'we know it's biased' into an automatic warning" (Design 80
#' sec. "Bridge diagnostic (cheap, ship in the RE arc)").
#'
#' `reml_bridge()` is an explicit opt-in diagnostic: it triggers exactly
#' one extra refit of `object` (with the opposite `REML` value) and is
#' deliberately not run inside [check_gllvmTMB()]'s default path, because a
#' refit is expensive. Pass the result to
#' `check_gllvmTMB(object, reml_bridge = ...)`, or attach it as
#' `object$reml_bridge` before calling `check_gllvmTMB(object)`, to surface
#' the flag on the fit-health table.
#'
#' REML likelihoods are not comparable across fixed-effect structures;
#' this diagnostic only ever compares a model against itself under the two
#' estimators; it is not an LRT and says nothing about fixed-effect
#' structure choice.
#'
#' @param object A fit returned by [gllvmTMB()]. Must be Gaussian for every
#'   response row -- REML is only implemented for Gaussian-only fits (see
#'   the `REML` argument of [gllvmTMB()]).
#' @param rel_thresh Relative-gap threshold, `abs(reml - ml) / abs(reml)`,
#'   above which a component's `flag` is `TRUE`. Default `0.10` (10%); a
#'   heuristic screening value, not a calibrated small-cluster-regime
#'   cutoff.
#' @return A data frame with one row per comparable random-effect standard
#'   deviation component: `component` (name), `ml`, `reml` (fitted
#'   standard deviations under each estimator), `gap_abs`
#'   (`abs(reml - ml)`), `gap_rel` (`gap_abs / abs(reml)`), `threshold`
#'   (`rel_thresh`), and `flag` (`gap_rel > rel_thresh`).
#' @seealso [check_gllvmTMB()] for the fit-health surface this feeds.
#' @export
#' @examples
#' \dontrun{
#' df <- data.frame(
#'   study = factor(rep(1:8, each = 8)),
#'   trait = factor(rep(c("t1", "t2"), length.out = 64)),
#'   value = rnorm(64)
#' )
#' fit <- gllvmTMB(value ~ 0 + trait + (1 | study), data = df, unit = "study")
#' bridge <- reml_bridge(fit)
#' bridge
#' check_gllvmTMB(fit, reml_bridge = bridge)
#' }
reml_bridge <- function(object, rel_thresh = 0.10) {
  if (!inherits(object, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  fids <- object$tmb_data$family_id_vec
  if (is.null(fids) || !all(fids == 0L)) {
    cli::cli_abort(c(
      "{.fn reml_bridge} is Gaussian-only.",
      "x" = "At least one response row uses a non-Gaussian family.",
      "i" = "REML is currently implemented for Gaussian-only {.fn gllvmTMB} fits (see {.arg REML} in {.fn gllvmTMB})."
    ))
  }
  if (!is.numeric(rel_thresh) || length(rel_thresh) != 1L ||
        is.na(rel_thresh) || rel_thresh <= 0) {
    cli::cli_abort("{.arg rel_thresh} must be a single positive number.")
  }

  formula <- .reconstruct_multi_formula(object)
  call_args <- list(
    formula = formula,
    data    = object$data,
    trait   = object$trait_col,
    unit    = object$unit_col,
    cluster = object$cluster_col %||% object$species_col,
    family  = object$family_input %||% object$family,
    silent  = TRUE
  )
  aux <- list(
    cluster2          = object$cluster2_col,
    phylo_vcv         = object$phylo_vcv,
    phylo_tree        = object$phylo_tree,
    mesh              = object$mesh,
    lambda_constraint = object$lambda_constraint
  )
  aux <- aux[!vapply(aux, is.null, logical(1))]
  call_args <- c(call_args, aux)

  refit_with <- function(reml) {
    tryCatch(
      suppressMessages(suppressWarnings(
        do.call(gllvmTMB, c(call_args, list(REML = reml)))
      )),
      error = function(e) e
    )
  }

  if (isTRUE(object$REML)) {
    fit_reml <- object
    fit_ml   <- refit_with(FALSE)
    if (inherits(fit_ml, "error")) {
      cli::cli_abort(c(
        "The companion ML refit failed.",
        "x" = conditionMessage(fit_ml)
      ))
    }
  } else {
    fit_ml   <- object
    fit_reml <- refit_with(TRUE)
    if (inherits(fit_reml, "error")) {
      cli::cli_abort(c(
        "The companion REML refit failed.",
        "x" = conditionMessage(fit_reml),
        "i" = "REML is restricted to Gaussian, unweighted, full-rank, no-mi(), no-missing-response fits (see the {.arg REML} guard in {.fn gllvmTMB})."
      ))
    }
  }

  comp_ml   <- .gllvmTMB_reml_bridge_components(fit_ml)
  comp_reml <- .gllvmTMB_reml_bridge_components(fit_reml)
  common <- intersect(names(comp_ml), names(comp_reml))
  if (length(common) == 0L) {
    cli::cli_abort(
      "No comparable random-effect standard-deviation component found on this fit (no {.code (1 | group)}, {.field sd_B}, {.field sd_W}, ... report field)."
    )
  }

  ml_vals   <- vapply(common, function(nm) comp_ml[[nm]], numeric(1))
  reml_vals <- vapply(common, function(nm) comp_reml[[nm]], numeric(1))
  gap_abs <- abs(reml_vals - ml_vals)
  gap_rel <- gap_abs / pmax(abs(reml_vals), 1e-8)

  data.frame(
    component = common,
    ml        = unname(ml_vals),
    reml      = unname(reml_vals),
    gap_abs   = unname(gap_abs),
    gap_rel   = unname(gap_rel),
    threshold = rel_thresh,
    flag      = is.finite(gap_rel) & gap_rel > rel_thresh,
    stringsAsFactors = FALSE
  )
}
