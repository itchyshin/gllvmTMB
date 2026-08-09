## `vcov()` and `coef()` for multi-trait fits.
##
## Added 2026-08-04. The `@return` block of `gllvmTMB()` had claimed for some
## time that "S3 methods such as tidy(), predict(), vcov(), logLik() etc.
## dispatch on gllvmTMB". An audit of every generic it named found `vcov()` and
## `coef()` were registered ONLY for the variational `gllvmTMB_va` class, where
## they deliberately refuse -- so on an ordinary multi-trait fit both raised R's
## "no applicable method". The documentation was corrected first, and these two
## methods make the original promise true.
##
## Both read what the fit already carries; neither computes anything new.

#' Fixed-effect estimates and covariance for a multi-trait fit
#'
#' `coef()` returns the fixed-effect point estimates; `vcov()` returns their
#' covariance matrix, taken from the fit's TMB `sdreport()`.
#'
#' @param object A fitted multivariate model returned by [gllvmTMB()].
#' @param ... Ignored, present for S3 consistency.
#'
#' @return
#' `coef()`: a named numeric vector, one entry per fixed-effect term
#' (`object$X_fix_names`).
#'
#' `vcov()`: a square numeric matrix with those same names on both margins.
#' Rows and columns for coefficients held fixed via `Xcoef_fixed` are `NA` --
#' a fixed parameter was not estimated, so it has no sampling covariance.
#'
#' @section Point estimates need no standard errors:
#' `coef()` works on any fit, including one made with
#' `gllvmTMBcontrol(se = FALSE)` -- point estimates are this package's supported
#' claim and do not depend on `sdreport()`. `vcov()` does depend on it, and
#' raises the same typed errors [confint()] does when it is missing
#' (`gllvmTMB_confint_no_sdreport`) or non-finite
#' (`gllvmTMB_confint_nonfinite_se`), naming `standard_errors()` as the remedy
#' in the first case. The conditions are shared deliberately: a caller that
#' handles one should handle the other.
#'
#' @section What this covariance is:
#' The fixed-effect block of the single TMB `sdreport()` the fit already
#' carries -- a Wald covariance, with exactly the caveats any Wald quantity
#' from this package carries. It is not a resampled or profiled quantity, and
#' no interval built from it has certified coverage.
#'
#' @seealso [standard_errors()] to compute the `sdreport()` after fitting;
#'   [confint()] for intervals; [summary()] for a coefficient table.
#' @name gllvmTMB_multi-vcov
#' @examples
#' \dontrun{
#' coef(fit)
#' vcov(fit)
#' }
NULL

#' @rdname gllvmTMB_multi-vcov
#' @export
coef.gllvmTMB_multi <- function(object, ...) {
  nm <- object$X_fix_names %||% character(0)
  if (length(nm) == 0L) {
    return(stats::setNames(numeric(0), character(0)))
  }
  stats::setNames(as.numeric(.gllvmTMB_b_fix_values(object)), nm)
}

#' @rdname gllvmTMB_multi-vcov
#' @export
vcov.gllvmTMB_multi <- function(object, ...) {
  .gllvmTMB_mspl_assert_inference(object, "vcov")
  nm <- object$X_fix_names %||% character(0)
  if (length(nm) == 0L) {
    return(matrix(numeric(0), 0L, 0L))
  }

  ## Same gate, same condition classes, same remedies as confint()'s Wald path.
  .confint_require_sdreport(object, method = "wald", caller = "vcov")

  cv <- object$sd_report$cov.fixed
  out <- matrix(NA_real_, length(nm), length(nm), dimnames = list(nm, nm))
  if (is.null(cv) || length(cv) == 0L) {
    return(out)
  }

  ## `cov.fixed` covers the ESTIMATED parameters only, and its rows are named
  ## by parameter block. Coefficients held fixed via `Xcoef_fixed` never enter
  ## it, so the block can be shorter than `nm` -- align on the free ones rather
  ## than assuming a 1:1 correspondence.
  idx <- which(rownames(cv) == "b_fix")
  if (length(idx) == 0L) {
    return(out)
  }
  free <- .gllvmTMB_xcoef_status(object) != "fixed"

  if (length(idx) == sum(free)) {
    out[free, free] <- cv[idx, idx, drop = FALSE]
  } else if (length(idx) >= length(nm)) {
    keep <- idx[seq_along(nm)]
    out[] <- cv[keep, keep, drop = FALSE]
  }
  out
}
