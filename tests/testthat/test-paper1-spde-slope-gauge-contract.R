spde_slope_gauge_contract_env <- function() {
  env <- new.env(parent = baseenv())
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-contract.R"
  ), local = env)
  env
}

spde_slope_gauge_fd_jacobian <- function(map, phi, h = 1e-6) {
  vapply(seq_len(3L), function(j) {
    displacement <- rep(0, 3L)
    displacement[[j]] <- h
    (map(phi + displacement) - map(phi - displacement)) / (2 * h)
  }, numeric(3L))
}

test_that("the frozen GBIF slope loading round-trips in its positive gauge", {
  contract <- spde_slope_gauge_contract_env()
  lambda <- c(0.06615484034380216, -0.005920383591143399, -0.07900112916196837)
  phi <- c(-2.270971312595905, -0.089492825625087633, -1.1941851684835898)

  expect_equal(contract$spde_slope_gauge_map(phi), lambda, tolerance = 64 * .Machine$double.eps)
  expect_equal(contract$spde_slope_gauge_inverse(lambda), phi,
    tolerance = 64 * .Machine$double.eps)
  expect_equal(contract$.spde_slope_gauge_relative_error(
    contract$spde_slope_gauge_map(contract$spde_slope_gauge_inverse(lambda)), lambda
  ), 0, tolerance = 64 * .Machine$double.eps)

  for (interior_phi in list(c(-0.2, 0.7, -1.4), c(1.4, -1.1, 0.3))) {
    interior_lambda <- contract$spde_slope_gauge_map(interior_phi)
    expect_lte(contract$.spde_slope_gauge_relative_error(
      contract$spde_slope_gauge_inverse(interior_lambda), interior_phi
    ), 64 * .Machine$double.eps)
    expect_lte(contract$.spde_slope_gauge_relative_error(
      contract$spde_slope_gauge_map(contract$spde_slope_gauge_inverse(interior_lambda)),
      interior_lambda
    ), 64 * .Machine$double.eps)
  }
})

test_that("the analytic map Jacobian has the predeclared finite-difference agreement", {
  contract <- spde_slope_gauge_contract_env()
  frozen_phi <- c(-2.270971312595905, -0.089492825625087633, -1.1941851684835898)
  interior_points <- list(frozen_phi, c(-0.2, 0.7, -1.4), c(1.4, -1.1, 0.3))

  for (phi in interior_points) {
    jacobian <- contract$spde_slope_gauge_jacobian(phi)
    expect_gt(det(jacobian), 0)
    expect_lte(contract$.spde_slope_gauge_relative_error(
      jacobian,
      spde_slope_gauge_fd_jacobian(contract$spde_slope_gauge_map, phi)
    ), 1e-7)
  }
})

test_that("the gauge preserves the rank-one spatial-slope covariance", {
  contract <- spde_slope_gauge_contract_env()
  lambda <- c(0.06615484034380216, -0.005920383591143399, -0.07900112916196837)
  phi <- contract$spde_slope_gauge_inverse(lambda)

  expect_equal(contract$spde_slope_gauge_covariance(phi), tcrossprod(lambda),
    tolerance = 64 * .Machine$double.eps)
})

test_that("the gauge rejects nonpositive and malformed raw loading coordinates", {
  contract <- spde_slope_gauge_contract_env()

  expect_error(contract$spde_slope_gauge_inverse(c(0, 1, 1)), "positive-hemisphere")
  expect_error(contract$spde_slope_gauge_inverse(c(-1, 0, 0)), "positive-hemisphere")
  expect_error(contract$spde_slope_gauge_inverse(c(NA_real_, 0, 0)), "finite double")
  expect_error(contract$spde_slope_gauge_map(c(0, 0, Inf)), "finite double")
  expect_error(contract$spde_slope_gauge_jacobian(c(0, 0)), "finite double")
  expect_error(contract$spde_slope_gauge_jacobian(c(300, 0, 0)), "finite positive-determinant")
})

test_that("the chain-rule gradient matches an independent quadratic finite difference", {
  contract <- spde_slope_gauge_contract_env()
  precision <- matrix(c(2.0, 0.3, -0.1, 0.3, 1.5, 0.2, -0.1, 0.2, 1.2), 3, 3)
  linear <- c(0.4, -0.3, 0.1)
  raw_objective <- function(lambda) {
    0.5 * drop(crossprod(lambda, precision %*% lambda)) + sum(linear * lambda)
  }
  raw_gradient <- function(lambda) drop(precision %*% lambda + linear)
  transformed_objective <- function(phi) raw_objective(contract$spde_slope_gauge_map(phi))

  for (phi in list(
    c(-2.270971312595905, -0.089492825625087633, -1.1941851684835898),
    c(-0.2, 0.7, -1.4), c(1.4, -1.1, 0.3)
  )) {
    lambda <- contract$spde_slope_gauge_map(phi)
    analytic <- contract$spde_slope_gauge_chain_gradient(phi, raw_gradient(lambda))
    h <- .Machine$double.eps^(1 / 3) * pmax(1, abs(phi))
    finite_difference <- vapply(seq_len(3L), function(j) {
      displacement <- rep(0, 3L)
      displacement[[j]] <- h[[j]]
      (transformed_objective(phi + displacement) - transformed_objective(phi - displacement)) /
        (2 * h[[j]])
    }, numeric(1L))
    expect_lte(contract$.spde_slope_gauge_relative_error(analytic, finite_difference), 1e-5)
  }
})

test_that("the full 22-coordinate transform preserves a synthetic exact-order vector", {
  contract <- spde_slope_gauge_contract_env()
  theta <- c(
    -1.262290617, -1.304981027, -1.574027140, -0.564006099,
    0.368601106, 0.519498993, -0.116297433, 0.209393346,
    0.133570593, 0.364582652, -0.138192688, 0.183240509,
    -1.086430093, -1.550160288, -0.877284144, 2.687653160,
    21.617935157, -21.081066816, 14.560272537,
    0.06615484034380216, -0.005920383591143399, -0.07900112916196837
  )
  names(theta) <- contract$spde_slope_gauge_raw_order()

  phi <- contract$spde_slope_gauge_phi_from_theta(theta)
  expect_identical(names(phi), contract$spde_slope_gauge_phi_order())
  expect_equal(
    contract$spde_slope_gauge_theta_from_phi(phi), theta,
    tolerance = 64 * .Machine$double.eps
  )
  expect_error(
    contract$spde_slope_gauge_phi_from_theta(stats::setNames(theta, rev(names(theta)))),
    "exact gauge coordinate order"
  )
  expect_error(
    contract$spde_slope_gauge_phi_from_theta(unname(theta)),
    "exact gauge coordinate order"
  )
  expect_error(
    contract$spde_slope_gauge_theta_from_phi(stats::setNames(phi, rev(names(phi)))),
    "exact gauge coordinate order"
  )
  expect_error(
    contract$spde_slope_gauge_full_chain_gradient(phi, unname(theta)),
    "exact gauge coordinate order"
  )
})

test_that("the full Jacobian retains the raw-by-gauge positional axes", {
  contract <- spde_slope_gauge_contract_env()
  theta <- stats::setNames(seq(-1.1, 1.0, length.out = 22L),
    contract$spde_slope_gauge_raw_order())
  theta[20:22] <- c(0.2, -0.1, 0.3)
  phi <- contract$spde_slope_gauge_phi_from_theta(theta)
  full_jacobian <- contract$spde_slope_gauge_full_jacobian(phi)

  expect_identical(dim(full_jacobian), c(22L, 22L))
  expect_identical(rownames(full_jacobian), contract$spde_slope_gauge_raw_order())
  expect_identical(colnames(full_jacobian), contract$spde_slope_gauge_phi_order())
  expect_equal(unname(full_jacobian[1:19, 1:19]), diag(19L), tolerance = 0)
  expect_equal(unname(full_jacobian[1:19, 20:22]), matrix(0, 19L, 3L), tolerance = 0)
  expect_equal(unname(full_jacobian[20:22, 1:19]), matrix(0, 3L, 19L), tolerance = 0)
  expect_equal(unname(full_jacobian[20:22, 20:22]),
    contract$spde_slope_gauge_jacobian(unname(phi[20:22])), tolerance = 0)
})

test_that("the full transformed gradient matches a 22-dimensional quadratic harness", {
  contract <- spde_slope_gauge_contract_env()
  theta <- stats::setNames(seq(-1.1, 1.0, length.out = 22L),
    contract$spde_slope_gauge_raw_order())
  theta[20:22] <- c(0.2, -0.1, 0.3)
  phi <- contract$spde_slope_gauge_phi_from_theta(theta)
  precision <- diag(seq(1.1, 3.2, length.out = 22L))
  precision[1L, 2L] <- precision[2L, 1L] <- 0.1
  linear <- seq(-0.3, 0.3, length.out = 22L)
  raw_objective <- function(raw_theta) {
    0.5 * drop(crossprod(raw_theta, precision %*% raw_theta)) + sum(linear * raw_theta)
  }
  raw_gradient <- function(raw_theta) {
    stats::setNames(drop(precision %*% raw_theta + linear), contract$spde_slope_gauge_raw_order())
  }
  transformed_objective <- function(gauge_phi) {
    raw_objective(contract$spde_slope_gauge_theta_from_phi(gauge_phi))
  }
  analytic <- contract$spde_slope_gauge_full_chain_gradient(
    phi, raw_gradient(contract$spde_slope_gauge_theta_from_phi(phi))
  )
  h <- .Machine$double.eps^(1 / 3) * pmax(1, abs(phi))
  finite_difference <- vapply(seq_len(22L), function(j) {
    displacement <- rep(0, 22L)
    displacement[[j]] <- h[[j]]
    names(displacement) <- names(phi)
    (transformed_objective(phi + displacement) - transformed_objective(phi - displacement)) /
      (2 * h[[j]])
  }, numeric(1L))
  names(finite_difference) <- names(phi)

  expect_lte(contract$.spde_slope_gauge_relative_error(analytic, finite_difference), 1e-5)
})
