# Coverage for simulate_unit_trait(): the generic (unit, observation, trait)
# stacked-trait simulator. Three contracts:
#   (a) recovery -- a gllvmTMB fit recovers the true between-unit Lambda_B
#       shape (heavy-gated; the TMB fit is slow);
#   (b) the `unit_observation` id matches the `unique()` within-unit row
#       contract (one level per unit-observation cell);
#   (c) the all-NULL default produces a coherent fixed-effects-only dataset.

# ---- (c) all-NULL default: fixed-effects-only, coherent shape ------------

test_that("simulate_unit_trait(): all-NULL default is fixed-effects-only", {
  sim <- simulate_unit_trait(n_units = 20L, n_obs_per_unit = 3L,
                             n_traits = 4L, seed = 1)
  ## Structure components all NULL -> only alpha + sigma2_eps in truth.
  expect_named(sim, c("data", "truth"))
  expect_named(sim$truth,
               c("alpha", "Lambda_B", "Lambda_W", "psi_B", "psi_W",
                 "sigma2_eps"))
  expect_null(sim$truth$Lambda_B)
  expect_null(sim$truth$Lambda_W)
  expect_null(sim$truth$psi_B)
  expect_null(sim$truth$psi_W)
  expect_length(sim$truth$alpha, 4L)
  expect_equal(sim$truth$sigma2_eps, 0.5)

  ## Long-format shape: one row per (unit, observation, trait).
  expect_equal(nrow(sim$data), 20L * 3L * 4L)
  expect_named(sim$data,
               c("unit", "observation", "trait", "value", "unit_observation"))
  expect_equal(nlevels(sim$data$unit), 20L)
  expect_equal(nlevels(sim$data$observation), 3L)
  expect_equal(nlevels(sim$data$trait), 4L)
  expect_true(is.numeric(sim$data$value))
  expect_false(any(is.na(sim$data$value)))
  ## No phylo/spatial machinery returned.
  expect_null(sim$Cphy)
  expect_null(sim$coords)
})

test_that("simulate_unit_trait(): same seed reproduces $data", {
  s1 <- simulate_unit_trait(n_units = 15L, n_obs_per_unit = 2L,
                            n_traits = 3L, seed = 99)
  s2 <- simulate_unit_trait(n_units = 15L, n_obs_per_unit = 2L,
                            n_traits = 3L, seed = 99)
  expect_identical(s1$data, s2$data)
})

test_that("simulate_unit_trait(): alpha and matrices honoured in truth", {
  alpha_in <- c(-1, 0.5, 2)
  L_B <- matrix(c(0.8, -0.3, 0.5), nrow = 3, ncol = 1)
  sim <- simulate_unit_trait(n_units = 12L, n_obs_per_unit = 3L,
                             n_traits = 3L, alpha = alpha_in,
                             Lambda_B = L_B, psi_W = 0.4, seed = 1)
  expect_equal(sim$truth$alpha, alpha_in)
  expect_identical(sim$truth$Lambda_B, L_B)
  ## psi_W scalar recycled to length n_traits in truth.
  expect_length(sim$truth$psi_W, 3L)
  expect_true(all(sim$truth$psi_W == 0.4))
})

test_that("simulate_unit_trait(): wrong-nrow Lambda_B errors", {
  expect_error(
    simulate_unit_trait(n_units = 10L, n_obs_per_unit = 2L, n_traits = 3L,
                        Lambda_B = matrix(0, 2, 1), seed = 1)
  )
})

# ---- (b) unit_observation matches the unique() row contract --------------

test_that("simulate_unit_trait(): unit_observation is the unique() row id", {
  n_units <- 8L
  n_obs   <- 3L
  n_tr    <- 4L
  sim <- simulate_unit_trait(n_units = n_units, n_obs_per_unit = n_obs,
                             n_traits = n_tr, seed = 7)
  d <- sim$data

  ## Contract: one unit_observation level per (unit, observation) cell.
  expect_equal(nlevels(d$unit_observation), n_units * n_obs)

  ## Each unit_observation level groups exactly n_traits rows (one per
  ## trait) -- i.e. it is the within-unit observation grouping that a
  ## `unique(0 + trait | unit_observation)` term ranges over.
  per_cell <- table(d$unit_observation)
  expect_true(all(per_cell == n_tr))

  ## The level label decomposes as paste(unit, observation, "_") and is a
  ## bijection with the (unit, observation) pair.
  key <- paste(d$unit, d$observation, sep = "_")
  expect_equal(as.character(d$unit_observation), key)
  expect_equal(length(unique(key)), n_units * n_obs)
})

# ---- (a) recovery of true Lambda_B from a fit (heavy-gated) ---------------

test_that("simulate_unit_trait(): a gllvmTMB fit recovers between-unit Lambda_B", {
  skip_on_cran()
  skip_if_not_heavy()

  set.seed(2026)

  n_traits <- 5L
  K        <- 2L
  ## Clear two-axis between-unit loading with mixed signs (shape is
  ## identified only up to rotation, so the recovery target is shape).
  Lambda_B <- matrix(
    c(0.90,  0.10,
      0.70, -0.20,
     -0.40,  0.60,
      0.20,  0.80,
      0.55,  0.50),
    nrow = n_traits, ncol = K, byrow = TRUE
  )
  ## Diagonal within-unit term + small row residual; replicate observations
  ## per unit identify the between/within split.
  sim <- simulate_unit_trait(
    n_units        = 180L,
    n_obs_per_unit = 4L,
    n_traits       = n_traits,
    alpha          = rep(0, n_traits),
    Lambda_B       = Lambda_B,
    psi_W          = c(0.30, 0.25, 0.35, 0.20, 0.30),
    sigma2_eps     = 0.40,
    seed           = 11
  )
  df <- sim$data

  ## Between-unit reduced-rank latent block on `unit`; within-unit diagonal
  ## `unique()` block on the unit-observation row id.
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | unit, d = 2) +
            unique(0 + trait | unit_observation),
    data = df,
    unit = "unit"
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$rr_B),
              label = "between-unit latent (reduced-rank) block fit")
  expect_equal(dim(fit$report$Lambda_B), c(n_traits, K))

  ## Loading SHAPE recovery via Procrustes (rotation invariance built in).
  Lambda_hat <- extract_ordination(fit, level = "unit")$loadings
  expect_equal(dim(Lambda_hat), c(n_traits, K))
  proc <- compare_loadings(Lambda_hat, Lambda_B)
  for (k in seq_len(K)) {
    expect_gt(abs(proc$cor_per_factor[k]), 0.90)
  }

  ## Total between-unit Sigma off-diagonal pattern is rotation-invariant.
  Sigma_hat  <- extract_Sigma(fit, level = "unit", part = "total")$Sigma
  Sigma_true <- Lambda_B %*% t(Lambda_B)
  off_true   <- Sigma_true[lower.tri(Sigma_true)]
  off_hat    <- Sigma_hat[lower.tri(Sigma_hat)]
  expect_gt(stats::cor(off_true, off_hat), 0.90)
})
