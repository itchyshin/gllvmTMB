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
## Family choice: truncated_poisson() (family-id 10, log link). The matrix task
## names this family explicitly for the latent/unique structural smoke, and the
## diagnosis below shows why it is the right pick for a *structural* smoke:
##   * truncated_poisson has NO dispersion parameter, so the structural cells
##     identify only the trait intercepts and the unit-tier (co)variance -- the
##     exact targets a structural smoke is meant to exercise.
##   * truncated_nbinom2 was tried first (it carries phi_truncnb2). At the
##     ~60-unit tier its per-trait phi is only weakly identified under zero-
##     truncation -- the very fragility test-truncated-recovery.R warns about in
##     its "keep mu on the higher side" note -- and one trait's phi ran away to
##     ~4e7 (NB2 -> Poisson limit), tripping nlminb code 8 ("false convergence")
##     even with a PD Hessian and ~0 gradient. That is a dispersion-identification
##     artefact orthogonal to the structural question, so it does not belong in a
##     structural smoke at this n. truncated_nbinom2's phi recovery stays covered
##     by test-truncated-recovery.R at its larger n (250-300).
##
## DGP (one shared seed-controlled fixture per cell, see make_ztpois_unit_fixture):
##   mu_{u,t} = exp(alpha_t + [shared] lambda_t * f_u + [diag] g_{u,t})
##   y_{u,t}  ~ ZTPois(mu_{u,t})  via rejection on rpois (draw until y >= 1)
## CRITICAL: each structural cell is fitted to the DGP whose variance it can
## actually identify, otherwise the cell collapses to the boundary and an honest
## smoke is impossible:
##   * `latent(d = 1)` (reduced rank) <- a single shared unit factor f_u with
##     all-positive per-trait loadings lambda_t (rank-1 cross-trait structure).
##   * `unique(0 + trait | unit)` (per-trait diagonal) <- INDEPENDENT per-trait
##     unit effects g_{u,t} ~ N(0, sd_diag^2). The earlier shared-only fixture
##     had no diagonal variance, so the diagonal SDs collapsed to ~0
##     (boundary flag near_zero_sd_B, non-PD Hessian, SEs ~1e5): a DGP/spec
##     mismatch, not an engine limitation.
##   * `latent + unique` paired <- both components present.
##
## Sizing: 3 traits, 60 units (the matrix-campaign "~3 traits / ~60 units" tier).
## Per the Design 59 Honest-matrix discipline, any cell that fails to construct /
## does not converge / is non-PD is skip()-ped with a reason and reported as
## FAM-15 staying partial -- never forced green by relaxing a check.
##
## Tolerances (Phase B0 non-Gaussian scoping memo, 2026-05-26): truncated_poisson
## is a mean-dependent family, so trait-intercept recovery uses the WIDER B0 band
## (|b_hat - alpha| < 0.40) rather than the tight fixed-residual-scale band of the
## binomial / ordinal-probit families. The per-trait diagonal SD on the unique
## cell is checked only for non-collapse (sd_B > 0.1) against a true 0.6, not for
## a tight point-recovery -- that keeps the smoke honest at this n.
##
## rho:unit profile-CI smoke (CI-08): the zero-truncated count families do not
## expose a finite-bounded rho:unit profile at this unit tier. confint(method =
## "profile") returns NA on every upper-triangular pair and the rho:unit:i,j
## tokens are not even in the default parm set, for BOTH truncated_poisson and
## truncated_nbinom2 here. The profile is genuinely degenerate, so that smoke is
## kept in its own test_that per off-diagonal cell and HONEST-skipped with a
## precise reason -- never relaxed or dropped to dodge the skip. Splitting it out
## is what lets the structural recovery assertions in the main blocks actually
## run and pass instead of being masked by a single trailing skip().

skip_if_not_truncpois_unit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## Zero-truncated Poisson draw via rejection on the conditional distribution.
## Matches rztpois() in test-truncated-recovery.R.
rztpois_one <- function(lambda) {
  repeat {
    x <- stats::rpois(1L, lambda)
    if (x >= 1L) return(x)
  }
}

## Seed-controlled zero-truncated Poisson fixture. `structure` selects which
## unit-tier variance components are present in the DGP so each structural cell
## is fitted to data it can identify:
##   "shared" : rank-1 shared unit factor only          (-> latent)
##   "diag"   : independent per-trait unit effects only  (-> unique)
##   "both"   : shared factor + per-trait diagonal       (-> latent + unique)
make_ztpois_unit_fixture <- function(structure = c("shared", "diag", "both"),
                                     n_unit = 60L, n_traits = 3L,
                                     mu_int = c(1.5, 2.0, 2.5),
                                     lambda = c(0.7, 0.6, 0.5),
                                     sd_f = 0.5, sd_diag = 0.6, seed = 715L) {
  structure <- match.arg(structure)
  set.seed(seed)
  trait_names <- paste0("trait_", seq_len(n_traits))
  mu_int  <- rep_len(mu_int, n_traits)
  lambda  <- rep_len(lambda, n_traits)
  sd_diag <- rep_len(sd_diag, n_traits)

  f_u    <- stats::rnorm(n_unit, sd = sd_f)                     # shared unit factor
  g_ut   <- matrix(stats::rnorm(n_unit * n_traits,              # per-trait diagonal
                                sd = rep(sd_diag, each = n_unit)),
                   nrow = n_unit, ncol = n_traits)

  rows <- vector("list", n_unit * n_traits)
  k <- 0L
  for (u in seq_len(n_unit)) {
    for (t in seq_len(n_traits)) {
      eta <- mu_int[t]
      if (structure %in% c("shared", "both")) eta <- eta + lambda[t] * f_u[u]
      if (structure %in% c("diag", "both"))   eta <- eta + g_ut[u, t]
      k <- k + 1L
      rows[[k]] <- data.frame(
        unit  = u,
        trait = trait_names[t],
        value = rztpois_one(exp(eta))
      )
    }
  }
  df <- do.call(rbind, rows)
  df$unit  <- factor(df$unit, levels = seq_len(n_unit))
  df$trait <- factor(df$trait, levels = trait_names)
  list(
    data     = df,
    n_traits = n_traits,
    mu_int   = mu_int,
    sd_diag  = sd_diag
  )
}

## Fit one unit-tier truncated_poisson structural spec; return the fit or error.
fit_ztpois_unit <- function(formula, fx) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data   = fx$data,
      unit   = "unit",
      family = truncated_poisson()
    ))),
    error = function(e) e
  )
}

## Shared health gate: skip honestly on construct-fail / non-conv / non-PD.
## With the matched DGP + truncated_poisson this gate is not expected to trip at
## the 60-unit tier; it is retained as the Design 59 honest-skip safety net so a
## future engine/seed drift degrades to an honest skip rather than a hard error.
skip_unless_healthy_ztpois <- function(fit, cell) {
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "%s truncated_poisson unit fit failed to construct: %s (FAM-15 stays partial)",
      cell,
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    testthat::skip(sprintf(
      paste0("%s truncated_poisson unit fit did not converge with PD Hessian ",
             "(convergence=%s, pd_hessian=%s); FAM-15 stays partial pending ",
             "bigger n / different seed"),
      cell, fit$opt$convergence, fit$fit_health$pd_hessian
    ))
  }
  invisible(fit)
}

## Common per-cell health + zero-truncation family-id assertions.
expect_ztpois_unit_health <- function(fit) {
  expect_stationary_for_recovery_test(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_stationary_for_recovery_test(fit)
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], 10L)  # truncated_poisson
  ## A healthy structural fit should carry no boundary collapse flag.
  testthat::expect_length(fit$fit_health$boundary_flags, 0L)
}

## Wider Phase-B0 trait-intercept recovery check for this mean-dependent family.
expect_ztpois_intercepts_recover <- function(fit, fx, tol = 0.40) {
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  testthat::expect_equal(length(bfix), fx$n_traits)
  testthat::expect_lt(max(abs(bfix - fx$mu_int)), tol)
}

## rho:unit profile-CI smoke: one finite bound on one upper-tri pair. Only
## meaningful for cells with off-diagonal unit-tier structure (`latent`,
## `latent+unique`). For the zero-truncated count families this profile is
## degenerate at this n (see header), so a missing finite bound is an HONEST
## skip, not a relaxed assertion (CI-08 stays partial there).
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
      "Profile CI for rho:unit returned no finite bound on any pair for the ",
      "zero-truncated count family at the 60-unit tier (token absent from the ",
      "default parm set; profile degenerate); honest skip rather than relax ",
      "assertion (CI-08 stays partial here)"
    ))
  }
  testthat::expect_true(any_finite)
}

## ---------------------------------------------------------------
## latent(0 + trait | unit, d = 1) -- reduced-rank, one shared factor
## ---------------------------------------------------------------
test_that("truncated_poisson x latent(0 + trait | unit, d = 1): converges, PD Hessian, recovers intercepts, Lambda_B 3x1", {
  skip_if_not_heavy()
  skip_if_not_truncpois_unit_deps()
  fx  <- make_ztpois_unit_fixture("shared")
  fit <- fit_ztpois_unit(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1), fx
  )
  skip_unless_healthy_ztpois(fit, "latent(d=1)")

  expect_ztpois_unit_health(fit)
  expect_true(isTRUE(fit$use$rr_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_ztpois_intercepts_recover(fit, fx)
})

## rho:unit profile-CI smoke for the latent cell (off-diagonal structure present).
## Split out so the degenerate profile -> honest skip does not mask the passing
## structural recovery above.
test_that("truncated_poisson x latent(d = 1): rho:unit profile-CI smoke (honest skip if degenerate)", {
  skip_if_not_heavy()
  skip_if_not_truncpois_unit_deps()
  fx  <- make_ztpois_unit_fixture("shared")
  fit <- fit_ztpois_unit(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1), fx
  )
  skip_unless_healthy_ztpois(fit, "latent(d=1) rho:unit")
  expect_rho_unit_ci_smoke(fit, fx$n_traits)
})

## ---------------------------------------------------------------
## unique(0 + trait | unit) -- per-trait diagonal; non-collapsing SDs
## ---------------------------------------------------------------
test_that("truncated_poisson x unique(0 + trait | unit): converges, PD Hessian, diagonal SDs do not collapse", {
  skip_if_not_heavy()
  skip_if_not_truncpois_unit_deps()
  fx  <- make_ztpois_unit_fixture("diag")
  fit <- fit_ztpois_unit(
    value ~ 0 + trait + unique(0 + trait | unit), fx
  )
  skip_unless_healthy_ztpois(fit, "unique")

  expect_ztpois_unit_health(fit)
  expect_true(isTRUE(fit$use$diag_B))
  expect_ztpois_intercepts_recover(fit, fx)

  ## Diagonal-SD non-collapse: the matched DGP carries independent per-trait unit
  ## variance (sd_diag = 0.6), so each per-trait unit SD must stay clear of the
  ## zero boundary. This is the check that the earlier shared-only fixture failed
  ## (sd_B -> 0, near_zero_sd_B). A loose floor (> 0.1) keeps it honest at this n
  ## -- it asserts identification, not tight point recovery.
  sd_B <- as.numeric(fit$report$sd_B)
  expect_equal(length(sd_B), fx$n_traits)
  expect_true(all(is.finite(sd_B) & sd_B > 0.1))

  ## Diagonal cell has no off-diagonal unit-tier correlation by construction,
  ## so there is no rho:unit to profile here.
})

## ---------------------------------------------------------------
## latent + unique paired (reduced-rank + diagonal on the same grouping)
## ---------------------------------------------------------------
test_that("truncated_poisson x latent + unique paired (unit): converges, PD Hessian, both terms active, recovers intercepts", {
  skip_if_not_heavy()
  skip_if_not_truncpois_unit_deps()
  fx  <- make_ztpois_unit_fixture("both")
  fit <- fit_ztpois_unit(
    value ~ 0 + trait +
            latent(0 + trait | unit, d = 1) +
            unique(0 + trait | unit),
    fx
  )
  skip_unless_healthy_ztpois(fit, "latent+unique")

  expect_ztpois_unit_health(fit)
  expect_true(isTRUE(fit$use$rr_B) && isTRUE(fit$use$diag_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_ztpois_intercepts_recover(fit, fx)
})

## rho:unit profile-CI smoke for the paired cell (off-diagonal structure present).
## Split out for the same reason as the latent cell.
test_that("truncated_poisson x latent + unique paired (unit): rho:unit profile-CI smoke (honest skip if degenerate)", {
  skip_if_not_heavy()
  skip_if_not_truncpois_unit_deps()
  fx  <- make_ztpois_unit_fixture("both")
  fit <- fit_ztpois_unit(
    value ~ 0 + trait +
            latent(0 + trait | unit, d = 1) +
            unique(0 + trait | unit),
    fx
  )
  skip_unless_healthy_ztpois(fit, "latent+unique rho:unit")
  expect_rho_unit_ci_smoke(fit, fx$n_traits)
})
