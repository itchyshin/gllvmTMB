## Paper 1 SPDE-slope gauge-coordinate pure contract.
##
## This file has no TMB construction, optimisation, filesystem mutation, or
## ecological-model admission logic.  It implements only the map specified in
## 2026-08-15-paper1-spde-slope-gauge-coordinate-design.md so that its algebra
## can be tested before an executable estimator is designed.

.spde_slope_gauge_fail <- function(message) {
  stop(message, call. = FALSE)
}

.spde_slope_gauge_double3 <- function(x, what) {
  if (!is.double(x) || length(x) != 3L || any(!is.finite(x))) {
    .spde_slope_gauge_fail(sprintf("%s must be a finite double vector of length 3", what))
  }
  unname(x)
}

.spde_slope_gauge_relative_error <- function(x, y) {
  if (!is.numeric(x) || !is.numeric(y) || length(x) != length(y) ||
      any(!is.finite(x)) || any(!is.finite(y))) {
    .spde_slope_gauge_fail("relative-error inputs must be finite numeric vectors of equal length")
  }
  max(abs(x - y)) / max(1, abs(x), abs(y))
}

spde_slope_gauge_raw_order <- function() {
  c(
    paste0("b_fix[", 1:12, "]"),
    paste0("theta_diag_B[", 13:15, "]"),
    "log_kappa_spde[16]",
    paste0("theta_rr_spde_slope[", 17:22, "]")
  )
}

spde_slope_gauge_phi_order <- function() {
  c(
    spde_slope_gauge_raw_order()[seq_len(19L)],
    "spde_slope_gauge_log_norm[20]",
    "spde_slope_gauge_stereo_2[21]",
    "spde_slope_gauge_stereo_3[22]"
  )
}

.spde_slope_gauge_full_vector <- function(x, order, what) {
  if (!is.double(x) || length(x) != length(order) || any(!is.finite(x)) ||
      !identical(names(x), order)) {
    .spde_slope_gauge_fail(sprintf("%s must be a finite vector with the exact gauge coordinate order", what))
  }
  x
}

spde_slope_gauge_map <- function(phi) {
  phi <- .spde_slope_gauge_double3(phi, "phi")
  eta <- phi[[1L]]
  a <- phi[[2L]]
  b <- phi[[3L]]
  scale <- sqrt(1 + a * a + b * b)
  lambda <- exp(eta) * c(1, a, b) / scale
  if (any(!is.finite(lambda)) || lambda[[1L]] <= 0) {
    .spde_slope_gauge_fail("phi does not map to a finite positive-hemisphere loading")
  }
  lambda
}

spde_slope_gauge_inverse <- function(lambda) {
  lambda <- .spde_slope_gauge_double3(lambda, "lambda")
  if (lambda[[1L]] <= 0) {
    .spde_slope_gauge_fail("lambda must be in the positive-hemisphere gauge domain")
  }
  norm_lambda <- sqrt(sum(lambda * lambda))
  phi <- c(log(norm_lambda), lambda[[2L]] / lambda[[1L]], lambda[[3L]] / lambda[[1L]])
  if (any(!is.finite(phi))) {
    .spde_slope_gauge_fail("lambda has no finite gauge inverse")
  }
  phi
}

spde_slope_gauge_jacobian <- function(phi) {
  phi <- .spde_slope_gauge_double3(phi, "phi")
  eta <- phi[[1L]]
  a <- phi[[2L]]
  b <- phi[[3L]]
  scale <- sqrt(1 + a * a + b * b)
  radius <- exp(eta)
  jacobian <- cbind(
    spde_slope_gauge_map(phi),
    radius / scale^3 * c(-a, 1 + b * b, -a * b),
    radius / scale^3 * c(-b, -a * b, 1 + a * a)
  )
  determinant <- det(jacobian)
  if (any(!is.finite(jacobian)) || !is.finite(determinant) || determinant <= 0) {
    .spde_slope_gauge_fail("phi has no finite positive-determinant gauge Jacobian")
  }
  jacobian
}

spde_slope_gauge_covariance <- function(phi) {
  lambda <- spde_slope_gauge_map(phi)
  tcrossprod(lambda)
}

spde_slope_gauge_chain_gradient <- function(phi, raw_gradient) {
  raw_gradient <- .spde_slope_gauge_double3(raw_gradient, "raw_gradient")
  drop(crossprod(spde_slope_gauge_jacobian(phi), raw_gradient))
}

spde_slope_gauge_phi_from_theta <- function(theta) {
  raw_order <- spde_slope_gauge_raw_order()
  theta <- .spde_slope_gauge_full_vector(theta, raw_order, "theta")
  phi <- c(theta[seq_len(19L)], spde_slope_gauge_inverse(unname(theta[20:22])))
  stats::setNames(as.double(phi), spde_slope_gauge_phi_order())
}

spde_slope_gauge_theta_from_phi <- function(phi) {
  phi_order <- spde_slope_gauge_phi_order()
  phi <- .spde_slope_gauge_full_vector(phi, phi_order, "phi")
  theta <- c(phi[seq_len(19L)], spde_slope_gauge_map(unname(phi[20:22])))
  stats::setNames(as.double(theta), spde_slope_gauge_raw_order())
}

spde_slope_gauge_full_jacobian <- function(phi) {
  phi <- .spde_slope_gauge_full_vector(phi, spde_slope_gauge_phi_order(), "phi")
  jacobian <- diag(22L)
  jacobian[20:22, 20:22] <- spde_slope_gauge_jacobian(unname(phi[20:22]))
  dimnames(jacobian) <- list(spde_slope_gauge_raw_order(), spde_slope_gauge_phi_order())
  jacobian
}

spde_slope_gauge_full_chain_gradient <- function(phi, raw_gradient) {
  phi <- .spde_slope_gauge_full_vector(phi, spde_slope_gauge_phi_order(), "phi")
  raw_gradient <- .spde_slope_gauge_full_vector(
    raw_gradient, spde_slope_gauge_raw_order(), "raw_gradient"
  )
  stats::setNames(
    drop(crossprod(spde_slope_gauge_full_jacobian(phi), raw_gradient)),
    spde_slope_gauge_phi_order()
  )
}

.spde_slope_gauge_scalar_double <- function(x, what) {
  if (!is.double(x) || length(x) != 1L || !is.finite(x)) {
    .spde_slope_gauge_fail(sprintf("%s must be one finite double", what))
  }
  as.double(unname(x))
}

.spde_slope_gauge_callback_gradient <- function(x) {
  order <- spde_slope_gauge_raw_order()
  if (!is.numeric(x) || length(x) != length(order) || any(!is.finite(x))) {
    .spde_slope_gauge_fail("gradient callback must return 22 finite coordinates")
  }
  if (!identical(names(x), order)) {
    .spde_slope_gauge_fail("gradient callback supplied a noncanonical positional order")
  }
  stats::setNames(as.double(x), order)
}

spde_slope_gauge_no_fit_controls <- function() {
  list(theta = 64 * .Machine$double.eps, objective = 1e-10,
    gradient = 1e-6, transformed_gradient = 1e-5)
}

.spde_slope_gauge_no_fit_controls_ok <- function(x) {
  expected <- spde_slope_gauge_no_fit_controls()
  is.list(x) && identical(x, expected)
}

spde_slope_gauge_validate_no_fit_state <- function(state, objective_fn, gradient_fn,
                                                    controls = spde_slope_gauge_no_fit_controls()) {
  fields <- c("theta", "objective", "gradient")
  if (!is.list(state) || !identical(names(state), fields) ||
      !is.function(objective_fn) || !is.function(gradient_fn) ||
      !.spde_slope_gauge_no_fit_controls_ok(controls)) {
    return(list(valid = FALSE, reason = "state_or_callback_schema_invalid"))
  }
  theta <- tryCatch(
    .spde_slope_gauge_full_vector(state$theta, spde_slope_gauge_raw_order(), "state theta"),
    error = function(e) NULL
  )
  gradient <- tryCatch(
    .spde_slope_gauge_full_vector(state$gradient, spde_slope_gauge_raw_order(), "state gradient"),
    error = function(e) NULL
  )
  objective <- tryCatch(.spde_slope_gauge_scalar_double(state$objective, "state objective"),
    error = function(e) NULL)
  if (is.null(theta) || is.null(gradient) || is.null(objective)) {
    return(list(valid = FALSE, reason = "state_coordinate_schema_invalid"))
  }
  phi <- tryCatch(spde_slope_gauge_phi_from_theta(theta), error = function(e) NULL)
  if (is.null(phi)) return(list(valid = FALSE, reason = "gauge_domain_hold"))
  raw_theta <- spde_slope_gauge_theta_from_phi(phi)
  theta_error <- .spde_slope_gauge_relative_error(raw_theta, theta)
  raw_objective <- tryCatch(.spde_slope_gauge_scalar_double(objective_fn(unname(raw_theta)), "objective callback"),
    error = function(e) NULL)
  raw_gradient <- tryCatch(.spde_slope_gauge_callback_gradient(gradient_fn(unname(raw_theta))),
    error = function(e) NULL)
  if (is.null(raw_objective) || is.null(raw_gradient)) {
    return(list(valid = FALSE, reason = "callback_unavailable"))
  }
  objective_error <- abs(raw_objective - objective) / max(1, abs(raw_objective), abs(objective))
  gradient_error <- .spde_slope_gauge_relative_error(raw_gradient, gradient)
  transformed_gradient <- spde_slope_gauge_full_chain_gradient(phi, raw_gradient)
  step <- .Machine$double.eps^(1 / 3) * pmax(1, abs(phi))
  fd_records <- tryCatch(lapply(seq_len(22L), function(j) {
    displacement <- rep(0, 22L)
    displacement[[j]] <- step[[j]]
    names(displacement) <- names(phi)
    phi_plus <- phi + displacement
    phi_minus <- phi - displacement
    theta_plus <- spde_slope_gauge_theta_from_phi(phi_plus)
    theta_minus <- spde_slope_gauge_theta_from_phi(phi_minus)
    plus <- .spde_slope_gauge_scalar_double(
      objective_fn(unname(theta_plus)), "plus objective callback"
    )
    minus <- .spde_slope_gauge_scalar_double(
      objective_fn(unname(theta_minus)), "minus objective callback"
    )
    list(index = as.integer(j), phi_id = names(phi)[[j]], h = as.double(step[[j]]),
      phi_plus = phi_plus, phi_minus = phi_minus, theta_plus = theta_plus,
      theta_minus = theta_minus, objective_plus = plus, objective_minus = minus)
  }), error = function(e) NULL)
  if (is.null(fd_records) || length(fd_records) != 22L) {
    return(list(valid = FALSE, reason = "finite_difference_callback_unavailable"))
  }
  fd_gradient <- vapply(fd_records, function(record) {
    (record$objective_plus - record$objective_minus) / (2 * record$h)
  }, numeric(1L))
  if (any(!is.finite(fd_gradient))) return(list(valid = FALSE, reason = "finite_difference_callback_unavailable"))
  names(fd_gradient) <- names(phi)
  transformed_gradient_error <- .spde_slope_gauge_relative_error(transformed_gradient, fd_gradient)
  errors <- list(
    theta = theta_error, objective = objective_error, gradient = gradient_error,
    transformed_gradient = transformed_gradient_error
  )
  valid <- theta_error <= controls$theta && objective_error <= controls$objective &&
    gradient_error <= controls$gradient && transformed_gradient_error <= controls$transformed_gradient
  list(
    valid = valid,
    reason = if (valid) "no_fit_state_valid" else "no_fit_state_replay_failed",
    phi = phi, raw_theta = raw_theta, objective = raw_objective,
    raw_gradient = raw_gradient, transformed_gradient = transformed_gradient,
    transformed_gradient_fd = fd_gradient, finite_difference = fd_records,
    controls = controls, errors = errors
  )
}

spde_slope_gauge_no_fit_evidence_ok <- function(evidence) {
  raw_order <- spde_slope_gauge_raw_order()
  phi_order <- spde_slope_gauge_phi_order()
  fields <- c(
    "valid", "reason", "phi", "raw_theta", "objective", "raw_gradient",
    "transformed_gradient", "transformed_gradient_fd", "finite_difference",
    "controls", "errors", "gradient_callback"
  )
  if (!is.list(evidence) || !identical(names(evidence), fields) ||
      !isTRUE(evidence$valid) || !identical(evidence$reason, "no_fit_state_valid") ||
      !.spde_slope_gauge_no_fit_controls_ok(evidence$controls)) return(FALSE)
  phi <- tryCatch(.spde_slope_gauge_full_vector(evidence$phi, phi_order, "no-fit phi"),
    error = function(e) NULL)
  raw_theta <- tryCatch(.spde_slope_gauge_full_vector(evidence$raw_theta, raw_order, "no-fit raw theta"),
    error = function(e) NULL)
  raw_gradient <- tryCatch(.spde_slope_gauge_full_vector(evidence$raw_gradient, raw_order, "no-fit raw gradient"),
    error = function(e) NULL)
  transformed_gradient <- tryCatch(.spde_slope_gauge_full_vector(
    evidence$transformed_gradient, phi_order, "no-fit transformed gradient"
  ), error = function(e) NULL)
  transformed_fd <- tryCatch(.spde_slope_gauge_full_vector(
    evidence$transformed_gradient_fd, phi_order, "no-fit finite-difference gradient"
  ), error = function(e) NULL)
  objective <- tryCatch(.spde_slope_gauge_scalar_double(evidence$objective, "no-fit objective"),
    error = function(e) NULL)
  if (is.null(phi) || is.null(raw_theta) || is.null(raw_gradient) ||
      is.null(transformed_gradient) || is.null(transformed_fd) || is.null(objective) ||
      !identical(raw_theta, spde_slope_gauge_theta_from_phi(phi)) ||
      !identical(transformed_gradient, spde_slope_gauge_full_chain_gradient(phi, raw_gradient))) return(FALSE)
  expected_h <- .Machine$double.eps^(1 / 3) * pmax(1, abs(phi))
  records <- evidence$finite_difference
  if (!is.list(records) || length(records) != 22L) return(FALSE)
  valid_records <- vapply(seq_len(22L), function(index) {
    record <- records[[index]]
    expected_fields <- c(
      "index", "phi_id", "h", "phi_plus", "phi_minus", "theta_plus", "theta_minus",
      "objective_plus", "objective_minus"
    )
    displacement <- rep(0, 22L)
    displacement[[index]] <- expected_h[[index]]
    names(displacement) <- phi_order
    is.list(record) && identical(names(record), expected_fields) &&
      identical(record$index, as.integer(index)) && identical(record$phi_id, phi_order[[index]]) &&
      is.double(record$h) && length(record$h) == 1L && identical(record$h, as.double(expected_h[[index]])) &&
      identical(record$phi_plus, phi + displacement) && identical(record$phi_minus, phi - displacement) &&
      identical(record$theta_plus, spde_slope_gauge_theta_from_phi(phi + displacement)) &&
      identical(record$theta_minus, spde_slope_gauge_theta_from_phi(phi - displacement)) &&
      !is.null(tryCatch(.spde_slope_gauge_scalar_double(record$objective_plus, "no-fit plus objective"), error = function(e) NULL)) &&
      !is.null(tryCatch(.spde_slope_gauge_scalar_double(record$objective_minus, "no-fit minus objective"), error = function(e) NULL))
  }, logical(1L))
  if (!all(valid_records)) return(FALSE)
  fd_gradient <- vapply(records, function(record) {
    (record$objective_plus - record$objective_minus) / (2 * record$h)
  }, numeric(1L))
  names(fd_gradient) <- phi_order
  transformed_gradient_error <- .spde_slope_gauge_relative_error(transformed_gradient, fd_gradient)
  errors <- evidence$errors
  callback <- evidence$gradient_callback
  mapping_fields <- c("supplied_names", "object_order", "parameter_order", "block_labels", "raw_order")
  block_labels <- c(rep("b_fix", 12L), rep("theta_diag_B", 3L), "log_kappa_spde",
    rep("theta_rr_spde_slope", 6L))
  callback_ok <- is.list(callback) && identical(names(callback), c(
    "supplied_names", "raw_values", "named_gradient", "mapping"
  )) && (is.null(callback$supplied_names) || identical(callback$supplied_names, raw_order)) &&
    is.double(callback$raw_values) && length(callback$raw_values) == 22L &&
    identical(callback$named_gradient, raw_gradient) &&
    identical(callback$raw_values, as.double(unname(raw_gradient))) &&
    is.list(callback$mapping) && identical(names(callback$mapping), mapping_fields) &&
    identical(callback$mapping$object_order, block_labels) &&
    identical(callback$mapping$parameter_order, raw_order) &&
    identical(callback$mapping$block_labels, block_labels) &&
    identical(callback$mapping$raw_order, raw_order) &&
    (is.null(callback$mapping$supplied_names) || identical(callback$mapping$supplied_names, raw_order) ||
      identical(callback$mapping$supplied_names, block_labels))
  errors_ok <- is.list(errors) && identical(names(errors), c(
    "theta", "objective", "gradient", "transformed_gradient"
  )) && all(vapply(errors, function(x) is.double(x) && length(x) == 1L && is.finite(x), logical(1L))) &&
    errors$theta <= evidence$controls$theta && errors$objective <= evidence$controls$objective &&
    errors$gradient <= evidence$controls$gradient &&
    errors$transformed_gradient <= evidence$controls$transformed_gradient &&
    abs(errors$transformed_gradient - transformed_gradient_error) <=
      64 * .Machine$double.eps * max(1, abs(errors$transformed_gradient), abs(transformed_gradient_error)) &&
    .spde_slope_gauge_relative_error(transformed_fd, fd_gradient) <= 64 * .Machine$double.eps
  isTRUE(callback_ok) && isTRUE(errors_ok)
}
