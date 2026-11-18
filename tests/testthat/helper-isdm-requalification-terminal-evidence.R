## Pure helpers for the checksum-bound v3 terminal adjudication.
## These functions do not fit a model or write an attempt record.

isdm_v3_normalize_psi <- function(record) {
  if (!is.list(record) || !identical(record$status, "fit_returned")) {
    return(record)
  }
  truth <- record$truth$Psi
  estimate <- record$estimate$Psi
  sigma <- record$estimate$Sigma
  if (!is.matrix(truth) || !is.numeric(truth) ||
      nrow(truth) != ncol(truth) || nrow(truth) < 1L) {
    stop("v3 Psi repair requires a square numeric truth matrix")
  }
  truth_names <- rownames(truth)
  if (is.null(truth_names) || anyNA(truth_names) || any(!nzchar(truth_names)) ||
      anyDuplicated(truth_names) || !identical(colnames(truth), truth_names)) {
    stop("v3 Psi repair requires identical unique truth row/column names")
  }
  if (!is.matrix(sigma) || !identical(dim(sigma), dim(truth)) ||
      !identical(rownames(sigma), truth_names) ||
      !identical(colnames(sigma), truth_names)) {
    stop("v3 Psi repair requires Sigma to bind the exact truth trait order")
  }
  if (!is.matrix(estimate) || !is.numeric(estimate) ||
      !identical(dim(estimate), dim(truth)) || any(!is.finite(estimate))) {
    stop("v3 Psi repair requires a finite estimate with the truth dimensions")
  }
  estimate_names <- dimnames(estimate)
  if (is.null(estimate_names) ||
      (is.null(estimate_names[[1L]]) && is.null(estimate_names[[2L]]))) {
    dimnames(estimate) <- list(truth_names, truth_names)
  } else if (!identical(rownames(estimate), truth_names) ||
             !identical(colnames(estimate), truth_names)) {
    stop("v3 Psi repair refuses non-matching estimate trait names")
  }
  record$estimate$Psi <- estimate
  record
}

isdm_v3_attack_classification <- function(record) {
  warnings <- record$warnings
  if (is.null(warnings)) warnings <- character()
  warnings <- as.character(warnings)
  relevant_pattern <- paste(
    c("disconnect", "non[- ]?identif", "overlap", "support"),
    collapse = "|"
  )
  relevant_warning <- any(grepl(
    relevant_pattern, warnings, ignore.case = TRUE, perl = TRUE
  ))
  fit_returned <- identical(record$status, "fit_returned")
  fit_refusal <- identical(record$status, "error") &&
    identical(record$failure_phase, "fit")
  unhealthy <- fit_returned &&
    (!identical(record$diagnostics$convergence, 0L) ||
       !isTRUE(record$diagnostics$pd_hessian))
  routine_warning_only <- fit_returned && length(warnings) > 0L &&
    !relevant_warning && !unhealthy
  list(
    qualified = fit_refusal || relevant_warning || unhealthy,
    fit_refusal = fit_refusal,
    relevant_warning = relevant_warning,
    unhealthy = unhealthy,
    routine_warning_only = routine_warning_only
  )
}

isdm_v3_attack_verdict <- function(attack_records, ordinary_complete) {
  classification <- lapply(attack_records, isdm_v3_attack_classification)
  count <- function(name) {
    sum(vapply(classification, `[[`, logical(1L), name))
  }
  complete <- isTRUE(ordinary_complete) && length(attack_records) == 200L
  qualified <- count("qualified")
  list(
    verdict = if (complete && qualified == 200L) "PASS" else "FAIL",
    disposition = if (complete) "STRESS_ONLY" else "INCOMPLETE",
    complete = complete,
    planned = 200L,
    diagnostic_qualified = qualified,
    fit_refusal = count("fit_refusal"),
    relevant_warning = count("relevant_warning"),
    unhealthy = count("unhealthy"),
    routine_warning_only = count("routine_warning_only"),
    silent_or_unqualified = 200L - qualified
  )
}
