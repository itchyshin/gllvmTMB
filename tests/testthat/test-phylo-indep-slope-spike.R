## Track B spike (Design 60 vs audit): phylo_indep(1 + x | species).
##
## Question settled here: an INDEPENDENT augmented phylogenetic random
## regression uses one intercept/slope block per trait. The implementation
## reuses the augmented `b_phy_aug` dependent engine, with cross-trait
## Cholesky entries fixed to zero; each trait's intercept--slope correlation
## remains estimable. No new C++ likelihood block.
##
## Routing:
##   phylo_indep(1 + x | species)
##     -> parser (R/brms-sugar.R, phylo_indep handler) detects the augmented
##        LHS via .gllvmTMB_lhs_form() and rewrites to
##        phylo_slope(bar, .phylo_unique_augmented = TRUE, .indep = TRUE, ...)
##     -> fit-multi.R sets use_phylo_slope_indep and maps the cross-trait
##        Cholesky entries to NA.
##   The C++ path (src/gllvmTMB.cpp, use_phylo_slope_correlated == 1) is
##   byte-for-byte the phylo_unique augmented path; the map fixes only
##   cross-trait entries, yielding a per-trait block-diagonal Sigma_b.
##
## Truth: each trait has an independent intercept/slope block with both SDs
## nonzero and within-trait correlation = 0. The phylogenetic correlation is
## identity (star tree). ~40 species, one continuous covariate x.

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

  ## The fitted model is I_T x Sigma_b: draw one independent (alpha, beta)
  ## block per trait. chol(identity) = identity across species.
  ab <- matrix(NA_real_, nrow = n_sp, ncol = 2L * n_traits)
  for (t in seq_len(n_traits)) {
    cols <- c(2L * t - 1L, 2L * t)
    raw_t <- matrix(stats::rnorm(n_sp * 2L), nrow = n_sp, ncol = 2L)
    ab[, cols] <- raw_t %*% chol(Sigma_b_true)
  }
  colnames(ab) <- as.vector(rbind(
    paste0("alpha_", seq_len(n_traits)),
    paste0("beta_", seq_len(n_traits))
  ))
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

  trait_idx <- as.integer(df_long$trait)
  species_idx <- match(as.character(df_long$species), sp_labels)
  mu_t <- seq(2, 0.5, length.out = n_traits)[trait_idx]
  alpha_sp <- ab[cbind(species_idx, 2L * trait_idx - 1L)]
  beta_sp <- ab[cbind(species_idx, 2L * trait_idx)]
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
    Sigma_b_true = Sigma_b_true,
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

test_that("phylo_indep augmented routes to per-trait block-diagonal b_phy_aug", {
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

  ## Design 79/80: one free 2x2 block per trait, with cross-trait blocks
  ## map-pinned to zero in the full augmented engine.
  C <- 2L * 3L
  expect_equal(fit$tmb_data$n_lhs_cols, C)
  expect_true("b_phy_aug" %in% fit$tmb_obj$env$.random)
  expect_true(isTRUE(fit$use$phylo_dep_slope))
  expect_true(isTRUE(fit$use$phylo_indep_slope))
  expect_equal(dim(as.matrix(fit$report$Sigma_b_dep)), c(C, C))
  expect_equal(sum(names(fit$opt$par) == "theta_dep_chol"), 3L * 3L)
  cor_b <- as.matrix(fit$report$cor_b_mat)
  block <- rep(seq_len(3L), each = 2L)
  cross <- outer(block, block, `!=`)
  expect_lt(max(abs(cor_b[cross])), 1e-6)

  es <- extract_Sigma(fit, level = "phy")
  expect_identical(es$level, "phy_indep_slope")
  expect_identical(es$part, "indep")
  expect_equal(dim(es$Sigma), c(C, C))
  expect_lt(max(abs(es$Sigma[cross])), 1e-8)
  expect_identical(
    rownames(es$Sigma),
    as.vector(rbind(
      paste0("intercept.t", seq_len(3L)),
      paste0("slope.t", seq_len(3L))
    ))
  )
})

test_that("phylo_indep augmented Gaussian has a trait-pooled variance sanity check", {
  skip_if_not_heavy()
  skip_if_not_phylo_indep_slope_deps()

  fx <- make_phylo_indep_slope_fixture()
  fit <- fit_phylo_indep_slope_long(fx)

  Sigma_b <- as.matrix(fit$report$Sigma_b_dep)
  sigma2 <- diag(Sigma_b)
  sigma2_int_hat <- mean(sigma2[seq(1L, length(sigma2), by = 2L)])
  sigma2_slope_hat <- mean(sigma2[seq(2L, length(sigma2), by = 2L)])

  ## This single-seed pooled check is a fixture sanity test, not per-trait
  ## recovery evidence. The dedicated multi-seed Gaussian test owns recovery.
  expect_lte(
    abs(sigma2_int_hat - fx$sigma2_int_true) / fx$sigma2_int_true,
    0.20
  )
  expect_lte(
    abs(sigma2_slope_hat - fx$sigma2_slope_true) / fx$sigma2_slope_true,
    0.20
  )

  ## Cross-trait blocks are structurally zero; within-trait correlations are
  ## estimated and are not the old shared, pinned scalar route.
  cor_b <- as.matrix(fit$report$cor_b_mat)
  block <- rep(seq_len(3L), each = 2L)
  expect_lt(max(abs(cor_b[outer(block, block, `!=`)])), 1e-6)
})

test_that("phylo_indep wide and long augmented surfaces are numerically equivalent", {
  skip_if_not_heavy()
  skip_if_not_phylo_indep_slope_deps()

  fx <- make_phylo_indep_slope_fixture()
  fit_long <- fit_phylo_indep_slope_long(fx)
  fit_wide <- fit_phylo_indep_slope_wide(fx)

  expect_equal(fit_wide$opt$objective, fit_long$opt$objective, tolerance = 1e-8)
  expect_identical(fit_wide$tmb_data$Z_phy_aug, fit_long$tmb_data$Z_phy_aug)
  expect_equal(fit_wide$report$Sigma_b_dep, fit_long$report$Sigma_b_dep,
               tolerance = 1e-8)
  expect_equal(fit_wide$report$cor_b_mat, fit_long$report$cor_b_mat,
               tolerance = 1e-8)
})
