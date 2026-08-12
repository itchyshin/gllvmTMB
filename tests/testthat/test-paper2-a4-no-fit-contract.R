## Paper 2 A4 is deliberately Tier-1: hand-built numerical ledgers only.
## It must never construct the private iJSDM objective or invoke its runner.

test_that("Paper 2 A4 preserves Case-C non-entry and Case-B isolation", {
  classify <- gllvmTMB:::.gllvmTMB_isdm_numerical_admission
  base <- list(
    isdm_internal = TRUE, optimizer = "nlminb", aghq_used = FALSE,
    ridge_tau = NULL, convergence = 0L, objective = 100,
    gradient = c(b_fix = 2e-4, theta_rr_B = -3e-4, theta_diag_B = 1e-4),
    parameter_names = c("b_fix", "theta_rr_B", "theta_diag_B"),
    pd_hessian = TRUE, boundary_flags = character(), boundary_diag_indices = integer(),
    raw_gradient_gate = 1e-3, health_gradient_gate = 1e-2
  )

  raw_pass <- do.call(classify, base)
  expect_identical(raw_pass, list(
    case = "A", polish_status = "NOT_REQUIRED", numerical_admission = TRUE,
    reason = "raw_gradient_pass"
  ))

  boundary <- do.call(classify, utils::modifyList(base, list(
    gradient = c(b_fix = 2e-4, theta_rr_B = -1.5e-3, theta_diag_B = 1e-4),
    boundary_flags = "near_zero_sd_B", boundary_diag_indices = 1L
  )))
  expect_identical(boundary$case, "B")
  expect_identical(boundary$polish_status, "ELIGIBLE")
  expect_false(boundary$numerical_admission)

  for (block in c("b_fix", "theta_rr_B")) {
    gradient <- base$gradient
    gradient[[block]] <- 1.5e-3
    case_c <- do.call(classify, utils::modifyList(base, list(gradient = gradient)))
    expect_identical(case_c, list(
      case = "C", polish_status = "NO_CANDIDATE", numerical_admission = FALSE,
      reason = paste0("nonboundary_", block)
    ))
    expect_false(any(c("candidate_method", "candidate_attempts", "accepted") %in%
      names(case_c)))
  }
})

test_that("Paper 2 A4 rejects every non-Case-C adversarial raw state", {
  classify <- gllvmTMB:::.gllvmTMB_isdm_numerical_admission
  base <- list(
    isdm_internal = TRUE, optimizer = "nlminb", aghq_used = FALSE,
    ridge_tau = NULL, convergence = 0L, objective = 100,
    gradient = c(b_fix = 2e-4, theta_rr_B = -3e-4, theta_diag_B = 1e-4),
    parameter_names = c("b_fix", "theta_rr_B", "theta_diag_B"),
    pd_hessian = TRUE, boundary_flags = character(), boundary_diag_indices = integer(),
    raw_gradient_gate = 1e-3, health_gradient_gate = 1e-2
  )
  invalid <- list(
    tied_maximum = list(gradient = c(b_fix = 1.5e-3, theta_rr_B = -1.5e-3,
                                     theta_diag_B = 1e-4)),
    diagonal_maximum = list(gradient = c(b_fix = 2e-4, theta_rr_B = -3e-4,
                                          theta_diag_B = 1.5e-3)),
    upper_classifier_boundary = list(gradient = c(b_fix = 1e-2, theta_rr_B = -3e-4,
                                                    theta_diag_B = 1e-4)),
    nonfinite_objective = list(objective = Inf),
    nonfinite_gradient = list(gradient = c(b_fix = NA_real_, theta_rr_B = -3e-4,
                                            theta_diag_B = 1e-4)),
    non_pd_hessian = list(pd_hessian = FALSE),
    wrong_optimizer = list(optimizer = "other"),
    aghq = list(aghq_used = TRUE),
    ridge = list(ridge_tau = 1e-6)
  )
  for (name in names(invalid)) {
    result <- do.call(classify, utils::modifyList(base, invalid[[name]]))
    expect_identical(result$case, "D", info = name)
    expect_identical(result$polish_status, "INVALID_RULE_STATE", info = name)
    expect_false(result$numerical_admission, info = name)
  }
})

test_that("Paper 2 A4 keeps the diagonal-Psi transform and no-execution fence", {
  theta_diag_B <- c(sp1 = log(0.2), sp2 = log(0.5), sp3 = log(1.1))
  expect_equal(exp(2 * theta_diag_B), c(sp1 = 0.04, sp2 = 0.25, sp3 = 1.21))

  body_text <- paste(deparse(body(
    gllvmTMB:::.gllvmTMB_isdm_numerical_admission
  )), collapse = "\n")
  expect_false(grepl("MakeADFun\\(|\\.gll_isdm_fit\\(|nlminb\\(|profile", body_text))
  expect_true(grepl("NO_CANDIDATE", body_text, fixed = TRUE))
  expect_true(grepl("theta_rr_B", body_text, fixed = TRUE))
  expect_true(grepl("b_fix", body_text, fixed = TRUE))
})
