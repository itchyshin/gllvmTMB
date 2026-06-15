## Shared CI-status helpers for matrix-like interval returns.
##
## These are intentionally internal: public methods expose the status as
## either a data-frame column or a row-named matrix attribute.

.gtmb_ci_status <- function(method, lower, upper) {
  lower <- as.numeric(lower)
  upper <- as.numeric(upper)
  n <- max(length(lower), length(upper))
  if (n == 0L) {
    return(character(0))
  }
  method <- rep_len(as.character(method), n)
  lower <- rep_len(lower, n)
  upper <- rep_len(upper, n)
  finite_lower <- is.finite(lower)
  finite_upper <- is.finite(upper)
  both <- finite_lower & finite_upper
  partial <- xor(finite_lower, finite_upper)
  neither <- !finite_lower & !finite_upper
  out <- rep("ok", length(lower))

  unavailable <- is.na(method) | !nzchar(method) | method == "(unavailable)"
  out[unavailable] <- "interval_unavailable"

  profile <- method == "profile" & !unavailable
  out[profile & partial] <- "profile_boundary"
  out[profile & neither] <- "profile_failed"

  bootstrap <- method == "bootstrap" & !unavailable
  out[bootstrap & partial] <- "partial_interval"
  out[bootstrap & neither] <- "bootstrap_failed"

  wald <- (method %in% c("wald", "wald_asym") | startsWith(method, "wald(")) &
    !unavailable
  out[wald & !both] <- "wald_unavailable"

  fisher_z <- method == "fisher-z" & !unavailable
  out[fisher_z & !both] <- "fisher_z_unavailable"

  other <- !(unavailable | profile | bootstrap | wald | fisher_z)
  out[other & !both] <- "interval_unavailable"
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

.gtmb_add_ci_status_column <- function(
  out,
  method_col = "method",
  lower_col = "lower",
  upper_col = "upper",
  status_col = "ci_status"
) {
  out[[status_col]] <- .gtmb_ci_status(
    out[[method_col]],
    out[[lower_col]],
    out[[upper_col]]
  )
  out
}
