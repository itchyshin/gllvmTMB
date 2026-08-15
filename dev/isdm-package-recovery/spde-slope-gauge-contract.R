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
  unname(x)
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
