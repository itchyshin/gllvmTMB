## Paper 1 range--amplitude orthogonal-chart pure contract.
##
## This file deliberately contains no TMB construction, optimisation,
## filesystem mutation, or numerical-admission logic.

.rao_fail <- function(message) stop(message, call. = FALSE)

.rao_full_vector <- function(x, order, what) {
  if (!is.double(x) || length(x) != length(order) || any(!is.finite(x)) ||
      !identical(names(x), order)) {
    .rao_fail(sprintf("%s must be a finite double vector in exact coordinate order", what))
  }
  x
}

rao_raw_order <- function() {
  c(
    paste0("b_fix[", 1:12, "]"),
    paste0("theta_diag_B[", 13:15, "]"),
    "log_kappa_spde[16]",
    paste0("theta_rr_spde_slope[", 17:22, "]")
  )
}

rao_phi_order <- function() {
  c(
    rao_raw_order()[1:15],
    "spde_slope_range_amplitude_u[16]",
    rao_raw_order()[17:19],
    "spde_slope_range_amplitude_v[20]",
    "spde_slope_bias_ratio_2[21]",
    "spde_slope_bias_ratio_3[22]"
  )
}

.rao_local_map <- function(local_phi) {
  if (!is.double(local_phi) || length(local_phi) != 4L || any(!is.finite(local_phi))) {
    .rao_fail("local chart coordinates must be four finite doubles")
  }
  u <- local_phi[[1L]]
  v <- local_phi[[2L]]
  a <- local_phi[[3L]]
  b <- local_phi[[4L]]
  root_two <- sqrt(2)
  q <- (u + v) / root_two
  eta <- (u - v) / root_two
  amplitude <- exp(eta)
  lambda <- amplitude * c(1, a, b)
  raw <- c(q, lambda)
  if (any(!is.finite(raw)) || raw[[2L]] <= 0) {
    .rao_fail("local chart maps outside the finite positive-loading domain")
  }
  raw
}

.rao_local_inverse <- function(local_raw) {
  if (!is.double(local_raw) || length(local_raw) != 4L || any(!is.finite(local_raw))) {
    .rao_fail("local raw coordinates must be four finite doubles")
  }
  q <- local_raw[[1L]]
  lambda <- local_raw[2:4]
  if (lambda[[1L]] <= 0) {
    .rao_fail("first GBIF loading must be positive in the orthogonal-chart domain")
  }
  eta <- log(lambda[[1L]])
  root_two <- sqrt(2)
  phi <- c(
    (q + eta) / root_two,
    (q - eta) / root_two,
    lambda[[2L]] / lambda[[1L]],
    lambda[[3L]] / lambda[[1L]]
  )
  if (any(!is.finite(phi))) .rao_fail("local raw coordinates have no finite chart inverse")
  phi
}

rao_phi_from_theta <- function(theta) {
  theta <- .rao_full_vector(theta, rao_raw_order(), "theta")
  local <- .rao_local_inverse(unname(theta[c(16L, 20:22)]))
  phi <- c(theta[1:15], local[[1L]], theta[17:19], local[2:4])
  stats::setNames(as.double(phi), rao_phi_order())
}

rao_theta_from_phi <- function(phi) {
  phi <- .rao_full_vector(phi, rao_phi_order(), "phi")
  local <- .rao_local_map(unname(phi[c(16L, 20:22)]))
  theta <- c(phi[1:15], local[[1L]], phi[17:19], local[2:4])
  stats::setNames(as.double(theta), rao_raw_order())
}

rao_full_jacobian <- function(phi) {
  phi <- .rao_full_vector(phi, rao_phi_order(), "phi")
  local_raw <- .rao_local_map(unname(phi[c(16L, 20:22)]))
  lambda <- local_raw[2:4]
  amplitude <- lambda[[1L]]
  root_two <- sqrt(2)
  jacobian <- matrix(0, nrow = 22L, ncol = 22L)
  jacobian[c(1:15, 17:19), c(1:15, 17:19)] <- diag(18L)
  jacobian[16L, c(16L, 20L)] <- 1 / root_two
  jacobian[20:22, 16L] <- lambda / root_two
  jacobian[20:22, 20L] <- -lambda / root_two
  jacobian[20:22, 21L] <- c(0, amplitude, 0)
  jacobian[20:22, 22L] <- c(0, 0, amplitude)
  dimnames(jacobian) <- list(rao_raw_order(), rao_phi_order())
  if (any(!is.finite(jacobian))) .rao_fail("orthogonal-chart Jacobian is non-finite")
  jacobian
}

rao_full_chain_gradient <- function(phi, raw_gradient) {
  phi <- .rao_full_vector(phi, rao_phi_order(), "phi")
  raw_gradient <- .rao_full_vector(raw_gradient, rao_raw_order(), "raw_gradient")
  stats::setNames(
    drop(crossprod(rao_full_jacobian(phi), raw_gradient)),
    rao_phi_order()
  )
}

# rao_relative_error is a WHOLE-VECTOR metric: every coordinate is scaled by
# the single largest magnitude found anywhere in x or y, so a large coordinate
# can mask a total miss on a small one. It must NOT be used to gate the
# 22-coordinate gradient ledger; use rao_coordinatewise_relative_error there.
rao_relative_error <- function(x, y) {
  if (!is.numeric(x) || !is.numeric(y) || length(x) != length(y) ||
      any(!is.finite(x)) || any(!is.finite(y))) {
    .rao_fail("relative-error inputs must be finite numeric vectors of equal length")
  }
  max(abs(x - y)) / max(1, abs(x), abs(y))
}

# rao_coordinatewise_relative_error removes only the MASKING face of the defect
# -- a large coordinate hiding a total miss on a small sibling. It does NOT
# remove the absolute-tolerance face: its floor of 1 still judges every
# coordinate below unity absolutely, and EVERY coordinate of the frozen
# gradient is below unity. On the frozen state a 100% error on the smallest
# coordinate returns 5.53e-06 and passes a 1e-5 gate. It is a diagnostic for
# the masking face only; it is NOT the gradient-ledger gate.
rao_coordinatewise_relative_error <- function(x, y) {
  if (!is.numeric(x) || !is.numeric(y) || length(x) != length(y) ||
      any(!is.finite(x)) || any(!is.finite(y))) {
    .rao_fail("relative-error inputs must be finite numeric vectors of equal length")
  }
  max(abs(x - y) / pmax(1, abs(x), abs(y)))
}

# The gradient-ledger gate. Mixed absolute/relative criterion against the
# reference y: the ledger passes when the returned worst ratio is <= 1.
# Both tolerances are REQUIRED. There is no defensible default: a floor of 1
# silently converts the comparison to an absolute one, and a purely relative
# tolerance is unreachable wherever the reference approaches the objective's
# central-difference noise floor. `atol` must be justified against that
# measured floor, never chosen for convenience.
rao_coordinatewise_discrepancy <- function(x, y, atol, rtol) {
  if (!is.numeric(x) || !is.numeric(y) || length(x) != length(y) ||
      any(!is.finite(x)) || any(!is.finite(y))) {
    .rao_fail("discrepancy inputs must be finite numeric vectors of equal length")
  }
  if (!is.numeric(atol) || length(atol) != 1L || !is.finite(atol) || atol < 0 ||
      !is.numeric(rtol) || length(rtol) != 1L || !is.finite(rtol) || rtol < 0 ||
      atol + rtol <= 0) {
    .rao_fail("atol and rtol must be single finite non-negative numbers, not both zero")
  }
  max(abs(x - y) / (atol + rtol * abs(y)))
}
