test_that("compiled fixed-effect BFGS uses the exact cloglog gradient", {
  skip_if_not_installed("TMB")
  scratch <- tempfile("bfgs-cloglog-fixed-")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  fixture_dir <- test_path("fixtures")
  header <- test_path("..", "..", "src", "gllvmTMB_cloglog.h")
  skip_if_not(file.exists(header), "production cloglog header unavailable")
  expect_true(all(file.copy(c(
    file.path(fixture_dir, "gllvmTMB_cloglog_tail.cpp"), header
  ), scratch)))
  cpp <- file.path(scratch, "gllvmTMB_cloglog_tail.cpp")
  expect_equal(TMB::compile(cpp), 0L)
  dll <- TMB::dynlib(file.path(scratch, "gllvmTMB_cloglog_tail"))
  dyn.load(dll)
  on.exit(dyn.unload(dll), add = TRUE)

  tmb_obj <- TMB::MakeADFun(
    data = list(y = c(1, 2, 2), n_trials = rep(3, 3)),
    parameters = list(eta = c(-0.9012205, 0.0955478, 0.0954478)),
    DLL = "gllvmTMB_cloglog_tail", silent = TRUE
  )
  par <- tmb_obj$par
  names(par) <- c("b_fix", "theta_rr_B", "theta_diag_B")
  gradient_calls <- 0L
  obj <- list(
    fn = function(theta) tmb_obj$fn(theta),
    gr = function(theta) {
      gradient_calls <<- gradient_calls + 1L
      unname(tmb_obj$gr(theta))
    }
  )
  callback <- function(theta, positional_ids) {
    report <- tryCatch(
      TMB::sdreport(tmb_obj, par.fixed = unname(theta)), error = identity
    )
    if (inherits(report, "error")) {
      return(list(
        available = FALSE, reason = "sdreport_unavailable",
        par.fixed = NULL, cov.fixed = NULL, pdHess = NA,
        positional_ids = positional_ids, error = conditionMessage(report)
      ))
    }
    covariance <- report$cov.fixed
    dimnames(covariance) <- list(positional_ids, positional_ids)
    list(
      available = TRUE, reason = "available", par.fixed = theta,
      cov.fixed = covariance, pdHess = report$pdHess,
      positional_ids = positional_ids, error = NA_character_
    )
  }
  out <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    obj, par, obj$fn(par), bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), callback
  )

  expect_identical(out$status, "BFGS_NUMERICAL_ADMISSION")
  expect_gt(gradient_calls, 1L)
  expect_equal(out$candidate$objective, tmb_obj$fn(out$candidate$parameter_vector),
    tolerance = 1e-12)
  expect_equal(out$candidate$gradient,
    stats::setNames(as.numeric(tmb_obj$gr(out$candidate$parameter_vector)),
      names(out$candidate$parameter_vector)), tolerance = 1e-10)
  expect_true(out$curvature$positive_definite)
})

test_that("random-effect BFGS reaches candidate-specific sdreport curvature", {
  skip_if_not_installed("TMB")
  scratch <- tempfile("bfgs-gaussian-random-")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  source_cpp <- test_path("fixtures", "bfgs_gaussian_random_intercept.cpp")
  expect_true(file.copy(source_cpp, scratch))
  cpp <- file.path(scratch, basename(source_cpp))
  expect_equal(TMB::compile(cpp), 0L)
  dll <- TMB::dynlib(file.path(scratch, "bfgs_gaussian_random_intercept"))
  dyn.load(dll)
  on.exit(dyn.unload(dll), add = TRUE)

  obj <- TMB::MakeADFun(
    data = list(
      y = c(-1.1, -0.8, 0.8, 1.0, -0.5, -0.2, 0.3, 0.5),
      group = rep(0:3, each = 2L), log_obs_sd = log(0.35)
    ),
    parameters = list(beta = 0, log_sd_group = log(0.7), u = rep(0, 4L)),
    random = "u", DLL = "bfgs_gaussian_random_intercept", silent = TRUE
  )
  expect_error(obj$he(obj$par))

  optimum <- stats::nlminb(obj$par, obj$fn, obj$gr,
    control = list(eval.max = 100L, iter.max = 100L))
  optimum_cov <- TMB::sdreport(obj, par.fixed = optimum$par)$cov.fixed
  target_gradient <- c(beta = 0.004, log_sd_group = 0.002)
  raw_par <- optimum$par + drop(optimum_cov %*% target_gradient)
  names(raw_par) <- names(optimum$par)
  raw_gradient <- obj$gr(raw_par)
  callback_calls <- list()
  callback <- function(theta, positional_ids) {
    callback_calls[[length(callback_calls) + 1L]] <<- theta
    report <- tryCatch(
      TMB::sdreport(obj, par.fixed = unname(theta)), error = identity
    )
    if (inherits(report, "error")) {
      return(list(
        available = FALSE, reason = "sdreport_unavailable",
        par.fixed = NULL, cov.fixed = NULL, pdHess = NA,
        positional_ids = positional_ids, error = conditionMessage(report)
      ))
    }
    covariance <- report$cov.fixed
    dimnames(covariance) <- list(positional_ids, positional_ids)
    list(
      available = TRUE, reason = "available", par.fixed = theta,
      cov.fixed = covariance, pdHess = report$pdHess,
      positional_ids = positional_ids, error = NA_character_
    )
  }
  out <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    obj, raw_par, obj$fn(raw_par), bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), callback
  )

  expect_true(max(abs(raw_gradient)) > 1e-3)
  expect_true(max(abs(raw_gradient)) < 1e-2)
  expect_identical(out$status, "BFGS_NUMERICAL_ADMISSION")
  expect_length(callback_calls, 1L)
  expect_identical(names(out$candidate$parameter_vector),
    paste0(names(raw_par), "[", seq_along(raw_par), "]"))
  expect_true(all(is.finite(out$curvature$covariance)))
  expect_true(out$curvature$symmetric)
  expect_true(out$curvature$positive_definite)
  expect_lte(out$curvature$condition, 1e8)
})
