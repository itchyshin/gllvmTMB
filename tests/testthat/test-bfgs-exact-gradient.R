test_that("exact-gradient BFGS recovers a quadratic optimum once", {
  x <- bfgs_quadratic_fixture()
  calls <- list()
  callback <- function(theta, positional_ids) {
    calls[[length(calls) + 1L]] <<- list(theta = theta, ids = positional_ids)
    bfgs_curvature_record(theta, positional_ids, x$covariance)
  }
  out <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    x$obj, x$par, x$objective, bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), callback
  )

  expect_identical(out$estimator, "BFGS_EXACT_GRADIENT_CONTINUATION_V1")
  expect_identical(out$status, "BFGS_NUMERICAL_ADMISSION")
  expect_identical(out$method, "BFGS")
  expect_identical(out$control,
    list(maxit = 500L, reltol = 1e-12, trace = 0L, REPORT = 1L))
  expect_equal(out$raw$gradient,
    stats::setNames(x$gradient, c("beta[1]", "theta[2]", "theta[3]")),
    tolerance = 1e-12)
  expect_equal(unname(out$candidate$parameter_vector), rep(0, 3L),
    tolerance = 1e-7)
  expect_lte(out$candidate$max_gradient, 1e-3)
  expect_true(all(unlist(out$candidate$gates)))
  expect_length(calls, 1L)
  expect_identical(calls[[1L]]$ids, c("beta[1]", "theta[2]", "theta[3]"))
  expect_equal(
    unname(out$curvature$covariance), unname(x$covariance), tolerance = 1e-12
  )
})

test_that("BFGS rejects every change to method, controls, or thresholds", {
  x <- bfgs_quadratic_fixture()
  callback <- function(theta, positional_ids) {
    bfgs_curvature_record(theta, positional_ids, x$covariance)
  }
  overrides <- list(
    list(method = "L-BFGS-B"),
    list(control = list(maxit = 501L, reltol = 1e-12, trace = 0L, REPORT = 1L)),
    list(control = list(maxit = 500L, reltol = 1e-10, trace = 0L, REPORT = 1L)),
    list(raw_gradient_gate = 2e-3),
    list(health_gradient_gate = 2e-2),
    list(condition_limit = 1e9)
  )
  for (override in overrides) {
    args <- c(list(
      obj = x$obj, par = x$par, expected_objective = x$objective,
      signature = bfgs_signature_fixture(), raw_state = bfgs_raw_state_fixture(),
      curvature_fn = callback
    ), override)
    out <- do.call(
      gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation, args
    )
    expect_identical(out$status, "BFGS_RAW_INELIGIBLE", info = names(override))
    expect_null(out$optimizer, info = names(override))
  }
})

test_that("BFGS malformed raw inputs and disabled-route changes fail closed", {
  x <- bfgs_quadratic_fixture()
  callback <- function(theta, positional_ids) {
    bfgs_curvature_record(theta, positional_ids, x$covariance)
  }
  bad_states <- lapply(c("retry_enabled", "profile_enabled", "aghq", "ridge"),
    function(field) {
      state <- bfgs_raw_state_fixture()
      state[[field]] <- TRUE
      state
    })
  for (state in bad_states) {
    out <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
      x$obj, x$par, x$objective, bfgs_signature_fixture(), state, callback
    )
    expect_identical(out$status, "BFGS_RAW_INELIGIBLE")
    expect_null(out$optimizer)
  }
  mismatch <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    x$obj, x$par, x$objective + 1, bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), callback
  )
  expect_identical(mismatch$status, "BFGS_RAW_INELIGIBLE")
  expect_identical(mismatch$reason, "raw_objective_replay_mismatch")

  nonfinite <- x$par
  nonfinite[[1L]] <- Inf
  rejected <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    x$obj, nonfinite, x$objective, bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), callback
  )
  expect_identical(rejected$status, "BFGS_RAW_INELIGIBLE")
})

test_that("BFGS retains optimizer errors distinctly from raw ineligibility", {
  x <- bfgs_quadratic_fixture()
  gradient_calls <- 0L
  failing_obj <- list(
    fn = x$obj$fn,
    gr = function(theta) {
      gradient_calls <<- gradient_calls + 1L
      if (gradient_calls > 1L) stop("sealed optimizer gradient failure")
      x$obj$gr(theta)
    }
  )
  callback <- function(theta, positional_ids) {
    bfgs_curvature_record(theta, positional_ids, x$covariance)
  }
  out <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    failing_obj, x$par, x$objective, bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), callback
  )
  expect_identical(out$status, "BFGS_OPTIMIZER_ERROR")
  expect_match(out$reason, "sealed optimizer gradient failure", fixed = TRUE)
  expect_null(out$candidate)
})

test_that("BFGS infrastructure holds are distinct from optimizer failures", {
  x <- bfgs_quadratic_fixture()
  callback <- function(theta, positional_ids) {
    bfgs_curvature_record(theta, positional_ids, x$covariance)
  }
  missing_interface <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    list(fn = x$obj$fn), x$par, x$objective, bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), callback
  )
  expect_identical(missing_interface$status, "BFGS_INFRASTRUCTURE_HOLD")
  expect_identical(
    missing_interface$reason, "objective_or_curvature_interface_unavailable"
  )
  expect_null(missing_interface$optimizer)

  raw_unavailable <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    list(
      fn = function(theta) stop("sealed raw objective unavailable"),
      gr = x$obj$gr
    ),
    x$par, x$objective, bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), callback
  )
  expect_identical(raw_unavailable$status, "BFGS_INFRASTRUCTURE_HOLD")
  expect_identical(
    raw_unavailable$reason, "raw_objective_or_gradient_unavailable"
  )
  expect_null(raw_unavailable$optimizer)

  outside_objective_calls <- 0L
  replay_fails <- list(
    fn = function(theta) {
      ## The helper strips names for its exact raw/candidate replays, whereas
      ## stats::optim preserves the named parameter vector passed to it.
      if (is.null(names(theta))) {
        outside_objective_calls <<- outside_objective_calls + 1L
        if (outside_objective_calls > 1L) {
          stop("sealed candidate replay infrastructure failure")
        }
      }
      x$obj$fn(theta)
    },
    gr = x$obj$gr
  )
  held <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    replay_fails, x$par, x$objective, bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), callback
  )
  expect_identical(held$status, "BFGS_INFRASTRUCTURE_HOLD")
  expect_identical(held$reason, "candidate_exact_replay_unavailable")
  expect_false(is.null(held$optimizer))
  expect_null(held$candidate)
})

test_that("BFGS curvature taxonomy separates unavailable and invalid", {
  x <- bfgs_quadratic_fixture()
  unavailable <- function(theta, positional_ids) {
    bfgs_curvature_record(theta, positional_ids, x$covariance,
      available = FALSE, reason = "sdreport_unavailable",
      error = "sealed callback error")
  }
  held <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    x$obj, x$par, x$objective, bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), unavailable
  )
  expect_identical(held$status, "BFGS_CURVATURE_UNAVAILABLE")
  expect_identical(held$reason, "sdreport_unavailable")

  invalid <- list(
    nonfinite = { z <- x$covariance; z[1, 1] <- Inf; z },
    nonsymmetric = { z <- x$covariance; z[1, 2] <- 0.1; z },
    non_pd = diag(c(1, 1, -1)),
    boundary_correlation = matrix(c(1, 1, 0, 1, 1, 0, 0, 0, 1), 3L, 3L),
    ill_conditioned = diag(c(1, 1, 1e-9))
  )
  for (label in names(invalid)) {
    callback <- local({
      covariance <- invalid[[label]]
      function(theta, positional_ids) {
        bfgs_curvature_record(theta, positional_ids, covariance)
      }
    })
    out <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
      x$obj, x$par, x$objective, bfgs_signature_fixture(),
      bfgs_raw_state_fixture(), callback
    )
    expect_identical(out$status, "BFGS_CURVATURE_INVALID", info = label)
  }

  false_pdhess <- function(theta, positional_ids) {
    bfgs_curvature_record(theta, positional_ids, x$covariance, pd_hess = FALSE)
  }
  invalid_flag <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    x$obj, x$par, x$objective, bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), false_pdhess
  )
  expect_identical(invalid_flag$status, "BFGS_CURVATURE_INVALID")

  callback_error <- function(theta, positional_ids) {
    stop("sealed sdreport callback error")
  }
  errored <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    x$obj, x$par, x$objective, bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), callback_error
  )
  expect_identical(errored$status, "BFGS_CURVATURE_UNAVAILABLE")
  expect_identical(errored$reason, "curvature_callback_error")

  permuted <- function(theta, positional_ids) {
    ans <- bfgs_curvature_record(theta, positional_ids, x$covariance)
    ans$par.fixed <- theta[c(2, 1, 3)]
    ans
  }
  misaligned <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    x$obj, x$par, x$objective, bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), permuted
  )
  expect_identical(misaligned$status, "BFGS_CURVATURE_UNAVAILABLE")
  expect_identical(misaligned$reason, "curvature_positional_identity_failure")
})

test_that("converged BFGS without the gradient gate is a clean non-admission", {
  obj <- list(
    fn = function(theta) 1e12 + 0.5e-6 * (theta[[1L]] - 1)^2,
    gr = function(theta) 1e-6 * (theta - 1)
  )
  par <- stats::setNames(4001, "beta")
  callback_calls <- 0L
  callback <- function(theta, positional_ids) {
    callback_calls <<- callback_calls + 1L
    bfgs_curvature_record(theta, positional_ids, matrix(1e6, 1L, 1L))
  }
  out <- gllvmTMB:::.gllvmTMB_isdm_bfgs_exact_gradient_continuation(
    obj, par, obj$fn(par), bfgs_signature_fixture(),
    bfgs_raw_state_fixture(), callback
  )
  expect_identical(out$optimizer$convergence, 0L)
  expect_identical(out$status, "BFGS_NO_NUMERICAL_ADMISSION")
  expect_false(out$candidate$gates$gradient)
  expect_true(is.na(out$candidate$gates$curvature))
  expect_null(out$curvature)
  expect_identical(callback_calls, 0L)
})
