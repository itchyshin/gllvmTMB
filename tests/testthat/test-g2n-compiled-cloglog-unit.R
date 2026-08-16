test_that("G2n compiled unit preserves finite PA-cloglog objective derivatives", {
  skip_if_not_installed("TMB")
  scratch <- tempfile("g2n-cloglog-unit-")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  fixture_dir <- test_path("fixtures")
  header <- test_path("..", "..", "src", "gllvmTMB_cloglog.h")
  skip_if_not(file.exists(header), "production cloglog header unavailable")
  file.copy(c(file.path(fixture_dir, "gllvmTMB_cloglog_tail.cpp"), header), scratch)
  cpp <- file.path(scratch, "gllvmTMB_cloglog_tail.cpp")
  expect_equal(TMB::compile(cpp), 0L)
  dll <- TMB::dynlib(file.path(scratch, "gllvmTMB_cloglog_tail"))
  dyn.load(dll)
  on.exit(dyn.unload(dll), add = TRUE)

  obj <- TMB::MakeADFun(
    data = list(y = c(1, 2, 2), n_trials = rep(3, 3)),
    parameters = list(eta = c(-40, 0, 40)),
    DLL = "gllvmTMB_cloglog_tail", silent = TRUE
  )
  raw_par <- obj$par
  names(raw_par) <- c("b_fix", "theta_rr_B", "theta_diag_B")
  raw_objective <- obj$fn(raw_par)
  raw_gradient <- obj$gr(raw_par)
  covariance <- diag(c(0.05, 0.04, 0.03))
  dimnames(covariance) <- list(names(raw_par), names(raw_par))
  candidate_par <- gllvmTMB:::.gllvmTMB_isdm_covariance_newton_candidate(
    raw_par, as.numeric(raw_gradient), covariance
  )
  candidate_objective <- obj$fn(candidate_par)
  candidate_gradient <- obj$gr(candidate_par)

  expect_true(is.finite(raw_objective))
  expect_true(all(is.finite(raw_gradient)))
  expect_true(is.finite(candidate_objective))
  expect_true(all(is.finite(candidate_gradient)))
  expect_true(all(is.finite(obj$he(obj$par))))

  ## This is a compiled, no-optimizer Case-B candidate/provenance unit: the
  ## production covariance-Newton helper receives an explicit SPD covariance,
  ## and the compiled cloglog objective supplies raw/candidate gradients.
  record <- gllvmTMB:::.gllvmTMB_isdm_polish_record(
    eligible = TRUE, attempted = TRUE, accepted = FALSE,
    raw_parameter_vector = raw_par, candidate_parameter_vector = candidate_par,
    raw_convergence = 0L,
    raw_objective = raw_objective, candidate_objective = candidate_objective,
    raw_gradient = raw_gradient, candidate_gradient = candidate_gradient,
    raw_pd_hessian = TRUE, candidate_pd_hessian = TRUE,
    raw_boundary_flags = "near_zero_sd_B",
    candidate_boundary_flags = "near_zero_sd_B",
    boundary_diag_indices = 1L, candidate_boundary_diag_indices = 1L,
    parameter_names = c("b_fix", "theta_rr_B", "theta_diag_B"),
    map_identical = TRUE, candidate_method = "covariance_newton",
    candidate_attempts = list(
      covariance_newton = list(
        method = "covariance_newton", covariance = covariance, accepted = FALSE
      )
    )
  )
  expect_identical(record$candidate_method, "covariance_newton")
  expect_equal(record$raw$gradient, as.numeric(raw_gradient))
  expect_equal(record$candidate$gradient, as.numeric(candidate_gradient))
})
