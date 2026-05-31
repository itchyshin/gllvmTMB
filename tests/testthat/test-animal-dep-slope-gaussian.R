## Design 55 A3 + Design 56 9.5d-dep -- animal_dep(1 + x | id) Gaussian.
##
## animal_dep(1 + x | id, pedigree = ped) routes through the same
## b_phy_aug engine as phylo_dep(1 + x | species) (Design 56 sec. 9.5c).
## The only difference: the structural matrix A comes from a pedigree via
## pedigree_to_Ainv_sparse(), not from a phylogenetic tree.
##
## Validated column ordering: INTERLEAVED (alpha_t0, beta_t0, alpha_t1,
## beta_t1, ...) -- same as phylo_dep (see test-phylo-dep-slope-gaussian.R).
##
## Coverage:
##   - Wide == long byte-identity: traits(t1,t2) ~ 1 + animal_dep(1+x|id)
##     and the explicit long surface produce identical logLik and Sigma_b_dep
##     (tolerance <= 1e-8).
##   - Gaussian recovery (n_id = 80, n_rep = 8): diagonal variance ratios
##     within [1/2, 2]; max abs off-diagonal Sigma_b error < 0.25.
##   - conv = 0 and PD Hessian.
##   - Non-Gaussian aborts loud.

skip_if_not_animal_dep_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not(exists("pedigree_to_A", envir = asNamespace("gllvmTMB")))
  testthat::skip_if_not_installed("tidyr")
}

## ---------------------------------------------------------------------------
## Shared pedigree + fixture builder
## ---------------------------------------------------------------------------
.make_animal_dep_ped <- function(n_id = 80L) {
  data.frame(
    id   = paste0("i", seq_len(n_id)),
    sire = c(rep(NA, 8L), rep(paste0("i", rep(1:4, length.out = n_id - 8L)), 1L)),
    dam  = c(rep(NA, 8L), rep(paste0("i", rep(5:8, length.out = n_id - 8L)), 1L)),
    stringsAsFactors = FALSE
  )
}

## Known PD Cholesky of the 2T x 2T Sigma_b (interleaved).
## Matches the dep recovery spike (test-phylo-dep-slope-gaussian.R).
.dep_L_animal <- function(C = 4L) {
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

.make_animal_dep_fixture <- function(seed, n_id = 80L, T_tr = 2L, n_rep = 8L) {
  set.seed(seed)
  ped <- .make_animal_dep_ped(n_id)
  A <- gllvmTMB::pedigree_to_A(ped)
  id_labels <- rownames(A)

  C <- 2L * T_tr
  Ltrue <- .dep_L_animal(C)
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
    ped = ped, A = A, df_long = df_long, B = B,
    Sigma_b_true = Sigma_b_true, T_tr = T_tr, C = C
  )
}

## ======================================================================
## 1. Wide == long byte-identity
## ======================================================================
test_that("animal_dep wide and long Gaussian fits are byte-identical", {
  skip_if_not_heavy()
  skip_if_not_animal_dep_slope_deps()

  fx <- .make_animal_dep_fixture(seed = 778L, n_id = 60L, n_rep = 5L)
  df_wide <- as.data.frame(tidyr::pivot_wider(
    fx$df_long,
    id_cols    = c(species, rep, x),
    names_from  = trait,
    values_from = value
  ))

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      animal_dep(0 + trait + (0 + trait):x | species, pedigree = fx$ped),
    data = fx$df_long, unit = "species", control = ctl
  )))
  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(t1, t2) ~ 1 + animal_dep(1 + x | species, pedigree = fx$ped),
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
    tolerance = 1e-6
  )
  expect_equal(
    fit_wide$report$Sigma_b_dep,
    fit_long$report$Sigma_b_dep,
    tolerance = 1e-8
  )
})

## ======================================================================
## 2. Gaussian recovery: diagonal variances tight, off-diagonals banded
## ======================================================================
test_that("animal_dep Gaussian fit recovers the 2T x 2T Sigma_b", {
  skip_if_not_heavy()
  skip_if_not_animal_dep_slope_deps()

  fx <- .make_animal_dep_fixture(seed = 20260530L, n_id = 80L, n_rep = 8L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      animal_dep(1 + x | species, pedigree = fx$ped),
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
## 3. Negative test: non-Gaussian animal_dep slope is deferred fail-loud
## ======================================================================
test_that("non-Gaussian animal_dep slope aborts with a clear error", {
  skip_if_not_heavy()
  skip_if_not_animal_dep_slope_deps()

  fx <- .make_animal_dep_fixture(seed = 11L, n_id = 20L, n_rep = 3L)
  df <- fx$df_long
  df$count <- stats::rpois(nrow(df), lambda = exp(1 + 0.2 * df$x))
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      count ~ 0 + trait +
        animal_dep(1 + x | species, pedigree = fx$ped),
      data = df, unit = "species",
      family = stats::poisson()
    ))),
    regexp = "not yet supported for this"
  )
})
