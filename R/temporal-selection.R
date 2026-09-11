#' Compare supplied temporal model candidates
#'
#' The bounded composed route accepts only replicated Gaussian AR1
#' `temporal_indep() + kernel_indep()` candidates with the same fixed labelled
#' kernel. It reports AIC only and does not perform a likelihood-ratio test or
#' automatic search.
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
  kernel_pair <- vapply(fits, function(x) {
    .temporal_is_qualified_kernel_pair(
      x, .gllvmTMB_predict_unhandled_re_tiers(x, handled = "temporal")
    )
  }, logical(1))
  if (any(composed) && !all(kernel_pair)) {
    .temporal_abort(c(
      "{.fn compare_temporal} supports only matching qualified temporal-kernel candidates.",
      "i" = "Candidate(s) with another covariance tier: {.val {names(fits)[composed]}}.",
      ">" = "Supply temporal-only fits, or replicated AR1 {.code temporal_indep() + kernel_indep()} fits with one identical labelled kernel."
    ), class = "gllvmTMB_temporal_selection_composed")
  }
  if (all(kernel_pair)) {
    qualified <- vapply(fits, function(x) {
      identical(x$temporal$mode, "indep") &&
        identical(x$temporal$structure, "ar1") &&
        !is.null(x$temporal$replicate_col) &&
        all(x$tmb_data$family_id_vec == 0L)
    }, logical(1))
    if (!all(qualified)) {
      .temporal_abort("The qualified temporal-kernel comparison requires replicated Gaussian AR1 {.fn temporal_indep} fits.")
    }
    reference_name <- fits[[1L]]$kernel_levels$name
    reference_matrix <- fits[[1L]]$kernel_matrices[[reference_name]]
    same_kernel <- vapply(fits, function(x) {
      identical(x$kernel_levels$name, reference_name) &&
        isTRUE(all.equal(x$kernel_matrices[[reference_name]], reference_matrix,
          check.attributes = TRUE, tolerance = 0))
    }, logical(1))
    if (!all(same_kernel)) {
      .temporal_abort(c(
        "Qualified temporal-kernel candidates must use the same labelled kernel.",
        ">" = "Fit every supplied candidate with the same {.code kernel_indep()} label and matrix."
      ), class = "gllvmTMB_temporal_selection_kernel")
    }
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
