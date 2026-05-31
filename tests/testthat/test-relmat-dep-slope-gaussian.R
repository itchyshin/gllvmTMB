## Design 55 A5 + Design 56 9.5f-dep -- relmat_dep(1 + x | id) Gaussian.
##
## SCOPE NOTE (Design 14 sec. 2). There is no `relmat_dep()` keyword in
## gllvmTMB (the drmTMB-team review deferred a separate `relmat_*()` escape
## hatch and ratified that any known relatedness matrix is passed through the
## phylo surface: `phylo_dep(species, vcv = A)`). "relmat" denotes the
## CAPABILITY "phylo dep random regression on a user-supplied (non-pedigree)
## relatedness matrix", not a distinct keyword.
##
## This test pins that capability for the DEP augmented slope cell:
## phylo_dep(1 + x | id, vcv = A) with an arbitrary user A (AR(1)-based).
## The same b_phy_aug engine and theta_dep_chol machinery as phylo_dep with
## a tree; no new C++.
##
## Coverage:
##   - Wide == long byte-identity (tolerance <= 1e-8 logLik).
##   - Gaussian recovery (n_id = 80, n_rep = 8): diagonal variance ratios
##     within [1/2, 2]; max abs off-diagonal Sigma_b error < 0.25; conv = 0
##     + PD Hessian.
##   - Non-Gaussian aborts loud.

skip_if_not_relmat_dep_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("Matrix")
  testthat::skip_if_not_installed("tidyr")
}

## ---------------------------------------------------------------------------
## Known Cholesky of 2T x 2T Sigma_b (interleaved; same as animal_dep).
## ---------------------------------------------------------------------------
.dep_L_relmat <- function(C = 4L) {
  L <- matrix(0, C, C)
  stopifnot(C == 4L)
  L[lower.tri(L, diag = TRUE)] <- c(
    0.8, 0.2, -0.1, 0.15,
    0.6, 0.1, -0.05,
    0.5, 0.1,
    0.45
  )
  L
}

make_relmat_dep_slope_fixture <- function(
  seed,
  n_id  = 80L,
  T_tr  = 2L,
  n_rep = 8L,
  ar1_rho = 0.5
) {
  set.seed(seed)
  id_labels <- paste0("g", seq_len(n_id))
  ## Generic user relatedness matrix: AR(1) correlation. PD by construction,
  ## NON-identity, NOT pedigree-derived.
  A <- ar1_rho^abs(outer(seq_len(n_id), seq_len(n_id), "-"))
  dimnames(A) <- list(id_labels, id_labels)

  C <- 2L * T_tr
  Ltrue <- .dep_L_relmat(C)
  Sigma_b_true <- Ltrue %*% t(Ltrue)
  LA <- t(chol(A + diag(1e-8, n_id)))
  B <- (LA %*% matrix(stats::rnorm(n_id * C), n_id, C)) %*% chol(Sigma_b_true)
  rownames(B) <- id_labels

  sr <- expand.grid(
    species = factor(id_labels, levels = id_labels),
    rep = seq_len(n_rep)
  )
  sr$x <- stats::rnorm(nrow(sr))
  trait_levels <- paste0("t", seq_len(T_tr))
  df_long <- merge(
    sr,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df_long <- df_long[order(df_long$species, df_long$rep, df_long$trait), ]
  ti <- as.integer(df_long$trait)
  si <- match(as.character(df_long$species), id_labels)
  mu_t <- seq(1, by = -0.5, length.out = T_tr)[ti]
  alpha <- B[cbind(si, 2L * (ti - 1L) + 1L)]
  beta  <- B[cbind(si, 2L * (ti - 1L) + 2L)]
  df_long$value <- mu_t + alpha + beta * df_long$x +
    stats::rnorm(nrow(df_long), sd = 0.3)

  list(
    A = A, df_long = df_long, B = B,
    Sigma_b_true = Sigma_b_true, T_tr = T_tr, C = C
  )
}

## ======================================================================
## 1. Wide == long byte-identity
## ======================================================================
test_that("relmat_dep (phylo_dep, vcv=A) wide and long Gaussian fits are byte-identical", {
  skip_if_not_heavy()
  skip_if_not_relmat_dep_slope_deps()

  fx <- make_relmat_dep_slope_fixture(seed = 778L, n_id = 60L, n_rep = 5L)
  df_wide <- as.data.frame(tidyr::pivot_wider(
    fx$df_long,
    id_cols    = c(species, rep, x),
    names_from  = trait,
    values_from = value
  ))

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_dep(0 + trait + (0 + trait):x | species, vcv = fx$A),
    data = fx$df_long, unit = "species", control = ctl
  )))
  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(t1, t2) ~ 1 + phylo_dep(1 + x | species, vcv = fx$A),
    data = df_wide, unit = "species", control = ctl
  )))

  expect_identical(fit_long$tmb_data$use_phylo_dep_slope, 1L)
  expect_identical(fit_wide$tmb_data$use_phylo_dep_slope, 1L)
  expect_identical(fit_long$tmb_data$n_lhs_cols, fx$C)
  expect_identical(fit_wide$tmb_data$n_lhs_cols, fx$C)

  expect_identical(fit_wide$tmb_data$y,              fit_long$tmb_data$y)
  expect_identical(fit_wide$tmb_data$trait_id,        fit_long$tmb_data$trait_id)
  expect_identical(fit_wide$tmb_data$species_aug_id,  fit_long$tmb_data$species_aug_id)
  expect_identical(fit_wide$tmb_data$Z_phy_aug,       fit_long$tmb_data$Z_phy_aug)

  expect_equal(
    as.numeric(logLik(fit_wide)),
    as.numeric(logLik(fit_long)),
    tolerance = 1e-8
  )
  expect_equal(
    fit_wide$report$Sigma_b_dep,
    fit_long$report$Sigma_b_dep,
    tolerance = 1e-8
  )
})

## ======================================================================
## 2. Gaussian recovery
## ======================================================================
test_that("relmat_dep (phylo_dep, vcv=A) Gaussian fit recovers the 2T x 2T Sigma_b", {
  skip_if_not_heavy()
  skip_if_not_relmat_dep_slope_deps()

  fx <- make_relmat_dep_slope_fixture(seed = 20260530L, n_id = 80L, n_rep = 8L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_dep(1 + x | species, vcv = fx$A),
    data = fx$df_long, unit = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_true(isTRUE(fit$fit_health$pd_hessian))

  Sig_hat  <- fit$report$Sigma_b_dep
  Sig_true <- fx$Sigma_b_true
  expect_equal(dim(Sig_hat), c(fx$C, fx$C))

  ## Diagonal variance ratio within [1/2, 2].
  diag_ratio <- diag(Sig_hat) / diag(Sig_true)
  expect_true(all(is.finite(diag_ratio)))
  expect_true(all(diag_ratio >= 0.5))
  expect_true(all(diag_ratio <= 2.0))

  ## Intercept variances (interleaved cols 1, 3) within 25% relative error.
  int_idx <- seq(1L, fx$C, by = 2L)
  expect_true(all(
    abs(diag(Sig_hat)[int_idx] - diag(Sig_true)[int_idx]) /
      diag(Sig_true)[int_idx] <= 0.25
  ))

  ## Off-diagonal absolute error < 0.25.
  offdiag_err <- max(abs((Sig_hat - Sig_true)[upper.tri(Sig_true)]))
  expect_lt(offdiag_err, 0.25)
})

## ======================================================================
## 3. Negative test: non-Gaussian relmat_dep slope aborts loud
## ======================================================================
test_that("non-Gaussian relmat_dep slope aborts loud", {
  skip_if_not_heavy()
  skip_if_not_relmat_dep_slope_deps()

  fx <- make_relmat_dep_slope_fixture(seed = 11L, n_id = 20L, n_rep = 3L)
  df <- fx$df_long
  df$count <- stats::rpois(nrow(df), lambda = exp(1 + 0.2 * df$x))
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      count ~ 0 + trait +
        phylo_dep(1 + x | species, vcv = fx$A),
      data = df, unit = "species",
      family = stats::poisson()
    ))),
    regexp = "not yet supported for this"
  )
})
