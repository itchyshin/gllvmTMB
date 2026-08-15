spde_slope_gauge_tr_contract_env <- function() {
  env <- new.env(parent = baseenv())
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-contract.R"
  ), local = env)
  source(testthat::test_path(
    "..", "..", "dev", "isdm-package-recovery", "spde-slope-gauge-trust-region-contract.R"
  ), local = env)
  env
}

spde_slope_gauge_tr_fixture <- function(contract) {
  raw_order <- contract$spde_slope_gauge_raw_order()
  phi_order <- contract$spde_slope_gauge_phi_order()
  theta <- stats::setNames(seq(-0.8, 0.8, length.out = 22L), raw_order)
  theta[20:22] <- c(0.2, -0.1, 0.3)
  phi0 <- contract$spde_slope_gauge_phi_from_theta(theta)
  target <- phi0
  target[1:3] <- target[1:3] + c(0.025, -0.02, 0.01)
  evaluate <- function(phi) {
    phi <- stats::setNames(as.double(phi), phi_order)
    transformed_gradient <- phi - target
    jacobian <- contract$spde_slope_gauge_full_jacobian(phi)
    raw_gradient <- stats::setNames(
      drop(solve(t(jacobian), transformed_gradient)), raw_order
    )
    list(
      objective = as.double(0.5 * sum((phi - target)^2)),
      raw_theta = contract$spde_slope_gauge_theta_from_phi(phi),
      raw_gradient = raw_gradient
    )
  }
  covariance <- function(raw_theta) {
    list(
      par.fixed = raw_theta,
      cov.fixed = structure(diag(seq(1, 2, length.out = 22L)),
        dimnames = list(raw_order, raw_order)),
      pdHess = TRUE
    )
  }
  list(phi0 = phi0, evaluate = evaluate, covariance = covariance)
}

test_that("the transformed Hessian retains the fixed three-scale 132-gradient ledger", {
  contract <- spde_slope_gauge_tr_contract_env()
  fixture <- spde_slope_gauge_tr_fixture(contract)
  controls <- contract$spde_slope_gauge_trust_region_controls()
  hessian <- contract$.spde_slope_gauge_tr_hessian(fixture$phi0, fixture$evaluate, controls)

  expect_true(hessian$valid)
  expect_identical(hessian$reason, "hessian_stability_valid")
  expect_length(hessian$records, 132L)
  expect_identical(vapply(hessian$records, `[[`, integer(1L), "scale_index"),
    rep(1:3, each = 44L))
  expect_identical(vapply(hessian$records, `[[`, integer(1L), "coordinate"),
    rep(rep(1:22, each = 2L), 3L))
  expect_identical(vapply(hessian$records, `[[`, character(1L), "side"),
    rep(c("minus", "plus"), 66L))
  expect_identical(dim(hessian$hessian), c(22L, 22L))
  expect_identical(rownames(hessian$hessian), contract$spde_slope_gauge_phi_order())
  expect_identical(colnames(hessian$hessian), contract$spde_slope_gauge_phi_order())
  expect_lte(max(hessian$matrix_error), controls$hessian_agreement)
  expect_lte(max(hessian$eigen_error), controls$hessian_agreement)
})

test_that("Hessian diagnostics use the declared Frobenius-relative error", {
  contract <- spde_slope_gauge_tr_contract_env()
  reference <- diag(2L)
  perturbed <- reference + matrix(1e-6, 2L, 2L)
  expected <- sqrt(sum(matrix(1e-6, 2L, 2L)^2)) / sqrt(sum(reference^2))

  expect_lt(abs(contract$.spde_slope_gauge_tr_relative_error(perturbed, reference) - expected), 2e-11)
  expect_gt(expected, 1e-6)
})

test_that("the fixed shifted grid admits a candidate only after raw covariance gates", {
  contract <- spde_slope_gauge_tr_contract_env()
  fixture <- spde_slope_gauge_tr_fixture(contract)
  result <- contract$spde_slope_gauge_trust_region(
    fixture$phi0, fixture$evaluate, fixture$covariance
  )

  expect_identical(result$status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION")
  expect_identical(result$reason, "selected_candidate_passed_all_gates")
  expect_length(result$trials, 24L)
  expect_identical(vapply(result$trials, `[[`, integer(1L), "index"), 1:24)
  expect_identical(result$selected$index, 1L)
  expect_true(result$selected$accepted)
  expect_identical(names(result$selected$evaluation$raw_theta), contract$spde_slope_gauge_raw_order())
  expect_identical(rownames(result$selected$covariance$covariance), contract$spde_slope_gauge_raw_order())
})

test_that("an unavailable shifted system is retained as a complete deterministic rejection grid", {
  contract <- spde_slope_gauge_tr_contract_env()
  fixture <- spde_slope_gauge_tr_fixture(contract)
  assign("chol", function(...) stop("forced shifted Cholesky failure"), envir = contract)
  result <- contract$spde_slope_gauge_trust_region(
    fixture$phi0, fixture$evaluate, fixture$covariance
  )

  expect_identical(result$status, "GAUGE_TRUST_REGION_NO_ADMISSIBLE_CANDIDATE")
  expect_length(result$trials, 24L)
  expect_true(all(vapply(result$trials, function(trial) {
    identical(trial$reason, "shifted_system_unavailable") && identical(trial$accepted, FALSE)
  }, logical(1L))))
})

test_that("terminal evidence is independently recomputed from the fixed callback contract", {
  contract <- spde_slope_gauge_tr_contract_env()
  fixture <- spde_slope_gauge_tr_fixture(contract)
  result <- contract$spde_slope_gauge_trust_region(
    fixture$phi0, fixture$evaluate, fixture$covariance
  )
  tampered <- result
  tampered$selected$evaluation$raw_gradient[[1L]] <-
    tampered$selected$evaluation$raw_gradient[[1L]] + 1e-4

  accepted <- contract$spde_slope_gauge_trust_region_validate_result(
    result, fixture$phi0, fixture$evaluate, fixture$covariance
  )
  rejected <- contract$spde_slope_gauge_trust_region_validate_result(
    tampered, fixture$phi0, fixture$evaluate, fixture$covariance
  )
  expect_true(accepted$valid)
  expect_identical(accepted$reason, "trust_region_result_recomputed")
  expect_identical(accepted$status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION")
  expect_false(rejected$valid)
  expect_identical(rejected$reason, "terminal_evidence_recomputation_failed")
})

test_that("covariance rejection remains a numerical non-admission rather than an infrastructure result", {
  contract <- spde_slope_gauge_tr_contract_env()
  fixture <- spde_slope_gauge_tr_fixture(contract)
  non_pd_covariance <- function(raw_theta) {
    raw_order <- contract$spde_slope_gauge_raw_order()
    covariance <- diag(22L)
    covariance[[22L, 22L]] <- -1
    dimnames(covariance) <- list(raw_order, raw_order)
    list(par.fixed = raw_theta, cov.fixed = covariance, pdHess = TRUE)
  }
  result <- contract$spde_slope_gauge_trust_region(
    fixture$phi0, fixture$evaluate, non_pd_covariance
  )

  expect_identical(result$status, "GAUGE_TRUST_REGION_NO_ADMISSIBLE_CANDIDATE")
  expect_identical(result$reason, "no_trial_passed_all_gates")
  expect_true(all(vapply(result$trials, function(trial) {
    identical(trial$reason, "candidate_covariance_not_positive_definite") ||
      identical(trial$reason, "objective_or_gradient_gate_failed")
  }, logical(1L))))
})

test_that("an entirely unnamed covariance uses only the verified par.fixed positional map", {
  contract <- spde_slope_gauge_tr_contract_env()
  fixture <- spde_slope_gauge_tr_fixture(contract)
  unnamed_covariance <- function(raw_theta) {
    list(par.fixed = raw_theta, cov.fixed = diag(22L), pdHess = TRUE)
  }
  result <- contract$spde_slope_gauge_trust_region(
    fixture$phi0, fixture$evaluate, unnamed_covariance
  )

  expect_identical(result$status, "GAUGE_TRUST_REGION_NUMERICAL_ADMISSION")
  expect_null(result$selected$covariance$raw_row_names)
  expect_null(result$selected$covariance$raw_column_names)
  expect_identical(rownames(result$selected$covariance$covariance),
    contract$spde_slope_gauge_raw_order())
})

test_that("callback and covariance schema drift fail closed", {
  contract <- spde_slope_gauge_tr_contract_env()
  fixture <- spde_slope_gauge_tr_fixture(contract)
  bad_gradient <- function(phi) {
    value <- fixture$evaluate(phi)
    value$raw_gradient <- stats::setNames(value$raw_gradient, rev(names(value$raw_gradient)))
    value
  }
  bad_covariance <- function(raw_theta) {
    value <- fixture$covariance(raw_theta)
    dimnames(value$cov.fixed) <- list(rev(rownames(value$cov.fixed)), colnames(value$cov.fixed))
    value
  }
  stale_covariance <- function(raw_theta) {
    value <- fixture$covariance(raw_theta)
    value$par.fixed[[1L]] <- value$par.fixed[[1L]] + 1e-3
    value
  }

  gradient_result <- contract$spde_slope_gauge_trust_region(
    fixture$phi0, bad_gradient, fixture$covariance
  )
  covariance_result <- contract$spde_slope_gauge_trust_region(
    fixture$phi0, fixture$evaluate, bad_covariance
  )
  stale_result <- contract$spde_slope_gauge_trust_region(
    fixture$phi0, fixture$evaluate, stale_covariance
  )
  expect_identical(gradient_result$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD")
  expect_identical(gradient_result$reason, "start_callback_unavailable")
  expect_identical(covariance_result$status, "GAUGE_TRUST_REGION_NO_ADMISSIBLE_CANDIDATE")
  expect_true(any(vapply(covariance_result$trials, function(trial) {
    identical(trial$reason, "candidate_covariance_schema_or_finiteness_failed")
  }, logical(1L))))
  expect_identical(stale_result$status, "GAUGE_TRUST_REGION_NO_ADMISSIBLE_CANDIDATE")
  expect_true(any(vapply(stale_result$trials, function(trial) {
    identical(trial$reason, "candidate_covariance_schema_or_finiteness_failed")
  }, logical(1L))))
})

test_that("an infrastructure failure retains the failing trial rather than erasing its prefix", {
  contract <- spde_slope_gauge_tr_contract_env()
  fixture <- spde_slope_gauge_tr_fixture(contract)
  calls <- 0L
  late_failure <- function(phi) {
    calls <<- calls + 1L
    if (calls == 134L) return(list())
    fixture$evaluate(phi)
  }
  result <- contract$spde_slope_gauge_trust_region(
    fixture$phi0, late_failure, fixture$covariance
  )

  expect_identical(result$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD")
  expect_identical(result$reason, "trial_callback_unavailable")
  expect_length(result$trials, 1L)
  expect_identical(result$trials[[1L]]$reason, "trial_callback_unavailable")
  expect_false(result$trials[[1L]]$accepted)
})

test_that("the controls are an exact frozen packet", {
  contract <- spde_slope_gauge_tr_contract_env()
  fixture <- spde_slope_gauge_tr_fixture(contract)
  altered <- contract$spde_slope_gauge_trust_region_controls()
  altered$radii[[1L]] <- 1
  result <- contract$spde_slope_gauge_trust_region(
    fixture$phi0, fixture$evaluate, fixture$covariance, altered
  )
  expect_identical(result$status, "GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD")
  expect_identical(result$reason, "input_schema_invalid")
})
