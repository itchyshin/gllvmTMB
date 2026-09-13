#' Compare supplied temporal model candidates
#' @param ... Named fitted temporal models.
#' @return AIC comparison table; no likelihood-ratio test is assigned. The
#'   qualified replicated AR1 `temporal_indep() + kernel_indep()` cell with one
#'   fixed labelled kernel is supported alongside temporal-only candidates.
#' @export
compare_temporal <- function(...) {
  fits <- list(...)
  if (length(fits) < 2L) .temporal_abort("Supply at least two named temporal fits.")
  if (is.null(names(fits)) || any(!nzchar(names(fits)))) .temporal_abort("Temporal candidates must be named.")
  ok <- vapply(fits, function(x) inherits(x, "gllvmTMB_multi") && isTRUE(x$temporal$active), logical(1))
  if (!all(ok)) .temporal_abort("Every candidate must be a native temporal fit.")
  active <- lapply(fits, .gllvmTMB_predict_unhandled_re_tiers, handled = "temporal")
  composed <- lengths(active) > 0L
  indep_kernel_pair <- mapply(.temporal_is_qualified_indep_kernel_pair,
    fits, active, USE.NAMES = FALSE)
  if (any(composed & !indep_kernel_pair)) {
    .temporal_abort(c(
      "{.fn compare_temporal} supports the temporal source by itself, or the qualified AR1 {.fn temporal_indep} + {.fn kernel_indep} cell.",
      "i" = "Candidate(s) with another covariance tier: {.val {names(fits)[composed & !indep_kernel_pair]}}.",
      ">" = "AIC comparison for temporal source pairs needs its own selection contract and evidence."
    ), class = "gllvmTMB_temporal_selection_composed")
  }
  responses <- lapply(fits, function(x) x$tmb_data$y)
  if (!all(vapply(responses[-1L], identical, logical(1), responses[[1L]])))
    .temporal_abort("Temporal candidates must use identical response rows and ordering.")
  data.frame(model = names(fits), logLik = vapply(fits, function(x) -x$opt$objective, numeric(1)),
    df = vapply(fits, function(x) length(x$opt$par), integer(1)),
    AIC = vapply(fits, stats::AIC, numeric(1)),
    convergence = vapply(fits, function(x) x$opt$convergence, integer(1), USE.NAMES = FALSE),
    row.names = NULL)
}
