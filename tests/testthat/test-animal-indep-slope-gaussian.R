## animal_indep(1 + x | id) augmented Gaussian recovery -- per-trait
## block-diagonal contract (Design 79/80, SUPERSEDES Design 56 Sec. 5.3).
##
## OLD contract (pre-Design 79/80): animal_indep(1 + x | id) fit a single
## SHARED 2x2 (intercept, slope) block across all traits, with the
## intercept-slope correlation PINNED to 0 via `atanh_cor_b` (the
## `log_sd_b` / `atanh_cor_b` closed-form path, `n_lhs_cols = 2`).
##
## NEW contract (Design 79/80): animal_indep(1 + x | id) fits T INDEPENDENT
## per-trait 2x2 blocks -- Sigma_b is BLOCK-DIAGONAL over the trait-stacked
## (intercept, slope) columns (C = n_lhs_cols = 2T), the intercept-slope
## correlation is ESTIMATED per trait (not pinned), and cross-trait
## covariance is fixed at exactly 0. This is T stacked univariate random
## regressions sharing one relatedness structure A. animal_indep now routes
## through the SAME phylo_slope engine as phylo_indep, with the pedigree-
## derived relatedness matrix A supplied via `vcv`.
##
## Routing:
##   animal_indep(1 + x | id, A = A)  [augmented LHS]
##     -> parser (R/brms-sugar.R, `animal_indep` handler) resolves A via
##        .animal_resolve_vcv_call() and, on detecting the augmented LHS via
##        .gllvmTMB_lhs_form(), rewrites to
##        phylo_slope(bar, .phylo_dep_augmented = TRUE, .indep_blockdiag = TRUE,
##                     ..., vcv = A).
##     -> fit-multi.R sets use_phylo_dep_slope + use_phylo_indep_blockdiag and
##        pins the CROSS-BLOCK strictly-lower `theta_dep_chol` entries to 0
##        via the TMB map (dep_chol_crossblock_pins(), R/lambda-constraint.R),
##        leaving the WITHIN-BLOCK diagonal + intercept-slope entries free:
##        3T free `theta_dep_chol` parameters for a single slope (2T diagonal
##        + T within-block off-diagonal), matching T stacked univariate
##        random regressions. No new C++ likelihood block (same engine as
##        phylo_dep, just with cross-block entries held at 0).
##   The wide `traits(...) ~ 1 + animal_indep(1 + x | id)` LHS is expanded to
##   the long trait-stacked form by .traits_expand_bar_lhs() (R/traits-keyword.R,
##   `animal_indep` added to .traits_covstruct_bar_keywords).
##
## Reporting contract (verified against the live engine, src/gllvmTMB.cpp):
## the dep-family path (phylo_dep / phylo_indep / animal_dep / animal_indep)
## REPORTs `sd_b` (length C, INTERLEAVED per trait: sd_b[2t-1] = intercept SD,
## sd_b[2t] = slope SD), `cor_b_mat` (C x C correlation matrix; within-trait
## rho at cor_b_mat[2t-1, 2t], cross-trait entries exactly 0 by construction),
## and `Sigma_b_dep` (C x C covariance). It does NOT report a scalar `cor_b`
## (that name is reserved for the closed-form 2x2 unique/indep-non-blockdiag
## path, n_lhs_cols in {1, 2}; see R/extract-sigma.R's discriminator comment).
##
## Truth: TWO distinct per-trait 2x2 blocks G_t with a strong, sign-distinct
## intercept-slope correlation (t1 rho = +0.40, t2 rho = -0.45), relatedness
## A = pedigree-derived (NON-identity), so this also exercises the structural
## matrix end to end. 40 ids, one continuous covariate x.

skip_if_not_animal_indep_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("tidyr")
  testthat::skip_if_not(exists("pedigree_to_A", envir = asNamespace("gllvmTMB")))
}

## Per-trait TRUE 2x2 (intercept, slope) covariance blocks, sign-distinct
## intercept-slope correlation: t1 rho = +0.40, t2 rho = -0.45.
.animal_indep_slope_true_blocks <- function() {
  list(
    matrix(
      c(0.50, 0.40 * sqrt(0.50 * 0.30),
        0.40 * sqrt(0.50 * 0.30), 0.30),
      nrow = 2L, ncol = 2L
    ),
    matrix(
      c(0.45, -0.45 * sqrt(0.45 * 0.35),
        -0.45 * sqrt(0.45 * 0.35), 0.35),
      nrow = 2L, ncol = 2L
    )
  )
}

make_animal_indep_slope_fixture <- function(
  seed,
  n_id = 40L,
  n_traits = 2L,
  n_rep = 6L
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
  L_A <- t(chol(A))

  G_list <- .animal_indep_slope_true_blocks()[seq_len(n_traits)]

  ## Per-trait A-structured (intercept, slope) draws: for each trait t,
  ## (alpha_t, beta_t)[id] ~ N(0, G_t (x) A). L_A %*% Z_t gives the raw
  ## A-correlated columns; right-multiplying by chol(G_t) imposes the
  ## per-trait (intercept, slope) covariance. Distinct Z_t per trait ->
  ## cross-trait covariance is 0 in the DGP (matching the model contract).
  ab_list <- lapply(G_list, function(G_t) {
    Z_t <- matrix(stats::rnorm(n_id * 2L), nrow = n_id, ncol = 2L)
    ab <- L_A %*% Z_t %*% chol(G_t)
    colnames(ab) <- c("alpha", "beta")
    rownames(ab) <- id_labels
    ab
  })

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

  mu_t <- c(2, 1)[seq_len(n_traits)][as.integer(df_long$trait)]
  ti <- as.integer(df_long$trait)
  sp_chr <- as.character(df_long$species)
  alpha_id <- vapply(seq_len(nrow(df_long)), function(k) {
    ab_list[[ti[k]]][sp_chr[k], "alpha"]
  }, numeric(1))
  beta_id <- vapply(seq_len(nrow(df_long)), function(k) {
    ab_list[[ti[k]]][sp_chr[k], "beta"]
  }, numeric(1))
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
    G_list = G_list,
    n_traits = n_traits,
    var_true = unlist(lapply(G_list, diag)),
    rho_true = vapply(G_list, function(G) G[1L, 2L] / sqrt(G[1L, 1L] * G[2L, 2L]), numeric(1))
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
    traits(t1, t2) ~ 1 + animal_indep(1 + x | species, A = fx$A),
    data = fx$df_wide,
    unit = "species",
    control = ctl
  )))
}

## Extract the block-diagonal structure from a fit: per-trait diagonal
## variances (interleaved sd_b^2), per-trait intercept-slope correlation
## (from cor_b_mat's block diagonal), and the max |cross-trait correlation|
## (off block-diagonal entries of cor_b_mat, which are pinned to exactly 0
## by construction).
.animal_indep_slope_extract <- function(fit, n_traits) {
  sd_b <- as.numeric(fit$report$sd_b)
  cor_mat <- as.matrix(fit$report$cor_b_mat)
  C <- 2L * n_traits
  blk <- rep(seq_len(n_traits), each = 2L)
  cross_idx <- which(outer(blk, blk, `!=`) & upper.tri(matrix(0, C, C)))
  within_rho <- vapply(seq_len(n_traits), function(t) {
    cor_mat[2L * t - 1L, 2L * t]
  }, numeric(1))
  list(
    var_hat = sd_b^2,
    within_rho = within_rho,
    cross_max = if (length(cross_idx) > 0L) max(abs(cor_mat[cross_idx])) else 0
  )
}

test_that("animal_indep augmented routes to the phylo_dep engine with per-trait block-diagonal Sigma_b", {
  skip_if_not_heavy()
  skip_if_not_animal_indep_slope_deps()

  fx <- make_animal_indep_slope_fixture(seed = 99L)
  fit <- fit_animal_indep_slope_long(fx)

  ## Fits without error and is healthy.
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_lt(fit$fit_health$max_gradient, 1e-2)
  expect_true(isTRUE(fit$fit_health$pd_hessian))
  expect_true(isTRUE(fit$fit_health$sdreport_ok))

  ## Routed through the augmented dep engine (2T LHS columns, b_phy_aug
  ## random, phylo_dep_slope flag set).
  expect_equal(fit$tmb_data$n_lhs_cols, 2L * fx$n_traits)
  expect_true("b_phy_aug" %in% fit$tmb_obj$env$.random)
  expect_true(isTRUE(fit$use$phylo_dep_slope))
  expect_length(as.numeric(fit$report$sd_b), 2L * fx$n_traits)

  ## STRUCTURAL: exactly 3T free theta_dep_chol entries (2T diagonal + T
  ## within-block off-diagonal); the cross-block entries are pinned to 0
  ## via the TMB map, not part of the optimised parameter vector.
  expect_equal(sum(names(fit$opt$par) == "theta_dep_chol"), 3L * fx$n_traits)

  ext <- .animal_indep_slope_extract(fit, fx$n_traits)

  ## STRUCTURAL: cross-trait correlation is exactly 0 by construction (the
  ## cross-block Cholesky entries are map-pinned, not merely small).
  expect_lt(ext$cross_max, 1e-6)

  ## STRUCTURAL: the per-trait intercept-slope correlation is ESTIMATED
  ## (not pinned to 0) -- sign-correct and non-trivial in magnitude for
  ## both traits, matching the sign-distinct truth (t1 > 0, t2 < 0).
  expect_gt(ext$within_rho[1L], 0.1)
  expect_lt(ext$within_rho[2L], -0.1)
})

test_that("animal_indep augmented Gaussian recovers per-trait variances and intercept-slope correlations", {
  skip_if_not_heavy()
  skip_if_not_animal_indep_slope_deps()

  seeds <- 1:5
  res <- lapply(seeds, function(s) {
    fx <- make_animal_indep_slope_fixture(seed = s)
    fit <- fit_animal_indep_slope_long(fx)
    ext <- .animal_indep_slope_extract(fit, fx$n_traits)
    list(
      conv = fit$opt$convergence,
      pd = isTRUE(fit$fit_health$pd_hessian),
      cross_max = ext$cross_max,
      within_rho = ext$within_rho,
      var_hat = ext$var_hat,
      var_true = fx$var_true,
      rho_true = fx$rho_true
    )
  })

  conv <- vapply(res, function(r) r$conv, integer(1))
  pd <- vapply(res, function(r) r$pd, logical(1))
  cross_max <- vapply(res, function(r) r$cross_max, numeric(1))

  ## Fit health on every seed.
  expect_true(all(conv == 0L))
  expect_true(all(pd))

  ## STRUCTURAL (every seed): cross-trait correlation exactly 0.
  expect_true(all(cross_max < 1e-6))

  ## STRUCTURAL (every seed): per-trait rho sign-correct, non-trivial
  ## magnitude -- the correlation is genuinely estimated, not pinned.
  rho_mat <- t(vapply(res, function(r) r$within_rho, numeric(2L)))
  expect_true(all(rho_mat[, 1L] > 0.1))
  expect_true(all(rho_mat[, 2L] < -0.1))

  ## RECOVERY (seed-averaged, generous 0.30 relative band): per-trait
  ## intercept and slope variances.
  var_hat_mat <- t(vapply(res, function(r) r$var_hat, numeric(4L)))
  var_true <- res[[1L]]$var_true
  rel_err <- abs(colMeans(var_hat_mat) - var_true) / var_true
  expect_true(all(rel_err <= 0.30))

  ## RECOVERY (seed-averaged, generous band): per-trait intercept-slope
  ## correlation lands within 0.25 (absolute) of the truth.
  rho_true <- res[[1L]]$rho_true
  rho_err <- abs(colMeans(rho_mat) - rho_true)
  expect_true(all(rho_err <= 0.25))
})

test_that("animal_indep is byte-identical to phylo_indep(vcv = A) and wide == long", {
  skip_if_not_heavy()
  skip_if_not_animal_indep_slope_deps()

  fx <- make_animal_indep_slope_fixture(seed = 99L)
  fit_long <- fit_animal_indep_slope_long(fx)
  fit_wide <- fit_animal_indep_slope_wide(fx)

  ## animal_indep(A = A) is a pure rewrite onto phylo_indep(vcv = A); the two
  ## surfaces share the augmented b_phy_aug / phylo_dep engine byte for byte
  ## (the ANI-03 contract from test-animal-keyword.R, extended to the
  ## per-trait block-diagonal augmented LHS).
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
  expect_equal(fit_long$report$Sigma_b_dep, fit_phylo$report$Sigma_b_dep, tolerance = 1e-8)

  ## Wide and long augmented surfaces are byte-identical.
  expect_equal(fit_wide$opt$objective, fit_long$opt$objective, tolerance = 1e-8)
  expect_identical(fit_wide$tmb_data$Z_phy_aug, fit_long$tmb_data$Z_phy_aug)
  expect_equal(fit_wide$report$sd_b, fit_long$report$sd_b, tolerance = 1e-8)
  expect_equal(fit_wide$report$Sigma_b_dep, fit_long$report$Sigma_b_dep, tolerance = 1e-8)

  ## Cross-trait correlation stays exactly 0 on both surfaces (the model
  ## contract, not an approximation).
  ext_wide <- .animal_indep_slope_extract(fit_wide, fx$n_traits)
  expect_lt(ext_wide$cross_max, 1e-6)
})
