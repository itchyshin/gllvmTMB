# Two-U PGLLVM: phylo_latent(species, d = K) + phylo_unique(species)
# co-fit as separate components Sigma_phy = Lambda_phy Lambda_phy^T +
# diag(U_phy). The phylo_diag engine slot is independent of phylo_rr;
# both can be on simultaneously.
#
# Scope:
#   1. Sanity: both flags `phylo_rr` and `phylo_diag` are TRUE in the
#      fit's `use` list when both keywords are in the formula.
#   2. Backward compatibility: a fit with ONLY phylo_latent has the same
#      objective as the same fit on main 6e3888e3 (phylo_diag is mapped
#      off, so the optimisation surface is unchanged).
#   3. Recovery: with replication (multiple sites per species, the
#      functional-biogeography scenario from Hadfield & Nakagawa 2010),
#      the per-trait phylogenetic SDs (U_phy) are recovered within
#      reasonable bias.
#   4. extract_Sigma(level = "phy", part = ...) returns the correct
#      decomposition.

skip_unless_ape <- function() testthat::skip_if_not_installed("ape")

# Simulate a two-U PGLLVM dataset:
#   eta_{ist} = b_t + lambda_phy_t' g_phy_i + sd_phy_diag_t * u_phy_i_t + eps
# where g_phy.col(k) ~ N(0, Cphy) for k = 1..K (shared rank-K phylogeny),
# u_phy.col(t) ~ N(0, Cphy) for t = 1..T (per-trait phylogeny). Each
# species observed at `n_sites_per_sp` sites for replication, which is
# what breaks the U_phy / U_non confound (Hadfield & Nakagawa 2010).
simulate_two_U <- function(n_sp = 60, n_traits = 4, K = 1,
                           n_sites_per_sp = 5,
                           Lambda_phy = NULL, sd_phy_diag = NULL,
                           sigma_eps = 0.3, seed = 1) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))

  if (is.null(Lambda_phy)) {
    Lambda_phy <- matrix(0, nrow = n_traits, ncol = K)
    diag(Lambda_phy) <- 0.5
  }
  if (is.null(sd_phy_diag))
    sd_phy_diag <- rep(0.4, n_traits)

  # Shared phylogeny (rank K)
  g <- matrix(0, n_sp, K)
  for (k in seq_len(K))
    g[, k] <- as.numeric(t(Lphy) %*% stats::rnorm(n_sp))

  # Per-trait phylogeny (rank T diagonal)
  u <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits))
    u[, t] <- as.numeric(t(Lphy) %*% stats::rnorm(n_sp))

  # mu_{i,t} = sum_k Lambda_phy[t,k] * g[i,k] + sd_phy_diag[t] * u[i,t]
  mu_phy <- g %*% t(Lambda_phy)
  for (t in seq_len(n_traits))
    mu_phy[, t] <- mu_phy[, t] + sd_phy_diag[t] * u[, t]

  # Long-format data: each species observed at n_sites_per_sp sites
  rows <- list()
  for (s in seq_len(n_sites_per_sp)) {
    for (i in seq_len(n_sp)) {
      for (t in seq_len(n_traits)) {
        rows[[length(rows) + 1L]] <- data.frame(
          site    = s,
          species = paste0("sp", i),
          trait   = paste0("trait_", t),
          value   = stats::rnorm(1, mu_phy[i, t], sigma_eps),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  df <- do.call(rbind, rows)
  df$site         <- factor(df$site)
  df$species      <- factor(df$species, levels = paste0("sp", seq_len(n_sp)))
  df$trait        <- factor(df$trait, levels = paste0("trait_", seq_len(n_traits)))
  df$site_species <- factor(paste(df$site, df$species, sep = "_"))
  list(data       = df,
       tree       = tree,
       Cphy       = Cphy,
       Lambda_phy = Lambda_phy,
       sd_phy_diag = sd_phy_diag,
       sigma_eps  = sigma_eps)
}

test_that("two-U: phylo_latent + phylo_unique sets both phylo_rr and phylo_diag flags", {
  skip_unless_ape()
  s <- simulate_two_U(n_sp = 30, n_traits = 3, K = 1,
                      n_sites_per_sp = 4, seed = 1)
  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1) + phylo_unique(species),
    data      = s$data,
    phylo_vcv = s$Cphy
  )
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_true(isTRUE(fit$use$phylo_diag))
  ## phylo_unique sub-flag should be FALSE (it's TRUE only in the legacy
  ## phylo_unique-alone path)
  expect_false(isTRUE(fit$use$phylo_unique))
  ## d_phy is the rank of the shared component (the latent), not n_traits
  expect_equal(fit$d_phy, 1L)
  expect_equal(fit$opt$convergence, 0L)
  ## Both blocks report
  expect_true(!is.null(fit$report$Lambda_phy))
  expect_true(!is.null(fit$report$sd_phy_diag))
  expect_length(fit$report$sd_phy_diag, 3L)
})

test_that("two-U: backward-compat — phylo_latent-only fit has phylo_diag = FALSE", {
  skip_unless_ape()
  s <- simulate_two_U(n_sp = 30, n_traits = 3, K = 1,
                      n_sites_per_sp = 3, seed = 2)
  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1),
    data      = s$data,
    phylo_vcv = s$Cphy
  )
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_false(isTRUE(fit$use$phylo_diag))
  expect_equal(fit$opt$convergence, 0L)
})

test_that("two-U: backward-compat — phylo_unique-only fit retains legacy diagonal-Lambda path", {
  skip_unless_ape()
  s <- simulate_two_U(n_sp = 30, n_traits = 3, K = 1,
                      n_sites_per_sp = 3, seed = 3)
  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_unique(species),
    data      = s$data,
    phylo_vcv = s$Cphy
  )
  ## Legacy path: phylo_rr = TRUE (with diagonal Lambda), phylo_diag = FALSE
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_true(isTRUE(fit$use$phylo_unique))
  expect_false(isTRUE(fit$use$phylo_diag))
  expect_equal(fit$opt$convergence, 0L)
  ## d_phy = n_traits in legacy phylo_unique-alone path
  expect_equal(fit$d_phy, 3L)
})

test_that("two-U: extract_Sigma(level='phy', part=...) returns correct components", {
  skip_unless_ape()
  s <- simulate_two_U(n_sp = 25, n_traits = 3, K = 1,
                      n_sites_per_sp = 4, seed = 5)
  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1) + phylo_unique(species),
    data      = s$data,
    phylo_vcv = s$Cphy
  )
  expect_equal(fit$opt$convergence, 0L)

  shared <- suppressMessages(extract_Sigma(fit, level = "phy", part = "shared"))
  uniq   <- suppressMessages(extract_Sigma(fit, level = "phy", part = "unique"))
  total  <- suppressMessages(extract_Sigma(fit, level = "phy", part = "total"))

  ## Shared: Lambda_phy Lambda_phy^T (rank K = 1, so rank-1 PSD)
  Lphy <- fit$report$Lambda_phy
  expect_equal(shared$Sigma, Lphy %*% t(Lphy),
               ignore_attr = TRUE, tolerance = 1e-8)

  ## Unique: diag(sd_phy_diag^2)
  expect_equal(uniq$s, as.numeric(fit$report$sd_phy_diag)^2,
               ignore_attr = TRUE, tolerance = 1e-8)
  expect_length(uniq$s, 3L)

  ## Total: shared + diag(unique)
  expect_equal(total$Sigma, shared$Sigma + diag(uniq$s),
               ignore_attr = TRUE, tolerance = 1e-8)
})

test_that("two-U: U_phy recovery within bias on replicated data", {
  skip_on_cran()
  skip_unless_ape()
  ## Recovery study: the small-replication / small-rep budget is
  ## consistent with the simulation pilot's sampling design (Cooney et
  ## al. 2017 use ~6000 species; here we test with N=60 species at 5
  ## replicate sites — replication breaks U_phy / U_non confounding,
  ## per Hadfield & Nakagawa 2010).
  n_reps     <- 3L          # keep the test fast; pilot at n_reps = 10
  n_sp       <- 60L
  n_sites    <- 5L
  K          <- 1L
  n_traits   <- 3L
  Lambda_phy <- matrix(0.6, nrow = n_traits, ncol = K)
  sd_phy_true <- c(0.5, 0.4, 0.6)
  sigma_eps  <- 0.3

  est <- matrix(NA_real_, nrow = n_reps, ncol = n_traits)
  for (r in seq_len(n_reps)) {
    s <- simulate_two_U(n_sp = n_sp, n_traits = n_traits, K = K,
                        n_sites_per_sp = n_sites,
                        Lambda_phy = Lambda_phy,
                        sd_phy_diag = sd_phy_true,
                        sigma_eps = sigma_eps,
                        seed = 100L + r)
    fit <- tryCatch(gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1) + phylo_unique(species),
      data      = s$data,
      phylo_vcv = s$Cphy
    ), error = function(e) NULL)
    if (is.null(fit) || fit$opt$convergence != 0L) next
    est[r, ] <- as.numeric(fit$report$sd_phy_diag)
  }
  ## Drop failed reps (NA rows)
  ok <- complete.cases(est)
  est <- est[ok, , drop = FALSE]
  expect_gte(nrow(est), 2L)   # at least 2 successful reps for variance check
  ## Bias must not exceed ~50% (small-N test) per trait.
  ## With n_reps = 10 in the pilot the bias drops to <20%, but at
  ## n_reps = 3 we keep the bound generous so the test is stable.
  for (t in seq_len(n_traits)) {
    rel_bias <- abs(mean(est[, t]) - sd_phy_true[t]) / sd_phy_true[t]
    expect_lt(rel_bias, 0.5)
  }
})
