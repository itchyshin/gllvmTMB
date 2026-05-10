## Re-export generics that the gllvmTMB_multi S3 methods register against.
##
## `tidy()` is the broom-style generic. The legacy package shipped its own
## `tidy.gllvmTMB` (single-response) implementation in R/tidy.R; that file
## was cut along with the single-response engine. The multivariate
## `tidy.gllvmTMB_multi` lives in R/methods-gllvmTMB.R and dispatches off
## the generic re-exported here.

#' @importFrom generics tidy
#' @export
generics::tidy
