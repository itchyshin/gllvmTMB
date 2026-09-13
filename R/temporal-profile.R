#' Profile a temporal persistence or decay parameter
#'
#' Profiles the direct native temporal time parameter with all other TMB
#' parameters re-optimized. This is a fitted-parameter likelihood profile, not
#' a calibrated interval or a profile of conditional temporal states.
#'
#' @param object An unreplicated Gaussian `temporal_indep()` fit, or the
#'   qualified replicated AR1 `temporal_indep() + kernel_indep()` fit with one
#'   fixed labelled kernel.
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
  indep_kernel_pair <- .temporal_is_qualified_indep_kernel_pair(object, active)
  if (!identical(object$temporal$mode, "indep") ||
      any(object$tmb_data$family_id_vec != 0L)) {
    .temporal_abort("{.fn profile_temporal} currently supports Gaussian {.fn temporal_indep} fits only.")
  }
  if (!is.null(object$temporal$replicate_col) && !indep_kernel_pair) {
    .temporal_abort(c(
      "{.fn profile_temporal} supports replicated panels only for the qualified AR1 {.fn temporal_indep} + {.fn kernel_indep} cell.",
      "i" = "Other temporal source combinations need their own profiling contract and evidence."
    ), class = "gllvmTMB_temporal_profile_replicated")
  }
  if (length(active) && !indep_kernel_pair) .temporal_abort(c(
    "{.fn profile_temporal} currently supports the temporal source by itself, or the qualified AR1 {.fn temporal_indep} + {.fn kernel_indep} cell.",
    "i" = "Other temporal source combinations need their own profiling contract and evidence."
  ), class = "gllvmTMB_temporal_profile_composed")
  transform <- if (identical(object$temporal$structure, "ar1")) {
    function(x) (1 - 1e-6) * tanh(x)
  } else exp
  tmbprofile_wrapper(object, name = "theta_temporal_time", level = level,
    transform = transform, ...)
}
