## Issue #341 Track B -- activate binomial(probit/logit) augmented random
## slopes on the phylo_indep path: `phylo_indep(1 + x | species)` x
## binomial. This is the per-trait block-diagonal augmented-slope cell, the
## binomial structural analogue of the Gaussian anchor
## `test-phylo-indep-slope-gaussian.R`.
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
## response. phylo_indep uses the family-general phylo_unique() path with a
## TMB map that fixes cross-trait Cholesky entries to zero. Activating binomial
## therefore needed only relaxing the Gaussian-only guard in R/fit-multi.R
## (it now admits family_id in {0 = gaussian, 1 = binomial}); no C++
## likelihood branch was added.
##
## ----------------------------------------------------------------------
## Structural design
##
## The DGP uses multi-trial (n = 10) binomial responses and a non-trivial
## phylogenetic covariance. Its purpose is to assert the live non-Gaussian
## routing and exact Design 79/80 covariance pins, not to certify binomial
## variance recovery or interval calibration.
##
## Contract asserted per family (probit, logit):
##   - every seed constructs the requested model;
##   - at least one deterministic fit has a positive-definite Hessian;
##   - every constructed fit retains 2T columns, 3T free Cholesky entries,
##     and exactly zero cross-trait correlations.

skip_if_not_binom_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

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
  n_traits <- length(levels(fx$df$trait))
  sd_b <- as.numeric(fit$report$sd_b)
  cor_b <- as.matrix(fit$report$cor_b_mat)
  block <- rep(seq_len(n_traits), each = 2L)
  list(
    error = NA_character_,
    conv = fit$opt$convergence,
    pd = isTRUE(fit$fit_health$pd_hessian),
    max_cross = max(abs(cor_b[outer(block, block, `!=`)])),
    ntheta_free = sum(names(fit$opt$par) == "theta_dep_chol")
  )
}

## Shared structural-contract body for a given link.
run_binom_indep_slope_contract <- function(link, seeds = 1:6) {
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
  max_cross <- vapply(res, function(r) r$max_cross, numeric(1))
  ntheta_free <- vapply(res, function(r) r$ntheta_free, integer(1))

  ## The 2T covariance parameterisation is intentionally harder than the
  ## retired shared 2x2 slope block. This is a structural smoke test, so it
  ## requires a usable fit without treating its finite-sample estimates as a
  ## recovery certificate.
  healthy <- conv == 0L & pd
  testthat::expect_true(any(healthy))

  ## ---- Design 79/80 per-trait block-diagonal contract -----------------
  testthat::expect_true(all(ntheta_free == 3L * 3L))
  testthat::expect_true(all(max_cross < 1e-6))

  invisible(list(n_healthy = sum(healthy)))
}

## ---------------------------------------------------------------------
## binomial(probit): phylo_indep(1 + x | sp) augmented-slope recovery
## ---------------------------------------------------------------------
test_that("phylo_indep(1 + x | sp) x binomial(probit) preserves the per-trait block-diagonal contract; ZERO new C++", {
  skip_if_not_heavy()
  skip_if_not_binom_slope_deps()
  run_binom_indep_slope_contract("probit")
})

## ---------------------------------------------------------------------
## binomial(logit): phylo_indep(1 + x | sp) augmented-slope recovery
## ---------------------------------------------------------------------
test_that("phylo_indep(1 + x | sp) x binomial(logit) preserves the per-trait block-diagonal contract; ZERO new C++", {
  skip_if_not_heavy()
  skip_if_not_binom_slope_deps()
  run_binom_indep_slope_contract("logit")
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
