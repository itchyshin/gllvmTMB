## G3 private full-vector Newton-polish contract.
## Tier 1 only: pure numeric checks on hand-built values. No TMB object, fitter,
## optimiser, profile, simulator, or data reader is reachable from this file.

g3_raw_gradient_gate <- 1e-3
g3_health_gradient_gate <- 1e-2
g3_trial_alphas <- 2^-(0:8)
g3_hessian_condition_limit <- 1e8

g3_signature_names <- c("objective", "gradient", "parameter_order", "map", "data",
  "random", "bounds", "scale", "controls", "starts", "selection", "source_gate")

g3_validate_signature <- function(x) {
  is.list(x) && identical(names(x), g3_signature_names) &&
    all(vapply(x, function(z) is.character(z) && length(z) == 1L && nzchar(z), logical(1L)))
}

g3_historical_comparators <- list(
  paper1_spatial = list(attempt_id = "paper1-spatial-b2-86202", status = "PRIVATE_NUMERICAL_ADMISSION_HOLD",
    case = "D", source_sha256 = "deade4fe9dae9f6da191e78139baba86d8658d625a3547cd8f1a5c1bd036ec5f"),
  paper2_nonspatial = list(attempt_id = "paper2-s6-86122", status = "PAPER2_PRIVATE_STOP_HOLD",
    case = "C", source_sha256 = "701ba79e88a354c7285ac4786d9464b3b8b31edf8789e5fb71ed1f887bee9969")
)
g3_validate_historical_comparator <- function(x, family) {
  identical(x, g3_historical_comparators[[family]])
}

g3_validate_hessian <- function(hessian, parameter_names,
                                 condition_limit = g3_hessian_condition_limit) {
  n <- length(parameter_names)
  typed <- is.matrix(hessian) && identical(dim(hessian), c(n, n)) &&
    is.character(parameter_names) && n > 0L && !anyDuplicated(parameter_names) &&
    identical(rownames(hessian), parameter_names) && identical(colnames(hessian), parameter_names) &&
    all(is.finite(hessian)) && is.numeric(condition_limit) && length(condition_limit) == 1L &&
    is.finite(condition_limit) && condition_limit > 1
  if (!typed || !isTRUE(all.equal(hessian, t(hessian), tolerance = 1e-10))) {
    return(list(valid = FALSE, reason = "invalid_or_nonsymmetric_hessian"))
  }
  chol_h <- tryCatch(chol(hessian), error = function(e) NULL)
  if (is.null(chol_h)) return(list(valid = FALSE, reason = "non_pd_hessian"))
  kappa <- tryCatch(kappa(hessian, exact = TRUE), error = function(e) Inf)
  if (!is.finite(kappa) || kappa > condition_limit) {
    return(list(valid = FALSE, reason = "ill_conditioned_hessian", condition = kappa))
  }
  list(valid = TRUE, reason = "ok", condition = unname(kappa))
}

g3_eligible <- function(raw, hessian, signature, raw_gradient_gate = g3_raw_gradient_gate,
                        health_gradient_gate = g3_health_gradient_gate) {
  required <- c("optimizer", "convergence", "objective", "gradient", "parameter_names",
    "pd_hessian", "boundary_flags", "tie_count")
  if (!is.list(raw) || !all(required %in% names(raw)) || !g3_validate_signature(signature) ||
      !identical(raw$optimizer, "nlminb") || !identical(raw$convergence, 0L) ||
      !is.numeric(raw$objective) || length(raw$objective) != 1L || !is.finite(raw$objective) ||
      !is.numeric(raw$gradient) || !length(raw$gradient) || any(!is.finite(raw$gradient)) ||
      !is.character(raw$parameter_names) || length(raw$parameter_names) != length(raw$gradient) ||
      anyDuplicated(raw$parameter_names) || !identical(names(raw$gradient), raw$parameter_names) ||
      !identical(raw$pd_hessian, TRUE) ||
      !is.character(raw$boundary_flags) || length(raw$boundary_flags) ||
      !identical(raw$tie_count, as.integer(length(which(abs(raw$gradient) == max(abs(raw$gradient))))))) {
    return(list(eligible = FALSE, reason = "invalid_raw_state"))
  }
  max_gradient <- max(abs(raw$gradient))
  if (!(max_gradient > raw_gradient_gate && max_gradient < health_gradient_gate)) {
    return(list(eligible = FALSE, reason = "outside_g3_open_gradient_interval"))
  }
  curvature <- g3_validate_hessian(hessian, raw$parameter_names)
  if (!isTRUE(curvature$valid)) return(list(eligible = FALSE, reason = curvature$reason))
  list(eligible = TRUE, reason = "g3_full_vector_candidate", max_gradient = max_gradient,
       condition = curvature$condition)
}

g3_newton_trial <- function(par, gradient, hessian, alpha, lower, upper) {
  n <- length(par)
  typed <- is.numeric(par) && n > 0L && all(is.finite(par)) &&
    is.numeric(gradient) && length(gradient) == n && all(is.finite(gradient)) &&
    is.numeric(alpha) && length(alpha) == 1L && alpha %in% g3_trial_alphas &&
    is.numeric(lower) && length(lower) == n && is.numeric(upper) && length(upper) == n &&
    !anyNA(lower) && !anyNA(upper) && !any(is.nan(lower)) && !any(is.nan(upper)) && all(lower <= upper) &&
    identical(names(par), names(gradient)) && identical(names(par), names(lower)) &&
    identical(names(par), names(upper))
  if (!typed) return(list(feasible = FALSE, reason = "invalid_trial_input"))
  curvature <- g3_validate_hessian(hessian, names(par))
  if (!isTRUE(curvature$valid)) return(list(feasible = FALSE, reason = curvature$reason))
  direction <- tryCatch(as.numeric(solve(hessian, gradient)), error = function(e) NULL)
  if (is.null(direction) || any(!is.finite(direction))) {
    return(list(feasible = FALSE, reason = "hessian_solve_failure"))
  }
  candidate <- par - alpha * direction
  names(candidate) <- names(par)
  if (any(candidate < lower) || any(candidate > upper)) {
    return(list(feasible = FALSE, reason = "candidate_outside_bounds", candidate = candidate))
  }
  list(feasible = TRUE, reason = "feasible", candidate = candidate,
       direction = direction, alpha = alpha, condition = curvature$condition)
}

g3_accept <- function(raw, candidate, raw_signature, candidate_signature,
                      raw_gradient_gate = g3_raw_gradient_gate) {
  required <- c("objective", "gradient", "parameter_vector", "parameter_names", "hessian", "lower", "upper",
                "pd_hessian", "feasible")
  valid <- function(x) is.list(x) && all(required %in% names(x)) &&
    is.numeric(x$objective) && length(x$objective) == 1L && is.finite(x$objective) &&
    is.numeric(x$gradient) && length(x$gradient) > 0L && all(is.finite(x$gradient)) &&
    is.numeric(x$parameter_vector) && length(x$parameter_vector) == length(x$gradient) &&
    all(is.finite(x$parameter_vector)) && is.character(x$parameter_names) &&
    identical(names(x$parameter_vector), x$parameter_names) &&
    identical(names(x$gradient), x$parameter_names) &&
    is.numeric(x$lower) && is.numeric(x$upper) && length(x$lower) == length(x$gradient) &&
    length(x$upper) == length(x$gradient) && all(is.finite(x$lower)) && all(is.finite(x$upper)) &&
    all(x$lower <= x$upper) && all(x$parameter_vector >= x$lower) && all(x$parameter_vector <= x$upper) &&
    identical(x$pd_hessian, TRUE) && identical(x$feasible, TRUE)
  if (!valid(raw) || !valid(candidate) || !is.numeric(candidate$alpha) ||
      length(candidate$alpha) != 1L || !candidate$alpha %in% g3_trial_alphas ||
      !identical(raw$parameter_names, candidate$parameter_names) ||
      !isTRUE(g3_validate_hessian(candidate$hessian, candidate$parameter_names)$valid) ||
      !g3_validate_signature(raw_signature) ||
      !identical(raw_signature, candidate_signature)) return(FALSE)
  trial <- g3_newton_trial(raw$parameter_vector, raw$gradient, raw$hessian,
    candidate$alpha, raw$lower, raw$upper)
  if (!isTRUE(trial$feasible) || !isTRUE(all.equal(candidate$parameter_vector, trial$candidate,
      tolerance = 64 * .Machine$double.eps))) return(FALSE)
  tolerance <- 64 * .Machine$double.eps * max(1, abs(raw$objective))
  isTRUE(candidate$objective <= raw$objective + tolerance) &&
    isTRUE(max(abs(candidate$gradient)) <= raw_gradient_gate)
}

g3_attempt_record <- function(attempt_id, family, raw, eligibility, candidate = NULL,
                              raw_signature, candidate_signature = raw_signature,
                              historical_comparator) {
  if (!is.character(attempt_id) || length(attempt_id) != 1L || !nzchar(attempt_id) ||
      !family %in% c("paper1_spatial", "paper2_nonspatial") || !is.list(raw) ||
      !is.list(eligibility) || !g3_validate_signature(raw_signature) ||
      !g3_validate_signature(candidate_signature) || !g3_validate_historical_comparator(historical_comparator, family)) {
    stop("invalid G3 all-attempt record", call. = FALSE)
  }
  if (is.null(candidate)) {
    candidate <- list(status = "NOT_ATTEMPTED", rejection_reason = eligibility$reason,
                      trials = list())
  }
  candidate_required <- c("status", "rejection_reason", "trials")
  if (!is.list(candidate) || !all(candidate_required %in% names(candidate)) ||
      !candidate$status %in% c("NOT_ATTEMPTED", "REJECTED", "ACCEPTED", "ERROR") ||
      !is.character(candidate$rejection_reason) || length(candidate$rejection_reason) != 1L ||
      !nzchar(candidate$rejection_reason) || !is.list(candidate$trials)) {
    stop("invalid G3 candidate provenance", call. = FALSE)
  }
  trial_valid <- function(x) is.list(x) && identical(names(x), c("alpha", "status", "reason")) &&
    is.numeric(x$alpha) && length(x$alpha) == 1L && x$alpha %in% g3_trial_alphas &&
    x$status %in% c("INFEASIBLE", "REJECTED", "ACCEPTED", "ERROR") &&
    is.character(x$reason) && length(x$reason) == 1L && nzchar(x$reason)
  if (!all(vapply(candidate$trials, trial_valid, logical(1L)))) stop("invalid G3 trial receipt", call. = FALSE)
  alphas <- vapply(candidate$trials, `[[`, numeric(1L), "alpha")
  if (length(alphas) && !identical(alphas, g3_trial_alphas[seq_along(alphas)])) {
    stop("G3 trials must be an ordered alpha prefix", call. = FALSE)
  }
  accepted <- identical(candidate$status, "ACCEPTED") && isTRUE(eligibility$eligible) &&
    length(candidate$trials) > 0L && identical(tail(candidate$trials, 1L)[[1L]]$status, "ACCEPTED") &&
    g3_accept(raw, candidate, raw_signature, candidate_signature)
  list(schema = "G3_FULL_VECTOR_ALL_ATTEMPT_V1", attempt_id = attempt_id, family = family,
       raw = raw, eligibility = eligibility, candidate = candidate, accepted = accepted,
       raw_signature = raw_signature, candidate_signature = candidate_signature,
       historical_comparator = historical_comparator)
}
