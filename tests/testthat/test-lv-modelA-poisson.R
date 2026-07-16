## Design 73/76 S2 — Poisson Model A (predictor-informed latent `lv` + phylo source).
##
## Symbolic alignment (mirrors test-lv-gaussian-recovery.R / dev/modelA-rank2-coverage.R):
## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
## | --- | --- | --- | --- | --- |
## | z_i = x_i alpha + e_i | latent(0+trait|species, d=1, lv=~x) | e_i ~ N(0,1), x_i fixed | (score, not directly checked) | -- |
## | g_i ~ MVN(0, lambda_phy A) | phylo_latent(0+trait|species, d=1, tree=tree) | L_A %*% N(0,1) | (nuisance source, not directly checked) | -- |
## | B_lv = Lambda_B alpha^T | latent(0+trait|species, d=1, lv=~x) | Lambda_B, alpha fixed | extract_lv_effects(type = "trait_effect") | Lambda_B %*% t(alpha) |
## | y_it | poisson() (log link) | Pois(exp(eta_it)) | fitted TMB likelihood | count response |
##
## Poisson was authorized onto `latent(..., lv = ~ x)` by the maintainer on 2026-07-16
## (see the LV-05 note in R/lv-predictor.R). A prior diagnostic (kept out of this
## slice; see docs/dev-log/after-task/2026-07-16-modelA-extend-arc-kickoff.md) showed
## the engine fits and recovers B_lv, but the shared `species` grouping between the
## ordinary `latent(lv=~x)` term and `phylo_latent()` can leave `pdHess = FALSE` --
## the same "route intervals via profile, not Wald" case already documented for
## Gaussian Model A (LV-09). This test therefore asserts convergence and point-estimate
## recovery only; it does NOT require `pdHess`.

make_lv_modelA_poisson_data <- function(
  S = 120L,
  n_traits = 5L,
  K_B = 1L,
  K_phy = 1L,
  lambda_phy = 0.4,
  design_seed = 20260716L,
  draw_seed = 20260718L
) {
  set.seed(design_seed)
  tree <- ape::rcoal(S)
  tree$tip.label <- paste0("sp", seq_len(S))
  A <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(A))

  LambdaB <- matrix(stats::runif(n_traits * K_B, -0.6, 0.6), n_traits, K_B)
  diag(LambdaB) <- abs(diag(LambdaB)) + 0.3
  alpha <- matrix(stats::runif(K_B, 0.4, 0.7), 1L, K_B)
  LambdaPhy <- matrix(stats::runif(n_traits * K_phy, -0.6, 0.6), n_traits, K_phy) *
    sqrt(lambda_phy)
  beta <- rep(1.0, n_traits) + stats::rnorm(n_traits, 0, 0.1) ## baseline ~1.0 -> mean count ~3-4
  x <- as.numeric(scale(stats::rnorm(S)))

  set.seed(draw_seed)
  zB <- matrix(x, S, 1) %*% alpha + matrix(stats::rnorm(S * K_B), S, K_B)
  gphy <- LA %*% matrix(stats::rnorm(S * K_phy), S, K_phy)
  eta <- matrix(beta, S, n_traits, byrow = TRUE) +
    zB %*% t(LambdaB) +
    gphy %*% t(LambdaPhy)
  y <- matrix(stats::rpois(S * n_traits, lambda = exp(eta)), S, n_traits)

  df <- data.frame(
    species = factor(rep(tree$tip.label, times = n_traits), levels = tree$tip.label),
    trait = factor(rep(paste0("t", seq_len(n_traits)), each = S)),
    value = as.vector(y),
    x = rep(x, times = n_traits)
  )

  list(
    data = df,
    tree = tree,
    truth = list(LambdaB = LambdaB, alpha = alpha, B_lv = LambdaB %*% t(alpha))
  )
}

test_that("Poisson Model A latent lv converges and recovers B_lv (pdHess not required)", {
  skip_if_not_heavy()
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )

  dgp <- make_lv_modelA_poisson_data()

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | species, d = 1, lv = ~x) +
      phylo_latent(0 + trait | species, d = 1, tree = dgp$tree),
    data = dgp$data,
    unit = "species",
    trait = "trait",
    family = stats::poisson(),
    REML = FALSE,
    control = gllvmTMBcontrol(
      se = TRUE,
      optimizer = "optim",
      optArgs = list(method = "BFGS")
    )
  )))

  expect_identical(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$lv_B))

  effects <- extract_lv_effects(fit, type = "trait_effect")
  estimate <- matrix(effects$estimate, nrow = fit$n_traits)
  max_abs_err <- max(abs(estimate - dgp$truth$B_lv))
  expect_lt(
    max_abs_err,
    0.25,
    label = sprintf("max absolute B_lv recovery error = %.3f", max_abs_err)
  )
})
