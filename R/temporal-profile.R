#' Profile a temporal persistence or decay parameter
#'
#' Profiles the direct native temporal time parameter with all other TMB
#' parameters re-optimized. This is a fitted-parameter likelihood profile,
#' not a calibrated interval or a profile of conditional temporal states.
#' The current helper supports temporal-only unreplicated Gaussian
#' `temporal_indep()` fits. Temporal combinations and replicated panels need
#' their own lifecycle contracts.
#'
#' @param object An unreplicated Gaussian `temporal_indep()` fit.
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
  if (length(active)) {
    .temporal_abort(c(
      "This helper currently supports the temporal source by itself.",
      "i" = "The fit also uses covariance tier{?s}: {.val {active}}.",
      ">" = "Temporal combinations with phylogenetic, animal, spatial, and dense-kernel sources are deferred."
    ))
  }
  kernel_pair <- .temporal_is_qualified_kernel_pair(object, active)
  dep_phylo_pair <- .temporal_is_qualified_dep_phylo_pair(object, active)
  dep_animal_pair <- .temporal_is_qualified_dep_animal_pair(object, active)
  latent_animal_pair <- .temporal_is_qualified_latent_animal_pair(object, active)
  latent_spatial_pair <- .temporal_is_qualified_latent_spatial_pair(object, active)
  dep_spatial_pair <- .temporal_is_qualified_dep_spatial_pair(object, active)
  if (length(active) && !kernel_pair && !dep_phylo_pair && !dep_animal_pair && !latent_animal_pair && !latent_spatial_pair && !dep_spatial_pair) {
    .temporal_abort(c(
      "{.fn profile_temporal} supports only qualified temporal-kernel, temporal-dependent phylogenetic, animal, or spatial, rank-one temporal-animal, or rank-one temporal-spatial source pairs.",
      "i" = "The fit also uses covariance tier(s): {.val {active}}.",
      ">" = "Use the replicated {.code temporal_indep() + kernel_indep()} cell, an AR1 {.code temporal_dep()} cell with a fixed phylogeny or animal relationship, a qualified rank-one {.code temporal_latent()} source pair, or a temporal-only fit."
    ), class = "gllvmTMB_temporal_profile_composed")
  }
  if ((!identical(object$temporal$mode, "indep") && !dep_phylo_pair && !dep_animal_pair && !latent_animal_pair && !latent_spatial_pair && !dep_spatial_pair) ||
      any(object$tmb_data$family_id_vec != 0L)) {
    .temporal_abort("{.fn profile_temporal} currently supports Gaussian {.fn temporal_indep} fits, apart from qualified temporal-dependent phylogenetic, animal, or spatial and rank-one temporal-animal or temporal-spatial cells.")
  }
  if (kernel_pair) {
    if (!object$temporal$structure %in% c("ar1", "ou") || is.null(object$temporal$replicate_col)) {
      .temporal_abort("The qualified temporal-kernel profile requires a replicated AR1 or OU panel.")
    }
  } else if (dep_phylo_pair) {
    if (!identical(object$temporal$structure, "ar1") || is.null(object$temporal$replicate_col)) {
      .temporal_abort("The qualified temporal-dependent phylogenetic profile requires a replicated AR1 panel.")
    }
  } else if (dep_animal_pair) {
    if (!identical(object$temporal$structure, "ar1") || is.null(object$temporal$replicate_col)) {
      .temporal_abort("The qualified temporal-dependent animal profile requires a replicated AR1 panel.")
    }
  } else if (latent_animal_pair) {
    if (!identical(object$temporal$structure, "ar1") || is.null(object$temporal$replicate_col)) {
      .temporal_abort("The qualified rank-one temporal-animal profile requires a replicated AR1 panel.")
    }
  } else if (latent_spatial_pair) {
    if (!identical(object$temporal$structure, "ar1") || is.null(object$temporal$replicate_col)) {
      .temporal_abort("The qualified rank-one temporal-spatial profile requires a replicated AR1 panel.")
    }
  } else if (dep_spatial_pair) {
    if (!identical(object$temporal$structure, "ar1") || is.null(object$temporal$replicate_col)) {
      .temporal_abort("The qualified temporal-dependent spatial profile requires a replicated AR1 panel.")
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
