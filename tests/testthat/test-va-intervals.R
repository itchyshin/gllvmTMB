## Tests for the VA interval routes in R/va-intervals.R -- opt-in, unexported
## instruments for the coverage-measurement campaign
## (docs/design/va-interval-coverage-campaign.md). Design 110 promotes only the
## fixed-effect profiled-Schur block to public confint()/vcov() as explicitly
## uncalibrated VA-Wald output. The remaining routes stay internal.
##
## Per surviving route (wald-schur, profile, sandwich, bootstrap) this file
## checks: (1) intervals are finite and correctly ordered on a small healthy
## fit; (2) the route errors -- rather than silently returning a
## plausible-looking number -- on a degenerate/unhealthy input; (3) (once,
## globally) the public surface labels the promoted beta route honestly.

skip_on_cran()

## ---------------------------------------------------------------------
## Shared fixture: one small, fast, healthy VA-R3 binomial-logit fit.
## N=50 units, T=4 traits, q=1 -- well inside the "N <= 80, a few seconds"
## local-compute bound, deliberately small enough to avoid a multi-seed
## campaign.
## ---------------------------------------------------------------------

.va_intervals_fixture <- function(seed = 20260804L, N = 50L, Tn = 4L, q = 1L) {
  set.seed(seed)
  trait_names <- paste0("sp", seq_len(Tn))
  long <- data.frame(
    unit = factor(rep(seq_len(N), each = Tn)),
    trait = factor(rep(trait_names, N), levels = trait_names)
  )
  beta_true <- seq(0.2, by = 0.15, length.out = Tn)
  Lambda_true <- matrix(c(0.6, 0.4, -0.3, 0.5)[seq_len(Tn * q)], Tn, q)
  score <- matrix(stats::rnorm(N * q), N, q)
  unit <- as.integer(long$unit)
  trait <- as.integer(long$trait)
  eta <- beta_true[trait] +
    rowSums(Lambda_true[trait, , drop = FALSE] * score[unit, , drop = FALSE])
  y <- stats::rbinom(N * Tn, 1L, stats::plogis(eta))
  n_trials <- rep(1L, N * Tn)
  X <- stats::model.matrix(~ 0 + trait, long)

  fit <- .va_r3_fit(
    y = y, n_trials = n_trials, X = X, unit_id = unit, trait_id = trait,
    q = q, family = "binomial", link = "logit", H = 15L, n_starts = 4L
  )
  list(fit = fit, y = y, n_trials = n_trials, X = X, unit_id = unit,
       trait_id = trait, N = N, Tn = Tn, q = q)
}

## Built once and reused by every test_that() below -- fitting is the
## expensive part; every subsequent call is arithmetic on the same object.
fx <- .va_intervals_fixture()

test_that("fixture VA fit is healthy (precondition for every test below)", {
  expect_identical(fx$fit$status, "healthy")
  expect_true(is.finite(fx$fit$best$objective))
})

## ---------------------------------------------------------------------
## Route: Wald-from-Schur (.va_wald_beta_ci / .va_wald_loadings_ci)
## ---------------------------------------------------------------------

test_that("wald-schur beta CI is finite and correctly ordered", {
  ci <- .va_wald_beta_ci(fx$fit)
  expect_equal(nrow(ci), fx$Tn)
  expect_true(all(is.finite(ci$estimate)))
  expect_true(all(is.finite(ci$se)))
  expect_true(all(ci$se > 0))
  expect_true(all(ci$lower < ci$estimate))
  expect_true(all(ci$estimate < ci$upper))
  expect_false(any(ci$calibrated))
})

test_that("wald-schur loadings (Sigma) CI is finite and correctly ordered", {
  ci <- .va_wald_loadings_ci(fx$fit)
  expect_equal(nrow(ci), fx$Tn * (fx$Tn + 1L) / 2L)
  expect_true(all(is.finite(ci$estimate)))
  expect_true(all(is.finite(ci$se)))
  expect_true(all(ci$lower <= ci$estimate))
  expect_true(all(ci$estimate <= ci$upper))
  expect_false(any(ci$calibrated))
})

test_that("wald-schur errors, not nonsense, on an unhealthy/un-admitted fit", {
  fit_bad <- fx$fit
  fit_bad$status <- "failed_health_gate"
  expect_error(.va_wald_beta_ci(fit_bad), "health gate was not cleared")
  expect_error(.va_wald_loadings_ci(fit_bad), "health gate was not cleared")
})

test_that("wald-schur errors, not nonsense, on an unrecognised fit object", {
  expect_error(.va_wald_beta_ci(list()), "recognised VA fit")
})

## ---------------------------------------------------------------------
## Route: profile (ELBO drop-in, chi-squared(1)/2)
## ---------------------------------------------------------------------

test_that("profile CI is finite and correctly ordered for every beta entry", {
  for (i in seq_len(fx$Tn)) {
    p <- .va_profile_ci(fx$fit, name = "beta", which = i)
    expect_true(is.finite(p$estimate))
    expect_true(is.finite(p$lower))
    expect_true(is.finite(p$upper))
    expect_lt(p$lower, p$estimate)
    expect_lt(p$estimate, p$upper)
    expect_false(p$calibrated)
    expect_identical(p$route, "va_elbo_profile")
  }
})

test_that("profile errors, not nonsense, on an unhealthy/un-admitted fit", {
  fit_bad <- fx$fit
  fit_bad$status <- "failed_variance_domain"
  expect_error(.va_profile_ci(fit_bad, name = "beta", which = 1L),
               "health gate was not cleared")
})

test_that("profile refuses to target raw (non-identified) loadings", {
  expect_error(.va_profile_ci(fx$fit, name = "theta_rr", which = 1L),
               "rotation and sign")
})

## ---------------------------------------------------------------------
## Route: sandwich (robust/Huber-White)
## ---------------------------------------------------------------------

test_that("sandwich beta CI is finite and correctly ordered", {
  ci <- .va_sandwich_beta_ci(fx$fit)
  expect_equal(nrow(ci), fx$Tn)
  expect_true(all(is.finite(ci$estimate)))
  expect_true(all(is.finite(ci$se)))
  expect_true(all(ci$se > 0))
  expect_true(all(ci$lower < ci$estimate))
  expect_true(all(ci$estimate < ci$upper))
  expect_false(any(ci$calibrated))
  expect_true(all(is.finite(ci$max_abs_gradient)))
})

test_that("sandwich loadings (Sigma) CI is finite and correctly ordered", {
  ci <- .va_sandwich_loadings_ci(fx$fit)
  expect_equal(nrow(ci), fx$Tn * (fx$Tn + 1L) / 2L)
  expect_true(all(is.finite(ci$estimate)))
  expect_true(all(is.finite(ci$se)))
  expect_true(all(ci$lower <= ci$estimate))
  expect_true(all(ci$estimate <= ci$upper))
  expect_false(any(ci$calibrated))
})

test_that("sandwich errors, not nonsense, on an unhealthy/un-admitted fit", {
  fit_bad <- fx$fit
  fit_bad$status <- "failed_health_gate"
  expect_error(.va_sandwich_beta_ci(fit_bad), "health gate was not cleared")
})

test_that("sandwich's internal stationarity gate rejects a drifted point, not just an unhealthy fit label", {
  ## Regression test for the FATAL finding: a fit whose $status still says
  ## "healthy" but whose $best$par has been perturbed away from the optimum
  ## (e.g. by an upstream bug, not by a mislabelled fit) must not silently
  ## return a plausible-looking SE. This is deliberately NOT the same
  ## precondition as the $status check above -- it fires even when $status
  ## claims healthy.
  fit_drifted <- fx$fit
  expect_identical(fit_drifted$status, "healthy")
  beta_idx <- which(names(fit_drifted$best$par) == "beta")[1]
  fit_drifted$best$par[beta_idx] <- fit_drifted$best$par[beta_idx] + 1.0
  expect_error(.va_sandwich_beta_ci(fit_drifted), "va_non_stationary_gradient")
  expect_error(.va_sandwich_loadings_ci(fit_drifted), "va_non_stationary_gradient")
})

## ---------------------------------------------------------------------
## Route: parametric bootstrap (simulate-then-refit)
## ---------------------------------------------------------------------

test_that("bootstrap beta and Sigma CIs are finite and correctly ordered, with the codebase-standard 1-based unit_id/trait_id convention", {
  ## Regression test for the FATAL indexing-convention bug: unit_id/trait_id
  ## below are the SAME 1-based vectors used to produce fx$fit (matching this
  ## package's own test-suite convention, e.g. test-va-r3-prototype.R's
  ## `rep(seq_len(N), each = T)`), passed straight through as the function's
  ## own docs instruct. Before the fix, every replicate failed with a
  ## swallowed "subscript out of bounds".
  boot <- .va_bootstrap_replicates(
    fx$fit, y = fx$y, n_trials = fx$n_trials, X = fx$X,
    unit_id = fx$unit_id, trait_id = fx$trait_id,
    n_boot = 9L, seed = 11L, n_starts = 1L, H = 15L, progress = FALSE
  )
  expect_identical(boot$n_boot, 9L)
  expect_equal(boot$n_failed, 0L)

  bci <- .va_bootstrap_beta_ci(boot, level = 0.5)
  expect_equal(nrow(bci), fx$Tn)
  expect_true(all(is.finite(bci$lower)))
  expect_true(all(is.finite(bci$upper)))
  expect_true(all(bci$lower <= bci$upper))
  expect_false(any(bci$calibrated))

  lci <- .va_bootstrap_loadings_ci(boot, level = 0.5)
  expect_equal(nrow(lci), fx$Tn * (fx$Tn + 1L) / 2L)
  expect_true(all(is.finite(lci$lower)))
  expect_true(all(is.finite(lci$upper)))
  expect_true(all(lci$lower <= lci$upper))
  expect_false(any(lci$calibrated))
})

test_that("bootstrap errors, not nonsense, on an unhealthy/un-admitted original fit", {
  fit_bad <- fx$fit
  fit_bad$status <- "failed_health_gate"
  expect_error(
    .va_bootstrap_replicates(
      fit_bad, y = fx$y, n_trials = fx$n_trials, X = fx$X,
      unit_id = fx$unit_id, trait_id = fx$trait_id,
      n_boot = 2L, n_starts = 1L, H = 15L, progress = FALSE
    ),
    "health gate was not cleared"
  )
})

test_that("bootstrap's simulator errors, not nonsense, on an unimplemented family/link", {
  expect_error(
    .va_bootstrap_simulate_one(
      beta = c(0, 0), Lambda = matrix(c(0.1, 0.2), 2L, 1L),
      X = diag(2), unit_id = c(1L, 2L), trait_id = c(1L, 2L),
      n_trials = c(1L, 1L), family = "gaussian_anchor", link = "identity",
      q = 1L
    ),
    "No bootstrap simulator is implemented"
  )
})

test_that("bootstrap simulator accepts both 1-based and 0-based unit_id/trait_id and gives identical draws for the identical seed", {
  Lambda <- matrix(c(0.5, -0.2, 0.3, 0.1), 4L, 1L)
  X <- matrix(0, 8L, 1L)
  beta <- 0.3
  unit_1based <- rep(1:4, each = 2L)
  trait_1based <- rep(1:2, 4L)
  unit_0based <- unit_1based - 1L
  trait_0based <- trait_1based - 1L

  set.seed(7L)
  y_1 <- .va_bootstrap_simulate_one(beta, Lambda, X, unit_1based, trait_1based,
                                    n_trials = rep(1L, 8L), family = "binomial",
                                    link = "logit", q = 1L)
  set.seed(7L)
  y_0 <- .va_bootstrap_simulate_one(beta, Lambda, X, unit_0based, trait_0based,
                                    n_trials = rep(1L, 8L), family = "binomial",
                                    link = "logit", q = 1L)
  expect_identical(y_1, y_0)
})

## ---------------------------------------------------------------------
## Public Design-110 surface: fixed-effect VA-Wald only.
## ---------------------------------------------------------------------

test_that("public vcov/confint expose labelled fixed-effect profiled-Schur VA-Wald output", {
  public_va <- structure(
    list(
      status = "healthy",
      engine_result = fx$fit,
      beta_names = colnames(fx$X)
    ),
    class = c("gllvmTMB_va", "gllvmTMB")
  )
  V <- vcov(public_va)
  CI <- confint(public_va)
  expect_equal(dim(V), c(fx$Tn, fx$Tn))
  expect_equal(dim(CI), c(fx$Tn, 2L))
  expect_identical(rownames(V), colnames(fx$X))
  expect_identical(rownames(CI), colnames(fx$X))
  expect_true(all(is.finite(V)))
  expect_true(all(is.finite(CI)))
  expect_identical(attr(V, "route"), "va_wald_profile_schur")
  expect_identical(attr(CI, "route"), "va_wald_profile_schur")
  expect_false(isTRUE(attr(V, "calibrated")))
  expect_false(isTRUE(attr(CI, "calibrated")))
  expect_match(attr(V, "uncertainty_basis"), "VA-Wald")
  expect_match(attr(CI, "uncertainty_basis"), "VA-Wald")

  CI_2 <- confint(public_va, parm = 2L)
  CI_3 <- confint(public_va, parm = colnames(fx$X)[3L])
  expect_equal(as.numeric(CI_2), as.numeric(CI[2L, , drop = FALSE]))
  expect_equal(as.numeric(CI_3), as.numeric(CI[3L, , drop = FALSE]))
  expect_identical(rownames(CI_2), colnames(fx$X)[2L])
  expect_identical(rownames(CI_3), colnames(fx$X)[3L])
  expect_identical(attr(CI_2, "route"), "va_wald_profile_schur")
  expect_identical(attr(CI_3, "route"), "va_wald_profile_schur")
})

test_that("public fixed-effect VA-Wald methods fail closed on an unhealthy fit", {
  fake_va <- structure(
    list(status = "failed_health_gate"),
    class = c("gllvmTMB_va", "gllvmTMB")
  )
  expect_error(confint(fake_va), "healthy variational fit")
  expect_error(vcov(fake_va), "healthy variational fit")
})

test_that("public VA-Wald profiles fitted family nuisance parameters", {
  ## A synthetic positive-definite Hessian makes the intended marginalisation
  ## exactly observable. beta is correlated with log_sigma, so an implementation
  ## that conditions on log_sigma returns a different (too small) variance.
  H <- matrix(c(
    4.0, 0.2, 1.2, 0.5, 0.1,
    0.2, 3.0, 0.1, 0.2, 0.1,
    1.2, 0.1, 2.5, 0.3, 0.2,
    0.5, 0.2, 0.3, 2.0, 0.1,
    0.1, 0.1, 0.2, 0.1, 1.8
  ), nrow = 5L, byrow = TRUE)
  expect_gt(min(eigen(H, symmetric = TRUE, only.values = TRUE)$values), 0)
  par <- stats::setNames(
    numeric(5L), c("beta", "theta_rr", "log_sigma", "m", "log_L_diag")
  )
  objective <- list(gr = function(x) as.numeric(H %*% x))
  public_va <- structure(
    list(
      status = "healthy",
      engine_result = list(objective = objective, best = list(par = par)),
      beta_names = "intercept"
    ),
    class = c("gllvmTMB_va", "gllvmTMB")
  )

  schur <- .va_r3_schur_fixed_covariance(objective, par, N = 1L, q = 1L)
  info <- .va_r3_fixed_information_blocked(objective, par, N = 1L, q = 1L)
  V <- vcov(public_va)
  expected_full_inverse <- solve(H)[1L, 1L]

  ## Prove this fixture would catch the old beta/theta-only implementation.
  old_fixed <- 1:2
  variational <- 4:5
  old_schur <- H[old_fixed, old_fixed] -
    H[old_fixed, variational] %*%
      solve(H[variational, variational], H[variational, old_fixed])
  expect_gt(abs(solve(old_schur)[1L, 1L] - expected_full_inverse), 1e-3)

  expect_identical(schur$status, "ok")
  expect_identical(schur$names, names(par)[1:3])
  expect_equal(unname(sqrt(diag(schur$covariance))), unname(info$se_profile),
               tolerance = 1e-8)
  expect_equal(unname(V[1L, 1L]), expected_full_inverse, tolerance = 1e-8)
  expect_identical(attr(V, "route"), "va_wald_profile_schur")
  expect_false(isTRUE(attr(V, "calibrated")))
})
