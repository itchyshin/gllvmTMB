## Phase B-tiers: Gamma(link = "log") x grouping-tier recovery.
##
## Validates that the `unit_obs` (within-unit OLRE) and `cluster`
## (third-slot) grouping tiers recover their per-trait variances under a
## Gamma response with a log link. Both tiers are family-agnostic at the
## prior level (the family enters only at the response-likelihood node,
## after eta accumulates the random-effect contributions; see
## docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md S1), so
## the question this file answers is empirical: does Gamma x tier converge
## to a positive-definite Hessian and recover the simulated SDs?
##
## DGP convention (both tests):
##   * log link, gamma shape phi = 2 -> CV = 1 / sqrt(phi) = 0.7071.
##   * gamma CV is stored in `sigma_eps` (there is NO separate phi_gamma
##     slot in the engine). For the CV to be identifiable the data need
##     within-cell replicates: with one observation per finest cell the
##     OLRE / tier variance and the gamma CV both try to explain the same
##     within-cell spread and the CV collapses. Every fixture below puts
##     several replicate rows in each finest (trait x grouping) cell.
##   * log-scale intercept 0 -> conditional median exp(0) = 1; the
##     marginal mean is a touch above 1 because the random effects enter
##     log-normally (E[exp(b)] > 1), i.e. mean(y) ~ 1.2. "mean ~ 1" is
##     meant on the conditional / median scale.
##   * 3 traits throughout.
##
## Recovery is checked on the SD scale via the engine's canonical reports
## (`fit$report$sd_B`, `sd_W`, `sd_q`); `extract_Sigma(part = "unique")$s`
## returns those same quantities squared (variance scale) and is used for
## a structural cross-check.

## ---- 1. unit_obs tier: between-unit (sd_B) + within-unit OLRE (sd_W) -------

test_that("Gamma x unit_obs: two-tier unique() converges (PD) and separates sd_B / sd_W", {
  skip_on_cran()

  ## Two crossed unique() tiers on a unit / unit_obs hierarchy:
  ##   unique(0 + trait | unit)     -> between-unit variance  (sd_B)
  ##   unique(0 + trait | unit_obs) -> within-unit OLRE       (sd_W)
  ## Each unit_obs cell carries `n_rep` replicate rows per trait so the
  ## gamma CV (sigma_eps) is identified from the within-cell spread and
  ## the OLRE sits at the cell (not per-row) level. Gamma x OLRE is the
  ## hard combination flagged in the Phase B0 audit; here it is PD.
  set.seed(101)

  n_unit  <- 80L   # many units -> sd_B estimable
  n_cell  <- 4L    # unit_obs cells per unit
  n_rep   <- 4L    # replicate rows per (trait, unit_obs) cell -> CV identified
  Tn      <- 3L
  trait_names <- c("a", "b", "c")

  true_sd_B <- c(0.5, 0.6, 0.4)    # between-unit per-trait SD
  true_sd_W <- c(0.3, 0.45, 0.55)  # within-unit (OLRE) per-trait SD
  phi       <- 2                   # gamma shape
  cv_true   <- 1 / sqrt(phi)       # 0.7071

  rows <- expand.grid(
    rep_id    = seq_len(n_rep),
    cell      = seq_len(n_cell),
    unit_i    = seq_len(n_unit),
    trait_idx = seq_len(Tn)
  )
  rows$unit     <- factor(rows$unit_i)
  rows$unit_obs <- factor(paste(rows$unit_i, rows$cell, sep = "_"))
  rows$trait    <- factor(trait_names[rows$trait_idx], levels = trait_names)

  unit_lv <- levels(rows$unit)
  cell_lv <- levels(rows$unit_obs)
  b_unit <- matrix(0, length(unit_lv), Tn)
  w_cell <- matrix(0, length(cell_lv), Tn)
  for (t in seq_len(Tn)) {
    b_unit[, t] <- rnorm(length(unit_lv), sd = true_sd_B[t])
    w_cell[, t] <- rnorm(length(cell_lv), sd = true_sd_W[t])
  }
  ui <- match(as.character(rows$unit), unit_lv)
  ci <- match(as.character(rows$unit_obs), cell_lv)
  ## log-scale intercept 0 -> mu = exp(b_unit + w_cell); median ~ 1.
  eta <- b_unit[cbind(ui, rows$trait_idx)] + w_cell[cbind(ci, rows$trait_idx)]
  rows$value <- rgamma(nrow(rows), shape = phi, scale = exp(eta) / phi)

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
            unique(0 + trait | unit) +
            unique(0 + trait | unit_obs),
    data     = rows,
    unit     = "unit",
    unit_obs = "unit_obs",
    family   = Gamma(link = "log")
  )))

  ## --- convergence + positive-definite Hessian ---------------------------
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess),
              label = "Gamma x unit_obs OLRE: joint Hessian is positive definite")
  expect_equal(fit$tmb_data$family_id_vec[1], 4L)  # Gamma == family_id 4

  ## --- both tiers are actually fit --------------------------------------
  expect_true(isTRUE(fit$use$diag_B), label = "unit-tier diag fit")
  expect_true(isTRUE(fit$use$diag_W), label = "unit_obs-tier diag (OLRE) fit")

  ## --- recover BOTH tier variances (SD scale, +/- 0.2) ------------------
  sd_B <- as.numeric(fit$report$sd_B)
  sd_W <- as.numeric(fit$report$sd_W)
  expect_equal(length(sd_B), Tn)
  expect_equal(length(sd_W), Tn)
  for (t in seq_len(Tn)) {
    expect_equal(sd_B[t], true_sd_B[t], tolerance = 0.2,
                 label = paste0("sd_B[", t, "] (between-unit)"))
    expect_equal(sd_W[t], true_sd_W[t], tolerance = 0.2,
                 label = paste0("sd_W[", t, "] (within-unit OLRE)"))
  }

  ## --- gamma CV (sigma_eps) recovered: identified by within-cell reps ---
  cv_hat <- as.numeric(fit$report$sigma_eps)
  expect_equal(cv_hat, cv_true, tolerance = 0.1,
               label = "gamma CV stored in sigma_eps")

  ## --- tiers separate: traits where the two true SDs differ are each
  ##     recovered closer to their OWN tier's truth than to the other's.
  ##     (Trait 'a' has sd_B = 0.5 vs sd_W = 0.3; trait 'c' has
  ##      sd_B = 0.4 vs sd_W = 0.55 -- both well separated.)
  for (t in c(1L, 3L)) {
    expect_lt(abs(sd_B[t] - true_sd_B[t]), abs(sd_B[t] - true_sd_W[t]),
              label = paste0("sd_B[", t, "] nearer its own tier than the OLRE tier"))
    expect_lt(abs(sd_W[t] - true_sd_W[t]), abs(sd_W[t] - true_sd_B[t]),
              label = paste0("sd_W[", t, "] nearer its own tier than the unit tier"))
  }

  ## --- extract_Sigma() cross-check: $s is the variance (SD^2) ------------
  s_unit <- extract_Sigma(fit, level = "unit",     part = "unique")$s
  s_uobs <- suppressMessages(
    extract_Sigma(fit, level = "unit_obs", part = "unique")$s
  )
  expect_equal(unname(s_unit), sd_B^2, tolerance = 1e-6)
  expect_equal(unname(s_uobs), sd_W^2, tolerance = 1e-6)
})


## ---- 2. cluster tier: third-slot unique() variance (sd_q) -----------------

test_that("Gamma x cluster: third-slot unique() converges (PD) and recovers sd_q", {
  skip_on_cran()

  ## Strictly-nested 3-level fixture: cluster > unit > unit_obs, one
  ## per-trait random effect at the cluster level:
  ##   unique(0 + trait | cluster)  -> cluster-tier variance (sd_q)
  ## unit_obs carries `n_obs_per` replicate cells per unit so the gamma CV
  ## is identified within cell. Many clusters (80) make sd_q estimable.
  set.seed(202)

  n_cluster  <- 80L  # many clusters -> sd_q estimable
  n_unit_per <- 4L   # units per cluster
  n_obs_per  <- 4L   # unit_obs cells per unit -> within-cell replication
  Tn         <- 3L
  trait_names <- c("a", "b", "c")

  true_sd_q <- c(0.5, 0.7, 0.4)   # cluster-tier per-trait SD
  phi       <- 2                  # gamma shape
  cv_true   <- 1 / sqrt(phi)      # 0.7071

  rows <- expand.grid(
    obs       = seq_len(n_obs_per),
    unit_j    = seq_len(n_unit_per),
    clus      = seq_len(n_cluster),
    trait_idx = seq_len(Tn)
  )
  rows$cluster  <- factor(rows$clus)
  rows$unit     <- factor(paste(rows$clus, rows$unit_j, sep = "_"))
  rows$unit_obs <- factor(paste(rows$clus, rows$unit_j, rows$obs, sep = "_"))
  rows$trait    <- factor(trait_names[rows$trait_idx], levels = trait_names)

  clus_lv <- levels(rows$cluster)
  q_clus  <- matrix(0, length(clus_lv), Tn)
  for (t in seq_len(Tn)) {
    q_clus[, t] <- rnorm(length(clus_lv), sd = true_sd_q[t])
  }
  ci  <- match(as.character(rows$cluster), clus_lv)
  eta <- q_clus[cbind(ci, rows$trait_idx)]
  rows$value <- rgamma(nrow(rows), shape = phi, scale = exp(eta) / phi)

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | cluster),
    data     = rows,
    unit     = "unit",
    unit_obs = "unit_obs",
    cluster  = "cluster",
    family   = Gamma(link = "log")
  )))

  ## --- convergence + positive-definite Hessian ---------------------------
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess),
              label = "Gamma x cluster: joint Hessian is positive definite")
  expect_equal(fit$tmb_data$family_id_vec[1], 4L)  # Gamma == family_id 4

  ## --- cluster argument honoured, third-slot diag lit ------------------
  expect_equal(fit$cluster_col, "cluster")
  expect_true(isTRUE(fit$use$diag_species),
              label = "cluster-tier diag (sd_q) fit")

  ## --- recover cluster variance (SD scale, +/- 0.2) ---------------------
  sd_q <- as.numeric(fit$report$sd_q)
  expect_equal(length(sd_q), Tn)
  for (t in seq_len(Tn)) {
    expect_equal(sd_q[t], true_sd_q[t], tolerance = 0.2,
                 label = paste0("sd_q[", t, "] (cluster tier)"))
  }

  ## --- gamma CV (sigma_eps) recovered -----------------------------------
  cv_hat <- as.numeric(fit$report$sigma_eps)
  expect_equal(cv_hat, cv_true, tolerance = 0.1,
               label = "gamma CV stored in sigma_eps")

  ## --- extract_Sigma() cross-check at level = "cluster": $s = sd_q^2 ----
  s_clus <- suppressMessages(
    extract_Sigma(fit, level = "cluster", part = "unique")$s
  )
  expect_equal(length(s_clus), Tn)
  expect_equal(unname(s_clus), sd_q^2, tolerance = 1e-6)
})
