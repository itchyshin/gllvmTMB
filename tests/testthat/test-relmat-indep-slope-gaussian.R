## relmat_indep(1 + x | id) augmented Gaussian recovery (Track B spike extension).
##
## SCOPE NOTE (Design 14 §2). There is intentionally NO `relmat_*()` keyword in
## gllvmTMB: the drmTMB-team review (2026-05-17) deferred the low-level
## `relmat_*()` / `knownvcv_*()` escape hatch and ratified that, for v0.2.0,
## *any* known relatedness matrix is passed through the biology-flavoured but
## fully generic phylo surface: `phylo_*(species, vcv = K)`. "relmat" therefore
## denotes the CAPABILITY "phylo augmented random regression on a user-supplied
## (non-pedigree, non-identity) relatedness matrix", not a distinct keyword.
##
## This test pins that capability for the INDEPENDENT augmented slope cell:
## phylo_indep(1 + x | id, vcv = A) with an arbitrary user A. It reuses the SAME
## cheap route as phylo_indep / animal_indep — the augmented `b_phy_aug` engine
## with `atanh_cor_b` pinned to 0 via the TMB map (block-diagonal Sigma_b). No
## new C++ likelihood block, and no new keyword.
##
## Truth: intercept SD and slope SD both nonzero, correlation = 0, A = a generic
## AR(1) correlation matrix (PD, NON-identity, NOT pedigree-derived). 60 ids,
## 6 reps for slope-variance identifiability.

skip_if_not_relmat_indep_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("tidyr")
}

make_relmat_indep_slope_fixture <- function(
  seed = 7L,
  n_id = 60L,
  n_traits = 3L,
  n_rep = 6L,
  ar1_rho = 0.5
) {
  set.seed(seed)
  id_labels <- paste0("g", seq_len(n_id))

  ## Generic user relatedness matrix: AR(1) correlation on the id ordering.
  ## PD by construction, NON-identity, and not derived from any pedigree —
  ## the "user A matrix" case Design 14 §2 routes through phylo_*(vcv = K).
  A <- ar1_rho^abs(outer(seq_len(n_id), seq_len(n_id), "-"))
  dimnames(A) <- list(id_labels, id_labels)

  sigma2_int_true <- 0.4
  sigma2_slope_true <- 0.3
  rho_true <- 0.0
  cov_true <- rho_true * sqrt(sigma2_int_true * sigma2_slope_true)
  Sigma_b_true <- matrix(
    c(sigma2_int_true, cov_true, cov_true, sigma2_slope_true),
    nrow = 2L,
    ncol = 2L
  )

  ## Impose A-structure across ids (chol(A)^T %*% raw) and the (intercept,
  ## slope) covariance via chol(Sigma_b_true).
  raw <- matrix(stats::rnorm(n_id * 2L), nrow = n_id, ncol = 2L) %*%
    chol(Sigma_b_true)
  ab <- t(chol(A)) %*% raw
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- id_labels

  id_rep <- expand.grid(
    species = factor(id_labels, levels = id_labels),
    rep = seq_len(n_rep)
  )
  id_rep$x <- stats::rnorm(nrow(id_rep))

  trait_levels <- paste0("t", seq_len(n_traits))
  df_long <- merge(
    id_rep,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df_long <- df_long[order(df_long$species, df_long$rep, df_long$trait), ]

  mu_t <- c(2, 1, 0.5)[as.integer(df_long$trait)]
  alpha_id <- ab[as.character(df_long$species), "alpha"]
  beta_id <- ab[as.character(df_long$species), "beta"]
  df_long$value <- mu_t + alpha_id + beta_id * df_long$x +
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
    A = A,
    sigma2_int_true = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true = rho_true
  )
}

## "relmat" is expressed as phylo_indep(vcv = user_A) per Design 14 §2.
fit_relmat_indep_slope_long <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_indep(0 + trait + (0 + trait):x | species, vcv = fx$A),
    data = fx$df_long,
    phylo_vcv = fx$A,
    unit = "species",
    control = ctl
  )))
}

fit_relmat_indep_slope_wide <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(t1, t2, t3) ~ 1 + phylo_indep(1 + x | species, vcv = fx$A),
    data = fx$df_wide,
    phylo_vcv = fx$A,
    unit = "species",
    control = ctl
  )))
}

test_that("relmat_indep (= phylo_indep with user A) routes to b_phy_aug with atanh_cor_b pinned (no C++)", {
  skip_if_not_heavy()
  skip_if_not_relmat_indep_slope_deps()

  fx <- make_relmat_indep_slope_fixture()
  fit <- fit_relmat_indep_slope_long(fx)

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

  ## The correlation is PINNED, not estimated.
  expect_true("atanh_cor_b" %in% names(fit$tmb_map))
  expect_true(all(is.na(fit$tmb_map$atanh_cor_b)))
  expect_false("atanh_cor_b" %in% names(fit$opt$par))
  expect_equal(as.numeric(fit$report$cor_b), 0, tolerance = 1e-10)
})

test_that("relmat_indep augmented Gaussian recovers both SDs with correlation pinned at 0", {
  skip_if_not_heavy()
  skip_if_not_relmat_indep_slope_deps()

  fx <- make_relmat_indep_slope_fixture()
  fit <- fit_relmat_indep_slope_long(fx)

  sd_b <- as.numeric(fit$report$sd_b)
  sigma2_int_hat <- sd_b[1L]^2
  sigma2_slope_hat <- sd_b[2L]^2

  ## Recover both variance components within 20% relative error.
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

test_that("relmat_indep wide and long augmented surfaces are byte-identical", {
  skip_if_not_heavy()
  skip_if_not_relmat_indep_slope_deps()

  fx <- make_relmat_indep_slope_fixture()
  fit_long <- fit_relmat_indep_slope_long(fx)
  fit_wide <- fit_relmat_indep_slope_wide(fx)

  expect_equal(fit_wide$opt$objective, fit_long$opt$objective, tolerance = 1e-8)
  expect_identical(fit_wide$tmb_data$Z_phy_aug, fit_long$tmb_data$Z_phy_aug)
  expect_equal(fit_wide$report$sd_b, fit_long$report$sd_b, tolerance = 1e-8)
  expect_equal(as.numeric(fit_wide$report$cor_b), 0, tolerance = 1e-10)
})
