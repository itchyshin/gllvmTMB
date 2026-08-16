## Full random-effect sign-orbit contract for the SPDE-slope gauge chart.
##
## The worker supplies TMB's full parameter vector, random indices, sparse
## conditional Hessian, report callback, and marginal fixed-parameter callback.
## This file has no TMB construction or filesystem effects.

.spde_slope_gauge_sign_fail <- function(message) {
  stop(message, call. = FALSE)
}

.spde_slope_gauge_sign_relative_error <- function(x, y) {
  if (!is.numeric(x) || !is.numeric(y) || length(x) != length(y) ||
      any(!is.finite(x)) || any(!is.finite(y))) {
    .spde_slope_gauge_sign_fail("sign-orbit comparison inputs must be finite and conformable")
  }
  max(abs(x - y)) / max(1, abs(x), abs(y))
}

spde_slope_gauge_sign_descriptor <- function(parameters, random, full, random_indices, theta) {
  raw_order <- spde_slope_gauge_raw_order()
  if (!is.list(parameters) || !is.double(parameters$g_spde_slope) ||
      !identical(random, c("s_B", "g_spde_slope")) || !is.double(full) ||
      is.null(names(full)) || !is.integer(random_indices) ||
      any(random_indices < 1L) || any(random_indices > length(full)) ||
      anyDuplicated(random_indices) || !is.double(theta) || !identical(names(theta), raw_order)) {
    .spde_slope_gauge_sign_fail("sign-orbit state or full-parameter schema is invalid")
  }
  dimensions <- dim(parameters$g_spde_slope)
  if (length(dimensions) != 3L || dimensions[[2L]] != 1L || dimensions[[3L]] != 2L ||
      any(dimensions < 1L)) {
    .spde_slope_gauge_sign_fail("g_spde_slope must have one latent rank and two LHS columns")
  }
  fixed_index <- which(names(full) == "theta_rr_spde_slope")
  random_names <- names(full)[random_indices]
  g_index <- which(random_names == "g_spde_slope")
  if (length(fixed_index) != 6L || length(g_index) != prod(dimensions) ||
      !all(random_names[-g_index] == "s_B")) {
    .spde_slope_gauge_sign_fail("full-parameter packing does not match the sealed SPDE slope layout")
  }
  loading_error <- .spde_slope_gauge_sign_relative_error(full[fixed_index], theta[17:22])
  if (loading_error > 64 * .Machine$double.eps || theta[[20L]] <= 0) {
    .spde_slope_gauge_sign_fail("full fixed loading block does not equal the positive sealed raw state")
  }
  field_size <- dimensions[[1L]] * dimensions[[2L]]
  gbif_in_random <- g_index[field_size + seq_len(field_size)]
  random_sign <- rep(1, length(random_indices))
  random_sign[gbif_in_random] <- -1
  signed_full <- full
  signed_full[fixed_index[4:6]] <- -signed_full[fixed_index[4:6]]
  signed_full[random_indices[gbif_in_random]] <- -signed_full[random_indices[gbif_in_random]]
  signed_theta <- theta
  signed_theta[20:22] <- -signed_theta[20:22]
  list(
    fixed_index = fixed_index,
    gbif_random_index = random_indices[gbif_in_random],
    random_sign = random_sign,
    signed_full = signed_full,
    signed_theta = signed_theta,
    dimensions = dimensions
  )
}

spde_slope_gauge_validate_sign_orbit <- function(
  parameters,
  random,
  full,
  random_indices,
  theta,
  conditional_hessian_fn,
  report_fn,
  marginal_objective_fn,
  objective_tolerance = 1e-10,
  predictor_tolerance = 1e-10
) {
  if (!is.function(conditional_hessian_fn) || !is.function(report_fn) ||
      !is.function(marginal_objective_fn) ||
      !identical(objective_tolerance, 1e-10) || !identical(predictor_tolerance, 1e-10)) {
    return(list(valid = FALSE, reason = "sign_orbit_callback_or_control_invalid"))
  }
  descriptor <- tryCatch(
    spde_slope_gauge_sign_descriptor(parameters, random, full, random_indices, theta),
    error = function(e) NULL
  )
  if (is.null(descriptor)) return(list(valid = FALSE, reason = "sign_orbit_state_invalid"))
  q <- tryCatch(as.matrix(conditional_hessian_fn(full)), error = function(e) NULL)
  signed_q <- tryCatch(as.matrix(conditional_hessian_fn(descriptor$signed_full)), error = function(e) NULL)
  expected_dim <- c(length(random_indices), length(random_indices))
  if (is.null(q) || is.null(signed_q) || !is.double(q) || !is.double(signed_q) ||
      !identical(dim(q), expected_dim) || !identical(dim(signed_q), expected_dim) ||
      any(!is.finite(q)) || any(!is.finite(signed_q))) {
    return(list(valid = FALSE, reason = "sign_orbit_conditional_hessian_invalid", descriptor = descriptor))
  }
  transformed_q <- sweep(sweep(q, 1L, descriptor$random_sign, `*`), 2L, descriptor$random_sign, `*`)
  q_error <- .spde_slope_gauge_sign_relative_error(signed_q, transformed_q)
  report <- tryCatch(report_fn(full), error = function(e) NULL)
  signed_report <- tryCatch(report_fn(descriptor$signed_full), error = function(e) NULL)
  eta <- if (is.list(report)) report$eta else NULL
  signed_eta <- if (is.list(signed_report)) signed_report$eta else NULL
  predictor_error <- tryCatch(.spde_slope_gauge_sign_relative_error(eta, signed_eta),
    error = function(e) Inf)
  objective <- tryCatch(as.double(unname(marginal_objective_fn(unname(theta)))), error = function(e) NA_real_)
  signed_objective <- tryCatch(as.double(unname(marginal_objective_fn(unname(descriptor$signed_theta)))),
    error = function(e) NA_real_)
  objective_error <- tryCatch(.spde_slope_gauge_sign_relative_error(objective, signed_objective),
    error = function(e) Inf)
  valid <- is.finite(q_error) && q_error <= objective_tolerance &&
    is.finite(predictor_error) && predictor_error <= predictor_tolerance &&
    is.finite(objective_error) && objective_error <= objective_tolerance
  list(
    valid = valid,
    reason = if (valid) "sign_orbit_valid" else "sign_orbit_invariance_failed",
    descriptor = descriptor,
    conditional_hessian_error = q_error,
    conditional_hessian = q,
    signed_conditional_hessian = signed_q,
    predictor_error = predictor_error,
    objective_error = objective_error,
    eta = eta,
    signed_eta = signed_eta,
    objective = objective,
    signed_objective = signed_objective
  )
}
