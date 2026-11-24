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
    "enough. Broad package-wide interval coverage is not yet confirmed. A ",
    "handful of interval calculations for standardized factor loadings have ",
    "been checked and shown accurate, but only for one Gaussian model, in a few ",
    "fixed sample-size and rank combinations, fitted to ",
    "one fixed simulated dataset with known true values, and ",
    "only for fits that converge cleanly; this does not carry over to any other ",
    "sample size, rank, or dataset. Total-variance penalty profiles are still ",
    "only an approximate calculation: even in previously checked cases, we have ",
    "not confirmed they match the exact answer."
  )
}

.onLoad <- function(libname, pkgname) {
  ## #1759 / #1768. gllvm's generics mask getLoadings/getLV/getResidualCov/
  ## getResidualCor/simulate when that package is attached. Register on gllvm's
  ## S3 table at load, and again if gllvm is attached later in the session.
  if (!isTRUE(.gllvm_mask_hook_installed)) {
    setHook(
      packageEvent("gllvm", "onLoad"),
      .gllvm_mask_on_gllvm_load,
      action = "append"
    )
    utils::assignInMyNamespace(".gllvm_mask_hook_installed", TRUE)
  }
  if (isNamespaceLoaded("gllvm")) {
    .register_gllvm_masking_methods()
  }
}

.onUnload <- function(libpath) {
  library.dynam.unload("gllvmTMB", libpath)
}
