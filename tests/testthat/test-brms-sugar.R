# brms-style sugar (phylo / gr / meta) must produce the same LL as the
# glmmTMB-style equivalents on identical formulas.

skip_unless_ape <- function() testthat::skip_if_not_installed("ape")

test_that("phylo(species, vcv = Cphy) == propto(0+species | trait, Cphy)", {
  skip_unless_ape()
  set.seed(1)
  n_sp <- 12
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- simulate_site_trait(
    n_sites = 50, n_species = n_sp, n_traits = 3,
    mean_species_per_site = 5,
    Cphy = Cphy, sigma2_phy = c(0.6, 0.6, 0.6), seed = 1
  )
  df <- sim$data
  levels(df$species) <- paste0("sp", seq_len(n_sp))

  fit_brms <- gllvmTMB(value ~ 0 + trait + phylo(species, vcv = Cphy),
                       data = df, phylo_vcv = Cphy)
  fit_glmm <- gllvmTMB(value ~ 0 + trait + propto(0 + species | trait, Cphy),
                       data = df, phylo_vcv = Cphy)
  expect_equal(-fit_brms$opt$objective, -fit_glmm$opt$objective,
               tolerance = 1e-6)
})

test_that("gr(species, cov = Cphy) is equivalent to propto(0+species | trait, Cphy)", {
  skip_unless_ape()
  set.seed(2)
  n_sp <- 10
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- simulate_site_trait(
    n_sites = 40, n_species = n_sp, n_traits = 3,
    mean_species_per_site = 4,
    Cphy = Cphy, sigma2_phy = c(0.5, 0.5, 0.5), seed = 2
  )
  df <- sim$data
  levels(df$species) <- paste0("sp", seq_len(n_sp))

  fit_brms <- gllvmTMB(value ~ 0 + trait + gr(species, cov = Cphy),
                       data = df, phylo_vcv = Cphy)
  fit_glmm <- gllvmTMB(value ~ 0 + trait + propto(0 + species | trait, Cphy),
                       data = df, phylo_vcv = Cphy)
  expect_equal(-fit_brms$opt$objective, -fit_glmm$opt$objective,
               tolerance = 1e-6)
})

test_that("phylo() works in a combined formula with rr() and diag()", {
  skip_unless_ape()
  set.seed(3)
  n_sp <- 12
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- simulate_site_trait(
    n_sites = 60, n_species = n_sp, n_traits = 4,
    mean_species_per_site = 6,
    Cphy = Cphy, sigma2_phy = c(0.5, 0.5, 0.5, 0.5),
    Lambda_B = matrix(c(0.8, 0.5, -0.2, 0.3,
                        0.2, -0.4, 0.6, 0.1),
                      nrow = 4, ncol = 2),
    seed = 3
  )
  df <- sim$data
  levels(df$species) <- paste0("sp", seq_len(n_sp))

  fit <- gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
            latent(0 + trait | site, d = 2) +
            unique(0 + trait | site) +
            phylo(species, vcv = Cphy),
    data = df, phylo_vcv = Cphy
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(fit$use$rr_B)
  expect_true(fit$use$propto)
})
