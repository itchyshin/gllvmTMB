test_that("G3 compiled unit evaluates a sealed Newton grid without optimisation", {
  skip_if_not_installed("TMB")
  scratch <- tempfile("g3-cloglog-unit-")
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
    ## Deliberately just off the three scalar cloglog MLEs: the compiled
    ## objective is eligible for the sealed G3 (1e-3, 1e-2) raw-gradient
    ## interval without running an optimiser.
    parameters = list(eta = c(-0.9012205, 0.0955478, 0.0954478)),
    DLL = "gllvmTMB_cloglog_tail", silent = TRUE
  )
  raw_par <- obj$par
  names(raw_par) <- c("b_fix", "theta_rr_B", "theta_diag_B")
  lower <- stats::setNames(rep(-Inf, length(raw_par)), names(raw_par))
  upper <- stats::setNames(rep(Inf, length(raw_par)), names(raw_par))
  signature_names <- gllvmTMB:::.gllvmTMB_isdm_g3_signature_names
  signature <- as.list(stats::setNames(paste0("sealed-", signature_names), signature_names))
  raw_state <- list(optimizer = "nlminb", convergence = 0L, pd_hessian = TRUE,
    boundary_flags = character(), tie_count = 1L, is_isdm = TRUE, aghq = FALSE,
    ridge = FALSE, retry_enabled = FALSE, profile_enabled = FALSE,
    source_gate = "G3_COMPILED_UNIT")
  raw_fn <- obj$fn(raw_par)
  raw_gr <- obj$gr(raw_par)
  trials <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    obj, raw_par, lower, upper, signature, raw_state,
    raw_gradient_gate = 1e-3, health_gradient_gate = 1e-2
  )

  expect_identical(trials$status, "TRIALS_EVALUATED")
  expect_equal(trials$raw$objective, raw_fn)
  expect_equal(trials$raw$gradient, stats::setNames(as.numeric(raw_gr), names(raw_par)))
  expect_identical(trials$signature, signature)
  expect_identical(vapply(trials$trials, `[[`, numeric(1L), "alpha"), 2^-(0:8))
  expect_length(trials$trials, 9L)
  expect_true(all(vapply(trials$trials, function(x) x$status %in%
    c("ACCEPTED", "REJECTED", "INFEASIBLE", "ERROR"), logical(1L))))
  expect_true(all(vapply(trials$trials, function(x)
    identical(names(x$parameter_vector), names(raw_par)), logical(1L))))
  expect_true(all(vapply(trials$trials, function(x)
    isTRUE(all.equal(x$objective, obj$fn(x$parameter_vector))), logical(1L))))
  expect_true(all(vapply(trials$trials, function(x)
    is.matrix(x$hessian) && is.finite(x$condition), logical(1L))))

  ## A sealed but deliberately zero-width bound box makes every candidate
  ## infeasible.  The runner must retain the entire grid rather than stop after
  ## its first rejection.
  locked <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    obj, raw_par, raw_par, raw_par, signature, raw_state,
    raw_gradient_gate = 1e-3, health_gradient_gate = 1e-2
  )
  expect_identical(locked$status, "TRIALS_EVALUATED")
  expect_identical(vapply(locked$trials, `[[`, numeric(1L), "alpha"), 2^-(0:8))
  expect_true(all(vapply(locked$trials, function(x)
    identical(x$status, "INFEASIBLE") && identical(x$reason, "candidate_outside_bounds"), logical(1L))))

  bad_signature <- signature[-1L]
  invalid <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    obj, raw_par, lower, upper, bad_signature, raw_state,
    raw_gradient_gate = 1e-3, health_gradient_gate = 1e-2
  )
  expect_identical(invalid$status, "INVALID_INPUT")
})
