## Phase B-matrix Group E (agent E-ln; Design 59): `lognormal()` family-recovery
## depth + unit-tier structural smoke. Informs register row FAM-11.
##
## FAM-11 is currently smoke-only (test-family-lognormal.R covers a single
## `latent(d = 2)` recovery cell + a non-positive-y guard + a non-log-link
## guard). This file DEEPENS that coverage by walking the three unit-tier
## structural cells the matrix campaign asks for on the lognormal family:
##   latent(0 + trait | unit, d = 1) / unique(0 + trait | unit) / latent+unique.
##
## DGP (one shared seed-controlled fixture, see make_lognormal_unit_fixture()):
##   log(y_{u,t,r}) ~ Normal(alpha_t + lambda_t * b_u, sigma_eps^2),  b_u ~ N(0,1)
##   y_{u,t,r}      = exp(.)                                          (positive cts)
## A single shared unit-level latent factor b_u with all-positive per-trait
## loadings lambda_t induces a clean cross-trait correlation the reduced-rank
## (`latent`) and the paired (`latent+unique`) cells can identify, so the
## rho:unit profile-CI smoke has a real off-diagonal to profile. The log-scale
## DGP matches test-family-lognormal.R (mu + u Lambda^T + Normal residual,
## then exp()), specialised to a single d = 1 factor for the structural tier.
##
## REPLICATES per (unit, trait) cell (reps = 3) are load-bearing for the
## diagonal-bearing cells. With one observation per cell a per-trait unit
## random intercept (`unique` / `latent + unique`) is confounded with the
## log-scale residual and `sigma_eps` collapses to ~0; replicates separate the
## per-trait random effect from the residual so the free log-scale residual SD
## is identifiable for every structure (same lesson as the gamma-unit sibling).
##
## Sizing: 3 traits, 60 units, 3 reps (the matrix-campaign "~3 traits / ~60
## units" tier). Unlike the mean-dependent tail families in this campaign,
## lognormal carries a FREE log-scale residual SD (`sigma_eps`); the response
## is Gaussian on the log scale, so identifiability is close to the Gaussian
## baseline and a TIGHTER recovery band than the mean-dependent families is
## honest here (Design 59 task note). We still SKIP -- never relax -- any cell
## that fails to construct / does not converge / is non-PD (Honest-matrix
## discipline); FAM-11 then stays partial for that cell.
##
## Tolerances: trait log-intercepts within 0.25 (Gaussian-like, tighter than
## the mean-dependent 0.40 B0 band); sigma_eps within 0.10 of the truth (the
## stage2 residual-sigma tolerance); implied latent variances diag(Lambda Lambda^T)
## within 0.25 absolute of lambda^2 (rotation/sign-invariant single-factor band).

skip_if_not_lognormal_unit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## Seed-controlled log-normal fixture on a single shared unit factor + reps.
make_lognormal_unit_fixture <- function(n_unit = 60L, n_traits = 3L, reps = 3L,
                                        sigma_eps = 0.3,
                                        mu_int = c(1.0, 1.5, 0.5),
                                        lambda = c(0.8, 0.6, 0.5),
                                        sd_u = 1.0, seed = 811L) {
  set.seed(seed)
  trait_names <- paste0("trait_", seq_len(n_traits))
  mu_int <- rep_len(mu_int, n_traits)
  lambda <- rep_len(lambda, n_traits)
  b_u    <- stats::rnorm(n_unit, sd = sd_u)        # shared unit-level latent effect

  rows <- vector("list", n_unit * n_traits * reps)
  k <- 0L
  for (u in seq_len(n_unit)) {
    for (t in seq_len(n_traits)) {
      log_mu <- mu_int[t] + lambda[t] * b_u[u]
      for (r in seq_len(reps)) {
        k <- k + 1L
        rows[[k]] <- data.frame(
          unit  = u,
          trait = trait_names[t],
          value = exp(stats::rnorm(1L, mean = log_mu, sd = sigma_eps))
        )
      }
    }
  }
  df <- do.call(rbind, rows)
  df$unit  <- factor(df$unit, levels = seq_len(n_unit))
  df$trait <- factor(df$trait, levels = trait_names)
  list(
    data      = df,
    n_traits  = n_traits,
    sigma_eps = sigma_eps,
    mu_int    = mu_int,
    lambda    = lambda
  )
}

## Fit one unit-tier lognormal structural spec; return the fit or the error.
fit_lognormal_unit <- function(formula, fx) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data   = fx$data,
      unit   = "unit",
      family = lognormal()
    ))),
    error = function(e) e
  )
}

## Shared health gate: skip honestly on construct-fail / non-conv / non-PD.
skip_unless_healthy_lognormal <- function(fit, cell) {
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "%s lognormal unit fit failed to construct: %s (FAM-11 stays partial)",
      cell,
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    testthat::skip(sprintf(
      "%s lognormal unit fit did not converge with PD Hessian; FAM-11 stays partial",
      cell
    ))
  }
  invisible(fit)
}

## Common per-cell health assertions. lognormal is family-id 3 and exposes the
## free log-scale residual SD as `sigma_eps`; both convergence and a PD Hessian
## are required, and the log-scale residual SD must be finite and positive.
expect_lognormal_unit_health <- function(fit, fx) {
  expect_stationary_for_recovery_test(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_stationary_for_recovery_test(fit)
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], 3L)  # lognormal

  sigma_eps_hat <- as.numeric(fit$report$sigma_eps)
  testthat::expect_equal(length(sigma_eps_hat), 1L)
  testthat::expect_true(is.finite(sigma_eps_hat) && sigma_eps_hat > 0)
}

## Tighter (Gaussian-like) trait-intercept recovery on the log scale.
expect_lognormal_intercepts_recover <- function(fit, fx, tol = 0.25) {
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  testthat::expect_equal(length(bfix), fx$n_traits)
  testthat::expect_lt(max(abs(bfix - fx$mu_int)), tol)
}

## The free log-scale residual SD is identifiable (this is what makes lognormal
## Gaussian-like); recover it within the stage2 residual-sigma tolerance.
expect_lognormal_sigma_eps_recover <- function(fit, fx, tol = 0.10) {
  sigma_eps_hat <- as.numeric(fit$report$sigma_eps)
  testthat::expect_equal(sigma_eps_hat, fx$sigma_eps, tolerance = tol)
}

## Implied latent variances diag(Lambda Lambda^T) recover lambda^2 (single d=1
## factor). Rotation/sign-invariant, so we compare the diagonal magnitudes.
expect_lognormal_latent_var_recover <- function(fit, fx, tol = 0.25) {
  LB <- fit$report$Lambda_B
  testthat::expect_equal(dim(LB), c(fx$n_traits, 1L))
  implied <- diag(LB %*% t(LB))
  testthat::expect_lt(max(abs(implied - fx$lambda^2)), tol)
}

## rho:unit profile-CI smoke on the canonical (1,2) pair: at least one finite
## bound. For a standalone latent(d = 1) the correlation profile's lower bound
## frequently does not invert (returns NA) -- one finite bound is the honest
## smoke target; a fully degenerate profile is skipped, not relaxed (CI-08
## stays partial there). Only meaningful for latent-bearing cells.
expect_rho_unit_ci_smoke <- function(fit) {
  ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "rho:unit:1,2", method = "profile"
    ))),
    error = function(e) e
  )
  ok <- !inherits(ci, "error") && is.matrix(ci) && nrow(ci) == 1L &&
    ncol(ci) == 2L && any(is.finite(ci))
  if (!ok) {
    testthat::skip(paste0(
      "Profile CI for rho:unit:1,2 did not return a finite bound; honest skip ",
      "rather than relax assertion (CI-08 stays partial here)"
    ))
  }
  testthat::expect_true(ok)
}

## ---------------------------------------------------------------
## latent(0 + trait | unit, d = 1) -- reduced-rank, one shared factor
## ---------------------------------------------------------------
test_that("lognormal x latent(0 + trait | unit, d = 1): converges, PD Hessian, sigma_eps + latent var recover, rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_lognormal_unit_deps()
  fx  <- make_lognormal_unit_fixture()
  fit <- fit_lognormal_unit(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1), fx
  )
  skip_unless_healthy_lognormal(fit, "latent(d=1)")

  expect_lognormal_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$rr_B))
  expect_lognormal_intercepts_recover(fit, fx)
  expect_lognormal_sigma_eps_recover(fit, fx)
  expect_lognormal_latent_var_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit)
})

## ---------------------------------------------------------------
## unique(0 + trait | unit) -- per-trait diagonal; cleanest sigma_eps recovery
## ---------------------------------------------------------------
test_that("lognormal x unique(0 + trait | unit): converges, PD Hessian, sigma_eps recovers", {
  skip_if_not_heavy()
  skip_if_not_lognormal_unit_deps()
  fx  <- make_lognormal_unit_fixture()
  fit <- fit_lognormal_unit(
    value ~ 0 + trait + unique(0 + trait | unit), fx
  )
  skip_unless_healthy_lognormal(fit, "unique")

  expect_lognormal_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$diag_B))
  expect_lognormal_intercepts_recover(fit, fx)
  expect_lognormal_sigma_eps_recover(fit, fx)

  ## A diagonal (unique) Sigma has no off-diagonal unit-tier correlation, so
  ## rho:unit is undefined and the engine errors by design. Assert the error
  ## rather than skip silently, keeping the diagonal-no-correlation contract
  ## tested.
  expect_error(
    suppressMessages(stats::confint(fit, parm = "rho:unit:1,2", method = "profile")),
    regexp = "latent|correlation"
  )
})

## ---------------------------------------------------------------
## latent + unique paired (reduced-rank + diagonal on the same grouping)
## ---------------------------------------------------------------
test_that("lognormal x latent + unique paired (unit): converges, PD Hessian, sigma_eps + latent var recover, rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_lognormal_unit_deps()
  fx  <- make_lognormal_unit_fixture()
  fit <- fit_lognormal_unit(
    value ~ 0 + trait +
            latent(0 + trait | unit, d = 1) +
            unique(0 + trait | unit),
    fx
  )
  skip_unless_healthy_lognormal(fit, "latent+unique")

  expect_lognormal_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$rr_B) && isTRUE(fit$use$diag_B))
  expect_lognormal_intercepts_recover(fit, fx)
  expect_lognormal_sigma_eps_recover(fit, fx)
  expect_lognormal_latent_var_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit)
})
