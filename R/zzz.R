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
    "extensive further validation. Point estimates are the primary output, ",
    "and how well they are supported depends on the exact model and route ",
    "used. Broad interval coverage is not yet confirmed. A handful of ",
    "interval calculations for standardized factor loadings have been ",
    "checked and shown accurate, but only for one Gaussian model, in a few ",
    "fixed sample-size and rank combinations, fitted to ",
    "one fixed simulated dataset with known true values, and ",
    "only for fits that converge cleanly; this does not carry over to ",
    "any other sample size, rank, or dataset. ",
    "Total-variance penalty profiles are still only an ",
    "approximate calculation: even in previously checked cases, we have ",
    "not confirmed they match the exact answer. ",
    "See the Current limitations and boundaries page for scope."
  )
}

.onUnload <- function(libpath) {
  library.dynam.unload("gllvmTMB", libpath)
}
