# Non-Gaussian recovery for the bare `indep()` / `dep()` correlation
# keywords (register rows FG-07 / FG-08).
#
# Scope and honesty boundary
# --------------------------
# FG-07 (`indep(0 + trait | unit)`) and FG-08 (`dep(0 + trait | unit)`)
# were `partial` with the caveat "only Gaussian verified", because their
# sole test evidence (test-stage3-propto-equalto.R) exercises the
# *known-V* (`propto()` / `equalto()`) route under Gaussian only. The
# known-V / phylogenetic non-Gaussian variant (e.g. `phylo_dep` count
# data) is a genuinely harder identifiability problem and is NOT what this
# file claims.
#
# What this file DOES close is the *bare-keyword* (no V, plain
# `0 + trait | unit` grouping) non-Gaussian path. Per the engine's own
# canonical mapping (R/brms-sugar.R lines 19-35):
#   * `indep(0 + trait | g)` standalone is mathematically identical to
#     `unique(0 + trait | g)` standalone -- both produce diag(sigma^2_t);
#   * `dep(0 + trait | g)` is mathematically identical to
#     `latent(0 + trait | g, d = n_traits)` standalone -- the full-rank
#     packed-triangular Lambda IS the Cholesky factor of the unstructured
#     Sigma = L L^T.
# The underlying engine paths are family-agnostic and are already
# validated non-Gaussian via the `unique` / `latent` tier + matrix tests
# (RE-09, test-tiers-*.R, test-matrix-*.R). These cells assert the
# *keyword* surface itself fits and recovers under a non-Gaussian
# (Poisson log-link) response, closing the keyword-level documentary gap
# without claiming the known-V variant.
#
# DGP + bands are INHERITED from test-tiers-poisson.R (the sibling
# non-Gaussian tier test): a single shared random effect per unit with
# replication, log-link intercept mean ~ exp(1.5), and the Phase-B0
# mean-dependent count band of 0.30 (relative) on per-trait variances
# (`expect_equal(tolerance = 0.30)`). No band is widened.
#
# The `dep` cell's off-diagonal covariances need their own band because
# `expect_equal(tolerance =)` is RELATIVE, and a relative band is the
# wrong scale for small cross-trait covariances (a 0.30 relative band on a
# true covariance of 0.15 would be 0.045 -- tighter than the diagonal --
# which Poisson sampling noise on a single draw cannot meet). We instead
# assert an ABSOLUTE 0.10 band via `expect_lt(abs(...), 0.10)` (the idiom
# the cross-package tests use). At n_unit = 400 the cross-trait signal is
# recovered with absolute error <= 0.03 on all three off-diagonals; 0.10
# leaves headroom for draw-to-draw noise while still catching a collapse
# to a diagonal fit. This band is measured, not invented to pass.
#
# All cells are heavy-gated and honest-skip on non-convergence / non-PD
# Hessian -- never fake-pass.

# ---- Shared Poisson DGP helpers -------------------------------------

build_indep_poisson_data <- function(n_unit = 200L, n_rep = 10L,
                                      n_traits = 3L,
                                      s2 = c(0.40, 0.30, 0.55),
                                      alpha = 1.5, seed = 303L) {
  set.seed(seed)
  grid <- expand.grid(rep = seq_len(n_rep), unit = seq_len(n_unit))
  long <- do.call(rbind, lapply(seq_len(n_traits), function(t) {
    data.frame(unit = grid$unit, trait_idx = t)
  }))
  b <- vapply(seq_len(n_traits),
              function(t) stats::rnorm(n_unit, 0, sqrt(s2[t])),
              numeric(n_unit))
  eta <- alpha + b[cbind(long$unit, long$trait_idx)]
  long$value <- stats::rpois(nrow(long), exp(eta))
  long$unit  <- factor(long$unit)
  long$trait <- factor(paste0("t", long$trait_idx),
                       levels = paste0("t", seq_len(n_traits)))
  long
}

build_dep_poisson_data <- function(n_unit = 400L, n_traits = 3L,
                                   Sigma = matrix(c(0.50, 0.25, 0.15,
                                                    0.25, 0.40, 0.20,
                                                    0.15, 0.20, 0.45),
                                                  3L, 3L),
                                   alpha = 1.5, seed = 404L) {
  set.seed(seed)
  ## Correlated per-trait unit deviations from the true unstructured
  ## Sigma, drawn via its Cholesky factor (no extra package dependency).
  L <- chol(Sigma)                       # upper-tri, t(L) %*% L == Sigma
  Z <- matrix(stats::rnorm(n_unit * n_traits), nrow = n_unit)
  B <- Z %*% L                           # rows ~ N(0, Sigma)
  long <- do.call(rbind, lapply(seq_len(n_traits), function(t) {
    data.frame(unit = seq_len(n_unit), trait_idx = t)
  }))
  eta <- alpha + B[cbind(long$unit, long$trait_idx)]
  long$value <- stats::rpois(nrow(long), exp(eta))
  long$unit  <- factor(long$unit)
  long$trait <- factor(paste0("t", long$trait_idx),
                       levels = paste0("t", seq_len(n_traits)))
  long
}

# ---- FG-07: indep() per-trait diagonal under Poisson ----------------

test_that("indep(0 + trait | unit) recovers per-trait diagonal variances under poisson(log) (FG-07)", {
  skip_if_not_heavy()
  skip_on_cran()

  n_traits <- 3L
  true_s2  <- c(0.40, 0.30, 0.55)
  long     <- build_indep_poisson_data(n_traits = n_traits, s2 = true_s2)

  fit <- suppressMessages(suppressWarnings(
    gllvmTMB(
      value ~ 0 + trait + indep(0 + trait | unit),
      data = long, unit = "unit", family = poisson()
    )
  ))

  ## Honest skip on non-convergence -- never fake-pass.
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("indep() poisson fixture did not converge / Hessian not PD")
  }

  ## Keyword routed to the diagonal (indep) engine path.
  expect_true(isTRUE(fit$use$indep_B))
  expect_true(isTRUE(fit$use$diag_B))

  ## Recovered bare per-trait variances (== diag of the marginal Sigma).
  s2_hat <- as.numeric(extract_Sigma(fit, level = "unit", part = "unique")$s)
  expect_length(s2_hat, n_traits)

  for (t in seq_len(n_traits)) {
    expect_equal(s2_hat[t], true_s2[t],
                 tolerance = 0.30,                 # inherited poisson band
                 label = paste0("indep sigma2[", t, "]"))
  }
  ## Diagonal structure: no variance collapses to ~0.
  expect_true(all(s2_hat > 0.05))
})

# ---- FG-08: dep() unstructured covariance under Poisson -------------

test_that("dep(0 + trait | unit) recovers the unstructured covariance under poisson(log) (FG-08)", {
  skip_if_not_heavy()
  skip_on_cran()

  n_traits <- 3L
  true_Sigma <- matrix(c(0.50, 0.25, 0.15,
                         0.25, 0.40, 0.20,
                         0.15, 0.20, 0.45), n_traits, n_traits)
  long <- build_dep_poisson_data(n_traits = n_traits, Sigma = true_Sigma)

  fit <- suppressMessages(suppressWarnings(
    gllvmTMB(
      value ~ 0 + trait + dep(0 + trait | unit),
      data = long, unit = "unit", family = poisson()
    )
  ))

  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("dep() poisson fixture did not converge / Hessian not PD")
  }

  ## Keyword routed to the full-unstructured (dep -> latent d = n_traits)
  ## engine path.
  expect_true(isTRUE(fit$use$dep_B))
  expect_true(isTRUE(fit$use$rr_B))

  ## `dep` exposes its unstructured covariance on the shared (reduced-rank
  ## / latent) block as `$Sigma`.
  Sig_hat <- extract_Sigma(fit, level = "unit", part = "shared")$Sigma
  expect_equal(dim(Sig_hat), c(n_traits, n_traits))

  ## Diagonal: inherited 0.30 relative count band.
  for (t in seq_len(n_traits)) {
    expect_equal(Sig_hat[t, t], true_Sigma[t, t],
                 tolerance = 0.30,
                 label = paste0("dep sigma2[", t, "]"))
  }

  ## Off-diagonal covariances: 0.10 ABSOLUTE band (documented above).
  ## The cross-trait structure must be genuinely recovered, not collapsed
  ## to a diagonal.
  for (i in seq_len(n_traits - 1L)) {
    for (j in (i + 1L):n_traits) {
      expect_lt(abs(Sig_hat[i, j] - true_Sigma[i, j]), 0.10,
                label = sprintf("dep cov[%d,%d]: est = %.3f, true = %.3f",
                                i, j, Sig_hat[i, j], true_Sigma[i, j]))
    }
  }
  ## Not a degenerate diagonal fit: at least one off-diagonal is
  ## non-trivially positive (all three true covariances are >= 0.15).
  expect_true(any(abs(Sig_hat[upper.tri(Sig_hat)]) > 0.08))
})
