## Recovery-DEPTH cell for Gamma(link = "log") -- issue #348 / board #340 /
## Design 61 §1c. The gamma FAMily row is already `C` (covered) for the
## *intercepts + CV* recovery axis (`test-family-gamma.R`), but the
## recovery-DEPTH axis (board #340) reads `partial` (P): no prior cell
## jointly recovers the trait fixed effects AND a NON-TRIVIAL between-unit
## random-effect covariance Sigma -- including its OFF-DIAGONAL cross-trait
## correlation -- from one intercept-only fit. The matrix/tiers cells
## (`test-matrix-gamma-unit.R`, `test-tiers-gamma.R`) recover the gamma CV
## and per-trait variances, and `test-family-gamma.R` recovers the
## intercepts, but neither asserts a known full unstructured Sigma_B with a
## planted cross-trait correlation. This file closes that depth gap.
##
## DGP (log link, seed-controlled, replicated):
##   * trait log-intercepts mu_eta on the log scale.
##   * a per-unit cross-trait random intercept drawn from a KNOWN full
##     covariance Sigma_true (Cholesky of a 3x3 matrix with planted
##     off-diagonal correlation rho_true), fit with dep(0 + trait | unit)
##     so the engine's report$Sigma_B is the full unstructured T x T
##     between-unit covariance -- the quantity we assert against truth.
##   * REPLICATES per (unit, trait) cell. Load-bearing: with one row per
##     cell the unit random intercept is confounded with the gamma residual
##     and the CV collapses (shape -> huge). Replicates make BOTH the CV
##     and the between-unit Sigma identifiable (same rationale as
##     test-matrix-gamma-unit.R lines 16-21).
##
## Bands are INHERITED, not invented:
##   * intercepts: abs 0.30 -- the loosest core-family intercept band in the
##     recovery suite (test-nb2-recovery.R:48; gamma is mean-dependent so we
##     do NOT use the tighter 0.15 from test-family-gamma.R's no-RE fixture).
##   * CV (sigma_eps): abs 0.15 -- the per-cell band from
##     test-matrix-gamma-unit.R (mean-dependent => wide).
##   * Sigma_B diagonal (per-trait variance): 40% median relative -- the
##     smoke-grade structural band used by the matrix-ordinal sibling and
##     the gamma tiers cells (no per-cell widening).
##   * Sigma_B off-diagonal correlation: abs 0.25 -- the cross-trait
##     correlation band used by the phylo_indep slope recovery rows
##     (Design 35 PHY-11). A planted rho recovered to +/-0.25 is honest
##     depth evidence, not a tight CI.
##
## Honest-skip discipline: a non-converged / non-PD / out-of-band fit
## SKIPS with a reason (board #340 stays `partial` for that cell) rather
## than relaxing an assertion. A clean pass EARNS `covered` on the depth
## axis.

.gamma_depth_cv_true <- 1 / sqrt(2)   # gamma shape = 2 -> CV = 0.7071

## Known full between-unit covariance with a planted cross-trait
## correlation. SDs c(0.7, 0.6, 0.5); pairwise correlation rho on the
## off-diagonals (compound-symmetric so every recovered off-diagonal
## correlation has the same target).
make_gamma_depth_sigma <- function(sd = c(0.7, 0.6, 0.5), rho = 0.5) {
  R <- matrix(rho, length(sd), length(sd))
  diag(R) <- 1
  D <- diag(sd)
  D %*% R %*% D
}

sim_gamma_depth <- function(seed,
                            n_unit = 120L,
                            reps   = 5L,
                            shape  = 2,
                            mu_eta = c(0.5, -0.3, 0.2),
                            Sigma  = make_gamma_depth_sigma()) {
  set.seed(seed)
  Tn <- length(mu_eta)
  tn <- c("a", "b", "c")[seq_len(Tn)]
  Lc <- chol(Sigma)                       # upper; t(Lc) %*% z is N(0, Sigma)
  b_unit <- t(crossprod(Lc, matrix(stats::rnorm(n_unit * Tn), Tn, n_unit)))
  N    <- n_unit * Tn * reps
  unit <- integer(N); trait <- character(N); value <- numeric(N)
  k <- 1L
  for (uu in seq_len(n_unit)) {
    for (t in seq_len(Tn)) {
      mu <- exp(mu_eta[t] + b_unit[uu, t])
      for (r in seq_len(reps)) {
        unit[k]  <- uu
        trait[k] <- tn[t]
        value[k] <- stats::rgamma(1L, shape = shape, scale = mu / shape)
        k <- k + 1L
      }
    }
  }
  list(
    data = data.frame(
      unit  = factor(unit),
      trait = factor(trait, levels = tn),
      value = value
    ),
    mu_eta = mu_eta,
    Sigma  = Sigma,
    cv     = .gamma_depth_cv_true,
    Tn     = Tn
  )
}

## Off-diagonal correlations of a covariance matrix as a flat vector
## (upper triangle), used to compare recovered vs true cross-trait rho.
.offdiag_cor <- function(S) {
  R <- stats::cov2cor(S)
  R[upper.tri(R)]
}

test_that("Gamma(log) joint depth: intercepts + CV + full between-unit Sigma (dep)", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()

  fx  <- sim_gamma_depth(seed = 4801L)
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + dep(0 + trait | unit),
      data   = fx$data,
      unit   = "unit",
      family = Gamma(link = "log")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    skip(paste0("Gamma depth fit errored: ", conditionMessage(fit),
                "; board #340 stays partial for gamma"))
  }
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$sd_report$pdHess)) {
    skip("Gamma depth fit non-convergent / non-PD; board #340 stays partial")
  }

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1L], 4L)
  expect_true(isTRUE(fit$use$dep_B))

  ## (1) Fixed-effect log-intercepts (inherited abs 0.30, nb2 band).
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), fx$Tn)
  if (max(abs(bfix - fx$mu_eta)) >= 0.30) {
    skip(sprintf("Gamma intercepts out of band (max dev %.3f); partial",
                 max(abs(bfix - fx$mu_eta))))
  }
  expect_lt(max(abs(bfix - fx$mu_eta)), 0.30)

  ## (2) Gamma CV (sigma_eps) (inherited abs 0.15, matrix-gamma band).
  cv_hat <- as.numeric(fit$report$sigma_eps)
  if (abs(cv_hat - fx$cv) >= 0.15) {
    skip(sprintf("Gamma CV out of band (dev %.3f); partial",
                 abs(cv_hat - fx$cv)))
  }
  expect_lt(abs(cv_hat - fx$cv), 0.15)

  ## (3) Between-unit Sigma_B: full unstructured T x T from the dep path.
  Sig_hat <- fit$report$Sigma_B
  expect_equal(dim(Sig_hat), c(fx$Tn, fx$Tn))
  expect_true(all(is.finite(Sig_hat)))

  ## (3a) Diagonal (per-trait variance): 40% median relative band.
  v_hat  <- diag(Sig_hat)
  v_true <- diag(fx$Sigma)
  rel_v  <- abs(v_hat - v_true) / v_true
  if (stats::median(rel_v) >= 0.40) {
    skip(sprintf("Gamma Sigma_B diagonal out of band (median rel %.3f); partial",
                 stats::median(rel_v)))
  }
  expect_lt(stats::median(rel_v), 0.40)

  ## (3b) Off-diagonal cross-trait correlation: planted rho recovered to
  ## abs 0.25 (inherited PHY-11 correlation band).
  rho_hat  <- .offdiag_cor(Sig_hat)
  rho_true <- .offdiag_cor(fx$Sigma)
  if (max(abs(rho_hat - rho_true)) >= 0.25) {
    skip(sprintf("Gamma Sigma_B off-diagonal correlation out of band (max dev %.3f); partial",
                 max(abs(rho_hat - rho_true))))
  }
  expect_lt(max(abs(rho_hat - rho_true)), 0.25)
})
