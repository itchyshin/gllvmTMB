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
