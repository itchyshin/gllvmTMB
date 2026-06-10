## Per-entry confidence intervals on the reduced-rank loading matrix Λ
## from a confirmatory gllvmTMB() fit. The maths is the delta method on
## a numerical Jacobian J = ∂vec(Λ)/∂theta_rr_packed; the covariance is
## fit$sd_report$cov.fixed restricted to the theta_rr_<level> rows; the
## CI is symmetric Wald.
##
## Why "confirmatory-only" in v1: a per-entry CI on an unconstrained
## exploratory fit is a property of the rotation convention, not the
## biology. See Mansolf & Reise 2016 (doi:10.1080/00273171.2016.1146564
## / PMID 26776711) for the standard psychometric treatment and
## ter Braak & van der Veen 2025 (doi:10.1007/s10651-025-00696-0) for
## the JSDM-side cautionary tale on overstated GLLVM confidence.
##
## Validated machinery already in the repo we reuse:
##  * fit$sd_report (TMB sdreport) — fit$sd_report$cov.fixed gives the
##    covariance of the fixed parameters at convergence.
##  * fit$tmb_obj$report(par) — recomputes the reported quantities
##    (including Lambda_B / Lambda_W) at an arbitrary parameter vector,
##    so the numerical Jacobian is cheap (no refit).
##  * .normalise_level() handles "unit" / "unit_obs" canonical names
##    plus the "B" / "W" legacy aliases.

#' Confidence intervals on individual entries of the loading matrix
#'
#' Return per-entry CIs on the reduced-rank loading matrix
#' `Lambda_<level>` of a confirmatory `gllvmTMB()` fit. Method v1 is the
#' delta-method Wald CI: a numerical Jacobian
#' `J = d vec(Lambda) / d theta_rr` is combined with the TMB
#' `sdreport()` covariance to give
#' `cov(vec(Lambda)) = J %*% cov.fixed %*% t(J)`, from which symmetric
#' Wald intervals are read.
#'
#' Per-entry CIs are **only well-defined for confirmatory fits** — i.e.
#' fits supplied with a `lambda_constraint` that fixes enough entries
#' to pin the rotation. Exploratory fits leave Lambda identified only
#' up to a `d x d` orthogonal rotation, so the SE on any single
#' `Lambda[i, k]` depends on the rotation convention and is not a
#' biological quantity. This function therefore errors on exploratory
#' fits and points the user at [confirmatory_lambda()] /
#' [suggest_lambda_constraint()], or at [extract_communality()] /
#' [extract_Sigma()] for rotation-invariant summaries.
#'
#' @param fit A multivariate `gllvmTMB()` fit object.
#' @param level Which loading matrix to summarise: `"unit"` (default)
#'   or `"unit_obs"`. Legacy aliases `"B"` / `"W"` are accepted with a
#'   one-shot deprecation warning.
#' @param method CI method:
#'   \describe{
#'     \item{`"wald"` (default)}{Symmetric Wald via delta method.}
#'     \item{`"wald_asym"`}{Asymmetric Wald via the Fisher-z transformation
#'       on the standardised loading
#'       \eqn{\rho = \Lambda / \sqrt{\Lambda^2 + \sigma_d^2}}.
#'       Same cost as `"wald"` (no refit) but captures the bounded-support
#'       asymmetry that symmetric Wald on \eqn{\Lambda} ignores. CIs are
#'       wider toward large \eqn{|\Lambda|} and narrower toward 0 — the
#'       qualitatively correct shape, leaving higher-order
#'       log-likelihood-curvature corrections to the profile path.}
#'     \item{`"profile"`}{Profile-likelihood inversion through
#'       [loading_profile()]. This refits across a grid for each free
#'       loading entry and can be used when Wald inference is blocked by a
#'       non-positive-definite Hessian.}
#'   }
#' @param sigma_d2 link-implicit residual variance on the link scale.
#'   Only used when `method = "wald_asym"`. Defaults to `1` (binomial
#'   probit and ordinal_probit; the cleanest non-Gaussian case). For
#'   logit use \eqn{\pi^2/3}; for cloglog use \eqn{\pi^2/6}. Set to the
#'   fitted unique variance for Gaussian. A future version will
#'   auto-detect per-trait from the family.
#' @param conf_level Confidence level. Defaults to 0.95.
#'
#' @return A data frame (one row per Lambda entry) with columns
#'   `trait`, `axis`, `estimate`, `se`, `lower`, `upper`, `method`, and
#'   `pinned` (logical: `TRUE` for entries fixed by `lambda_constraint`,
#'   whose SE is exactly 0 by construction).
#'
#' @seealso [flag_unreliable_loadings()] for a decision-aid summary;
#'   [confirmatory_lambda()] to build a confirmatory constraint matrix;
#'   [extract_communality()] for rotation-invariant alternatives.
#'
#' @examples
#' \dontrun{
#' # Build a confirmatory fit
#' M <- confirmatory_lambda(
#'   species  = species_names,
#'   group    = species_group,
#'   d        = 2L,
#'   loads_on = list(A = 1L, B = 2L)
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 2L),
#'   data              = df_long,
#'   family            = binomial(link = "probit"),
#'   lambda_constraint = list(unit = M)
#' )
#' loading_ci(fit, level = "unit")
#' }
#'
#' @export
loading_ci <- function(fit,
                       level      = c("unit", "unit_obs"),
                       method     = c("wald", "wald_asym", "profile"),
                       conf_level = 0.95,
                       sigma_d2   = 1) {

  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("{.code fit} must be a multi-trait {.fun gllvmTMB} fit.")

  level  <- match.arg(level)
  method <- match.arg(method)

  if (!is.numeric(conf_level) || length(conf_level) != 1L ||
      conf_level <= 0 || conf_level >= 1)
    cli::cli_abort("{.code conf_level} must be a single number in (0, 1).")

  internal_level <- .normalise_level(level, arg_name = "level")
  lam_name <- paste0("Lambda_", internal_level)

  rep_base <- fit$report
  if (is.null(rep_base[[lam_name]]))
    cli::cli_abort(c(
      "Fit has no {.code {lam_name}} to summarise.",
      i = "Refit with a {.fn latent} term at {.code level = {.val {level}}}."
    ))
  Lambda <- as.matrix(rep_base[[lam_name]])

  ## ---- Identifiability gate ----
  M <- fit$lambda_constraint[[internal_level]]
  if (is.null(M) || sum(!is.na(M)) == 0L)
    cli::cli_abort(c(
      "Per-entry Wald CIs on {.code Lambda} are well-defined only for confirmatory fits.",
      i = "This fit has no {.code lambda_constraint} pins at level {.val {level}}; {.code Lambda} is identified only up to rotation.",
      i = "Build a constraint with {.fn confirmatory_lambda} or {.fn suggest_lambda_constraint} and refit.",
      i = "For rotation-invariant alternatives see {.fn extract_communality} with {.code ci = TRUE} or {.fn extract_Sigma}."
    ))

  pd_ok <- isTRUE(fit$sd_report$pdHess)

  ## ---- Trait / axis / estimate / pinned (always available) ----
  n_traits <- nrow(Lambda)
  d        <- ncol(Lambda)
  axis_names  <- colnames(Lambda)
  if (is.null(axis_names))  axis_names  <- paste0("LV", seq_len(d))
  ## Trait names: prefer the engine-provided rownames; fall back to the
  ## lambda_constraint matrix the user supplied (which `confirmatory_lambda()`
  ## fills in); finally to the trait-factor levels in the fit's data.
  trait_names <- rownames(Lambda)
  if (is.null(trait_names))
    trait_names <- rownames(fit$lambda_constraint[[internal_level]])
  if (is.null(trait_names) && !is.null(fit$trait_col) &&
      !is.null(fit$data) && !is.null(fit$data[[fit$trait_col]]))
    trait_names <- levels(fit$data[[fit$trait_col]])
  if (is.null(trait_names))
    trait_names <- paste0("trait_", seq_len(n_traits))

  est    <- as.numeric(Lambda)
  pinned <- as.logical(!is.na(fit$lambda_constraint[[internal_level]]))

  ## ---- Profile path bypasses the pdHess gate (LRT doesn't need the
  ## Hessian; only Wald paths do). Build the curve via loading_profile()
  ## and invert it to CI bounds.
  if (method == "profile") {
    prof <- loading_profile(fit, level = level, n_grid = 11L,
                            grid_extent = 6, conf_level = conf_level)
    bounds <- .invert_profile_loadings(prof)
    ## Build full long-format output (one row per Lambda entry, pinned
    ## included). Bounds for pinned entries collapse to the point.
    out <- data.frame(
      trait      = factor(rep(trait_names, times = d), levels = trait_names),
      axis       = factor(rep(axis_names,  each = n_traits), levels = axis_names),
      estimate   = est,
      se         = NA_real_,
      lower      = est,
      upper      = est,
      method     = "profile",
      pinned     = pinned,
      pd_hessian = pd_ok,
      ci_status  = ifelse(pinned, "pinned", "interval_unavailable"),
      stringsAsFactors = FALSE
    )
    ## Merge profile bounds in by (i, k)
    out$.row_id <- seq_len(nrow(out))
    out_mat_idx <- arrayInd(out$.row_id, c(n_traits, d))
    for (b in seq_len(nrow(bounds))) {
      hit <- which(out_mat_idx[, 1] == bounds$i[b] &
                   out_mat_idx[, 2] == bounds$k[b])
      if (length(hit) == 1L) {
        out$lower[hit]     <- bounds$lower[b]
        out$upper[hit]     <- bounds$upper[b]
        out$ci_status[hit] <- bounds$ci_status[b]
      }
    }
    out$.row_id <- NULL
    return(out)
  }

  ## ---- pd_hessian gate (Wald paths only): refuse to invent Wald
  ## numbers from a non-PD Hessian. Returns estimates + pinned + NA CIs
  ## + status columns so downstream pipelines stay graceful.
  if (!pd_ok) {
    cli::cli_warn(c(
      "Fit's Hessian is not positive-definite at the optimum.",
      i = "Returning estimates only; {.code se} / {.code lower} / {.code upper} are NA -- Wald inference is unavailable for this fit.",
      i = "Consider refitting with a less aggressive {.code lambda_constraint} (e.g. fewer pins) or using {.code loading_ci(method = \"profile\")}."
    ))
    return(data.frame(
      trait      = factor(rep(trait_names, times = d), levels = trait_names),
      axis       = factor(rep(axis_names,  each = n_traits), levels = axis_names),
      estimate   = est,
      se         = NA_real_,
      lower      = NA_real_,
      upper      = NA_real_,
      method     = method,
      pinned     = pinned,
      pd_hessian = FALSE,
      ci_status  = "not_available_non_positive_definite_hessian",
      stringsAsFactors = FALSE
    ))
  }

  ## ---- Delta-method SE on Lambda (shared helper) ----
  se_info <- .lambda_se_at_mle(fit, internal_level)
  se_lambda <- as.numeric(se_info$se_lambda)
  ## Pinned entries: enforce SE = 0 explicitly (delta method already does
  ## this numerically; enforce so floating-point noise doesn't leak in).
  se_lambda[pinned] <- 0

  ## ---- CI bounds: symmetric Wald, or asymmetric via Fisher-z ----
  z <- stats::qnorm(0.5 + conf_level / 2)
  if (method == "wald") {
    lower <- est - z * se_lambda
    upper <- est + z * se_lambda
  } else {  # "wald_asym"
    asym <- .lambda_ci_asym(est = est, se = se_lambda,
                            sigma_d2 = sigma_d2,
                            conf_level = conf_level)
    lower <- asym$lower
    upper <- asym$upper
  }

  data.frame(
    trait      = factor(rep(trait_names, times = d), levels = trait_names),
    axis       = factor(rep(axis_names,  each = n_traits), levels = axis_names),
    estimate   = est,
    se         = se_lambda,
    lower      = lower,
    upper      = upper,
    method     = method,
    pinned     = pinned,
    pd_hessian = TRUE,
    ci_status  = "ok",
    stringsAsFactors = FALSE
  )
}


#' Flag loadings whose CI overlaps a "biologically negligible" region
#'
#' A simple decision aid in the spirit of Zientek & Thompson (2007,
#' doi:10.3758/BF03193163): given per-entry CIs on Lambda, flag the
#' entries whose `conf_level` confidence interval **does not exclude**
#' a user-supplied "null region" — a band around zero considered
#' biologically negligible. Loadings flagged as `unreliable = TRUE`
#' are the ones for which the data do not provide evidence that the
#' species responds non-trivially to the axis.
#'
#' Pinned entries (set explicitly by `lambda_constraint`) are reported
#' with `unreliable = NA` because no inference is being made about them.
#'
#' @param fit A multivariate `gllvmTMB()` fit, or a data frame already
#'   produced by [loading_ci()].
#' @param null_region Length-2 numeric, sorted ascending. The
#'   "negligible" band. Defaults to `c(-0.1, 0.1)`.
#' @param level,method,conf_level Forwarded to [loading_ci()] when
#'   `fit` is a fit object. Ignored when `fit` is already a
#'   `loading_ci()` data frame.
#'
#' @return The `loading_ci()` data frame with one extra logical column
#'   `unreliable`: `TRUE` if the CI overlaps `null_region`, `FALSE` if
#'   it lies entirely outside, `NA` for pinned entries.
#'
#' @seealso [loading_ci()].
#'
#' @export
flag_unreliable_loadings <- function(fit,
                                     null_region = c(-0.1, 0.1),
                                     level       = c("unit", "unit_obs"),
                                     method      = "wald",
                                     conf_level  = 0.95) {

  if (!is.numeric(null_region) || length(null_region) != 2L ||
      anyNA(null_region) || null_region[1] >= null_region[2])
    cli::cli_abort(
      "{.code null_region} must be a length-2 numeric vector with {.code null_region[1] < null_region[2]}."
    )

  if (is.data.frame(fit)) {
    needed <- c("estimate", "lower", "upper", "pinned")
    if (!all(needed %in% names(fit)))
      cli::cli_abort(
        "Data-frame input must have columns {.code {needed}} (output of {.fn loading_ci})."
      )
    df <- fit
  } else {
    df <- loading_ci(fit, level = level, method = method, conf_level = conf_level)
  }

  ## A CI [lo, hi] overlaps the null region [a, b] iff hi >= a and lo <= b.
  overlaps <- (df$upper >= null_region[1]) & (df$lower <= null_region[2])
  df$unreliable <- overlaps
  df$unreliable[df$pinned] <- NA      # pinned entries: no inference made
  df$null_region_lo <- null_region[1]
  df$null_region_hi <- null_region[2]
  df
}
