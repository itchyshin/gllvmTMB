## Tests for the formula-keyword consistency fix:
## the `vcv =` argument inside `phylo()` and the `cov =` argument inside
## `gr()` are decorative and optional. The covariance matrix actually
## used by the engine comes from the top-level `phylo_vcv =` argument
## to gllvmTMB(). Both `phylo(species)` and `phylo(species, vcv = Cphy)`
## should fit and give identical results, paralleling phylo_latent(species).

skip_if_no_ape <- function() {
  if (!requireNamespace("ape", quietly = TRUE)) skip("ape not installed")
}

make_phylo_data <- function(n_sp = 20, n_traits = 3, seed = 1) {
  skip_if_no_ape()
  set.seed(seed)
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- simulate_site_trait(
    n_sites = 30, n_species = n_sp, n_traits = n_traits, mean_species_per_site = 5,
    Lambda_B = matrix(0, n_traits, 1), S_B = rep(0.05, n_traits),
    Cphy = Cphy, sigma2_phy = rep(0.5, n_traits),
    beta = matrix(0, n_traits, 2), seed = seed
  )
  d <- sim$data
  levels(d$species) <- tree$tip.label
  list(data = d, Cphy = Cphy, tree = tree)
}

test_that("phylo(species) without vcv = fits", {
  s <- make_phylo_data()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + phylo(species),
    data = s$data, phylo_vcv = s$Cphy
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_true(fit$use$propto)
})

test_that("phylo(species, vcv = Cphy) is backward compatible", {
  s <- make_phylo_data()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + phylo(species, vcv = s$Cphy),
    data = s$data, phylo_vcv = s$Cphy
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_true(fit$use$propto)
})

test_that("phylo() with and without vcv = give identical fits", {
  s <- make_phylo_data()
  fit_a <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + phylo(species),
    data = s$data, phylo_vcv = s$Cphy
  )))
  fit_b <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + phylo(species, vcv = s$Cphy),
    data = s$data, phylo_vcv = s$Cphy
  )))
  expect_equal(fit_a$opt$objective, fit_b$opt$objective, tolerance = 1e-8)
  ## Reported parameters should match too
  expect_equal(as.numeric(fit_a$report$lam_phy),
               as.numeric(fit_b$report$lam_phy),
               tolerance = 1e-6)
})

test_that("gr(species) without cov = fits (parallels phylo)", {
  s <- make_phylo_data()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + gr(species),
    data = s$data, phylo_vcv = s$Cphy
  )))
  expect_equal(fit$opt$convergence, 0L)
})

test_that("gr(species, cov = M) is backward compatible", {
  s <- make_phylo_data()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + gr(species, cov = s$Cphy),
    data = s$data, phylo_vcv = s$Cphy
  )))
  expect_equal(fit$opt$convergence, 0L)
})

test_that("phylo(species) and phylo_latent(species) have parallel API: neither needs the matrix in the formula", {
  ## This is the consistency check the user pointed at: both formula
  ## keywords accept just the species column; the matrix is supplied
  ## via the top-level phylo_vcv (or phylo_tree) argument.
  s <- make_phylo_data()
  fit_phylo <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + phylo(species),
    data = s$data, phylo_vcv = s$Cphy
  )))
  fit_phylo_rr <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1),
    data = s$data, phylo_vcv = s$Cphy
  )))
  expect_equal(fit_phylo$opt$convergence, 0L)
  expect_equal(fit_phylo_rr$opt$convergence, 0L)
  ## The two are different models (single shared phylo scaling vs per-trait
  ## phylo loadings); we just verify both APIs accept the parallel formula
  ## form without `vcv =`.
})
