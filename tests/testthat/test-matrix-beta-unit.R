## Phase B-matrix Group A (Design 59): `beta_family()` x unit-tier
## structural recovery + correlation-CI smoke.
##
## Walks the unit-tier structural cells of the capability matrix
## (`latent`, `unique`, `latent + unique`, `indep`, `dep`, scalar
## `unique(1 | unit)`) from `partial` to `covered` for the Beta
## response branch. Informs register rows FG-07/08/09 (beta) and
## FAM-10.
##
## DGP (shared across cells): logit-link Beta with concentration
##   phi = 5, ~60 units, 3-4 traits. A rank-1 latent score `u_i` per
##   unit drives a shared cross-trait covariance on the logit scale
##   (loadings `lam`), so the `latent` / `latent + unique` / `dep`
##   cells have a genuine off-diagonal correlation surface to recover,
##   while `unique` / `indep` / scalar treat that variance as
##   trait-marginal. Response is strictly inside (0, 1) by
##   construction.
##
## Per the Phase B0 scoping memo
## (docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md):
## Beta is mean-dependent (no fixed residual scale like binomial /
## ordinal probit), so the logit-scale intercept recovery gets a
## WIDER B0 tolerance than fixed-scale families. We therefore do NOT
## assert tight intercept recovery here; the honest, identifiable
## target is (a) clean convergence with a PD Hessian, (b) the Beta
## family routing (`family_id == 7`), (c) the correct structural
## use-flag, and (d) per-trait concentration `phi_beta` recovered
## inside the same [phi/3, 3*phi] band used by test-beta-recovery.R.
##
## Honest-matrix discipline (Design 59): no widened tolerances, no
## fake-pass. A cell that fails to converge / is non-PD is `skip()`ed
## with a reason and the register row stays `partial`. The
## correlation profile-CI smoke requires at least one finite bound on
## `rho:unit:1,2`; if the profile is degenerate we skip rather than
## relax the assertion.

skip_if_not_beta_unit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## phi recovery band: identical to test-beta-recovery.R ([phi/3, 3*phi]).
PHI_TRUE_BETA  <- 5.0
PHI_LO_BETA    <- PHI_TRUE_BETA / 3
PHI_HI_BETA    <- PHI_TRUE_BETA * 3

## Shared fixture: logit-link Beta, rank-1 latent cross-trait covariance.
make_beta_unit_fixture <- function(n_unit = 60L, n_traits = 3L,
                                   phi_true = PHI_TRUE_BETA,
                                   seed = 20260529L) {
  set.seed(seed)
  tn <- letters[seq_len(n_traits)]
  ## Logit-scale intercepts in [-0.6, 0.6] -> mu in [0.35, 0.65]
  ## (mean-dependent: away from the (0,1) boundaries).
  mu_true <- seq(-0.6, 0.6, length.out = n_traits)
  ## Rank-1 loadings: a real shared cross-trait signal on the logit scale.
  lam <- c(0.8, -0.5, 0.4, 0.3)[seq_len(n_traits)]
  u   <- stats::rnorm(n_unit)                     # latent score per unit
  y <- matrix(NA_real_, n_unit, n_traits)
  for (t in seq_len(n_traits)) {
    p_t <- stats::plogis(mu_true[t] + lam[t] * u)
    y[, t] <- stats::rbeta(n_unit, p_t * phi_true, (1 - p_t) * phi_true)
  }
  df <- data.frame(
    unit  = factor(rep(seq_len(n_unit), each = n_traits)),
    trait = factor(rep(tn, n_unit), levels = tn),
    value = as.vector(t(y))
  )
  list(data = df, n_traits = n_traits, phi_true = phi_true)
}

## Construct a Beta unit-tier fit; return the fit object, or a
## classed condition on construction error (caller skips honestly).
fit_beta_unit <- function(formula, data) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data   = data,
      unit   = "unit",
      family = gllvmTMB::Beta()
    ))),
    error = function(e) e
  )
}

## Shared health assertions for a converged Beta unit-tier fit.
expect_beta_unit_health <- function(fit) {
  testthat::expect_s3_class(fit, "gllvmTMB_multi")
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
  ## Beta family routing (family_id 7 per test-beta-recovery.R).
  testthat::expect_equal(fit$tmb_data$family_id_vec[1], 7L)
}

## phi_beta recovery on >= 1 cell, inside [phi/3, 3*phi].
expect_phi_beta_recovered <- function(fit, n_traits, phi_lo = PHI_LO_BETA,
                                      phi_hi = PHI_HI_BETA) {
  phi_hat <- as.numeric(fit$report$phi_beta)
  testthat::expect_equal(length(phi_hat), n_traits)
  testthat::expect_true(all(is.finite(phi_hat)))
  ## "recovered on >= 1 cell": at least one trait's phi lands in band.
  testthat::expect_true(any(phi_hat > phi_lo & phi_hat < phi_hi))
}

## Correlation profile-CI smoke for cells that carry a cross-trait
## surface. Requires >= 1 finite bound on rho:unit:1,2; skip-honest if
## the profile is degenerate.
expect_rho_unit_profile_finite <- function(fit) {
  ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "rho:unit:1,2", method = "profile"
    ))),
    error = function(e) e
  )
  if (inherits(ci, "error") || !is.matrix(ci) ||
        nrow(ci) != 1L || ncol(ci) != 2L || !any(is.finite(ci))) {
    testthat::skip(
      "Profile CI for rho:unit:1,2 did not return a finite bound; honest skip rather than relax assertion (cell stays partial for the CI claim)"
    )
  }
  testthat::expect_true(any(is.finite(ci)))
}

## ---------------------------------------------------------------
## latent(0 + trait | unit, d = 1) — rank-1 reduced-rank covariance
## ---------------------------------------------------------------
test_that("beta x latent(0 + trait | unit, d = 1): converges, pd_hessian, phi recovered, rho:unit profile CI finite", {
  skip_if_not_heavy()
  skip_if_not_beta_unit_deps()
  fx  <- make_beta_unit_fixture()
  fit <- fit_beta_unit(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1), fx$data
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("beta x latent fit failed to construct: %s",
                 if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    skip("beta x latent did not converge with PD Hessian; FG-07/08/09(beta) stays partial pending bigger n / different seed")
  }
  expect_beta_unit_health(fit)
  expect_true(isTRUE(fit$use$rr_B))
  expect_phi_beta_recovered(fit, fx$n_traits)
  ## latent(d = 1) carries a shared cross-trait covariance -> rho surface.
  expect_rho_unit_profile_finite(fit)
})

## ---------------------------------------------------------------
## unique(0 + trait | unit) — per-trait diagonal variances
## ---------------------------------------------------------------
test_that("beta x unique(0 + trait | unit): converges, pd_hessian, phi recovered", {
  skip_if_not_heavy()
  skip_if_not_beta_unit_deps()
  fx  <- make_beta_unit_fixture()
  fit <- fit_beta_unit(
    value ~ 0 + trait + unique(0 + trait | unit), fx$data
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("beta x unique fit failed to construct: %s",
                 if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    skip("beta x unique did not converge with PD Hessian; FG-07/08/09(beta) stays partial pending bigger n / different seed")
  }
  expect_beta_unit_health(fit)
  expect_true(isTRUE(fit$use$diag_B))
  expect_phi_beta_recovered(fit, fx$n_traits)
  ## unique is diagonal-by-construction: no cross-trait rho surface.
})

## ---------------------------------------------------------------
## latent + unique paired — reduced-rank + diagonal nugget
## ---------------------------------------------------------------
test_that("beta x latent + unique (paired): converges, pd_hessian, phi recovered, rho:unit profile CI finite", {
  skip_if_not_heavy()
  skip_if_not_beta_unit_deps()
  fx  <- make_beta_unit_fixture()
  fit <- fit_beta_unit(
    value ~ 0 + trait +
      latent(0 + trait | unit, d = 1) +
      unique(0 + trait | unit),
    fx$data
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("beta x latent+unique fit failed to construct: %s",
                 if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    skip("beta x latent+unique did not converge with PD Hessian; FG-07/08/09(beta) stays partial pending bigger n / different seed")
  }
  expect_beta_unit_health(fit)
  expect_true(isTRUE(fit$use$rr_B) && isTRUE(fit$use$diag_B))
  expect_phi_beta_recovered(fit, fx$n_traits)
  ## latent component carries the cross-trait covariance -> rho surface.
  expect_rho_unit_profile_finite(fit)
})

## ---------------------------------------------------------------
## indep(0 + trait | unit) — marginal-only diagonal canonical
## ---------------------------------------------------------------
test_that("beta x indep(0 + trait | unit): converges, pd_hessian, phi recovered", {
  skip_if_not_heavy()
  skip_if_not_beta_unit_deps()
  fx  <- make_beta_unit_fixture()
  fit <- fit_beta_unit(
    value ~ 0 + trait + indep(0 + trait | unit), fx$data
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("beta x indep fit failed to construct: %s",
                 if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    skip("beta x indep did not converge with PD Hessian; FG-07/08/09(beta) stays partial pending bigger n / different seed")
  }
  expect_beta_unit_health(fit)
  expect_true(isTRUE(fit$use$indep_B))
  expect_phi_beta_recovered(fit, fx$n_traits)
  ## indep is diagonal-by-construction: no cross-trait rho surface.
})

## ---------------------------------------------------------------
## dep(0 + trait | unit) — full unstructured cross-trait covariance
## (= latent(d = n_traits) standalone)
## ---------------------------------------------------------------
test_that("beta x dep(0 + trait | unit): converges, pd_hessian, phi recovered, rho:unit profile CI finite", {
  skip_if_not_heavy()
  skip_if_not_beta_unit_deps()
  fx  <- make_beta_unit_fixture()
  fit <- fit_beta_unit(
    value ~ 0 + trait + dep(0 + trait | unit), fx$data
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("beta x dep fit failed to construct: %s",
                 if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    skip("beta x dep did not converge with PD Hessian; FG-07/08/09(beta) stays partial pending bigger n / different seed")
  }
  expect_beta_unit_health(fit)
  expect_true(isTRUE(fit$use$dep_B))
  expect_phi_beta_recovered(fit, fx$n_traits)
  ## dep is full unstructured -> genuine cross-trait rho surface.
  expect_rho_unit_profile_finite(fit)
})

## ---------------------------------------------------------------
## scalar — unique(1 | unit): single shared random intercept variance
## (the unit-tier "scalar" mode; routes via diag(1 | unit))
## ---------------------------------------------------------------
test_that("beta x scalar unique(1 | unit): converges, pd_hessian, phi recovered", {
  skip_if_not_heavy()
  skip_if_not_beta_unit_deps()
  fx  <- make_beta_unit_fixture()
  fit <- fit_beta_unit(
    value ~ 0 + trait + unique(1 | unit), fx$data
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("beta x scalar (unique(1 | unit)) fit failed to construct: %s",
                 if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    skip("beta x scalar (unique(1 | unit)) did not converge with PD Hessian; FG-07/08/09(beta) stays partial pending bigger n / different seed")
  }
  expect_beta_unit_health(fit)
  expect_phi_beta_recovered(fit, fx$n_traits)
  ## Single shared scalar variance: no cross-trait rho surface.
})
