#' Compare supplied temporal model candidates
#' @param ... Named fitted temporal models.
#' @return AIC comparison table; no likelihood-ratio test is assigned.
#' @export
compare_temporal <- function(...) {
  fits <- list(...)
  if (length(fits) < 2L) .temporal_abort("Supply at least two named temporal fits.")
  if (is.null(names(fits)) || any(!nzchar(names(fits)))) .temporal_abort("Temporal candidates must be named.")
  ok <- vapply(fits, function(x) inherits(x, "gllvmTMB_multi") && isTRUE(x$temporal$active), logical(1))
  if (!all(ok)) .temporal_abort("Every candidate must be a native temporal fit.")
  composed <- vapply(fits, function(x) {
    length(.gllvmTMB_predict_unhandled_re_tiers(x, handled = "temporal")) > 0L
  }, logical(1))
  if (any(composed)) {
    .temporal_abort(c(
      "{.fn compare_temporal} currently requires the temporal source by itself.",
      "i" = "Candidate(s) with another covariance tier: {.val {names(fits)[composed]}}.",
      ">" = "AIC comparison for temporal source pairs needs its own selection contract and evidence."
    ), class = "gllvmTMB_temporal_selection_composed")
  }
  responses <- lapply(fits, function(x) x$data[[all.vars(x$formula[[2L]])]])
  if (!all(vapply(responses[-1L], identical, logical(1), responses[[1L]])))
    .temporal_abort("Temporal candidates must use identical response rows and ordering.")
  data.frame(model = names(fits), logLik = vapply(fits, function(x) -x$opt$objective, numeric(1)),
    df = vapply(fits, function(x) length(x$opt$par), integer(1)),
    AIC = vapply(fits, stats::AIC, numeric(1)),
    convergence = vapply(fits, function(x) x$opt$convergence, integer(1), USE.NAMES = FALSE),
    row.names = NULL)
}
