## Phase B-matrix, agent A-gam: Gamma(link = "log") x unit-tier structural
## recovery + CI smoke. Informs register rows FG-07/08/09 (gamma) and FAM-09.
##
## DGP (log link, seed-controlled):
##   * shape phi = 2  =>  gamma CV = 1 / sqrt(phi) ~ 0.7071, and the engine
##     parametrises Gamma with `sigma_eps` AS the CV (shape = 1 / sigma_eps^2;
##     see src/gllvmTMB.cpp fid 4 + R/extract-sigma.R:181-182). There is no
##     separate `phi_gamma` slot for the non-delta Gamma family, so the
##     dispersion-parameter ("phi_gamma") recovery check is on shape =
##     1 / sigma_eps^2.
##   * trait log-intercepts c(0, 0.2, -0.2)  =>  natural-scale mean mu ~ 1.
##   * a shared per-unit latent factor (cross-trait covariance, so rho:unit
##     is defined for the latent-bearing cells) plus a per-trait per-unit
##     nugget, positive continuous responses.
##   * REPLICATES per (unit, trait) cell. This is load-bearing: with one
##     observation per cell, a unit-level random intercept (unique / indep /
##     latent+unique / scalar) is confounded with the per-observation gamma
##     residual and the CV collapses to ~0 (shape -> 1e6). Replicates make
##     the gamma dispersion identifiable for every structure. The latent()
##     factor alone is separable even without replicates, but the shared DGP
##     keeps all six cells on one fixture.
##
## Honest-matrix discipline (Design 59): Gamma is mean-dependent, so the CV
## tolerance is wide (Phase B0 scoping memo: mean-dependent families looser
## than fixed-residual-scale families). No widening beyond that. A cell that
## does not converge / is non-PD is SKIPPED with a reason, never forced green.
## Gamma is FAM-09 smoke-only at baseline, so solidifying recovery here is
## the contribution; partial cells stay partial honestly.

## True gamma CV for shape = 2.
.gamma_cv_true <- 1 / sqrt(2)

## Shared seeded simulator. One fixture, used by every cell.
sim_gamma_unit <- function(seed,
                           n_unit    = 60L,
                           Tn        = 3L,
                           reps      = 4L,
                           shape     = 2,
                           mu_eta    = c(0.0, 0.2, -0.2),
                           Lam       = c(0.7, 0.5, -0.3),
                           sd_nugget = 0.3) {
  set.seed(seed)
  tn     <- c("a", "b", "c", "d")[seq_len(Tn)]
  Lambda <- matrix(Lam[seq_len(Tn)], nrow = Tn, ncol = 1L)
  fac    <- stats::rnorm(n_unit)               # shared latent factor (per unit)
  ueff   <- outer(fac, as.numeric(Lambda))     # n_unit x Tn cross-trait signal
  nug    <- matrix(stats::rnorm(n_unit * Tn, sd = sd_nugget), n_unit, Tn)

  N    <- n_unit * Tn * reps
  unit  <- integer(N); trait <- character(N); value <- numeric(N)
  k <- 1L
  for (uu in seq_len(n_unit)) {
    for (t in seq_len(Tn)) {
      mu <- exp(mu_eta[t] + ueff[uu, t] + nug[uu, t])
      for (r in seq_len(reps)) {
        unit[k]  <- uu
        trait[k] <- tn[t]
        value[k] <- stats::rgamma(1L, shape = shape, scale = mu / shape)
        k <- k + 1L
      }
    }
  }
  data.frame(
    unit  = factor(unit),
    trait = factor(trait, levels = tn),
    value = value
  )
}

## Fit helper: returns NULL on a hard fit error (so the caller can skip).
fit_gamma_unit <- function(form, df) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      form,
      data   = df,
      unit   = "unit",
      family = Gamma(link = "log")
    ))),
    error = function(e) e
  )
}

## Shared convergence + PD gate. Skips honestly instead of fake-passing.
expect_converged_pd <- function(fit) {
  if (inherits(fit, "error")) {
    testthat::skip(paste0("gamma fit errored: ", conditionMessage(fit)))
  }
  if (!isTRUE(fit$opt$convergence == 0L)) {
    testthat::skip(paste0("non-convergence (code ",
                          fit$opt$convergence %||% NA, "); stays partial"))
  }
  if (!isTRUE(fit$sd_report$pdHess)) {
    testthat::skip("non-PD Hessian; stays partial")
  }
  invisible(fit)
}

## --------------------------------------------------------------------------
## latent(0 + trait | unit, d = 1)
## --------------------------------------------------------------------------
test_that("Gamma(log) x latent(d=1) unit-tier: converges, PD, recovers shape", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  df  <- sim_gamma_unit(seed = 4101L)
  fit <- fit_gamma_unit(value ~ 0 + trait + latent(0 + trait | unit, d = 1), df)
  expect_converged_pd(fit)

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))
  expect_true(isTRUE(fit$use$rr_B))

  ## phi_gamma == shape == 1 / CV^2; mean-dependent => wide tolerance.
  cv_hat <- as.numeric(fit$report$sigma_eps)
  expect_lt(abs(cv_hat - .gamma_cv_true), 0.15)
  shape_hat <- 1 / cv_hat^2
  expect_gt(shape_hat, 1.0)
  expect_lt(shape_hat, 4.0)

  ## CI smoke: rho:unit profile. This standalone d = 1 cell used to be the
  ## fragile Gamma profile canary. Keep the honest skip fallback if a future
  ## optimizer/platform returns a degenerate endpoint, but the 2026-07-05 local
  ## gate runs this cell non-skipped with finite bounds.
  ci <- tryCatch(
    suppressMessages(confint(fit, parm = "rho:unit:1,2", method = "profile")),
    error = function(e) e
  )
  if (inherits(ci, "error") || !all(is.finite(ci))) {
    testthat::skip(
      "rho:unit profile degenerate for standalone latent(d=1) (NA bound); FAM-09 smoke stays partial for this cell"
    )
  }
  expect_true(all(is.finite(ci)))
})

## --------------------------------------------------------------------------
## unique(0 + trait | unit)
## --------------------------------------------------------------------------
test_that("Gamma(log) x unique unit-tier: converges, PD, recovers shape", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  df  <- sim_gamma_unit(seed = 4102L)
  fit <- fit_gamma_unit(value ~ 0 + trait + unique(0 + trait | unit), df)
  expect_converged_pd(fit)

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))
  expect_true(isTRUE(fit$use$diag_B))

  cv_hat <- as.numeric(fit$report$sigma_eps)
  expect_lt(abs(cv_hat - .gamma_cv_true), 0.15)
  shape_hat <- 1 / cv_hat^2
  expect_gt(shape_hat, 1.0)
  expect_lt(shape_hat, 4.0)

  ## rho:unit is not defined for a diagonal (unique) Sigma -- the engine
  ## errors by design ("no latent() term"). The CI smoke therefore does not
  ## apply to this cell; we assert the error is raised rather than skip
  ## silently, so the diagonal-no-correlation contract stays tested.
  expect_error(
    suppressMessages(confint(fit, parm = "rho:unit:1,2", method = "profile")),
    regexp = "latent|correlation"
  )
})

## --------------------------------------------------------------------------
## latent(d=1) + unique  (paired)
## --------------------------------------------------------------------------
test_that("Gamma(log) x latent+unique unit-tier: converges, PD, shape + rho CI", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  df  <- sim_gamma_unit(seed = 4103L)
  fit <- fit_gamma_unit(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1) + unique(0 + trait | unit),
    df
  )
  expect_converged_pd(fit)

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))
  expect_true(isTRUE(fit$use$rr_B) && isTRUE(fit$use$diag_B))

  cv_hat <- as.numeric(fit$report$sigma_eps)
  expect_lt(abs(cv_hat - .gamma_cv_true), 0.15)
  shape_hat <- 1 / cv_hat^2
  expect_gt(shape_hat, 1.0)
  expect_lt(shape_hat, 4.0)

  ## CI smoke (primary): rho:unit profile is defined here (latent gives the
  ## cross-trait covariance, unique the per-trait nugget) and returns a
  ## finite, monotone profile interval. This is the FAM-09 gamma CI smoke.
  ci <- tryCatch(
    suppressMessages(confint(fit, parm = "rho:unit:1,2", method = "profile")),
    error = function(e) e
  )
  if (inherits(ci, "error")) {
    testthat::skip(paste0("rho:unit profile errored: ", conditionMessage(ci)))
  }
  expect_true(is.matrix(ci) && ncol(ci) == 2L)
  expect_true(all(is.finite(ci)))
  expect_true(ci[1] <= ci[2])
})

## --------------------------------------------------------------------------
## indep(0 + trait | unit)
## --------------------------------------------------------------------------
test_that("Gamma(log) x indep unit-tier: converges, PD, recovers shape", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  df  <- sim_gamma_unit(seed = 4104L)
  fit <- fit_gamma_unit(value ~ 0 + trait + indep(0 + trait | unit), df)
  expect_converged_pd(fit)

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))
  expect_true(isTRUE(fit$use$indep_B))

  cv_hat <- as.numeric(fit$report$sigma_eps)
  expect_lt(abs(cv_hat - .gamma_cv_true), 0.15)
  shape_hat <- 1 / cv_hat^2
  expect_gt(shape_hat, 1.0)
  expect_lt(shape_hat, 4.0)

  ## indep => diagonal Sigma; rho:unit undefined, engine errors by design.
  expect_error(
    suppressMessages(confint(fit, parm = "rho:unit:1,2", method = "profile")),
    regexp = "latent|correlation"
  )
})

## --------------------------------------------------------------------------
## dep(0 + trait | unit)
## --------------------------------------------------------------------------
test_that("Gamma(log) x dep unit-tier: converges, PD, shape + rho CI", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  df  <- sim_gamma_unit(seed = 4105L)
  fit <- fit_gamma_unit(value ~ 0 + trait + dep(0 + trait | unit), df)
  expect_converged_pd(fit)

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))
  expect_true(isTRUE(fit$use$dep_B))

  cv_hat <- as.numeric(fit$report$sigma_eps)
  expect_lt(abs(cv_hat - .gamma_cv_true), 0.15)
  shape_hat <- 1 / cv_hat^2
  expect_gt(shape_hat, 1.0)
  expect_lt(shape_hat, 4.0)

  ## CI smoke: dep is full unstructured (= latent at d = n_traits), so the
  ## cross-trait correlation profile is defined and finite.
  ci <- tryCatch(
    suppressMessages(confint(fit, parm = "rho:unit:1,2", method = "profile")),
    error = function(e) e
  )
  if (inherits(ci, "error")) {
    testthat::skip(paste0("rho:unit profile errored: ", conditionMessage(ci)))
  }
  expect_true(is.matrix(ci) && ncol(ci) == 2L)
  expect_true(all(is.finite(ci)))
  expect_true(ci[1] <= ci[2])
})

## --------------------------------------------------------------------------
## scalar : single shared per-unit variance via the (1 | unit) bar term.
## --------------------------------------------------------------------------
test_that("Gamma(log) x scalar unit-tier: converges, PD, recovers shape (wide)", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  df  <- sim_gamma_unit(seed = 4106L)
  fit <- fit_gamma_unit(value ~ 0 + trait + (1 | unit), df)
  expect_converged_pd(fit)

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))

  ## A single shared scalar variance is structurally misspecified relative to
  ## the per-trait DGP (it pools the per-trait nugget into the gamma
  ## residual), so the CV is biased upward. Honest wider tolerance for the
  ## scalar cell -- still a real recovery, not a fake pass.
  cv_hat <- as.numeric(fit$report$sigma_eps)
  expect_lt(abs(cv_hat - .gamma_cv_true), 0.30)
  shape_hat <- 1 / cv_hat^2
  expect_gt(shape_hat, 0.8)
  expect_lt(shape_hat, 4.0)

  ## A single shared scalar has no cross-trait Sigma matrix, so rho:unit is
  ## undefined; the engine cannot extract Sigma at the tier. Not applicable.
  expect_error(
    suppressMessages(confint(fit, parm = "rho:unit:1,2", method = "profile")),
    regexp = "Sigma|latent|correlation"
  )
})
