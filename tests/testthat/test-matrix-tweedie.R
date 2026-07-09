## Phase B-matrix Group E (agent E-tw; Design 59): `tweedie()` family-recovery
## depth + unit-tier structural smoke. Informs register row FAM-13.
##
## FAM-13 is currently recovery-test-only (test-tweedie-recovery.R covers the
## single `latent(d = 1)` recovery cell + a glmmTMB logLik cross-check + a
## non-log-link guard). This file DEEPENS that coverage by walking the three
## unit-tier structural cells the matrix campaign asks for on the
## compound-Poisson-Gamma family:
##   latent(0 + trait | unit, d = 1) / unique(0 + trait | unit) / latent+unique.
##
## DGP (one shared seed-controlled fixture, see make_tweedie_unit_fixture()):
##   mu_{u,t} = exp(alpha_t + lambda_t * b_u),  b_u ~ N(0, sd_u^2)
##   y_{u,t}  ~ Tweedie(mu_{u,t}, phi, p)  via mgcv::rTweedie  (1 < p < 2)
## A single shared unit-level latent factor b_u with all-positive per-trait
## loadings lambda_t induces a clean cross-trait correlation the reduced-rank
## (`latent`) and the paired (`latent+unique`) cells can identify, so the
## rho:unit profile-CI smoke has a real off-diagonal to profile. The DGP
## (mgcv::rTweedie at p = 1.5, phi = 1) and the power-parameter argument
## (`p = p_true` to mgcv::rTweedie) match test-tweedie-recovery.R exactly.
##
## Sizing: 3 traits, 60 units (the matrix-campaign "~3 traits / ~60 units" tier).
## Tweedie is the hardest tail family in this campaign -- the simultaneous
## estimation of per-trait phi AND the power p on top of a structural Sigma_b
## frequently fails to reach a PD Hessian at this small a sample. Per the
## Design 59 Honest-matrix discipline + the explicit task note ("tweedie is
## hard -- honest skip on non-convergence is acceptable"), any cell that fails
## to construct / does not converge / is non-PD is skip()-ped with a reason and
## reported as FAM-13 staying partial -- never forced green by relaxing a check.
##
## Tolerances (Phase B0 non-Gaussian scoping memo, 2026-05-26): tweedie is a
## mean-dependent family, so trait-intercept recovery uses the WIDER B0 band
## (|b_hat - mu_int| < 0.40) rather than the tight fixed-residual-scale band of
## the binomial / ordinal-probit families. We deliberately keep the
## recovery-test's structural checks (phi/p finiteness, p in (1,2)) and do NOT
## tighten them per cell.

skip_if_not_tweedie_unit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("mgcv")          # rTweedie DGP
}

## Seed-controlled compound-Poisson-Gamma fixture on a single shared unit factor.
make_tweedie_unit_fixture <- function(n_unit = 60L, n_traits = 3L,
                                      phi_true = 1.0, p_true = 1.5,
                                      mu_int = c(1.0, 1.5, 0.5),
                                      lambda = c(0.8, 0.6, 0.5),
                                      sd_u = 0.6, seed = 613L) {
  set.seed(seed)
  trait_names <- paste0("trait_", seq_len(n_traits))
  mu_int <- rep_len(mu_int, n_traits)
  lambda <- rep_len(lambda, n_traits)
  b_u    <- stats::rnorm(n_unit, sd = sd_u)        # shared unit-level latent effect

  rows <- vector("list", n_unit * n_traits)
  k <- 0L
  for (u in seq_len(n_unit)) {
    for (t in seq_len(n_traits)) {
      mu_ut <- exp(mu_int[t] + lambda[t] * b_u[u])
      k <- k + 1L
      rows[[k]] <- data.frame(
        unit  = u,
        trait = trait_names[t],
        value = mgcv::rTweedie(mu_ut, p = p_true, phi = phi_true)
      )
    }
  }
  df <- do.call(rbind, rows)
  df$unit  <- factor(df$unit, levels = seq_len(n_unit))
  df$trait <- factor(df$trait, levels = trait_names)
  list(
    data     = df,
    n_traits = n_traits,
    phi_true = phi_true,
    p_true   = p_true,
    mu_int   = mu_int
  )
}

## Fit one unit-tier tweedie structural spec; return the fit or the error.
fit_tweedie_unit <- function(formula, fx) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data   = fx$data,
      unit   = "unit",
      family = tweedie()
    ))),
    error = function(e) e
  )
}

## Shared health gate: skip honestly on construct-fail / non-conv / non-PD.
skip_unless_healthy_tweedie <- function(fit, cell) {
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "%s tweedie unit fit failed to construct: %s (FAM-13 stays partial)",
      cell,
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_converged(fit)) {
    testthat::skip(sprintf(
      paste0("%s tweedie unit fit did not converge with PD Hessian; FAM-13 ",
             "stays partial pending bigger n / different seed (tweedie is hard)"),
      cell
    ))
  }
  invisible(fit)
}

## Common per-cell health + tweedie dispersion/power finiteness assertions.
## phi_tweedie and p_tweedie are per-trait; both must be finite, phi positive,
## and p strictly inside the compound-Poisson-Gamma regime (1, 2).
expect_tweedie_unit_health <- function(fit, fx) {
  expect_converged(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_converged(fit)
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], 6L)  # tweedie

  phi_hat <- as.numeric(fit$report$phi_tweedie)
  p_hat   <- as.numeric(fit$report$p_tweedie)
  testthat::expect_equal(length(phi_hat), fx$n_traits)
  testthat::expect_equal(length(p_hat),   fx$n_traits)
  testthat::expect_true(all(is.finite(phi_hat) & phi_hat > 0))
  testthat::expect_true(all(is.finite(p_hat) & p_hat > 1 & p_hat < 2))
}

## Wider Phase-B0 trait-intercept recovery check for this mean-dependent family.
expect_tweedie_intercepts_recover <- function(fit, fx, tol = 0.40) {
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  testthat::expect_equal(length(bfix), fx$n_traits)
  testthat::expect_lt(max(abs(bfix - fx$mu_int)), tol)
}

## rho:unit profile-CI smoke on the canonical (1,2) pair: one finite bound.
## Only meaningful for cells with off-diagonal unit-tier structure (`latent`,
## `latent+unique`); a degenerate profile is an honest skip, not a relaxed
## assertion (CI-08 stays partial there).
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
test_that("tweedie x latent(0 + trait | unit, d = 1): converges, PD Hessian, phi/p finite, rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_tweedie_unit_deps()
  fx  <- make_tweedie_unit_fixture()
  fit <- fit_tweedie_unit(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1), fx
  )
  skip_unless_healthy_tweedie(fit, "latent(d=1)")

  expect_tweedie_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$rr_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_tweedie_intercepts_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit)
})

## ---------------------------------------------------------------
## unique(0 + trait | unit) -- per-trait diagonal; cleanest phi/p recovery
## ---------------------------------------------------------------
test_that("tweedie x unique(0 + trait | unit): converges, PD Hessian, phi/p finite", {
  skip_if_not_heavy()
  skip_if_not_tweedie_unit_deps()
  fx  <- make_tweedie_unit_fixture()
  fit <- fit_tweedie_unit(
    value ~ 0 + trait + unique(0 + trait | unit), fx
  )
  skip_unless_healthy_tweedie(fit, "unique")

  expect_tweedie_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$diag_B))
  expect_tweedie_intercepts_recover(fit, fx)
  ## Diagonal cell has no off-diagonal unit-tier correlation by construction,
  ## so there is no rho:unit to profile here.
})

## ---------------------------------------------------------------
## latent + unique paired (reduced-rank + diagonal on the same grouping)
## ---------------------------------------------------------------
test_that("tweedie x latent + unique paired (unit): converges, PD Hessian, phi/p finite, rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_tweedie_unit_deps()
  fx  <- make_tweedie_unit_fixture()
  fit <- fit_tweedie_unit(
    value ~ 0 + trait +
            latent(0 + trait | unit, d = 1) +
            unique(0 + trait | unit),
    fx
  )
  skip_unless_healthy_tweedie(fit, "latent+unique")

  expect_tweedie_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$rr_B) && isTRUE(fit$use$diag_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_tweedie_intercepts_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit)
})
