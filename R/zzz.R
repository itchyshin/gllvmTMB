## Package-level roxygen block for the auto-generated NAMESPACE entry
## that registers the compiled TMB engine (src/gllvmTMB.cpp).
#' @useDynLib gllvmTMB, .registration = TRUE
#' @section Current limitations and boundaries:
#' Before choosing a family, covariance source, estimator, or interval method,
#' read the
#' [current limitations and boundaries](https://itchyshin.github.io/gllvmTMB/articles/current-limits.html).
#' @keywords internal
"_PACKAGE"

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "gllvmTMB is experimental. Use a documented tutorial, inspect fit ",
    "diagnostics, and read Current limitations and boundaries before treating ",
    "an estimate or interval as a scientific result. Convergence alone is not ",
    "enough."
  )
}

.onUnload <- function(libpath) {
  library.dynam.unload("gllvmTMB", libpath)
}
