## Design 55 §A2 + Design 56 §9.5c -- phylo_dep(1 + x | sp) Gaussian.
##
## phylo_dep(1 + x | species) fits a SINGLE full unstructured 2T x 2T
## covariance Sigma_b over the trait-stacked (intercept, slope) random-effect
## columns. The validated column ordering is INTERLEAVED --
## (alpha_t0, beta_t0, alpha_t1, beta_t1, ...) -- intercept then slope, per
## trait. (NOT all-intercepts || all-slopes.) Z, the extractor dimnames, and
## every assertion below follow that interleaving.
##
## Coverage:
##   - Wide <-> long byte-identity (Design 55 §3): identical Z_phy_aug, logLik,
##     and Sigma_b_dep between traits(...) ~ 1 + phylo_dep(1 + x | sp) and the
##     explicit long surface.
##   - Gaussian recovery (n_sp >= 80). The 2T x 2T Sigma_b estimator is
##     CONSISTENT-NOT-UNBIASED at fixed n: each single realized B ~ MN(0, A,
##     Sigma_b) draw deviates by genuine finite-sample sampling variability,
##     not bias. Empirically (this seed, n_sp = 80; and confirmed at n_sp =
##     100/120/150): intercept variances recover well, but the SLOPE variances
##     are the hardest entries (they need within-species x-variation) and a
##     single draw can sit ~1.5x off truth. The documented bands here reflect
##     what one n_sp = 80 realization actually delivers rather than a
##     cherry-picked seed: diagonal variance RATIO within [1/2, 2] (the slope
##     diagonals are the binding constraint), and off-diagonal cross-trait /
##     intercept-slope covariances within an absolute 0.25 (the recovery spike
##     shows max abs off-diagonal Sigma error ~0.13 at n_sp = 80).
##   - Density smoke: TMB nll matches the analytic matrix-normal prior density
##     for a fixed known L / B to < 1e-9 (ports the dep density-check spike).
##   - Negative tests (fail-loud, Design 56 §7): forcing n_lhs_cols back to the
##     closed-form cap aborts; a 2T-vs-1 dimension mismatch aborts.
##   - C2 extractor: extract_Sigma() on a dep fit returns a finite 2T x 2T with
##     interleaved dimnames.

skip_if_not_dep_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Known PD lower-triangular Cholesky factor of the 2T x 2T Sigma_b (column-
## major lower-tri incl diag), shared by the recovery + density-smoke cases.
## Matches the committed recovery / density spikes
## (docs/dev-log/spikes/2026-05-30-phylo-dep-slope-*.R).
.dep_Ltrue <- function(C) {
  L <- matrix(0, C, C)
  stopifnot(C == 4L)
  L[lower.tri(L, diag = TRUE)] <- c(
    0.8, 0.2, -0.1, 0.15, # col 1 (rows 1..4)
    0.6, 0.1, -0.05, # col 2 (rows 2..4)
    0.5, 0.1, # col 3 (rows 3..4)
    0.45 # col 4 (row 4)
  )
  L
}

## Draw the n_sp x 2T augmented effect matrix B ~ MN(0, A_phy, Sigma_b) with
## INTERLEAVED columns (alpha_t, beta_t). Returns tree + B + Sigma_b_true.
.make_dep_fixture <- function(seed, n_sp, T_tr, n_rep) {
  set.seed(seed)
  C <- 2L * T_tr
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Ltrue <- .dep_Ltrue(C)
  Sigma_b_true <- Ltrue %*% t(Ltrue)
  Cphy <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(Cphy + diag(1e-8, n_sp)))
  B <- (LA %*% matrix(stats::rnorm(n_sp * C), n_sp, C)) %*% chol(Sigma_b_true)
  rownames(B) <- tree$tip.label

  sr <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
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
  si <- match(as.character(df_long$species), tree$tip.label)
  mu_t <- seq(1, by = -0.5, length.out = T_tr)[ti]
  alpha <- B[cbind(si, 2L * (ti - 1L) + 1L)] # interleaved intercept col
  beta <- B[cbind(si, 2L * (ti - 1L) + 2L)] # interleaved slope col
  df_long$value <- mu_t + alpha + beta * df_long$x +
    stats::rnorm(nrow(df_long), sd = 0.3)

  list(
    tree = tree, df_long = df_long, B = B,
    Sigma_b_true = Sigma_b_true, T_tr = T_tr, C = C
  )
}

## ======================================================================
## 1. Wide <-> long byte-identity (Design 55 §3, interleaved ordering).
## ======================================================================
test_that("phylo_dep wide and long Gaussian fits are byte-identical", {
  skip_if_not_heavy()
  skip_if_not_dep_slope_deps()
  testthat::skip_if_not_installed("tidyr")

  fx <- .make_dep_fixture(seed = 778L, n_sp = 60L, T_tr = 2L, n_rep = 5L)
  df_wide <- as.data.frame(tidyr::pivot_wider(
    fx$df_long,
    id_cols = c(species, rep, x),
    names_from = trait,
    values_from = value
  ))
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(0 + trait + (0 + trait):x | species),
    data = fx$df_long, phylo_tree = fx$tree, unit = "species", control = ctl
  )))
  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(t1, t2) ~ 1 + phylo_dep(1 + x | species),
    data = df_wide, phylo_tree = fx$tree, unit = "species", control = ctl
  )))

  ## Both route to the dep path with C = 2T = 4 interleaved columns.
  expect_identical(fit_long$tmb_data$use_phylo_dep_slope, 1L)
  expect_identical(fit_wide$tmb_data$use_phylo_dep_slope, 1L)
  expect_identical(fit_long$tmb_data$n_lhs_cols, fx$C)
  expect_identical(fit_wide$tmb_data$n_lhs_cols, fx$C)

  ## Same constructed likelihood problem.
  expect_identical(fit_wide$tmb_data$y, fit_long$tmb_data$y)
  expect_identical(fit_wide$tmb_data$trait_id, fit_long$tmb_data$trait_id)
  expect_identical(
    fit_wide$tmb_data$species_aug_id,
    fit_long$tmb_data$species_aug_id
  )
  expect_identical(fit_wide$tmb_data$Z_phy_aug, fit_long$tmb_data$Z_phy_aug)

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
## 2. Interleaved Z structure (per-trait intercept + slope columns).
## ======================================================================
test_that("phylo_dep builds the interleaved 2T-wide Z design array", {
  skip_if_not_heavy()
  skip_if_not_dep_slope_deps()

  fx <- .make_dep_fixture(seed = 778L, n_sp = 30L, T_tr = 2L, n_rep = 4L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(1 + x | species),
    data = fx$df_long, phylo_tree = fx$tree, unit = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
  Z <- fit$tmb_data$Z_phy_aug
  expect_equal(dim(Z), c(nrow(fx$df_long), fx$C, 1L))

  trid <- fit$tmb_data$trait_id # 0-based
  xvec <- fit$tmb_data$x_phy_slope
  ## Each row activates exactly its own trait's (intercept, slope) pair:
  ## column 2*t0+1 == 1 and column 2*t0+2 == x; all other columns 0.
  for (o in seq_len(nrow(fx$df_long))) {
    t0 <- trid[o]
    expect_equal(Z[o, 2L * t0 + 1L, 1L], 1.0)
    expect_equal(Z[o, 2L * t0 + 2L, 1L], xvec[o])
    other <- setdiff(seq_len(fx$C), c(2L * t0 + 1L, 2L * t0 + 2L))
    expect_true(all(Z[o, other, 1L] == 0))
  }
})

## ======================================================================
## 3. Gaussian recovery: diagonal variances tight, off-diagonals banded.
## ======================================================================
test_that("phylo_dep Gaussian fit recovers the 2T x 2T Sigma_b", {
  skip_if_not_heavy()
  skip_if_not_dep_slope_deps()

  fx <- .make_dep_fixture(seed = 20260530L, n_sp = 80L, T_tr = 2L, n_rep = 8L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(1 + x | species),
    data = fx$df_long, phylo_tree = fx$tree, unit = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_true(isTRUE(fit$fit_health$pd_hessian))

  Sig_hat <- fit$report$Sigma_b_dep
  Sig_true <- fx$Sigma_b_true
  expect_equal(dim(Sig_hat), c(fx$C, fx$C))

  ## Diagonal variances: RATIO within [1/2, 2]. The slope diagonals (cols 2,4
  ## interleaved) are the binding constraint at fixed n; intercept diagonals
  ## (cols 1,3) recover tighter. See header note on the consistent-not-
  ## unbiased band.
  diag_ratio <- diag(Sig_hat) / diag(Sig_true)
  expect_true(all(is.finite(diag_ratio)))
  expect_true(all(diag_ratio >= 1 / 2))
  expect_true(all(diag_ratio <= 2))
  ## The intercept variances (interleaved cols 1, 3) are well identified --
  ## tighter ~25% band -- separating the well- from the harder-identified part.
  int_idx <- seq(1L, fx$C, by = 2L)
  expect_true(all(
    abs(diag(Sig_hat)[int_idx] - diag(Sig_true)[int_idx]) /
      diag(Sig_true)[int_idx] <= 0.25
  ))

  ## Off-diagonal cross-trait / intercept-slope covariances: absolute 0.25
  ## band (recovery spike max abs off-diagonal Sigma error ~0.13 at n_sp=80).
  offdiag_err <- max(abs((Sig_hat - Sig_true)[upper.tri(Sig_true)]))
  expect_lt(offdiag_err, 0.25)
})

## ======================================================================
## 4. Density smoke: TMB nll == analytic matrix-normal prior density.
##    Ports docs/dev-log/spikes/2026-05-30-phylo-dep-slope-density-check.R to
##    a small C = 4 testthat case (< 1e-9).
## ======================================================================
test_that("phylo_dep TMB nll matches the analytic matrix-normal density", {
  skip_if_not_heavy()
  skip_if_not_dep_slope_deps()

  set.seed(7)
  T_tr <- 2L
  C <- 2L * T_tr
  n_sp <- 12L
  n_rep <- 3L
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  sr <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep)
  )
  sr$x <- stats::rnorm(nrow(sr))
  trait_levels <- paste0("t", seq_len(T_tr))
  df <- merge(
    sr,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df <- df[order(df$species, df$rep, df$trait), ]
  df$value <- stats::rnorm(nrow(df))

  ## Build a dep scaffold fit (no optimisation needed; we evaluate at a fixed
  ## known parameter point).
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(1 + x | species),
    data = df, phylo_tree = tree, unit = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
  expect_identical(fit$tmb_data$use_phylo_dep_slope, 1L)
  expect_identical(fit$tmb_data$n_lhs_cols, C)

  dat <- fit$tmb_data
  par <- fit$tmb_params
  map <- fit$tmb_map
  n_aug <- dat$n_aug_phy
  n_obs <- length(dat$y)
  trid <- dat$trait_id
  xvec <- dat$x_phy_slope

  ## KNOWN L (chol of Sigma_b) and KNOWN B.
  Ltrue <- matrix(0, C, C)
  Ltrue[lower.tri(Ltrue, diag = TRUE)] <- c(
    0.9, 0.3, -0.2, 0.1, 0.7, 0.15, -0.1, 0.6, 0.2, 0.5
  )
  theta <- numeric(C * (C + 1L) / 2L)
  idx <- 1L
  for (j in 1:C) {
    theta[idx] <- log(Ltrue[j, j])
    idx <- idx + 1L
  }
  for (j in 1:(C - 1L)) {
    for (i in (j + 1L):C) {
      theta[idx] <- Ltrue[i, j]
      idx <- idx + 1L
    }
  }
  Sigma_b <- Ltrue %*% t(Ltrue)

  set.seed(99)
  Bfix <- matrix(stats::rnorm(n_aug * C), n_aug, C)
  par$b_phy_aug <- array(Bfix, dim = c(n_aug, C, 1L))
  par$theta_dep_chol <- theta
  map$b_phy_aug <- NULL
  map$theta_dep_chol <- NULL

  obj <- TMB::MakeADFun(
    data = dat, parameters = par, map = map,
    DLL = "gllvmTMB", silent = TRUE
  )
  nll_total <- obj$fn(obj$par)

  ## Analytic matrix-normal prior nll for vec(B) ~ N(0, Sigma_b (x) A).
  Ainv <- as.matrix(dat$Ainv_phy_rr)
  logdetA <- dat$log_det_A_phy_rr
  Q <- t(Bfix) %*% Ainv %*% Bfix
  Sinv <- solve(Sigma_b)
  quad <- sum(diag(Sinv %*% Q))
  nll_prior_R <- 0.5 * (n_aug * C * log(2 * pi) +
    n_aug * log(det(Sigma_b)) + C * logdetA + quad)

  ## Gaussian data-likelihood (reconstruct eta with the fixed B).
  eta <- as.numeric(dat$X_fix %*% par$b_fix)
  for (o in seq_len(n_obs)) {
    t0 <- trid[o]
    s <- dat$species_aug_id[o] + 1L
    eta[o] <- eta[o] + Bfix[s, 2L * t0 + 1L] * 1.0 +
      Bfix[s, 2L * t0 + 2L] * xvec[o]
  }
  sigma_eps <- exp(par$log_sigma_eps)
  nll_data_R <- -sum(stats::dnorm(dat$y, eta, sigma_eps, log = TRUE))

  ## Only the dep augmented prior + Gaussian data-lik are active in this
  ## scaffold (assert no other use_* flag is on besides the phylo slope ones).
  flags_on <- names(dat)[
    grepl("^use_", names(dat)) &
      vapply(
        names(dat),
        function(f) isTRUE(as.integer(dat[[f]]) == 1L),
        logical(1L)
      )
  ]
  expect_setequal(
    flags_on,
    c("use_phylo_slope", "use_phylo_slope_correlated", "use_phylo_dep_slope")
  )

  expect_equal(nll_total - nll_data_R, nll_prior_R, tolerance = 1e-9)
})

## ======================================================================
## 5. Negative tests (fail-loud, Design 56 §7).
## ======================================================================
test_that("phylo_dep aborts when n_lhs_cols is forced back to the 2x2 cap", {
  skip_if_not_heavy()
  skip_if_not_dep_slope_deps()

  fx <- .make_dep_fixture(seed = 5L, n_sp = 12L, T_tr = 2L, n_rep = 2L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(1 + x | species),
    data = fx$df_long, phylo_tree = fx$tree, unit = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))

  ## Re-engage the closed-form 1<=n_lhs_cols<=2 cap while the dep flag still
  ## demands C = 2T: the C++ guard must abort, not silently truncate.
  dat <- fit$tmb_data
  dat$n_lhs_cols <- 2L
  expect_error(
    TMB::MakeADFun(
      data = dat, parameters = fit$tmb_params, map = fit$tmb_map,
      random = "b_phy_aug", DLL = "gllvmTMB", silent = TRUE
    ),
    regexp = "n_lhs_cols does not match augmented phylo arrays"
  )
})

test_that("phylo_dep aborts on a 2T-vs-1 design-array dimension mismatch", {
  skip_if_not_heavy()
  skip_if_not_dep_slope_deps()

  fx <- .make_dep_fixture(seed = 5L, n_sp = 12L, T_tr = 2L, n_rep = 2L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(1 + x | species),
    data = fx$df_long, phylo_tree = fx$tree, unit = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))

  ## Collapse Z to a single column while n_lhs_cols stays 2T: fail loud.
  dat <- fit$tmb_data
  dat$Z_phy_aug <- array(
    dat$Z_phy_aug[, 1L, 1L],
    dim = c(length(dat$y), 1L, 1L)
  )
  expect_error(
    TMB::MakeADFun(
      data = dat, parameters = fit$tmb_params, map = fit$tmb_map,
      random = "b_phy_aug", DLL = "gllvmTMB", silent = TRUE
    ),
    regexp = "n_lhs_cols does not match augmented phylo arrays"
  )
})

test_that("non-Gaussian phylo_dep slope is deferred (fail-loud)", {
  skip_if_not_heavy()
  skip_if_not_dep_slope_deps()

  fx <- .make_dep_fixture(seed = 11L, n_sp = 20L, T_tr = 2L, n_rep = 3L)
  df <- fx$df_long
  df$count <- stats::rpois(nrow(df), lambda = exp(1 + 0.2 * df$x))
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      count ~ 0 + trait + phylo_dep(1 + x | species),
      data = df, phylo_tree = fx$tree, unit = "species",
      family = stats::poisson()
    ))),
    regexp = "not yet supported for this family"
  )
})

## ======================================================================
## 6. C2 extractor: 2T x 2T with interleaved dimnames.
## ======================================================================
test_that("extract_Sigma returns the interleaved 2T x 2T dep covariance", {
  skip_if_not_heavy()
  skip_if_not_dep_slope_deps()

  fx <- .make_dep_fixture(seed = 20260530L, n_sp = 80L, T_tr = 2L, n_rep = 8L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(1 + x | species),
    data = fx$df_long, phylo_tree = fx$tree, unit = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
  )))
  expect_true(isTRUE(fit$use$phylo_dep_slope))
  expect_false(isTRUE(fit$use$phylo_dep)) # distinct from the RR intercept path

  ## The dep covariance is a phylogenetic random effect: surfaced at the
  ## "phy" tier (NOT the unit / unit_obs tiers).
  es <- suppressMessages(extract_Sigma(fit, level = "phy"))
  expect_equal(dim(es$Sigma), c(fx$C, fx$C))
  expect_true(all(is.finite(es$Sigma)))
  expect_identical(es$level, "phy_dep")
  expect_identical(es$part, "dep")

  expected_names <- c("intercept.t1", "slope.t1", "intercept.t2", "slope.t2")
  expect_identical(rownames(es$Sigma), expected_names)
  expect_identical(colnames(es$Sigma), expected_names)
  expect_identical(rownames(es$R), expected_names)

  ## Matches the engine report; symmetric; correlation diag == 1.
  expect_equal(unname(es$Sigma), unname(fit$report$Sigma_b_dep))
  expect_equal(es$Sigma, t(es$Sigma))
  expect_equal(unname(diag(es$R)), rep(1, fx$C), tolerance = 1e-8)

  ## The `part` argument is ignored for the single unstructured block.
  es2 <- suppressMessages(extract_Sigma(fit, level = "phy", part = "shared"))
  expect_equal(es2$Sigma, es$Sigma)

  ## The unit / unit_obs tiers carry no covariance term for a dep-only fit.
  expect_null(extract_Sigma_B(fit))
  expect_null(extract_Sigma_W(fit))

  ## print() and summary() must not crash on a dep fit (the dep block must
  ## not hijack the R_B / R_W summary slots).
  expect_no_error(capture.output(print(fit)))
  expect_no_error(capture.output(summary(fit)))
})
