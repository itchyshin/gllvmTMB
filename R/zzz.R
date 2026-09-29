## Package-level roxygen block for the auto-generated NAMESPACE entry
## that registers the compiled TMB engine (src/gllvmTMB.cpp).
#' @title gllvmTMB: Generalised Linear Latent Variable Models with TMB
#' @useDynLib gllvmTMB, .registration = TRUE
#' @section Current limitations and boundaries:
#' The online [current limitations and boundaries
#' page](https://itchyshin.github.io/gllvmTMB/articles/current-limits.html)
#' follows the development version and may describe changes made after 0.7.1.
#' For the scope and restrictions of 0.7.1, use this release's NEWS and the
#' help and vignettes installed with the package.
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
    "For 0.7.1 scope, see its installed help, vignettes, and NEWS. The ",
    "online limitations page may differ as development continues."
  )
}

.onUnload <- function(libpath) {
  library.dynam.unload("gllvmTMB", libpath)
}
