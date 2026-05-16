## Phase 1b validation milestone 2026-05-15:
## confint_inspect(fit, parm) -- the visual-verification companion
## to confint(method = "profile"). Returns the full profile curve
## along with the threshold + Wald comparison so users can SEE
## whether a profile is well-behaved (quadratic + symmetric, agrees
## with Wald) or problematic (skewed, kinked, flat at the MLE,
## bound at +/-Inf).
##
## The audit's 2026-05-15 #1 P1 recommendation:
##   "Add confint_inspect(fit, parameter) returning a tidy
##    data.frame (parameter grid, deviance, excess-over-threshold)
##    + a ggplot showing profile shape + MLE + CI bounds for visual
##    verification ('does this profile look quadratic or skewed?')."
##
## Companion to the existing troubleshooting article
## `vignettes/articles/troubleshooting-profile.Rmd` (PR #115, merged).

#' Inspect the profile-likelihood curve for a direct profile target
#'
#' Returns the full profile-likelihood curve, the deviance bounds,
#' and (when `ggplot2` is available) a `ggplot` visualisation showing
#' the curve, the MLE, the chi-squared threshold, and the resulting
#' confidence-interval bounds. This is the visual-verification
#' companion to [confint.gllvmTMB_multi()] with
#' `method = "profile"`: it answers the
#' question "is this profile well-behaved?" before the user
#' interprets the bound.
#'
#' Common failure modes to look for in the returned plot
#' (cross-referenced in the
#' [troubleshooting-profile](https://itchyshin.github.io/gllvmTMB/articles/troubleshooting-profile.html)
#' vignette):
#'
#' * **Quadratic + symmetric near the MLE**: Wald and profile agree.
#'   Either method is fine.
#' * **Asymmetric / skewed**: Wald is wrong; the profile bound is
#'   right.
#' * **Flat at the MLE**: weak identifiability; the profile is right
#'   and the Wald CI hides the flatness.
#' * **Hits the parameter range bound on one side**:
#'   `bounds$lower = -Inf` or `bounds$upper = Inf`. Boundary
#'   parameter (variance pinned at 0) or unidentified upper tail.
#' * **No crossing at all**: `bounds$lower = bounds$upper = NA`. The
#'   profile didn't converge. Switch to bootstrap.
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param parm Character. A single profile-target label from
#'   [profile_targets()]. Examples: `"sigma_eps"`, `"sd_B[1]"`,
#'   `"phi_nbinom2[2]"`, `"b_fix[1]"`. For derived targets
#'   (communality, repeatability, phylogenetic signal, trait
#'   correlations), use the matching `extract_*(method = "profile")`
#'   extractor instead -- those produce their own typed diagnostics.
#' @param level Confidence level. Default `0.95`.
#' @param ystep Profile grid spacing on the deviance scale, passed
#'   to [TMB::tmbprofile()]. Default `0.5`.
#' @param ytol Profile maximum-deviance budget, passed to
#'   [TMB::tmbprofile()]. Default `2`.
#' @param parm.range Two-element numeric range (in the TMB-link
#'   scale) for the profile walk, passed to [TMB::tmbprofile()].
#'   Default `c(-Inf, Inf)`.
#'
#' @return An object of class `gllvmTMB_confint_inspect` with
#'   components:
#'   \describe{
#'     \item{`$curve`}{Data frame with one row per profile-grid
#'       point. Columns: `parm` (user-facing label),
#'       `parm_value_natural` (parameter value on the natural scale
#'       after the registered transformation),
#'       `parm_value_link` (parameter value on the TMB optimisation
#'       scale), `nll` (negative log-likelihood), `deviance_drop`
#'       (`2 * (nll - mle_nll)`, the chi-squared statistic),
#'       `excess_over_threshold` (`deviance_drop - chi2_threshold`;
#'       negative is inside CI, positive is outside),
#'       `in_ci` (logical).}
#'     \item{`$bounds`}{Data frame, 1 row: `parm`,
#'       `estimate_natural`, `lower_natural`, `upper_natural`,
#'       `wald_lower_natural`, `wald_upper_natural`,
#'       `wald_profile_disagree_lower`,
#'       `wald_profile_disagree_upper`. Wald bounds come from
#'       `fit$sd_report$cov.fixed` via the delta method; disagreement
#'       flags are TRUE when the absolute difference exceeds 25% of
#'       the Wald half-width (a heuristic for "look at the plot").}
#'     \item{`$plot`}{A `ggplot` object visualising the curve, MLE,
#'       chi-squared threshold, profile bounds (vertical lines), and
#'       Wald bounds (dashed vertical lines for comparison). `NULL`
#'       if `ggplot2` is not installed.}
#'     \item{`$diagnostics`}{Named character vector flagging any of:
#'       `"quadratic"` (well-behaved), `"asymmetric"` (skewed,
#'       Wald-vs-profile disagrees), `"flat_at_mle"`,
#'       `"hits_lower_bound"`, `"hits_upper_bound"`,
#'       `"no_lower_crossing"`, `"no_upper_crossing"`,
#'       `"profile_failed"`.}
#'     \item{`$call`}{The `match.call()` of the invocation.}
#'   }
#'
#' @seealso [confint.gllvmTMB_multi()] (the corresponding CI
#'   extractor; same `parm` vocabulary), [profile_targets()] (the
#'   target inventory), [tmbprofile_wrapper()] (the lower-level
#'   profile API),
#'   the
#'   [troubleshooting-profile](https://itchyshin.github.io/gllvmTMB/articles/troubleshooting-profile.html)
#'   vignette (the four failure-mode catalogue this function
#'   helps diagnose).
#'
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(value ~ 0 + trait +
#'                 latent(0 + trait | site, d = 1) +
#'                 unique(0 + trait | site),
#'                 data  = sim$data,
#'                 trait = "trait",
#'                 unit  = "site")
#' inspect <- confint_inspect(fit, parm = "sigma_eps")
#' inspect$bounds       # the CI + Wald comparison
#' inspect$diagnostics  # any shape flags
#' inspect$plot         # ggplot of the profile curve
#' }
#'
#' @export
confint_inspect <- function(fit,
                            parm,
                            level     = 0.95,
                            ystep     = 0.5,
                            ytol      = 2,
                            parm.range = c(-Inf, Inf)) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  if (missing(parm) || !is.character(parm) || length(parm) != 1L)
    cli::cli_abort(
      "{.arg parm} must be a single character target label (see {.fn profile_targets})."
    )

  ## ---- Resolve the target via profile_targets() ---------------------
  targets <- profile_targets(fit, ready_only = FALSE)
  row <- targets[targets$parm == parm, , drop = FALSE]
  if (nrow(row) == 0L)
    cli::cli_abort(c(
      "No matching profile target found for {.val {parm}}.",
      "i" = "See {.code profile_targets(fit)} for the full inventory."
    ))
  if (row$target_type == "derived")
    cli::cli_abort(c(
      "{.fn confint_inspect} does not handle derived targets ({.val {parm}}).",
      "i" = "Use the matching {.fn extract_*} extractor with {.code method = \"profile\"} (see {.code profile_targets(fit)} {.field profile_note} column)."
    ))
  if (!row$profile_ready)
    cli::cli_abort(c(
      "Target {.val {parm}} is not profile-ready.",
      "i" = "{.field profile_note}: {.val {row$profile_note}}.",
      ">" = "If the fit object has been serialised, refit before calling {.fn confint_inspect}."
    ))

  transform_fun <- switch(
    row$transformation,
    "linear_predictor"  = identity,
    "exp"               = exp,
    "logit"             = stats::plogis,
    "logit_p_tweedie"   = function(x) 1 + stats::plogis(x),
    "lambda_packed"     = identity,
    "ordinal_threshold" = exp,
    identity
  )

  ## ---- Compute the profile curve via TMB::tmbprofile() ---------------
  idx <- .resolve_param_index(fit, name = row$tmb_parameter,
                              which = if (is.na(row$index)) 1L else row$index)
  mle_nll <- as.numeric(fit$opt$objective)
  crit    <- .qchisq_threshold(level)
  prof <- tryCatch(
    TMB::tmbprofile(
      fit$tmb_obj,
      name       = idx,
      ystep      = ystep,
      ytol       = ytol,
      parm.range = parm.range,
      trace      = FALSE
    ),
    error = function(e) {
      cli::cli_warn(
        "tmbprofile() failed for {.val {parm}}: {conditionMessage(e)}."
      )
      NULL
    }
  )

  if (is.null(prof) || nrow(prof) < 3L) {
    out <- list(
      curve       = data.frame(parm = character(0),
                               parm_value_natural = numeric(0),
                               parm_value_link    = numeric(0),
                               nll                = numeric(0),
                               deviance_drop      = numeric(0),
                               excess_over_threshold = numeric(0),
                               in_ci              = logical(0)),
      bounds      = data.frame(
        parm = parm,
        estimate_natural = transform_fun(as.numeric(fit$opt$par[idx])),
        lower_natural    = NA_real_, upper_natural    = NA_real_,
        wald_lower_natural = NA_real_, wald_upper_natural = NA_real_,
        wald_profile_disagree_lower = NA, wald_profile_disagree_upper = NA
      ),
      plot        = NULL,
      diagnostics = "profile_failed",
      call        = match.call()
    )
    class(out) <- "gllvmTMB_confint_inspect"
    return(out)
  }

  par_link <- prof[[1L]]
  nll      <- prof[[2L]]
  ## Sort by parameter for tidy presentation.
  ord <- order(par_link)
  par_link <- par_link[ord]; nll <- nll[ord]
  par_natural <- vapply(par_link, transform_fun, numeric(1L))
  dev_drop <- 2 * (nll - mle_nll)
  excess <- dev_drop - 2 * crit  # 2 * crit = chi2 threshold (note crit = chi2/2)
  in_ci <- excess <= 0

  curve <- data.frame(
    parm                 = parm,
    parm_value_natural   = par_natural,
    parm_value_link      = par_link,
    nll                  = nll,
    deviance_drop        = dev_drop,
    excess_over_threshold = excess,
    in_ci                = in_ci,
    stringsAsFactors = FALSE
  )

  ## ---- Profile bounds via the existing helper ------------------------
  mle_par_link <- as.numeric(fit$opt$par[idx])
  prof_for_bounds <- data.frame(name = par_link, value = nll)
  bounds_link <- .profile_bounds(
    prof_for_bounds, mle_val = mle_nll,
    mle_par = mle_par_link, crit = crit
  )
  lower_natural <- if (is.na(bounds_link$lower)) NA_real_ else
                   transform_fun(bounds_link$lower)
  upper_natural <- if (is.na(bounds_link$upper)) NA_real_ else
                   transform_fun(bounds_link$upper)

  ## ---- Wald bounds for comparison (delta-method on the link scale) ---
  z <- stats::qnorm(1 - (1 - level) / 2)
  wald_se_link <- tryCatch(
    sqrt(diag(fit$sd_report$cov.fixed))[idx],
    error = function(e) NA_real_
  )
  if (is.na(wald_se_link) || !is.finite(wald_se_link)) {
    wald_lower_natural <- NA_real_
    wald_upper_natural <- NA_real_
  } else {
    wald_lower_natural <- transform_fun(mle_par_link - z * wald_se_link)
    wald_upper_natural <- transform_fun(mle_par_link + z * wald_se_link)
  }

  ## Wald vs profile disagreement (heuristic):
  ## flag when |profile - wald| exceeds 25% of the Wald half-width on
  ## the natural scale. Skip the flag when either bound is NA / Inf.
  est_natural <- transform_fun(mle_par_link)
  wald_halfwidth <- if (!any(is.na(c(wald_lower_natural, wald_upper_natural))))
                      (wald_upper_natural - wald_lower_natural) / 2 else NA_real_
  disagree_flag <- function(prof_bound, wald_bound, hw) {
    if (any(is.na(c(prof_bound, wald_bound, hw)))) return(NA)
    if (!is.finite(prof_bound) || !is.finite(wald_bound)) return(NA)
    abs(prof_bound - wald_bound) > 0.25 * abs(hw)
  }
  bounds <- data.frame(
    parm                       = parm,
    estimate_natural           = est_natural,
    lower_natural              = lower_natural,
    upper_natural              = upper_natural,
    wald_lower_natural         = wald_lower_natural,
    wald_upper_natural         = wald_upper_natural,
    wald_profile_disagree_lower = disagree_flag(lower_natural,
                                               wald_lower_natural,
                                               wald_halfwidth),
    wald_profile_disagree_upper = disagree_flag(upper_natural,
                                               wald_upper_natural,
                                               wald_halfwidth),
    stringsAsFactors = FALSE
  )

  ## ---- Diagnostic flags ----------------------------------------------
  flags <- character(0L)
  if (is.na(lower_natural) && !is.infinite(lower_natural))
    flags <- c(flags, "no_lower_crossing")
  if (is.na(upper_natural) && !is.infinite(upper_natural))
    flags <- c(flags, "no_upper_crossing")
  if (is.infinite(lower_natural))
    flags <- c(flags, "hits_lower_bound")
  if (is.infinite(upper_natural))
    flags <- c(flags, "hits_upper_bound")
  ## Wald-profile disagreement flag:
  if (isTRUE(bounds$wald_profile_disagree_lower) ||
      isTRUE(bounds$wald_profile_disagree_upper))
    flags <- c(flags, "asymmetric")
  ## Flat-at-MLE: the maximum deviance_drop on the curve is < 1
  ## (chi2_1(0.68) ~ 1) -- the curve barely rises. Weak identifiability.
  if (max(dev_drop, na.rm = TRUE) < 1)
    flags <- c(flags, "flat_at_mle")
  ## If no flags fire, the profile is well-behaved.
  if (length(flags) == 0L) flags <- "quadratic"

  ## ---- Build the ggplot (optional) -----------------------------------
  plot_obj <- NULL
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    plot_obj <- .confint_inspect_plot(
      curve, bounds, mle_par_link, mle_par_natural = est_natural,
      crit = crit, level = level
    )
  }

  out <- list(
    curve       = curve,
    bounds      = bounds,
    plot        = plot_obj,
    diagnostics = flags,
    call        = match.call()
  )
  class(out) <- "gllvmTMB_confint_inspect"
  out
}

## ---- Internal: build the ggplot ---------------------------------------

#' @keywords internal
#' @noRd
.confint_inspect_plot <- function(curve, bounds, mle_par_link,
                                  mle_par_natural, crit, level) {
  ## Build the data + annotations on the natural scale (more
  ## interpretable than the TMB log/logit scale). The chi-squared
  ## threshold drawn as a horizontal line at deviance_drop = 2 * crit.
  thresh_dev <- 2 * crit
  parm_label <- unique(curve$parm)

  p <- ggplot2::ggplot(curve, ggplot2::aes_string(
        x = "parm_value_natural", y = "deviance_drop")) +
    ggplot2::geom_line() +
    ggplot2::geom_point(size = 0.8) +
    ggplot2::geom_hline(yintercept = thresh_dev,
                        linetype = "dashed",
                        colour = "darkred") +
    ggplot2::geom_vline(xintercept = mle_par_natural,
                        linetype = "solid",
                        colour = "steelblue") +
    ggplot2::labs(
      x = paste0(parm_label, " (natural scale)"),
      y = expression(2 ~ "[" * italic(nll) * "(" * theta * ") - " *
                     italic(nll) * "(" * hat(theta) * ")]"),
      title = sprintf(
        "Profile likelihood for %s (%g%% CI threshold)",
        parm_label, 100 * level
      )
    ) +
    ggplot2::theme_minimal(base_size = 11)

  ## Profile bounds (solid vertical lines)
  if (!is.na(bounds$lower_natural) && is.finite(bounds$lower_natural))
    p <- p + ggplot2::geom_vline(
      xintercept = bounds$lower_natural,
      linetype = "solid", colour = "darkgreen"
    )
  if (!is.na(bounds$upper_natural) && is.finite(bounds$upper_natural))
    p <- p + ggplot2::geom_vline(
      xintercept = bounds$upper_natural,
      linetype = "solid", colour = "darkgreen"
    )
  ## Wald bounds (dashed vertical lines for comparison)
  if (!is.na(bounds$wald_lower_natural) &&
      is.finite(bounds$wald_lower_natural))
    p <- p + ggplot2::geom_vline(
      xintercept = bounds$wald_lower_natural,
      linetype = "dashed", colour = "orange"
    )
  if (!is.na(bounds$wald_upper_natural) &&
      is.finite(bounds$wald_upper_natural))
    p <- p + ggplot2::geom_vline(
      xintercept = bounds$wald_upper_natural,
      linetype = "dashed", colour = "orange"
    )

  p
}

## ---- print method -----------------------------------------------------

#' @export
print.gllvmTMB_confint_inspect <- function(x, ...) {
  cli::cli_h1("gllvmTMB confint_inspect for {.val {x$bounds$parm}}")
  cli::cli_h2("Estimate + CI")
  print(x$bounds)
  cli::cli_h2("Diagnostics")
  if (identical(x$diagnostics, "quadratic")) {
    cli::cli_alert_success("Profile is well-behaved (quadratic / symmetric).")
  } else {
    cli::cli_alert_warning(
      "Profile shape flags: {.val {x$diagnostics}}. See {.run vignette(\"troubleshooting-profile\", package = \"gllvmTMB\")} for the failure-mode catalogue."
    )
  }
  if (!is.null(x$plot)) {
    cli::cli_inform(
      "The {.field $plot} component is a {.cls ggplot}; call {.code plot(result$plot)} to render."
    )
  }
  invisible(x)
}
