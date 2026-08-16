test_that("G2n prospective numerical-admission table is exhaustive and exclusive", {
  classify <- gllvmTMB:::.gllvmTMB_isdm_numerical_admission
  base <- list(
    isdm_internal = TRUE, optimizer = "nlminb", aghq_used = FALSE,
    ridge_tau = NULL, convergence = 0L, objective = 100,
    gradient = c(b_fix = 0.0002, theta_rr_B = -0.0003, theta_diag_B = 0.0001),
    parameter_names = c("b_fix", "theta_rr_B", "theta_diag_B"),
    pd_hessian = TRUE, boundary_flags = character(), boundary_diag_indices = integer()
  )
  a <- do.call(classify, base)
  expect_identical(a$case, "A")
  expect_identical(a$polish_status, "NOT_REQUIRED")
  expect_true(a$numerical_admission)

  b_input <- utils::modifyList(base, list(
    gradient = c(b_fix = 0.0002, theta_rr_B = -0.0015, theta_diag_B = 0.0001),
    boundary_flags = "near_zero_sd_B", boundary_diag_indices = 1L
  ))
  b <- do.call(classify, b_input)
  expect_identical(b$case, "B")
  expect_identical(b$polish_status, "ELIGIBLE")
  accepted <- list(eligible = TRUE, attempted = TRUE, accepted = TRUE)
  expect_true(do.call(classify, c(b_input, list(polish = accepted)))$numerical_admission)
  rejected <- list(eligible = TRUE, attempted = TRUE, accepted = FALSE)
  expect_false(do.call(classify, c(b_input, list(polish = rejected)))$numerical_admission)

  ## The Case-E overlap is prohibited by construction: the named-boundary
  ## predicate requires a raw gradient strictly above the raw gate.
  a_boundary <- do.call(classify, utils::modifyList(base, list(
    boundary_flags = "near_zero_sd_B", boundary_diag_indices = 1L
  )))
  expect_identical(a_boundary$case, "A")
  expect_identical(a_boundary$polish_status, "NOT_REQUIRED")

  nonconverged <- do.call(classify, utils::modifyList(base, list(
    convergence = 1L
  )))
  expect_identical(nonconverged$case, "D")
  expect_false(nonconverged$numerical_admission)

  for (block in c("b_fix", "theta_rr_B")) {
    g <- c(b_fix = 0.0002, theta_rr_B = 0.0002, theta_diag_B = 0.0001)
    g[[block]] <- 0.0015
    c_case <- do.call(classify, utils::modifyList(base, list(gradient = g)))
    expect_identical(c_case$case, "C")
    expect_identical(c_case$polish_status, "NO_CANDIDATE")
    expect_false(c_case$numerical_admission)
  }

  tied <- do.call(classify, utils::modifyList(base, list(
    gradient = c(b_fix = 0.0015, theta_rr_B = -0.0015, theta_diag_B = 0.0001)
  )))
  expect_identical(tied$case, "D")
  expect_false(tied$numerical_admission)
  invalid <- do.call(classify, utils::modifyList(base, list(pd_hessian = FALSE)))
  expect_identical(invalid$case, "D")
})

test_that("G2n candidate provenance names a method and retains raw state", {
  record <- gllvmTMB:::.gllvmTMB_isdm_polish_record(
    eligible = TRUE, attempted = TRUE, accepted = FALSE,
    raw_parameter_vector = c(0.1, -0.6, -8.8),
    candidate_parameter_vector = c(0.1, -0.60001, -8.8),
    raw_objective = 100, candidate_objective = 100,
    raw_gradient = c(0.0002, -0.00129, 0.0000005),
    candidate_gradient = c(0.0002, -0.00101, 0.0000005),
    raw_pd_hessian = TRUE, candidate_pd_hessian = TRUE,
    raw_boundary_flags = "near_zero_sd_B",
    candidate_boundary_flags = "near_zero_sd_B",
    boundary_diag_indices = 1L, candidate_boundary_diag_indices = 1L,
    parameter_names = c("b_fix", "theta_rr_B", "theta_diag_B"),
    map_identical = TRUE, candidate_method = "nlminb_retry",
    candidate_attempts = list(selected = list(method = "nlminb_retry"))
  )
  expect_identical(record$candidate_method, "nlminb_retry")
  expect_identical(record$candidate_attempts$selected$method, "nlminb_retry")
  expect_identical(record$raw$max_gradient_parameter_block, "theta_rr_B")
  expect_false(record$accepted)
  expect_error(
    gllvmTMB:::.gllvmTMB_isdm_polish_record(candidate_method = "other"),
    "arg.*none"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_isdm_polish_record(candidate_attempts = "other"),
    "candidate_attempts"
  )
})

test_that("G2n classification creates no optimizer path", {
  classifier_body <- paste(deparse(body(
    gllvmTMB:::.gllvmTMB_isdm_numerical_admission
  )), collapse = "\n")
  expect_false(grepl("run_one\\(|\\.gllvmTMB_isdm_covariance_newton_candidate\\(",
                     classifier_body))
  eligible <- gllvmTMB:::.gllvmTMB_isdm_polish_eligible
  base <- list(
    isdm_internal = TRUE, optimizer = "nlminb", aghq_used = FALSE,
    ridge_tau = NULL, convergence = 0L, objective = 100,
    gradient = c(b_fix = 0.0015, theta_rr_B = 0.0002, theta_diag_B = 0.0001),
    parameter_names = c("b_fix", "theta_rr_B", "theta_diag_B"),
    pd_hessian = TRUE, boundary_flags = character(), boundary_diag_indices = integer()
  )
  expect_false(do.call(eligible, base))
  base$gradient <- c(b_fix = 0.0002, theta_rr_B = 0.0015, theta_diag_B = 0.0001)
  expect_false(do.call(eligible, base))
})
