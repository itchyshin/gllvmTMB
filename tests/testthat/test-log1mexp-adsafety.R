## AD-safety of gll_log1mexp's CondExp branches, on the SHIPPED Laplace
## ordinal_probit path (fid 14).
##
## THE DEFECT THIS GUARDS. CppAD::CondExp evaluates BOTH branches, so both must
## be finite even when only one is selected. `gll_log1mexp` had an argument range
## where neither was: for log_p in (-1.1e-16, 0] the series branch takes log(0)
## and the direct branch takes log(1 - exp(tiny)) = log(0).
##
## It is reachable through `gll_log_pnorm_diff`, whose `gll_log_pnorm` uses
## log(pnorm(x)) rather than a log-scale CDF. pnorm(x) rounds to EXACTLY 1.0 for
## x > 8.2924, so when both ordinal cutpoints sit more than ~8.3 from eta on the
## same side, the two log-probabilities are bit-identical and their difference is
## exactly 0.
##
## WHY gr() CANNOT SEE IT. A non-finite value on an UNSELECTED CondExp branch
## leaves fn() and gr() finite AND CORRECT, and poisons only he(). That is
## measured and documented at inst/tmb/gllvmTMB_va_r3.cpp:154-180. Every
## assertion below therefore checks he(); a gradient-only test would pass against
## the defect and is worthless here.

test_that("gll_log1mexp keeps BOTH CondExp branches finite at its ceiling", {
  ## R transcription of the exact C++ formulae, double precision. This pins the
  ## arithmetic the fix relies on without needing a fit -- in particular that the
  ## ceiling MAGNITUDE is load bearing.
  branches <- function(log_p, ceil = -1.2e-16) {
    ac <- min(log_p, ceil)
    u <- -ac
    c(series = log(u - u^2 / 2 + u^3 / 6), direct = log(1 - exp(ac)))
  }
  ## the whole reachable hazard interval, not just exactly zero
  for (lp in c(0, -1e-20, -1e-17, -1e-16, -1.2e-16, -1e-15, -1e-9, -1e-3, -0.5)) {
    expect_true(all(is.finite(branches(lp))),
                info = paste("log_p =", lp))
  }

  ## the ceiling must sit at the unit roundoff: a smaller floor rescues the
  ## series branch but leaves the DIRECT branch at -Inf, because exp(tiny)
  ## rounds back to exactly 1.
  expect_false(all(is.finite(branches(0, ceil = -1e-300))))
  expect_false(all(is.finite(branches(0, ceil = -1e-20))))
  expect_true(all(is.finite(branches(0, ceil = -1.2e-16))))

  ## and it must not perturb ordinary arguments
  unclamped <- function(log_p) {
    u <- -log_p
    if (u < 1e-6) log(u - u^2 / 2 + u^3 / 6) else log(1 - exp(log_p))
  }
  clamped <- function(log_p) {
    b <- branches(log_p); if (-min(log_p, -1.2e-16) < 1e-6) b[["series"]] else b[["direct"]]
  }
  for (lp in c(-0.5, -1e-3, -1e-7, -1e-12)) {
    expect_identical(clamped(lp), unclamped(lp), info = paste("log_p =", lp))
  }
})

test_that("ordinal_probit Hessian is finite when cutpoints sit past the CDF-rounding reach", {
  skip_on_cran()
  skip_if_not(identical(Sys.getenv("NOT_CRAN"), "true"),
              "set NOT_CRAN=true to run the compiled ordinal AD-safety check")

  ## A K = 3 ordinal cell with a deliberately RARE extreme category, so the
  ## fitted top cutpoint sits far out. pnorm rounds to exactly 1 above 8.2924,
  ## so a cutpoint beyond that reach is what trips the unselected branch. Small
  ## n keeps this cheap; the property is per-cell, not asymptotic. Formula shape
  ## follows tests/testthat/test-ordinal-probit.R.
  set.seed(11)
  n_ind <- 120L; Tn <- 2L
  ystar <- matrix(stats::rnorm(n_ind * Tn, 0.3, 1), n_ind, Tn)
  ## thresholds at 0 and 2.2 make category 3 rare (~1%)
  ycat <- 1L + (ystar > 0) + (ystar > 2.2)
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(c("a", "b"), n_ind), levels = c("a", "b")),
    value      = c(t(ycat)))

  fit <- try(suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | individual),
    data = df, unit = "individual", family = ordinal_probit()))), silent = TRUE)
  skip_if(inherits(fit, "try-error"),
          paste("ordinal_probit fit unavailable:", as.character(fit)))
  expect_equal(fit$tmb_data$family_id_vec[1], 14L)   # confirm we are on fid 14

  expect_false(is.null(fit$tmb_obj))

  ## TMB refuses he() on a model with a `random` block ("Hessian not yet
  ## implemented for models with random effects"), so the Laplace objective
  ## cannot be interrogated directly. Rebuild the SAME C++ objective, same data
  ## and same parameters, with random = NULL: the full joint Hessian is then
  ## available, and it exercises exactly the gll_log_pnorm_diff ->
  ## gll_log1mexp path that was fixed. This is a test of the C++ numerics, which
  ## is what the fix changes; it is NOT a claim about the Laplace approximation.
  obj <- TMB::MakeADFun(data = fit$tmb_data, parameters = fit$tmb_params,
                        map = fit$tmb_map, random = NULL,
                        DLL = "gllvmTMB", silent = TRUE)
  expect_true(all(c("fn", "gr", "he") %in% names(obj)))
  p <- obj$par
  expect_true(all(is.finite(p)))

  ## The gradient is NOT the test -- it stays finite AND CORRECT with the defect
  ## present. Asserted only to show the tape is live.
  expect_true(all(is.finite(obj$fn(p))))
  expect_true(all(is.finite(obj$gr(p))))

  ## THE ACTUAL ASSERTION.
  expect_true(all(is.finite(obj$he(p))),
              info = "he() must be finite: a -Inf on an UNSELECTED CondExp branch shows up ONLY here")

  ## AND -- this is the part that actually reaches the defect.
  ##
  ## THE LEVER IS eta, NOT THE CUTPOINTS. For K = 3 the interior category is
  ## log(Phi(tau_2 - eta) - Phi(tau_1 - eta)), so a = tau_2 - eta and
  ## b = tau_1 - eta = -eta. The defect needs a AND b on the SAME side of zero,
  ## both past 8.2924, so that gll_log_pnorm's log(pnorm(.)) returns exactly 0
  ## for both and their difference is exactly 0. Enlarging tau_2 widens `a` while
  ## leaving b ~ 0, so the two straddle and the condition is never met -- pushing
  ## cutpoints does NOT reach it. Driving |eta| past ~8.3 moves BOTH together.
  ## Verified: an earlier version of this test pushed the cutpoints and passed
  ## against the unfixed engine, i.e. it guarded nothing.
  b_idx <- which(names(p) == "b_fix")
  expect_gt(length(b_idx), 0)            # if this fails, the probe is not probing
  reached <- FALSE
  for (push in c(-14, -11, 11, 14)) {
    p_far <- p; p_far[b_idx] <- push
    ## fn() and gr() stay finite AND CORRECT with the defect present -- asserted
    ## to show the tape is live at these parameters, never as the guard itself.
    expect_true(is.finite(obj$fn(p_far)), info = paste("fn() finite at eta push", push))
    expect_true(all(is.finite(obj$gr(p_far))), info = paste("gr() finite at eta push", push))
    ## THE GUARD. Without the input ceiling in gll_log1mexp the UNSELECTED
    ## CondExp branch is -Inf here and this returns NaN.
    he_far <- obj$he(p_far)
    expect_true(all(is.finite(he_far)),
                info = paste("he() must stay finite at eta push", push,
                             "-- the assertion the defect fails"))
    if (all(is.finite(he_far))) reached <- TRUE
  }
  expect_true(reached)
})
