## Maintainer decision D-293 (2026-09-27): binary (single-trial Bernoulli)
## data get a loading-ridge sweep default in select_lv(), wired via a new
## `binary_ridge` argument (default 2). Rationale/evidence: a ridge
## experiment in this lane (LOOP/lanes/auto-d-20260926/ridge/
## ridge_binary_scaled.R, GLLVM.jl-auto-d-20260926 lane worktree) found
## control(aghq_ridge = 2) recovered true d = 2 in 8/10 simulated Bernoulli
## datasets (20 traits, n = 120) against 4/10 without.
##
## All fits below except the last are fakes returned by a stub `.fitter`
## (select_lv()'s own test hook), following the house convention in
## test-select-lv-guard.R -- but with an INDEPENDENT fake class/S3 method
## (`gllvmTMB_select_lv_ridge_test_fake`), registered in THIS file, so
## `testthat::test_file()` on this file alone (with no other test file
## sourced first) is self-sufficient.

## ---- Fake fit constructor --------------------------------------------------

## A minimal fake fit carrying everything select_lv()'s guard reads:
## $opt$convergence, $sd_report$pdHess, stats::logLik(fit) (dispatched here),
## $aghq$ridge_tau (recorded verbatim in `table$ridge_tau`), and
## $objective_components$optimization_nll (the penalised NLL the
## monotonicity guard reads when the ridge is active -- see `mono_value()`
## in R/select-lv.R). `loglik` is the UNPENALISED log-likelihood; `penalty`
## is the ridge penalty added on top (0.5 * sum(lambda^2) / tau^2, whatever
## a caller wants to stand in for that number), so
## `optimization_nll = -loglik + penalty` exactly mirrors
## `.gllvmTMB_objective_components()` (R/fit-multi.R) by construction.
.ridge_fake_fit <- function(loglik, npar = 5L, nobs = 100L, penalty = 0,
                             ridge_tau = Inf, converged = TRUE, pdhess = TRUE) {
  optimization_nll <- -loglik + penalty
  structure(
    list(
      opt = list(convergence = if (converged) 0L else 1L, objective = optimization_nll),
      sd_report = list(pdHess = pdhess),
      aghq = list(ridge_tau = ridge_tau, penalised = is.finite(ridge_tau) && penalty != 0),
      objective_components = list(
        likelihood_nll = -loglik, ridge_penalty = penalty,
        optimization_nll = optimization_nll
      ),
      .loglik = loglik, .npar = npar, .nobs = nobs
    ),
    class = "gllvmTMB_select_lv_ridge_test_fake"
  )
}

logLik.gllvmTMB_select_lv_ridge_test_fake <- function(object, ...) {
  structure(object$.loglik, df = object$.npar, nobs = object$.nobs, class = "logLik")
}
registerS3method("logLik", "gllvmTMB_select_lv_ridge_test_fake",
                  logLik.gllvmTMB_select_lv_ridge_test_fake)

## Recover the swept d from the (real, but mocked-fitter) formula rewrite.
.ridge_d_of <- function(formula) {
  txt <- paste(deparse(formula), collapse = " ")
  as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
}

.ridge_formula <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)
.ridge_data <- data.frame(unit = 1, trait = 1, value = 1)

.ridge_multitrial_formula <- cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 1)
.ridge_multitrial_data <- data.frame(unit = 1, trait = 1, succ = 3, fail = 2)

## ---- (a)/(b)/(c)/(d)/(e): control(aghq_ridge = ) injection -----------------

test_that("single-trial Bernoulli binomial: every sweep fit's control carries aghq_ridge = binary_ridge (default 2)", {
  captured <- list()
  fitter <- function(formula, data, ..., control = NULL) {
    captured <<- c(captured, list(control))
    ## Mirror the real engine (R/fit-multi.R): report back whatever ridge
    ## scale the control actually carried, so `table$ridge_tau` reflects it.
    rt <- if (!is.null(control) && isTRUE(control$aghq_ridge_explicit)) control$aghq_ridge else Inf
    .ridge_fake_fit(loglik = -500 + 60 * .ridge_d_of(formula), ridge_tau = rt)
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1), .package = "gllvmTMB"
  )
  sel <- select_lv(.ridge_formula, data = .ridge_data, d_max = 3L,
                    family = stats::binomial(), .fitter = fitter)
  expect_length(captured, 3L)
  for (ctrl in captured) {
    expect_true(isTRUE(ctrl$aghq_ridge_explicit))
    expect_equal(ctrl$aghq_ridge, 2)
  }
  expect_true(all(sel$table$ridge_tau == 2))
})

test_that("binary_ridge = Inf disables the default (today's unpenalised behaviour)", {
  captured <- list()
  fitter <- function(formula, data, ..., control = NULL) {
    captured <<- c(captured, list(control))
    .ridge_fake_fit(loglik = -500 + 60 * .ridge_d_of(formula))
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1), .package = "gllvmTMB"
  )
  sel <- select_lv(.ridge_formula, data = .ridge_data, d_max = 3L,
                    family = stats::binomial(), binary_ridge = Inf, .fitter = fitter)
  expect_length(captured, 3L)
  expect_true(all(vapply(captured, is.null, logical(1L))))
  expect_true(all(is.na(sel$table$ridge_tau)))
})

test_that("the caller's own control(aghq_ridge = ) wins over binary_ridge", {
  captured <- list()
  fitter <- function(formula, data, ..., control = NULL) {
    captured <<- c(captured, list(control))
    .ridge_fake_fit(loglik = -500 + 60 * .ridge_d_of(formula), ridge_tau = 5)
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1), .package = "gllvmTMB"
  )
  sel <- select_lv(.ridge_formula, data = .ridge_data, d_max = 2L,
                    family = stats::binomial(),
                    control = gllvmTMBcontrol(aghq_ridge = 5), .fitter = fitter)
  expect_length(captured, 2L)
  for (ctrl in captured) expect_equal(ctrl$aghq_ridge, 5)
  expect_true(all(sel$table$ridge_tau == 5))
})

test_that("a non-binomial family (Poisson) is untouched", {
  captured <- list()
  fitter <- function(formula, data, ..., control = NULL) {
    captured <<- c(captured, list(control))
    .ridge_fake_fit(loglik = -500 + 60 * .ridge_d_of(formula))
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1), .package = "gllvmTMB"
  )
  sel <- select_lv(.ridge_formula, data = .ridge_data, d_max = 2L,
                    family = stats::poisson(), .fitter = fitter)
  expect_true(all(vapply(captured, is.null, logical(1L))))
  expect_true(all(is.na(sel$table$ridge_tau)))
})

test_that("multi-trial binomial via cbind(successes, failures) is untouched", {
  captured <- list()
  fitter <- function(formula, data, ..., control = NULL) {
    captured <<- c(captured, list(control))
    .ridge_fake_fit(loglik = -500 + 60 * .ridge_d_of(formula))
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1), .package = "gllvmTMB"
  )
  sel <- select_lv(.ridge_multitrial_formula, data = .ridge_multitrial_data, d_max = 2L,
                    family = stats::binomial(), .fitter = fitter)
  expect_true(all(vapply(captured, is.null, logical(1L))))
  expect_true(all(is.na(sel$table$ridge_tau)))
})

test_that("multi-trial binomial via weights = n_trials is untouched", {
  captured <- list()
  fitter <- function(formula, data, ..., control = NULL) {
    captured <<- c(captured, list(control))
    .ridge_fake_fit(loglik = -500 + 60 * .ridge_d_of(formula))
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1), .package = "gllvmTMB"
  )
  sel <- select_lv(.ridge_formula, data = .ridge_data, d_max = 2L,
                    family = stats::binomial(), weights = 5, .fitter = fitter)
  expect_true(all(vapply(captured, is.null, logical(1L))))
  expect_true(all(is.na(sel$table$ridge_tau)))
})

## ---- (f): the start_from retry also carries the ridge control -------------

test_that("the start_from retry also carries binary_ridge's control(aghq_ridge = )", {
  captured <- list()
  fitter <- function(formula, data, ..., control = NULL) {
    d <- .ridge_d_of(formula)
    captured <<- c(captured, list(control))
    warm <- !is.null(control) && !is.null(control$start_from)
    ll <- if (d == 1L) -440 else if (d == 2L) -390 else if (warm) -388 else -395
    .ridge_fake_fit(loglik = ll)
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1), .package = "gllvmTMB"
  )
  sel <- select_lv(.ridge_formula, data = .ridge_data, d_max = 3L,
                    family = stats::binomial(), .fitter = fitter)
  retry_ctrls <- Filter(function(ctrl) !is.null(ctrl) && !is.null(ctrl$start_from), captured)
  expect_length(retry_ctrls, 1L)
  expect_true(isTRUE(retry_ctrls[[1L]]$aghq_ridge_explicit))
  expect_equal(retry_ctrls[[1L]]$aghq_ridge, 2)
  a3 <- sel$table[sel$table$d == 3L, ]
  expect_equal(a3$status, "warm_start")
})

## ---- (g): the monotonicity bar uses the penalised objective under the ridge -

test_that("the monotonicity bar uses the penalised objective when the ridge is active, and plain logLik otherwise", {
  ## d = 1: logLik = -500, ridge penalty = 100 -> penalised objective = -600.
  ## d = 2: logLik = -520 (a genuine 20-unit FALL), ridge penalty = 0 ->
  ## penalised objective = -520, which IMPROVES on d = 1's -600.
  fitter <- function(formula, data, ...) {
    d <- .ridge_d_of(formula)
    if (d == 1L) {
      .ridge_fake_fit(loglik = -500, penalty = 100, ridge_tau = 3)
    } else {
      .ridge_fake_fit(loglik = -520, penalty = 0, ridge_tau = 3)
    }
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1), .package = "gllvmTMB"
  )

  ## Ridge active (the caller's own explicit control -- decoupled here from
  ## the binomial auto-detection tested above): d = 2 is NOT rejected, even
  ## though its unpenalised logLik fell, because the penalised objective
  ## improved.
  sel_ridge <- select_lv(.ridge_formula, data = .ridge_data, d_max = 2L,
                          family = stats::poisson(),
                          control = gllvmTMBcontrol(aghq_ridge = 3),
                          warm_start = FALSE, .fitter = fitter)
  a2_ridge <- sel_ridge$table[sel_ridge$table$d == 2L, ]
  expect_equal(a2_ridge$status, "ok")
  expect_equal(a2_ridge$logLik, -520)

  ## Without the ridge (no control override -> plain logLik comparison), the
  ## SAME unpenalised fall (-500 -> -520) IS rejected as nonmonotone.
  sel_plain <- select_lv(.ridge_formula, data = .ridge_data, d_max = 2L,
                          family = stats::poisson(), warm_start = FALSE, .fitter = fitter)
  a2_plain <- sel_plain$table[sel_plain$table$d == 2L, ]
  expect_equal(a2_plain$status, "nonmonotone")
})

## ---- One small real Bernoulli fit: ridge_tau recorded, no runaway ----------

.ridge_real_test_ctrl <- function() {
  gllvmTMBcontrol(optimizer = "optim", optArgs = list(method = "BFGS"), se = FALSE)
}

## Simulate one small Bernoulli dataset from a rank-1 ordinary latent() DGP.
## 10 traits x 60 units, true d = 1: eta_it = beta_t + Lambda[t, 1] * z_i,
## z_i ~ N(0, 1), y_it ~ Bernoulli(plogis(eta_it)).
.ridge_real_dgp <- function(n_units = 60L, n_traits = 10L, seed = 2026) {
  set.seed(seed)
  traits <- paste0("t", seq_len(n_traits))
  units <- paste0("u", seq_len(n_units))
  Lambda <- matrix(seq(0.9, -0.9, length.out = n_traits), ncol = 1L)
  beta <- rep(0, n_traits)
  scores <- matrix(stats::rnorm(n_units), n_units, 1L)
  eta <- outer(rep(1, n_units), beta) + scores %*% t(Lambda)
  df <- do.call(rbind, lapply(seq_along(units), function(i) {
    data.frame(
      unit = units[i], trait = traits,
      value = stats::rbinom(n_traits, size = 1L, prob = stats::plogis(eta[i, ]))
    )
  }))
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  df
}

test_that("a real single-trial Bernoulli sweep records ridge_tau and has no runaway status", {
  data <- .ridge_real_dgp()
  msgs <- testthat::capture_messages(
    sel <- select_lv(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = data, family = stats::binomial(), unit = "unit", trait = "trait",
      d_max = 3L, control = .ridge_real_test_ctrl()
    )
  )
  expect_true(any(grepl("loading ridge", msgs, fixed = TRUE)))
  expect_true(all(sel$table$ridge_tau == 2, na.rm = TRUE))
  expect_false(any(sel$table$status == "runaway"))
  expect_true(sel$selected_d %in% 1:3)
})

## ---- Penalised Hessian under the ridge (Shinichi, 2026-09-28) ---------------
## The ridge is applied in R, outside the TMB template, so sdreport()'s pdHess
## tests the UNPENALISED Hessian at the PENALISED optimum. A fit whose
## unpenalised Hessian is indefinite but whose penalised Hessian is positive
## definite is a proper optimum of what was minimised and must not be rejected.
## The objective below is f(x) = 0.5 x' A x with A indefinite on the ridge
## block (eigenvalues 2 and -0.1); adding 1/tau^2 = 0.25 there makes it PD.
test_that(".select_lv_pd_hessian tests the penalised Hessian under the ridge", {
  A <- matrix(c(2, 0, 0, -0.1), 2, 2)
  par <- c(beta = 0.3, theta_rr_B = 0.2)
  obj <- list(par = par,
              fn = function(x) 0.5 * sum(x * (A %*% x)),
              gr = function(x) as.numeric(A %*% x))
  fit <- list(sd_report = list(pdHess = FALSE), tmb_obj = obj,
              opt = list(par = par), aghq = list(ridge_tau = 2))
  expect_true(gllvmTMB:::.select_lv_pd_hessian(fit))
  ## Without a ridge the sdreport flag stands.
  fit_noridge <- fit; fit_noridge$aghq$ridge_tau <- Inf
  expect_false(gllvmTMB:::.select_lv_pd_hessian(fit_noridge))
  ## A ridge too weak to fix the indefinite direction (1/tau^2 = 0.04 < 0.1).
  fit_weak <- fit; fit_weak$aghq$ridge_tau <- 5
  expect_false(gllvmTMB:::.select_lv_pd_hessian(fit_weak))
  ## sdreport says PD, or was skipped: returned as is.
  expect_true(gllvmTMB:::.select_lv_pd_hessian(
    modifyList(fit, list(sd_report = list(pdHess = TRUE)))))
  expect_true(is.na(gllvmTMB:::.select_lv_pd_hessian(
    modifyList(fit, list(sd_report = NULL)))))
})
