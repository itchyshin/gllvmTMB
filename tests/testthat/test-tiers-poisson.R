# Phase B-tiers (poisson): unit_obs (within-unit/OLRE) + cluster tiers.
#
# Validates that the grouping-tier variance-component machinery recovers
# the right per-trait variances under a log-link Poisson response, for the
# two tiers not exercised by the Gaussian tier tests:
#
#   * unit_obs tier: a nested fixture with BOTH
#       unique(0 + trait | unit)      -> diag_B -> sd_B  (between-unit)
#       unique(0 + trait | unit_obs)  -> diag_W -> sd_W  (within-unit/OLRE)
#     where `unit_obs` is at per-row resolution, so the W-tier term is an
#     observation-level random effect (OLRE). Poisson (family id 2) fits
#     OLRE normally (R/fit-multi.R per-family-aware OLRE table). We recover
#     BOTH tiers' variances and assert they separate (not confounded).
#
#   * cluster tier: a 3-level fixture (obs within unit within cluster) fit
#       via the `cluster = ...` argument with
#       unique(0 + trait | cluster)   -> diag_species -> sd_q
#     and recover the cluster-level variance.
#
# Recovery target: for `part = "unique"`, extract_Sigma()$s returns the bare
# random-effect variance (== sd_B^2 / sd_W^2 / sd_q^2); the Poisson
# link-implicit residual is added only on the `total`/Sigma path, not here.
#
# Tolerance: Phase-B0 non-Gaussian scoping audit
# (docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md) specifies
# a mean-dependent, wider band for count families. With intercept mean ~2
# (exp(2) ~ 7.4 expected counts) Poisson sampling noise is non-trivial
# relative to the variance signal, so we use a relative band: 0.30 for the
# unit_obs tiers (many unit + obs draws) and 0.35 for the cluster tier
# (variance estimated from cluster-level draws only, hence noisier). These
# are honest count-family bands, not widened Gaussian tolerances.

test_that("unit_obs tier (poisson OLRE): recovers sigma2_unit + sigma2_unit_obs and they separate", {
  skip_on_cran()

  set.seed(202)
  n_traits <- 3L
  n_unit   <- 120L      # between-unit grouping with replication
  n_rep    <- 10L       # replicate observations per unit
  true_s2_unit     <- c(0.40, 0.25, 0.55)   # between-unit per-trait variances
  true_s2_unit_obs <- c(0.30, 0.50, 0.20)   # within-unit (OLRE) per-trait variances
  alpha <- rep(2.0, n_traits)               # log-link intercept -> mean ~ exp(2)

  ## One row per (unit, rep); `unit_obs` is the unique row id so that
  ## unique(0 + trait | unit_obs) lands at per-row (OLRE) resolution while
  ## unique(0 + trait | unit) stays a genuine grouping (n_rep rows per unit).
  grid <- expand.grid(rep = seq_len(n_rep), unit = seq_len(n_unit))
  grid$unit_obs <- seq_len(nrow(grid))
  long <- do.call(rbind, lapply(seq_len(n_traits), function(t) {
    data.frame(unit = grid$unit, unit_obs = grid$unit_obs, trait_idx = t)
  }))

  b_unit <- vapply(seq_len(n_traits),
                   function(t) stats::rnorm(n_unit, 0, sqrt(true_s2_unit[t])),
                   numeric(n_unit))
  e_obs  <- vapply(seq_len(n_traits),
                   function(t) stats::rnorm(nrow(grid), 0, sqrt(true_s2_unit_obs[t])),
                   numeric(nrow(grid)))
  eta <- alpha[long$trait_idx] +
    b_unit[cbind(long$unit, long$trait_idx)] +
    e_obs[cbind(long$unit_obs, long$trait_idx)]
  long$value    <- stats::rpois(nrow(long), exp(eta))
  long$unit     <- factor(long$unit)
  long$unit_obs <- factor(long$unit_obs)
  long$trait    <- factor(paste0("t", long$trait_idx),
                          levels = paste0("t", seq_len(n_traits)))

  fit <- suppressMessages(suppressWarnings(
    gllvmTMB(
      value ~ 0 + trait +
        unique(0 + trait | unit) +
        unique(0 + trait | unit_obs),
      data     = long,
      unit     = "unit",
      unit_obs = "unit_obs",
      family   = poisson()
    )
  ))

  ## Honest skip on non-convergence -- never fake-pass.
  if (!identical(fit$opt$convergence, 0L) || !isTRUE(fit$sd_report$pdHess)) {
    skip("poisson unit_obs OLRE fixture did not converge / Hessian not PD")
  }

  ## Both diag tiers registered.
  expect_true(isTRUE(fit$use$diag_B))
  expect_true(isTRUE(fit$use$diag_W))

  ## Recovered per-trait variances (bare RE variances; == sd_B^2 / sd_W^2).
  s2_unit_hat     <- as.numeric(extract_Sigma(fit, level = "unit",     part = "unique")$s)
  s2_unit_obs_hat <- as.numeric(extract_Sigma(fit, level = "unit_obs", part = "unique")$s)
  expect_length(s2_unit_hat,     n_traits)
  expect_length(s2_unit_obs_hat, n_traits)

  ## Recover BOTH tiers within the Phase-B0 mean-dependent count band.
  for (t in seq_len(n_traits)) {
    expect_equal(s2_unit_hat[t], true_s2_unit[t],
                 tolerance = 0.30,
                 label = paste0("sigma2_unit[", t, "]"))
    expect_equal(s2_unit_obs_hat[t], true_s2_unit_obs[t],
                 tolerance = 0.30,
                 label = paste0("sigma2_unit_obs[", t, "]"))
  }

  ## Tiers separate (not confounded): neither tier collapses to ~0, and
  ## each tracks its OWN truth rather than a shared/merged variance. With
  ## the two tiers carrying distinct per-trait truths, recovering each to
  ## its own value is direct evidence they are not confounded.
  expect_true(all(s2_unit_hat     > 0.05))
  expect_true(all(s2_unit_obs_hat > 0.05))
  ## A confounded fit could not put trait-1 unit variance (0.40) above its
  ## obs variance (0.30) AND trait-2 unit (0.25) below its obs (0.50); the
  ## per-trait sign of (unit - obs) must match the truth for all traits.
  expect_equal(sign(s2_unit_hat - s2_unit_obs_hat),
               sign(true_s2_unit - true_s2_unit_obs))
})

test_that("cluster tier (poisson): `cluster =` argument recovers cluster-level variance", {
  skip_on_cran()

  set.seed(33)
  n_traits   <- 3L
  n_clu      <- 100L    # number of clusters (drives cluster-variance precision)
  n_unit_per <- 6L      # units per cluster
  n_obs_per  <- 4L      # observations per unit
  true_s2_clu <- c(0.45, 0.30, 0.60)
  alpha <- rep(2.0, n_traits)

  ## Strictly nested: obs within unit within cluster.
  clu  <- rep(seq_len(n_clu), each = n_unit_per * n_obs_per)
  unit <- rep(seq_len(n_clu * n_unit_per), each = n_obs_per)
  obs  <- seq_along(unit)
  base <- data.frame(cluster = clu, unit = unit, unit_obs = obs)
  long <- do.call(rbind, lapply(seq_len(n_traits), function(t) {
    cbind(base, trait_idx = t)
  }))

  q_clu <- vapply(seq_len(n_traits),
                  function(t) stats::rnorm(n_clu, 0, sqrt(true_s2_clu[t])),
                  numeric(n_clu))
  eta <- alpha[long$trait_idx] + q_clu[cbind(long$cluster, long$trait_idx)]
  long$value    <- stats::rpois(nrow(long), exp(eta))
  long$cluster  <- factor(long$cluster)
  long$unit     <- factor(long$unit)
  long$unit_obs <- factor(long$unit_obs)
  long$trait    <- factor(paste0("t", long$trait_idx),
                          levels = paste0("t", seq_len(n_traits)))

  fit <- suppressMessages(suppressWarnings(
    gllvmTMB(
      value ~ 0 + trait + unique(0 + trait | cluster),
      data     = long,
      unit     = "unit",
      unit_obs = "unit_obs",
      cluster  = "cluster",
      family   = poisson()
    )
  ))

  ## Honest skip on non-convergence -- never fake-pass.
  if (!identical(fit$opt$convergence, 0L) || !isTRUE(fit$sd_report$pdHess)) {
    skip("poisson cluster fixture did not converge / Hessian not PD")
  }

  ## Cluster (third-slot) tier registered under the `cluster =` argument.
  expect_true(isTRUE(fit$use$diag_species))
  expect_equal(fit$cluster_col, "cluster")

  ## Recover the cluster-level per-trait variance (== sd_q^2).
  s2_clu_hat <- as.numeric(extract_Sigma(fit, level = "cluster", part = "unique")$s)
  expect_length(s2_clu_hat, n_traits)
  for (t in seq_len(n_traits)) {
    expect_equal(s2_clu_hat[t], true_s2_clu[t],
                 tolerance = 0.35,
                 label = paste0("sigma2_cluster[", t, "]"))
  }
})
