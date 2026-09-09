#' Profile a temporal persistence or decay parameter
#'
#' Profiles the direct native temporal time parameter with all other TMB
#' parameters re-optimized. This is a fitted-parameter likelihood profile, not
#' a calibrated interval or a profile of conditional temporal states.
#'
#' @param object An unreplicated Gaussian `temporal_indep()` fit.
#' @param level Likelihood-ratio confidence level.
#' @param ... Passed to [tmbprofile_wrapper()].
#' @return Named numeric vector with `estimate`, `lower`, and `upper`, on the
#'   AR1 persistence or OU decay-rate scale. `NA` bounds mean the profile did
#'   not establish an endpoint.
#' @export
profile_temporal <- function(object, level = 0.95, ...) {
  if (!inherits(object, "gllvmTMB_multi") || !isTRUE(object$temporal$active))
    cli::cli_abort("{.fn profile_temporal} requires a native temporal fit.")
  if (!identical(object$temporal$mode, "indep") ||
      !is.null(object$temporal$replicate_col) ||
      any(object$tmb_data$family_id_vec != 0L)) {
    cli::cli_abort("{.fn profile_temporal} currently supports unreplicated Gaussian {.fn temporal_indep} fits only.")
  }
  active <- .gllvmTMB_predict_unhandled_re_tiers(object, handled = "temporal")
  if (length(active)) cli::cli_abort("{.fn profile_temporal} currently requires the temporal source by itself.")
  transform <- if (identical(object$temporal$structure, "ar1")) {
    function(x) (1 - 1e-6) * tanh(x)
  } else exp
  tmbprofile_wrapper(object, name = "theta_temporal_time", level = level,
    transform = transform, ...)
}
