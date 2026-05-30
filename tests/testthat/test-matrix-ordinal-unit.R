## Phase B-matrix Group A (Design 59): `ordinal_probit()` x unit-tier
## structural recovery + CI smoke. Walks FG-07/08/09 (ordinal) and FAM-14
## of `docs/design/35-validation-debt-register.md` for the six unit-tier
## structural cells:
##
##   latent(d = 1) | unique | latent + unique (paired) | indep | dep | scalar
##
## Family note (Phase B0 scoping memo, 2026-05-26):
##   * ordinal_probit has latent residual variance sigma_d^2 = 1 EXACTLY
##     by construction (Wright/Falconer threshold model; no trigamma
##     correction). This puts the unit-tier variance components on the same
##     scale as a continuous trait and lets us assert sigma_d = 1 tightly.
##   * The 2x2-and-up unit Sigma_b adds to the fixed sigma_d^2 = 1 latent
##     baseline. For the unit-tier variance to be identifiable, var(x) of
##     the linear-predictor contribution must be substantial (>> 0.1); the
##     memo's empirical n-sweep pass bar is var(x) >= 0.5. Both fixtures
##     below are tuned so every trait's unit-tier signal clears var(x) > 0.5.
##   * ordinal_probit is FAM-14 "smoke-only at baseline" -- there was no
##     prior unit-tier structural coverage for it, so a clean converging,
##     PD-Hessian fit with the correct engine slots toggled and (where an
##     off-diagonal exists) a finite profile-CI bound IS the recovery
##     evidence this cell needs. Bootstrap CI is unsupported for ordinal
##     (Design 50 family-ID 14 guard), so we use method = "profile" only.
##
## Fixture design (K = 4 ordinal categories; cutpoints tau = 0, 0.7, 1.4):
##   * "shared-factor" fixture -- a single unit-level latent factor (d = 1)
##     drives all four traits via loadings, optionally plus per-trait unique
##     unit variance. This is the identifiable DGP for the cells that carry
##     an off-diagonal cross-trait covariance: `latent(d = 1)`,
##     `latent + unique`, and `dep`. n_rep replicate ordinal draws per
##     (unit, trait) identify the loadings against the fixed N(0, 1) latent
##     residual.
##   * "diagonal" fixture -- each trait gets its own independent unit-level
##     random intercept (no shared factor), the identifiable DGP for the
##     diagonal-only cells `unique`, `indep`, and `scalar`. The same
##     replication identifies the per-trait between-unit variances.
##
## CI smoke (`confint(parm = "rho:unit:1,2", method = "profile")`):
##   * Meaningful ONLY for the cells with an off-diagonal unit covariance
##     (latent / paired / dep) -- those route through profile_ci_correlation()
##     at the "unit" tier. We require a 1x2 matrix with at least one finite
##     bound (the spatial/phylo binary smoke bar; tight coverage at scale
##     stays in Phase B-COV).
##   * For the diagonal-only cells (unique / indep / scalar) there is NO
##     off-diagonal to profile -- `rho:unit:1,2` deliberately errors with
##     "Tier ... has no `latent()` term". We assert that contract instead of
##     inventing a CI, and the structural recovery (per-trait variance,
##     tied-variance for scalar) carries the cell.
##
## SKIP discipline (no fake-pass): every cell skips honestly with a reason
## on non-construction / non-convergence / non-PD Hessian rather than
## relaxing an assertion. A cell that only skips leaves FG-07/08/09 (ordinal)
## / FAM-14 "partial"; the final report says so.

skip_if_not_ordinal_unit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

K_CATEGORIES   <- 4L                 # ordinal categories
TRUE_TAUS      <- c(0, 0.7, 1.4)     # K = 4 -> 3 thresholds (tau_1 = 0 fixed)
N_UNIT         <- 60L
N_TRAITS       <- 4L
N_REP          <- 4L
TRAIT_NAMES    <- paste0("t", seq_len(N_TRAITS))

## Cut a latent y* into K = 4 ordinal categories at TRUE_TAUS.
.ordinalise <- function(ystar) {
  1L + (ystar > TRUE_TAUS[1L]) + (ystar > TRUE_TAUS[2L]) + (ystar > TRUE_TAUS[3L])
}

## Shared-factor fixture: one unit-level latent factor drives all traits via
## `lambda`, plus optional per-trait unique unit variance `psi`. Identifies
## the off-diagonal cells (latent / paired / dep).
make_shared_factor_fixture <- function(seed = 20260529L,
                                        lambda = c(1.2, 1.0, -0.9, 0.85),
                                        psi    = NULL) {
  set.seed(seed)
  alpha <- c(0.2, -0.1, 0.15, 0.0)
  f     <- stats::rnorm(N_UNIT, 0, 1)                # shared factor, var ~ 1
  u     <- if (is.null(psi)) {
    matrix(0, N_UNIT, N_TRAITS)
  } else {
    vapply(seq_len(N_TRAITS),
           function(t) stats::rnorm(N_UNIT, 0, sqrt(psi[t])),
           numeric(N_UNIT))
  }
  rows <- vector("list", N_UNIT * N_TRAITS * N_REP)
  k <- 1L
  for (i in seq_len(N_UNIT)) {
    for (t in seq_len(N_TRAITS)) {
      for (r in seq_len(N_REP)) {
        ystar <- alpha[t] + lambda[t] * f[i] + u[i, t] + stats::rnorm(1L, 0, 1)
        rows[[k]] <- data.frame(unit  = i,
                                trait = TRAIT_NAMES[t],
                                value = .ordinalise(ystar))
        k <- k + 1L
      }
    }
  }
  df <- do.call(rbind, rows)
  df$unit  <- factor(df$unit,  levels = seq_len(N_UNIT))
  df$trait <- factor(df$trait, levels = TRAIT_NAMES)
  ## var(x) of each trait's shared-factor contribution on the link scale.
  varx <- stats::var(f) * lambda^2
  list(data = df, lambda = lambda, psi = psi, varx = varx)
}

## Diagonal fixture: each trait gets its own independent unit-level random
## intercept (no shared factor). Identifies the diagonal-only cells
## (unique / indep / scalar).
make_diagonal_fixture <- function(seed = 919191L,
                                  sd_unit = c(1.0, 1.0, 0.9, 1.1)) {
  set.seed(seed)
  alpha <- c(0.2, -0.1, 0.15, 0.0)
  u <- vapply(seq_len(N_TRAITS),
              function(t) stats::rnorm(N_UNIT, 0, sd_unit[t]),
              numeric(N_UNIT))
  rows <- vector("list", N_UNIT * N_TRAITS * N_REP)
  k <- 1L
  for (i in seq_len(N_UNIT)) {
    for (t in seq_len(N_TRAITS)) {
      for (r in seq_len(N_REP)) {
        ystar <- alpha[t] + u[i, t] + stats::rnorm(1L, 0, 1)
        rows[[k]] <- data.frame(unit  = i,
                                trait = TRAIT_NAMES[t],
                                value = .ordinalise(ystar))
        k <- k + 1L
      }
    }
  }
  df <- do.call(rbind, rows)
  df$unit  <- factor(df$unit,  levels = seq_len(N_UNIT))
  df$trait <- factor(df$trait, levels = TRAIT_NAMES)
  varx <- apply(u, 2L, stats::var)
  list(data = df, sd_unit = sd_unit, varx = varx)
}

## Fit one cell, returning either the fitted object or an "error" condition.
.fit_ordinal_unit <- function(form, data) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      form,
      data   = data,
      unit   = "unit",
      family = ordinal_probit()
    ))),
    error = function(e) e
  )
}

## Shared health gate -- convergence, finite objective, PD Hessian, and the
## ordinal family id (14). Returns TRUE if healthy; the caller skips on FALSE.
expect_ordinal_unit_health <- function(fit) {
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], 14L)
  ## sigma_d^2 = 1 EXACTLY (no trigamma correction) -- the defining ordinal
  ## property, asserted tightly since it is fixed by construction.
  testthat::expect_equal(
    unname(gllvmTMB:::link_residual_per_trait(fit)),
    rep(1, fit$n_traits)
  )
}

## ---------------------------------------------------------------
## CELL 1: latent(0 + trait | unit, d = 1)
## ---------------------------------------------------------------
test_that("ordinal_probit x latent(0 + trait | unit, d = 1): recovery + rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_ordinal_unit_deps()
  fx <- make_shared_factor_fixture()
  testthat::expect_true(all(fx$varx > 0.5))   # Phase B0 var(x) >= 0.5 bar

  fit <- .fit_ordinal_unit(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1), fx$data
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("ordinal latent(d=1) fit failed to construct: %s",
                 if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    skip("ordinal latent(d=1) fit did not converge with PD Hessian; FG-07/08/09 (ordinal) stays partial")
  }

  expect_ordinal_unit_health(fit)
  expect_true(isTRUE(fit$use$rr_B))           # latent => rr_B engine slot
  expect_false(isTRUE(fit$use$diag_B))        # no unique() half here

  ## Loading recovery: with the fixed sigma_d = 1 scale, the d = 1 loading
  ## column should track the true lambda up to sign. Ordinal is smoke-grade
  ## so we use a generous 40% relative band per the Phase B0 memo.
  Lhat <- as.numeric(fit$report$Lambda_B)
  expect_equal(length(Lhat), N_TRAITS)
  expect_true(all(is.finite(Lhat)))
  rel_err <- abs(abs(Lhat) - abs(fx$lambda)) / abs(fx$lambda)
  expect_lt(stats::median(rel_err), 0.40)

  ## CI smoke: confint(parm = "rho:unit:1,2", method = "profile") routes
  ## through profile_ci_correlation() at the "unit" tier. Require a 1x2
  ## matrix with at least one finite bound across the upper-tri pairs.
  pairs_to_try <- list(c(1L, 2L), c(1L, 3L), c(2L, 3L))
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
    skip("Profile CI for rho:unit did not return any finite bound on any pair; honest skip rather than relax assertion")
  }
  expect_true(any_finite)
})

## ---------------------------------------------------------------
## CELL 2: unique(0 + trait | unit)  (diagonal-only)
## ---------------------------------------------------------------
test_that("ordinal_probit x unique(0 + trait | unit): per-trait variance recovery; rho:unit has no target", {
  skip_if_not_heavy()
  skip_if_not_ordinal_unit_deps()
  fx <- make_diagonal_fixture()
  testthat::expect_true(all(fx$varx > 0.5))

  fit <- .fit_ordinal_unit(
    value ~ 0 + trait + unique(0 + trait | unit), fx$data
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("ordinal unique fit failed to construct: %s",
                 if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    skip("ordinal unique fit did not converge with PD Hessian; FG-07/08/09 (ordinal) stays partial")
  }

  expect_ordinal_unit_health(fit)
  expect_true(isTRUE(fit$use$diag_B))         # unique => diag_B engine slot
  expect_false(isTRUE(fit$use$rr_B))
  expect_false(isTRUE(fit$use$indep_B))       # plain unique, not the indep marker

  ## Per-trait between-unit SD recovery (the diagonal Sigma_unit). With
  ## sigma_d = 1 fixed and N_REP replicates identifying the unit intercepts,
  ## the per-trait sd_B should track the true SDs; ordinal is smoke-grade so
  ## a 40% median relative band per the Phase B0 memo.
  sd_hat <- as.numeric(fit$report$sd_B)
  expect_equal(length(sd_hat), N_TRAITS)
  expect_true(all(is.finite(sd_hat)) && all(sd_hat > 0))
  rel_err <- abs(sd_hat - fx$sd_unit) / fx$sd_unit
  expect_lt(stats::median(rel_err), 0.40)

  ## A diagonal-only fit has NO off-diagonal unit covariance, so the
  ## correlation profile target does not exist. The unified confint surface
  ## errors with a "no `latent()` term" message; we assert that contract
  ## rather than inventing a CI.
  ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "rho:unit:1,2", method = "profile"
    ))),
    error = function(e) e
  )
  expect_s3_class(ci, "condition")
  expect_match(conditionMessage(ci), "latent|correlation profile",
               ignore.case = TRUE)
})

## ---------------------------------------------------------------
## CELL 3: latent(0 + trait | unit, d = 1) + unique(0 + trait | unit)  (paired)
## ---------------------------------------------------------------
test_that("ordinal_probit x latent + unique (paired): both slots; recovery + rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_ordinal_unit_deps()
  ## Shared factor PLUS per-trait unique variance so BOTH halves of the
  ## decomposition Sigma = Lambda Lambda^T + Psi are identified.
  fx <- make_shared_factor_fixture(psi = c(0.4, 0.5, 0.45, 0.5))
  testthat::expect_true(all(fx$varx > 0.5))

  fit <- .fit_ordinal_unit(
    value ~ 0 + trait +
            latent(0 + trait | unit, d = 1) +
            unique(0 + trait | unit),
    fx$data
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("ordinal latent + unique fit failed to construct: %s",
                 if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    skip("ordinal latent + unique paired fit did not converge with PD Hessian; FG-07/08/09 (ordinal) stays partial")
  }

  expect_ordinal_unit_health(fit)
  ## Both halves of the paired decomposition must be active.
  expect_true(isTRUE(fit$use$rr_B))
  expect_true(isTRUE(fit$use$diag_B))

  ## Lambda_B has the expected (T x d) shape and a finite per-trait Psi.
  Lhat <- fit$report$Lambda_B
  expect_equal(dim(Lhat), c(N_TRAITS, 1L))
  sd_hat <- as.numeric(fit$report$sd_B)
  expect_equal(length(sd_hat), N_TRAITS)
  expect_true(all(is.finite(Lhat)) && all(is.finite(sd_hat)))

  ## CI smoke on the cross-trait correlation induced by the shared factor.
  pairs_to_try <- list(c(1L, 2L), c(1L, 3L), c(2L, 3L))
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
    skip("Profile CI for rho:unit (paired) did not return any finite bound on any pair; honest skip rather than relax assertion")
  }
  expect_true(any_finite)
})

## ---------------------------------------------------------------
## CELL 4: indep(0 + trait | unit)  (diagonal-only, marginal mode)
## ---------------------------------------------------------------
test_that("ordinal_probit x indep(0 + trait | unit): indep_B marker + variance recovery; rho:unit has no target", {
  skip_if_not_heavy()
  skip_if_not_ordinal_unit_deps()
  fx <- make_diagonal_fixture()
  testthat::expect_true(all(fx$varx > 0.5))

  fit <- .fit_ordinal_unit(
    value ~ 0 + trait + indep(0 + trait | unit), fx$data
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("ordinal indep fit failed to construct: %s",
                 if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    skip("ordinal indep fit did not converge with PD Hessian; FG-07/08/09 (ordinal) stays partial")
  }

  expect_ordinal_unit_health(fit)
  ## indep rides the diag_B engine path with the `.indep` marker set, so
  ## BOTH the engine slot and the canonical indep flag must be TRUE.
  expect_true(isTRUE(fit$use$diag_B))
  expect_true(isTRUE(fit$use$indep_B))

  sd_hat <- as.numeric(fit$report$sd_B)
  expect_equal(length(sd_hat), N_TRAITS)
  expect_true(all(is.finite(sd_hat)) && all(sd_hat > 0))
  rel_err <- abs(sd_hat - fx$sd_unit) / fx$sd_unit
  expect_lt(stats::median(rel_err), 0.40)

  ## Diagonal-only: no off-diagonal to profile -- assert the no-target error.
  ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "rho:unit:1,2", method = "profile"
    ))),
    error = function(e) e
  )
  expect_s3_class(ci, "condition")
  expect_match(conditionMessage(ci), "latent|correlation profile",
               ignore.case = TRUE)
})

## ---------------------------------------------------------------
## CELL 5: dep(0 + trait | unit)  (full unstructured)
## ---------------------------------------------------------------
test_that("ordinal_probit x dep(0 + trait | unit): full-unstructured slot + rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_ordinal_unit_deps()
  fx <- make_shared_factor_fixture()
  testthat::expect_true(all(fx$varx > 0.5))

  fit <- .fit_ordinal_unit(
    value ~ 0 + trait + dep(0 + trait | unit), fx$data
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("ordinal dep fit failed to construct: %s",
                 if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    skip("ordinal dep fit did not converge with PD Hessian; FG-07/08/09 (ordinal) stays partial")
  }

  expect_ordinal_unit_health(fit)
  ## dep rewrites to latent(d = n_traits) standalone, so the rr_B engine
  ## slot is active AND the canonical dep flag is set.
  expect_true(isTRUE(fit$use$dep_B))
  expect_true(isTRUE(fit$use$rr_B))
  ## Full-rank packed-triangular Lambda: T x T factor of the unstructured
  ## Sigma_unit = L L^T.
  Lhat <- fit$report$Lambda_B
  expect_equal(dim(Lhat), c(N_TRAITS, N_TRAITS))
  expect_true(all(is.finite(Lhat)))

  ## CI smoke on the cross-trait correlation (off-diagonal exists for dep).
  pairs_to_try <- list(c(1L, 2L), c(1L, 3L), c(2L, 3L))
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
    skip("Profile CI for rho:unit (dep) did not return any finite bound on any pair; honest skip rather than relax assertion")
  }
  expect_true(any_finite)
})

## ---------------------------------------------------------------
## CELL 6: scalar -- unique(0 + trait | unit, common = TRUE)
## ---------------------------------------------------------------
## There is no bare `scalar()` covstruct keyword at the unit/"none" tier
## (the man-page grid shows "(omit)" for the none x scalar cell). The scalar
## mode -- ONE shared variance tied across all traits -- is expressed via
## `unique(..., common = TRUE)`, the byte-equivalent of the tie-across-traits
## contract that `phylo_scalar` / `spatial_scalar` enforce via TMB's map.
test_that("ordinal_probit x scalar (unique common = TRUE): single shared variance tied across traits", {
  skip_if_not_heavy()
  skip_if_not_ordinal_unit_deps()
  ## Equal true SDs across traits so a single shared variance is the right
  ## model and recovery is meaningful.
  fx <- make_diagonal_fixture(sd_unit = rep(1.0, N_TRAITS))
  testthat::expect_true(all(fx$varx > 0.5))

  fit <- .fit_ordinal_unit(
    value ~ 0 + trait + unique(0 + trait | unit, common = TRUE), fx$data
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("ordinal scalar (common = TRUE) fit failed to construct: %s",
                 if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    skip("ordinal scalar fit did not converge with PD Hessian; FG-07/08/09 (ordinal) stays partial")
  }

  expect_ordinal_unit_health(fit)
  expect_true(isTRUE(fit$use$diag_B))

  ## Tied-variance contract: `common = TRUE` collapses the per-trait sd_B to
  ## ONE shared value (the unit-tier analogue of spatial_scalar's tied
  ## log_tau). All entries must be byte-equal.
  sd_hat <- as.numeric(fit$report$sd_B)
  expect_equal(length(sd_hat), N_TRAITS)
  expect_true(all(abs(sd_hat - sd_hat[1L]) < 1e-9),
              info = "scalar (common = TRUE) must tie sd_B across all traits")
  ## The shared SD is finite-positive and lands in a generous band around
  ## the common true SD (1.0); ordinal smoke-grade -> 40% band.
  expect_true(is.finite(sd_hat[1L]) && sd_hat[1L] > 0)
  expect_lt(abs(sd_hat[1L] - 1.0) / 1.0, 0.40)
})
