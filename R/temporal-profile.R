#' Profile a temporal persistence or decay parameter
#'
#' Profiles the direct native temporal time parameter with all other TMB
#' parameters re-optimized. The qualified replicated AR1 or OU
#' `temporal_indep() + kernel_indep()` route re-optimizes the fixed kernel's
#' variance and every other nuisance parameter at each profile point. This is
#' also available for the qualified replicated AR1
#' `temporal_dep() + phylo_indep()` route, which re-optimizes its full temporal
#' trait covariance and phylogenetic variances at each profile point. This is
#' also available for the qualified replicated rank-one AR1
#' `temporal_latent() + animal_indep()` route. It is a fitted-parameter
#' likelihood profile, not a calibrated interval or a
#' profile of conditional temporal states.
#'
#' @param object An unreplicated Gaussian `temporal_indep()` fit, or the
#'   qualified replicated AR1 or OU `temporal_indep() + kernel_indep()` fit,
#'   or a qualified replicated AR1 `temporal_dep() + phylo_indep()` fit.
#'   The qualified replicated rank-one `temporal_latent() + animal_indep()` fit
#'   is also accepted.
#' @param level Likelihood-ratio confidence level.
#' @param ... Passed to [tmbprofile_wrapper()].
#' @return Named numeric vector with `estimate`, `lower`, and `upper`, on the
#'   AR1 persistence or OU decay-rate scale. `NA` bounds mean the profile did
#'   not establish an endpoint.
#' @export
profile_temporal <- function(object, level = 0.95, ...) {
  if (!inherits(object, "gllvmTMB_multi") || !isTRUE(object$temporal$active))
    .temporal_abort("{.fn profile_temporal} requires a native temporal fit.")
  active <- .gllvmTMB_predict_unhandled_re_tiers(object, handled = "temporal")
  kernel_pair <- .temporal_is_qualified_kernel_pair(object, active)
  dep_phylo_pair <- .temporal_is_qualified_dep_phylo_pair(object, active)
  latent_animal_pair <- .temporal_is_qualified_latent_animal_pair(object, active)
  latent_spatial_pair <- .temporal_is_qualified_latent_spatial_pair(object, active)
  if (length(active) && !kernel_pair && !dep_phylo_pair && !latent_animal_pair && !latent_spatial_pair) {
    .temporal_abort(c(
      "{.fn profile_temporal} supports only qualified temporal-kernel or temporal-dependent phylogenetic source pairs.",
      "i" = "The fit also uses covariance tier(s): {.val {active}}.",
      ">" = "Use the replicated {.code temporal_indep() + kernel_indep()} cell, the AR1 {.code temporal_dep() + phylo_indep()} cell, or a temporal-only fit."
    ), class = "gllvmTMB_temporal_profile_composed")
  }
  if ((!identical(object$temporal$mode, "indep") && !dep_phylo_pair && !latent_animal_pair && !latent_spatial_pair) ||
      any(object$tmb_data$family_id_vec != 0L)) {
    .temporal_abort("{.fn profile_temporal} currently supports Gaussian {.fn temporal_indep} fits, apart from the qualified temporal-dependent phylogenetic cell.")
  }
  if (kernel_pair) {
    if (!object$temporal$structure %in% c("ar1", "ou") || is.null(object$temporal$replicate_col)) {
      .temporal_abort("The qualified temporal-kernel profile requires a replicated AR1 or OU panel.")
    }
  } else if (dep_phylo_pair) {
    if (!identical(object$temporal$structure, "ar1") || is.null(object$temporal$replicate_col)) {
      .temporal_abort("The qualified temporal-dependent phylogenetic profile requires a replicated AR1 panel.")
    }
  } else if (latent_animal_pair) {
    if (!identical(object$temporal$structure, "ar1") || is.null(object$temporal$replicate_col)) {
      .temporal_abort("The qualified rank-one temporal-animal profile requires a replicated AR1 panel.")
    }
  } else if (latent_spatial_pair) {
    if (!identical(object$temporal$structure, "ar1") || is.null(object$temporal$replicate_col)) {
      .temporal_abort("The qualified rank-one temporal-spatial profile requires a replicated AR1 panel.")
    }
  } else if (!is.null(object$temporal$replicate_col)) {
    .temporal_abort("{.fn profile_temporal} currently supports replicated panels only for the qualified AR1 {.code temporal_indep() + kernel_indep()} cell.")
  }
  transform <- if (identical(object$temporal$structure, "ar1")) {
    function(x) (1 - 1e-6) * tanh(x)
  } else exp
  tmbprofile_wrapper(object, name = "theta_temporal_time", level = level,
    transform = transform, ...)
}
