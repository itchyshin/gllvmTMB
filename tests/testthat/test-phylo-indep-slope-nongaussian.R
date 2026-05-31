## Issue #341 Track B -- activate the augmented diagonal random-slope cell
## `phylo_indep(1 + x | species)` for the remaining non-Gaussian families:
## poisson, nbinom2, Gamma, Beta, ordinal_probit. This extends the binomial
## anchor (test-binomial-slope-recovery.R, #381) and the Gaussian anchor
## (test-phylo-indep-slope-gaussian.R) to the families whose family-general
## correlated-slope cells already pass (test-matrix-slope-{poisson,nbinom2,
## gamma,beta,ordinal}.R).
##
## ----------------------------------------------------------------------
## Why this is ZERO new C++ (family-agnostic engine)
##
## The augmented-slope contribution enters the linear predictor BEFORE the
## C++ family dispatch:
##
##   src/gllvmTMB.cpp (eta loop):  eta(o) += b_phy_aug . Z_phy_aug   [~L1359]
##   src/gllvmTMB.cpp (likelihood): int fid = family_id_vec(o); ...   [~L1395]
##
## so swapping the family only changes how the SAME eta maps to the
## response. phylo_indep differs from the family-general phylo_unique() path
## solely by pinning atanh_cor_b to 0 via the TMB map (R/fit-multi.R).
## Activating these families therefore needed only relaxing the family guard
## in R/fit-multi.R (it now admits the runtime family ids
## {0 gaussian, 1 binomial, 2 poisson, 4 Gamma, 5 nbinom2, 7 Beta,
## 14 ordinal_probit}); no C++ likelihood branch was added.
##
## ----------------------------------------------------------------------
## Recovery design (mirrors test-binomial-slope-recovery.R + RE-09)
##
## Each family draws a genuinely DIAGONAL Sigma_b (rho = 0), matching the
## phylo_indep model contract, fits a small grid of seeds, and checks
## recovery on the MEAN across the grid (per-seed noise averages out -- the
## RE-09 within-cell-replicate discipline). Per family we assert the same
## contract the binomial anchor asserts:
##   - every seed: opt$convergence == 0 and a positive-definite Hessian;
##   - every seed: atanh_cor_b is mapped to factor(NA) and report$cor_b is
##     EXACTLY 0 (the diagonal-Sigma_b indep contract, not an estimate);
##   - every seed: the runtime family id matches (no silent fallthrough);
##   - mean(sigma^2_intercept) and mean(sigma^2_slope) within the band the
##     SAME family's existing correlated-slope cell uses (NOT a looser
##     invented band): poisson 4x, nbinom2 0.30 relative, Gamma 3x,
##     Beta 0.40 relative, ordinal_probit 2.5x. The diagonal-truth values
##     (sigma^2_int, sigma^2_slope) are inherited from those cells too:
##     (0.4, 0.3) for all except ordinal (0.6, 0.5).
## The intercept-slope correlation band of those cells is NOT inherited:
## the indep DGP draws rho = 0 and the model pins it, so rho is asserted
## EXACTLY 0 rather than recovered within a band.
##
## Bands are NOT widened to force green -- an out-of-band seed-mean is an
## honest failure of the cell, and a family that failed to recover would be
## held reserved (left off the R/fit-multi.R allowlist), not forced in.

skip_if_not_ng_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Shared diagonal-Sigma_b phylo fixture core: (alpha, beta) ~
## N(0, diag(s2_int, s2_slope) (x) A_phy), i.e. cov(intercept, slope) = 0
## (the phylo_indep truth). `star = TRUE` swaps the coalescent tree for a
## star tree (identity tip-correlation), matching the Gamma sibling cell.
make_ng_indep_slope_ab <- function(seed, n_sp, s2_int, s2_slope,
                                    star = FALSE) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  if (star) {
    Cphy <- diag(n_sp)
    rownames(Cphy) <- colnames(Cphy) <- tree$tip.label
  } else {
    Cphy <- ape::vcv(tree, corr = TRUE)
  }
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))
  raw <- matrix(stats::rnorm(n_sp * 2L), nrow = n_sp, ncol = 2L)
  ab <- (Lphy_chol %*% raw) %*% chol(diag(c(s2_int, s2_slope)))
  rownames(ab) <- tree$tip.label
  colnames(ab) <- c("alpha", "beta")
  list(tree = tree, Cphy = Cphy, ab = ab)
}

## Build the long (species, rep, trait) frame with a shared x per
## (species, rep) cell and the augmented intercept + slope draws applied.
make_ng_indep_slope_frame <- function(core, n_traits, n_rep) {
  tip <- core$tree$tip.label
  species_rep <- expand.grid(
    species = factor(tip, levels = tip),
    rep = seq_len(n_rep)
  )
  species_rep$x <- stats::rnorm(nrow(species_rep))  # var(x) ~ 1
  trait_levels <- paste0("t", seq_len(n_traits))
  df <- merge(
    species_rep,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df <- df[order(df$species, df$rep, df$trait), ]
  df$alpha_sp <- core$ab[as.character(df$species), "alpha"]
  df$beta_sp <- core$ab[as.character(df$species), "beta"]
  df
}

## ---- per-family fixture builders (diagonal Sigma_b) ------------------

make_indep_slope_poisson <- function(seed, n_sp = 60L, n_traits = 3L,
                                      n_rep = 4L, intercept_mean = 2) {
  core <- make_ng_indep_slope_ab(seed, n_sp, 0.4, 0.3)
  df <- make_ng_indep_slope_frame(core, n_traits, n_rep)
  eta <- intercept_mean + df$alpha_sp + df$beta_sp * df$x
  df$value <- stats::rpois(nrow(df), lambda = exp(eta))
  list(df = df, tree = core$tree, family = stats::poisson(link = "log"),
       phylo_vcv = NULL)
}

make_indep_slope_nbinom2 <- function(seed, n_sp = 60L, n_traits = 3L,
                                     n_rep = 4L, phi = 2.0) {
  core <- make_ng_indep_slope_ab(seed, n_sp, 0.4, 0.3)
  df <- make_ng_indep_slope_frame(core, n_traits, n_rep)
  mu_t <- c(0.8, 0.7, 0.6)[as.integer(df$trait)]
  eta <- mu_t + df$alpha_sp + df$beta_sp * df$x
  df$value <- stats::rnbinom(nrow(df), mu = exp(eta), size = phi)
  list(df = df, tree = core$tree, family = gllvmTMB::nbinom2(),
       phylo_vcv = NULL)
}

make_indep_slope_gamma <- function(seed, n_sp = 60L, n_traits = 3L,
                                   n_rep = 6L, phi = 2.0) {
  ## Star tree (identity tip-correlation), matching test-matrix-slope-gamma.R.
  core <- make_ng_indep_slope_ab(seed, n_sp, 0.4, 0.3, star = TRUE)
  df <- make_ng_indep_slope_frame(core, n_traits, n_rep)
  mu_t <- c(0.0, 0.1, -0.1)[as.integer(df$trait)]
  mu <- exp(mu_t + df$alpha_sp + df$beta_sp * df$x)
  ## shape = phi (CV = 1/sqrt(phi)); scale = mu / shape.
  df$value <- stats::rgamma(nrow(df), shape = phi, scale = mu / phi)
  list(df = df, tree = core$tree, family = stats::Gamma(link = "log"),
       phylo_vcv = core$Cphy)
}

make_indep_slope_beta <- function(seed, n_sp = 60L, n_traits = 3L,
                                  n_rep = 12L, phi = 5) {
  core <- make_ng_indep_slope_ab(seed, n_sp, 0.4, 0.3)
  df <- make_ng_indep_slope_frame(core, n_traits, n_rep)
  alpha0 <- c(-0.2, 0.0, 0.2)[as.integer(df$trait)]
  mu <- stats::plogis(alpha0 + df$alpha_sp + df$beta_sp * df$x)
  df$value <- stats::rbeta(nrow(df), mu * phi, (1 - mu) * phi)
  list(df = df, tree = core$tree, family = gllvmTMB::Beta(),
       phylo_vcv = NULL)
}

make_indep_slope_ordinal <- function(seed, n_sp = 60L, n_traits = 4L,
                                     n_rep = 6L) {
  core <- make_ng_indep_slope_ab(seed, n_sp, 0.6, 0.5)
  ## ordinal uses all 4 traits; rebuild the frame for n_traits = 4.
  df <- make_ng_indep_slope_frame(core, n_traits, n_rep)
  mu_t <- c(0.7, 0.5, 0.6, 0.4)[as.integer(df$trait)]
  ## sigma_d^2 = 1 EXACT: standard-normal latent residual (threshold model).
  ystar <- mu_t + df$alpha_sp + df$beta_sp * df$x +
    stats::rnorm(nrow(df), 0, 1)
  taus <- c(0, 0.7, 1.4)  # K = 4 ordinal thresholds (3 cutpoints)
  df$value <- as.integer(
    1L + colSums(outer(taus, ystar, FUN = function(t, y) y > t))
  )
  list(df = df, tree = core$tree, family = gllvmTMB::ordinal_probit(),
       phylo_vcv = NULL)
}

## Fit one seed of a family's diagonal augmented-slope cell. Returns NA
## fields on a construction error so the caller can fail loudly (a
## construction failure is NOT an honest skip -- these family paths are
## meant to be live now that they are on the R/fit-multi.R allowlist).
fit_ng_indep_slope <- function(fx) {
  args <- list(
    formula = value ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df,
    unit = "species",
    family = fx$family,
    control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
  )
  if (is.null(fx$phylo_vcv)) {
    args$phylo_tree <- fx$tree
  } else {
    args$phylo_vcv <- fx$phylo_vcv
  }
  fit <- tryCatch(
    suppressMessages(suppressWarnings(do.call(gllvmTMB::gllvmTMB, args))),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    return(list(error = conditionMessage(fit)))
  }
  sd_b <- as.numeric(fit$report$sd_b)
  list(
    error = NA_character_,
    conv = fit$opt$convergence,
    pd = isTRUE(fit$fit_health$pd_hessian),
    v_int = sd_b[1L]^2,
    v_slope = sd_b[2L]^2,
    rho = as.numeric(fit$report$cor_b)[1L],
    ## phylo_indep contract: atanh_cor_b mapped to factor(NA).
    cor_mapped = !is.null(fit$tmb_map$atanh_cor_b),
    fid = as.integer(fit$tmb_data$family_id_vec[1L])
  )
}

## Shared recovery body. `band` is the inherited band; `band_form` selects
## the inherited band shape ("mult" = hat/truth must lie in (1/band, band);
## "rel" = relative error must be <= band). `fid_expected` guards against a
## silent family fallthrough.
run_ng_indep_slope_recovery <- function(builder, s2_int, s2_slope,
                                        band, band_form, fid_expected,
                                        seeds = 1:6) {
  res <- lapply(seeds, function(s) fit_ng_indep_slope(builder(s)))

  errs <- vapply(res, function(r) r$error, character(1))
  testthat::expect_true(
    all(is.na(errs)),
    label = sprintf("all seeds construct (got: %s)",
                    paste(stats::na.omit(errs), collapse = "; "))
  )

  conv <- vapply(res, function(r) r$conv, integer(1))
  pd <- vapply(res, function(r) r$pd, logical(1))
  rho <- vapply(res, function(r) r$rho, numeric(1))
  cor_mapped <- vapply(res, function(r) r$cor_mapped, logical(1))
  fid <- vapply(res, function(r) r$fid, integer(1))
  v_int <- vapply(res, function(r) r$v_int, numeric(1))
  v_slope <- vapply(res, function(r) r$v_slope, numeric(1))

  ## ---- Fit health on EVERY seed ---------------------------------------
  testthat::expect_true(all(conv == 0L))
  testthat::expect_true(all(pd))

  ## ---- Family really is the claimed family (no fallthrough) -----------
  testthat::expect_true(all(fid == fid_expected))

  ## ---- phylo_indep diagonal contract: rho held EXACTLY at 0 -----------
  testthat::expect_true(all(cor_mapped))
  testthat::expect_true(all(rho == 0))

  ## ---- Seed-averaged variance recovery (RE-09 within-cell replicate) --
  mean_v_int <- mean(v_int)
  mean_v_slope <- mean(v_slope)

  if (identical(band_form, "rel")) {
    int_metric <- abs(mean_v_int - s2_int) / s2_int
    slope_metric <- abs(mean_v_slope - s2_slope) / s2_slope
    testthat::expect_lte(int_metric, band)
    testthat::expect_lte(slope_metric, band)
  } else {
    int_ratio <- mean_v_int / s2_int
    slope_ratio <- mean_v_slope / s2_slope
    testthat::expect_gt(int_ratio, 1 / band)
    testthat::expect_lt(int_ratio, band)
    testthat::expect_gt(slope_ratio, 1 / band)
    testthat::expect_lt(slope_ratio, band)
  }

  invisible(list(mean_v_int = mean_v_int, mean_v_slope = mean_v_slope))
}

## ---------------------------------------------------------------------
## poisson(log): inherited 4x variance band (test-matrix-slope-poisson.R)
## ---------------------------------------------------------------------
test_that("phylo_indep(1 + x | sp) x poisson recovers diagonal Sigma_b (rho pinned 0); ZERO new C++", {
  skip_if_not_heavy()
  skip_if_not_ng_slope_deps()
  run_ng_indep_slope_recovery(
    make_indep_slope_poisson, s2_int = 0.4, s2_slope = 0.3,
    band = 4, band_form = "mult", fid_expected = 2L
  )
})

## ---------------------------------------------------------------------
## nbinom2: inherited 0.30 relative variance band (test-matrix-slope-nbinom2.R)
## ---------------------------------------------------------------------
test_that("phylo_indep(1 + x | sp) x nbinom2 recovers diagonal Sigma_b (rho pinned 0); ZERO new C++", {
  skip_if_not_heavy()
  skip_if_not_ng_slope_deps()
  run_ng_indep_slope_recovery(
    make_indep_slope_nbinom2, s2_int = 0.4, s2_slope = 0.3,
    band = 0.30, band_form = "rel", fid_expected = 5L
  )
})

## ---------------------------------------------------------------------
## Gamma(log): inherited 3x variance band (test-matrix-slope-gamma.R)
## ---------------------------------------------------------------------
test_that("phylo_indep(1 + x | sp) x Gamma recovers diagonal Sigma_b (rho pinned 0); ZERO new C++", {
  skip_if_not_heavy()
  skip_if_not_ng_slope_deps()
  run_ng_indep_slope_recovery(
    make_indep_slope_gamma, s2_int = 0.4, s2_slope = 0.3,
    band = 3, band_form = "mult", fid_expected = 4L
  )
})

## ---------------------------------------------------------------------
## Beta: inherited 0.40 relative variance band (test-matrix-slope-beta.R)
## ---------------------------------------------------------------------
test_that("phylo_indep(1 + x | sp) x Beta recovers diagonal Sigma_b (rho pinned 0); ZERO new C++", {
  skip_if_not_heavy()
  skip_if_not_ng_slope_deps()
  run_ng_indep_slope_recovery(
    make_indep_slope_beta, s2_int = 0.4, s2_slope = 0.3,
    band = 0.40, band_form = "rel", fid_expected = 7L
  )
})

## ---------------------------------------------------------------------
## ordinal_probit: inherited 2.5x variance band, truths (0.6, 0.5)
## (test-matrix-slope-ordinal.R)
## ---------------------------------------------------------------------
test_that("phylo_indep(1 + x | sp) x ordinal_probit recovers diagonal Sigma_b (rho pinned 0); ZERO new C++", {
  skip_if_not_heavy()
  skip_if_not_ng_slope_deps()
  run_ng_indep_slope_recovery(
    make_indep_slope_ordinal, s2_int = 0.6, s2_slope = 0.5,
    band = 2.5, band_form = "mult", fid_expected = 14L
  )
})
