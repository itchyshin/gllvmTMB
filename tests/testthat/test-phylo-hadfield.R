# Tests for the TRUE Hadfield sparse-A^-1 path of `phylo_latent()`.
#
# The package ships two implementations of the prior on the
# phylogenetic latent factors g_phy:
#   1. Legacy dense path (phylo_vcv = Cphy): inverts dense tip-only Cphy
#      via Matrix::solve(); correct, but does not exploit tree
#      topology sparsity.
#   2. Hadfield sparse path (phylo_tree = tree): builds A^-1 over tips
#      + internal nodes via MCMCglmm::inverseA(tree); ~5n non-zeros
#      versus n^2 in the dense path.
#
# These two paths must give identical MLEs for Sigma_phy, Lambda_phy,
# and the fixed effects on the same data. They differ only in
# computational cost. The tests below check (a) the sparse path
# actually produces a sparse A^-1 (the bug that motivated this
# implementation: the previous code just stored a dense matrix in a
# sparse-format wrapper), (b) the two paths agree, and (c) the
# augmented dimensions are passed through correctly.

skip_if_not_installed("ape")
skip_if_not_installed("MCMCglmm")
skip_if_not_installed("Matrix")

make_phylo_sim <- function(n_sp = 50, n_traits = 4, seed = 7) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- simulate_site_trait(
    n_sites               = 1,
    n_species             = n_sp,
    n_traits              = n_traits,
    mean_species_per_site = n_sp,
    Lambda_B              = matrix(0.0, n_traits, 1),
    psi_B                   = rep(0.05, n_traits),
    Cphy                  = Cphy,
    sigma2_phy            = rep(0.5, n_traits),
    seed                  = seed
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  list(tree = tree, Cphy = Cphy, df = df)
}

test_that("phylo_tree path produces a genuinely sparse Ainv", {
  s <- make_phylo_sim(n_sp = 50)
  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 2),
    data       = s$df,
    phylo_tree = s$tree
  )
  Ainv <- fit$tmb_data$Ainv_phy_rr
  ## Augmented dimension: tips + internal nodes (~ 2 * n_tips - 1)
  expect_gt(nrow(Ainv), 50L)             # strictly greater than n_tips
  ## Number of non-zeros should be O(n) not O(n^2)
  nnz <- Matrix::nnzero(Ainv)
  expect_lt(nnz, 0.1 * nrow(Ainv)^2)     # < 10% density
  ## At n_tips = 50, true Hadfield gives ~290 nz; bound generously.
  expect_lt(nnz, 600)
})

test_that("phylo_vcv path stores a dense Ainv (legacy behaviour)", {
  s <- make_phylo_sim(n_sp = 50)
  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 2),
    data      = s$df,
    phylo_vcv = s$Cphy
  )
  Ainv <- fit$tmb_data$Ainv_phy_rr
  expect_equal(nrow(Ainv), 50L)
  ## Dense Cphy^-1 has approximately n^2 non-zeros (after Matrix
  ## sparsification, may drop entries below tol; still >> 5n).
  nnz <- Matrix::nnzero(Ainv)
  expect_gt(nnz, 5 * nrow(Ainv))
})

test_that("phylo_tree and phylo_vcv paths give identical MLE", {
  s <- make_phylo_sim(n_sp = 50)
  fit_h <- gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 2),
    data       = s$df,
    phylo_tree = s$tree
  )
  fit_d <- gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 2),
    data      = s$df,
    phylo_vcv = s$Cphy
  )
  expect_equal(fit_h$opt$convergence, 0L)
  expect_equal(fit_d$opt$convergence, 0L)
  ## Sigma_phy (= Lambda Lambda^T) must agree to TMB tolerance —
  ## Lambda_phy itself is identifiable only up to column rotation.
  expect_equal(fit_h$report$Sigma_phy, fit_d$report$Sigma_phy,
               tolerance = 1e-4)
  ## Fixed effects must agree
  bh <- fit_h$opt$par[grep("^b_fix", names(fit_h$opt$par))]
  bd <- fit_d$opt$par[grep("^b_fix", names(fit_d$opt$par))]
  expect_equal(unname(bh), unname(bd), tolerance = 1e-4)
})

test_that("species_aug_id maps each obs to a tip row of the augmented Ainv", {
  s <- make_phylo_sim(n_sp = 30)
  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1),
    data       = s$df,
    phylo_tree = s$tree
  )
  ## species_aug_id is 0-indexed; every value must point inside the
  ## augmented matrix. With n_aug ~= 2 * n_tips - 1 = 59 here, expect
  ## values in [0, n_aug-1].
  ids <- fit$tmb_data$species_aug_id
  n_aug <- fit$tmb_data$n_aug_phy
  expect_true(all(ids >= 0L))
  expect_true(all(ids < n_aug))
  ## Each unique species id should map to a unique augmented row.
  expect_equal(length(unique(ids)), nlevels(s$df$species))
})

test_that("phylo_tree path requires MCMCglmm and an ape::phylo object", {
  s <- make_phylo_sim(n_sp = 20)
  ## Wrong class for phylo_tree — should error with a clear message
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1),
      data       = s$df,
      phylo_tree = s$Cphy   # a matrix, not a tree
    ),
    regexp = "ape::phylo"
  )
})
