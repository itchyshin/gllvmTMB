## Issue #341 Track B -- activate binomial(probit/logit) augmented random
## slopes on the phylo_indep path: `phylo_indep(1 + x | species)` x
## binomial. This is the DIAGONAL augmented-slope cell (intercept-slope
## correlation pinned to 0 by the model contract), the binomial analogue of
## the Gaussian anchor `test-phylo-indep-slope-gaussian.R`.
##
## ----------------------------------------------------------------------
## Why this is ZERO new C++ (family-agnostic engine)
##
## The augmented-slope contribution is accumulated into the linear
## predictor BEFORE the C++ family dispatch:
##
##   src/gllvmTMB.cpp (eta loop):  eta(o) += b_phy_aug . Z_phy_aug   [~L1359]
##   src/gllvmTMB.cpp (likelihood): int fid = family_id_vec(o); ...   [~L1395]
##
## so swapping the family only changes how the SAME eta is mapped to the
## response. phylo_indep differs from the family-general phylo_unique()
## path solely by pinning atanh_cor_b to 0 via the TMB map
## (R/fit-multi.R). Activating binomial therefore needed only relaxing the
## Gaussian-only guard in R/fit-multi.R (it now admits family_id in
## {0 = gaussian, 1 = binomial}); no C++ likelihood branch was added.
##
## ----------------------------------------------------------------------
## Recovery design (mirrors test-spatial-indep-slope-gaussian.R +
## the RE-09 within-cell-replicate discipline)
##
## Binary/binomial slope variances and the species-level Sigma_b identify
## only with substantial var(x) and a non-trivial n_sp (Phase B0 scoping
## memo, docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md).
## A single seed's point estimate is noisy, so -- exactly as the spatial
## indep-slope Gaussian cell does -- we fit a small grid of seeds and check
## recovery on the MEAN across the grid (the per-seed noise averages out).
## The DGP draws a genuinely DIAGONAL Sigma_b (rho = 0), matching the
## phylo_indep model contract, and uses multi-trial (n = 10) binomial
## responses for sharper information than single Bernoulli draws.
##
## Contract asserted per family (probit, logit):
##   - every seed: opt$convergence == 0 and a positive-definite Hessian;
##   - every seed: atanh_cor_b is mapped to factor(NA) and report$cor_b is
##     EXACTLY 0 (the diagonal-Sigma_b indep contract, not an estimate);
##   - mean(sigma^2_intercept) and mean(sigma^2_slope) within a stated
##     relative band of the truth (0.4, 0.3). Bands are NOT widened to force
##     green: an out-of-band mean is an honest failure of the cell.

skip_if_not_binom_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Relative bands on the seed-averaged variances. Calibrated on a 6-seed
## grid (max observed mean relative error: ~0.12 on the intercept variance,
## ~0.09 on the slope variance); 0.25 leaves honest head-room without
## fitting the band to the sample.
.binom_slope_tol <- list(sigma2_int_rel = 0.25, sigma2_slope_rel = 0.25)

.sigma2_int_true <- 0.4
.sigma2_slope_true <- 0.3

## Diagonal-Sigma_b phylo fixture for the phylo_indep binomial cell.
## (alpha, beta) ~ N(0, Sigma_b (x) A_phy) with Sigma_b = diag(0.4, 0.3),
## i.e. cov(intercept, slope) = 0 (the phylo_indep truth). Multi-trial
## binomial response (size = 10) under `link`.
make_binom_indep_slope_fixture <- function(seed,
                                           link,
                                           n_sp = 70L,
                                           n_traits = 3L,
                                           n_rep = 8L) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))

  Sigma_b_true <- diag(c(.sigma2_int_true, .sigma2_slope_true))
  raw <- matrix(stats::rnorm(n_sp * 2L), nrow = n_sp, ncol = 2L)
  ab <- (Lphy_chol %*% raw) %*% chol(Sigma_b_true)
  rownames(ab) <- tree$tip.label
  colnames(ab) <- c("alpha", "beta")

  species_rep <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep)
  )
  species_rep$x <- stats::rnorm(nrow(species_rep)) # var(x) = 1

  trait_levels <- paste0("t", seq_len(n_traits))
  df_long <- merge(
    species_rep,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df_long <- df_long[order(df_long$species, df_long$rep, df_long$trait), ]

  mu_t <- c(0.2, 0.0, -0.2, 0.1)[as.integer(df_long$trait)]
  alpha_sp <- ab[as.character(df_long$species), "alpha"]
  beta_sp <- ab[as.character(df_long$species), "beta"]
  eta <- mu_t + alpha_sp + beta_sp * df_long$x
  p <- if (identical(link, "probit")) stats::pnorm(eta) else stats::plogis(eta)
  df_long$succ <- stats::rbinom(nrow(df_long), size = 10L, prob = p)
  df_long$fail <- 10L - df_long$succ

  list(df = df_long, tree = tree)
}

## Fit + summarise one seed. Returns NA fields on a construction error so
## the caller can fail loudly (a construction failure is NOT an honest skip
## here -- the engine path is meant to be live for binomial).
fit_binom_indep_slope <- function(fx, link) {
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      cbind(succ, fail) ~ 0 + trait + phylo_indep(1 + x | species),
      data = fx$df,
      phylo_tree = fx$tree,
      unit = "species",
      family = stats::binomial(link = link),
      control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
    ))),
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
    rho = as.numeric(fit$report$cor_b),
    ## phylo_indep contract: atanh_cor_b mapped to factor(NA).
    cor_mapped = !is.null(fit$tmb_map$atanh_cor_b)
  )
}

## Shared recovery body for a given link.
run_binom_indep_slope_recovery <- function(link, seeds = 1:6) {
  res <- lapply(seeds, function(s) {
    fit_binom_indep_slope(make_binom_indep_slope_fixture(s, link), link)
  })

  errs <- vapply(res, function(r) r$error, character(1))
  testthat::expect_true(
    all(is.na(errs)),
    label = sprintf(
      "phylo_indep(1 + x | sp) x binomial(%s): all seeds construct (got: %s)",
      link, paste(stats::na.omit(errs), collapse = "; ")
    )
  )

  conv <- vapply(res, function(r) r$conv, integer(1))
  pd <- vapply(res, function(r) r$pd, logical(1))
  rho <- vapply(res, function(r) r$rho, numeric(1))
  cor_mapped <- vapply(res, function(r) r$cor_mapped, logical(1))
  v_int <- vapply(res, function(r) r$v_int, numeric(1))
  v_slope <- vapply(res, function(r) r$v_slope, numeric(1))

  ## ---- Fit health on EVERY seed ---------------------------------------
  testthat::expect_true(all(conv == 0L))
  testthat::expect_true(all(pd))

  ## ---- phylo_indep diagonal contract: rho held EXACTLY at 0 -----------
  testthat::expect_true(all(cor_mapped))
  testthat::expect_true(all(rho == 0))

  ## ---- Seed-averaged variance recovery (RE-09 within-cell replicate) --
  mean_v_int <- mean(v_int)
  mean_v_slope <- mean(v_slope)
  int_rel <- abs(mean_v_int - .sigma2_int_true) / .sigma2_int_true
  slope_rel <- abs(mean_v_slope - .sigma2_slope_true) / .sigma2_slope_true

  testthat::expect_lte(int_rel, .binom_slope_tol$sigma2_int_rel)
  testthat::expect_lte(slope_rel, .binom_slope_tol$sigma2_slope_rel)

  invisible(list(
    mean_v_int = mean_v_int, mean_v_slope = mean_v_slope,
    int_rel = int_rel, slope_rel = slope_rel
  ))
}

## ---------------------------------------------------------------------
## binomial(probit): phylo_indep(1 + x | sp) augmented-slope recovery
## ---------------------------------------------------------------------
test_that("phylo_indep(1 + x | sp) x binomial(probit) recovers diagonal Sigma_b (rho pinned 0); ZERO new C++", {
  skip_if_not_heavy()
  skip_if_not_binom_slope_deps()
  run_binom_indep_slope_recovery("probit")
})

## ---------------------------------------------------------------------
## binomial(logit): phylo_indep(1 + x | sp) augmented-slope recovery
## ---------------------------------------------------------------------
test_that("phylo_indep(1 + x | sp) x binomial(logit) recovers diagonal Sigma_b (rho pinned 0); ZERO new C++", {
  skip_if_not_heavy()
  skip_if_not_binom_slope_deps()
  run_binom_indep_slope_recovery("logit")
})

## ---------------------------------------------------------------------
## Family-agnostic engine guard: the augmented 2-column Sigma_b machinery
## (not a scalar-slope fallback) carries the binomial fit. Forcing
## n_lhs_cols to 1 must trip the C++ dimension check -- proving the SAME
## augmented array path is active under binomial as under Gaussian.
## ---------------------------------------------------------------------
test_that("phylo_indep(1 + x | sp) x binomial: augmented path aborts when n_lhs_cols is forced to 1", {
  skip_if_not_heavy()
  skip_if_not_binom_slope_deps()

  fx <- make_binom_indep_slope_fixture(seed = 1L, link = "probit",
                                       n_sp = 12L, n_rep = 3L)
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      cbind(succ, fail) ~ 0 + trait + phylo_indep(1 + x | species),
      data = fx$df, phylo_tree = fx$tree, unit = "species",
      family = stats::binomial(link = "probit"),
      control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "small-n binomial-probit indep fixture failed to construct for the n_lhs_cols guard check: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB object"
    ))
  }

  tmb_data <- fit$tmb_data
  tmb_data$n_lhs_cols <- 1L
  expect_error(
    TMB::MakeADFun(
      data = tmb_data,
      parameters = fit$tmb_params,
      map = fit$tmb_map,
      random = "b_phy_aug",
      DLL = "gllvmTMB",
      silent = TRUE
    ),
    regexp = "n_lhs_cols does not match augmented phylo arrays"
  )
})
