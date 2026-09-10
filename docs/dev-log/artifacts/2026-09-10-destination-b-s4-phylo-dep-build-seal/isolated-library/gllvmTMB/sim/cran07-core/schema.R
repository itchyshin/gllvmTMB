# Frozen attempt-accounting helpers for the CRAN 0.7 ordinary-core campaign.
#
# This file is campaign machinery, not package API. Keep the status order and
# required columns synchronized with the frozen specification under
# docs/dev-log/simulation-artifacts/2026-08-08-cran07-core-recovery/.

cran07_attempt_status_levels <- c(
  "planned",
  "construction_error",
  "fit_error",
  "nonfinite",
  "optimizer_failed",
  "nonstationary",
  "non_pd_hessian",
  "boundary",
  "geometry_failed",
  "usable"
)

cran07_attempt_columns <- c(
  "campaign_id", "registry_sha256", "cell_id", "replicate", "seed",
  "status", "constructed", "optimizer_converged", "stationary",
  "pd_hessian", "finite_estimands", "boundary", "geometry_flag",
  "detector_flagged", "catastrophic_truth_error",
  "relative_covariance_error", "max_eigen_ratio",
  "family", "n_trials_min", "n_trials_max", "diag_B_skip", "diag_B_all_free",
  "error_class", "error_message", "elapsed_seconds"
)

cran07_classify_attempt <- function(
  constructed = TRUE,
  fit_error = FALSE,
  finite_estimands = TRUE,
  optimizer_converged = TRUE,
  stationary = TRUE,
  pd_hessian = TRUE,
  boundary = FALSE,
  geometry_flag = FALSE
) {
  flags <- c(
    constructed = constructed,
    fit_error = fit_error,
    finite_estimands = finite_estimands,
    optimizer_converged = optimizer_converged,
    stationary = stationary,
    pd_hessian = pd_hessian,
    boundary = boundary,
    geometry_flag = geometry_flag
  )
  if (length(flags) != 8L || anyNA(flags)) {
    stop("Attempt-classification flags must be eight non-missing logical scalars.",
         call. = FALSE)
  }
  if (!constructed) return("construction_error")
  if (fit_error) return("fit_error")
  if (!finite_estimands) return("nonfinite")
  if (!optimizer_converged) return("optimizer_failed")
  if (!stationary) return("nonstationary")
  if (!pd_hessian) return("non_pd_hessian")
  if (boundary) return("boundary")
  if (geometry_flag) return("geometry_failed")
  "usable"
}

cran07_validate_attempt_table <- function(x) {
  if (!is.data.frame(x)) stop("Attempt ledger must be a data frame.", call. = FALSE)
  missing_columns <- setdiff(cran07_attempt_columns, names(x))
  if (length(missing_columns)) {
    stop("Attempt ledger is missing frozen columns: ",
         paste(missing_columns, collapse = ", "), call. = FALSE)
  }
  if (any(!x$status %in% cran07_attempt_status_levels)) {
    stop("Attempt ledger contains an unknown status.", call. = FALSE)
  }
  if (any(!grepl("^[0-9a-f]{64}$", x$registry_sha256))) {
    stop("Attempt ledger contains an invalid registry SHA-256.", call. = FALSE)
  }
  key <- paste(x$campaign_id, x$cell_id, x$replicate, sep = "::")
  if (anyDuplicated(key)) {
    stop("Attempt ledger contains duplicate immutable attempt keys.", call. = FALSE)
  }
  if (anyNA(x$replicate) || any(x$replicate < 1L) ||
      anyNA(x$seed) || any(x$seed < 1L)) {
    stop("Replicate and seed must be positive and non-missing.", call. = FALSE)
  }
  terminal <- x$status != "planned"
  expected <- vapply(which(terminal), function(i) {
    cran07_classify_attempt(
      constructed = x$constructed[i],
      fit_error = nzchar(x$error_class[i]) || nzchar(x$error_message[i]),
      finite_estimands = x$finite_estimands[i],
      optimizer_converged = x$optimizer_converged[i],
      stationary = x$stationary[i],
      pd_hessian = x$pd_hessian[i],
      boundary = x$boundary[i],
      geometry_flag = x$geometry_flag[i]
    )
  }, character(1L))
  if (length(expected) && any(x$status[terminal] != expected)) {
    stop("Attempt status contradicts its frozen diagnostic flags.", call. = FALSE)
  }
  expected_detector <- terminal & x$status != "usable"
  if (anyNA(x$detector_flagged) || any(x$detector_flagged != expected_detector)) {
    stop("detector_flagged must depend only on the observable terminal status.",
         call. = FALSE)
  }
  if (anyNA(x$catastrophic_truth_error) ||
      anyNA(x$relative_covariance_error) || anyNA(x$max_eigen_ratio)) {
    stop("Truth-error labels and metrics must be complete for terminal attempts.",
         call. = FALSE)
  }
  binomial_usable <- x$family == "binomial" & !nzchar(x$error_class) &
    !nzchar(x$error_message)
  if (any(binomial_usable & (x$n_trials_min != 10L | x$n_trials_max != 10L |
                            x$diag_B_skip != "0;0;0" | !x$diag_B_all_free))) {
    stop("Successful binomial attempts must prove n_trials=10 and all diag_B_skip entries free.",
         call. = FALSE)
  }
  invisible(TRUE)
}
