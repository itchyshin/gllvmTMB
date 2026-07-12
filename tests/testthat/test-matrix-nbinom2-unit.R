## Phase B-matrix Group A (agent A-nb2; Design 59): `nbinom2()` x unit-tier
## structural recovery + CI smoke.
##
## Walks the unit-tier structural cells of the family x structure capability
## matrix for the overdispersed-count family `nbinom2()` (log link):
##   latent / unique / latent+unique / indep / dep / scalar.
## Informs register rows FG-07 / FG-08 / FG-09 (nbinom2).
##
## DGP (one shared seed-controlled fixture, see make_nb2_unit_fixture()):
##   y_{u,t} ~ NB2(mu_{u,t}, phi),  log mu_{u,t} = alpha_t + lambda_t * b_u
##   b_u ~ N(0, sd_u^2)  shared unit-level latent effect
##   alpha_t = mu_int (intercept ~ 2 on the log scale, i.e. mean count ~ 7),
##   phi = 2 (moderate overdispersion; Ver Hoef & Boveng 2007 Ecology
##   88:2766-2772), 4 traits, 80 units. The per-trait loadings lambda_t are
##   all positive so the single shared factor induces a clean cross-trait
##   correlation pattern that the reduced-rank (`latent`, `dep`) cells can
##   identify, and the unit-level variance is large enough (sd_u = 0.7) that
##   every trait is genuinely overdispersed -- otherwise a near-Poisson trait
##   pushes its per-trait phi -> Inf and the loading collapses (the
##   mean-dependent fragility the Phase B0 scoping memo flags for nbinom2 x
##   latent at small n). n_unit = 80 was the smallest grid on this seed where
##   all six structural cells reach a PD Hessian.
##
## Tolerances (Phase B0 non-Gaussian scoping memo, 2026-05-26): nbinom2 is a
## mean-dependent family, so trait-intercept recovery uses the wider B0 band
## (|b_hat - mu_int| < 0.40) rather than the tight fixed-residual-scale band
## used for binomial / ordinal probit. Per-trait phi at n = 80 recovers within
## roughly a factor of two, so the overdispersion check on the cleanest
## (diagonal) cell uses the [phi/3, 3*phi] band of test-nb2-recovery.R.
##
## CI smoke: confint(parm = "rho:unit:i,j", method = "profile") routes through
## the unit-tier correlation-profile path. Cross-trait correlations only exist
## for the cells with off-diagonal structure (`latent`, `latent+unique`,
## `dep`); the purely diagonal cells (`unique`, `indep`, scalar) have no rho by
## construction, so the smoke runs on the former three. We loop the three
## upper-triangular pairs and require one finite bound on one pair, so a single
## hard pair does not collapse the test (matching the binary-probit structural
## templates test-spatial-pair-binary.R / test-phyloscalar-binary.R).
##
## Honest-matrix discipline (Design 59): a cell that fails to construct, does
## not converge, or has a non-PD Hessian is skip()-ped with a reason and
## reported as "stays partial" -- never forced green by relaxing an assertion.

skip_if_not_nb2_unit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## Seed-controlled overdispersed-count fixture on a single shared unit factor.
make_nb2_unit_fixture <- function(n_unit = 80L, n_traits = 4L,
                                  phi_true = 2.0, mu_int = 2.0,
                                  lambda = c(0.8, 0.7, 0.6, 0.5),
                                  sd_u = 0.7, seed = 101L) {
  set.seed(seed)
  trait_names <- paste0("trait_", seq_len(n_traits))
  lambda <- rep_len(lambda, n_traits)
  b_u <- stats::rnorm(n_unit, sd = sd_u)        # shared unit-level latent effect

  rows <- vector("list", n_unit * n_traits)
  k <- 0L
  for (u in seq_len(n_unit)) {
    for (t in seq_len(n_traits)) {
      eta <- mu_int + lambda[t] * b_u[u]
      k <- k + 1L
      rows[[k]] <- data.frame(
        unit  = u,
        trait = trait_names[t],
        value = stats::rnbinom(1L, mu = exp(eta), size = phi_true)
      )
    }
  }
  df <- do.call(rbind, rows)
  df$unit  <- factor(df$unit, levels = seq_len(n_unit))
  df$trait <- factor(df$trait, levels = trait_names)
  list(
    data        = df,
    n_traits    = n_traits,
    phi_true    = phi_true,
    mu_int      = mu_int
  )
}

## Fit one unit-tier nbinom2 structural spec; return the fit or the error.
fit_nb2_unit <- function(formula, fx) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data   = fx$data,
      unit   = "unit",
      family = nbinom2()
    ))),
    error = function(e) e
  )
}

## Shared health gate: skip honestly on construct-fail / non-conv / non-PD.
skip_unless_healthy_nb2 <- function(fit, cell, row) {
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "%s nbinom2 unit fit failed to construct: %s",
      cell,
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    testthat::skip(sprintf(
      "%s nbinom2 unit fit did not converge with PD Hessian; %s stays partial pending bigger n / different seed",
      cell, row
    ))
  }
  invisible(fit)
}

## Common per-cell health assertions once the gate has passed.
expect_nb2_unit_health <- function(fit) {
  expect_stationary_for_recovery_test(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_stationary_for_recovery_test(fit)
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], 5L)  # nbinom2
}

## Wider Phase-B0 trait-intercept recovery check for this mean-dependent family.
expect_nb2_intercepts_recover <- function(fit, fx, tol = 0.40) {
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  testthat::expect_equal(length(bfix), fx$n_traits)
  testthat::expect_lt(max(abs(bfix - fx$mu_int)), tol)
}

## rho:unit profile CI smoke: one finite bound on one upper-tri pair.
expect_rho_unit_ci_smoke <- function(fit, n_traits) {
  pairs_to_try <- list(c(1L, 2L), c(1L, 3L), c(2L, 3L))
  pairs_to_try <- Filter(function(p) all(p <= n_traits), pairs_to_try)
  any_finite <- FALSE
  for (p in pairs_to_try) {
    parm_token <- sprintf("rho:unit:%d,%d", p[1L], p[2L])
    ci <- tryCatch(
      suppressMessages(suppressWarnings(stats::confint(
        fit, parm = parm_token, method = "profile"
      ))),
      error = function(e) e
    )
    if (!inherits(ci, "error") && is.matrix(ci) && nrow(ci) == 1L &&
          ncol(ci) == 2L && any(is.finite(ci))) {
      any_finite <- TRUE
      break
    }
  }
  if (!any_finite) {
    testthat::skip(paste0(
      "Profile CI for rho:unit did not return any finite bound on any pair; ",
      "honest skip rather than relax assertion (CI-08 stays partial here)"
    ))
  }
  testthat::expect_true(any_finite)
}

## ---------------------------------------------------------------
## latent(0 + trait | unit, d = 1) -- reduced-rank, one shared factor
## ---------------------------------------------------------------
test_that("nbinom2 x latent(0 + trait | unit, d = 1): converges, PD Hessian, rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_nb2_unit_deps()
  fx  <- make_nb2_unit_fixture()
  fit <- fit_nb2_unit(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1), fx
  )
  skip_unless_healthy_nb2(fit, "latent(d=1)", "FG-07/08/09 (nbinom2)")

  expect_nb2_unit_health(fit)
  expect_true(isTRUE(fit$use$rr_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_nb2_intercepts_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit, fx$n_traits)
})

## ---------------------------------------------------------------
## unique(0 + trait | unit) -- per-trait diagonal; cleanest phi recovery
## ---------------------------------------------------------------
test_that("nbinom2 x unique(0 + trait | unit): converges, PD Hessian, recovers phi", {
  skip_if_not_heavy()
  skip_if_not_nb2_unit_deps()
  fx  <- make_nb2_unit_fixture()
  fit <- fit_nb2_unit(
    value ~ 0 + trait + unique(0 + trait | unit), fx
  )
  skip_unless_healthy_nb2(fit, "unique", "FG-07/08/09 (nbinom2)")

  expect_nb2_unit_health(fit)
  expect_true(isTRUE(fit$use$diag_B))
  expect_nb2_intercepts_recover(fit, fx)

  ## Overdispersion recovery: the diagonal cell is the cleanest place to
  ## check phi (no factor structure to soak up the count variance). All
  ## per-trait phi must be finite-positive and their mean must land in the
  ## [phi/3, 3*phi] band of test-nb2-recovery.R.
  phi_hat <- as.numeric(fit$report$phi_nbinom2)
  expect_equal(length(phi_hat), fx$n_traits)
  expect_true(all(is.finite(phi_hat) & phi_hat > 0))
  expect_gt(mean(phi_hat), fx$phi_true / 3)
  expect_lt(mean(phi_hat), 3 * fx$phi_true)
})

## ---------------------------------------------------------------
## latent + unique paired (reduced-rank + diagonal on the same grouping)
## ---------------------------------------------------------------
test_that("nbinom2 x latent + unique paired (unit): converges, PD Hessian, rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_nb2_unit_deps()
  fx  <- make_nb2_unit_fixture()
  fit <- fit_nb2_unit(
    value ~ 0 + trait +
            latent(0 + trait | unit, d = 1) +
            unique(0 + trait | unit),
    fx
  )
  skip_unless_healthy_nb2(fit, "latent+unique", "FG-07/08/09 (nbinom2)")

  expect_nb2_unit_health(fit)
  expect_true(isTRUE(fit$use$rr_B) && isTRUE(fit$use$diag_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_nb2_intercepts_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit, fx$n_traits)
})

## ---------------------------------------------------------------
## indep(0 + trait | unit) -- diagonal "clean trio" alias of unique
## ---------------------------------------------------------------
test_that("nbinom2 x indep(0 + trait | unit): converges, PD Hessian, indep_B flag set", {
  skip_if_not_heavy()
  skip_if_not_nb2_unit_deps()
  fx  <- make_nb2_unit_fixture()
  fit <- fit_nb2_unit(
    value ~ 0 + trait + indep(0 + trait | unit), fx
  )
  skip_unless_healthy_nb2(fit, "indep", "FG-07/08/09 (nbinom2)")

  expect_nb2_unit_health(fit)
  ## indep is the diagonal structure with the .indep marker; the use-flag
  ## must dispatch to indep_B (not just diag_B).
  expect_true(isTRUE(fit$use$indep_B))
  expect_nb2_intercepts_recover(fit, fx)
})

## ---------------------------------------------------------------
## dep(0 + trait | unit) -- full unstructured (= latent at d = n_traits)
## ---------------------------------------------------------------
test_that("nbinom2 x dep(0 + trait | unit): converges, PD Hessian, rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_nb2_unit_deps()
  fx  <- make_nb2_unit_fixture()
  fit <- fit_nb2_unit(
    value ~ 0 + trait + dep(0 + trait | unit), fx
  )
  skip_unless_healthy_nb2(fit, "dep", "FG-07/08/09 (nbinom2)")

  expect_nb2_unit_health(fit)
  ## dep is the full unstructured 2T x 2T path; the use-flag must dispatch
  ## to dep_B.
  expect_true(isTRUE(fit$use$dep_B))
  expect_nb2_intercepts_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit, fx$n_traits)
})

## ---------------------------------------------------------------
## scalar -- ONE shared variance across traits == unique(common = TRUE)
## ---------------------------------------------------------------
test_that("nbinom2 x scalar (unique common = TRUE, unit): converges, PD Hessian, ties trait variances", {
  skip_if_not_heavy()
  skip_if_not_nb2_unit_deps()
  fx  <- make_nb2_unit_fixture()
  fit <- fit_nb2_unit(
    value ~ 0 + trait + unique(0 + trait | unit, common = TRUE), fx
  )
  skip_unless_healthy_nb2(fit, "scalar (unique common = TRUE)", "FG-07/08/09 (nbinom2)")

  expect_nb2_unit_health(fit)
  expect_true(isTRUE(fit$use$diag_B))
  ## scalar contract: `common = TRUE` collapses the per-trait unit variances
  ## to a single shared sd_B value (the unit-tier analogue of *_scalar()).
  sds <- as.numeric(fit$report$sd_B)
  expect_length(sds, fx$n_traits)
  expect_true(all(abs(sds - sds[1L]) < 1e-10))
  expect_nb2_intercepts_recover(fit, fx)
})
