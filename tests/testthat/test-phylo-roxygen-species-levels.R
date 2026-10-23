test_that("phylo keyword example species remap has no NA", {
  skip_if_not_installed("ape")
  tree <- ape::rcoal(8)
  tree$tip.label <- paste0("sp", seq_len(8))
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1,
    n_species = 8,
    n_traits = 3,
    mean_species_per_site = 8,
    Cphy = ape::vcv(tree, corr = TRUE),
    sigma2_phy = rep(0.3, 3),
    seed = 1
  )
  sim$data$species <- factor(
    tree$tip.label[as.integer(sim$data$species)],
    levels = tree$tip.label
  )
  expect_false(anyNA(sim$data$species))
  expect_identical(levels(sim$data$species), tree$tip.label)
})
