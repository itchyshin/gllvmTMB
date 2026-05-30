## animal_indep(1 + x | id) augmented Gaussian recovery (Track B spike extension).
##
## Same cheap route as phylo_indep(1 + x | species): an INDEPENDENT augmented
## animal random regression (correlated intercept+slope, intercept-slope
## correlation FIXED at 0) reuses the SAME augmented `b_phy_aug` engine, with
## the structural matrix A supplied via the keyword's `A =` argument and
## `atanh_cor_b` pinned to 0 via the TMB map. No new C++ likelihood block.
##
## Routing:
##   animal_indep(1 + x | id, A = A)
##     -> parser (R/brms-sugar.R, animal_indep handler) resolves A via
##        .animal_resolve_vcv_call() and, on detecting the augmented LHS via
##        .gllvmTMB_lhs_form(), rewrites to
##        phylo_slope(bar, .phylo_unique_augmented = TRUE, .indep = TRUE,
##                    ..., vcv = A).
##     -> fit-multi.R sets use_phylo_slope_indep and adds
##        tmb_map$atanh_cor_b <- factor(NA), holding rho = tanh(0) = 0.
##   The wide `traits(...) ~ 1 + animal_indep(1 + x | id)` LHS is expanded to
##   the long trait-stacked form by .traits_expand_bar_lhs() (R/traits-keyword.R,
##   `animal_indep` added to .traits_covstruct_bar_keywords).
##
## Truth: intercept SD and slope SD both nonzero, correlation = 0, relatedness
## A = pedigree-derived (NON-identity), so this also exercises the structural
## matrix end to end. ~30 ids, one continuous covariate x.

skip_if_not_animal_indep_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("tidyr")
  testthat::skip_if_not(exists("pedigree_to_A", envir = asNamespace("gllvmTMB")))
}

make_animal_indep_slope_fixture <- function(
  seed = 99L,
  n_id = 30L,
  n_traits = 3L,
  n_rep = 4L
) {
  set.seed(seed)

  ## Half-sib pedigree (4 founders, rest are offspring of i1/i2 x i3/i4).
  ## Topologically sorted: parents always precede offspring. Yields a
  ## NON-identity relatedness matrix A so the structural path is exercised.
  ped <- data.frame(
    id   = paste0("i", seq_len(n_id)),
    sire = c(rep(NA, 4L), rep(c("i1", "i2"), length.out = n_id - 4L)),
    dam  = c(rep(NA, 4L), rep(c("i3", "i4"), length.out = n_id - 4L)),
    stringsAsFactors = FALSE
  )
  A <- gllvmTMB::pedigree_to_A(ped)
  id_labels <- rownames(A)

  sigma2_int_true <- 0.4
  sigma2_slope_true <- 0.3
  rho_true <- 0.0
  cov_true <- rho_true * sqrt(sigma2_int_true * sigma2_slope_true)
  Sigma_b_true <- matrix(
    c(sigma2_int_true, cov_true, cov_true, sigma2_slope_true),
    nrow = 2L,
    ncol = 2L
  )

  ## Impose the A-structure across ids: each column (intercept, slope) is a
  ## draw from N(0, sigma2 * A); chol(A)^T %*% raw gives the A-correlated
  ## effects, then chol(Sigma_b) scales the (intercept, slope) covariance.
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

fit_animal_indep_slope_long <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      animal_indep(0 + trait + (0 + trait):x | species, A = fx$A),
    data = fx$df_long,
    unit = "species",
    control = ctl
  )))
}

fit_animal_indep_slope_wide <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(t1, t2, t3) ~ 1 + animal_indep(1 + x | species, A = fx$A),
    data = fx$df_wide,
    unit = "species",
    control = ctl
  )))
}

test_that("animal_indep augmented routes to b_phy_aug with atanh_cor_b pinned (no C++)", {
  skip_if_not_animal_indep_slope_deps()

  fx <- make_animal_indep_slope_fixture()
  fit <- fit_animal_indep_slope_long(fx)

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

test_that("animal_indep augmented Gaussian recovers both SDs with correlation pinned at 0", {
  skip_if_not_animal_indep_slope_deps()

  fx <- make_animal_indep_slope_fixture()
  fit <- fit_animal_indep_slope_long(fx)

  sd_b <- as.numeric(fit$report$sd_b)
  sigma2_int_hat <- sd_b[1L]^2
  sigma2_slope_hat <- sd_b[2L]^2

  ## Recover both variance components within 20% relative error (the same band
  ## the validated phylo_indep / phylo_unique augmented Gaussian tests use).
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

test_that("animal_indep is byte-identical to phylo_indep(vcv = A) and wide == long", {
  skip_if_not_animal_indep_slope_deps()

  fx <- make_animal_indep_slope_fixture()
  fit_long <- fit_animal_indep_slope_long(fx)
  fit_wide <- fit_animal_indep_slope_wide(fx)

  ## animal_indep(A = A) is a pure rewrite onto phylo_indep(vcv = A); the two
  ## surfaces share the augmented b_phy_aug engine byte for byte (the ANI-03
  ## contract from test-animal-keyword.R, extended to the augmented LHS).
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  fit_phylo <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_indep(0 + trait + (0 + trait):x | species, vcv = fx$A),
    data = fx$df_long,
    phylo_vcv = fx$A,
    unit = "species",
    control = ctl
  )))
  expect_equal(fit_long$opt$objective, fit_phylo$opt$objective, tolerance = 1e-8)
  expect_equal(fit_long$report$sd_b, fit_phylo$report$sd_b, tolerance = 1e-8)

  ## Wide and long augmented surfaces are byte-identical.
  expect_equal(fit_wide$opt$objective, fit_long$opt$objective, tolerance = 1e-8)
  expect_identical(fit_wide$tmb_data$Z_phy_aug, fit_long$tmb_data$Z_phy_aug)
  expect_equal(fit_wide$report$sd_b, fit_long$report$sd_b, tolerance = 1e-8)
  expect_equal(as.numeric(fit_wide$report$cor_b), 0, tolerance = 1e-10)
})
