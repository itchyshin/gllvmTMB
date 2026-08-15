rao_contract_env <- function() {
  env <- new.env(parent = baseenv())
  sys.source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "range-amplitude-orthogonal-contract.R"
  ), envir = env)
  env
}

rao_theta <- function(contract) {
  theta <- stats::setNames(seq(-1.1, 1.0, length.out = 22L), contract$rao_raw_order())
  theta[16L] <- 2.687653160
  theta[20:22] <- c(0.06615484034380216, -0.005920383591143399, -0.07900112916196837)
  theta
}

test_that("orthogonal range--amplitude coordinates round trip without changing raw order", {
  contract <- rao_contract_env()
  theta <- rao_theta(contract)
  phi <- contract$rao_phi_from_theta(theta)
  expect_identical(names(phi), contract$rao_phi_order())
  expect_equal(contract$rao_theta_from_phi(phi), theta, tolerance = 64 * .Machine$double.eps)
  expect_error(contract$rao_phi_from_theta(unname(theta)), "exact coordinate order")
  theta[20L] <- 0
  expect_error(contract$rao_phi_from_theta(theta), "positive")
})

test_that("the full Jacobian has exact axes, unchanged coordinates, and the analytic local block", {
  contract <- rao_contract_env()
  phi <- contract$rao_phi_from_theta(rao_theta(contract))
  jacobian <- contract$rao_full_jacobian(phi)
  expect_identical(dim(jacobian), c(22L, 22L))
  expect_identical(rownames(jacobian), contract$rao_raw_order())
  expect_identical(colnames(jacobian), contract$rao_phi_order())
  unchanged <- c(1:15, 17:19)
  expect_equal(unname(jacobian[unchanged, unchanged]), diag(length(unchanged)), tolerance = 0)
  expect_equal(unname(jacobian[unchanged, c(16L, 20:22)]), matrix(0, length(unchanged), 4L), tolerance = 0)
  expect_equal(unname(jacobian[c(16L, 20:22), unchanged]), matrix(0, 4L, length(unchanged)), tolerance = 0)
  expect_gt(abs(det(jacobian[c(16L, 20:22), c(16L, 20:22)])), 0)
})

test_that("chain gradient agrees with independent composed quadratic finite differences in all 22 coordinates", {
  contract <- rao_contract_env()
  theta <- rao_theta(contract)
  phi <- contract$rao_phi_from_theta(theta)
  precision <- diag(seq(1.1, 3.2, length.out = 22L))
  precision[1L, 2L] <- precision[2L, 1L] <- 0.1
  linear <- seq(-0.3, 0.3, length.out = 22L)
  objective <- function(raw) 0.5 * drop(crossprod(raw, precision %*% raw)) + sum(linear * raw)
  gradient <- function(raw) stats::setNames(drop(precision %*% raw + linear), contract$rao_raw_order())
  transformed <- function(x) objective(contract$rao_theta_from_phi(x))
  analytic <- contract$rao_full_chain_gradient(phi, gradient(theta))
  h <- .Machine$double.eps^(1 / 3) * pmax(1, abs(phi))
  finite_difference <- vapply(seq_len(22L), function(j) {
    delta <- stats::setNames(rep(0, 22L), names(phi))
    delta[[j]] <- h[[j]]
    (transformed(phi + delta) - transformed(phi - delta)) / (2 * h[[j]])
  }, numeric(1L))
  names(finite_difference) <- names(phi)
  expect_lte(contract$rao_relative_error(analytic, finite_difference), 1e-5)
  expect_error(contract$rao_full_chain_gradient(phi, unname(gradient(theta))), "exact coordinate order")
})
