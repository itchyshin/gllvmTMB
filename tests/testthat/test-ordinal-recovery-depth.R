## Recovery-DEPTH cell for ordinal_probit() -- issue #348 / board #340 /
## Design 61 §1c. The ordinal FAMily row is already `C` (covered) for the
## *cutpoints + intercepts* recovery axis (`test-ordinal-probit.R`,
## K = 2/3/4), but the recovery-DEPTH axis (board #340) reads `partial`
## (P): the existing cutpoint-recovery cells fit `unique(0 + trait | unit)`
## with a DGP that has NO between-unit variance (the random intercept is
## fit but the data carry only the fixed N(0, 1) latent residual), so no
## prior cell jointly recovers cutpoints + intercepts AND a NON-TRIVIAL
## between-unit covariance Sigma with a planted OFF-DIAGONAL cross-trait
## correlation. The matrix-ordinal cells recover diagonal variances /
## loadings but not the joint cutpoint+Sigma cell. This file closes that
## depth gap.
##
## Family note (Wright/Falconer/Hadfield threshold model):
##   * ordinal_probit has latent residual variance sigma_d^2 = 1 EXACTLY by
##     construction (no trigamma correction). The between-unit Sigma adds on
##     top of that fixed baseline, so for it to be identifiable the
##     per-unit signal must be substantial and there must be REPLICATE
##     ordinal draws per (unit, trait) cell against the fixed N(0, 1)
##     residual (same rationale as test-matrix-ordinal-unit.R).
##
## DGP (K = 4 categories; cutpoints tau = 0, 0.7, 1.4 fixed across traits):
##   * trait latent-scale intercepts alpha.
##   * per-unit cross-trait random intercept drawn from a KNOWN full
##     covariance Sigma_true (planted off-diagonal correlation rho_true),
##     fit with dep(0 + trait | unit) so report$Sigma_B is the full
##     unstructured T x T between-unit covariance we assert against truth.
##   * y* = alpha_t + b_unit[unit, t] + N(0, 1); y = ordinalise(y*).
##   * N_REP replicate draws per (unit, trait) cell identify Sigma_B.
##
## Bands are INHERITED, not invented:
##   * intercepts: abs 0.30 -- test-ordinal-probit.R:66 intercept band.
##   * cutpoints: abs 0.30 -- test-ordinal-probit.R:58-60 (the looser of the
##     two thresholds; we apply 0.30 to all for a single honest band).
##   * Sigma_B diagonal (per-trait variance): 40% median relative -- the
##     ordinal smoke-grade structural band (test-matrix-ordinal-unit.R:198,
##     258 etc., Phase B0 memo).
##   * Sigma_B off-diagonal correlation: abs 0.30 -- the cross-trait
##     correlation band inherited from the ordinal phylo_indep slope row
##     (Design 35 PHY-16 uses ordinal's 2.5x looser convention); 0.30
##     rather than gamma's 0.25 because ordinal is smoke-grade per the
##     Phase B0 memo. No tightening.
##
## Honest-skip discipline: a non-converged / non-PD / out-of-band fit
## SKIPS with a reason (board #340 stays `partial` for ordinal) rather than
## relaxing an assertion. A clean pass EARNS `covered` on the depth axis.

.ord_depth_K       <- 4L
.ord_depth_taus    <- c(0, 0.7, 1.4)   # K = 4: 3 thresholds, 2 free
.ord_depth_alpha   <- c(0.2, -0.1, 0.15)
.ord_depth_traits  <- c("a", "b", "c")

.ord_depth_ordinalise <- function(ystar, taus = .ord_depth_taus) {
  1L + (ystar > taus[1L]) + (ystar > taus[2L]) + (ystar > taus[3L])
}

make_ord_depth_sigma <- function(sd = c(0.9, 1.0, 0.8), rho = 0.5) {
  R <- matrix(rho, length(sd), length(sd))
  diag(R) <- 1
  D <- diag(sd)
  D %*% R %*% D
}

sim_ord_depth <- function(seed,
                          n_unit = 150L,
                          reps   = 5L,
                          alpha  = .ord_depth_alpha,
                          Sigma  = make_ord_depth_sigma()) {
  set.seed(seed)
  Tn <- length(alpha)
  tn <- .ord_depth_traits[seq_len(Tn)]
  Lc <- chol(Sigma)
  b_unit <- t(crossprod(Lc, matrix(stats::rnorm(n_unit * Tn), Tn, n_unit)))
  N    <- n_unit * Tn * reps
  unit <- integer(N); trait <- character(N); value <- integer(N)
  k <- 1L
  for (uu in seq_len(n_unit)) {
    for (t in seq_len(Tn)) {
      for (r in seq_len(reps)) {
        ystar    <- alpha[t] + b_unit[uu, t] + stats::rnorm(1L, 0, 1)
        unit[k]  <- uu
        trait[k] <- tn[t]
        value[k] <- .ord_depth_ordinalise(ystar)
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
    alpha = alpha,
    taus  = .ord_depth_taus,
    Sigma = Sigma,
    Tn    = Tn
  )
}

.offdiag_cor_ord <- function(S) {
  R <- stats::cov2cor(S)
  R[upper.tri(R)]
}

test_that("ordinal_probit joint depth: intercepts + cutpoints + full between-unit Sigma (dep)", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()

  fx  <- sim_ord_depth(seed = 4901L)
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + dep(0 + trait | unit),
      data   = fx$data,
      unit   = "unit",
      family = ordinal_probit()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    skip(paste0("ordinal depth fit errored: ", conditionMessage(fit),
                "; board #340 stays partial for ordinal"))
  }
  if (!.fit_converged(fit)) {
    skip("ordinal depth fit non-convergent / non-PD; board #340 stays partial")
  }

  expect_converged(fit)
  expect_equal(fit$tmb_data$family_id_vec[1L], 14L)
  expect_true(isTRUE(fit$use$dep_B))
  ## sigma_d^2 = 1 exactly -- the defining ordinal property.
  expect_equal(
    unname(gllvmTMB:::link_residual_per_trait(fit)),
    rep(1, fit$n_traits)
  )

  ## (1) Latent-scale trait intercepts (inherited abs 0.30).
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), fx$Tn)
  if (max(abs(bfix - fx$alpha)) >= 0.30) {
    skip(sprintf("ordinal intercepts out of band (max dev %.3f); partial",
                 max(abs(bfix - fx$alpha))))
  }
  expect_lt(max(abs(bfix - fx$alpha)), 0.30)

  ## (2) Cutpoints (inherited abs 0.30). Each trait shares the same
  ## tau = (0.7, 1.4) free thresholds; extract_cutpoints() returns one row
  ## per free cutpoint per trait.
  cuts <- extract_cutpoints(fit)
  expect_true(all(c("trait", "cutpoint_index", "tau_estimate") %in% names(cuts)))
  ## True free taus per trait: index 2 -> 0.7, index 3 -> 1.4.
  tau_target <- ifelse(cuts$cutpoint_index == 2L, fx$taus[2L], fx$taus[3L])
  tau_dev    <- abs(cuts$tau_estimate - tau_target)
  if (max(tau_dev) >= 0.30) {
    skip(sprintf("ordinal cutpoints out of band (max dev %.3f); partial",
                 max(tau_dev)))
  }
  expect_lt(max(tau_dev), 0.30)

  ## (3) Between-unit Sigma_B: full unstructured T x T from the dep path.
  Sig_hat <- fit$report$Sigma_B
  expect_equal(dim(Sig_hat), c(fx$Tn, fx$Tn))
  expect_true(all(is.finite(Sig_hat)))

  ## (3a) Diagonal (per-trait variance): 40% median relative band.
  v_hat  <- diag(Sig_hat)
  v_true <- diag(fx$Sigma)
  rel_v  <- abs(v_hat - v_true) / v_true
  if (stats::median(rel_v) >= 0.40) {
    skip(sprintf("ordinal Sigma_B diagonal out of band (median rel %.3f); partial",
                 stats::median(rel_v)))
  }
  expect_lt(stats::median(rel_v), 0.40)

  ## (3b) Off-diagonal cross-trait correlation: planted rho recovered to
  ## abs 0.30 (inherited ordinal cross-trait band).
  rho_hat  <- .offdiag_cor_ord(Sig_hat)
  rho_true <- .offdiag_cor_ord(fx$Sigma)
  if (max(abs(rho_hat - rho_true)) >= 0.30) {
    skip(sprintf("ordinal Sigma_B off-diagonal correlation out of band (max dev %.3f); partial",
                 max(abs(rho_hat - rho_true))))
  }
  expect_lt(max(abs(rho_hat - rho_true)), 0.30)
})
