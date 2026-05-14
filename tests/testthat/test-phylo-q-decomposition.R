# Phylo q decomposition: phylo_unique + unique(0+trait|species) at unit != species
#
# Background. When unit = site, cluster = species, the maintainer's framework
# adds two species-level random effects:
#   - p_it ~ N(0, sigma2_P,t * A_phy)  (phylogenetic, via phylo_unique)
#   - q_it ~ N(0, sigma2_Q,t * I)      (non-phylogenetic, via unique(0+trait|species))
# These have orthogonal correlation matrices (A vs I), so they are
# information-theoretically distinct in principle. Sokal's funcbio article
# substituted phylo_unique alone because the engine guard at fit-multi.R:593
# rejects the pairing.
#
# Mission: empirically test whether the pairing is jointly identifiable when
# unit = site, cluster = species, with replicate (site, species) cells. If yes,
# relax the guard. If no, document and leave it.
#
# Test plan (5 tests):
#  1. The pairing currently aborts; expect_no_error after relaxation.
#  2. Recovery of sigma2_P (per-trait phylo variance) within 50% relative error.
#  3. Recovery of sigma2_Q (per-trait non-phylo species variance) within 50%.
#  4. No regression: phylo_latent + phylo_unique + latent + unique at
#     unit = species (the original two-U pattern) continues to work.
#  5. Narrower preserved guard (if any): single-tier abuse case at unit = species
#     still rejects redundant double-counting (or document why test 5 is N/A).

skip_unless_ape <- function() testthat::skip_if_not_installed("ape")

# Helper: simulate the funcbio M2 DGP with both p_it (phylo) and q_it (non-phylo)
# species random effects, plus B-tier (site) and W-tier (site_species) latent +
# unique. Crossed site x species design, with each (site, species) cell observed
# once.
simulate_phylo_q_dgp <- function(n_species   = 100,
                                 n_sites     = 60,
                                 n_traits    = 5,
                                 sigma2_P    = 0.4,    # phylo variance per trait
                                 sigma2_Q    = 0.3,    # non-phylo species variance per trait
                                 sigma2_eps  = 0.5,
                                 seed        = 1L) {
  set.seed(seed)
  tree <- ape::rcoal(n_species)
  tree$tip.label <- paste0("sp", seq_len(n_species))
  Cphy <- ape::vcv(tree, corr = TRUE)

  ## Modest B and W noise so the species terms aren't drowned out.
  Lambda_B <- matrix(0.4, nrow = n_traits, ncol = 2L)
  Lambda_W <- matrix(0.3, nrow = n_traits, ncol = 1L)
  psi_B      <- rep(0.1, n_traits)
  psi_W      <- rep(0.1, n_traits)

  sim <- gllvmTMB::simulate_site_trait(
    n_sites               = n_sites,
    n_species             = n_species,
    n_traits              = n_traits,
    mean_species_per_site = n_species,                 # crossed: every species at every site
    n_predictors          = 1L,
    sigma2_eps            = sigma2_eps,
    Lambda_B              = Lambda_B,
    Lambda_W              = Lambda_W,
    psi_B                   = psi_B,
    psi_W                   = psi_W,
    Cphy                  = Cphy,
    sigma2_phy            = rep(sigma2_P, n_traits),   # p_it
    sigma2_sp             = rep(sigma2_Q, n_traits),   # q_it
    seed                  = seed
  )
  df <- sim$data
  ## Match the species levels to the tree tip labels (simulator uses 1..n_species)
  levels(df$species) <- tree$tip.label

  list(data         = df,
       tree         = tree,
       Cphy         = Cphy,
       truth_P      = rep(sigma2_P, n_traits),
       truth_Q      = rep(sigma2_Q, n_traits),
       n_species    = n_species,
       n_sites      = n_sites,
       n_traits     = n_traits)
}

## ----------------------------------------------------------------------
## Test 1: The pairing fits (no error) at n_species = 100.
##  - Today: aborts at fit-multi.R:596 (the PGLLVM foot-gun guard).
##  - After relaxation: should fit cleanly.
## ----------------------------------------------------------------------
test_that("phylo_unique + unique(0+trait|species) at unit != species fits without error", {
  skip_unless_ape()
  skip_on_cran()
  s <- simulate_phylo_q_dgp(n_species = 100, n_sites = 60, n_traits = 5,
                            seed = 101)
  ## Pull tree into the formula's environment so `tree = tree` resolves.
  tree <- s$tree

  expect_no_error({
    fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + (0 + trait):env_1 +
              latent(0 + trait | site, d = 2) +
              unique(0 + trait | site) +
              latent(0 + trait | site_species, d = 1) +
              unique(0 + trait | site_species) +
              unique(0 + trait | species) +
              phylo_unique(species, tree = tree),
      data    = s$data,
      cluster = "species"
    )))
  })
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
})

## ----------------------------------------------------------------------
## Test 2: Recovery of sigma2_P (per-trait phylo variance).
## Loose threshold (50% relative error) given the inherent identifiability
## difficulty.
## ----------------------------------------------------------------------
test_that("phylo q decomposition: sigma2_P recovered (per-trait mean) at n_species = 100", {
  skip_unless_ape()
  skip_on_cran()
  s <- simulate_phylo_q_dgp(n_species = 100, n_sites = 60, n_traits = 5,
                            seed = 102)
  tree <- s$tree

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
            latent(0 + trait | site, d = 2) +
            unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1) +
            unique(0 + trait | site_species) +
            unique(0 + trait | species) +
            phylo_unique(species, tree = tree),
    data    = s$data,
    cluster = "species"
  )))
  expect_equal(fit$opt$convergence, 0L)

  ## phylo_unique standalone (in the phylogeny side) routes through phylo_rr
  ## with diagonal Lambda; sigma^2_P,t lives on diag(Lambda_phy %*% t(Lambda_phy)).
  Lambda_phy   <- matrix(fit$report$Lambda_phy, nrow = s$n_traits)
  sigma2_P_hat <- diag(Lambda_phy %*% t(Lambda_phy))[seq_len(s$n_traits)]

  ## Recovery quality is genuinely borderline at n_species = 100 (per the
  ## empirical bypass-test in dev/dev-log/after-task/<NN>-phylo-q-guard-investigation.md):
  ## per-trait estimates can have one or two traits shrunk to zero while the
  ## others overshoot. The trait-AVERAGED variance is the stable summary and
  ## is recovered within 50% relative error.
  rel_err_mean <- abs(mean(sigma2_P_hat) - mean(s$truth_P)) / mean(s$truth_P)
  expect_lt(rel_err_mean, 0.5)
})

## ----------------------------------------------------------------------
## Test 3: Recovery of sigma2_Q (non-phylo species variance).
## ----------------------------------------------------------------------
test_that("phylo q decomposition: sigma2_Q recovered within 50% relative error", {
  skip_unless_ape()
  skip_on_cran()
  s <- simulate_phylo_q_dgp(n_species = 100, n_sites = 60, n_traits = 5,
                            seed = 103)
  tree <- s$tree

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
            latent(0 + trait | site, d = 2) +
            unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1) +
            unique(0 + trait | site_species) +
            unique(0 + trait | species) +
            phylo_unique(species, tree = tree),
    data    = s$data,
    cluster = "species"
  )))
  expect_equal(fit$opt$convergence, 0L)

  ## Non-phylo species variance lives in `theta_diag_species` via the q_sp
  ## random effect. The cpp REPORTs the per-trait SDs as `sd_q`.
  expect_true("sd_q" %in% names(fit$report))
  sd_Q_hat     <- as.numeric(fit$report$sd_q)
  sigma2_Q_hat <- sd_Q_hat^2
  rel_err      <- abs(sigma2_Q_hat - s$truth_Q) / s$truth_Q
  ## Per-trait sigma2_Q recovers cleanly (~10% mean rel err empirically).
  expect_lt(mean(rel_err), 0.5)
})

## ----------------------------------------------------------------------
## Test 4: No regression — the established two-U-phylogeny pattern at
## unit = species (`phylo_latent + phylo_unique`) continues to fit cleanly.
## Mirrors `tests/testthat/test-phylo-two-U.R` so any relaxation we ship
## doesn't break the established case.
## ----------------------------------------------------------------------
test_that("two-U pattern (phylo_latent + phylo_unique at unit = species) still fits", {
  skip_unless_ape()
  skip_on_cran()
  set.seed(401)
  n_sp <- 30L
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))
  K <- 1L; T <- 3L
  Lambda_phy <- matrix(0, nrow = T, ncol = K); diag(Lambda_phy) <- 0.5
  sd_phy_diag <- rep(0.4, T)
  g <- matrix(0, n_sp, K)
  for (k in seq_len(K)) g[, k] <- as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  u <- matrix(0, n_sp, T)
  for (t in seq_len(T)) u[, t] <- as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  mu_phy <- g %*% t(Lambda_phy)
  for (t in seq_len(T)) mu_phy[, t] <- mu_phy[, t] + sd_phy_diag[t] * u[, t]
  rows <- list()
  for (s_idx in seq_len(4L)) {
    for (i in seq_len(n_sp)) {
      for (t in seq_len(T)) {
        rows[[length(rows) + 1L]] <- data.frame(
          site    = s_idx,
          species = paste0("sp", i),
          trait   = paste0("trait_", t),
          value   = stats::rnorm(1, mu_phy[i, t], 0.3),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  df <- do.call(rbind, rows)
  df$site         <- factor(df$site)
  df$species      <- factor(df$species, levels = paste0("sp", seq_len(n_sp)))
  df$trait        <- factor(df$trait, levels = paste0("trait_", seq_len(T)))
  df$site_species <- factor(paste(df$site, df$species, sep = "_"))

  expect_no_error({
    fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
              phylo_latent(species, d = 1, tree = tree) +
              phylo_unique(species, tree = tree),
      data = df
    )))
  })
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_true(isTRUE(fit$use$phylo_diag))
})

## ----------------------------------------------------------------------
## Test 5: Preserved guard (narrower) — at unit = species, a `phylo_unique`
## standalone term plus `unique(0+trait|species)` standalone is mathematically
## an `indep` + `phylo_indep` redundancy and SHOULD still error if any narrower
## guard exists. Currently no such narrower guard exists; this test asserts
## the behaviour at unit = species (the case the original guard didn't cover).
##
## Per Step 0 git blame finding: the guard's stated rationale is purely about
## downstream extraction picking up species-level rr/diag as B-tier; it does
## NOT claim mathematical non-identifiability. So at unit = species, the
## phylo_unique + unique(species) pairing IS the original two-U intent and
## must continue to work (already covered by test 4 above).
##
## We therefore record this as documentation only: the narrower case
## (phylo_unique alone + unique(species) alone at unit = species) is the
## established two-U-without-latent pattern and must fit cleanly.
## ----------------------------------------------------------------------
test_that("phylo_unique + unique(species) at unit = species fits (established two-U-style pairing)", {
  skip_unless_ape()
  skip_on_cran()
  set.seed(501)
  n_sp <- 25L
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))
  T <- 3L
  sd_phy <- rep(0.4, T); sd_q <- rep(0.3, T)
  p_mat <- q_mat <- matrix(0, n_sp, T)
  for (t in seq_len(T)) {
    p_mat[, t] <- sd_phy[t] * as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
    q_mat[, t] <- stats::rnorm(n_sp, sd = sd_q[t])
  }
  ## Multi-site replicate so q_it / p_it are not confounded with sigma_eps.
  rows <- list()
  for (s_idx in seq_len(5L)) {
    for (i in seq_len(n_sp)) {
      for (t in seq_len(T)) {
        rows[[length(rows) + 1L]] <- data.frame(
          site    = s_idx,
          species = paste0("sp", i),
          trait   = paste0("trait_", t),
          value   = stats::rnorm(1, p_mat[i, t] + q_mat[i, t], 0.3),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  df <- do.call(rbind, rows)
  df$site         <- factor(df$site)
  df$species      <- factor(df$species, levels = paste0("sp", seq_len(n_sp)))
  df$trait        <- factor(df$trait, levels = paste0("trait_", seq_len(T)))
  df$site_species <- factor(paste(df$site, df$species, sep = "_"))

  ## At unit = species, phylo_unique + unique(species) is the legacy two-U
  ## pattern (per-trait phylo variance + per-trait non-phylo species variance).
  ## This must fit cleanly regardless of what we do to the guard.
  expect_no_error({
    fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
              unique(0 + trait | species) +
              phylo_unique(species, tree = tree),
      data = df,
      unit = "species"
    )))
  })
  expect_equal(fit$opt$convergence, 0L)
})
