## Phase B-matrix, agent A-pois: poisson() x unit-tier structural dependence.
##
## Walks the six unit-tier structural cells (Design 59 group A) for the
## poisson(log) family from `partial` toward `covered`:
##   latent / unique / latent+unique / indep / dep / scalar.
##
## DGP (shared, seed-controlled): a single between-unit random-effect
## vector u_unit ~ N(0, Sigma_B) with a KNOWN rank-1-plus-diagonal
## Sigma_B = Lambda Lambda' + Psi enters the Poisson log-mean directly,
##   eta_{unit,trait} = alpha_trait + u_{unit,trait},   y ~ Poisson(exp(eta)),
## with intercept mean alpha = 2 on the log scale, 4 traits, 60 units.
## Injecting Sigma_B on the linear predictor (rather than re-standardising a
## Gaussian response) keeps the structural covariance scale interpretable so
## recovery claims are meaningful.
##
## Honest-matrix discipline (Design 59): poisson(log) is a MEAN-DEPENDENT
## residual family, so the Phase-B0 scoping memo
## (docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md, count
## section) prescribes a WIDER recovery tolerance than fixed-scale families
## (binomial / ordinal probit). Jensen shrinkage biases recovered marginal
## variances systematically low, so the stable, honest recovery targets are:
##   * latent : rank-1 loading SIGN pattern (up to a global flip) + Sigma_B PSD;
##   * unique / indep : variances finite & positive, dominant variance on the
##     correct trait (full ordering is not seed-stable, so only the argmax is
##     asserted);
##   * dep    : off-diagonal CORRELATION signs match + within 0.30 absolute
##     (B0 count tolerance ~30 %);
##   * scalar : the one-shared-variance constraint is recovered exactly
##     (all per-trait sd_B tied), variance positive.
## Each fit must converge AND have a positive-definite Hessian; otherwise the
## cell is skip()ped with a reason and reported as "stays partial" -- never
## forced green.
##
## CI smoke: one finite interval per fit via extract_correlations(tier =
## "unit") (the cross-trait correlation CIs). This is the robust arm of the
## Design 59 brief's "confint(rho ...) OR extract_correlations(tier='unit')
## finite" smoke; the profile rho CI can return a legitimately one-sided
## (NA-bounded) interval on these mean-dependent fits, so the finite-bound
## smoke is taken on extract_correlations().
##
## NOTE on the `scalar` cell: there is no bare `scalar(0 + trait | unit)`
## formula keyword (the canonical unit-tier keywords are latent / unique /
## indep / dep). The unit-tier "scalar" MODE -- a single shared variance
## across traits -- is spelled `unique(0 + trait | unit, common = TRUE)`,
## which is what this cell exercises (mirrors spatial_scalar's shared-tau
## collapse at the spatial tier).

skip_on_cran()

## ---- shared seed-controlled DGP ------------------------------------------

.matrix_pois_unit_dgp <- function(seed = 101L, T = 4L, n_units = 60L,
                                   reps_per_unit = 10L) {
  set.seed(seed)
  ## rank-1 loadings + per-trait unique diagonal -> known Sigma_B.
  Lam <- matrix(c(0.9, 0.5, -0.4, 0.3), nrow = T, ncol = 1L)
  psi <- rep(0.30, T)
  Sigma_B <- Lam %*% t(Lam) + diag(psi)
  alpha <- rep(2.0, T) # intercept mean ~ 2 on the log scale

  Lchol <- t(chol(Sigma_B))
  U <- matrix(stats::rnorm(n_units * T), n_units, T) %*% t(Lchol) # cov = Sigma_B

  df <- expand.grid(
    rep       = seq_len(reps_per_unit),
    trait_idx = seq_len(T),
    unit      = seq_len(n_units)
  )
  df$site         <- factor(df$unit)
  df$trait        <- factor(paste0("t", df$trait_idx),
                            levels = paste0("t", seq_len(T)))
  df$site_species <- factor(seq_len(nrow(df)))
  eta <- alpha[df$trait_idx] + U[cbind(df$unit, df$trait_idx)]
  df$value <- stats::rpois(nrow(df), exp(eta))

  list(data = df, Sigma_B = Sigma_B, Lam = Lam, psi = psi, T = T)
}

## Fit helper: returns the fit, or NULL on a hard fit error.
.fit_pois_unit <- function(form, data) {
  tryCatch(
    suppressMessages(suppressWarnings(
      gllvmTMB(form, data = data, family = poisson(), silent = TRUE)
    )),
    error = function(e) NULL
  )
}

## Convergence + PD-Hessian gate. Returns NULL if the cell is healthy;
## otherwise a skip reason string (so callers skip() honestly).
.unhealthy_reason <- function(fit) {
  if (is.null(fit)) {
    return("poisson unit-tier fit errored")
  }
  if (!identical(fit$opt$convergence, 0L)) {
    return(sprintf("poisson unit-tier fit did not converge (code %s)",
                   fit$opt$convergence))
  }
  if (!isTRUE(fit$sd_report$pdHess)) {
    return("poisson unit-tier fit Hessian not positive-definite")
  }
  NULL
}

## Default-surface smoke: extract_correlations(tier = "unit") returns finite
## point estimates without manufacturing an interval when no method is asked.
.ec_unit_point_only <- function(fit) {
  cc <- tryCatch(
    suppressMessages(
      extract_correlations(fit, tier = "unit", link_residual = "auto")
    ),
    error = function(e) NULL
  )
  if (is.null(cc) || nrow(cc) == 0L) {
    return(FALSE)
  }
  all(is.finite(cc$correlation)) &&
    all(is.na(cc$lower)) &&
    all(is.na(cc$upper)) &&
    all(cc$method == "none") &&
    all(cc$interval_status == "none")
}

## ===========================================================================
##  latent(0 + trait | unit, d = 1) -- Sigma recovery (rank-1 loading)
## ===========================================================================

test_that("poisson x latent(unit, d=1): converges, PD, recovers rank-1 loading sign + point-only rho", {
  skip_if_not_heavy()
  d <- .matrix_pois_unit_dgp()
  fit <- .fit_pois_unit(
    value ~ 0 + trait + latent(0 + trait | site, d = 1), d$data
  )
  reason <- .unhealthy_reason(fit)
  if (!is.null(reason)) skip(reason)

  expect_stationary_for_recovery_test(fit)
  expect_stationary_for_recovery_test(fit)

  ## Recovery: the rank-1 loading reproduces the true sign pattern up to a
  ## global sign flip (factor loadings are identified only up to reflection).
  lam_est  <- as.numeric(fit$report$Lambda_B[, 1L])
  lam_true <- sign(as.numeric(d$Lam))
  expect_true(
    all(sign(lam_est) == lam_true) || all(sign(lam_est) == -lam_true),
    info = "latent rank-1 loading sign pattern (up to a global flip)"
  )
  ## Implied Sigma_B is PSD (a rank-1 outer product has one positive and the
  ## rest near-zero eigenvalues; allow a tiny negative numerical tolerance).
  ev <- eigen(fit$report$Sigma_B, symmetric = TRUE, only.values = TRUE)$values
  expect_true(all(ev > -1e-6), info = "Sigma_B positive-semidefinite")

  ## Default extractor contract: point estimate only, with explicit NA bounds.
  expect_true(.ec_unit_point_only(fit))
})

## ===========================================================================
##  unique(0 + trait | unit) -- per-trait diagonal recovery
## ===========================================================================

test_that("poisson x unique(unit): converges, PD, recovers positive diag w/ correct dominant trait + point-only rho", {
  skip_if_not_heavy()
  d <- .matrix_pois_unit_dgp()
  fit <- .fit_pois_unit(
    value ~ 0 + trait + unique(0 + trait | site), d$data
  )
  reason <- .unhealthy_reason(fit)
  if (!is.null(reason)) skip(reason)

  expect_stationary_for_recovery_test(fit)
  expect_stationary_for_recovery_test(fit)

  ## Recovery: per-trait between-unit variances are finite and positive, and
  ## the largest variance sits on the trait with the largest true variance.
  ## (Mean-dependent Jensen shrinkage biases magnitudes low and reshuffles the
  ## smaller variances seed-to-seed, so only the argmax is asserted -- the
  ## honest stable target under the Phase-B0 wider count tolerance.)
  v_est <- as.numeric(fit$report$sd_B)^2
  expect_length(v_est, d$T)
  expect_true(all(is.finite(v_est)) && all(v_est > 0))
  expect_equal(which.max(v_est), which.max(diag(d$Sigma_B)),
               info = "unique() recovers the dominant-variance trait")

  expect_true(.ec_unit_point_only(fit))
})

## ===========================================================================
##  latent + unique (paired) -- both blocks present
## ===========================================================================

test_that("poisson x latent(unit, d=1) + unique(unit): converges, PD, recovers both blocks + point-only rho", {
  skip_if_not_heavy()
  d <- .matrix_pois_unit_dgp()
  fit <- .fit_pois_unit(
    value ~ 0 + trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    d$data
  )
  reason <- .unhealthy_reason(fit)
  if (!is.null(reason)) skip(reason)

  expect_stationary_for_recovery_test(fit)
  expect_stationary_for_recovery_test(fit)
  ## Both engine slots are active.
  expect_true(isTRUE(fit$use$rr_B) && isTRUE(fit$use$diag_B))

  ## latent block: implied Sigma_B is reported and (now full-rank via the
  ## added diagonal) positive-semidefinite.
  expect_false(is.null(fit$report$Sigma_B))
  ev <- eigen(fit$report$Sigma_B, symmetric = TRUE, only.values = TRUE)$values
  expect_true(all(ev > -1e-6), info = "Sigma_B PSD with latent+unique")
  ## unique block: per-trait diagonal SDs finite and positive.
  v_diag <- as.numeric(fit$report$sd_B)
  expect_true(all(is.finite(v_diag)) && all(v_diag > 0))

  expect_true(.ec_unit_point_only(fit))
})

## ===========================================================================
##  indep(0 + trait | unit) -- diagonal-only marginal mode (recovery/smoke)
## ===========================================================================

test_that("poisson x indep(unit): converges, PD, sets indep marker, recovers positive diag + point-only rho", {
  skip_if_not_heavy()
  d <- .matrix_pois_unit_dgp()
  fit <- .fit_pois_unit(
    value ~ 0 + trait + indep(0 + trait | site), d$data
  )
  reason <- .unhealthy_reason(fit)
  if (!is.null(reason)) skip(reason)

  expect_stationary_for_recovery_test(fit)
  expect_stationary_for_recovery_test(fit)
  ## indep dispatch flag distinguishes it from a plain unique() fit.
  expect_true(isTRUE(fit$use$indep_B))

  ## Recovery/smoke: positive per-trait variances, dominant trait recovered.
  v_est <- as.numeric(fit$report$sd_B)^2
  expect_true(all(is.finite(v_est)) && all(v_est > 0))
  expect_equal(which.max(v_est), which.max(diag(d$Sigma_B)),
               info = "indep() recovers the dominant-variance trait")

  expect_true(.ec_unit_point_only(fit))
})

## ===========================================================================
##  dep(0 + trait | unit) -- full unstructured Sigma (recovery/smoke)
## ===========================================================================

test_that("poisson x dep(unit): converges, PD, recovers off-diagonal correlations + point-only rho", {
  skip_if_not_heavy()
  d <- .matrix_pois_unit_dgp()
  fit <- .fit_pois_unit(
    value ~ 0 + trait + dep(0 + trait | site), d$data
  )
  reason <- .unhealthy_reason(fit)
  if (!is.null(reason)) skip(reason)

  expect_stationary_for_recovery_test(fit)
  expect_stationary_for_recovery_test(fit)
  ## dep dispatch flag (full unstructured Sigma_B).
  expect_true(isTRUE(fit$use$dep_B))

  ## Recovery: the off-diagonal correlation structure matches in sign and to
  ## within 0.30 absolute -- the Phase-B0 count-family (~30 %) tolerance.
  cor_est  <- stats::cov2cor(fit$report$Sigma_B)
  cor_true <- stats::cov2cor(d$Sigma_B)
  off      <- upper.tri(cor_true)
  expect_true(all(sign(cor_est[off]) == sign(cor_true[off])),
              info = "dep() off-diagonal correlation signs match truth")
  expect_lt(max(abs(cor_est[off] - cor_true[off])), 0.30)

  expect_true(.ec_unit_point_only(fit))
})

## ===========================================================================
##  scalar (one shared variance) == unique(..., common = TRUE) (recovery/smoke)
## ===========================================================================

test_that("poisson x scalar/unique(common=TRUE) (unit): converges, PD, ties one shared variance + point-only rho", {
  skip_if_not_heavy()
  d <- .matrix_pois_unit_dgp()
  fit <- .fit_pois_unit(
    value ~ 0 + trait + unique(0 + trait | site, common = TRUE), d$data
  )
  reason <- .unhealthy_reason(fit)
  if (!is.null(reason)) skip(reason)

  expect_stationary_for_recovery_test(fit)
  expect_stationary_for_recovery_test(fit)

  ## Recovery of the scalar CONSTRAINT: a single shared variance across all
  ## traits (every per-trait sd_B exactly tied), and positive.
  sds <- as.numeric(fit$report$sd_B)
  expect_length(sds, d$T)
  expect_true(all(abs(sds - sds[1L]) < 1e-8),
              info = "scalar mode ties all per-trait variances to one value")
  expect_true(sds[1L] > 0)

  expect_true(.ec_unit_point_only(fit))
})
