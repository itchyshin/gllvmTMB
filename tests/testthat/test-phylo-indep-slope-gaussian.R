## Design 55 A2 + Design 56 9.5b -- phylo_indep(1 + x | sp) Gaussian recovery.
##
## Filled in (issue #341 Track B): the augmented diagonal random-slope
## engine is live (the binomial anchor test-binomial-slope-recovery.R and
## the non-Gaussian cells in test-phylo-indep-slope-nongaussian.R prove it),
## so this Gaussian anchor cell -- formerly a skip()ped Stage-3 skeleton --
## now carries a real recovery + wide/long byte-identity test. Mirrors
## tests/testthat/test-phylo-unique-slope-gaussian.R (PR #282); customised
## for the diagonal-Sigma_b case per Design 55 5.
##
## What this cell tests:
##
##   - LHS = (1 + x | sp) (wide) / (0 + trait + (0 + trait):x | sp) (long).
##   - Sigma_b is DIAGONAL per Design 56 5.3: cov(intercept, slope) = 0 is
##     the model contract (not just truth). The rho parameter (atanh_cor_b)
##     is map-pinned to zero in TMB.
##   - Recovery: sigma^2_intercept, sigma^2_slope on a seed grid (recovery
##     on the seed-mean, RE-09 within-cell replicates), plus the assertion
##     that report$cor_b is EXACTLY 0 (the model is constrained, not
##     estimating cov).
##   - Byte-identity wide vs long per Design 55 3.

skip_if_not_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
}

## Diagonal-Sigma_b Gaussian fixture: (alpha, beta) ~
## N(0, diag(0.4, 0.3) (x) A_phy), i.e. cov(intercept, slope) = 0 (the
## phylo_indep truth). Gaussian response with a small residual SD.
make_gaussian_indep_slope_fixture <- function(seed, n_sp = 60L,
                                              n_traits = 3L, n_rep = 6L,
                                              s2_int = 0.4, s2_slope = 0.3,
                                              resid_sd = 0.3) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))

  ab <- (Lphy_chol %*% matrix(stats::rnorm(n_sp * 2L), n_sp, 2L)) %*%
    chol(diag(c(s2_int, s2_slope)))
  rownames(ab) <- tree$tip.label
  colnames(ab) <- c("alpha", "beta")

  species_rep <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep)
  )
  species_rep$x <- stats::rnorm(nrow(species_rep))  # var(x) ~ 1

  trait_levels <- paste0("t", seq_len(n_traits))
  df_long <- merge(
    species_rep,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df_long <- df_long[order(df_long$species, df_long$rep, df_long$trait), ]

  mu_t <- c(2, 1, 0.5)[as.integer(df_long$trait)]
  alpha_sp <- ab[as.character(df_long$species), "alpha"]
  beta_sp <- ab[as.character(df_long$species), "beta"]
  df_long$value <- mu_t + alpha_sp + beta_sp * df_long$x +
    stats::rnorm(nrow(df_long), sd = resid_sd)

  list(df = df_long, tree = tree)
}

fit_gaussian_indep_slope <- function(formula, fx) {
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data = fx$df,
      phylo_tree = fx$tree,
      unit = "species",
      family = stats::gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    return(list(error = conditionMessage(fit)))
  }
  sd_b <- as.numeric(fit$report$sd_b)
  list(
    error = NA_character_,
    conv = fit$opt$convergence,
    pd = isTRUE(fit$fit_health$pd_hessian),
    v_int = sd_b[1L]^2,
    v_slope = sd_b[2L]^2,
    rho = as.numeric(fit$report$cor_b)[1L],
    cor_mapped = !is.null(fit$tmb_map$atanh_cor_b)
  )
}

.gauss_indep_slope_true <- list(sigma2_int = 0.4, sigma2_slope = 0.3)
## Gaussian B0 band: 0.20 relative on the seed-averaged variances (the tight
## fixed-residual-scale band, NOT widened). Calibrated on a 6-seed grid (max
## observed mean relative error ~0.14 on the slope variance).
.gauss_indep_slope_band <- 0.20

## ---------------------------------------------------------------------
## Recovery: phylo_indep(1 + x | sp) on Gaussian, diagonal Sigma_b.
## ---------------------------------------------------------------------
test_that(
  "phylo_indep(1 + x | sp) recovers sigma2_int, sigma2_slope on Gaussian; cov pinned to 0", {
  skip_if_not_heavy()
  skip_if_not_ape()

  seeds <- 1:6
  res <- lapply(seeds, function(s) {
    fit_gaussian_indep_slope(
      value ~ 0 + trait + phylo_indep(1 + x | species),
      make_gaussian_indep_slope_fixture(s)
    )
  })

  errs <- vapply(res, function(r) r$error, character(1))
  expect_true(all(is.na(errs)),
              label = sprintf("all seeds construct (got: %s)",
                              paste(stats::na.omit(errs), collapse = "; ")))

  conv <- vapply(res, function(r) r$conv, integer(1))
  pd <- vapply(res, function(r) r$pd, logical(1))
  rho <- vapply(res, function(r) r$rho, numeric(1))
  cor_mapped <- vapply(res, function(r) r$cor_mapped, logical(1))
  v_int <- vapply(res, function(r) r$v_int, numeric(1))
  v_slope <- vapply(res, function(r) r$v_slope, numeric(1))

  ## Fit health on every seed.
  expect_true(all(conv == 0L))
  expect_true(all(pd))

  ## Diagonal contract: rho map-pinned and held EXACTLY at 0.
  expect_true(all(cor_mapped))
  expect_true(all(rho == 0))

  ## Seed-averaged variance recovery within the 0.20 Gaussian band.
  int_rel <- abs(mean(v_int) - .gauss_indep_slope_true$sigma2_int) /
    .gauss_indep_slope_true$sigma2_int
  slope_rel <- abs(mean(v_slope) - .gauss_indep_slope_true$sigma2_slope) /
    .gauss_indep_slope_true$sigma2_slope
  expect_lte(int_rel, .gauss_indep_slope_band)
  expect_lte(slope_rel, .gauss_indep_slope_band)
})

## ---------------------------------------------------------------------
## Byte-identity: the wide `(1 + x | sp)` LHS and the explicit long
## `(0 + trait + (0 + trait):x | sp)` LHS rewrite to the SAME augmented
## engine inputs and produce the same fit (Design 55 3).
## ---------------------------------------------------------------------
test_that(
  "phylo_indep wide (1 + x) and long (0 + trait + (0 + trait):x) are byte-identical (Design 55)", {
  skip_if_not_heavy()
  skip_if_not_ape()

  fx <- make_gaussian_indep_slope_fixture(seed = 1L)

  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, phylo_tree = fx$tree, unit = "species",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
  )))
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + trait + (0 + trait):x | species),
    data = fx$df, phylo_tree = fx$tree, unit = "species",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
  )))

  expect_equal(fit_wide$opt$convergence, 0L)
  expect_equal(fit_long$opt$convergence, 0L)

  ## Same augmented design feeding the engine.
  expect_identical(fit_wide$tmb_data$Z_phy_aug, fit_long$tmb_data$Z_phy_aug)

  ## Same objective and recovered diagonal Sigma_b; rho pinned 0 on both.
  expect_equal(as.numeric(logLik(fit_wide)), as.numeric(logLik(fit_long)),
               tolerance = 1e-8)
  expect_equal(fit_wide$opt$objective, fit_long$opt$objective,
               tolerance = 1e-8)
  expect_equal(fit_wide$report$sd_b, fit_long$report$sd_b, tolerance = 1e-8)
  expect_equal(as.numeric(fit_wide$report$cor_b)[1L], 0)
  expect_equal(as.numeric(fit_long$report$cor_b)[1L], 0)
})
