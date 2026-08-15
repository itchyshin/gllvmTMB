## Pure contract for PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1.
##
## This is deliberately callback-only: it builds no TMB object, writes no
## root, and calls no optimiser.  The future worker supplies one already
## provenance-bound marginal-Laplace callback object.

.spde_slope_gauge_tr_fail <- function(message) {
  stop(message, call. = FALSE)
}

spde_slope_gauge_trust_region_controls <- function() {
  list(
    hessian_step = 1e-4,
    hessian_scales = c(0.5, 1, 2),
    hessian_antisymmetry = 1e-6,
    hessian_agreement = 1e-5,
    shift_count = 6L,
    shift_floor = 1e-8,
    radii = c(0.5, 0.25, 0.125, 0.0625),
    prediction_slack = 64 * .Machine$double.eps,
    rho = 0.1,
    raw_gradient = 1e-3,
    covariance_symmetry = 1e-10,
    covariance_condition = 1e8
  )
}

.spde_slope_gauge_tr_controls_ok <- function(x) {
  identical(x, spde_slope_gauge_trust_region_controls())
}

.spde_slope_gauge_tr_relative_error <- function(x, y) {
  if (!is.numeric(x) || !is.numeric(y) || length(x) != length(y) ||
      any(!is.finite(x)) || any(!is.finite(y))) {
    .spde_slope_gauge_tr_fail("relative-error inputs must be finite numeric vectors of equal length")
  }
  numerator <- sqrt(sum((as.double(x) - as.double(y))^2))
  denominator <- max(sqrt(sum(as.double(x)^2)), sqrt(.Machine$double.eps))
  numerator / denominator
}

.spde_slope_gauge_tr_scalar <- function(x, what) {
  if (!is.double(x) || length(x) != 1L || !is.finite(x)) {
    .spde_slope_gauge_tr_fail(sprintf("%s must be one finite double", what))
  }
  as.double(unname(x))
}

.spde_slope_gauge_tr_phi <- function(phi, what = "phi") {
  .spde_slope_gauge_full_vector(phi, spde_slope_gauge_phi_order(), what)
}

.spde_slope_gauge_tr_raw <- function(theta, what = "raw theta") {
  .spde_slope_gauge_full_vector(theta, spde_slope_gauge_raw_order(), what)
}

.spde_slope_gauge_tr_evaluation_ok <- function(x, phi) {
  fields <- c("objective", "raw_theta", "raw_gradient")
  if (!is.list(x) || !identical(names(x), fields)) return(FALSE)
  raw_theta <- tryCatch(.spde_slope_gauge_tr_raw(x$raw_theta), error = function(e) NULL)
  raw_gradient <- tryCatch(.spde_slope_gauge_tr_raw(x$raw_gradient, "raw gradient"), error = function(e) NULL)
  objective <- tryCatch(.spde_slope_gauge_tr_scalar(x$objective, "objective"), error = function(e) NULL)
  expected_theta <- tryCatch(spde_slope_gauge_theta_from_phi(phi), error = function(e) NULL)
  if (is.null(raw_theta) || is.null(raw_gradient) || is.null(objective) || is.null(expected_theta) ||
      !identical(raw_theta, expected_theta)) return(FALSE)
  transformed_gradient <- tryCatch(spde_slope_gauge_full_chain_gradient(phi, raw_gradient),
    error = function(e) NULL)
  !is.null(transformed_gradient) && all(is.finite(transformed_gradient))
}

.spde_slope_gauge_tr_evaluate <- function(evaluate_fn, phi) {
  result <- tryCatch(evaluate_fn(phi), error = function(e) list(error = conditionMessage(e)))
  if (!.spde_slope_gauge_tr_evaluation_ok(result, phi)) return(NULL)
  list(
    objective = .spde_slope_gauge_tr_scalar(result$objective, "objective"),
    raw_theta = result$raw_theta,
    raw_gradient = result$raw_gradient,
    gradient = spde_slope_gauge_full_chain_gradient(phi, result$raw_gradient)
  )
}

.spde_slope_gauge_tr_hessian <- function(phi0, evaluate_fn, controls) {
  scale_diag <- pmax(1, abs(phi0))
  base <- .spde_slope_gauge_tr_evaluate(evaluate_fn, phi0)
  if (is.null(base)) return(list(valid = FALSE, reason = "start_callback_unavailable"))
  records <- vector("list", length(controls$hessian_scales) * 22L * 2L)
  models <- vector("list", length(controls$hessian_scales))
  record_index <- 0L
  for (scale_index in seq_along(controls$hessian_scales)) {
    scale <- controls$hessian_scales[[scale_index]]
    hessian <- matrix(NA_real_, 22L, 22L,
      dimnames = list(spde_slope_gauge_phi_order(), spde_slope_gauge_phi_order()))
    for (coordinate in seq_len(22L)) {
      h <- scale * controls$hessian_step
      displacement <- rep(0, 22L)
      displacement[[coordinate]] <- h
      names(displacement) <- spde_slope_gauge_phi_order()
      minus_phi <- phi0 - scale_diag * displacement
      plus_phi <- phi0 + scale_diag * displacement
      minus <- .spde_slope_gauge_tr_evaluate(evaluate_fn, minus_phi)
      plus <- .spde_slope_gauge_tr_evaluate(evaluate_fn, plus_phi)
      record_index <- record_index + 1L
      records[[record_index]] <- list(scale_index = as.integer(scale_index), scale = as.double(scale),
        coordinate = as.integer(coordinate), side = "minus", h = as.double(h), phi = minus_phi,
        evaluation = minus)
      record_index <- record_index + 1L
      records[[record_index]] <- list(scale_index = as.integer(scale_index), scale = as.double(scale),
        coordinate = as.integer(coordinate), side = "plus", h = as.double(h), phi = plus_phi,
        evaluation = plus)
      if (is.null(minus) || is.null(plus)) {
        return(list(valid = FALSE, reason = "hessian_gradient_callback_unavailable", base = base,
          records = records[seq_len(record_index)]))
      }
      hessian[, coordinate] <- (plus$gradient - minus$gradient) /
        (2 * h * scale_diag[[coordinate]])
    }
    antisymmetry <- .spde_slope_gauge_tr_relative_error(hessian, t(hessian))
    hsym <- (hessian + t(hessian)) / 2
    eigenvalue <- tryCatch(eigen(hsym, symmetric = TRUE, only.values = TRUE)$values,
      error = function(e) NULL)
    if (is.null(eigenvalue) || any(!is.finite(eigenvalue))) {
      return(list(valid = FALSE, reason = "hessian_eigendecomposition_unavailable", base = base,
        records = records[seq_len(record_index)]))
    }
    models[[scale_index]] <- list(scale = as.double(scale), hessian = hessian, hsym = hsym,
      antisymmetry = antisymmetry, eigenvalues = eigenvalue)
  }
  default <- models[[2L]]
  matrix_error <- vapply(c(1L, 3L), function(index) {
    .spde_slope_gauge_tr_relative_error(models[[index]]$hsym, default$hsym)
  }, numeric(1L))
  eigen_error <- vapply(c(1L, 3L), function(index) {
    .spde_slope_gauge_tr_relative_error(models[[index]]$eigenvalues, default$eigenvalues)
  }, numeric(1L))
  stable <- all(vapply(models, function(model) {
    is.finite(model$antisymmetry) && model$antisymmetry <= controls$hessian_antisymmetry
  }, logical(1L))) && all(matrix_error <= controls$hessian_agreement) &&
    all(eigen_error <= controls$hessian_agreement)
  list(valid = stable, reason = if (stable) "hessian_stability_valid" else "hessian_stability_failed",
    base = base, records = records, models = models, hessian = default$hsym,
    matrix_error = matrix_error, eigen_error = eigen_error, scale_diagonal = scale_diag)
}

.spde_slope_gauge_tr_covariance <- function(x, expected_theta, controls) {
  fields <- c("par.fixed", "cov.fixed", "pdHess")
  raw_order <- spde_slope_gauge_raw_order()
  if (!is.list(x) || !identical(names(x), fields)) {
    return(list(valid = FALSE, reason = "candidate_covariance_schema_or_finiteness_failed"))
  }
  par_fixed <- tryCatch(.spde_slope_gauge_tr_raw(x$par.fixed, "candidate par.fixed"),
    error = function(e) NULL)
  expected_theta <- tryCatch(.spde_slope_gauge_tr_raw(expected_theta, "candidate raw theta"),
    error = function(e) NULL)
  if (!isTRUE(x$pdHess) ||
      is.null(par_fixed) || is.null(expected_theta) ||
      .spde_slope_gauge_tr_relative_error(par_fixed, expected_theta) > 64 * .Machine$double.eps ||
      !is.double(x$cov.fixed) ||
      !identical(dim(x$cov.fixed), c(22L, 22L)) ||
      !(
        (is.null(rownames(x$cov.fixed)) && is.null(colnames(x$cov.fixed))) ||
          (identical(rownames(x$cov.fixed), raw_order) &&
            identical(colnames(x$cov.fixed), raw_order))
      ) || any(!is.finite(x$cov.fixed))) {
    return(list(valid = FALSE, reason = "candidate_covariance_schema_or_finiteness_failed"))
  }
  raw_row_names <- rownames(x$cov.fixed)
  raw_column_names <- colnames(x$cov.fixed)
  covariance <- x$cov.fixed
  if (is.null(raw_row_names)) dimnames(covariance) <- list(raw_order, raw_order)
  asymmetry <- .spde_slope_gauge_tr_relative_error(covariance, t(covariance))
  if (asymmetry > controls$covariance_symmetry) {
    return(list(valid = FALSE, reason = "candidate_covariance_asymmetry_failed", asymmetry = asymmetry))
  }
  vsym <- (covariance + t(covariance)) / 2
  cholesky <- tryCatch(chol(vsym), error = function(e) NULL)
  eigenvalue <- tryCatch(eigen(vsym, symmetric = TRUE, only.values = TRUE)$values,
    error = function(e) NULL)
  if (is.null(cholesky) || is.null(eigenvalue) || any(!is.finite(eigenvalue)) || any(eigenvalue <= 0)) {
    return(list(valid = FALSE, reason = "candidate_covariance_not_positive_definite", asymmetry = asymmetry))
  }
  condition <- max(eigenvalue) / min(eigenvalue)
  list(valid = is.finite(condition) && condition <= controls$covariance_condition,
    reason = if (is.finite(condition) && condition <= controls$covariance_condition)
      "candidate_covariance_valid" else "candidate_covariance_condition_failed",
    asymmetry = asymmetry, raw_row_names = raw_row_names, raw_column_names = raw_column_names,
    covariance = vsym, eigenvalues = eigenvalue, condition = condition)
}

spde_slope_gauge_trust_region <- function(phi0, evaluate_fn, covariance_fn,
                                          controls = spde_slope_gauge_trust_region_controls()) {
  phi0 <- tryCatch(.spde_slope_gauge_tr_phi(phi0, "phi0"), error = function(e) NULL)
  if (is.null(phi0) || !is.function(evaluate_fn) || !is.function(covariance_fn) ||
      !.spde_slope_gauge_tr_controls_ok(controls)) {
    return(list(status = "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD", reason = "input_schema_invalid"))
  }
  hessian <- .spde_slope_gauge_tr_hessian(phi0, evaluate_fn, controls)
  if (!isTRUE(hessian$valid)) {
    return(list(status = if (identical(hessian$reason, "hessian_stability_failed"))
      "GAUGE_TRUST_REGION_CURVATURE_VALIDATION_HOLD" else "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD",
    reason = hessian$reason, hessian = hessian))
  }
  h <- hessian$hessian
  gradient_z <- hessian$scale_diagonal * hessian$base$gradient
  h_z <- diag(hessian$scale_diagonal, 22L) %*% h %*% diag(hessian$scale_diagonal, 22L)
  spectrum <- eigen(h_z, symmetric = TRUE, only.values = TRUE)$values
  scale <- max(1, max(abs(spectrum)))
  shift0 <- max(controls$shift_floor * scale, -min(spectrum) + controls$shift_floor * scale)
  trials <- vector("list", controls$shift_count * length(controls$radii))
  trial_index <- 0L
  for (shift_index in seq_len(controls$shift_count)) {
    shift <- shift0 * 2^(shift_index - 1L)
    shifted <- h_z + diag(shift, 22L)
    direction <- tryCatch(solve(shifted, -gradient_z), error = function(e) NULL)
    for (radius_index in seq_along(controls$radii)) {
      trial_index <- trial_index + 1L
      radius <- controls$radii[[radius_index]]
      if (is.null(direction) || any(!is.finite(direction)) || is.null(tryCatch(chol(shifted), error = function(e) NULL))) {
        trials[[trial_index]] <- list(index = as.integer(trial_index), shift_index = as.integer(shift_index),
          radius_index = as.integer(radius_index), shift = as.double(shift), radius = as.double(radius),
          step_z = NULL, phi = NULL, evaluation = NULL, covariance = NULL,
          accepted = FALSE, reason = "shifted_system_unavailable")
        next
      }
      step_z <- drop(direction) * min(1, radius / sqrt(sum(direction * direction)))
      phi <- phi0 + hessian$scale_diagonal * step_z
      raw_theta <- tryCatch(spde_slope_gauge_theta_from_phi(phi), error = function(e) NULL)
      if (is.null(raw_theta)) {
        trials[[trial_index]] <- list(index = as.integer(trial_index), shift_index = as.integer(shift_index),
          radius_index = as.integer(radius_index), shift = as.double(shift), radius = as.double(radius),
          step_z = stats::setNames(as.double(step_z), spde_slope_gauge_phi_order()), phi = phi,
          evaluation = NULL, covariance = NULL, accepted = FALSE, reason = "gauge_domain_rejection")
        next
      }
      evaluation <- .spde_slope_gauge_tr_evaluate(evaluate_fn, phi)
      if (is.null(evaluation)) {
        trials[[trial_index]] <- list(index = as.integer(trial_index), shift_index = as.integer(shift_index),
          radius_index = as.integer(radius_index), shift = as.double(shift), radius = as.double(radius),
          step_z = stats::setNames(as.double(step_z), spde_slope_gauge_phi_order()), phi = phi,
          evaluation = NULL, covariance = NULL, accepted = FALSE, reason = "trial_callback_unavailable")
        return(list(status = "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD", reason = "trial_callback_unavailable",
          hessian = hessian, trials = trials[seq_len(trial_index)]))
      }
      prediction <- -sum(gradient_z * step_z) - 0.5 * drop(crossprod(step_z, h_z %*% step_z))
      actual <- hessian$base$objective - evaluation$objective
      rho <- actual / prediction
      objective_ok <- is.finite(prediction) && is.finite(actual) && is.finite(rho) && prediction > 0 &&
        evaluation$objective <= hessian$base$objective + controls$prediction_slack *
          max(1, abs(hessian$base$objective)) && rho >= controls$rho &&
        max(abs(evaluation$raw_gradient)) <= controls$raw_gradient
      covariance <- NULL
      if (objective_ok) {
        covariance <- tryCatch(covariance_fn(evaluation$raw_theta), error = function(e) NULL)
        if (is.null(covariance)) {
          trials[[trial_index]] <- list(index = as.integer(trial_index), shift_index = as.integer(shift_index),
            radius_index = as.integer(radius_index), shift = as.double(shift), radius = as.double(radius),
            step_z = stats::setNames(as.double(step_z), spde_slope_gauge_phi_order()), phi = phi,
            evaluation = evaluation, prediction = as.double(prediction), actual = as.double(actual),
            rho = as.double(rho), objective_ok = TRUE, covariance = NULL, accepted = FALSE,
            reason = "candidate_covariance_callback_unavailable")
          return(list(status = "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD", reason = "candidate_covariance_callback_unavailable",
            hessian = hessian, trials = trials[seq_len(trial_index)]))
        }
        covariance <- .spde_slope_gauge_tr_covariance(covariance, evaluation$raw_theta, controls)
      }
      trials[[trial_index]] <- list(index = as.integer(trial_index), shift_index = as.integer(shift_index),
        radius_index = as.integer(radius_index), shift = as.double(shift), radius = as.double(radius),
        step_z = stats::setNames(as.double(step_z), spde_slope_gauge_phi_order()), phi = phi,
        evaluation = evaluation, prediction = as.double(prediction), actual = as.double(actual), rho = as.double(rho),
        objective_ok = objective_ok, covariance = covariance,
        accepted = isTRUE(objective_ok) && isTRUE(covariance$valid),
        reason = if (!objective_ok) "objective_or_gradient_gate_failed" else covariance$reason)
    }
  }
  accepted <- which(vapply(trials, `[[`, logical(1L), "accepted"))
  if (!length(accepted)) return(list(status = "GAUGE_TRUST_REGION_NO_ADMISSIBLE_CANDIDATE",
    reason = "no_trial_passed_all_gates", hessian = hessian, trials = trials, selected = NULL))
  actual <- vapply(trials[accepted], `[[`, numeric(1L), "actual")
  maximum_actual <- max(actual)
  tie_slack <- controls$prediction_slack * max(1, abs(hessian$base$objective))
  best <- accepted[[which(actual >= maximum_actual - tie_slack)[[1L]]]]
  list(status = "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION", reason = "selected_candidate_passed_all_gates",
    hessian = hessian, trials = trials, selected = trials[[best]])
}

.spde_slope_gauge_tr_audit_common_ok <- function(record, fields, call_index, object_id, dll_path, dll_md5) {
  .spde_slope_gauge_tr_smoke_exact_names <- function(x, names) {
    is.list(x) && identical(names(x), names)
  }
  .spde_slope_gauge_tr_smoke_exact_names(
    record, c(fields, "call_index", "object_id", "dll_path", "dll_md5")
  ) && is.integer(record$call_index) && length(record$call_index) == 1L &&
    identical(record$call_index, call_index) && is.integer(record$object_id) &&
    length(record$object_id) == 1L && identical(record$object_id, object_id) &&
    is.character(record$dll_path) && length(record$dll_path) == 1L &&
    identical(record$dll_path, dll_path) && is.character(record$dll_md5) &&
    length(record$dll_md5) == 1L && identical(record$dll_md5, dll_md5)
}

spde_slope_gauge_trust_region_callbacks_from_audit <- function(
  audit,
  object_id,
  dll_path,
  dll_md5
) {
  fields <- c("object_id", "dll_path", "dll_md5", "objective", "gradient", "covariance")
  raw_order <- spde_slope_gauge_raw_order()
  if (!is.list(audit) || !identical(names(audit), fields) ||
      !is.integer(object_id) || length(object_id) != 1L || object_id <= 0L ||
      !is.character(dll_path) || length(dll_path) != 1L || !nzchar(dll_path) ||
      !is.character(dll_md5) || length(dll_md5) != 1L || !grepl("^[[:xdigit:]]{32}$", dll_md5) ||
      !identical(audit$object_id, object_id) || !identical(audit$dll_path, dll_path) ||
      !identical(audit$dll_md5, dll_md5) || !is.list(audit$objective) ||
      !is.list(audit$gradient) || !is.list(audit$covariance)) {
    return(NULL)
  }
  objective_index <- 0L
  gradient_index <- 0L
  covariance_index <- 0L
  call_index <- 0L
  evaluate <- function(phi) {
    objective_index <<- objective_index + 1L
    gradient_index <<- gradient_index + 1L
    objective <- audit$objective[[objective_index]]
    gradient <- audit$gradient[[gradient_index]]
    theta <- tryCatch(spde_slope_gauge_theta_from_phi(phi), error = function(e) NULL)
    if (is.null(theta) || is.null(objective) || is.null(gradient) ||
        !.spde_slope_gauge_tr_audit_common_ok(
          objective, c("raw_theta", "value"), as.integer(call_index + 1L), object_id, dll_path, dll_md5
        ) || !.spde_slope_gauge_tr_audit_common_ok(
          gradient, c("raw_theta", "supplied_names", "raw_values", "named_gradient"),
          as.integer(call_index + 2L), object_id, dll_path, dll_md5
        ) || !identical(objective$raw_theta, theta) || !identical(gradient$raw_theta, theta) ||
        !is.double(objective$value) || length(objective$value) != 1L || !is.finite(objective$value) ||
        !(is.null(gradient$supplied_names) || identical(gradient$supplied_names, raw_order)) ||
        !is.double(gradient$raw_values) || length(gradient$raw_values) != length(raw_order) ||
        any(!is.finite(gradient$raw_values)) || !is.double(gradient$named_gradient) ||
        !identical(names(gradient$named_gradient), raw_order) ||
        !identical(unname(gradient$named_gradient), gradient$raw_values)) {
      .spde_slope_gauge_tr_fail("retained callback audit cannot supply the requested evaluation")
    }
    call_index <<- call_index + 2L
    list(
      objective = objective$value,
      raw_theta = theta,
      raw_gradient = gradient$named_gradient
    )
  }
  covariance <- function(theta) {
    covariance_index <<- covariance_index + 1L
    record <- audit$covariance[[covariance_index]]
    if (is.null(record) || !.spde_slope_gauge_tr_audit_common_ok(
      record, c("raw_theta", "result"), as.integer(call_index + 1L), object_id, dll_path, dll_md5
    ) || !identical(record$raw_theta, theta)) {
      .spde_slope_gauge_tr_fail("retained callback audit cannot supply the requested covariance")
    }
    call_index <<- call_index + 1L
    record$result
  }
  list(
    evaluate = evaluate,
    covariance = covariance,
    complete = function() {
      identical(objective_index, length(audit$objective)) &&
        identical(gradient_index, length(audit$gradient)) &&
        identical(covariance_index, length(audit$covariance)) &&
        identical(call_index, length(audit$objective) + length(audit$gradient) + length(audit$covariance))
    }
  )
}

spde_slope_gauge_trust_region_validate_result <- function(
  result,
  phi0,
  evaluate_fn,
  covariance_fn,
  controls = spde_slope_gauge_trust_region_controls()
) {
  recomputed <- spde_slope_gauge_trust_region(
    phi0 = phi0,
    evaluate_fn = evaluate_fn,
    covariance_fn = covariance_fn,
    controls = controls
  )
  if (!identical(result, recomputed)) {
    return(list(valid = FALSE, reason = "terminal_evidence_recomputation_failed"))
  }
  list(valid = TRUE, reason = "trust_region_result_recomputed", status = recomputed$status)
}
