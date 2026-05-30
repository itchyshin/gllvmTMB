## Phase B-tiers (beta): validate the `unit_obs` and `cluster` latent
## tiers under `beta_family()` (engine family-id 7, logit link only).
##
## Per docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md the
## TMB template handles structural-block priors family-agnostically; the
## family enters only at the response-likelihood node after `eta`
## accumulates the random-effect contributions. These tests confirm that
## the per-trait diagonal `unique(0 + trait | <group>)` tiers compose
## with the Beta likelihood and that the tier variances remain separately
## identifiable from the Beta concentration parameter `phi`.
##
## DGP (both tiers, logit link, phi = 5):
##   eta_it = b_t + (tier deviations);  mu_it = invlogit(eta_it);
##   y_it ~ Beta(mu_it * phi, (1 - mu_it) * phi),  y in (0, 1).
##
## Identification note: the `unit_obs` tier is built with replicate rows
## *inside* each (unit_obs, trait) cell (n_rep per cell), NOT one row per
## cell. A per-row term would be an observation-level random effect whose
## variance is not separable from the Beta `phi` (both add per-observation
## dispersion to y); the within-cell replication is what identifies the
## tier variance separately from `phi`. The same applies to the cluster
## tier, whose 3-level nesting (cluster > unit > unit_obs-with-reps) gives
## each cluster many rows.

## ----------------------------------------------------------------------
## unit_obs tier: unique(0 + trait | unit) + unique(0 + trait | unit_obs)
## ----------------------------------------------------------------------

test_that("Beta x unit_obs tier: two diag tiers converge, pd_hessian, and separate", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(2025)
  Tn          <- 3L
  trait_names <- letters[seq_len(Tn)]
  n_unit      <- 60L   # top grouping (B tier)
  n_uo_per    <- 4L    # unit_obs cells per unit
  n_rep       <- 4L    # replicate rows per (unit_obs, trait) -> identifies W vs phi

  b_true     <- c(-0.6, 0.0, 0.6)   # logit-scale trait intercepts
  sd_B_true  <- c(0.7, 0.5, 0.9)    # unit-tier      per-trait SD
  sd_W_true  <- c(0.5, 0.4, 0.6)    # unit_obs-tier  per-trait SD
  phi_true   <- 5.0                 # Beta concentration

  n_uo    <- n_unit * n_uo_per
  uo_unit <- rep(seq_len(n_unit), each = n_uo_per)            # unit of each unit_obs
  uB <- matrix(stats::rnorm(n_unit * Tn), n_unit, Tn) %*% diag(sd_B_true)
  uW <- matrix(stats::rnorm(n_uo   * Tn), n_uo,   Tn) %*% diag(sd_W_true)

  grid <- expand.grid(rep = seq_len(n_rep), uo = seq_len(n_uo))
  df <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
    uo_i <- grid$uo[i]
    u_i  <- uo_unit[uo_i]
    data.frame(
      unit  = u_i,
      obs   = uo_i,
      trait = factor(trait_names, levels = trait_names),
      eta   = b_true + uB[u_i, ] + uW[uo_i, ],
      stringsAsFactors = FALSE
    )
  }))
  df$unit  <- factor(df$unit)
  df$obs   <- factor(df$obs)
  mu       <- stats::plogis(df$eta)
  df$value <- stats::rbeta(nrow(df), mu * phi_true, (1 - mu) * phi_true)
  df <- df[, c("unit", "obs", "trait", "value")]

  ## y strictly inside (0, 1)
  expect_true(all(df$value > 0 & df$value < 1))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | unit) + unique(0 + trait | obs),
    data     = df,
    unit     = "unit",
    unit_obs = "obs",
    family   = Beta()
  )))

  ## ---- convergence + positive-definite Hessian ------------------------
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_true(isTRUE(fit$fit_health$pd_hessian))
  ## Beta family routed (engine family-id 7)
  expect_equal(fit$tmb_data$family_id_vec[1], 7L)
  ## Both diagonal tiers active
  expect_true(isTRUE(fit$use$diag_B))
  expect_true(isTRUE(fit$use$diag_W))

  ## ---- recover both tier variances ------------------------------------
  ## `part = "unique"` returns the bare per-trait diagonal (sd^2); the
  ## link-residual addition applies only to `part = "total"`, so the
  ## extracted `s` here equals report$sd_B^2 / report$sd_W^2 directly.
  sB <- as.numeric(
    extract_Sigma(fit, level = "unit",     part = "unique")$s
  )
  sW <- as.numeric(
    extract_Sigma(fit, level = "unit_obs", part = "unique")$s
  )
  expect_length(sB, Tn)
  expect_length(sW, Tn)
  expect_equal(sB, as.numeric(fit$report$sd_B)^2, tolerance = 1e-8)
  expect_equal(sW, as.numeric(fit$report$sd_W)^2, tolerance = 1e-8)

  for (t in seq_len(Tn)) {
    expect_lte(
      abs(sB[t] - sd_B_true[t]^2) / sd_B_true[t]^2, 0.30,
      label = paste0("unit-tier sigma2[", trait_names[t], "]")
    )
    expect_lte(
      abs(sW[t] - sd_W_true[t]^2) / sd_W_true[t]^2, 0.30,
      label = paste0("unit_obs-tier sigma2[", trait_names[t], "]")
    )
  }

  ## ---- tiers separate: neither collapses to ~0, phi not absorbing -----
  ## If the unit_obs OLRE were confounded with phi it would collapse to 0
  ## while phi shrank; both tiers stay well away from the boundary and the
  ## Beta concentration recovers near its true value.
  expect_true(all(sB > 0.05))
  expect_true(all(sW > 0.05))
  phi_hat <- as.numeric(fit$report$phi_beta)
  expect_length(phi_hat, Tn)
  expect_true(all(phi_hat > phi_true / 3 & phi_hat < 3 * phi_true))
})

## ----------------------------------------------------------------------
## cluster tier: 3-level fixture, unique(0 + trait | <cluster_col>)
## ----------------------------------------------------------------------

test_that("Beta x cluster tier: 3-level fit converges, pd_hessian, recovers cluster variance", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(2025)
  Tn          <- 3L
  trait_names <- letters[seq_len(Tn)]
  ## Strictly nested: cluster (population) > unit (individual) > unit_obs
  ## (session). Each individual contributes several sessions, so each
  ## cluster carries many rows -> the cluster-tier variance is identified.
  n_cl        <- 40L   # clusters (third / cluster slot)
  n_unit_per  <- 5L    # individuals per cluster
  n_sess_per  <- 4L    # sessions per individual (replication)

  b_true    <- c(-0.5, 0.1, 0.7)   # logit-scale trait intercepts
  sd_q_true <- c(0.8, 0.6, 1.0)    # cluster-tier per-trait SD (recovery target)
  phi_true  <- 5.0

  n_unit  <- n_cl * n_unit_per
  unit_cl <- rep(seq_len(n_cl), each = n_unit_per)             # cluster of each unit
  uQ <- matrix(stats::rnorm(n_cl * Tn), n_cl, Tn) %*% diag(sd_q_true)

  grid <- expand.grid(sess = seq_len(n_sess_per), unit = seq_len(n_unit))
  df <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
    u_i  <- grid$unit[i]
    cl_i <- unit_cl[u_i]
    data.frame(
      cluster    = cl_i,
      individual = u_i,
      session    = (u_i - 1L) * n_sess_per + grid$sess[i],
      trait      = factor(trait_names, levels = trait_names),
      eta        = b_true + uQ[cl_i, ],
      stringsAsFactors = FALSE
    )
  }))
  df$cluster    <- factor(df$cluster)
  df$individual <- factor(df$individual)
  df$session    <- factor(df$session)
  mu       <- stats::plogis(df$eta)
  df$value <- stats::rbeta(nrow(df), mu * phi_true, (1 - mu) * phi_true)
  df <- df[, c("cluster", "individual", "session", "trait", "value")]

  expect_true(all(df$value > 0 & df$value < 1))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | cluster),
    data     = df,
    unit     = "individual",
    unit_obs = "session",
    cluster  = "cluster",
    family   = Beta()
  )))

  ## ---- convergence + positive-definite Hessian ------------------------
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_true(isTRUE(fit$fit_health$pd_hessian))
  expect_equal(fit$tmb_data$family_id_vec[1], 7L)
  ## Cluster (third-slot) diagonal active and stored under the canonical name
  expect_true(isTRUE(fit$use$diag_species))
  expect_equal(fit$cluster_col, "cluster")

  ## ---- recover cluster variance ---------------------------------------
  sQ <- as.numeric(
    extract_Sigma(fit, level = "cluster", part = "unique")$s
  )
  expect_length(sQ, Tn)
  expect_equal(sQ, as.numeric(fit$report$sd_q)^2, tolerance = 1e-8)

  for (t in seq_len(Tn)) {
    expect_lte(
      abs(sQ[t] - sd_q_true[t]^2) / sd_q_true[t]^2, 0.30,
      label = paste0("cluster-tier sigma2[", trait_names[t], "]")
    )
  }
  expect_true(all(sQ > 0.05))

  phi_hat <- as.numeric(fit$report$phi_beta)
  expect_length(phi_hat, Tn)
  expect_true(all(phi_hat > phi_true / 3 & phi_hat < 3 * phi_true))
})
