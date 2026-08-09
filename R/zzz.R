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
    "gllvmTMB is EXPERIMENTAL (lifecycle: experimental). Use at your own risk: ",
    "the package is not complete, is not fully human-verified, and needs ",
    "extensive further validation. Point estimates are the primary inferential ",
    "output, but evidence is route- and regime-specific. Broad interval ",
    "coverage is not certified. One narrow two-sided ",
    "Gaussian total-variance profile regime has a documented 0.94 floor. ",
    "See the Current limitations and boundaries page for scope."
  )
}

.onUnload <- function(libpath) {
  library.dynam.unload("gllvmTMB", libpath)
}
