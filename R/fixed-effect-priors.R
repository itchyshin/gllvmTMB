##' Construct explicit link-aware normal fixed-effect priors
##'
##' Builds a coefficient table for already standardized predictors. This helper
##' only constructs independent normal priors; it does not fit a model, rescale
##' data or establish calibrated intervals. The package default remains no prior.
##'
##' @param link Either `"logit"` or `"probit"`.
##' @param intercepts Character vector of exact model-matrix column names for
##'   intercepts, including item intercepts such as `"traita"` in `~ 0 + trait`.
##' @param slopes Character vector of exact model-matrix column names for slopes.
##'   The two groups must be distinct. No coefficient role is inferred from a name.
##' @param standardized Must be explicitly `TRUE`: continuous predictors have
##'   already been centered and scaled to SD 0.5; binary predictors use a declared
##'   zero/one coding. The helper does not inspect or change the data.
##' @param intercept_scale,slope_scale Positive scalar multipliers of the latent
##'   reference SD, separately for intercept and slope coefficients.
##' @param additional_variance Nonnegative scalar variance chosen before fitting.
##'   This is an explicit reference for additional random-effect variation, not
##'   an estimate from the data or a default GLLVM variance.
##' @return A data frame with `coefficient`, zero `mean`, and actual `sd` columns.
##'   Attributes record the link, residual reference variance, additional variance,
##'   multipliers and predictor convention. Inspect `sd` before fitting.
##' @details The returned SD is `scale * sqrt(v + additional_variance)`, where
##'   `v = pi^2 / 3` for logit and `v = 1` for probit. With unit multipliers and
##'   no additional variance these are approximately 1.814 and 1 respectively.
##'   These are latent-variance reference normals, not exact equivalent priors
##'   across links and not a guarantee of a flat prior on outcome probabilities
##'   in a GLLVM. A GLLVM item's additional variance depends on its loadings and
##'   other random effects; it is not automatically one or the latent rank.
##'
##'   This is not the original Gelman scaled Cauchy recommendation (intercept
##'   scale 10, slope scale 2.5), nor the full covariance transformation returned
##'   by `MCMCglmm::gelman.prior()` for the supplied design. That transformation
##'   can induce intercept-slope correlations. Arbitrary independent normal SDs,
##'   including the SD 10 comparison benchmark, can instead be supplied directly
##'   in a coefficient table; SD 10 is not a general recommendation.
##' @references Hadfield, J. MCMCglmm `gelman.prior` documentation and source:
##'   \url{https://github.com/jarrodhadfield/MCMCglmm/blob/master/R/gelman.prior.R}.
##' @examples
##' fixed_effect_priors("logit", intercepts = c("traita", "traitb"),
##'                     slopes = c("traita:x", "traitb:x"),
##'                     standardized = TRUE, intercept_scale = 2,
##'                     slope_scale = 1)
##' @export
fixed_effect_priors <- function(link, intercepts = character(), slopes = character(),
                                standardized = FALSE, intercept_scale = 1,
                                slope_scale = 1, additional_variance = 0) {
  if (!is.character(link) || length(link) != 1L || is.na(link) ||
      !link %in% c("logit", "probit")) {
    cli::cli_abort("{.arg link} must be 'logit' or 'probit'.")
  }
  if (!isTRUE(standardized)) {
    cli::cli_abort("Confirm already standardized predictors with standardized = TRUE; no data rescaling is performed.")
  }
  coefficients <- c(intercepts, slopes)
  if (!is.character(intercepts) || !is.character(slopes) || !length(coefficients) ||
      anyNA(coefficients) || any(!nzchar(coefficients)) || anyDuplicated(coefficients)) {
    cli::cli_abort("{.arg intercepts} and {.arg slopes} must contain distinct, nonempty coefficient names.")
  }
  positive_scalar <- function(x) is.numeric(x) && length(x) == 1L &&
    is.finite(x) && x > 0
  if (!positive_scalar(intercept_scale) || !positive_scalar(slope_scale)) {
    cli::cli_abort("Intercept and slope scales must be finite positive scalars.")
  }
  if (!is.numeric(additional_variance) || length(additional_variance) != 1L ||
      !is.finite(additional_variance) || additional_variance < 0) {
    cli::cli_abort("Additional variance must be a finite nonnegative scalar.")
  }
  residual <- if (link == "logit") pi^2 / 3 else 1
  multiplier <- c(rep(intercept_scale, length(intercepts)),
                  rep(slope_scale, length(slopes)))
  out <- data.frame(coefficient = coefficients, mean = 0,
                    sd = multiplier * sqrt(residual + additional_variance))
  if (any(!is.finite(out$sd))) {
    cli::cli_abort("The chosen scales overflow the generated SD; use smaller finite scales.")
  }
  .gllvmTMB_resolve_fixed_priors(out, coefficients)
  attr(out, "calibration") <- list(
    convention = "latent_variance_reference_normal", link = link,
    residual_variance = residual, additional_variance = additional_variance,
    intercept_scale = intercept_scale, slope_scale = slope_scale,
    continuous_predictor_sd = .5, predictors_rescaled = FALSE
  )
  out
}

## Independent normal densities on named columns of the resolved fixed design.
## Constants are included. Inf explicitly disables a row, including its constant.
.gllvmTMB_fixed_prior_route <- function(priors, engine, estimator, REML, control) {
  if (is.null(priors)) return(invisible(NULL))
  if (!identical(engine, "tmb") || !identical(estimator, "ml") ||
      isTRUE(REML) ||
      !identical(control$integration %||% "laplace", "laplace")) {
    cli::cli_abort(c(
      "{.arg fixed_effect_priors} requires native TMB estimation with REML = FALSE.",
      "i" = "Julia, MSPL and variational integration are unsupported with these priors.",
      ">" = "Use engine = 'tmb', estimator = 'ml', REML = FALSE and integration = 'laplace'."
    ), class = "gllvmTMB_fixed_prior_unsupported")
  }
  invisible(NULL)
}

.gllvmTMB_fixed_prior_inference <- function(object, caller, prior_curvature = FALSE) {
  if (!is.null(object$fixed_effect_priors) && !isTRUE(prior_curvature)) {
    cli::cli_abort(c(
      "{.fn {caller}} is not validated for fixed-effect prior fits.",
      "i" = "Only point predictions and local approximate posterior covariance via vcov() or sd_report are currently supported.",
      ">" = "Inspect the MAP estimates and prior sensitivity; do not interpret inverse penalized curvature as calibrated sampling intervals."
    ), class = "gllvmTMB_fixed_prior_inference_unsupported")
  }
  invisible(NULL)
}

.gllvmTMB_resolve_fixed_priors <- function(priors, coefficient_names) {
  if (is.null(priors)) return(NULL)
  if (!is.data.frame(priors) ||
      !identical(sort(names(priors)), sort(c("coefficient", "mean", "sd")))) {
    cli::cli_abort("{.arg fixed_effect_priors} must be a data.frame with coefficient, mean, and sd columns.")
  }
  if (!is.character(priors$coefficient) || anyNA(priors$coefficient) ||
      anyDuplicated(priors$coefficient) ||
      any(!priors$coefficient %in% coefficient_names)) {
    cli::cli_abort("Each prior coefficient must name one distinct column of the fixed-effects model matrix.")
  }
  if (!is.numeric(priors$mean) || any(!is.finite(priors$mean))) {
    cli::cli_abort("Prior mean values must be finite numbers.")
  }
  if (!is.numeric(priors$sd) || anyNA(priors$sd) || any(priors$sd <= 0)) {
    cli::cli_abort("Prior sd values must be positive numbers; Inf disables a prior.")
  }
  precision <- 1 / priors$sd[is.finite(priors$sd)]^2
  if (any(!is.finite(precision) | precision <= 0)) {
    cli::cli_abort("Finite prior SDs must yield finite positive precision on this machine.")
  }
  priors$index <- match(priors$coefficient, coefficient_names)
  attr(priors, "n_coefficients") <- length(coefficient_names)
  priors
}

.gllvmTMB_fixed_prior_surface <- function(priors, data, family_id, link_id,
                                          Xcoef_fixed, known_V, lambda_constraint,
                                          is_dep_B = FALSE, n_missing_response = 0L) {
  if (is.null(priors) || !any(is.finite(priors$sd))) return(invisible(NULL))
  flags <- c("use_temporal", "use_lv_B", "use_rr_W", "use_diag_W",
    "use_rr_B_slope", "use_diag_B_slope", "use_propto", "use_diag_species",
    "use_diag_cluster2", "use_equalto", "use_spde", "use_spatial_column_slope",
    "use_spde_slope", "use_spde_dep_slope", "use_spde_latent_slope",
    "use_phylo_rr", "use_phylo_diag", "use_phylo_slope", "use_phylo_column_slope",
    "use_phylo_latent_slope", "use_phylo_dep_slope", "n_kernel_tiers",
    "use_re_int", "has_mi", "use_aghq")
  unsupported <- any(vapply(flags, function(nm) any(data[[nm]] %||% 0 != 0), logical(1)))
  pure_family <- all(family_id == 0L) || all(family_id == 1L & link_id %in% c(0L, 1L))
  if (!pure_family || unsupported || isTRUE(is_dep_B) || n_missing_response > 0L ||
      !is.null(Xcoef_fixed) || !is.null(known_V) ||
      any(vapply(lambda_constraint %||% list(), function(x) !is.null(x), logical(1))) ||
      any(data$weights_i != 1) || any(data$is_y_observed == 0L)) {
    cli::cli_abort(c(
      "Fixed-effect priors currently support ordinary unit-tier latent/indep Gaussian or binomial logit/probit models only.",
      ">" = "Use complete observed responses, unit likelihood weights and unconstrained fixed coefficients; omit structured sources, extra grouping tiers and loading constraints."
    ), class = "gllvmTMB_fixed_prior_unsupported")
  }
  invisible(NULL)
}

.gllvmTMB_attach_fixed_priors <- function(obj, priors) {
  active <- if (is.null(priors)) logical() else is.finite(priors$sd)
  if (!any(active)) return(obj)
  if (!is.null(obj$fixed_effect_priors)) {
    cli::cli_abort("This objective already has fixed-effect priors attached.")
  }
  n_coefficients <- attr(priors, "n_coefficients")
  priors <- priors[active, , drop = FALSE]
  beta <- which(names(obj$par) == "b_fix")
  if (!identical(length(beta), n_coefficients) || length(beta) < max(priors$index)) {
    cli::cli_abort("Fixed-effect priors require an unmapped outer b_fix parameter vector.")
  }
  idx <- beta[priors$index]
  mu <- priors$mean
  precision <- 1 / priors$sd^2
  base_fn <- obj$fn
  base_gr <- obj$gr
  base_he <- obj$he
  penalty <- function(p) -sum(stats::dnorm(p[idx], mu, priors$sd, log = TRUE))
  obj$fn <- function(p = obj$par, ...) base_fn(p, ...) + penalty(p)
  obj$gr <- function(p = obj$par, ...) {
    g <- base_gr(p, ...)
    g[idx] <- g[idx] + (p[idx] - mu) * precision
    g
  }
  if (is.function(base_he)) obj$he <- function(p = obj$par, ...) {
    H <- base_he(p, ...)
    H[cbind(idx, idx)] <- H[cbind(idx, idx)] + precision
    H
  }
  obj$fixed_effect_priors <- list(
    specification = priors, indices = idx, penalty = penalty,
    likelihood_fn = base_fn,
    likelihood_gr = base_gr,
    interpretation = "local_approximate_posterior_curvature_at_map",
    calibrated_sampling_covariance = FALSE
  )
  obj
}
