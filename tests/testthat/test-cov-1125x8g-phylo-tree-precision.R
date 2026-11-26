## Coverage (cursor-cloud-1125x8g): phylo-tree-precision.R validators.

skip_if_not_installed("ape")

test_that(".gllvm_phylo_node_depths and labels on a three-tip tree", {
  tree <- ape::rtree(3)
  n_tot <- length(tree$tip.label) + tree$Nnode
  depths <- gllvmTMB:::.gllvm_phylo_node_depths(
    tree$edge, tree$edge.length, n_tot, root = n_tot
  )
  expect_length(depths, n_tot)
  expect_equal(depths[[n_tot]], 0)
  expect_true(all(depths[!is.na(depths)] >= 0))
  labs <- gllvmTMB:::.gllvm_phylo_augmented_node_labels(seq_len(n_tot), tree$tip.label)
  expect_length(labs, n_tot)
  expect_equal(labs[seq_along(tree$tip.label)], tree$tip.label)
})

test_that(".gllvm_validate_phylo_species checks tip membership", {
  tree <- ape::rtree(4)
  lv <- gllvmTMB:::.gllvm_validate_phylo_species(tree$tip.label[1:3], tree$tip.label)
  expect_length(lv, 3L)
  expect_error(
    gllvmTMB:::.gllvm_validate_phylo_species(c("ghost"), tree$tip.label),
    "Missing tip"
  )
  expect_error(gllvmTMB:::.gllvm_validate_phylo_species(character(0), tree$tip.label))
})

test_that(".gllvm_validate_phylo_tree enforces phylo contract", {
  tree <- ape::rtree(3)
  tree <- ape::compute.brlen(tree, method = "Grafen")
  info <- gllvmTMB:::.gllvm_validate_phylo_tree(tree)
  expect_type(info, "list")
  expect_true(info$n_tip >= 3L)
  expect_error(gllvmTMB:::.gllvm_validate_phylo_tree(list()), "phylo")
  bad <- tree
  bad$tip.label[2] <- bad$tip.label[1]
  expect_error(gllvmTMB:::.gllvm_validate_phylo_tree(bad), "unique")
})

test_that(".gllvm_phylo_tree_precision returns sparse inverse", {
  tree <- ape::rtree(5)
  tree <- ape::compute.brlen(tree, method = "Grafen")
  out <- gllvmTMB:::.gllvm_phylo_tree_precision(tree)
  expect_type(out, "list")
  expect_s4_class(out$precision, "dgCMatrix")
  expect_equal(nrow(out$precision), length(out$node_labels))
})