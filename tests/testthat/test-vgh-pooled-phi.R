## Regression test for the VGH engine's phi_pool option (dev/vgh/vgh-engine.R).
## The engine estimates one gaussian dispersion PER TRAIT by default; phi_pool
## constrains that to a single shared value, matching the Laplace engine's one
## scalar residual SD.  This lives in dev/, outside the package namespace, so
## the test must source it and skip gracefully when it is unavailable (dev/ is
## .Rbuildignore'd -- same pattern as test-m3-grid-summary.R /
## test-lv-wald-coverage-harness.R).

source_vgh_engine <- function() {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- c(
    file.path("dev", "vgh", "vgh-engine.R"),
    file.path("..", "..", "dev", "vgh", "vgh-engine.R"),
    if (!is.na(workspace)) file.path(workspace, "dev", "vgh", "vgh-engine.R")
  )
  dev_file <- candidates[file.exists(candidates)][1]
  testthat::skip_if(
    is.na(dev_file),
    "dev/vgh/vgh-engine.R is unavailable in this source-tarball context"
  )
  source(dev_file, local = parent.frame())
}

## Heteroscedastic gaussian fixture: phi_j spans an 8x range (0.25 to 2), so
## pooled and unpooled dispersion estimates are genuinely distinguishable --
## a homoscedastic truth would make phi_pool a no-op and the test vacuous.
## d = 2L keeps this fixture on the full d^2 vec path.  It previously ALSO
## dodged a shape bug in vgh_update_model() at d == 1L (the
## R <- Avec + t(apply(amean, 1L, ...)) line ran unconditionally, ahead of its
## own `if (d == 1L)` correction, so apply()'s length-1 simplification produced
## a 1 x n term and the sum with the n x 1 Avec errored).  That is now FIXED --
## the two lines are one if/else expression -- and the d == 1L test at the
## bottom of this file is the regression guard.
.vgh_pool_fixture <- function(n = 200L, m = 5L, d = 2L, seed = 20260730L) {
  set.seed(seed)
  phi_true <- seq(0.25, 2, length.out = m)
  Beta0 <- matrix(stats::rnorm(m), 1L, m)
  Lambda0 <- matrix(stats::rnorm(m * d, 0, 0.7), m, d)
  U0 <- matrix(stats::rnorm(n * d), n, d)
  X <- matrix(1, n, 1L)
  eta <- X %*% Beta0 + U0 %*% t(Lambda0)
  noise <- matrix(stats::rnorm(n * m), n, m) *
    matrix(sqrt(phi_true), n, m, byrow = TRUE)
  list(Y = eta + noise, X = X, d = d, phi_true = phi_true)
}

test_that("phi_pool shares one dispersion across traits, matches an independent recomputation, and keeps the ELBO monotone", {
  source_vgh_engine()
  fx <- .vgh_pool_fixture()
  Y <- fx$Y; X <- fx$X

  fit_pool   <- vgh_fit(Y, X, d = fx$d, family = "gaussian",
                        phi_pool = TRUE, trace_elbo = TRUE)
  fit_nopool <- vgh_fit(Y, X, d = fx$d, family = "gaussian",
                        phi_pool = FALSE)

  # (b) pooled phi is exactly uniform ...
  expect_lt(diff(range(fit_pool$phi)), 1e-10)
  # (c) ... and unpooled phi is not -- this arm is what proves the test can fail.
  expect_gt(diff(range(fit_nopool$phi)), 0.1)

  # the returned metadata records what actually ran
  expect_true(fit_pool$phi_pool)
  expect_false(fit_nopool$phi_pool)

  # (d) the pooled value equals the pooled residual variance, recomputed here
  # from the returned Beta/Lambda/amean/Avec -- NOT by re-calling
  # vgh_update_phi, which would only show the function agrees with itself.
  L2 <- t(apply(fit_pool$Lambda, 1L, function(l) as.vector(tcrossprod(l))))
  M_check  <- X %*% fit_pool$Beta + fit_pool$amean %*% t(fit_pool$Lambda)
  S2_check <- fit_pool$Avec %*% t(L2)
  phi_floor <- 1e-8   # mirrors vgh_update_phi()'s default; does not bind here
  phi_expected <- max(mean((Y - M_check)^2 + S2_check), phi_floor)
  expect_equal(fit_pool$phi, rep(phi_expected, ncol(Y)), tolerance = 1e-8)

  # (e) pooling is a constraint on the phi block; the optimiser must still
  # ascend the ELBO every sweep.
  expect_true(all(diff(fit_pool$elbo_path) >= -1e-8))
})


## Single-factor fixture for the d == 1L regression test: one latent dimension,
## per-family responses generated off a common eta.  Deliberately small
## (n = 120, m = 4) -- this is a shape guard, not a recovery test; it only has to
## reach vgh_update_model() and stay monotone.
.vgh_d1_fixture <- function(family, n = 120L, m = 4L, seed = 20260730L) {
  set.seed(seed)
  X <- matrix(1, n, 1L)
  eta <- X %*% matrix(stats::rnorm(m, 0, 0.3), 1L, m) +
    matrix(stats::rnorm(n), n, 1L) %*% t(matrix(stats::rnorm(m, 0, 0.7), m, 1L))
  Y <- switch(family,
    gaussian = eta + matrix(stats::rnorm(n * m, 0, 0.5), n, m),
    poisson  = matrix(stats::rpois(n * m, exp(eta)), n, m),
    binomial = matrix(stats::rbinom(n * m, 1L, stats::plogis(eta)), n, m))
  list(Y = Y, X = X)
}

test_that("vgh_fit runs at d = 1L for every family and keeps the ELBO monotone", {
  source_vgh_engine()

  # The R = vec(E_q[u u']) block in vgh_update_model() is family-independent, so
  # a d == 1L shape failure there breaks every family -- all three are checked.
  for (family in c("gaussian", "poisson", "binomial")) {
    fx <- .vgh_d1_fixture(family)

    # (a) the fit completes.  This is the arm that fails on the unfixed engine,
    # where sweep 1 dies in vgh_update_model() with "non-conformable arrays".
    fit <- expect_no_error(
      vgh_fit(fx$Y, fx$X, d = 1L, family = family, trace_elbo = TRUE)
    )

    # (b) one latent dimension in, one column of loadings out
    expect_equal(ncol(fit$Lambda), 1L, info = family)

    # (c) nothing degenerate came back
    expect_true(all(is.finite(fit$Beta)), info = family)
    expect_true(all(is.finite(fit$Lambda)), info = family)
    expect_true(all(is.finite(fit$phi)), info = family)

    # (d) coordinate ascent still ascends at d == 1L.  The length check keeps
    # the monotonicity assertion from passing vacuously on a 1-sweep path.
    expect_gt(length(fit$elbo_path), 1L)
    expect_true(all(diff(fit$elbo_path) >= -1e-8), info = family)
  }
})


## --- Reported ELBO corresponds to the RETURNED parameters ----------------------
## vgh_fit() used to return `elbo = prev`, the ELBO from the PREVIOUS sweep: the
## convergence test breaks BEFORE `prev <- e$value`, so on a converged fit the
## reported objective was stale by one sweep relative to the Beta/Lambda it
## shipped alongside.  Design ported from the production engine's test in
## test-vgh-oracle.R.
##
## The tolerance has to be LOOSE on purpose.  At a tight tol the last increment
## is negligible and a one-sweep lag is invisible; at tol = 1e-4 it is ~0.1 ELBO
## units, large enough that the previous sweep's value is detectably wrong.  The
## sweeps < maxit check is what keeps this non-vacuous: on an maxit-exhausted run
## the trailing `prev <- e$value` masks the defect.
test_that("reported elbo is the objective at the returned parameters", {
  source_vgh_engine()
  maxit <- 200L

  for (family in c("gaussian", "poisson")) {
    fx <- if (family == "gaussian") .vgh_pool_fixture() else
      .vgh_d1_fixture("poisson", n = 200L, m = 5L)
    d <- if (family == "gaussian") fx$d else 1L

    fit <- vgh_fit(fx$Y, fx$X, d = d, family = family,
                   maxit = maxit, tol = 1e-4, trace_elbo = TRUE)

    # (a) the fit converged rather than running out of sweeps -- otherwise the
    # assertion below passes for the wrong reason.
    expect_lt(fit$sweeps, maxit)
    expect_gt(length(fit$elbo_path), 1L)

    # (b) the reported value is the LAST path entry, not the one before it --
    # the direct statement of the defect.
    expect_equal(fit$elbo, fit$elbo_path[length(fit$elbo_path)],
                 tolerance = 1e-12, info = family)

    # (c) and it is not merely close: the stale value is a DIFFERENT number, so
    # the previous entry must fail the same check.  This arm proves (b) can fail.
    expect_gt(abs(fit$elbo_path[length(fit$elbo_path) - 1L] -
                    fit$elbo_path[length(fit$elbo_path)]), 1e-6)
  }
})
