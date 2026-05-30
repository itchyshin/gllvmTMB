## Phase B-tiers: ordinal_probit() x {unit_obs, cluster} tier validation.
##
## Goal: verify the two non-{unit} grouping tiers behave correctly under the
## ordinal_probit() threshold family, whose latent residual variance is fixed
## at sigma2_d = 1 EXACTLY by construction (Wright 1934; Falconer & Mackay
## 1996; Hadfield 2015 MEE 6:706-714). That fixed-scale liability is what
## makes one of these two tiers structurally degenerate and the other clean.
##
## ---------------------------------------------------------------------------
## Tier 1 -- unit_obs (the within-unit / "W" tier).
##
##   Recipe from the brief:
##     unique(0 + trait | unit) + unique(0 + trait | unit_obs)
##   with `unit_obs` at per-row resolution (one observation per unit_obs
##   level). A per-row `unique()` at the W tier is an observation-level
##   random effect (OLRE). Under ordinal_probit the OLRE variance sd_W is
##   NOT separately identifiable: the threshold model pins sigma2_d = 1 to
##   fix the cutpoint scale, and an extra per-row sd_W simply rescales the
##   cutpoints (tau_k -> tau_k / sqrt(sd_W^2 + 1)). The engine therefore
##   auto-suppresses the W-tier OLRE for ordinal traits -- it maps
##   theta_diag_W and the matching s_W column off and pins sd_W at ~1e-6
##   (R/fit-multi.R:1803-1870; mirrors test-mixed-family-olre.R test 4).
##
##   Consequence for recovery: the `unit` (B) tier variance IS recoverable
##   (given replication per (unit, trait) cell so the unit effect is
##   identified above the fixed liability), but the `unit_obs` (W) tier
##   variance is NOT -- it is the sigma2_d = 1 floor case the Phase B0
##   scoping audit flags. This test recovers the identifiable B tier and
##   documents the W tier as a structural non-recovery (honest skip of the
##   W-variance claim only), asserting the engine's documented suppression
##   rather than fabricating a recovered value.
##
## ---------------------------------------------------------------------------
## Tier 2 -- cluster (the third-slot grouping).
##
##   A 3-level fixture (population > individual > session), fitted with the
##   public `cluster = "population"` argument and a
##   unique(0 + trait | population) term. The cluster grouping spans many
##   rows per level (it is NOT per-row), so the cluster variance sits one
##   level ABOVE the fixed sigma2_d = 1 liability residual and is cleanly
##   identifiable. This tier recovers its per-trait variance (sd_q /
##   diag_species, reported by extract_Sigma(level = "cluster")).
##
## K = 4 ordinal categories, 3 traits, seed-controlled throughout.

## ---- Tier 1: unit_obs (W) -- B recovers; W is the sigma2_d=1 floor --------

test_that("ordinal_probit x unit_obs tier: converges + pd_hessian; unit (B) variance recovers, unit_obs (W) OLRE is the sigma2_d=1 floor", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(303)
  n_unit       <- 120L          # between-unit grouping levels
  n_rep        <- 6L            # replicates per (unit, trait): identifies B
  Tn           <- 3L            # three traits
  trait_names  <- c("a", "b", "c")
  true_unit_sd <- c(0.9, 0.7, 1.1)   # B-tier per-trait SD (the unit tier)
  true_taus    <- c(0, 0.6, 1.3)     # K = 4 cutpoints (3 thresholds)
  true_int     <- c(0.2, -0.1, 0.0)  # per-trait latent intercept

  ## Per-unit (B) random effect, shared across that unit's replicate rows.
  u <- vapply(seq_len(Tn),
              function(t) stats::rnorm(n_unit, 0, true_unit_sd[t]),
              numeric(n_unit))

  df <- expand.grid(rep_idx   = seq_len(n_rep),
                    trait_idx = seq_len(Tn),
                    unit      = seq_len(n_unit))
  df$trait <- factor(trait_names[df$trait_idx], levels = trait_names)
  df$unit  <- factor(df$unit)
  df$obs   <- factor(seq_len(nrow(df)))     # per-row unit_obs (OLRE resolution)

  ## Latent liability y* = intercept + unit effect + N(0, 1), then threshold.
  ystar <- true_int[df$trait_idx] +
           u[cbind(as.integer(df$unit), df$trait_idx)] +
           stats::rnorm(nrow(df), 0, 1)
  df$value <- 1L + (ystar > true_taus[1]) +
                   (ystar > true_taus[2]) +
                   (ystar > true_taus[3])

  ## Sanity: unit_obs really is per-row (so the W term is an OLRE), while the
  ## unit tier has replication (so the B term can be identified).
  expect_equal(length(unique(df$obs)), nrow(df))
  expect_gt(nrow(df) / nlevels(df$unit), Tn)        # > 1 row per (unit, trait)

  msgs <- testthat::capture_messages(
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait +
              unique(0 + trait | unit) +
              unique(0 + trait | obs),
      data     = df,
      unit     = "unit",
      unit_obs = "obs",
      family   = ordinal_probit()
    ))
  )

  ## --- Convergence + positive-definite Hessian ---------------------------
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))
  expect_equal(fit$tmb_data$family_id_vec[1], 14L)  # ordinal_probit family id

  ## --- unit (B) tier: variance IS identifiable, recovers to truth --------
  expect_true(isTRUE(fit$use$diag_B))
  sd_B <- as.numeric(fit$report$sd_B)
  expect_length(sd_B, Tn)
  for (t in seq_len(Tn)) {
    expect_lt(abs(sd_B[t] - true_unit_sd[t]), 0.30,
              label = paste0("sd_B[", t, "] recovers unit-tier SD"))
  }
  ## extract_Sigma at the unit tier returns the same diagonal (variances).
  ext_B <- extract_Sigma(fit, level = "unit", part = "unique")
  expect_length(ext_B$s, Tn)
  expect_equal(unname(ext_B$s), sd_B^2, tolerance = 1e-6)

  ## --- unit_obs (W) tier: structurally unidentifiable (sigma2_d = 1 floor)
  ## HONEST SKIP of the W-variance RECOVERY claim: under ordinal_probit a
  ## per-row OLRE cannot be separated from the fixed unit liability, so the
  ## engine auto-suppresses it. We assert the documented suppression (the
  ## truthful outcome) rather than fabricate a recovered sd_W.
  expect_true("theta_diag_W" %in% names(fit$tmb_obj$env$map))
  expect_true(all(is.na(fit$tmb_obj$env$map$theta_diag_W)),
              label = "theta_diag_W mapped off for the ordinal_probit W-OLRE")
  expect_true(all(is.na(fit$tmb_obj$env$map$s_W)),
              label = "s_W mapped off for the ordinal_probit W-OLRE")
  expect_true(all(as.numeric(fit$report$sd_W) < 1e-3),
              label = "sd_W pinned at the ~1e-6 floor (not free-estimated)")
  expect_true(
    any(grepl("Skipping OLRE", msgs) & grepl("ordinal_probit", msgs)),
    label = "engine announces the ordinal_probit OLRE suppression"
  )
  ## Document the non-recovery explicitly: the unit_obs (W) tier variance is
  ## the sigma2_d = 1 floor case from the Phase B0 scoping audit and is NOT
  ## recoverable for ordinal_probit. (Recoverable only with a non-fixed-scale
  ## family, or by collapsing the tier into the fixed liability as done here.)
  testthat::succeed(
    "unit_obs (W) tier variance is the sigma2_d=1 floor: structurally non-recoverable under ordinal_probit; suppression asserted above."
  )
})

## ---- Tier 2: cluster (third slot) -- clean recovery -----------------------

test_that("ordinal_probit x cluster tier: 3-level fixture converges + pd_hessian; cluster variance recovers", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(404)
  n_pop           <- 30L         # populations (cluster levels)
  n_ind_per       <- 10L         # individuals per population
  n_traits        <- 3L
  trait_names     <- c("a", "b", "c")
  true_cluster_sd <- c(1.0, 0.8, 1.2)   # per-trait population (cluster) SD
  true_taus       <- c(0, 0.6, 1.3)     # K = 4 cutpoints
  true_int        <- 0.1

  ## Strictly-nested fixture: population > individual > session(=per-row).
  pop_of_ind <- rep(seq_len(n_pop), each = n_ind_per)
  ind        <- seq_len(n_pop * n_ind_per)

  ## Population-level random effect per trait (the cluster tier signal).
  pe <- vapply(seq_len(n_traits),
               function(t) stats::rnorm(n_pop, 0, true_cluster_sd[t]),
               numeric(n_pop))

  df <- expand.grid(trait_idx = seq_len(n_traits), individual = ind)
  df$population <- factor(pop_of_ind[df$individual])
  df$individual <- factor(df$individual)
  df$session_id <- factor(seq_len(nrow(df)))   # per-row unit_obs (not in formula)
  df$trait      <- factor(trait_names[df$trait_idx], levels = trait_names)

  ystar <- true_int +
           pe[cbind(as.integer(as.character(df$population)), df$trait_idx)] +
           stats::rnorm(nrow(df), 0, 1)
  df$value <- 1L + (ystar > true_taus[1]) +
                   (ystar > true_taus[2]) +
                   (ystar > true_taus[3])

  ## Sanity: the cluster grouping spans many rows per level (NOT per-row),
  ## so the cluster variance sits above the fixed sigma2_d = 1 liability.
  expect_gt(nrow(df) / nlevels(df$population), n_traits)

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | population),
    data     = df,
    unit     = "individual",
    unit_obs = "session_id",
    cluster  = "population",
    family   = ordinal_probit()
  )))

  ## --- Convergence + positive-definite Hessian ---------------------------
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))
  expect_equal(fit$tmb_data$family_id_vec[1], 14L)
  expect_equal(fit$cluster_col, "population")

  ## --- cluster tier: variance recovers -----------------------------------
  expect_true(isTRUE(fit$use$diag_species))
  sd_q <- as.numeric(fit$report$sd_q)
  expect_length(sd_q, n_traits)
  for (t in seq_len(n_traits)) {
    expect_lt(abs(sd_q[t] - true_cluster_sd[t]), 0.35,
              label = paste0("sd_q[", t, "] recovers cluster-tier SD"))
  }
  ## extract_Sigma at the cluster tier returns the per-trait variances.
  ext <- extract_Sigma(fit, level = "cluster", part = "unique")
  expect_length(ext$s, n_traits)
  expect_equal(unname(ext$s), sd_q^2, tolerance = 1e-6)
})
