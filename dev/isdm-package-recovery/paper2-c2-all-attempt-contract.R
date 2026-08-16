## Paper 2 Gate C2 — all-attempt admission/Psi contract helpers.
## Tier-1 only: hand-built records and arithmetic. No fitter, objective, profile,
## simulator, or compiled engine is reachable from these functions.

paper2_c2_cells <- function() data.frame(
  S = c(6L, 20L, 60L), C = 360L, r = 3L, b = 1L, d = 1L,
  N = c(8640L, 28800L, 86400L), P = c(36L, 120L, 360L), R = 20L
)
paper2_c2_metric_names <- c("beta", "gamma", "map_correlation", "shared_covariance", "psi_variance")
paper2_c2_metric_pass <- function(x) {
  is.list(x) && identical(names(x), paper2_c2_metric_names) &&
    isTRUE(x$beta <= 0.30) && isTRUE(x$gamma <= 0.30) &&
    isTRUE(x$map_correlation >= 0.70) && isTRUE(x$shared_covariance <= 0.50) &&
    isTRUE(x$psi_variance <= 0.20)
}
paper2_c2_attempt <- function(id, numerical_admission, psi_pass, metrics,
                              status = "FIT_RETURNED", first_failure = NA_character_,
                              available = TRUE) {
  if (!is.character(id) || length(id) != 1L || !nzchar(id) ||
      !is.logical(numerical_admission) || length(numerical_admission) != 1L ||
      !is.logical(psi_pass) || length(psi_pass) != 1L ||
      !is.logical(available) || length(available) != 1L ||
      !is.character(status) || length(status) != 1L ||
      !is.character(first_failure) || length(first_failure) != 1L ||
      !is.list(metrics) || !identical(names(metrics), paper2_c2_metric_names)) {
    stop("invalid C2 all-attempt record", call. = FALSE)
  }
  list(id = id, status = status, available = available,
       numerical_admission = numerical_admission, psi_pass = psi_pass,
       metrics = metrics, first_failure = first_failure)
}
paper2_c2_validate_attempt <- function(x) {
  required <- c("id", "status", "available", "numerical_admission", "psi_pass",
                "metrics", "first_failure")
  if (!is.list(x) || !identical(names(x), required)) stop("invalid C2 all-attempt record", call. = FALSE)
  if (!isTRUE(x$available) && (isTRUE(x$numerical_admission) || isTRUE(x$psi_pass) ||
       !identical(x$status, "UNAVAILABLE") || is.na(x$first_failure))) {
    stop("unavailable C2 attempts must remain all-attempt failures", call. = FALSE)
  }
  invisible(TRUE)
}
paper2_c2_summarise <- function(attempts, expected_R = 20L) {
  if (!is.list(attempts) || length(attempts) != expected_R) {
    stop("C2 requires exactly its independent all-attempt denominator.", call. = FALSE)
  }
  ids <- vapply(attempts, function(x) x$id, character(1L))
  if (anyDuplicated(ids)) stop("C2 attempt identifiers must be unique.", call. = FALSE)
  lapply(attempts, paper2_c2_validate_attempt)
  A <- vapply(attempts, function(x) isTRUE(x$numerical_admission), logical(1L))
  P <- vapply(attempts, function(x) isTRUE(x$psi_pass), logical(1L))
  K <- vapply(attempts, function(x) paper2_c2_metric_pass(x$metrics), logical(1L))
  J <- A & K
  list(
    schema = "PAPER2_C2_ALL_ATTEMPT_SUMMARY_V1", denominator = as.integer(expected_R),
    A_by_P = table(factor(A, levels = c(FALSE, TRUE)), factor(P, levels = c(FALSE, TRUE))),
    atomic = c(numerical_admission = sum(A), psi_pass = sum(P), known_truth = sum(K),
      strict_joint = sum(J), unavailable = sum(!vapply(attempts, function(x) x$available, logical(1L)))),
    attempts = attempts
  )
}
paper2_c2_validate_receipt <- function(x) {
  required <- c("schema", "frozen_cells", "retained_s6", "retained_s6_summary",
                "historical_provenance", "current_contract_md5", "scope")
  if (!is.list(x) || !identical(names(x), required) ||
      !identical(x$schema, "PAPER2_C2_NO_FIT_RECEIPT_V1")) {
    stop("invalid Paper 2 C2 no-fit receipt", call. = FALSE)
  }
  if (!identical(x$frozen_cells, paper2_c2_cells()) ||
      !identical(x$scope, "private_no_fit_contract_only")) {
    stop("Paper 2 C2 receipt scope or frozen cells drift", call. = FALSE)
  }
  paper2_c2_validate_retained_s6(x$retained_s6)
  expected <- paper2_c2_summarise(list(x$retained_s6), expected_R = 1L)
  provenance_required <- c("seed", "S", "C", "r", "b", "d", "retained_commit",
                           "historical_fixture_sha256")
  if (!identical(x$retained_s6_summary, expected) ||
      !is.list(x$historical_provenance) ||
      !identical(names(x$historical_provenance), provenance_required) ||
      !identical(x$historical_provenance$seed, 86122L) ||
      !identical(x$historical_provenance$S, 6L) ||
      !identical(x$historical_provenance$C, 360L) ||
      !identical(x$historical_provenance$r, 3L) ||
      !identical(x$historical_provenance$b, 1L) ||
      !identical(x$historical_provenance$d, 1L) ||
      !identical(x$historical_provenance$retained_commit, "57613984ddf844194326c3829ae97aab28ba3a35") ||
      !identical(x$historical_provenance$historical_fixture_sha256, "701ba79e88a354c7285ac4786d9464b3b8b31edf8789e5fb71ed1f887bee9969") ||
      !is.character(x$current_contract_md5) || length(x$current_contract_md5) != 3L ||
      any(!nzchar(x$current_contract_md5))) {
    stop("Paper 2 C2 receipt summary or provenance drift", call. = FALSE)
  }
  invisible(TRUE)
}
paper2_c2_retained_s6 <- function() {
  paper2_c2_attempt(
    id = "paper2-s6-86122", numerical_admission = FALSE, psi_pass = FALSE,
    metrics = list(beta = 0.1597133, gamma = 0.1043863, map_correlation = 0.7324197,
      shared_covariance = 0.2403427, psi_variance = 0.2156398),
    first_failure = "Case_C_NO_CANDIDATE; psi_variance_threshold"
  )
}
paper2_c2_validate_retained_s6 <- function(x) {
  paper2_c2_validate_attempt(x)
  if (!identical(x$id, "paper2-s6-86122") || isTRUE(x$numerical_admission) ||
      isTRUE(x$psi_pass) || paper2_c2_metric_pass(x$metrics) ||
      !identical(x$first_failure, "Case_C_NO_CANDIDATE; psi_variance_threshold")) {
    stop("retained S=6 C2 record drift", call. = FALSE)
  }
  invisible(TRUE)
}
