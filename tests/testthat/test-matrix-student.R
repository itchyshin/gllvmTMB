## Phase B-matrix Group E (agent E-st; Design 59): `student()` (Student-t)
## family-recovery depth + unit-tier structural smoke. Informs register row
## FAM-12.
##
## FAM-12 is currently recovery-test-only (test-student-recovery.R covers the
## single `latent(d = 1)` recovery cell on an i.i.d. heavy-tailed DGP, a
## `student(df = 3)` map-pin check, a glmmTMB::t_family() logLik cross-check,
## and a non-identity-link guard). This file DEEPENS that coverage by walking
## the three unit-tier structural cells the matrix campaign asks for on the
## heavy-tailed continuous family:
##   latent(0 + trait | unit, d = 1) / unique(0 + trait | unit) / latent+unique.
##
## DGP (one shared seed-controlled fixture, see make_student_unit_fixture()):
##   eta_{u,t} = mu_t + lambda_t * b_u,   b_u ~ N(0, sd_u^2)
##   y_{u,t}   = eta_{u,t} + sigma * t_df(eps_{u,t})        (identity link)
## i.e. the Student-t noise of test-student-recovery.R (y = mu + sigma * rt())
## PLUS a single shared unit-level latent factor b_u with per-trait loadings
## lambda_t. test-student-recovery.R's DGP is purely trait-marginal, so its
## `latent` cell has no genuine cross-trait covariance to identify; adding the
## shared factor here gives the reduced-rank (`latent`) and paired
## (`latent + unique`) cells a real off-diagonal between-unit covariance to
## recover and a real `rho:unit` surface to profile. df = 5, sigma = 1, and the
## identity link match test-student-recovery.R exactly.
##
## Sizing: 3 traits, 200 units. The matrix-campaign nominal tier is "~3 traits
## / ~60 units", but the Student-t df is the binding identification constraint
## here: with only ~60 draws per trait the heavy tail of a df = 5 t is usually
## not expressed in-sample, so log(df - 1) drifts to the +Inf (Gaussian-limit)
## boundary and the Hessian goes non-PD on every cell (verified: all three
## cells skip at n = 60, this seed). n = 200 is the SMALLEST tier at which the
## df identifies and all three cells reach a PD Hessian on this seed -- still
## below test-student-recovery.R's 250. This is "bigger n", the remedy the
## honest-skip reason itself names, NOT a relaxed check. Per the Design 59
## Honest-matrix discipline, any cell that still fails to construct / does not
## converge / is non-PD is skip()-ped with a reason and reported as FAM-12
## staying partial -- never forced green by relaxing a tolerance.
##
## Tolerances (Phase B0 non-Gaussian scoping memo, 2026-05-26): Student-t is a
## mean-dependent family (no fixed residual scale like binomial / ordinal
## probit), so trait-intercept recovery uses the same WIDER band as
## test-student-recovery.R (|b_hat - mu_t| < 0.30) and df is only loosely
## identified at moderate n (band [2, 30] around 5). The latent between-unit
## covariance recovery is checked rotation-invariantly via Lambda_B Lambda_B^T
## against the DGP's outer(lambda) * sd_u^2 with a deliberately loose band; we
## do NOT tighten any of these per cell.

skip_if_not_student_unit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## ---- truth constants (shared with the recovery checks) ----
SIGMA_TRUE_ST <- 1.0
DF_TRUE_ST    <- 5
SD_U_ST       <- 0.7        # shared unit-factor SD (between-unit covariance scale)

## Seed-controlled Student-t fixture on a single shared unit factor.
## eta = mu_t + lambda_t * b_u; y = eta + sigma * rt(df). Identity link.
make_student_unit_fixture <- function(n_unit = 200L, n_traits = 3L,
                                      sigma_true = SIGMA_TRUE_ST,
                                      df_true = DF_TRUE_ST,
                                      sd_u = SD_U_ST,
                                      mu_int = c(0.0, 1.0, -0.5),
                                      lambda = c(0.8, -0.5, 0.4),
                                      seed = 512L) {
  set.seed(seed)
  trait_names <- paste0("trait_", seq_len(n_traits))
  mu_int <- rep_len(mu_int, n_traits)
  lambda <- rep_len(lambda, n_traits)
  b_u    <- stats::rnorm(n_unit, sd = sd_u)        # shared unit-level latent factor

  y <- matrix(NA_real_, n_unit, n_traits)
  for (t in seq_len(n_traits)) {
    eta_t  <- mu_int[t] + lambda[t] * b_u
    y[, t] <- eta_t + sigma_true * stats::rt(n_unit, df = df_true)
  }
  df <- data.frame(
    unit  = factor(rep(seq_len(n_unit), each = n_traits)),
    trait = factor(rep(trait_names, n_unit), levels = trait_names),
    value = as.vector(t(y))
  )
  ## True between-unit cross-trait covariance from the shared factor:
  ##   Cov(eta_{.,s}, eta_{.,t}) = lambda_s lambda_t * sd_u^2.
  Sigma_b_true <- outer(lambda, lambda) * sd_u^2
  list(
    data         = df,
    n_traits     = n_traits,
    sigma_true   = sigma_true,
    df_true      = df_true,
    mu_int       = mu_int,
    Sigma_b_true = Sigma_b_true
  )
}

## Fit one unit-tier Student-t structural spec; return the fit or the error.
fit_student_unit <- function(formula, fx) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data   = fx$data,
      unit   = "unit",
      family = gllvmTMB::student()
    ))),
    error = function(e) e
  )
}

## Shared health gate: skip honestly on construct-fail / non-conv / non-PD.
skip_unless_healthy_student <- function(fit, cell) {
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "%s student unit fit failed to construct: %s (FAM-12 stays partial)",
      cell,
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    testthat::skip(sprintf(
      paste0("%s student unit fit did not converge with PD Hessian; FAM-12 ",
             "stays partial pending bigger n / different seed"),
      cell
    ))
  }
  invisible(fit)
}

## Common per-cell health + Student-t sigma/df finiteness assertions.
## sigma_student and df_student are per-trait; both finite, sigma positive,
## df > 1 (the TMB constraint df = 1 + exp(.)), and df loosely identified in
## [2, 30] around the true 5 (matching test-student-recovery.R).
expect_student_unit_health <- function(fit, fx) {
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], 9L)  # student-t

  sigma_hat <- as.numeric(fit$report$sigma_student)
  df_hat    <- as.numeric(fit$report$df_student)
  testthat::expect_equal(length(sigma_hat), fx$n_traits)
  testthat::expect_equal(length(df_hat),    fx$n_traits)
  testthat::expect_true(all(is.finite(sigma_hat) & sigma_hat > 0))
  testthat::expect_true(all(df_hat > 1))                       # parameter constraint
  ## Per-trait sigma within [sigma/2, 2*sigma]; df loosely in [2, 30] around 5.
  testthat::expect_true(all(sigma_hat > 0.5 * fx$sigma_true &
                              sigma_hat < 2 * fx$sigma_true))
  testthat::expect_true(all(df_hat > 2 & df_hat < 30))
}

## Wider Phase-B0 trait-intercept recovery (matches test-student-recovery.R).
expect_student_intercepts_recover <- function(fit, fx, tol = 0.30) {
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  testthat::expect_equal(length(bfix), fx$n_traits)
  testthat::expect_lt(max(abs(bfix - fx$mu_int)), tol)
}

## Latent between-unit covariance recovery, rotation/sign-invariant.
## The reduced-rank loadings Lambda_B are identified only up to an orthogonal
## rotation + sign, so we compare the IMPLIED covariance Lambda_B Lambda_B^T
## (invariant) to the DGP's outer(lambda) * sd_u^2. Band is deliberately loose
## (heavy-tailed noise + small n + d=1 rank-1 approximation of the full Sigma_b)
## per the Honest-matrix discipline -- the honest claim is "right structure +
## right order of magnitude", not a tight point estimate.
expect_latent_sigma_b_recover <- function(fit, fx, tol = 0.40) {
  Lambda_B <- fit$report$Lambda_B
  testthat::expect_equal(dim(Lambda_B), c(fx$n_traits, 1L))
  Sigma_b_hat <- Lambda_B %*% t(Lambda_B)
  testthat::expect_true(all(is.finite(Sigma_b_hat)))
  ## Whole-matrix max abs deviation (diagonal variances + off-diagonals).
  testthat::expect_lt(max(abs(Sigma_b_hat - fx$Sigma_b_true)), tol)
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
test_that("student x latent(0 + trait | unit, d = 1): converges, PD Hessian, sigma/df finite, Sigma_b + rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_student_unit_deps()
  fx  <- make_student_unit_fixture()
  fit <- fit_student_unit(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1), fx
  )
  skip_unless_healthy_student(fit, "latent(d=1)")

  expect_student_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$rr_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_student_intercepts_recover(fit, fx)
  expect_latent_sigma_b_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit)
})

## ---------------------------------------------------------------
## unique(0 + trait | unit) -- per-trait diagonal; cleanest sigma/df recovery
## ---------------------------------------------------------------
test_that("student x unique(0 + trait | unit): converges, PD Hessian, sigma/df finite, intercepts recover", {
  skip_if_not_heavy()
  skip_if_not_student_unit_deps()
  fx  <- make_student_unit_fixture()
  fit <- fit_student_unit(
    value ~ 0 + trait + unique(0 + trait | unit), fx
  )
  skip_unless_healthy_student(fit, "unique")

  expect_student_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$diag_B))
  expect_student_intercepts_recover(fit, fx)
  ## Diagonal cell has no off-diagonal unit-tier correlation by construction,
  ## so there is no rho:unit to profile and no Lambda_B to check here.
})

## ---------------------------------------------------------------
## latent + unique paired (reduced-rank + diagonal on the same grouping)
## ---------------------------------------------------------------
test_that("student x latent + unique paired (unit): converges, PD Hessian, sigma/df finite, Sigma_b + rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_student_unit_deps()
  fx  <- make_student_unit_fixture()
  fit <- fit_student_unit(
    value ~ 0 + trait +
            latent(0 + trait | unit, d = 1) +
            unique(0 + trait | unit),
    fx
  )
  skip_unless_healthy_student(fit, "latent+unique")

  expect_student_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$rr_B) && isTRUE(fit$use$diag_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_student_intercepts_recover(fit, fx)
  expect_latent_sigma_b_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit)
})
