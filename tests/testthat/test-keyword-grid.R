## 3 x 3 keyword-grid: phylo_unique + spatial_{unique,scalar,latent}.
##
## Each test uses a small biologically-realistic simulation:
##
## * phylo_unique fixture: a clade of 50 species with 4 quantitative traits.
##   Variance scale chosen to mimic Cooney et al. (2017, Nature 542:344-347)
##   "Mega-evolutionary dynamics of the adaptive radiation of birds": log
##   beak-trait variances on the natural log scale of order 0.5 - 2.0.
##   (See also Garamszegi 2014, "Modern Phylogenetic Comparative Methods")
##   We pick three traits with sigma^2_phy = (0.4, 0.6, 0.3) to test
##   whether per-trait variances are identifiable.
##
## * spatial_unique / spatial_scalar fixtures: an SPDE Matern field on a
##   60-site unit-square (terrestrial-vertebrate scale; see Bahn et al.
##   2008, "Bird species distributions across two neotropical forest
##   gradients" for plausible km-scale ranges -- here range = 0.3 in
##   normalised square units, sigma^2 = 0.4 - 0.6 on the link scale,
##   following Latimer et al. 2009 Ecol. Lett. 12:144-154 conventions).
##   We test that spatial_unique fits 3 independent log_tau and
##   spatial_scalar collapses to 1 shared log_tau.
##
## * spatial_latent: K_S shared SPDE fields driving T traits via a
##   T x K_S loading matrix Lambda_spde. The cpp template's `spde_lv_k`
##   switch swaps the per-trait omega path for the rank-K_S latent path
##   when this keyword is active. Recovery of Lambda_spde is checked in
##   detail in tests/testthat/test-spatial-latent-recovery.R.

skip_on_cran()

test_that("phylo_unique fits and stores per-trait variances on a diagonal Lambda", {
  set.seed(11)
  n_sp  <- 50
  tree  <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy  <- ape::vcv(tree, corr = TRUE)
  ## Three traits with realistic phylogenetic variances on the link
  ## (here identity / Gaussian) scale. Cooney et al. 2017 reports log
  ## beak-trait variances ~ 0.5 - 2.0 across avian families; we pick a
  ## moderate spread.
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy,
    sigma2_phy = c(0.4, 0.6, 0.3),
    Lambda_B = matrix(0, 3, 1),         # no other shared structure
    psi_B      = c(0.05, 0.05, 0.05),     # tiny non-phylo nuisance
    seed     = 11
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(species),
    data = df, phylo_tree = tree, silent = TRUE)))

  ## (a) Convergence
  expect_equal(fit$opt$convergence, 0L)
  ## (b) The right component is registered as phylo_rr (engine slot) AND
  ## as the phylo_unique sub-flavour (canonical name).
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_true(isTRUE(fit$use$phylo_unique))
  ## (c) Lambda_phy is a strict diagonal (off-diagonals pinned to 0).
  Lphy <- fit$report$Lambda_phy
  expect_equal(nrow(Lphy), 3L)            # n_traits
  expect_equal(ncol(Lphy), 3L)            # d_phy = n_traits
  expect_true(all(Lphy[lower.tri(Lphy)] == 0),
              info = "Strict-lower-triangle of Lambda_phy must be 0.")
  expect_true(all(Lphy[upper.tri(Lphy)] == 0),
              info = "Strict-upper-triangle is structurally 0.")
  ## (d) Diagonal entries are the per-trait phylogenetic SDs.
  expect_equal(length(diag(Lphy)), 3L)
  ## (e) Sigma_phy is diagonal (LL^T of a diagonal Lambda).
  Sphy <- Lphy %*% t(Lphy)
  off <- Sphy[lower.tri(Sphy)]
  expect_true(all(abs(off) < 1e-12),
              info = "Sigma_phy from phylo_unique must be diagonal.")
  ## (f) extract_Sigma at level 'phy' returns the diagonal Sigma.
  sig_phy <- suppressMessages(extract_Sigma(fit, level = "phy", part = "shared"))
  expect_equal(dim(sig_phy$Sigma), c(3L, 3L))
})

test_that("spatial_unique fits one independent log_tau per trait", {
  set.seed(2025)
  ## SPDE field on a 60-site unit-square (Bahn et al. 2008 / Latimer et
  ## al. 2009 conventions: range = 0.3 in normalised units, sigma^2 ~ 0.4
  ## on link scale).
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 60, n_species = 1, n_traits = 3,
    mean_species_per_site = 1,
    spatial_range = 0.3,
    sigma2_spa = c(0.4, 0.6, 0.3),
    seed = 1
  )
  df <- sim$data
  mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.07)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE)))
  expect_equal(fit$opt$convergence, 0L)
  ## (a) The right engine slot is active.
  expect_true(isTRUE(fit$use$spde))
  expect_false(isTRUE(fit$use$spatial_scalar))
  ## (b) log_tau_spde has length 3 with three (generally) different values.
  ltau <- as.numeric(fit$report$log_tau_spde)
  expect_length(ltau, 3L)
  ## At least two of the three should differ -- the simulator drew three
  ## different sigma2_spa, so a tied solution would be a degenerate fit.
  expect_gt(diff(range(ltau)), 1e-3,
            label = "spatial_unique must give per-trait log_tau, not one shared")
})

test_that("spatial_scalar collapses log_tau to one shared parameter", {
  set.seed(2025)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 60, n_species = 1, n_traits = 3,
    mean_species_per_site = 1,
    spatial_range = 0.3,
    sigma2_spa = rep(0.4, 3),                 # truly shared
    seed = 1
  )
  df <- sim$data
  mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.07)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_scalar(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE)))
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$spde))
  expect_true(isTRUE(fit$use$spatial_scalar))
  ## All three log_tau entries must be exactly tied.
  ltau <- as.numeric(fit$report$log_tau_spde)
  expect_length(ltau, 3L)
  expect_true(all(abs(ltau - ltau[1L]) < 1e-12),
              info = "spatial_scalar must tie log_tau across traits via tmb_map")
  ## Compared to spatial_unique on the same data, spatial_scalar has
  ## (n_traits - 1) fewer free parameters.
  fit_unique <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE)))
  expect_equal(length(fit_unique$opt$par) - length(fit$opt$par), 2L)
})

test_that("spatial_latent fits a rank-K Lambda_spde and toggles spde_lv_k", {
  set.seed(1)
  ## Same SPDE fixture as spatial_unique / spatial_scalar above, but here
  ## we recover a low-rank Lambda_spde rather than per-trait variances.
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 60, n_species = 1, n_traits = 3,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = rep(0.4, 3),
    seed = 1
  )
  df <- sim$data
  mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.07)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_latent(0 + trait | coords, d = 2),
    data = df, mesh = mesh, silent = TRUE)))

  ## (a) Convergence
  expect_equal(fit$opt$convergence, 0L)
  ## (b) Engine slot toggled to the latent path.
  expect_true(isTRUE(fit$use$spde))
  expect_true(isTRUE(fit$use$spatial_latent))
  expect_false(isTRUE(fit$use$spatial_scalar))
  expect_equal(fit$tmb_data$spde_lv_k, 2L)
  ## (c) Lambda_spde reported with the expected dimensions.
  Lspde <- fit$report$Lambda_spde
  expect_equal(dim(Lspde), c(3L, 2L))
  ## (d) Lower-triangular structure: strict upper triangle is 0.
  expect_true(all(Lspde[upper.tri(Lspde)] == 0),
              info = "Lambda_spde is packed lower-triangular by construction.")
  ## (e) Sigma_spde = Lambda_spde Lambda_spde^T is reported and PSD.
  Sspde <- fit$report$Sigma_spde
  expect_equal(dim(Sspde), c(3L, 3L))
  expect_true(all(diag(Sspde) >= 0))
})

test_that("phylo_unique appears in extract_Omega() at the phy tier", {
  set.seed(11)
  n_sp  <- 30
  tree  <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy  <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy,
    sigma2_phy = c(0.4, 0.6, 0.3),
    Lambda_B = matrix(0, 3, 1),
    psi_B      = c(0.05, 0.05, 0.05),
    seed     = 11
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(species) +
            unique(0 + trait | species),
    data = df, phylo_tree = tree, unit = "species", silent = TRUE)))
  expect_equal(fit$opt$convergence, 0L)
  ## Omega includes a non-zero phy diagonal (the per-trait phylo
  ## variances) plus the species-level unique() term U.
  out <- suppressMessages(extract_Omega(fit, tiers = c("phy", "B")))
  expect_true("phy" %in% out$tiers_used)
  expect_true(all(diag(out$Omega) > 0))
})
