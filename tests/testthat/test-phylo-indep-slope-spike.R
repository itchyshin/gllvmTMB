## Track B spike (Design 60 vs audit): phylo_indep(1 + x | species).
##
## Question settled here: an INDEPENDENT augmented phylogenetic random
## regression (correlated intercept+slope, but with the intercept-slope
## correlation FIXED at 0) reuses the SAME augmented `b_phy_aug` engine as
## phylo_unique() -- the only difference is that `atanh_cor_b` is pinned to 0
## via the TMB map. No new C++ likelihood block.
##
## Routing:
##   phylo_indep(1 + x | species)
##     -> parser (R/brms-sugar.R, phylo_indep handler) detects the augmented
##        LHS via .gllvmTMB_lhs_form() and rewrites to
##        phylo_slope(bar, .phylo_unique_augmented = TRUE, .indep = TRUE, ...)
##     -> fit-multi.R sets use_phylo_slope_indep and adds
##        tmb_map$atanh_cor_b <- factor(NA), holding rho = tanh(0) = 0.
##   The C++ path (src/gllvmTMB.cpp, use_phylo_slope_correlated == 1) is
##   byte-for-byte the phylo_unique augmented path; rho enters only the prior
##   (~line 593) and collapses to a block-diagonal Sigma_b when atanh_cor_b = 0.
##
## Truth: intercept SD and slope SD both nonzero, correlation = 0, phylo
## correlation = identity (star tree). ~40 species, one continuous covariate x.

skip_if_not_phylo_indep_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("tidyr")
}

make_phylo_indep_slope_fixture <- function(
  seed = 5641,
  n_sp = 40L,
  n_traits = 3L,
  n_rep = 4L
) {
  set.seed(seed)
  sp_labels <- paste0("sp", seq_len(n_sp))

  ## Identity phylogenetic correlation (star tree). Passed through the dense
  ## phylo_vcv path so the spike needs no rooted-tree dependency.
  Cphy <- diag(n_sp)
  dimnames(Cphy) <- list(sp_labels, sp_labels)

  sigma2_int_true <- 0.4
  sigma2_slope_true <- 0.3
  rho_true <- 0.0
  cov_true <- rho_true * sqrt(sigma2_int_true * sigma2_slope_true)
  Sigma_b_true <- matrix(
    c(sigma2_int_true, cov_true, cov_true, sigma2_slope_true),
    nrow = 2L,
    ncol = 2L
  )

  ## chol(identity) = identity, so the species effects are drawn directly.
  raw <- matrix(stats::rnorm(n_sp * 2L), nrow = n_sp, ncol = 2L)
  ab <- raw %*% chol(Sigma_b_true)
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- sp_labels

  species_rep <- expand.grid(
    species = factor(sp_labels, levels = sp_labels),
    rep = seq_len(n_rep)
  )
  species_rep$x <- stats::rnorm(nrow(species_rep))

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
    stats::rnorm(nrow(df_long), sd = 0.3)

  df_wide <- tidyr::pivot_wider(
    df_long,
    id_cols = c(species, rep, x),
    names_from = trait,
    values_from = value
  )
  df_wide <- as.data.frame(df_wide, stringsAsFactors = FALSE)

  list(
    df_long = df_long,
    df_wide = df_wide,
    Cphy = Cphy,
    sigma2_int_true = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true = rho_true
  )
}

fit_phylo_indep_slope_long <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_indep(0 + trait + (0 + trait):x | species),
    data = fx$df_long,
    phylo_vcv = fx$Cphy,
    unit = "species",
    control = ctl
  )))
}

fit_phylo_indep_slope_wide <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(t1, t2, t3) ~ 1 + phylo_indep(1 + x | species),
    data = fx$df_wide,
    phylo_vcv = fx$Cphy,
    unit = "species",
    control = ctl
  )))
}

test_that("phylo_indep augmented routes to b_phy_aug with atanh_cor_b pinned (no C++)", {
  skip_if_not_heavy()
  skip_if_not_phylo_indep_slope_deps()

  fx <- make_phylo_indep_slope_fixture()
  fit <- fit_phylo_indep_slope_long(fx)

  ## Fits without error and is healthy.
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_lt(fit$fit_health$max_gradient, 1e-2)
  expect_true(isTRUE(fit$fit_health$pd_hessian))
  expect_true(isTRUE(fit$fit_health$sdreport_ok))

  ## Routed through the augmented engine (two LHS columns, b_phy_aug random).
  expect_equal(fit$tmb_data$n_lhs_cols, 2L)
  expect_true("b_phy_aug" %in% fit$tmb_obj$env$.random)
  expect_length(as.numeric(fit$report$sd_b), 2L)

  ## The correlation is PINNED, not estimated: atanh_cor_b sits in the map as
  ## NA (held) and is absent from the optimised parameter vector.
  expect_true("atanh_cor_b" %in% names(fit$tmb_map))
  expect_true(all(is.na(fit$tmb_map$atanh_cor_b)))
  expect_false("atanh_cor_b" %in% names(fit$opt$par))
  expect_equal(as.numeric(fit$report$cor_b), 0, tolerance = 1e-10)
})

test_that("phylo_indep augmented Gaussian recovers both SDs with correlation pinned at 0", {
  skip_if_not_heavy()
  skip_if_not_phylo_indep_slope_deps()

  fx <- make_phylo_indep_slope_fixture()
  fit <- fit_phylo_indep_slope_long(fx)

  sd_b <- as.numeric(fit$report$sd_b)
  sigma2_int_hat <- sd_b[1L]^2
  sigma2_slope_hat <- sd_b[2L]^2

  ## Recover both variance components within 20% relative error (the same band
  ## the validated phylo_unique augmented Gaussian test uses).
  expect_lte(
    abs(sigma2_int_hat - fx$sigma2_int_true) / fx$sigma2_int_true,
    0.20
  )
  expect_lte(
    abs(sigma2_slope_hat - fx$sigma2_slope_true) / fx$sigma2_slope_true,
    0.20
  )

  ## Correlation stays exactly at the pinned value.
  expect_equal(as.numeric(fit$report$cor_b), fx$rho_true, tolerance = 1e-10)
})

test_that("phylo_indep wide and long augmented surfaces are byte-identical", {
  skip_if_not_heavy()
  skip_if_not_phylo_indep_slope_deps()

  fx <- make_phylo_indep_slope_fixture()
  fit_long <- fit_phylo_indep_slope_long(fx)
  fit_wide <- fit_phylo_indep_slope_wide(fx)

  expect_equal(fit_wide$opt$objective, fit_long$opt$objective, tolerance = 1e-8)
  expect_identical(fit_wide$tmb_data$Z_phy_aug, fit_long$tmb_data$Z_phy_aug)
  expect_equal(fit_wide$report$sd_b, fit_long$report$sd_b, tolerance = 1e-8)
  expect_equal(as.numeric(fit_wide$report$cor_b), 0, tolerance = 1e-10)
})
