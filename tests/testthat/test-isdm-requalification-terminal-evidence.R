test_that("v3 binds producer-shaped unnamed Psi through exact Sigma order", {
  truth <- diag(c(0.2, 0.3, 0.4))
  dimnames(truth) <- list(paste0("sp", 1:3), paste0("sp", 1:3))
  sigma <- truth + 0.1
  dimnames(sigma) <- dimnames(truth)
  record <- list(
    status = "fit_returned",
    truth = list(Psi = truth),
    estimate = list(Psi = diag(c(0.21, 0.29, 0.39)), Sigma = sigma)
  )
  repaired <- isdm_v3_normalize_psi(record)
  expect_identical(dimnames(repaired$estimate$Psi), dimnames(truth))
  expect_equal(unname(diag(repaired$estimate$Psi)), c(0.21, 0.29, 0.39))
})

test_that("v3 Psi binding refuses ambiguous or inconsistent shapes", {
  truth <- diag(c(0.2, 0.3, 0.4))
  dimnames(truth) <- list(paste0("sp", 1:3), paste0("sp", 1:3))
  sigma <- truth
  dimnames(sigma) <- list(c("sp2", "sp1", "sp3"),
                          c("sp2", "sp1", "sp3"))
  record <- list(
    status = "fit_returned",
    truth = list(Psi = truth),
    estimate = list(Psi = diag(c(0.21, 0.29, 0.39)), Sigma = sigma)
  )
  expect_error(
    isdm_v3_normalize_psi(record),
    "Sigma to bind the exact truth trait order"
  )
})

test_that("routine latent Psi advisory cannot pass the attack diagnostic", {
  routine <- list(
    status = "fit_returned", failure_phase = "fit",
    warnings = paste(
      "Ordinary latent() now includes a per-trait Psi by default",
      "Pass latent(..., unique = FALSE) for the old fit"
    ),
    diagnostics = list(convergence = 0L, pd_hessian = TRUE)
  )
  classified <- isdm_v3_attack_classification(routine)
  expect_false(classified$qualified)
  expect_true(classified$routine_warning_only)
  verdict <- isdm_v3_attack_verdict(rep(list(routine), 200L), TRUE)
  expect_identical(verdict$verdict, "FAIL")
  expect_identical(verdict$disposition, "STRESS_ONLY")
  expect_identical(verdict$diagnostic_qualified, 0L)
  expect_identical(verdict$routine_warning_only, 200L)
  expect_identical(verdict$silent_or_unqualified, 200L)
})

test_that("targeted warnings, fit refusals, and unhealthy fits qualify", {
  targeted <- list(
    status = "fit_returned", warnings = "disconnected support detected",
    diagnostics = list(convergence = 0L, pd_hessian = TRUE)
  )
  refused <- list(
    status = "error", failure_phase = "fit", warnings = character(),
    diagnostics = list(convergence = NA_integer_, pd_hessian = NA)
  )
  unhealthy <- list(
    status = "fit_returned", warnings = character(),
    diagnostics = list(convergence = 1L, pd_hessian = FALSE)
  )
  expect_true(isdm_v3_attack_classification(targeted)$qualified)
  expect_true(isdm_v3_attack_classification(refused)$qualified)
  expect_true(isdm_v3_attack_classification(unhealthy)$qualified)
})
