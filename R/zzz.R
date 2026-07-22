## Package-level roxygen block for the auto-generated NAMESPACE entry
## that registers the compiled TMB engine (src/gllvmTMB.cpp).
#' @useDynLib gllvmTMB, .registration = TRUE
#' @keywords internal
"_PACKAGE"

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "gllvmTMB is EXPERIMENTAL (lifecycle: experimental). Use at your own risk: ",
    "the package is not complete, is not fully human-verified, and needs ",
    "extensive further validation. Point estimates are the supported claim; ",
    "interval calibration is established only for the Gaussian cells that ",
    "cleared the coverage gate. See NEWS and the package website for scope."
  )
}

.onUnload <- function(libpath) {
  library.dynam.unload("gllvmTMB", libpath)
}
