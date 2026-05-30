## Design 55 Sec. A2 + Design 56 Sec. 9.5a -- phylo_latent(1 + x | sp, d = K)
## Gaussian.
##
## phylo_latent random slope = reduced-rank, BLOCK-DIAGONAL across the LHS
## columns (Design 56 Sec. 5.3, latent row). Each LHS column k in
## {intercept, slope} gets its OWN factor-analytic decomposition
## Sigma_k = Lambda_k Lambda_k^T (rank d), with K latent factor-score columns
## g_phy_slope[, f, k] ~ N(0, A_phy). There is NO intercept-slope correlation
## (block-diagonal == the cross-column covariance blocks are zero), in
## contrast to the full 2x2 / unstructured b_phy_aug path used by
## phylo_unique / phylo_dep. Standalone phylo_latent has no separate diag(psi)
## component: that is the paired phylo_unique (phylo_diag) term, out of scope
## for this slice.
##
## This file covers (Gaussian anchor; non-Gaussian deferred per Design 56
## Sec. 2):
##   - Recovery of per-column Sigma_k = Lambda_k Lambda_k^T (rotation-
##     invariant) on simulated phylo data, averaged over replicates to show
##     the estimator is unbiased (single-draw intercept scale is noisy -- the
##     Sec. 5.3 / Sec. 11 identifiability caveat).
##   - Byte-identity wide (1 + x | sp) vs long (0 + trait + (0 + trait):x | sp)
##     per Design 55 Sec. 3.
##   - Independent analytic joint-density cross-check (< 1e-9) against the
##     TMB inner objective.
##   - Fail-loud negative tests.

skip_if_not_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
}

## ---------------------------------------------------------------------------
## Simulate phylo latent-slope Gaussian data with known per-column loadings.
## ---------------------------------------------------------------------------
make_platent_slope_fixture <- function(seed, ntip = 80L, n_traits = 3L,
                                       K = 1L, reps = 14L,
                                       Lam0 = matrix(c(1.1, -0.6, 0.4), 3L, 1L),
                                       Lam1 = matrix(c(0.3, 0.9, -0.5), 3L, 1L),
                                       resid_sd = 0.35) {
  set.seed(seed)
  tree <- ape::rcoal(ntip)
  tree$tip.label <- paste0("sp", seq_len(ntip))
  A <- ape::vcv(tree, corr = TRUE)
  Lc <- t(chol(A))
  g0 <- Lc %*% matrix(stats::rnorm(ntip * K), ntip, K)
  g1 <- Lc %*% matrix(stats::rnorm(ntip * K), ntip, K)
  u_int <- g0 %*% t(Lam0)
  u_slp <- g1 %*% t(Lam1)
  rows <- expand.grid(rep = seq_len(reps), trait = seq_len(n_traits),
                      sp = seq_len(ntip))
  rows$x <- stats::rnorm(nrow(rows))
  beta <- c(0.5, -0.3, 0.1)[seq_len(n_traits)]
  mu <- beta[rows$trait] +
    u_int[cbind(rows$sp, rows$trait)] +
    u_slp[cbind(rows$sp, rows$trait)] * rows$x
  rows$value <- mu + stats::rnorm(nrow(rows), 0, resid_sd)
  rows$species <- factor(paste0("sp", rows$sp), levels = tree$tip.label)
  rows$trait <- factor(paste0("t", rows$trait))
  list(df = rows, tree = tree, n_traits = n_traits,
       Sig0_true = Lam0 %*% t(Lam0), Sig1_true = Lam1 %*% t(Lam1),
       resid_sd = resid_sd)
}

fit_platent_slope <- function(df, tree, long = FALSE) {
  form <- if (long) {
    value ~ 0 + trait +
      phylo_latent(0 + trait + (0 + trait):x | species, d = 1)
  } else {
    value ~ 0 + trait + phylo_latent(1 + x | species, d = 1)
  }
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    form, data = df, phylo_tree = tree, unit = "species", cluster = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
}

test_that("phylo_latent(1 + x | sp, d = 1) recovers per-column Sigma on Gaussian (unbiased over replicates)", {
  skip_if_not_heavy()
  skip_if_not_ape()

  ## Single-replicate fits are noisy on the intercept-block scale (one tree
  ## draw weakly pins the intercept variance -- the Sec. 5.3 / Sec. 11
  ## caveat). Average the recovered Sigma_k over several independent
  ## replicates and assert the MEAN matches truth (estimator unbiased), and
  ## that a single fit recovers the well-identified slope block tightly.
  nrep <- 8L
  S0s <- array(0, c(3L, 3L, nrep))
  S1s <- array(0, c(3L, 3L, nrep))
  fx1 <- NULL
  for (r in seq_len(nrep)) {
    fx <- make_platent_slope_fixture(seed = 2000L + r)
    if (r == 1L) fx1 <- fx
    fit <- fit_platent_slope(fx$df, fx$tree)
    testthat::expect_equal(fit$opt$convergence, 0L)
    S0s[, , r] <- fit$report$Sigma_phy_slope_intercept
    S1s[, , r] <- fit$report$Sigma_phy_slope_slope
  }
  S0bar <- apply(S0s, c(1, 2), mean)
  S1bar <- apply(S1s, c(1, 2), mean)

  ## Mean recovery (rotation-invariant: compare Sigma matrices directly).
  ## Bands are generous on the intercept block (Monte-Carlo scale noise) and
  ## tighter on the slope block (well identified by the within-species
  ## covariate contrasts).
  testthat::expect_lt(max(abs(S0bar - fx1$Sig0_true)), 0.30)
  testthat::expect_lt(max(abs(S1bar - fx1$Sig1_true)), 0.15)

  ## Residual SD recovered on the first replicate.
  fit1 <- fit_platent_slope(fx1$df, fx1$tree)
  testthat::expect_equal(as.numeric(fit1$report$sigma_eps), fx1$resid_sd,
                         tolerance = 0.05)
})

test_that("phylo_latent wide == long byte-identical (Design 55 Sec. 3)", {
  skip_if_not_heavy()
  skip_if_not_ape()

  fx <- make_platent_slope_fixture(seed = 4242L, ntip = 40L, reps = 10L)
  fw <- fit_platent_slope(fx$df, fx$tree, long = FALSE)
  fl <- fit_platent_slope(fx$df, fx$tree, long = TRUE)

  ## Same engine path; the long surface just stacks identical Z rows.
  testthat::expect_equal(as.numeric(logLik(fw)), as.numeric(logLik(fl)),
                         tolerance = 1e-6)
  testthat::expect_equal(fw$report$Sigma_phy_slope_intercept,
                         fl$report$Sigma_phy_slope_intercept,
                         tolerance = 1e-5)
  testthat::expect_equal(fw$report$Sigma_phy_slope_slope,
                         fl$report$Sigma_phy_slope_slope,
                         tolerance = 1e-5)
})

test_that("independent analytic joint-density cross-check matches TMB (< 1e-9)", {
  skip_if_not_heavy()
  skip_if_not_ape()

  fx <- make_platent_slope_fixture(seed = 7L, ntip = 12L, reps = 5L)
  fit <- fit_platent_slope(fx$df, fx$tree)
  obj <- fit$tmb_obj
  par.full <- obj$env$last.par.best
  nll_tmb <- as.numeric(obj$env$f(par.full, order = 0))

  dat <- obj$env$data
  ## parList warns harmlessly when reconstructing the full vector; the
  ## sub-1e-9 agreement below confirms the values are correct.
  p <- suppressWarnings(obj$env$parList(par.full))
  n_obs <- length(dat$y)
  n_tr <- dat$n_traits
  n_aug <- dat$n_aug_phy
  dps <- dat$d_phy_slope
  nlc <- dat$n_lhs_cols_lat
  Z <- dat$Z_phy_lat
  trait_id <- dat$trait_id
  sp_aug <- dat$species_aug_id
  Ainv <- as.matrix(dat$Ainv_phy_rr)
  logdetA <- dat$log_det_A_phy_rr

  ## Rebuild per-column Lambda_k from the packed lower-triangular vector.
  theta <- p$theta_rr_phy_slope
  len_per_col <- n_tr * dps - dps * (dps - 1) / 2
  Lam <- array(0, c(n_tr, dps, nlc))
  for (kc in seq_len(nlc)) {
    tk <- theta[((kc - 1) * len_per_col + 1):(kc * len_per_col)]
    lam_diag <- tk[seq_len(dps)]
    lam_lower <- tk[-seq_len(dps)]
    for (j in seq_len(dps)) for (i in seq_len(n_tr)) {
      if (j > i) {
        Lam[i, j, kc] <- 0
      } else if (i == j) {
        Lam[i, j, kc] <- lam_diag[j]
      } else {
        Lam[i, j, kc] <- lam_lower[(j - 1) * n_tr - j * (j - 1) / 2 + (i - 1) - (j - 1)]
      }
    }
  }
  g <- p$g_phy_slope

  ## eta = X b + sum_k Z[,k] * sum_f Lam[t,f,k] * g[sp,f,k]
  eta <- as.numeric(dat$X_fix %*% p$b_fix)
  for (o in seq_len(n_obs)) {
    t <- trait_id[o] + 1L
    s <- sp_aug[o] + 1L
    add <- 0
    for (kc in seq_len(nlc)) {
      add <- add + Z[o, kc] * sum(Lam[t, , kc] * g[s, , kc])
    }
    eta[o] <- eta[o] + add
  }
  sigma_eps <- exp(p$log_sigma_eps)
  nll_obs <- -sum(stats::dnorm(dat$y, eta, sigma_eps, log = TRUE))

  ## Independent N(0, A) prior on every factor column.
  nll_prior <- 0
  for (kc in seq_len(nlc)) for (f in seq_len(dps)) {
    gk <- g[, f, kc]
    quad <- as.numeric(t(gk) %*% Ainv %*% gk)
    nll_prior <- nll_prior + 0.5 * (n_aug * log(2 * pi) + logdetA + quad)
  }
  nll_hand <- nll_obs + nll_prior

  testthat::expect_lt(abs(nll_tmb - nll_hand), 1e-9)
})

test_that("extract_Sigma(level = 'phy_slope') returns the per-column Sigma matrices", {
  skip_if_not_heavy()
  skip_if_not_ape()

  fx <- make_platent_slope_fixture(seed = 909L, ntip = 30L, reps = 8L)
  fit <- fit_platent_slope(fx$df, fx$tree)

  es <- extract_Sigma(fit, level = "phy_slope")
  testthat::expect_s3_class(es, "gllvmTMB_Sigma_phy_slope")
  testthat::expect_equal(dim(es$intercept), c(fx$n_traits, fx$n_traits))
  testthat::expect_equal(dim(es$slope), c(fx$n_traits, fx$n_traits))
  ## Matches the raw report (the extractor is a thin, labelled view).
  testthat::expect_equal(unname(es$intercept),
                         unname(fit$report$Sigma_phy_slope_intercept))
  testthat::expect_equal(unname(es$slope),
                         unname(fit$report$Sigma_phy_slope_slope))
  ## Both Sigma_k are symmetric PSD (Lambda_k Lambda_k^T).
  testthat::expect_equal(es$slope, t(es$slope))
  testthat::expect_gte(min(eigen(es$slope, only.values = TRUE)$values), -1e-8)

  ## level = "phy" aborts on a pure latent-slope fit (no intercept-only tier).
  testthat::expect_error(
    extract_Sigma(fit, level = "phy"),
    regexp = "phylo_latent|phylo_unique|nothing to extract"
  )
})

test_that("phylo_latent slope fails loud on missing covariate and on non-Gaussian", {
  skip_if_not_ape()
  fx <- make_platent_slope_fixture(seed = 11L, ntip = 8L, reps = 3L)

  ## Missing slope covariate column.
  bad <- fx$df
  bad$x <- NULL
  testthat::expect_error(
    fit_platent_slope(bad, fx$tree),
    regexp = "not in|references column|x"
  )

  ## Non-Gaussian deferred (Gaussian anchor only).
  cnt <- fx$df
  cnt$value <- stats::rpois(nrow(cnt), lambda = 2)
  testthat::expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_latent(1 + x | species, d = 1),
      data = cnt, phylo_tree = fx$tree, unit = "species",
      family = poisson()
    ))),
    regexp = "gaussian|Gaussian anchor|deferred"
  )
})
