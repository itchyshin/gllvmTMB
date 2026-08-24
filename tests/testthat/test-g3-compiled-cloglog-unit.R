test_that("G3 compiled unit evaluates a sealed Newton grid without optimisation", {
  fd_gradient_jacobian <- function(object, theta, multiplier) {
    p <- length(theta)
    out <- matrix(NA_real_, p, p)
    for (j in seq_len(p)) {
      h <- multiplier * .Machine$double.eps^(1 / 3) * max(1, abs(theta[[j]]))
      delta <- rep(0, p)
      delta[[j]] <- h
      out[, j] <- (object$gr(theta + delta) - object$gr(theta - delta)) / (2 * h)
    }
    out
  }
  skip_if_not_installed("TMB")
  scratch <- tempfile("g3-cloglog-unit-")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  fixture_dir <- test_path("fixtures")
  header <- test_path("..", "..", "src", "gllvmTMB_cloglog.h")
  skip_if_not(file.exists(header), "production cloglog header unavailable")
  file.copy(c(file.path(fixture_dir, "gllvmTMB_cloglog_tail.cpp"), header), scratch)
  cpp <- file.path(scratch, "gllvmTMB_cloglog_tail.cpp")
  expect_equal(.compile_tmb_fixture(cpp), 0L)
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
  names(raw_par) <- c("b_fix[1]", "theta_rr_B[2]", "theta_diag_B[3]")
  g3_obj <- list(
    fn = function(theta) obj$fn(theta),
    gr = function(theta) unname(obj$gr(theta))
  )
  lower <- stats::setNames(rep(-Inf, length(raw_par)), names(raw_par))
  upper <- stats::setNames(rep(Inf, length(raw_par)), names(raw_par))
  signature_names <- gllvmTMB:::.gllvmTMB_isdm_g3_signature_names
  signature <- as.list(stats::setNames(paste0("sealed-", signature_names), signature_names))
  raw_state <- list(optimizer = "nlminb", convergence = 0L, pd_hessian = TRUE,
    boundary_flags = character(), tie_count = 1L, is_isdm = TRUE, aghq = FALSE,
    ridge = FALSE, retry_enabled = FALSE, profile_enabled = FALSE,
    source_gate = "G3_COMPILED_UNIT")
  signature$source_gate <- raw_state$source_gate
  raw_fn <- obj$fn(raw_par)
  raw_gr <- obj$gr(raw_par)
  raw_he <- obj$he(raw_par)
  raw_sd <- TMB::sdreport(obj, par.fixed = unname(raw_par))
  expect_equal(solve(raw_sd$cov.fixed), raw_he, tolerance = 1e-6)
  for (multiplier in c(0.5, 1, 2)) {
    fd_he <- fd_gradient_jacobian(obj, raw_par, multiplier)
    expect_equal(raw_he, fd_he, tolerance = 1e-6)
  }
  curvature_fn <- function(theta, positional_ids) {
    report <- tryCatch(TMB::sdreport(obj, par.fixed = unname(theta)), error = identity)
    if (inherits(report, "error")) {
      return(list(available = FALSE, reason = "sdreport_error", par.fixed = NULL,
        cov.fixed = NULL, pdHess = NA, positional_ids = positional_ids,
        error = conditionMessage(report)))
    }
    covariance <- report$cov.fixed
    dimnames(covariance) <- list(positional_ids, positional_ids)
    list(available = TRUE, reason = "available", par.fixed = theta,
      cov.fixed = covariance, pdHess = report$pdHess,
      positional_ids = positional_ids, error = NA_character_)
  }
  trials <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    g3_obj, raw_par, lower, upper, signature, raw_state,
    curvature_fn = curvature_fn,
    raw_gradient_gate = 1e-3, health_gradient_gate = 1e-2
  )

  expect_identical(trials$status, "G3_NUMERICAL_ADMISSION")
  expect_equal(trials$raw$objective, raw_fn)
  expect_equal(trials$raw$gradient, stats::setNames(as.numeric(raw_gr), names(raw_par)))
  expect_identical(trials$signature, signature)
  expect_identical(vapply(trials$trials, `[[`, numeric(1L), "alpha"), 2^-(0:8))
  expect_length(trials$trials, 9L)
  expect_true(all(vapply(trials$trials, function(x) x$status %in%
    c("ACCEPTED", "REJECTED", "ERROR"), logical(1L))))
  expect_true(all(vapply(trials$trials, function(x)
    identical(names(x$parameter_vector), names(raw_par)), logical(1L))))
  expect_true(all(vapply(trials$trials, function(x)
    isTRUE(all.equal(x$objective, obj$fn(x$parameter_vector))), logical(1L))))
  guarded <- Filter(function(x) is.list(x$curvature), trials$trials)
  expect_length(guarded, 1L)
  expect_true(all(vapply(guarded, function(x)
    is.matrix(x$curvature$covariance) && is.finite(x$condition), logical(1L))))

  ## Bounds wide enough for every frozen FD point but narrower than the full
  ## Newton step reject the only gradient-passing candidate. The helper must
  ## still retain the entire grid rather than stop after that rejection.
  fd_margin <- 4 * .Machine$double.eps^(1 / 3) * pmax(1, abs(raw_par))
  locked <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    g3_obj, raw_par, raw_par - fd_margin, raw_par + fd_margin, signature, raw_state,
    curvature_fn = curvature_fn,
    raw_gradient_gate = 1e-3, health_gradient_gate = 1e-2
  )
  expect_identical(locked$status, "G3_NO_ACCEPTED_TRIAL")
  expect_identical(vapply(locked$trials, `[[`, numeric(1L), "alpha"), 2^-(0:8))
  expect_true(any(vapply(locked$trials, function(x)
    identical(x$status, "REJECTED") && identical(x$reason, "candidate_bounds_gate"), logical(1L))))

  bad_signature <- signature[-1L]
  invalid <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    g3_obj, raw_par, lower, upper, bad_signature, raw_state,
    curvature_fn = curvature_fn,
    raw_gradient_gate = 1e-3, health_gradient_gate = 1e-2
  )
  expect_identical(invalid$status, "G3_RAW_INELIGIBLE")
})
