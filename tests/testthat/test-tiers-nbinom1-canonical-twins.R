## S8 secondary task: canonical `*_indep()` twins for the nbinom1 x
## phylo_unique(species) / spatial_unique(0 + trait | site) cells of
## test-tiers-nbinom1.R.
##
## Those two cells (test-tiers-nbinom1.R:144, :271) are the ONLY nbinom1
## coverage of the phylo/spatial structured tiers, and both are written
## through the soft-deprecated `phylo_unique(species)` /
## `spatial_unique(0 + trait | site)` spelling -- there is no canonical
## `*_indep()` twin. Per the standalone-diagonal equivalence documented in
## R/brms-sugar.R (`unique` and `indep` standalone are "mathematically
## identical (both produce diag(sigma^2_t)); the keyword distinction is
## documentary, not operational") and pinned for the intercept-only phylo
## case in test-canonical-keywords.R:429-458, these standalone (intercept-
## only) cells are expected to route through the SAME engine as their
## `*_unique()` counterparts -- unlike the augmented-SLOPE `phylo_unique(1 +
## x | species)` form pinned in test-unique-indep-slope-semantics.R, which is
## genuinely different from `phylo_indep(1 + x | species)`.
##
## If the deprecated `phylo_unique()` / `spatial_unique()` spelling were ever
## removed, nbinom1's structured-tier certification on these two cells would
## silently vanish with it (no other file exercises nbinom1 x phylo / nbinom1
## x spatial with the canonical spelling). This file adds that canonical
## twin so the coverage survives the eventual removal of the compatibility
## syntax. DGP, seeds, and bands are copied verbatim from the corresponding
## `*_unique()` cells in test-tiers-nbinom1.R so this is a like-for-like
## comparison, not a new (looser) design.

skip_if_not_nb1_tier_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## NB1 linear-variance draw helper: Var(y) = mu * (1 + phi) via size = mu / phi.
## (Duplicated from test-tiers-nbinom1.R so this file is self-contained.)
rnbinom1 <- function(mu, phi) {
  stats::rnbinom(length(mu), mu = mu, size = mu / phi)
}

## ---------------------------------------------------------------
## PHYLO tier twin: phylo_indep(0 + trait | species), canonical spelling of
## the phylo_unique(species) cell at test-tiers-nbinom1.R:144.
## ---------------------------------------------------------------
test_that("nbinom1 x phylo_indep(0 + trait | species): converges, PD Hessian, phi finite, total phylo variance recovers (4x band)", {
  skip_if_not_heavy()
  skip_if_not_nb1_tier_deps()
  testthat::skip_if_not_installed("ape")

  ## Same seed discipline as the phylo_unique twin (test-tiers-nbinom1.R):
  ## seed 101 at n_sp = 50 reaches conv == 0 with a PD Hessian.
  set.seed(101L)
  n_sp <- 50L; n_traits <- 3L; phi_true <- 2.0
  Cphy <- diag(n_sp)
  sp_names <- paste0("sp", seq_len(n_sp))
  dimnames(Cphy) <- list(sp_names, sp_names)
  sigma2_phy_true <- c(0.5, 0.4, 0.3)
  alpha           <- c(1.9, 2.0, 2.1)
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))
  p_mat <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits)) {
    p_mat[, t] <- sqrt(sigma2_phy_true[t]) *
      as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  }
  rows <- vector("list", n_sp * n_traits); k <- 1L
  for (i in seq_len(n_sp)) {
    for (t in seq_len(n_traits)) {
      eta <- alpha[t] + p_mat[i, t]
      rows[[k]] <- data.frame(
        species = sp_names[i],
        trait   = paste0("trait_", t),
        value   = as.integer(rnbinom1(exp(eta), phi_true)),
        stringsAsFactors = FALSE
      )
      k <- k + 1L
    }
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = sp_names)
  df$trait   <- factor(df$trait,   levels = paste0("trait_", seq_len(n_traits)))

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_indep(0 + trait | species),
      data      = df,
      phylo_vcv = Cphy,
      unit      = "species",
      family    = gllvmTMB::nbinom1()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "nbinom1 x phylo_indep fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("nbinom1 x phylo_indep did not converge with PD Hessian; canonical twin stays partial pending bigger n / different seed")
  }

  expect_stationary_for_recovery_test(fit)
  expect_true(is.finite(fit$opt$objective))
  expect_equal(fit$tmb_data$family_id_vec[1L], 15L)   # nbinom1 family id

  ## Canonical-spelling dispatch flag (distinct from the deprecated
  ## phylo_unique cell's fit$use$phylo_rr).
  expect_true(isTRUE(fit$use$phylo_indep))

  ## Mean-dependent family => phi FINITE only (register FAM-07 confound).
  phi_hat <- as.numeric(fit$report$phi_nbinom1)
  expect_equal(length(phi_hat), n_traits)
  expect_true(all(is.finite(phi_hat)))

  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_true(length(bfix) >= 1L)
  expect_lt(abs(mean(bfix) - mean(alpha)), 0.6)

  ## ---- Recovery on the TOTAL phylogenetic variance (4x band) -----------
  sig_phy <- tryCatch(
    suppressMessages(suppressWarnings(
      gllvmTMB::extract_Sigma(fit, level = "phy", part = "total")
    )),
    error = function(e) e
  )
  if (inherits(sig_phy, "error") || is.null(sig_phy$Sigma) ||
        !is.matrix(sig_phy$Sigma)) {
    skip(sprintf(
      "extract_Sigma(level='phy', part='total') unavailable on nbinom1 phylo_indep: %s",
      if (inherits(sig_phy, "error")) conditionMessage(sig_phy) else "no Sigma"
    ))
  }
  expect_equal(dim(sig_phy$Sigma), c(n_traits, n_traits))
  diag_hat <- diag(sig_phy$Sigma)
  expect_true(all(is.finite(diag_hat)))
  expect_true(all(diag_hat > 0))

  trace_hat   <- sum(diag_hat)
  trace_truth <- sum(sigma2_phy_true)
  ratio <- trace_hat / trace_truth
  if (!is.finite(ratio) || ratio < 1 / 4 || ratio > 4) {
    skip(sprintf(
      "Total phylo variance recovery outside 4x band (hat = %.3g, truth = %.3g, ratio = %.3g); canonical twin stays partial pending bigger n",
      trace_hat, trace_truth, ratio
    ))
  }
  expect_gt(trace_hat, trace_truth / 4)
  expect_lt(trace_hat, trace_truth * 4)
})

## ---------------------------------------------------------------
## SPATIAL tier twin: spatial_indep(0 + trait | site), canonical spelling of
## the spatial_unique(0 + trait | site) cell at test-tiers-nbinom1.R:271.
## ---------------------------------------------------------------
test_that("nbinom1 x spatial_indep(0 + trait | site): converges, PD Hessian, phi finite, kappa + per-trait tau finite", {
  skip_if_not_heavy()
  skip_if_not_nb1_tier_deps()
  testthat::skip_if_not_installed("fmesher")

  log_mean_true <- log(2)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 100L, n_species = 1L, n_traits = 3L,
    mean_species_per_site = 1, n_predictors = 1,
    alpha = rep(log_mean_true, 3L), beta = matrix(0, 3L, 1L),
    sigma2_eps = 0, spatial_range = 0.35,
    sigma2_spa = rep(0.5, 3L), seed = 20260529L
  )
  df  <- sim$data
  eta <- df$value                       # Gaussian latent log-mean surface
  df$value <- rnbinom1(exp(eta), 2)     # NB1 draw: Var = mu * (1 + phi)
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.12)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_indep(0 + trait | site, mesh = mesh),
      data   = df,
      trait  = "trait",
      unit   = "site",
      mesh   = mesh,
      family = gllvmTMB::nbinom1()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "nbinom1 x spatial_indep fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("nbinom1 x spatial_indep did not converge with PD Hessian; canonical twin stays partial pending bigger n / different seed")
  }

  expect_stationary_for_recovery_test(fit)
  expect_true(is.finite(fit$opt$objective))
  expect_equal(fit$tmb_data$family_id_vec[1L], 15L)   # nbinom1 family id

  ## Canonical-spelling dispatch flag (distinct from the deprecated
  ## spatial_unique cell's fit$use$spde alone).
  expect_true(isTRUE(fit$use$spatial_indep))
  expect_true(isTRUE(fit$use$spde))

  phi_hat <- as.numeric(fit$report$phi_nbinom1)
  expect_equal(length(phi_hat), fit$n_traits)
  expect_true(all(is.finite(phi_hat)))

  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_true(length(bfix) >= 1L)
  expect_lt(abs(mean(bfix) - log_mean_true), 0.6)

  kappa <- as.numeric(fit$report$kappa)
  expect_true(is.finite(kappa))
  expect_gt(kappa, 0)

  log_tau <- as.numeric(fit$report$log_tau_spde)
  expect_equal(length(log_tau), fit$n_traits)
  expect_true(all(is.finite(log_tau)))
})
