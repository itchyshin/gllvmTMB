## Package-level roxygen block for the auto-generated NAMESPACE entry
## that registers the compiled TMB engine (src/gllvmTMB.cpp).
#' @useDynLib gllvmTMB, .registration = TRUE
#' @keywords internal
"_PACKAGE"

.onUnload <- function(libpath) {
  library.dynam.unload("gllvmTMB", libpath)
}
