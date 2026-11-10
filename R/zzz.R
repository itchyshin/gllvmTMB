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

.onLoad <- function(libname, pkgname) {
  ## #1759. gllvm's generics mask getLoadings/getLV/getResidualCov/
  ## getResidualCor when that package is attached. Register on gllvm's
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
