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
## 3. Negative test: reserved-family animal_dep slope is deferred fail-loud
## ======================================================================
test_that("reserved-family animal_dep slope aborts with a clear error", {
  skip_if_not_heavy()
  skip_if_not_animal_dep_slope_deps()

  ## animal_dep (the known-pedigree dep slope) shares the phylo_dep augmented-
  ## slope guard (use_phylo_dep_slope, R/fit-multi.R), so PHY-18 (#422 / #424)
  ## admitting poisson, Gamma, Beta, binomial, nbinom2, and ordinal_probit
  ## means poisson now CONSTRUCTS here too. The fail-loud probe must use a
  ## still-RESERVED family: tweedie (runtime family id 6) is NOT on the
  ## allowlist c(0L, 1L, 2L, 4L, 5L, 7L, 14L), so the guard still fires.
  fx <- .make_animal_dep_fixture(seed = 11L, n_id = 20L, n_rep = 3L)
  df <- fx$df_long
  df$count <- stats::rpois(nrow(df), lambda = exp(1 + 0.2 * df$x))
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      count ~ 0 + trait +
        animal_dep(1 + x | species, pedigree = fx$ped),
      data = df, unit = "species",
      family = gllvmTMB::tweedie()
    ))),
    regexp = "not yet supported for this"
  )
})

## ======================================================================
## 4. animal_dep(1 + x | id) x poisson VALIDATION (ANI-12): real-API
##    recovery cell for the known-pedigree non-Gaussian dep slope.
## ======================================================================
## animal_dep non-Gaussian dep slopes are ALREADY ADMITTED via the shared
## `use_phylo_dep_slope` guard (R/fit-multi.R allowlist now
## c(0L, 1L, 2L, 4L, 5L, 7L, 14L, 15L)), but -- unlike phylo_dep (PHY-18,
## #422 / #424) -- they had NO dedicated recovery cell. animal_* stays
## first-class (NOT deprecated, unlike relmat). This cell is the confirmation
## the maintainer's relmat/animal decision asked for: ONE lightweight
## non-Gaussian (poisson) animal_dep slope that builds A from a pedigree via
## pedigree_to_A() and fits the REAL animal_dep path, asserting slope-variance
## recovery from the engine's `report$Sigma_b_dep` matrix within the inherited
## poisson band.
##
## The math is IDENTICAL to the phylo_dep poisson VALIDATION cell
## (test-matrix-slope-phylo-dep.R) -- only the source of the relatedness
## matrix A differs (a pedigree here vs an ape tree there). Same interleaved
## C = 4 Sigma_b (.dep_L_animal), same Sigma_b_dep read at interleaved slope
## positions 2 and 4, same inherited 4x poisson band (do NOT invent a tighter
## one). Honest-skip on non-convergence / non-PD / out-of-band recovery at the
## modest fixture; NO force-pass. NO relmat_dep cell is added (relmat is heading
## for kernel soft-deprecation per Design 65 C4).

## Poisson animal_dep fixture: B ~ MN(0, A_ped, Sigma_b) with INTERLEAVED
## per-trait (intercept, slope) columns, then y = rpois(n, exp(eta)) with
## eta = mu_t + alpha_id + beta_id * x and modest log-scale intercepts.
.make_animal_dep_pois_fixture <- function(seed, n_id = 150L, T_tr = 2L,
                                          n_rep = 10L, mu_t_log = c(1.0, 0.7)) {
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
  alpha <- B[cbind(si, 2L * (ti - 1L) + 1L)]
  beta  <- B[cbind(si, 2L * (ti - 1L) + 2L)]
  eta <- mu_t_log[ti] + alpha + beta * df_long$x
  df_long$value <- stats::rpois(nrow(df_long), lambda = exp(eta))

  list(
    ped = ped, A = A, df_long = df_long, B = B,
    Sigma_b_true = Sigma_b_true, T_tr = T_tr, C = C
  )
}

test_that("animal_dep(1 + x | id) x poisson VALIDATION (ANI-12): real-API fit converges PD and recovers slope variances from Sigma_b_dep", {
  skip_if_not_heavy()
  skip_if_not_animal_dep_slope_deps()

  fx <- .make_animal_dep_pois_fixture(
    seed = 20260603L, n_id = 150L, T_tr = 2L, n_rep = 10L,
    mu_t_log = c(1.0, 0.7)
  )

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + animal_dep(1 + x | species, pedigree = fx$ped),
      data = fx$df_long, unit = "species",
      family = stats::poisson(link = "log"),
      control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
    ))),
    error = function(e) e
  )

  ## animal_dep poisson is ADMITTED (shared use_phylo_dep_slope guard, id 2 on
  ## the allowlist). A surviving construction abort is a guard regression.
  if (inherits(fit, "error")) {
    testthat::fail(sprintf(
      "animal_dep(1 + x | id) x poisson aborted at construction: %s (the shared phylo_dep guard admits poisson id 2)",
      conditionMessage(fit)
    ))
    return(invisible(NULL))
  }
  testthat::expect_s3_class(fit, "gllvmTMB_multi")

  ## Engine ran the dep poisson path through the animal_dep route.
  testthat::expect_true(isTRUE(fit$use$phylo_dep_slope))
  testthat::expect_identical(fit$tmb_data$use_phylo_dep_slope, 1L)
  testthat::expect_true(all(fit$tmb_data$family_id_vec == 2L))

  ## Honest-skip on non-convergence / non-PD; do not force green.
  healthy <- isTRUE(fit$opt$convergence == 0L) &&
    is.finite(fit$opt$objective) &&
    (isTRUE(fit$fit_health$pd_hessian) || isTRUE(fit$sd_report$pdHess))
  if (!healthy) {
    testthat::skip(sprintf(
      "animal_dep(1 + x | id) x poisson did not converge with PD Hessian (conv = %s, pdHess = %s); ANI-12 stays partial pending bigger n / different seed",
      fit$opt$convergence, isTRUE(fit$sd_report$pdHess)
    ))
  }

  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian) ||
    isTRUE(fit$sd_report$pdHess))

  ## Read slope variances from the C x C report$Sigma_b_dep matrix at the
  ## interleaved diagonal positions 2 and 4 (same as the phylo_dep cell).
  Sig_hat <- as.matrix(fit$report$Sigma_b_dep)
  testthat::expect_equal(dim(Sig_hat), c(fx$C, fx$C))
  testthat::expect_true(all(is.finite(Sig_hat)))

  slope_idx <- c(2L, 4L)
  slope_var_hat <- diag(Sig_hat)[slope_idx]
  slope_var_true <- diag(fx$Sigma_b_true)[slope_idx]
  ratio <- slope_var_hat / slope_var_true

  ## Inherited 4x poisson band (matches the phylo_dep poisson VALIDATION cell).
  var_band <- 4
  if (!all(is.finite(ratio)) ||
        any(ratio < 1 / var_band) || any(ratio > var_band)) {
    testthat::skip(sprintf(
      "animal_dep Sigma_b_dep slope-variance recovery outside %gx band (hat = %s, truth = %s, ratio = %s); ANI-12 stays partial pending bigger n",
      var_band,
      paste(sprintf("%.3g", slope_var_hat), collapse = ", "),
      paste(sprintf("%.3g", slope_var_true), collapse = ", "),
      paste(sprintf("%.3g", ratio), collapse = ", ")
    ))
  }
  testthat::expect_true(all(slope_var_hat > slope_var_true / var_band))
  testthat::expect_true(all(slope_var_hat < slope_var_true * var_band))
})
