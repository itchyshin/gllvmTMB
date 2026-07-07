## The MCMCglmm-free sparse phylogenetic precision builder ported from drmTMB.
## Ground-truth check: inverting the augmented sparse A^{-1} and restricting to
## the tips must reproduce the phylogenetic correlation ape::vcv(tree, corr=TRUE)
## -- so the phylo_latent(tree=) path no longer needs MCMCglmm.

test_that(".gllvm_phylo_tree_precision matches ape::vcv on the tips (no MCMCglmm)", {
  skip_if_not_installed("ape")
  for (seed in c(1L, 7L, 42L)) {
    set.seed(seed)
    n <- 12L
    tree <- ape::rcoal(n)
    tree$tip.label <- paste0("t", seq_len(n))

    p <- gllvmTMB:::.gllvm_phylo_tree_precision(tree, correlation = TRUE)

    ## sparse dgCMatrix, symmetric, augmented (tips + internal nodes = 2n - 2)
    expect_s4_class(p$precision, "dgCMatrix")
    expect_equal(nrow(p$precision), 2L * n - 2L)
    expect_true(Matrix::isSymmetric(p$precision))

    ## invert -> restrict to tips -> compare to the phylo correlation
    A <- solve(as.matrix(p$precision))
    A_tip <- A[p$tip_node_index, p$tip_node_index]
    dimnames(A_tip) <- list(names(p$tip_node_index), names(p$tip_node_index))
    A_tip <- A_tip[tree$tip.label, tree$tip.label]

    Cphy <- ape::vcv(tree, corr = TRUE)[tree$tip.label, tree$tip.label]
    expect_equal(unname(A_tip), unname(Cphy), tolerance = 1e-6)

    ## log-det consistency: log det(A) = -log det(A^{-1})
    expect_equal(-p$log_det_precision, as.numeric(determinant(A, logarithm = TRUE)$modulus),
                 tolerance = 1e-6)
  }
})

test_that(".gllvm_phylo_tree_precision maps observed species into the augmented nodes", {
  skip_if_not_installed("ape")
  set.seed(3)
  tree <- ape::rcoal(6); tree$tip.label <- paste0("sp", 1:6)
  species <- factor(rep(tree$tip.label, each = 2))
  p <- gllvmTMB:::.gllvm_phylo_tree_precision(tree, species = species, correlation = TRUE)
  expect_identical(names(p$species_node_index), levels(species))
  ## each species maps to a valid augmented-node row
  expect_true(all(p$species_node_index >= 1L & p$species_node_index <= nrow(p$precision)))
  ## tips carry unit variance under the correlation form (diag of A on tips ~ 1)
  A <- solve(as.matrix(p$precision))
  expect_equal(unname(diag(A)[p$tip_node_index]), rep(1, length(tree$tip.label)), tolerance = 1e-6)
})
