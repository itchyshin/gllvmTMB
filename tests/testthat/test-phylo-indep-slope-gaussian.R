## Design 79/80 (supersedes Design 56 5.3) -- phylo_indep(1 + x | sp) Gaussian
## recovery.
##
## Design 79/80 redefines what phylo_indep(1 + x | sp) fits. It USED to fit a
## single SHARED 2x2 (intercept, slope) block across all traits with the
## intercept-slope correlation PINNED to 0 (2 free params: log_sd_b,
## atanh_cor_b mapped off). It NOW fits T INDEPENDENT per-trait 2x2 blocks:
## Sigma_b is BLOCK-DIAGONAL with T blocks, each block holding a trait's own
## (intercept variance, slope variance, intercept-slope covariance), with the
## correlation ESTIMATED per trait and cross-trait covariance structurally
## zero. This is "T stacked univariate random regressions," not one shared
## diagonal block. Engine path: `phylo_indep(1 + x | sp)` desugars to
## `phylo_slope(1 + x | sp, .phylo_dep_augmented = TRUE,
## .indep_blockdiag = TRUE, ...)` -- the same (1+s)T-wide `theta_dep_chol`
## engine as `phylo_dep()`, but with the cross-block strictly-lower Cholesky
## entries pinned to 0 (`dep_chol_crossblock_pins()`), so `Sigma_b = L L^T`
## is block-lower-triangular -> block-diagonal. Free `theta_dep_chol` count
## is `3 * n_traits` (3 per trait: two diagonal entries + one within-block
## off-diagonal), not the old `2` shared parameters.
##
## What this cell tests:
##
##   - LHS = (1 + x | sp) (wide) / (0 + trait + (0 + trait):x | sp) (long).
##   - Sigma_b is BLOCK-DIAGONAL per Design 79/80: T independent (intercept,
##     slope) 2x2 blocks, each with its own freely estimated correlation.
##     Cross-trait covariance is structurally zero (via the Cholesky pins),
##     NOT the old "correlation pinned to 0 within a single shared block."
##   - Structural, non-flaky assertions: free `theta_dep_chol` count is
##     exactly `3 * n_traits`; cross-trait `cor_b_mat` entries are ~0 (< 1e-6);
##     the within-block intercept-slope correlation is genuinely ESTIMATED
##     (correct sign, |rho| exceeding a small threshold for the two traits
##     simulated with a real correlation), not pinned to 0.
##   - Recovery: seed-averaged per-trait variances within a generous relative
##     band (noisy at moderate n; banded and averaged over a seed grid per
##     RE-09 discipline).
##   - Byte-identity wide vs long per Design 55 3 (same engine inputs, same
##     objective, same `sd_b` / `cor_b_mat`) -- WITHOUT the old `cor_b == 0`
##     assertions (correlations are now free -- and equal across wide/long --
##     not pinned to 0).

skip_if_not_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
}

## Block-diagonal Gaussian fixture (Design 79/80): T INDEPENDENT per-trait
## 2x2 (intercept, slope) blocks G_t = [[s2_int_t, cov_t], [cov_t,
## s2_slope_t]], each with its OWN correlation `rho_t` (distinct across
## traits, two of them clearly non-zero with opposite signs, one left at 0 as
## a null case). Per trait: (alpha_t, beta_t)[species] ~ N(0, G_t (x) A_phy),
## drawn as `L_A %*% Z_t %*% chol(G_t)` (Kronecker-structure trick: A_phy
## enters via the left phylogenetic Cholesky factor, G_t via the right
## trait-block Cholesky factor). Traits are otherwise independent draws, so
## the true Sigma_b (2T x 2T, ordered [int_t1, slope_t1, int_t2, slope_t2,
## ...]) is exactly block-diagonal by construction.
make_gaussian_indep_slope_fixture <- function(
  seed, n_sp = 80L, n_traits = 3L, n_rep = 8L,
  s2_int = c(0.4, 0.6, 0.3), s2_slope = c(0.3, 0.5, 0.2),
  rho = c(0.45, -0.4, 0.0), resid_sd = 0.3
) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))

  blocks <- lapply(seq_len(n_traits), function(t) {
    cov_t <- rho[t] * sqrt(s2_int[t] * s2_slope[t])
    matrix(c(s2_int[t], cov_t, cov_t, s2_slope[t]), 2L, 2L)
  })
  ab_list <- lapply(seq_len(n_traits), function(t) {
    Zt <- matrix(stats::rnorm(n_sp * 2L), n_sp, 2L)
    m <- Lphy_chol %*% Zt %*% chol(blocks[[t]])
    rownames(m) <- tree$tip.label
    colnames(m) <- c("alpha", "beta")
    m
  })

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
  ti <- as.integer(df_long$trait)
  alpha_mat <- sapply(seq_len(n_traits), function(t)
    ab_list[[t]][as.character(df_long$species), "alpha"])
  beta_mat <- sapply(seq_len(n_traits), function(t)
    ab_list[[t]][as.character(df_long$species), "beta"])
  idx <- cbind(seq_len(nrow(df_long)), ti)
  df_long$value <- mu_t + alpha_mat[idx] + beta_mat[idx] * df_long$x +
    stats::rnorm(nrow(df_long), sd = resid_sd)

  list(df = df_long, tree = tree, n_traits = n_traits,
       s2_int = s2_int, s2_slope = s2_slope, rho = rho)
}

## Cross-BLOCK (not cross-diagonal) max abs correlation: block_size = 2
## (intercept, slope) per trait. Excludes within-block entries (which carry
## the freely estimated per-trait rho), so this isolates the block-diagonal
## structural constraint.
.max_cross_block_cor <- function(cor_mat, block_size = 2L) {
  C <- nrow(cor_mat)
  blk <- (seq_len(C) - 1L) %/% block_size
  mask <- outer(blk, blk, `!=`)
  if (!any(mask)) return(0)
  max(abs(cor_mat[mask]))
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
  C <- length(sd_b)
  cor_mat <- matrix(as.numeric(fit$report$cor_b_mat), C, C)
  n_traits <- C %/% 2L
  int_idx <- seq(1L, C, by = 2L)
  slope_idx <- seq(2L, C, by = 2L)
  rho_hat <- vapply(seq_len(n_traits), function(t) cor_mat[2L * t - 1L, 2L * t],
                     numeric(1))
  list(
    error = NA_character_,
    conv = fit$opt$convergence,
    pd = isTRUE(fit$fit_health$pd_hessian),
    n_free_dep = sum(names(fit$opt$par) == "theta_dep_chol"),
    max_cross_block = .max_cross_block_cor(cor_mat),
    v_int = sd_b[int_idx]^2,
    v_slope = sd_b[slope_idx]^2,
    rho_hat = rho_hat,
    sd_b = sd_b,
    cor_mat = cor_mat
  )
}

.gauss_indep_slope_true <- list(
  s2_int = c(0.4, 0.6, 0.3),
  s2_slope = c(0.3, 0.5, 0.2),
  rho = c(0.45, -0.4, 0.0)
)
## Gaussian recovery band: 0.30 relative on the seed-averaged per-trait
## variances (6-seed grid, n_sp = 80, n_rep = 8). Calibrated on a live probe:
## max observed |mean - truth| / truth ~ 0.20 across the 3 traits x 2
## (intercept, slope) cells, so 0.30 carries a comfortable margin without
## being trivial. The within-block correlation sign/magnitude check below is
## the meaningful "correlation is estimated, not pinned" gate; the variance
## band is secondary recovery evidence.
.gauss_indep_slope_band <- 0.30
## Correlation "estimated, not pinned" threshold: seed-averaged |rho_hat|
## for the two strongly-correlated traits (true rho = +0.45, -0.4) must
## clear this magnitude with the correct sign. 0.1 is far below the true
## values and far above the pinned-at-0 null the old contract asserted.
.gauss_indep_slope_rho_floor <- 0.1

## ---------------------------------------------------------------------
## Recovery + structure: phylo_indep(1 + x | sp), block-diagonal Sigma_b.
## ---------------------------------------------------------------------
test_that(
  paste(
    "phylo_indep(1 + x | sp) fits T independent per-trait blocks:",
    "cross-trait cor ~ 0, within-trait cor estimated, variances recovered"
  ), {
  skip_if_not_heavy()
  skip_if_not_ape()

  seeds <- 1:6
  fx_list <- lapply(seeds, make_gaussian_indep_slope_fixture)
  n_traits <- fx_list[[1L]]$n_traits
  res <- lapply(fx_list, function(fx) {
    fit_gaussian_indep_slope(
      value ~ 0 + trait + phylo_indep(1 + x | species),
      fx
    )
  })

  errs <- vapply(res, function(r) r$error, character(1))
  expect_true(all(is.na(errs)),
              label = sprintf("all seeds construct (got: %s)",
                              paste(stats::na.omit(errs), collapse = "; ")))

  conv <- vapply(res, function(r) r$conv, integer(1))
  pd <- vapply(res, function(r) r$pd, logical(1))
  n_free_dep <- vapply(res, function(r) r$n_free_dep, integer(1))
  max_cross_block <- vapply(res, function(r) r$max_cross_block, numeric(1))

  ## Fit health on every seed.
  expect_true(all(conv == 0L))
  expect_true(all(pd))

  ## STRUCTURAL (exact, non-flaky): free theta_dep_chol == 3 * n_traits on
  ## every seed -- 3 per trait (2 diagonal + 1 within-block off-diagonal),
  ## the T-independent-blocks parameter count, not the old shared-block 2.
  expect_true(all(n_free_dep == 3L * n_traits))

  ## STRUCTURAL (exact, non-flaky): cross-trait correlations are ~0 on every
  ## seed -- the block-diagonal constraint from the Cholesky cross-block pins.
  expect_true(all(max_cross_block < 1e-6))

  ## STRUCTURAL (seed-averaged for stability): the within-block intercept-
  ## slope correlation is genuinely ESTIMATED, not pinned to 0. Trait 1 (true
  ## rho = +0.45) and trait 2 (true rho = -0.4) must recover the correct sign
  ## with |rho| clearly away from 0; trait 3 (true rho = 0) is the null case
  ## and is NOT asserted on sign (averaging noise around 0 is expected).
  rho_hat_mat <- do.call(rbind, lapply(res, function(r) r$rho_hat))
  mean_rho <- colMeans(rho_hat_mat)
  expect_gt(mean_rho[1L], .gauss_indep_slope_rho_floor)
  expect_lt(mean_rho[2L], -.gauss_indep_slope_rho_floor)

  ## RECOVERY: seed-averaged per-trait variances within the 0.30 relative band.
  v_int_mat <- do.call(rbind, lapply(res, function(r) r$v_int))
  v_slope_mat <- do.call(rbind, lapply(res, function(r) r$v_slope))
  int_rel <- abs(colMeans(v_int_mat) - .gauss_indep_slope_true$s2_int) /
    .gauss_indep_slope_true$s2_int
  slope_rel <- abs(colMeans(v_slope_mat) - .gauss_indep_slope_true$s2_slope) /
    .gauss_indep_slope_true$s2_slope
  expect_true(all(int_rel <= .gauss_indep_slope_band))
  expect_true(all(slope_rel <= .gauss_indep_slope_band))
})

## ---------------------------------------------------------------------
## Byte-identity: the wide `(1 + x | sp)` LHS and the explicit long
## `(0 + trait + (0 + trait):x | sp)` LHS rewrite to the SAME augmented
## engine inputs and produce the same fit (Design 55 3). Correlations are
## now FREE (not pinned to 0), so the check is that wide and long recover
## the SAME cor_b_mat, not that it is exactly 0.
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

  ## Same objective and recovered block-diagonal Sigma_b (sd_b + full
  ## cor_b_mat, including the now-free within-block correlations) on both.
  expect_equal(as.numeric(logLik(fit_wide)), as.numeric(logLik(fit_long)),
               tolerance = 1e-8)
  expect_equal(fit_wide$opt$objective, fit_long$opt$objective,
               tolerance = 1e-8)
  expect_equal(fit_wide$report$sd_b, fit_long$report$sd_b, tolerance = 1e-8)
  expect_equal(fit_wide$report$cor_b_mat, fit_long$report$cor_b_mat,
               tolerance = 1e-8)
})
