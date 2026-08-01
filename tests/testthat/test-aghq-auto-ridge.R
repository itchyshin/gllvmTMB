make_auto_ridge_fit <- function(tau = Inf, converged = TRUE,
                                loading = matrix(c(2, 1), ncol = 1),
                                k = 9L, n_starts = 2L) {
  structure(list(
    aghq = list(
      used = TRUE,
      converged = converged,
      k = k,
      n_starts = n_starts,
      ridge_tau = tau
    ),
    random = "z_B",
    tmb_data = list(
      use_rr_B = 1L,
      family_id_vec = rep(1L, 8),
      n_trials = rep(1, 8),
      diag_B_skip = c(1L, 1L),
      n_traits = 2L,
      d_B = 1L
    ),
    report = list(Lambda_B = loading)
  ), class = c("gllvmTMB_multi", "gllvmTMB"))
}

capture_auto_ridge_warnings <- function(expr) {
  warnings <- character()
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = warnings)
}

test_that("aghq_ridge auto is explicit and selects the calibrated node rule", {
  control <- gllvmTMBcontrol(aghq_ridge = "auto")
  expect_identical(control$aghq_ridge, "auto")
  expect_identical(control$aghq, 9L)
  expect_true(control$aghq_ridge_explicit)

  expect_error(
    gllvmTMBcontrol(aghq = FALSE, aghq_ridge = "auto"),
    "cannot be combined"
  )
  expect_error(gllvmTMBcontrol(aghq_ridge = "adaptive"),
               "positive number")

  numeric_control <- gllvmTMBcontrol(aghq = 9, aghq_ridge = 2)
  expect_identical(numeric_control$aghq, 9L)
  expect_identical(numeric_control$aghq_ridge, 2)
})

test_that("auto tau uses the unpenalised loading scale and cap", {
  fit <- make_auto_ridge_fit(loading = matrix(c(12, 0), ncol = 1))
  decision <- gllvmTMB:::.gllvmTMB_aghq_auto_tau(fit, cap = 6)
  expect_true(decision$ok)
  expect_equal(decision$tau_raw, 12 / sqrt(2))
  expect_equal(decision$tau_used, 6)
  expect_true(decision$clipped)

  fit$report$Lambda_B[,] <- c(0.1, 0.1)
  decision <- gllvmTMB:::.gllvmTMB_aghq_auto_tau(fit, cap = 6)
  expect_equal(decision$tau_raw, 1)
  expect_equal(decision$tau_used, 1)
  expect_false(decision$clipped)
})

test_that("auto route starts the candidate from a valid AGHQ pilot", {
  calls <- list()
  fit_once <- function(control) {
    calls[[length(calls) + 1L]] <<- control
    if (identical(control$aghq_ridge, Inf)) {
      return(make_auto_ridge_fit(tau = Inf))
    }
    make_auto_ridge_fit(tau = control$aghq_ridge)
  }
  control <- gllvmTMBcontrol(aghq = 5, aghq_ridge = "auto")
  rlang::reset_warning_verbosity("gllvmTMB-aghq-auto-ridge")
  observed <- capture_auto_ridge_warnings(
    gllvmTMB:::.gllvmTMB_fit_aghq_auto_ridge(fit_once, control)
  )
  fit <- observed$value
  expect_true(any(grepl("experimental", observed$warnings)))

  expect_length(calls, 2L)
  expect_identical(calls[[1]]$aghq, 9L)
  expect_identical(calls[[1]]$aghq_ridge, Inf)
  expect_true(calls[[1]]$aghq_multistart)
  expect_identical(calls[[2]]$aghq, 5L)
  expect_equal(calls[[2]]$aghq_ridge, sqrt(5 / 2))
  expect_identical(calls[[2]]$start_from, make_auto_ridge_fit(tau = Inf))
  expect_identical(fit$aghq$ridge_auto$selected, "auto")
  expect_false(fit$aghq$ridge_auto$fallback)
  expect_identical(fit$aghq$ridge_source,
                   "auto_unpenalised_multistart_aghq")
})

test_that("invalid pilot transparently returns an independent tau-2 fit", {
  calls <- list()
  fit_once <- function(control) {
    calls[[length(calls) + 1L]] <<- control
    if (identical(control$aghq_ridge, Inf)) {
      return(make_auto_ridge_fit(tau = Inf, converged = FALSE))
    }
    make_auto_ridge_fit(tau = control$aghq_ridge)
  }
  control <- gllvmTMBcontrol(aghq = 9, aghq_ridge = "auto")
  rlang::reset_warning_verbosity("gllvmTMB-aghq-auto-ridge")
  observed <- capture_auto_ridge_warnings(
    gllvmTMB:::.gllvmTMB_fit_aghq_auto_ridge(fit_once, control)
  )
  fit <- observed$value
  expect_true(any(grepl("fallback", observed$warnings)))

  expect_length(calls, 2L)
  expect_identical(calls[[2]]$aghq_ridge, 2)
  expect_null(calls[[2]]$start_from)
  expect_true(fit$aghq$ridge_auto$fallback)
  expect_identical(fit$aghq$ridge_auto$selected, "fixed2_fallback")
  expect_match(fit$aghq$ridge_auto$fallback_reason, "did not converge")
  expect_identical(fit$aghq$ridge_source, "fixed2_fallback")
})

test_that("models outside the calibrated scope fall back without blocking", {
  calls <- list()
  fit_once <- function(control) {
    calls[[length(calls) + 1L]] <<- control
    fit <- make_auto_ridge_fit(tau = control$aghq_ridge)
    if (identical(control$aghq_ridge, Inf)) {
      fit$tmb_data$family_id_vec[] <- 2L
    }
    fit
  }
  control <- gllvmTMBcontrol(aghq = 9, aghq_ridge = "auto")
  rlang::reset_warning_verbosity("gllvmTMB-aghq-auto-ridge")
  observed <- capture_auto_ridge_warnings(
    gllvmTMB:::.gllvmTMB_fit_aghq_auto_ridge(fit_once, control)
  )
  fit <- observed$value
  expect_true(any(grepl("outside the calibrated", observed$warnings)))

  expect_true(fit$aghq$ridge_auto$fallback)
  expect_match(fit$aghq$ridge_auto$fallback_reason,
               "outside the calibrated")
})
