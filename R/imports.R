## Centralised import declarations.
##
## Many of gllvmTMB's R files were inherited from sdmTMB and use
## `cli_abort()` / `cli_warn()` / `cli_inform()` and `assert_that()`
## as bare names. This file imports them once for the whole package
## namespace so the rest of R/*.R doesn't need per-file
## `@importFrom` blocks.

#' @importFrom cli cli_abort cli_warn cli_inform
#' @importFrom assertthat assert_that
#' @importFrom stats predict model.frame gaussian as.formula
#' @importFrom methods as
#' @keywords internal
NULL
