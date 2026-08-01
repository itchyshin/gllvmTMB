## Centralised import declarations.
##
## Centralised imports make the package's error and assertion helpers available
## without repeating `@importFrom` declarations in each R source file.

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
#' @importFrom rlang .data
#' @keywords internal
NULL
