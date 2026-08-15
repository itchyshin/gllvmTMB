spde_slope_gauge_sign_contract_env <- function() {
  env <- new.env(parent = baseenv())
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-contract.R"
  ), local = env)
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-sign-contract.R"
  ), local = env)
  env
}

spde_slope_gauge_sign_fixture <- function(contract) {
  theta <- stats::setNames(seq(-0.9, 1.2, length.out = 22L),
    contract$spde_slope_gauge_raw_order())
  theta[20:22] <- c(0.2, -0.1, 0.3)
  parameters <- list(g_spde_slope = array(0, dim = c(2L, 1L, 2L)))
  full <- c(theta[17:22], 0.4, -0.3, 0.1, 0.6, -0.2, 0.5, -0.7)
  names(full) <- c(rep("theta_rr_spde_slope", 6L), rep("s_B", 3L),
    rep("g_spde_slope", 4L))
  list(
    parameters = parameters,
    random = c("s_B", "g_spde_slope"),
    full = stats::setNames(as.double(full), names(full)),
    random_indices = as.integer(7:13),
    theta = theta,
    conditional_hessian_fn = function(x) diag(7L),
    report_fn = function(x) list(eta = c(
      x[[4L]] * x[[12L]],
      x[[5L]] * x[[13L]],
      x[[6L]] * (x[[12L]] + x[[13L]])
    )),
    marginal_objective_fn = function(raw_theta) sum(raw_theta * raw_theta)
  )
}

test_that("the full random-effect sign operator preserves Hessian, predictor, and marginal objective", {
  contract <- spde_slope_gauge_sign_contract_env()
  fixture <- spde_slope_gauge_sign_fixture(contract)
  verdict <- do.call(contract$spde_slope_gauge_validate_sign_orbit, fixture)

  expect_true(verdict$valid)
  expect_identical(verdict$reason, "sign_orbit_valid")
  expect_identical(verdict$descriptor$gbif_random_index, 12:13)
  expect_equal(verdict$conditional_hessian_error, 0, tolerance = 0)
  expect_equal(verdict$predictor_error, 0, tolerance = 0)
  expect_equal(verdict$objective_error, 0, tolerance = 0)
})

test_that("the signed conditional Hessian is compared with the transformed original state", {
  contract <- spde_slope_gauge_sign_contract_env()
  fixture <- spde_slope_gauge_sign_fixture(contract)
  descriptor <- contract$spde_slope_gauge_sign_descriptor(
    fixture$parameters, fixture$random, fixture$full, fixture$random_indices, fixture$theta
  )
  q <- diag(7L)
  q[4L, 6L] <- q[6L, 4L] <- 0.2
  signed_q <- sweep(sweep(q, 1L, descriptor$random_sign, `*`), 2L, descriptor$random_sign, `*`)
  fixture$conditional_hessian_fn <- function(x) {
    if (isTRUE(all.equal(x, descriptor$signed_full, tolerance = 0))) signed_q else q
  }
  verdict <- do.call(contract$spde_slope_gauge_validate_sign_orbit, fixture)

  expect_true(verdict$valid)
  expect_equal(verdict$conditional_hessian_error, 0, tolerance = 0)
  expect_equal(verdict$signed_conditional_hessian, signed_q, tolerance = 0)
})

test_that("the sign contract rejects a conditional Hessian that is not invariant", {
  contract <- spde_slope_gauge_sign_contract_env()
  fixture <- spde_slope_gauge_sign_fixture(contract)
  conditional_hessian <- diag(7L)
  conditional_hessian[4L, 6L] <- 0.2
  conditional_hessian[6L, 4L] <- 0.2
  fixture$conditional_hessian_fn <- function(x) conditional_hessian
  verdict <- do.call(contract$spde_slope_gauge_validate_sign_orbit, fixture)

  expect_false(verdict$valid)
  expect_identical(verdict$reason, "sign_orbit_invariance_failed")
  expect_gt(verdict$conditional_hessian_error, 1e-10)
})

test_that("the sign contract rejects an incompatible sealed random-effect packing", {
  contract <- spde_slope_gauge_sign_contract_env()
  fixture <- spde_slope_gauge_sign_fixture(contract)
  fixture$random <- rev(fixture$random)
  verdict <- do.call(contract$spde_slope_gauge_validate_sign_orbit, fixture)

  expect_false(verdict$valid)
  expect_identical(verdict$reason, "sign_orbit_state_invalid")
})
