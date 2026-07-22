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
## response. phylo_indep uses the family-general augmented path with a TMB
## map that fixes cross-trait Cholesky entries to zero while leaving each
## trait's intercept--slope correlation free. Activating binomial therefore
## needed no family-specific C++ likelihood branch.
##
## ----------------------------------------------------------------------
## Structural design
##
## The DGP uses multi-trial (n = 10) binomial responses and separate
## phylogenetically correlated intercept/slope draws for each trait. It is
## aligned with the current 2T parameterisation, but this test intentionally
## does not certify variance recovery or interval calibration.
##
## Contract asserted per family (probit, logit):
##   - one predeclared deterministic seed constructs and is numerically healthy;
##   - the live engine has 2T columns and 3T free Cholesky entries;
##   - the reported correlation matrix has unit diagonal and zero cross-trait
##     blocks, while within-trait correlations remain estimator parameters.

skip_if_not_binom_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

.sigma2_int_true <- 0.4
.sigma2_slope_true <- 0.3

## Per-trait block-diagonal phylogenetic fixture for the binomial cell.
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
  trait_levels <- paste0("t", seq_len(n_traits))
  ab <- array(
    NA_real_,
    dim = c(n_sp, 2L, n_traits),
    dimnames = list(tree$tip.label, c("alpha", "beta"), trait_levels)
  )
  for (tt in seq_len(n_traits)) {
    raw <- matrix(stats::rnorm(n_sp * 2L), nrow = n_sp, ncol = 2L)
    ab[, , tt] <- (Lphy_chol %*% raw) %*% chol(Sigma_b_true)
  }

  species_rep <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep)
  )
  species_rep$x <- stats::rnorm(nrow(species_rep)) # var(x) = 1

  df_long <- merge(
    species_rep,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df_long <- df_long[order(df_long$species, df_long$rep, df_long$trait), ]

  mu_t <- seq(0.2, -0.2, length.out = n_traits)[as.integer(df_long$trait)]
  sp_idx <- match(as.character(df_long$species), tree$tip.label)
  trait_idx <- as.integer(df_long$trait)
  alpha_sp <- ab[cbind(sp_idx, 1L, trait_idx)]
  beta_sp <- ab[cbind(sp_idx, 2L, trait_idx)]
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
  n_traits <- nlevels(fx$df$trait)
  cor_b <- as.matrix(fit$report$cor_b_mat)
  block <- rep(seq_len(n_traits), each = 2L)
  cross <- outer(block, block, `!=`)
  chol_map <- as.integer(fit$tmb_map$theta_dep_chol)
  list(
    error = NA_character_,
    conv = fit$opt$convergence,
    pd = isTRUE(fit$fit_health$pd_hessian),
    finite_objective = is.finite(fit$opt$objective),
    max_gradient = fit$fit_health$max_gradient,
    n_traits = n_traits,
    n_lhs_cols = fit$tmb_data$n_lhs_cols,
    ntheta_map = sum(!is.na(chol_map)),
    ntheta_opt = sum(names(fit$opt$par) == "theta_dep_chol"),
    diag_error = max(abs(diag(cor_b) - 1)),
    max_cross = max(abs(cor_b[cross]))
  )
}

## Shared structural-contract body for one predeclared deterministic seed.
run_binom_indep_slope_contract <- function(link, seed = 1L) {
  res <- fit_binom_indep_slope(
    make_binom_indep_slope_fixture(seed, link),
    link
  )
  testthat::expect_true(
    is.na(res$error),
    label = sprintf(
      "phylo_indep(1 + x | sp) x binomial(%s) constructs (got: %s)",
      link, res$error
    )
  )
  if (!is.na(res$error)) {
    return(invisible(res))
  }

  testthat::expect_identical(res$conv, 0L)
  testthat::expect_true(res$pd)
  testthat::expect_true(res$finite_objective)
  testthat::expect_true(is.finite(res$max_gradient))
  testthat::expect_lt(res$max_gradient, 1e-2)
  testthat::expect_equal(res$n_lhs_cols, 2L * res$n_traits)
  testthat::expect_equal(res$ntheta_map, 3L * res$n_traits)
  testthat::expect_equal(res$ntheta_opt, 3L * res$n_traits)
  testthat::expect_lt(res$diag_error, 1e-10)
  testthat::expect_lt(res$max_cross, 1e-10)
  invisible(res)
}

## ---------------------------------------------------------------------
## binomial(probit): phylo_indep(1 + x | sp) structural contract
## ---------------------------------------------------------------------
test_that("phylo_indep(1 + x | sp) x binomial(probit) preserves the per-trait block-diagonal contract; ZERO new C++", {
  skip_if_not_heavy()
  skip_if_not_binom_slope_deps()
  run_binom_indep_slope_contract("probit")
})

## ---------------------------------------------------------------------
## binomial(logit): phylo_indep(1 + x | sp) structural contract
## ---------------------------------------------------------------------
test_that("phylo_indep(1 + x | sp) x binomial(logit) preserves the per-trait block-diagonal contract; ZERO new C++", {
  skip_if_not_heavy()
  skip_if_not_binom_slope_deps()
  run_binom_indep_slope_contract("logit")
})

test_that("phylo_indep augmented slopes reject binomial cloglog before TMB construction", {
  skip_if_not_binom_slope_deps()

  fx <- make_binom_indep_slope_fixture(
    seed = 1L,
    link = "cloglog",
    n_sp = 8L,
    n_traits = 2L,
    n_rep = 2L
  )
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      cbind(succ, fail) ~ 0 + trait + phylo_indep(1 + x | species),
      data = fx$df,
      phylo_tree = fx$tree,
      unit = "species",
      family = stats::binomial(link = "cloglog"),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ))),
    "logit/probit only"
  )
})

## ---------------------------------------------------------------------
## Family-agnostic engine guard: the augmented 2T-column Sigma_b machinery
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
  if (inherits(fit, "error")) {
    testthat::fail(sprintf(
      "small-n binomial-probit indep fixture must construct for the n_lhs_cols guard check: %s",
      conditionMessage(fit)
    ))
    return(invisible())
  }
  expect_s3_class(fit, "gllvmTMB_multi")

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
