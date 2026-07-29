## Centralised import declarations.
##
## Many of gllvmTMB's R files were inherited from sdmTMB and use
## `cli_abort()` / `cli_warn()` / `cli_inform()` and `assert_that()`
## as bare names. This file imports them once for the whole package
## namespace so the rest of R/*.R doesn't need per-file
## `@importFrom` blocks.

#' @importFrom cli cli_abort cli_warn cli_inform
#' @importFrom assertthat assert_that
#' @importFrom stats predict model.frame gaussian as.formula residuals
## `dnorm` and `plogis` are called unqualified at R/aghq-control.R:118 and
## R/eva-proto.R (the scalar Bernoulli reference), which R CMD check reports as
## "no visible global function definition". Same class as the AIC/BIC namespace
## defect: `stats` is in DESCRIPTION Imports but the specific generic was never
## imported, so it is not visible from the package namespace.
#' @importFrom stats dnorm plogis
#' @importFrom methods as
#' @keywords internal
NULL
