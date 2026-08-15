rao_contract_env <- function() {
  env <- new.env(parent = baseenv())
  sys.source(isdm_dev_path("range-amplitude-orthogonal-contract.R"), envir = env)
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
  ## F3: the 22-coordinate ledger is gated by the mixed atol/rtol criterion.
  ## Neither rao_relative_error (whole-vector denominator) nor
  ## rao_coordinatewise_relative_error (floor pinned at 1) may gate it: the
  ## first lets a large coordinate hide a miss on a small one, the second
  ## judges absolutely every coordinate below unity.  This objective is an
  ## exactly-representable quadratic, so atol can be negligible here and the
  ## check is effectively relative; the real marginal objective cannot use
  ## these numbers -- its atol must be measured from its own noise floor.
  expect_lte(
    contract$rao_coordinatewise_discrepancy(
      analytic, finite_difference, atol = 1e-12, rtol = 1e-5
    ),
    1
  )
  expect_error(contract$rao_full_chain_gradient(phi, unname(gradient(theta))), "exact coordinate order")
})

test_that("F6: the local block determinant is exactly -lambda1^3, negative, and equals the full 22x22 determinant", {
  contract <- rao_contract_env()
  theta <- rao_theta(contract)
  phi <- contract$rao_phi_from_theta(theta)
  jacobian <- contract$rao_full_jacobian(phi)
  lambda1 <- unname(theta[[20L]])
  local_det <- det(jacobian[c(16L, 20:22), c(16L, 20:22)])
  expect_equal(local_det, -lambda1^3, tolerance = 1e-12)
  expect_lt(local_det, 0)
  expect_equal(det(jacobian), local_det, tolerance = 0)
})

test_that("F3: the whole-vector error metric masks a coordinate miss that the coordinatewise metric catches", {
  contract <- rao_contract_env()
  x <- c(1e6, 1, 2)
  y <- c(1e6, 2, 2)
  gate <- 1e-5
  whole_vector <- contract$rao_relative_error(x, y)
  coordinatewise <- contract$rao_coordinatewise_relative_error(x, y)
  expect_lt(whole_vector, gate)
  expect_equal(coordinatewise, 0.5, tolerance = 0)
  expect_gt(coordinatewise, gate)
})

test_that("F3: the coordinatewise metric is ITSELF vacuous below unity; only the mixed criterion catches a total miss", {
  contract <- rao_contract_env()
  ## Magnitudes taken from the sealed MSPDE V3 gradient: the largest component
  ## and the smallest of the four already below the 1e-5 gate.  Hard-coded
  ## rather than read from the packet so this stays a pure test.
  largest <- 2.823707e-04
  smallest <- 5.532734e-06
  reference <- c(largest, smallest)
  erroneous <- c(largest, 0)          # a 100% error on the small coordinate
  gate <- 1e-5

  ## The coordinatewise metric floors its denominator at 1, so every component
  ## below unity is judged absolutely -- and every component here is.  It lets
  ## a total miss through.
  expect_lt(contract$rao_coordinatewise_relative_error(erroneous, reference), gate)

  ## The mixed criterion, with atol scaled to the objective's noise floor
  ## rather than to 1, rejects it by three orders of magnitude.
  discrepancy <- contract$rao_coordinatewise_discrepancy(
    erroneous, reference, atol = 1e-9, rtol = 1e-5
  )
  expect_gt(discrepancy, 1)
  expect_gt(discrepancy, 1000)

  ## Exact agreement must still pass, and both tolerances are mandatory.
  expect_equal(
    contract$rao_coordinatewise_discrepancy(reference, reference, atol = 1e-9, rtol = 1e-5),
    0,
    tolerance = 0
  )
  expect_error(contract$rao_coordinatewise_discrepancy(reference, reference), "atol")
  expect_error(
    contract$rao_coordinatewise_discrepancy(reference, reference, atol = 0, rtol = 0),
    "not both zero"
  )
})

test_that("F5: domain-guard boundary behaviour at eta overflow, eta underflow, and a tiny positive first loading", {
  contract <- rao_contract_env()
  theta <- rao_theta(contract)
  phi <- contract$rao_phi_from_theta(theta)

  # (i) eta so large that exp(eta) overflows to Inf: already fails loudly.
  phi_overflow <- phi
  phi_overflow[16L] <- 1000
  phi_overflow[20L] <- -1000
  expect_error(
    contract$rao_theta_from_phi(phi_overflow),
    "outside the finite positive-loading domain"
  )

  # (ii) eta so negative that exp(eta) underflows to exactly 0: already fails
  # loudly (lambda1 == 0 trips the lambda1 <= 0 guard, same message as (i)).
  phi_underflow <- phi
  phi_underflow[16L] <- -1000
  phi_underflow[20L] <- 1000
  expect_error(
    contract$rao_theta_from_phi(phi_underflow),
    "outside the finite positive-loading domain"
  )

  # (iii) lambda1 tiny but positive, lambda2/lambda3 of order 1 (ratio a, b
  # enormous): no guard fires, round trip succeeds but loses precision --
  # measured ~1e-13, roughly ten times the standard round-trip tolerance
  # used elsewhere in this file, never blowing up.
  theta_tiny <- theta
  theta_tiny[20L] <- 1e-300
  theta_tiny[21L] <- 1
  theta_tiny[22L] <- 1
  phi_tiny <- contract$rao_phi_from_theta(theta_tiny)
  expect_true(all(is.finite(phi_tiny)))
  theta_back <- contract$rao_theta_from_phi(phi_tiny)
  roundtrip_error <- contract$rao_coordinatewise_relative_error(
    unname(theta_back[20:22]), unname(theta_tiny[20:22])
  )
  expect_gt(roundtrip_error, 64 * .Machine$double.eps)
  expect_lt(roundtrip_error, 1e-9)
})

test_that("F-NEW-A: permuted coordinate names (correct set, wrong order) are rejected, not just missing names", {
  contract <- rao_contract_env()
  theta <- rao_theta(contract)
  phi <- contract$rao_phi_from_theta(theta)

  theta_permuted <- theta[c(2L, 1L, 3:22)]
  expect_true(setequal(names(theta_permuted), contract$rao_raw_order()))
  expect_false(identical(names(theta_permuted), contract$rao_raw_order()))
  expect_error(contract$rao_phi_from_theta(theta_permuted), "exact coordinate order")

  phi_permuted <- phi[c(2L, 1L, 3:22)]
  expect_true(setequal(names(phi_permuted), contract$rao_phi_order()))
  expect_false(identical(names(phi_permuted), contract$rao_phi_order()))
  expect_error(contract$rao_theta_from_phi(phi_permuted), "exact coordinate order")

  raw_gradient <- stats::setNames(seq(0.1, 2.2, length.out = 22L), contract$rao_raw_order())
  raw_gradient_permuted <- raw_gradient[c(2L, 1L, 3:22)]
  expect_error(
    contract$rao_full_chain_gradient(phi, raw_gradient_permuted),
    "exact coordinate order"
  )
})

test_that("F-NEW-B: covariance is sign-invariant under lambda -> -lambda, but the chart rejects the negative representative", {
  contract <- rao_contract_env()
  theta <- rao_theta(contract)
  lambda <- unname(theta[20:22])

  Sigma_pos <- lambda %*% t(lambda)
  Sigma_neg <- (-lambda) %*% t(-lambda)
  expect_identical(Sigma_pos, Sigma_neg)

  theta_neg <- theta
  theta_neg[20:22] <- -lambda
  expect_error(
    contract$rao_phi_from_theta(theta_neg),
    "must be positive in the orthogonal-chart domain"
  )
})

test_that("F-NEW-C: Sigma depends on phi only through eta = (u - v) / sqrt(2); q = (u + v) / sqrt(2) is its orthogonal complement", {
  contract <- rao_contract_env()
  phi_base <- contract$rao_phi_from_theta(rao_theta(contract))

  # (i) hold u - v fixed (exact dyadic values so the subtraction is exact),
  # vary u + v: q changes, lambda (hence Sigma) is bit-identical.
  phi_a <- phi_base
  phi_a[16L] <- 1.0; phi_a[20L] <- 0.75; phi_a[21L] <- 0.5; phi_a[22L] <- -0.25
  phi_b <- phi_base
  phi_b[16L] <- 3.0; phi_b[20L] <- 2.75; phi_b[21L] <- 0.5; phi_b[22L] <- -0.25

  theta_a <- contract$rao_theta_from_phi(phi_a)
  theta_b <- contract$rao_theta_from_phi(phi_b)
  expect_false(identical(unname(theta_a[16L]), unname(theta_b[16L])))
  expect_identical(unname(theta_a[20:22]), unname(theta_b[20:22]))
  Sigma_a <- theta_a[20:22] %*% t(theta_a[20:22])
  Sigma_b <- theta_b[20:22] %*% t(theta_b[20:22])
  expect_identical(unname(Sigma_a), unname(Sigma_b))

  # (ii) hold u + v fixed, vary u - v: q is bit-identical, lambda (hence
  # Sigma) changes.
  phi_c <- phi_base
  phi_c[16L] <- 1.0; phi_c[20L] <- 0.75; phi_c[21L] <- 0.5; phi_c[22L] <- -0.25
  phi_d <- phi_base
  phi_d[16L] <- 1.25; phi_d[20L] <- 0.5; phi_d[21L] <- 0.5; phi_d[22L] <- -0.25

  theta_c <- contract$rao_theta_from_phi(phi_c)
  theta_d <- contract$rao_theta_from_phi(phi_d)
  expect_identical(unname(theta_c[16L]), unname(theta_d[16L]))
  Sigma_c <- theta_c[20:22] %*% t(theta_c[20:22])
  Sigma_d <- theta_d[20:22] %*% t(theta_d[20:22])
  expect_false(identical(unname(Sigma_c), unname(Sigma_d)))
})
