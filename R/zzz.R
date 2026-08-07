## Package-level roxygen block for the auto-generated NAMESPACE entry
## that registers the compiled TMB engine (src/gllvmTMB.cpp).
#' @useDynLib gllvmTMB, .registration = TRUE
#' @keywords internal
"_PACKAGE"

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "gllvmTMB is EXPERIMENTAL (lifecycle: experimental). Use at your own risk: ",
    "the package is not complete, is not fully human-verified, and needs ",
    "extensive further validation. Point estimates are the supported claim. ",
    "Interval coverage evidence exists only for the documented ",
    "profile_ci_total_variance() regime (gaussian unit-tier total variance ",
    "under named size limits; status certified-0.94 marks regime membership); ",
    "other interval routes remain recovery-oriented or uncalibrated. ",
    "Covariance routes have focused-test evidence only. See NEWS and the ",
    "package website for scope."
  )
}

.onUnload <- function(libpath) {
  library.dynam.unload("gllvmTMB", libpath)
}
