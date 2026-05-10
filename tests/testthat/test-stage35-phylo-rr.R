# Stage 35: phylo_latent() reduced-rank phylogenetic GLLVM (PGLLVM).

skip_unless_ape <- function() testthat::skip_if_not_installed("ape")

simulate_pgllvm <- function(n_sp = 20, T = 4, sites = 50, K = 2, seed = 1) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lambda_phy <- matrix(stats::rnorm(T * K, sd = 0.6), nrow = T, ncol = K)
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))
  g <- matrix(0, n_sp, K)
  for (k in seq_len(K)) g[, k] <- as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  mu_phy <- g %*% t(Lambda_phy)
  rows <- list()
  for (s in seq_len(sites)) {
    obs_sp <- sample(seq_len(n_sp), size = max(2, stats::rpois(1, 5)))
    for (i in obs_sp) for (t in seq_len(T)) {
      rows[[length(rows) + 1L]] <- data.frame(
        site    = s,
        species = paste0("sp", i),
        trait   = paste0("trait_", t),
        value   = stats::rnorm(1, mu_phy[i, t], 0.5),
        stringsAsFactors = FALSE
      )
    }
  }
  df <- do.call(rbind, rows)
  df$site         <- factor(df$site)
  df$species      <- factor(df$species, levels = paste0("sp", seq_len(n_sp)))
  df$trait        <- factor(df$trait, levels = paste0("trait_", seq_len(T)))
  df$site_species <- factor(paste(df$site, df$species, sep = "_"))
  list(data = df, Cphy = Cphy, Lambda_phy = Lambda_phy)
}

test_that("Stage 35: phylo_latent(species, d = K) fits and produces a Sigma_phy", {
  skip_unless_ape()
  s <- simulate_pgllvm()
  fit <- gllvmTMB(value ~ 0 + trait + phylo_latent(species, d = 2),
                  data = s$data, phylo_vcv = s$Cphy)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
  expect_true(fit$use$phylo_rr)
  expect_equal(fit$d_phy, 2L)
  expect_equal(dim(fit$report$Lambda_phy), c(4L, 2L))
  expect_equal(dim(fit$report$Sigma_phy), c(4L, 4L))
  expect_true(all(diag(fit$report$Sigma_phy) > 0))
  ## upper triangle of Lambda_phy is exactly 0 (lower-triangular)
  expect_equal(fit$report$Lambda_phy[1, 2], 0)
})

test_that("Stage 35: phylo_latent() requires phylo_vcv", {
  skip_unless_ape()
  s <- simulate_pgllvm(n_sp = 10, T = 3, sites = 20)
  expect_error(
    gllvmTMB(value ~ 0 + trait + phylo_latent(species, d = 2),
             data = s$data),
    "phylo_vcv"
  )
})

test_that("Stage 35: phylo_latent() can be combined with rr() and diag()", {
  skip_unless_ape()
  s <- simulate_pgllvm()
  fit <- gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2) + unique(0 + trait | site) +
            phylo_latent(species, d = 2),
    data      = s$data,
    phylo_vcv = s$Cphy
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(fit$use$phylo_rr)
  expect_true(fit$use$rr_B)
  expect_true(fit$use$diag_B)
})
