#' Profile a temporal persistence or decay parameter
#'
#' Profiles the direct native temporal time parameter with all other TMB
#' parameters re-optimized. This is a fitted-parameter likelihood profile,
#' not a calibrated interval or a profile of conditional temporal states.
#' The helper supports temporal-only unreplicated Gaussian `temporal_indep()`
#' fits and the separately qualified replicated Gaussian AR1
#' `temporal_dep() + spatial_indep()` route. Other combinations and replicated
#' panels need their own lifecycle contracts.
#'
#' @param object An unreplicated Gaussian `temporal_indep()` fit or a qualified
#'   replicated Gaussian AR1 `temporal_dep() + spatial_indep()` fit.
#' @param level Likelihood-ratio confidence level.
#' @param ... Passed to [tmbprofile_wrapper()]. `lincomb` is refused because
#'   this helper only profiles the native temporal time parameter.
#' @return Named numeric vector with `estimate`, `lower`, and `upper`, on the
#'   AR1 persistence or OU decay-rate scale. `NA` bounds mean the profile did
#'   not establish an endpoint.
#' @export
profile_temporal <- function(object, level = 0.95, ...) {
  if (!inherits(object, "gllvmTMB_multi") || !isTRUE(object$temporal$active))
    .temporal_abort("{.fn profile_temporal} requires a native temporal fit.")
  dots <- list(...)
  if ("lincomb" %in% names(dots) && !is.null(dots$lincomb)) {
    .temporal_abort(c(
      "{.fn profile_temporal} profiles temporal persistence or decay only; {.arg lincomb} is not supported.",
      ">" = "Use {.fn tmbprofile_wrapper} directly for a separately specified linear-combination profile."
    ), class = "gllvmTMB_temporal_profile_lincomb")
  }
  active <- .gllvmTMB_predict_unhandled_re_tiers(object, handled = "temporal")
  dep_spatial_pair <- .temporal_is_qualified_dep_spatial_pair(object, active)
  if (length(active) && !dep_spatial_pair) {
    .temporal_abort(c(
      "This helper currently supports the temporal source by itself.",
      "i" = "The fit also uses covariance tier{?s}: {.val {active}}.",
      ">" = "Temporal combinations with phylogenetic, animal, spatial, and dense-kernel sources are deferred."
    ))
  }
  if ((!identical(object$temporal$mode, "indep") && !dep_spatial_pair) ||
      any(object$tmb_data$family_id_vec != 0L)) {
    .temporal_abort("{.fn profile_temporal} currently supports Gaussian {.fn temporal_indep} fits and the qualified temporal-dependent spatial cell only.")
  }
  if (dep_spatial_pair && (!identical(object$temporal$structure, "ar1") ||
      is.null(object$temporal$replicate_col))) {
    .temporal_abort("The qualified temporal-dependent spatial profile requires a replicated AR1 panel.")
  }
  if (!dep_spatial_pair && !is.null(object$temporal$replicate_col)) {
    .temporal_abort("{.fn profile_temporal} currently supports unreplicated panels only.")
  }
  transform <- if (identical(object$temporal$structure, "ar1")) {
    function(x) (1 - 1e-6) * tanh(x)
  } else exp
  tmbprofile_wrapper(object, name = "theta_temporal_time", level = level,
    transform = transform, ...)
}
