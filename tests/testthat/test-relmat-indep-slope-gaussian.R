## relmat_indep(1 + x | id) augmented Gaussian structural and pooled-moment checks.
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
## phylo_indep(1 + x | id, vcv = A) with an arbitrary user A. It uses the
## augmented `b_phy_aug` engine with cross-trait Cholesky entries pinned to zero
## through the TMB map
## (per-trait block-diagonal Sigma_b). No new C++ likelihood block and no new
## keyword.
##
## Truth: each trait has an independent intercept/slope block with both SDs
## nonzero and within-trait correlation = 0. A is a generic AR(1) correlation
## matrix (PD, NON-identity, NOT pedigree-derived). 60 ids, 6 reps.

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

  ## The fitted model is I_T x Sigma_b. Draw independent trait blocks, then
  ## impose A across ids separately on each correlated (alpha, beta) pair.
  ab <- matrix(NA_real_, nrow = n_id, ncol = 2L * n_traits)
  A_chol_t <- t(chol(A))
  for (t in seq_len(n_traits)) {
    cols <- c(2L * t - 1L, 2L * t)
    raw_t <- matrix(stats::rnorm(n_id * 2L), nrow = n_id, ncol = 2L) %*%
      chol(Sigma_b_true)
    ab[, cols] <- A_chol_t %*% raw_t
  }
  colnames(ab) <- as.vector(rbind(
    paste0("alpha_", seq_len(n_traits)),
    paste0("beta_", seq_len(n_traits))
  ))
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

  trait_idx <- as.integer(df_long$trait)
  id_idx <- match(as.character(df_long$species), id_labels)
  mu_t <- seq(2, 0.5, length.out = n_traits)[trait_idx]
  alpha_id <- ab[cbind(id_idx, 2L * trait_idx - 1L)]
  beta_id <- ab[cbind(id_idx, 2L * trait_idx)]
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
    Sigma_b_true = Sigma_b_true,
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

test_that("relmat_indep (= phylo_indep with user A) uses per-trait block-diagonal b_phy_aug", {
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

  C <- 2L * 3L
  expect_equal(fit$tmb_data$n_lhs_cols, C)
  expect_true("b_phy_aug" %in% fit$tmb_obj$env$.random)
  expect_true(isTRUE(fit$use$phylo_dep_slope))
  expect_length(as.numeric(fit$report$sd_b), C)
  expect_equal(sum(names(fit$opt$par) == "theta_dep_chol"), 3L * 3L)
  cor_b <- as.matrix(fit$report$cor_b_mat)
  block <- rep(seq_len(3L), each = 2L)
  expect_lt(max(abs(cor_b[outer(block, block, `!=`)])), 1e-6)
})

test_that("relmat_indep augmented Gaussian has a trait-pooled variance sanity check", {
  skip_if_not_heavy()
  skip_if_not_relmat_indep_slope_deps()

  fx <- make_relmat_indep_slope_fixture()
  fit <- fit_relmat_indep_slope_long(fx)

  sd_b <- as.numeric(fit$report$sd_b)
  sigma2_int_hat <- mean(sd_b[seq(1L, length(sd_b), by = 2L)]^2)
  sigma2_slope_hat <- mean(sd_b[seq(2L, length(sd_b), by = 2L)]^2)

  ## This single-seed pooled check is a fixture sanity test, not complete
  ## per-trait covariance recovery evidence.
  expect_lte(
    abs(sigma2_int_hat - fx$sigma2_int_true) / fx$sigma2_int_true,
    0.20
  )
  expect_lte(
    abs(sigma2_slope_hat - fx$sigma2_slope_true) / fx$sigma2_slope_true,
    0.20
  )

  cor_b <- as.matrix(fit$report$cor_b_mat)
  block <- rep(seq_len(3L), each = 2L)
  expect_lt(max(abs(cor_b[outer(block, block, `!=`)])), 1e-6)
})

test_that("relmat_indep wide and long augmented surfaces are numerically equivalent", {
  skip_if_not_heavy()
  skip_if_not_relmat_indep_slope_deps()

  fx <- make_relmat_indep_slope_fixture()
  fit_long <- fit_relmat_indep_slope_long(fx)
  fit_wide <- fit_relmat_indep_slope_wide(fx)

  expect_equal(fit_wide$opt$objective, fit_long$opt$objective, tolerance = 1e-8)
  expect_identical(fit_wide$tmb_data$Z_phy_aug, fit_long$tmb_data$Z_phy_aug)
  expect_equal(fit_wide$report$sd_b, fit_long$report$sd_b, tolerance = 1e-8)
  expect_equal(fit_wide$report$cor_b_mat, fit_long$report$cor_b_mat,
               tolerance = 1e-8)
})
