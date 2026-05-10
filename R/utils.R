## ---------------------------------------------------------------------
## Small utilities used across the gllvmTMB-native R/ tree.
##
## The legacy package's `R/utils.R` was a 841-line catch-all of
## sdmTMB single-response engine helpers (sdmTMBcontrol(), get_pars(),
## replicate_df(), make_category_svc(), expand_time(), etc.). All of
## those were tied to the cut single-response API; the gllvmTMB-multi
## engine in `R/fit-multi.R` does not use them. What remains here are
## the small helpers that the parser (`R/parsing.R`) and other
## utility-using files (`R/plot.R`) still reach for.
## ---------------------------------------------------------------------

#' Safely deparse a language object back to a single string
#' @keywords internal
#' @noRd
safe_deparse <- function(x, collapse = " ") {
  paste(deparse(x, 500L), collapse = collapse)
}

#' Pull a printable label out of a call expression
#' @keywords internal
#' @noRd
extract_call_name <- function(call_element, max_width = 80) {
  if (is.call(call_element)) {
    text <- safe_deparse(call_element)
  } else {
    text <- as.character(call_element)
  }
  if (nchar(text) > max_width) {
    text <- paste0(substr(text, 1L, max_width - 1L), "...")
  }
  text
}

#' Is the {ggplot2} package installed?
#' @keywords internal
#' @noRd
ggplot2_installed <- function() {
  requireNamespace("ggplot2", quietly = TRUE)
}
