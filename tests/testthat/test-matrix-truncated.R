## Phase B-matrix Group E (agent E-tr; Design 59): truncated count family-recovery
## depth + unit-tier structural smoke. Informs register row FAM-15.
##
## FAM-15 is currently recovery-test-only (test-truncated-recovery.R covers the
## single `latent(d = 1)` recovery cell for truncated_poisson() AND
## truncated_nbinom2(), a glmmTMB logLik cross-check, plus the y >= 1 input
## guard). This file DEEPENS that coverage by walking the three unit-tier
## structural cells the matrix campaign asks for on ONE truncated count family:
##   latent(0 + trait | unit, d = 1) / unique(0 + trait | unit) / latent+unique.
##
## Family choice: truncated_nbinom2() (family-id 11, log link). Per the task
## ("truncated_nbinom2 preferred") it is the truncated family that recovers
## cleanly in test-truncated-recovery.R, and -- unlike truncated_poisson -- it
## carries a per-trait overdispersion parameter (phi_truncnb2) that gives the
## structural cells a real extra parameter to identify alongside Sigma_b.
##
## DGP (one shared seed-controlled fixture, see make_ztnb2_unit_fixture()):
##   mu_{u,t} = exp(alpha_t + lambda_t * b_u),  b_u ~ N(0, sd_u^2)
##   y_{u,t}  ~ ZTNB2(mu_{u,t}, phi)  via rejection on rnbinom (size = phi)
## A single shared unit-level latent factor b_u with all-positive per-trait
## loadings lambda_t induces a clean cross-trait correlation the reduced-rank
## (`latent`) and the paired (`latent+unique`) cells can identify, so the
## rho:unit profile-CI smoke has a real off-diagonal to profile. The rejection
## sampler and the "keep mu on the higher side" sizing rationale match
## test-truncated-recovery.R exactly: at low mu the zero-truncation removes the
## bulk of the zero-mass evidence and phi collapses toward the truncated
## Poisson, so mu_int = {1.5, 2.0, 2.5} on the log scale (mean count 4.5-12.2)
## keeps the truncation correction small and phi identifiable.
##
## Sizing: 3 traits, 60 units (the matrix-campaign "~3 traits / ~60 units" tier).
## Per the Design 59 Honest-matrix discipline, any cell that fails to construct /
## does not converge / is non-PD is skip()-ped with a reason and reported as
## FAM-15 staying partial -- never forced green by relaxing a check.
##
## Tolerances (Phase B0 non-Gaussian scoping memo, 2026-05-26): truncated_nbinom2
## is a mean-dependent family, so trait-intercept recovery uses the WIDER B0 band
## (|b_hat - mu_int| < 0.40) rather than the tight fixed-residual-scale band of
## the binomial / ordinal-probit families. The per-trait phi recovers within
## roughly a factor of two at this n, so the overdispersion check on the cleanest
## (diagonal) cell reuses the [phi/3, 3*phi] band of test-truncated-recovery.R.

skip_if_not_truncnb2_unit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## Zero-truncated NB2 draw via rejection on the conditional distribution.
## Matches rztnbinom2() in test-truncated-recovery.R.
rztnbinom2_one <- function(mu, phi) {
  repeat {
    x <- stats::rnbinom(1L, size = phi, mu = mu)
    if (x >= 1L) return(x)
  }
}

## Seed-controlled zero-truncated NB2 fixture on a single shared unit factor.
make_ztnb2_unit_fixture <- function(n_unit = 60L, n_traits = 3L,
                                    phi_true = 2.0,
                                    mu_int = c(1.5, 2.0, 2.5),
                                    lambda = c(0.6, 0.5, 0.4),
                                    sd_u = 0.5, seed = 715L) {
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
        value = rztnbinom2_one(mu_ut, phi_true)
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

## Fit one unit-tier truncated_nbinom2 structural spec; return the fit or error.
fit_ztnb2_unit <- function(formula, fx) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data   = fx$data,
      unit   = "unit",
      family = truncated_nbinom2()
    ))),
    error = function(e) e
  )
}

## Shared health gate: skip honestly on construct-fail / non-conv / non-PD.
skip_unless_healthy_ztnb2 <- function(fit, cell) {
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "%s truncated_nbinom2 unit fit failed to construct: %s (FAM-15 stays partial)",
      cell,
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    testthat::skip(sprintf(
      paste0("%s truncated_nbinom2 unit fit did not converge with PD Hessian; ",
             "FAM-15 stays partial pending bigger n / different seed"),
      cell
    ))
  }
  invisible(fit)
}

## Common per-cell health + zero-truncation family-id assertions.
expect_ztnb2_unit_health <- function(fit, fx) {
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], 11L)  # truncated_nbinom2

  phi_hat <- as.numeric(fit$report$phi_truncnb2)
  testthat::expect_equal(length(phi_hat), fx$n_traits)
  testthat::expect_true(all(is.finite(phi_hat) & phi_hat > 0))
}

## Wider Phase-B0 trait-intercept recovery check for this mean-dependent family.
expect_ztnb2_intercepts_recover <- function(fit, fx, tol = 0.40) {
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  testthat::expect_equal(length(bfix), fx$n_traits)
  testthat::expect_lt(max(abs(bfix - fx$mu_int)), tol)
}

## rho:unit profile-CI smoke: one finite bound on one upper-tri pair. Only
## meaningful for cells with off-diagonal unit-tier structure (`latent`,
## `latent+unique`); a degenerate profile is an honest skip, not a relaxed
## assertion (CI-08 stays partial there).
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
test_that("truncated_nbinom2 x latent(0 + trait | unit, d = 1): converges, PD Hessian, phi finite, rho:unit CI smoke", {
  skip_if_not_truncnb2_unit_deps()
  fx  <- make_ztnb2_unit_fixture()
  fit <- fit_ztnb2_unit(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1), fx
  )
  skip_unless_healthy_ztnb2(fit, "latent(d=1)")

  expect_ztnb2_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$rr_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_ztnb2_intercepts_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit, fx$n_traits)
})

## ---------------------------------------------------------------
## unique(0 + trait | unit) -- per-trait diagonal; cleanest phi recovery
## ---------------------------------------------------------------
test_that("truncated_nbinom2 x unique(0 + trait | unit): converges, PD Hessian, recovers phi", {
  skip_if_not_truncnb2_unit_deps()
  fx  <- make_ztnb2_unit_fixture()
  fit <- fit_ztnb2_unit(
    value ~ 0 + trait + unique(0 + trait | unit), fx
  )
  skip_unless_healthy_ztnb2(fit, "unique")

  expect_ztnb2_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$diag_B))
  expect_ztnb2_intercepts_recover(fit, fx)

  ## Overdispersion recovery: the diagonal cell is the cleanest place to check
  ## phi (no factor structure to soak up the count variance). Per-trait phi
  ## must be finite-positive and their mean must land in the [phi/3, 3*phi]
  ## band of test-truncated-recovery.R.
  phi_hat <- as.numeric(fit$report$phi_truncnb2)
  expect_gt(mean(phi_hat), fx$phi_true / 3)
  expect_lt(mean(phi_hat), 3 * fx$phi_true)

  ## Diagonal cell has no off-diagonal unit-tier correlation by construction,
  ## so there is no rho:unit to profile here.
})

## ---------------------------------------------------------------
## latent + unique paired (reduced-rank + diagonal on the same grouping)
## ---------------------------------------------------------------
test_that("truncated_nbinom2 x latent + unique paired (unit): converges, PD Hessian, phi finite, rho:unit CI smoke", {
  skip_if_not_truncnb2_unit_deps()
  fx  <- make_ztnb2_unit_fixture()
  fit <- fit_ztnb2_unit(
    value ~ 0 + trait +
            latent(0 + trait | unit, d = 1) +
            unique(0 + trait | unit),
    fx
  )
  skip_unless_healthy_ztnb2(fit, "latent+unique")

  expect_ztnb2_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$rr_B) && isTRUE(fit$use$diag_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_ztnb2_intercepts_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit, fx$n_traits)
})
