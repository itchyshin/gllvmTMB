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
