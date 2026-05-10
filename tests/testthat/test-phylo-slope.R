## Q6: phylo_slope(x | species). Initial release supports ONE continuous
## covariate, ONE shared slope variance, slopes shared across traits.
## Recovery test: simulate per-species slopes drawn from N(0, sigma2 * Cphy),
## fit, and verify (i) sigma_slope is recovered, (ii) the per-species
## slopes correlate strongly with the truth when correctly indexed.

skip_if_not_ape <- function() {
  ## Heavy TMB fits with 50–80 species + tree-augmented A^-1; takes 2–5
  ## min per test on CI runners. We skip these on CRAN / CI so the
  ## R-CMD-check matrix stays under ~25 min wall-clock; locally the
  ## tests exercise the full code path.
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")
}

test_that("phylo_slope: sigma_slope and per-species slopes are recovered", {
  skip_if_not_ape()
  set.seed(2026)
  n_sp <- 80
  T    <- 4
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  ## True per-species slopes ~ N(0, sigma2_slope * Cphy)
  sigma2_slope_true <- 0.4
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))
  beta_slope_true <- as.numeric(
    Lphy_chol %*% rnorm(n_sp, sd = sqrt(sigma2_slope_true)))
  names(beta_slope_true) <- tree$tip.label

  n_rep <- 5
  df <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    trait   = factor(paste0("t", 1:T), levels = paste0("t", 1:T)),
    rep     = seq_len(n_rep)
  )
  df$x <- rnorm(nrow(df))
  mu_t  <- c(2, 1.5, 1, 0.5)[as.integer(df$trait)]
  slope <- beta_slope_true[as.character(df$species)]
  df$value <- mu_t + slope * df$x + rnorm(nrow(df), sd = 0.5)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_slope(x | species),
    data       = df,
    phylo_tree = tree,
    unit       = "species"
  )))
  expect_equal(fit$opt$convergence, 0L)

  ## sigma_slope recovery
  sigma_slope_hat <- exp(
    fit$opt$par[grepl("log_sigma_slope", names(fit$opt$par))])
  expect_equal(unname(sigma_slope_hat), sqrt(sigma2_slope_true), tolerance = 0.15)

  ## Per-species slope recovery: pull b_phy_slope from the augmented A^-1
  ## and align to tip species names via the rownames of Ainv_phy_rr.
  b_full <- fit$tmb_obj$env$last.par.best
  b      <- as.numeric(b_full[names(b_full) == "b_phy_slope"])
  aug_names <- rownames(fit$tmb_data$Ainv_phy_rr)
  tip_idx   <- match(tree$tip.label, aug_names)
  b_tips    <- b[tip_idx]
  ## Strong positive correlation between fitted and true tip-level slopes.
  expect_gt(cor(b_tips, beta_slope_true), 0.85)
})

test_that("phylo_slope works alongside phylo_latent (combined fit)", {
  skip_if_not_ape()
  set.seed(7)
  n_sp <- 50
  T    <- 3
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  ## Latent + slope: simulate both pieces
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))
  Lambda_phy_true <- matrix(c(0.6, 0.3, -0.2, 0.0, 0.5, 0.4), T, 2)
  g_phy_true <- Lphy_chol %*% matrix(rnorm(n_sp * 2), n_sp, 2)
  beta_slope_true <- as.numeric(Lphy_chol %*% rnorm(n_sp, sd = sqrt(0.3)))
  names(beta_slope_true) <- tree$tip.label

  n_rep <- 3
  df <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    trait   = factor(paste0("t", 1:T), levels = paste0("t", 1:T)),
    rep     = seq_len(n_rep)
  )
  df$x <- rnorm(nrow(df))
  shared_eta <- g_phy_true %*% t(Lambda_phy_true)
  mu_t   <- c(1, 0.5, -0.5)[as.integer(df$trait)]
  shared <- shared_eta[cbind(as.integer(df$species), as.integer(df$trait))]
  slope  <- beta_slope_true[as.character(df$species)]
  df$value <- mu_t + shared + slope * df$x + rnorm(nrow(df), sd = 0.4)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 2) +
            phylo_slope(x | species),
    data       = df,
    phylo_tree = tree,
    unit       = "species"
  )))
  expect_equal(fit$opt$convergence, 0L)
  ## Both terms live in the fit: report has Lambda_phy and sigma_slope.
  expect_false(is.null(fit$report$Lambda_phy))
  sigma_slope_hat <- exp(
    fit$opt$par[grepl("log_sigma_slope", names(fit$opt$par))])
  expect_gt(sigma_slope_hat, 0.1)   # bounded away from zero
})
