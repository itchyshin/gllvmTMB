## Shared CI-status helpers for matrix-like interval returns.
##
## These are intentionally internal: public methods expose the status as
## either a data-frame column or a row-named matrix attribute.

.gtmb_ci_status <- function(method, lower, upper) {
  lower <- as.numeric(lower)
  upper <- as.numeric(upper)
  finite_lower <- is.finite(lower)
  finite_upper <- is.finite(upper)
  both <- finite_lower & finite_upper
  partial <- xor(finite_lower, finite_upper)
  neither <- !finite_lower & !finite_upper
  out <- rep("ok", length(lower))
  method <- as.character(method)[1L]

  if (identical(method, "profile")) {
    out[partial] <- "profile_boundary"
    out[neither] <- "profile_failed"
  } else if (identical(method, "bootstrap")) {
    out[partial] <- "partial_interval"
    out[neither] <- "bootstrap_failed"
  } else if (method %in% c("wald", "wald_asym")) {
    out[!both] <- "wald_unavailable"
  } else if (identical(method, "fisher-z")) {
    out[!both] <- "fisher_z_unavailable"
  } else {
    out[!both] <- "interval_unavailable"
  }
  out
}

.gtmb_attach_ci_status <- function(
  out,
  method,
  lower = out[, 1L],
  upper = out[, 2L]
) {
  rn <- rownames(out)
  if (is.null(rn)) {
    rn <- rep.int("", nrow(out))
  }
  attr(out, "ci_status") <- stats::setNames(
    .gtmb_ci_status(method, lower, upper),
    rn
  )
  out
}

.gtmb_rho_ci_status <- function(method, lower, upper) {
  .gtmb_ci_status(method, lower, upper)
}
