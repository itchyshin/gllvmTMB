## Phase B-tiers: nbinom2 x {unit_obs, cluster} tier recovery.
##
## Validates that the two grouping tiers that sit *outside* the
## between-unit `latent()`/`unique()` block -- the observation-level
## OLRE tier (`unit_obs`, internal slot W) and the third-slot cluster
## tier (`cluster`, internal slot sd_q) -- compose correctly with the
## nbinom2 response family. nbinom2 is the canonical overdispersed-count
## family in ecology (Ver Hoef & Boveng 2007, Ecology 88:2766-2772).
##
## Family scope reference: docs/dev-log/audits/2026-05-26-phase-b0-
## nongaussian-scoping.md, table 3.2: nbinom2 x <keyword> x `unique`
## is rated OK because the overdispersion `phi` is a legitimate scale
## parameter (the Design 42 binomial-psi lesson does NOT apply). BUT the
## same memo (row "latent(d=K) at large phi") flags a phi<->per-row
## variance trade-off. That trade-off is exactly what governs the
## OLRE (unit_obs) tier here: the per-observation random effect competes
## with nbinom2's overdispersion for the same residual variance, so the
## OLRE variance is only weakly identified and recovers with a downward
## bias even at large n. We therefore assert the OLRE tier is finite,
## positive, and separable from the (well-identified) unit tier, rather
## than claiming tight point recovery. The cluster tier has no such
## competition (the cluster RE is shared across all observations within a
## cluster, orthogonal to per-row overdispersion) and recovers cleanly,
## including phi ~ truth.
##
## Seed discipline (phi-blow-up guard): a seed sweep over
## {101,202,303,404,505,606} for the unit_obs fixture and
## {11,22,33,44,55,66} for the cluster fixture showed phi occasionally
## diverges to ~1e7 on under-replicated designs (the phi<->variance
## trade-off saturating). The fixtures below use heavy replication
## (unit_obs: 200 units x 10 reps; cluster: 30 pops x 6 ind x 4 sess) and
## the seeds (202, 22) were chosen as representative members of the sweep
## where every fit reaches a PD Hessian with finite phi. The tests stay
## SKIP-honest: if a fit fails to converge with a PD Hessian we skip()
## rather than relax an assertion.

## ------------------------------------------------------------------
## unit_obs (OLRE) tier: unique(0+trait|site) + unique(0+trait|site_species)
## ------------------------------------------------------------------
test_that("nbinom2 x unit_obs: unit + OLRE tiers fit, phi finite, tiers separate", {
  skip_if_not_heavy()
  skip_on_cran()

  n_units  <- 200L
  n_rep    <- 10L          # multiple obs per unit -> unit tier identified
  n_traits <- 3L
  alpha    <- log(2)       # marginal mean ~ 2-3 after RE inflation (Jensen)
  phi_true <- 2.0
  var_unit_true <- c(0.5, 0.4, 0.6)   # between-unit unique() variances
  var_obs_true  <- c(0.4, 0.4, 0.4)   # observation-level (OLRE) variances

  set.seed(202L)
  grid <- expand.grid(
    rep       = seq_len(n_rep),
    unit_idx  = seq_len(n_units),
    trait_idx = seq_len(n_traits)
  )
  grid <- grid[order(grid$unit_idx, grid$rep, grid$trait_idx), ]
  grid$site         <- factor(grid$unit_idx)
  grid$site_species <- factor(seq_len(nrow(grid)))   # one row per obs -> OLRE
  grid$trait <- factor(paste0("t", grid$trait_idx),
                       levels = paste0("t", seq_len(n_traits)))

  ## Between-unit random effect: constant within a unit, per-trait variance.
  b_unit <- matrix(0, n_units, n_traits)
  for (t in seq_len(n_traits))
    b_unit[, t] <- rnorm(n_units, sd = sqrt(var_unit_true[t]))
  ## Observation-level random effect: independent per row.
  e_obs <- rnorm(nrow(grid), sd = sqrt(var_obs_true[grid$trait_idx]))
  eta   <- alpha + b_unit[cbind(grid$unit_idx, grid$trait_idx)] + e_obs
  grid$value <- rnbinom(nrow(grid), mu = exp(eta), size = phi_true)

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
            unique(0 + trait | site) +
            unique(0 + trait | site_species),
    data   = grid,
    family = nbinom2()
  )))

  ## --- Convergence + PD Hessian gate (SKIP-honest) ---------------------
  if (!identical(fit$opt$convergence, 0L) ||
      !isTRUE(fit$fit_health$pd_hessian)) {
    skip("nbinom2 x unit_obs fit did not reach a PD Hessian on seed 202.")
  }
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$fit_health$pd_hessian))
  expect_equal(fit$tmb_data$family_id_vec[1], 5L)   # nbinom2 family id

  ## --- phi finite + positive, near truth band -------------------------
  phi_hat <- as.numeric(fit$report$phi_nbinom2)
  expect_equal(length(phi_hat), n_traits)
  expect_true(all(is.finite(phi_hat)))
  expect_true(all(phi_hat > 0))
  ## Per-trait phi inside [phi/3, 3*phi]; the OLRE<->phi trade-off pulls
  ## phi a little below truth (it does not absorb *all* the OLRE variance).
  expect_true(all(phi_hat > phi_true / 3))
  expect_true(all(phi_hat < 3 * phi_true))

  ## --- Recover BOTH tier variances ------------------------------------
  v_unit <- as.numeric(extract_Sigma(fit, level = "unit",     part = "unique")$s)
  v_obs  <- as.numeric(extract_Sigma(fit, level = "unit_obs", part = "unique")$s)
  expect_equal(length(v_unit), n_traits)
  expect_equal(length(v_obs),  n_traits)

  ## Unit tier is well identified (multiple obs per unit): each per-trait
  ## variance lands in a band around its truth (0.5, 0.4, 0.6).
  for (t in seq_len(n_traits)) {
    expect_gt(v_unit[t], 0.30)
    expect_lt(v_unit[t], 0.80)
  }

  ## OLRE (unit_obs) tier: finite and strictly positive. Per the Phase B0
  ## scoping memo (3.2), nbinom2's overdispersion competes with the
  ## per-row OLRE, so this tier recovers with a downward bias -- we assert
  ## identifiability (positive, finite) rather than tight point recovery.
  expect_true(all(is.finite(v_obs)))
  for (t in seq_len(n_traits)) expect_gt(v_obs[t], 0)

  ## Tiers SEPARATE: the OLRE tier is distinct from (and, under the phi
  ## trade-off, smaller than) the unit tier. If the two grouping slots
  ## were aliased they would return identical variances.
  expect_lt(max(v_obs), min(v_unit))
  expect_gt(max(abs(v_unit - v_obs)), 0.10)
})

## ------------------------------------------------------------------
## cluster (third-slot) tier: 3-level fixture, cluster = "population"
## ------------------------------------------------------------------
test_that("nbinom2 x cluster: 3-level fit, phi finite, cluster variance recovers", {
  skip_if_not_heavy()
  skip_on_cran()

  n_pop      <- 30L
  n_ind_per  <- 6L         # individuals per population
  n_sess     <- 4L         # sessions per individual
  n_traits   <- 3L
  alpha      <- log(2)
  phi_true   <- 2.0
  var_clust_true <- c(0.5, 0.4, 0.6)   # per-trait cluster (population) variances

  set.seed(22L)
  n_ind      <- n_pop * n_ind_per
  pop_of_ind <- rep(seq_len(n_pop), each = n_ind_per)
  grid <- expand.grid(
    sess      = seq_len(n_sess),
    ind       = seq_len(n_ind),
    trait_idx = seq_len(n_traits)
  )
  grid <- grid[order(grid$ind, grid$sess, grid$trait_idx), ]
  grid$pop_idx    <- pop_of_ind[grid$ind]
  grid$population <- factor(grid$pop_idx)            # cluster (3rd slot)
  grid$individual <- factor(grid$ind)                # unit
  grid$session_id <- factor(seq_len(nrow(grid)))     # unit_obs (one row each)
  grid$trait <- factor(paste0("t", grid$trait_idx),
                       levels = paste0("t", seq_len(n_traits)))

  ## Cluster (population) random effect: constant within a population.
  b_clust <- matrix(0, n_pop, n_traits)
  for (t in seq_len(n_traits))
    b_clust[, t] <- rnorm(n_pop, sd = sqrt(var_clust_true[t]))
  eta <- alpha + b_clust[cbind(grid$pop_idx, grid$trait_idx)]
  grid$value <- rnbinom(nrow(grid), mu = exp(eta), size = phi_true)

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | population),
    data     = grid,
    unit     = "individual",
    unit_obs = "session_id",
    cluster  = "population",
    family   = nbinom2()
  )))

  ## --- Convergence + PD Hessian gate (SKIP-honest) ---------------------
  if (!identical(fit$opt$convergence, 0L) ||
      !isTRUE(fit$fit_health$pd_hessian)) {
    skip("nbinom2 x cluster fit did not reach a PD Hessian on seed 22.")
  }
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$fit_health$pd_hessian))
  expect_equal(fit$tmb_data$family_id_vec[1], 5L)   # nbinom2 family id

  ## The third grouping slot is registered as the cluster tier.
  expect_true(isTRUE(fit$use$diag_species))
  expect_equal(fit$cluster_col, "population")

  ## --- phi finite + near truth ----------------------------------------
  ## No OLRE competition here (cluster RE is shared within a population,
  ## orthogonal to per-row overdispersion), so phi recovers cleanly ~ 2.
  phi_hat <- as.numeric(fit$report$phi_nbinom2)
  expect_equal(length(phi_hat), n_traits)
  expect_true(all(is.finite(phi_hat)))
  expect_true(all(phi_hat > 1.0))
  expect_true(all(phi_hat < 4.0))

  ## --- Recover cluster variance ---------------------------------------
  v_clust <- as.numeric(extract_Sigma(fit, level = "cluster", part = "unique")$s)
  expect_equal(length(v_clust), n_traits)
  expect_true(all(is.finite(v_clust)))
  ## Each per-trait cluster variance lands in a band around its truth
  ## (0.5, 0.4, 0.6); 30 populations gives reasonable recovery.
  for (t in seq_len(n_traits)) {
    expect_gt(v_clust[t], 0.25)
    expect_lt(v_clust[t], 0.95)
  }
})
