# Report-ready tidy tables returned by the covariance/correlation extractors
# carry internal provenance columns (notably `validation_row`, which indexes the
# internal validation register with codes such as "EXT-18"). Those columns are
# required by internal machinery and tests, but they are maintainer bookkeeping,
# not reader-facing content, so they must not surface when the table is printed.
#
# `.reportable_table()` tags such a table with the `gllvmTMB_reportable_table`
# class; the `print` method below hides the internal columns from display while
# leaving them in the object for programmatic and machinery use.

# Columns that are internal provenance and should never print reader-facing.
.reportable_internal_cols <- c("validation_row")

#' @keywords internal
#' @noRd
.reportable_table <- function(x) {
  if (!is.data.frame(x)) {
    return(x)
  }
  class(x) <- unique(c("gllvmTMB_reportable_table", class(x)))
  x
}

#' Print a report-ready gllvmTMB covariance/correlation table
#'
#' Prints the reader-facing columns of a report-ready table returned by
#' [extract_Sigma_table()] or [extract_correlations()]. The complete object is
#' returned invisibly for programmatic use.
#'
#' @param x A `gllvmTMB_reportable_table` object.
#' @param ... Passed to the data-frame print method.
#' @return `x`, invisibly.
#' @keywords internal
#' @exportS3Method print gllvmTMB_reportable_table
print.gllvmTMB_reportable_table <- function(x, ...) {
  visible <- x
  class(visible) <- "data.frame"
  hidden <- intersect(.reportable_internal_cols, names(visible))
  if (length(hidden) > 0L) {
    visible <- visible[, setdiff(names(visible), hidden), drop = FALSE]
  }
  print(visible, ...)
  invisible(x)
}
