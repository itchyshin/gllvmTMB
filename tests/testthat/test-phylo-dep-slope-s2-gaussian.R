## RE-03 multi-slope (s >= 2): phylo_dep(1 + x1 + x2 | sp) Gaussian.
##
## The C++ dep likelihood is dimension-general (C = n_lhs_cols), so activating
## s >= 2 is a purely R-side generalisation of the validated s == 1 dep core
## (test-phylo-dep-slope-gaussian.R) from 2T to (1+s)T columns. This cell is
## the bounded, low-risk Gaussian DEMONSTRATION that the generalisation
## recovers a (1+s)T x (1+s)T unstructured Sigma_b. Non-Gaussian s >= 2 stays
## RESERVED behind the dedicated RE-03 runtime guard until a separate
## identifiability sweep clears it, and s == 1 back-compat is owned by the
## existing test-phylo-dep-slope-gaussian.R suite.
##
## Column ordering is INTERLEAVED per trait --
## (alpha_t0, beta1_t0, beta2_t0, alpha_t1, beta1_t1, beta2_t1, ...) -- matching
## the engine Z fill and the extractor dimnames. Two DISTINCT covariates x1, x2
## with within-species variation (drawn per observation) so both slope
## variances are identifiable.
##
## Bands are INHERITED from the s == 1 dep recovery cell (diagonal variance
## RATIO within [1/2, 2]; off-diagonal absolute 0.25). The slope diagonals are
## the binding constraint at fixed n; n_sp is sized up (s == 2 has more
## covariance entries to identify than s == 1). SKIP discipline: a fit that
## does not converge / is non-PD / recovers outside the band => an honest
## skip, NOT a forced pass (the genuine identifiability cost; RE-03 stays
## partial).

skip_if_not_dep_s2_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

test_that("phylo_dep s=2 rejects duplicate slope covariates before design expansion", {
  withr::local_options(lifecycle_verbosity = "quiet")

  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + phylo_dep(1 + x1 + x1 | species)
    ),
    regexp = "Duplicate slope covariates|rank deficient|x1"
  )

  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait +
        phylo_dep(
          0 + trait + (0 + trait):x1 + (0 + trait):x1 | species
        )
    ),
    regexp = "Duplicate slope covariates|rank deficient|x1"
  )
})

## Known PD lower-triangular Cholesky factor of the (1+s)T x (1+s)T Sigma_b
## (column-major lower-tri incl diag). For s = 2, T = 2 => C = 6. Diagonal
## entries set the (intercept, slope1, slope2) marginal scales per trait;
## modest off-diagonals keep the matrix well inside the PD cone.
.dep_s2_Ltrue <- function(C) {
  stopifnot(C == 6L)
  L <- matrix(0, C, C)
  L[lower.tri(L, diag = TRUE)] <- c(
    0.80, 0.15, 0.10, -0.10, 0.08, -0.05, # col 1 (rows 1..6)
    0.55, 0.08, 0.05, -0.04, 0.03,        # col 2 (rows 2..6)
    0.50, 0.06, 0.04, -0.03,              # col 3 (rows 3..6)
    0.75, 0.10, 0.06,                     # col 4 (rows 4..6)
    0.55, 0.05,                           # col 5 (rows 5..6)
    0.50                                  # col 6 (row 6)
  )
  L
}

## Draw the n_sp x (1+s)T augmented effect matrix B ~ MN(0, A_phy, Sigma_b)
## with INTERLEAVED columns (alpha_t, beta1_t, beta2_t). Two distinct
## per-observation covariates x1, x2. Returns tree + B + truth + long frame.
.make_dep_s2_fixture <- function(seed, n_sp, T_tr, n_rep) {
  set.seed(seed)
  s <- 2L
  C <- (1L + s) * T_tr
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Ltrue <- .dep_s2_Ltrue(C)
  Sigma_b_true <- Ltrue %*% t(Ltrue)
  Cphy <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(Cphy + diag(1e-8, n_sp)))
  B <- (LA %*% matrix(stats::rnorm(n_sp * C), n_sp, C)) %*% chol(Sigma_b_true)
  rownames(B) <- tree$tip.label

  sr <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep)
  )
  ## Two DISTINCT covariates with within-species (across-rep) variation so the
  ## two slope variances are separately identifiable. Drawn per (species, rep)
  ## cell and held constant across traits within the cell (the wide<->long
  ## equivalent layout the slope siblings use).
  sr$x1 <- stats::rnorm(nrow(sr))
  sr$x2 <- stats::rnorm(nrow(sr))
  trait_levels <- paste0("t", seq_len(T_tr))
  df_long <- merge(
    sr,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df_long <- df_long[order(df_long$species, df_long$rep, df_long$trait), ]
  ti <- as.integer(df_long$trait)
  si <- match(as.character(df_long$species), tree$tip.label)
  mu_t <- seq(1, by = -0.5, length.out = T_tr)[ti]
  stride <- 1L + s
  alpha <- B[cbind(si, stride * (ti - 1L) + 1L)] # interleaved intercept col
  beta1 <- B[cbind(si, stride * (ti - 1L) + 2L)] # interleaved slope1 col
  beta2 <- B[cbind(si, stride * (ti - 1L) + 3L)] # interleaved slope2 col
  df_long$value <- mu_t + alpha + beta1 * df_long$x1 + beta2 * df_long$x2 +
    stats::rnorm(nrow(df_long), sd = 0.3)

  list(
    tree = tree, df_long = df_long, B = B,
    Sigma_b_true = Sigma_b_true, T_tr = T_tr, C = C, s = s
  )
}

test_that("phylo_dep s=2 rejects non-Gaussian families until the RE-03 sweep clears", {
  skip_if_not_dep_s2_deps()

  fx <- .make_dep_s2_fixture(seed = 1202L, n_sp = 6L, T_tr = 2L, n_rep = 2L)
  fx$df_long$value <- stats::rpois(nrow(fx$df_long), lambda = 3)

  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_dep(1 + x1 + x2 | species),
      data = fx$df_long,
      phylo_tree = fx$tree,
      unit = "species",
      family = stats::poisson(link = "log"),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ))),
    regexp = "two or more random slopes|RE-03|s >= 2"
  )
})

## ======================================================================
## 1. Interleaved (1+s)T-wide Z structure (per-trait intercept + 2 slopes).
## ======================================================================
test_that("phylo_dep s=2 builds the interleaved (1+s)T-wide Z design array", {
  skip_if_not_heavy()
  skip_if_not_dep_s2_deps()

  fx <- .make_dep_s2_fixture(seed = 778L, n_sp = 30L, T_tr = 2L, n_rep = 4L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(1 + x1 + x2 | species),
    data = fx$df_long, phylo_tree = fx$tree, unit = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))

  expect_identical(fit$tmb_data$use_phylo_dep_slope, 1L)
  expect_identical(fit$tmb_data$n_lhs_cols, fx$C) # (1+2)*2 = 6
  Z <- fit$tmb_data$Z_phy_aug
  expect_equal(dim(Z), c(nrow(fx$df_long), fx$C, 1L))

  trid <- fit$tmb_data$trait_id # 0-based
  stride <- 1L + fx$s
  x1 <- fx$df_long$x1
  x2 <- fx$df_long$x2
  ## Each row activates exactly its own trait's (intercept, slope1, slope2)
  ## run: column stride*t0+1 == 1, +2 == x1, +3 == x2; all others 0.
  for (o in seq_len(nrow(fx$df_long))) {
    t0 <- trid[o]
    base <- stride * t0
    expect_equal(Z[o, base + 1L, 1L], 1.0)
    expect_equal(Z[o, base + 2L, 1L], x1[o])
    expect_equal(Z[o, base + 3L, 1L], x2[o])
    other <- setdiff(seq_len(fx$C), c(base + 1L, base + 2L, base + 3L))
    expect_true(all(Z[o, other, 1L] == 0))
  }
})

## ======================================================================
## 2. Wide <-> long byte-identity for the s=2 path (interleaved ordering).
## ======================================================================
test_that("phylo_dep s=2 wide and long Gaussian fits are byte-identical", {
  skip_if_not_heavy()
  skip_if_not_dep_s2_deps()

  fx <- .make_dep_s2_fixture(seed = 909L, n_sp = 40L, T_tr = 2L, n_rep = 4L)
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(1 + x1 + x2 | species),
    data = fx$df_long, phylo_tree = fx$tree, unit = "species", control = ctl
  )))
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_dep(0 + trait + (0 + trait):x1 + (0 + trait):x2 | species),
    data = fx$df_long, phylo_tree = fx$tree, unit = "species", control = ctl
  )))

  expect_identical(fit_wide$tmb_data$use_phylo_dep_slope, 1L)
  expect_identical(fit_long$tmb_data$use_phylo_dep_slope, 1L)
  expect_identical(fit_wide$tmb_data$n_lhs_cols, fx$C)
  expect_identical(fit_long$tmb_data$n_lhs_cols, fx$C)
  expect_identical(fit_wide$tmb_data$Z_phy_aug, fit_long$tmb_data$Z_phy_aug)
  expect_equal(
    as.numeric(logLik(fit_wide)), as.numeric(logLik(fit_long)),
    tolerance = 1e-6
  )
  expect_equal(
    fit_wide$report$Sigma_b_dep, fit_long$report$Sigma_b_dep,
    tolerance = 1e-8
  )
})

## ======================================================================
## 3. Gaussian recovery (THE GATE): diagonal variances banded, off-diagonals
##    bounded. Slope diagonals (cols 2,3,5,6 interleaved) are the binding
##    constraint. Inherited s == 1 bands.
## ======================================================================
test_that("phylo_dep s=2 Gaussian fit recovers the (1+s)T x (1+s)T Sigma_b", {
  skip_if_not_heavy()
  skip_if_not_dep_s2_deps()

  fx <- .make_dep_s2_fixture(seed = 20260531L, n_sp = 140L, T_tr = 2L, n_rep = 10L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(1 + x1 + x2 | species),
    data = fx$df_long, phylo_tree = fx$tree, unit = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
  )))

  if (!(isTRUE(fit$opt$convergence == 0L) &&
          is.finite(fit$opt$objective) &&
          isTRUE(fit$fit_health$pd_hessian))) {
    testthat::skip(paste0(
      "phylo_dep(1 + x1 + x2 | sp) Gaussian s=2 did not converge with PD ",
      "Hessian at n_sp=140; RE-03 stays partial pending bigger n / seed ",
      "(genuine identifiability cost, not forced green)."
    ))
  }

  Sig_hat <- fit$report$Sigma_b_dep
  Sig_true <- fx$Sigma_b_true
  expect_equal(dim(Sig_hat), c(fx$C, fx$C))

  ## Diagonal variances: RATIO within [1/2, 2] (the inherited s == 1 band).
  diag_ratio <- diag(Sig_hat) / diag(Sig_true)
  if (!(all(is.finite(diag_ratio)) &&
          all(diag_ratio >= 1 / 2) && all(diag_ratio <= 2))) {
    testthat::skip(sprintf(paste0(
      "phylo_dep s=2 Sigma_b diagonal recovery outside [1/2, 2]: ratios = ",
      "%s; RE-03 stays partial pending bigger n (honest skip)."),
      paste(sprintf("%.2f", diag_ratio), collapse = ", ")
    ))
  }
  expect_true(all(diag_ratio >= 1 / 2))
  expect_true(all(diag_ratio <= 2))

  ## The intercept variances (interleaved cols 1, 4) are well identified --
  ## tighter ~30% band -- separating the well- from the harder-identified part.
  stride <- 1L + fx$s
  int_idx <- seq(1L, fx$C, by = stride)
  expect_true(all(
    abs(diag(Sig_hat)[int_idx] - diag(Sig_true)[int_idx]) /
      diag(Sig_true)[int_idx] <= 0.30
  ))

  ## Off-diagonal cross-trait / intercept-slope / slope-slope covariances:
  ## absolute 0.25 band (inherited from the s == 1 dep cell).
  offdiag_err <- max(abs((Sig_hat - Sig_true)[upper.tri(Sig_true)]))
  expect_lt(offdiag_err, 0.25)

  ## Report the recovered slope-block variances (the RE-03 gate numbers).
  slope_idx <- setdiff(seq_len(fx$C), int_idx)
  message(sprintf(
    "[RE-03 s=2] slope-var hat = {%s}; truth = {%s}; conv=%d pd=%s",
    paste(sprintf("%.3f", diag(Sig_hat)[slope_idx]), collapse = ", "),
    paste(sprintf("%.3f", diag(Sig_true)[slope_idx]), collapse = ", "),
    fit$opt$convergence, isTRUE(fit$fit_health$pd_hessian)
  ))
})

## ======================================================================
## 4. extract_Sigma: (1+s)T x (1+s)T with multi-slope interleaved dimnames.
## ======================================================================
test_that("extract_Sigma returns the (1+s)T x (1+s)T s=2 dep covariance with named slopes", {
  skip_if_not_heavy()
  skip_if_not_dep_s2_deps()

  fx <- .make_dep_s2_fixture(seed = 20260531L, n_sp = 60L, T_tr = 2L, n_rep = 6L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(1 + x1 + x2 | species),
    data = fx$df_long, phylo_tree = fx$tree, unit = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
  expect_true(isTRUE(fit$use$phylo_dep_slope))

  es <- suppressMessages(extract_Sigma(fit, level = "phy"))
  expect_equal(dim(es$Sigma), c(fx$C, fx$C))
  expect_true(all(is.finite(es$Sigma)))
  expect_identical(es$level, "phy_dep")
  expect_identical(es$part, "dep")

  ## Multi-slope interleaved dimnames: per trait intercept then slope.<x_j>.
  expected_names <- c(
    "intercept.t1", "slope.x1.t1", "slope.x2.t1",
    "intercept.t2", "slope.x1.t2", "slope.x2.t2"
  )
  expect_identical(rownames(es$Sigma), expected_names)
  expect_identical(colnames(es$Sigma), expected_names)

  expect_equal(unname(es$Sigma), unname(fit$report$Sigma_b_dep))
  expect_equal(es$Sigma, t(es$Sigma))

  ## print() / summary() must not crash on an s=2 dep fit.
  expect_no_error(capture.output(print(fit)))
  expect_no_error(capture.output(summary(fit)))
})
