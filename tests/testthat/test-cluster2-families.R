## Slice F (#356): per-family recovery sweep for the cluster2 tier.
##
## cluster2 is a SECOND independent diagonal grouping slot, a byte-for-byte
## structural copy of the third-slot `cluster` (sd_q) tier renamed to its own
## engine block (`diag_cluster2` / `r_c2`, reported as `sd_c2`); the
## equivalence-gate test in test-cluster2-rename.R proves the two slots are
## identical on a Gaussian DGP. Because the tier lives entirely in the
## structural-block prior (the family enters only at the response-likelihood
## node after eta accumulates the random-effect contributions; see
## docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md S1), the
## slot is family-agnostic. This file confirms that empirically: for each
## wired response family, a known per-trait cluster2 diagonal variance is
## simulated, fit with `cluster2 = "c2"`, and recovered via
## extract_Sigma(level = "cluster2", part = "unique")$s (== sd_c2^2).
##
## Fit shape (mirrors test-cluster2-rename.R's CROSSED RECOVERY test): the
## ONLY diag term is unique(0 + trait | c2); `unit` / `unit_obs` are pointed
## at disjoint throwaway per-row id columns that carry NO diag term, so the
## cluster2 term cannot collide with the unit / unit_obs slot. The cluster2
## random effect is shared across many rows per (c2, trait) cell, so -- like
## the sibling `cluster`-tier tests in test-tiers-*.R -- it sits one level
## ABOVE any per-row residual / OLRE / overdispersion and is cleanly
## identifiable. There is therefore no cluster2 analogue of the
## ordinal/nbinom2 OLRE non-recovery cells (those are per-row-tier effects).
##
## Bands are inherited from each family's sibling `cluster`-tier test (the
## closest structural analogue), NOT invented here:
##   * gaussian : SD-scale tolerance 0.15 (continuous, well-replicated).
##   * poisson  : variance relative band 0.35 (test-tiers-poisson.R cluster).
##   * nbinom2  : variance in [0.25, 0.95] for truths {0.5,0.4,0.6}; phi in
##                [1, 4] (test-tiers-nbinom2.R cluster).
##   * beta     : variance relative band 0.30; phi in [phi/3, 3phi]
##                (test-tiers-beta.R cluster).
##   * Gamma    : SD-scale tolerance 0.2; CV tolerance 0.1
##                (test-tiers-gamma.R cluster).
##   * ordinal  : SD-scale absolute band 0.35 (test-tiers-ordinal.R cluster).
##   * binomial : no sibling tier file; binary is noisy, so a variance band
##                of 0.40 (relative) on a heavily-replicated cell, mirroring
##                the loose-but-meaningful binary convention of
##                test-m2-2a-binary-recovery.R.
##
## Every cell is SKIP-honest: a fit that fails to converge or whose joint
## Hessian is not PD is skip()'d with an explicit note rather than asserted.

## ------------------------------------------------------------------
## Shared crossed (unit x cluster2) fixture builder. One row per
## (unit, c2, trait[, rep]); `obs` / `obs2` are throwaway per-row ids for
## the unit / unit_obs slots so neither carries a diag term.
## ------------------------------------------------------------------
.make_c2 <- function(n_c2, n_unit, n_traits, n_rep = 1L) {
  traits <- letters[seq_len(n_traits)]
  grid <- expand.grid(
    rep       = seq_len(n_rep),
    unit      = seq_len(n_unit),
    c2        = seq_len(n_c2),
    trait_idx = seq_len(n_traits)
  )
  grid$trait <- factor(traits[grid$trait_idx], levels = traits)
  grid
}

## Common post-processing: factor columns + throwaway per-row unit ids, fit
## the cluster2-only model, and return the fit (or NULL DGP scaffolding).
.fit_c2 <- function(grid, family) {
  grid$c2   <- factor(grid$c2)
  grid$obs  <- factor(seq_len(nrow(grid)))
  grid$obs2 <- factor(seq_len(nrow(grid)))
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | c2),
    data     = grid,
    family   = family,
    unit     = "obs",
    unit_obs = "obs2",
    cluster2 = "c2"
  )))
}

## ---- gaussian -------------------------------------------------------------

test_that("cluster2 x gaussian: cluster2 variance recovers (SD scale)", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(2024L)
  n_traits  <- 3L
  n_c2      <- 25L
  n_unit    <- 40L
  true_sd   <- c(0.50, 0.70, 0.60)   # per-trait cluster2 SD
  alpha     <- 1.0
  sd_resid  <- 0.4

  grid <- .make_c2(n_c2, n_unit, n_traits)
  re   <- vapply(seq_len(n_traits),
                 function(t) stats::rnorm(n_c2, 0, true_sd[t]), numeric(n_c2))
  eta  <- alpha + re[cbind(grid$c2, grid$trait_idx)]
  grid$value <- eta + stats::rnorm(nrow(grid), 0, sd_resid)

  fit <- .fit_c2(grid, gaussian())

  if (!.fit_converged(fit)) {
    skip("gaussian cluster2 fixture did not converge / Hessian not PD")
  }
  expect_equal(fit$tmb_data$family_id_vec[1], 0L)
  expect_true(isTRUE(fit$use$diag_cluster2))
  expect_equal(fit$cluster2_col, "c2")

  sd_c2 <- as.numeric(fit$report$sd_c2)
  expect_true(all(is.finite(sd_c2)))
  s <- as.numeric(extract_Sigma(fit, level = "cluster2", part = "unique")$s)
  expect_length(s, n_traits)
  expect_equal(unname(s), sd_c2^2, tolerance = 1e-6)

  for (t in seq_len(n_traits)) {
    expect_equal(sd_c2[t], true_sd[t], tolerance = 0.15,
                 label = paste0("sd_c2[", t, "] (gaussian)"))
  }
})

## ---- poisson --------------------------------------------------------------

test_that("cluster2 x poisson: cluster2 variance recovers (count band)", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(33L)
  n_traits  <- 3L
  n_c2      <- 100L     # many cluster2 levels -> variance estimable
  n_unit    <- 6L
  true_s2   <- c(0.45, 0.30, 0.60)   # per-trait cluster2 variance
  alpha     <- 2.0                    # log-link mean ~ exp(2)

  grid <- .make_c2(n_c2, n_unit, n_traits)
  re   <- vapply(seq_len(n_traits),
                 function(t) stats::rnorm(n_c2, 0, sqrt(true_s2[t])),
                 numeric(n_c2))
  eta  <- alpha + re[cbind(grid$c2, grid$trait_idx)]
  grid$value <- stats::rpois(nrow(grid), exp(eta))

  fit <- .fit_c2(grid, poisson())

  if (!.fit_converged(fit)) {
    skip("poisson cluster2 fixture did not converge / Hessian not PD")
  }
  expect_equal(fit$tmb_data$family_id_vec[1], 2L)
  expect_true(isTRUE(fit$use$diag_cluster2))

  sd_c2 <- as.numeric(fit$report$sd_c2)
  expect_true(all(is.finite(sd_c2)))
  s2_hat <- as.numeric(extract_Sigma(fit, level = "cluster2", part = "unique")$s)
  expect_length(s2_hat, n_traits)
  expect_equal(unname(s2_hat), sd_c2^2, tolerance = 1e-6)

  ## Mean-dependent count band (matches test-tiers-poisson.R cluster tier).
  for (t in seq_len(n_traits)) {
    expect_equal(s2_hat[t], true_s2[t], tolerance = 0.35,
                 label = paste0("sigma2_cluster2[", t, "] (poisson)"))
  }
})

## ---- binomial -------------------------------------------------------------

test_that("cluster2 x binomial: cluster2 variance recovers (binary band)", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(515L)
  n_traits  <- 3L
  n_c2      <- 30L
  n_unit    <- 40L      # many binary rows per (c2, trait) cell -> identified
  true_s2   <- c(0.36, 0.49, 0.30)   # per-trait cluster2 variance
  alpha     <- 0.0                    # logit intercept -> p ~ 0.5

  grid <- .make_c2(n_c2, n_unit, n_traits)
  re   <- vapply(seq_len(n_traits),
                 function(t) stats::rnorm(n_c2, 0, sqrt(true_s2[t])),
                 numeric(n_c2))
  eta  <- alpha + re[cbind(grid$c2, grid$trait_idx)]
  grid$value <- stats::rbinom(nrow(grid), 1L, stats::plogis(eta))

  fit <- .fit_c2(grid, binomial())

  if (!.fit_converged(fit)) {
    skip("binomial cluster2 fixture did not converge / Hessian not PD")
  }
  expect_equal(fit$tmb_data$family_id_vec[1], 1L)
  expect_true(isTRUE(fit$use$diag_cluster2))

  sd_c2 <- as.numeric(fit$report$sd_c2)
  expect_true(all(is.finite(sd_c2)))
  s2_hat <- as.numeric(extract_Sigma(fit, level = "cluster2", part = "unique")$s)
  expect_length(s2_hat, n_traits)
  expect_equal(unname(s2_hat), sd_c2^2, tolerance = 1e-6)

  ## Loose-but-meaningful binary band (binary fits are noisy; cf.
  ## test-m2-2a-binary-recovery.R). cluster2 RE is shared across n_unit rows
  ## per cell, so the variance is identified despite single-trial responses.
  for (t in seq_len(n_traits)) {
    expect_lte(abs(s2_hat[t] - true_s2[t]) / true_s2[t], 0.40,
               label = paste0("sigma2_cluster2[", t, "] (binomial)"))
  }
})

## ---- nbinom2 --------------------------------------------------------------

test_that("cluster2 x nbinom2: cluster2 variance recovers, phi finite", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(22L)
  n_traits  <- 3L
  n_c2      <- 30L      # cluster2 levels
  n_unit    <- 6L       # units per c2 (replication within cell)
  n_rep     <- 4L
  true_s2   <- c(0.50, 0.40, 0.60)   # per-trait cluster2 variance
  alpha     <- log(2)
  phi_true  <- 2.0

  grid <- .make_c2(n_c2, n_unit, n_traits, n_rep = n_rep)
  re   <- vapply(seq_len(n_traits),
                 function(t) stats::rnorm(n_c2, 0, sqrt(true_s2[t])),
                 numeric(n_c2))
  eta  <- alpha + re[cbind(grid$c2, grid$trait_idx)]
  grid$value <- stats::rnbinom(nrow(grid), mu = exp(eta), size = phi_true)

  fit <- .fit_c2(grid, nbinom2())

  if (!.fit_converged(fit)) {
    skip("nbinom2 cluster2 fixture did not converge / Hessian not PD")
  }
  expect_equal(fit$tmb_data$family_id_vec[1], 5L)
  expect_true(isTRUE(fit$use$diag_cluster2))

  ## phi finite + near truth (no OLRE competition: cluster2 RE is shared
  ## within a level, orthogonal to per-row overdispersion).
  phi_hat <- as.numeric(fit$report$phi_nbinom2)
  expect_length(phi_hat, n_traits)
  expect_true(all(is.finite(phi_hat)))
  expect_true(all(phi_hat > 1.0))
  expect_true(all(phi_hat < 4.0))

  sd_c2 <- as.numeric(fit$report$sd_c2)
  expect_true(all(is.finite(sd_c2)))
  v_hat <- as.numeric(extract_Sigma(fit, level = "cluster2", part = "unique")$s)
  expect_length(v_hat, n_traits)
  expect_equal(unname(v_hat), sd_c2^2, tolerance = 1e-6)

  ## Each per-trait variance lands in a band around its truth (matches
  ## test-tiers-nbinom2.R cluster tier band for truths {0.5,0.4,0.6}).
  for (t in seq_len(n_traits)) {
    expect_gt(v_hat[t], 0.25)
    expect_lt(v_hat[t], 0.95)
  }
})

## ---- beta -----------------------------------------------------------------

test_that("cluster2 x beta: cluster2 variance recovers, phi separates", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(2025L)
  n_traits  <- 3L
  n_c2      <- 40L
  n_unit    <- 6L
  n_rep     <- 4L       # within-cell reps identify cluster2 var vs phi
  b_true    <- c(-0.4, 0.0, 0.4)     # logit-scale trait intercepts
  true_sd   <- c(0.70, 0.50, 0.90)   # per-trait cluster2 SD
  phi_true  <- 5.0

  grid <- .make_c2(n_c2, n_unit, n_traits, n_rep = n_rep)
  re   <- vapply(seq_len(n_traits),
                 function(t) stats::rnorm(n_c2, 0, true_sd[t]), numeric(n_c2))
  eta  <- b_true[grid$trait_idx] + re[cbind(grid$c2, grid$trait_idx)]
  mu   <- stats::plogis(eta)
  grid$value <- stats::rbeta(nrow(grid), mu * phi_true, (1 - mu) * phi_true)
  expect_true(all(grid$value > 0 & grid$value < 1))

  fit <- .fit_c2(grid, Beta())

  if (!.fit_converged(fit)) {
    skip("beta cluster2 fixture did not converge / Hessian not PD")
  }
  expect_equal(fit$tmb_data$family_id_vec[1], 7L)
  expect_true(isTRUE(fit$use$diag_cluster2))

  sd_c2 <- as.numeric(fit$report$sd_c2)
  expect_true(all(is.finite(sd_c2)))
  s <- as.numeric(extract_Sigma(fit, level = "cluster2", part = "unique")$s)
  expect_length(s, n_traits)
  expect_equal(unname(s), sd_c2^2, tolerance = 1e-6)

  ## Variance relative band 0.30 (matches test-tiers-beta.R cluster tier).
  for (t in seq_len(n_traits)) {
    expect_lte(abs(s[t] - true_sd[t]^2) / true_sd[t]^2, 0.30,
               label = paste0("cluster2 sigma2[", t, "] (beta)"))
  }
  expect_true(all(s > 0.05))

  ## phi separates (not absorbed by the cluster2 tier).
  phi_hat <- as.numeric(fit$report$phi_beta)
  expect_length(phi_hat, n_traits)
  expect_true(all(phi_hat > phi_true / 3 & phi_hat < 3 * phi_true))
})

## ---- Gamma ----------------------------------------------------------------

test_that("cluster2 x Gamma: cluster2 variance recovers (SD scale), CV ok", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(202L)
  n_traits  <- 3L
  n_c2      <- 80L
  n_unit    <- 4L
  n_rep     <- 4L       # within-cell reps identify the gamma CV
  true_sd   <- c(0.50, 0.70, 0.40)   # per-trait cluster2 SD
  phi       <- 2                      # gamma shape -> CV = 1/sqrt(phi)
  cv_true   <- 1 / sqrt(phi)

  grid <- .make_c2(n_c2, n_unit, n_traits, n_rep = n_rep)
  re   <- vapply(seq_len(n_traits),
                 function(t) stats::rnorm(n_c2, 0, true_sd[t]), numeric(n_c2))
  eta  <- re[cbind(grid$c2, grid$trait_idx)]   # log-scale intercept 0
  grid$value <- stats::rgamma(nrow(grid), shape = phi, scale = exp(eta) / phi)

  fit <- .fit_c2(grid, Gamma(link = "log"))

  if (!.fit_converged(fit)) {
    skip("Gamma cluster2 fixture did not converge / Hessian not PD")
  }
  expect_equal(fit$tmb_data$family_id_vec[1], 4L)
  expect_true(isTRUE(fit$use$diag_cluster2))

  sd_c2 <- as.numeric(fit$report$sd_c2)
  expect_length(sd_c2, n_traits)
  expect_true(all(is.finite(sd_c2)))
  s <- as.numeric(extract_Sigma(fit, level = "cluster2", part = "unique")$s)
  expect_equal(unname(s), sd_c2^2, tolerance = 1e-6)

  ## SD-scale tolerance 0.2 (matches test-tiers-gamma.R cluster tier).
  for (t in seq_len(n_traits)) {
    expect_equal(sd_c2[t], true_sd[t], tolerance = 0.2,
                 label = paste0("sd_c2[", t, "] (Gamma)"))
  }

  ## gamma CV recovered from per-trait phi_gamma, identified by within-cell reps.
  cv_hat <- 1 / sqrt(as.numeric(fit$report$phi_gamma))
  expect_equal(cv_hat, rep(cv_true, n_traits), tolerance = 0.1,
               label = "gamma CV stored in per-trait phi_gamma")
})

## ---- ordinal_probit -------------------------------------------------------

test_that("cluster2 x ordinal_probit: cluster2 variance recovers (SD scale)", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(404L)
  n_traits  <- 3L
  n_c2      <- 30L      # cluster2 levels (above the fixed sigma2_d = 1 floor)
  n_ind     <- 10L      # individuals (unit rows) per cluster2 level
  true_sd   <- c(1.00, 0.80, 1.20)   # per-trait cluster2 SD
  true_taus <- c(0, 0.6, 1.3)         # K = 4 cutpoints
  true_int  <- 0.1

  ## Strictly nested: cluster2 (population) > individual (per-row). The
  ## cluster2 grouping spans many rows per level, so its variance sits ABOVE
  ## the fixed sigma2_d = 1 liability and is identifiable (unlike a per-row
  ## OLRE under ordinal_probit, which is the structurally degenerate case --
  ## NOT exercised by the cluster2 slot).
  c2_of_ind <- rep(seq_len(n_c2), each = n_ind)
  grid <- expand.grid(trait_idx = seq_len(n_traits),
                      ind = seq_len(n_c2 * n_ind))
  grid$c2    <- c2_of_ind[grid$ind]
  grid$trait <- factor(letters[grid$trait_idx], levels = letters[seq_len(n_traits)])

  re    <- vapply(seq_len(n_traits),
                  function(t) stats::rnorm(n_c2, 0, true_sd[t]), numeric(n_c2))
  ystar <- true_int + re[cbind(grid$c2, grid$trait_idx)] +
           stats::rnorm(nrow(grid), 0, 1)
  grid$value <- 1L + (ystar > true_taus[1]) +
                     (ystar > true_taus[2]) +
                     (ystar > true_taus[3])

  ## `unit` = individual (a genuine grouping here, but carries no diag term);
  ## `unit_obs` = a throwaway per-row id. Only the cluster2 slot carries the
  ## diag term.
  grid$c2   <- factor(grid$c2)
  grid$unit <- factor(grid$ind)
  grid$obs2 <- factor(seq_len(nrow(grid)))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | c2),
    data     = grid,
    family   = ordinal_probit(),
    unit     = "unit",
    unit_obs = "obs2",
    cluster2 = "c2"
  )))

  if (!.fit_converged(fit)) {
    skip("ordinal_probit cluster2 fixture did not converge / Hessian not PD")
  }
  expect_equal(fit$tmb_data$family_id_vec[1], 14L)
  expect_true(isTRUE(fit$use$diag_cluster2))

  sd_c2 <- as.numeric(fit$report$sd_c2)
  expect_length(sd_c2, n_traits)
  expect_true(all(is.finite(sd_c2)))
  ext <- extract_Sigma(fit, level = "cluster2", part = "unique")
  expect_length(ext$s, n_traits)
  expect_equal(unname(ext$s), sd_c2^2, tolerance = 1e-6)

  ## SD-scale absolute band 0.35 (matches test-tiers-ordinal.R cluster tier).
  for (t in seq_len(n_traits)) {
    expect_lt(abs(sd_c2[t] - true_sd[t]), 0.35,
              label = paste0("sd_c2[", t, "] (ordinal_probit)"))
  }
})
