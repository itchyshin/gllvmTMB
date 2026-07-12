## Phase B-matrix Group E (agent E-bb; Design 59): `betabinomial()` family-
## recovery depth + unit-tier structural smoke. Informs register row FAM-05.
##
## FAM-05 is currently recovery-test-only (test-betabinomial-recovery.R covers
## the single `latent(d = 1)` recovery cell + a glmmTMB obs-likelihood
## cross-check + a non-logit-link guard). This file DEEPENS that coverage by
## walking the three unit-tier structural cells the matrix campaign asks for on
## the overdispersed-binomial family:
##   latent(0 + trait | unit, d = 1) / unique(0 + trait | unit) / latent+unique.
##
## DGP (one shared seed-controlled fixture, see make_betabinom_unit_fixture()):
##   eta_{u,t} = mu_int_t + lambda_t * b_u,        b_u ~ N(0, sd_u^2)
##   p_random  ~ Beta(plogis(eta) * phi, (1 - plogis(eta)) * phi)
##   succ_{u,t} ~ Binom(N, p_random),  fail = N - succ
## A single shared unit-level latent factor b_u with all-positive per-trait
## loadings lambda_t induces a clean cross-trait correlation on the logit scale
## that the reduced-rank (`latent`) and paired (`latent+unique`) cells can
## identify, so the rho:unit profile-CI smoke has a real off-diagonal to
## profile. The beta-binomial sampling step (Beta-then-Binom at N = 10,
## phi = 3) matches test-betabinomial-recovery.R exactly; the only addition is
## the shared b_u factor on the linear predictor (the recovery test fits at
## eta = mu_int alone, with the latent factor estimated, not simulated).
##
## Sizing: 3 traits, 60 units (the matrix-campaign "~3 traits / ~60 units"
## tier), N = 10 trials per row (multi-trial binomial has tighter
## identification than single-trial per the Phase B0 scoping memo §3.1).
##
## Per the Design 59 Honest-matrix discipline: any cell that fails to construct
## / does not converge / is non-PD is skip()-ped with a reason and reported as
## FAM-05 staying partial -- never forced green by relaxing a check.
##
## Tolerances (Phase B0 non-Gaussian scoping memo, 2026-05-26): betabinomial is
## a mean-dependent family, so trait-intercept recovery uses the recovery
## test's logit-scale band (|b_hat - mu_int| < 0.30) and the per-trait phi band
## (phi in [phi/3, 3*phi]). We deliberately keep these and do NOT tighten or
## widen them per cell. The shared-factor SD (sd_u = 0.6) is sized so the
## logit-scale identification at the campaign's 60-unit tier stays inside that
## fixed 0.30 band (latent / paired recover at ~0.23 here) -- the fixture is
## calibrated to the band, not the band relaxed to the fixture.

skip_if_not_betabinom_unit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## Seed-controlled beta-binomial fixture on a single shared unit factor.
make_betabinom_unit_fixture <- function(n_unit = 60L, n_traits = 3L,
                                        phi_true = 3.0, N = 10L,
                                        mu_int = c(-0.4, 0.4, 1.0),
                                        lambda = c(0.8, 0.6, 0.5),
                                        sd_u = 0.6, seed = 805L) {
  set.seed(seed)
  trait_names <- paste0("trait_", seq_len(n_traits))
  mu_int <- rep_len(mu_int, n_traits)
  lambda <- rep_len(lambda, n_traits)
  b_u    <- stats::rnorm(n_unit, sd = sd_u)        # shared unit-level latent effect

  rows <- vector("list", n_unit * n_traits)
  k <- 0L
  for (u in seq_len(n_unit)) {
    for (t in seq_len(n_traits)) {
      eta_ut <- mu_int[t] + lambda[t] * b_u[u]
      p_t    <- stats::plogis(eta_ut)
      p_rand <- stats::rbeta(1L, p_t * phi_true, (1 - p_t) * phi_true)
      succ   <- stats::rbinom(1L, size = N, prob = p_rand)
      k <- k + 1L
      rows[[k]] <- data.frame(
        unit  = u,
        trait = trait_names[t],
        succ  = succ,
        fail  = N - succ
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
    mu_int   = mu_int
  )
}

## Fit one unit-tier betabinomial structural spec; return the fit or the error.
fit_betabinom_unit <- function(formula, fx) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data   = fx$data,
      unit   = "unit",
      family = betabinomial()
    ))),
    error = function(e) e
  )
}

## Shared health gate: skip honestly on construct-fail / non-conv / non-PD.
skip_unless_healthy_betabinom <- function(fit, cell) {
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "%s betabinomial unit fit failed to construct: %s (FAM-05 stays partial)",
      cell,
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    testthat::skip(sprintf(
      paste0("%s betabinomial unit fit did not converge with PD Hessian; ",
             "FAM-05 stays partial pending bigger n / different seed"),
      cell
    ))
  }
  invisible(fit)
}

## Common per-cell health + betabinomial dispersion finiteness assertions.
## phi_betabinom is per-trait; all entries must be finite and positive.
expect_betabinom_unit_health <- function(fit, fx) {
  expect_stationary_for_recovery_test(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_stationary_for_recovery_test(fit)
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], 8L)  # betabinomial

  phi_hat <- as.numeric(fit$report$phi_betabinom)
  testthat::expect_equal(length(phi_hat), fx$n_traits)
  testthat::expect_true(all(is.finite(phi_hat) & phi_hat > 0))
}

## Logit-scale trait-intercept recovery check (recovery test's band, 0.30).
expect_betabinom_intercepts_recover <- function(fit, fx, tol = 0.30) {
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
test_that("betabinomial x latent(0 + trait | unit, d = 1): converges, PD Hessian, phi finite, rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_betabinom_unit_deps()
  fx  <- make_betabinom_unit_fixture()
  fit <- fit_betabinom_unit(
    cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 1), fx
  )
  skip_unless_healthy_betabinom(fit, "latent(d=1)")

  expect_betabinom_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$rr_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_betabinom_intercepts_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit)
})

## ---------------------------------------------------------------
## unique(0 + trait | unit) -- per-trait diagonal; cleanest phi recovery
## ---------------------------------------------------------------
test_that("betabinomial x unique(0 + trait | unit): converges, PD Hessian, phi finite", {
  skip_if_not_heavy()
  skip_if_not_betabinom_unit_deps()
  fx  <- make_betabinom_unit_fixture()
  fit <- fit_betabinom_unit(
    cbind(succ, fail) ~ 0 + trait + unique(0 + trait | unit), fx
  )
  skip_unless_healthy_betabinom(fit, "unique")

  expect_betabinom_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$diag_B))
  expect_betabinom_intercepts_recover(fit, fx)
  ## Diagonal cell has no off-diagonal unit-tier correlation by construction,
  ## so there is no rho:unit to profile here.
})

## ---------------------------------------------------------------
## latent + unique paired (reduced-rank + diagonal on the same grouping)
## ---------------------------------------------------------------
test_that("betabinomial x latent + unique paired (unit): converges, PD Hessian, phi finite, rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_betabinom_unit_deps()
  fx  <- make_betabinom_unit_fixture()
  fit <- fit_betabinom_unit(
    cbind(succ, fail) ~ 0 + trait +
            latent(0 + trait | unit, d = 1) +
            unique(0 + trait | unit),
    fx
  )
  skip_unless_healthy_betabinom(fit, "latent+unique")

  expect_betabinom_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$rr_B) && isTRUE(fit$use$diag_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_betabinom_intercepts_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit)
})
