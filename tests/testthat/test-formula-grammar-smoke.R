# Phase 0B.2 smoke tests for NEEDS-SMOKE rows in
# `docs/design/01-formula-grammar.md` status map.
#
# Each test exercises a parser-syntax row + (a) family or
# (b) keyword combination that the M0 baseline did not cover.
# All 9 tests satisfy 3-rule contract item 3 (feature combination).
#
# Spec: docs/dev-log/audits/2026-05-16-phase0b-2-smoke-test-spec.md
# Audit: docs/dev-log/audits/2026-05-16-phase0b-claimed-row-audit.md

# ---- Test 1: indep() non-Gaussian (FG-07) ------------------------------------

test_that("indep(0 + trait | g) parses and fits on a binomial-family fit (FG-07)", {
  set.seed(123)
  n_unit  <- 50
  n_trait <- 4
  df <- expand.grid(
    site  = factor(seq_len(n_unit)),
    trait = factor(paste0("t", seq_len(n_trait)))
  )
  df$value <- rbinom(nrow(df), size = 1, prob = 0.4)

  fit <- gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site),
    data   = df,
    trait  = "trait",
    unit   = "site",
    family = binomial()
  )

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)

  Sigma <- extract_Sigma(fit, level = "unit", part = "total")$Sigma
  expect_true(is.matrix(Sigma))
  expect_equal(dim(Sigma), c(n_trait, n_trait))
  ev <- eigen(Sigma, symmetric = TRUE, only.values = TRUE)$values
  expect_true(min(ev) >= -1e-8)
})

# ---- Test 2: dep() non-Gaussian (FG-08) --------------------------------------

test_that("dep(0 + trait | g) parses and fits on a Poisson-family fit (FG-08)", {
  set.seed(124)
  n_unit  <- 50
  n_trait <- 3
  df <- expand.grid(
    site  = factor(seq_len(n_unit)),
    trait = factor(paste0("t", seq_len(n_trait)))
  )
  df$value <- rpois(nrow(df), lambda = 2)

  fit <- gllvmTMB(
    value ~ 0 + trait + dep(0 + trait | site),
    data   = df,
    trait  = "trait",
    unit   = "site",
    family = poisson()
  )

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)

  Sigma <- extract_Sigma(fit, level = "unit", part = "total")$Sigma
  expect_true(is.matrix(Sigma))
  expect_equal(dim(Sigma), c(n_trait, n_trait))
  ev <- eigen(Sigma, symmetric = TRUE, only.values = TRUE)$values
  expect_true(min(ev) >= -1e-8)
})

# ---- Test 3: phylo_scalar() with vcv = Cphy (PHY-04) -------------------------

test_that("phylo_scalar(species, vcv = Cphy) fits via the dense-vcv path (PHY-04)", {
  testthat::skip_if_not_installed("ape")
  set.seed(125)
  n_sp <- 15
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)

  sim <- simulate_site_trait(
    n_sites = 30, n_species = n_sp, n_traits = 3,
    mean_species_per_site = 5,
    Cphy = Cphy, sigma2_phy = rep(0.4, 3), seed = 125
  )
  df <- sim$data
  levels(df$species) <- paste0("sp", seq_len(n_sp))

  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_scalar(species, vcv = Cphy),
    data    = df,
    trait   = "trait",
    unit    = "site",
    cluster = "species"
  )

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
})

# ---- Test 4: phylo_indep() (PHY-05a) -----------------------------------------

test_that("phylo_indep(0 + trait | species, tree = tree) parses and fits (PHY-05)", {
  testthat::skip_if_not_installed("ape")
  set.seed(126)
  n_sp <- 20
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)

  sim <- simulate_site_trait(
    n_sites = 40, n_species = n_sp, n_traits = 3,
    mean_species_per_site = 5,
    Cphy = Cphy, sigma2_phy = rep(0.4, 3), seed = 126
  )
  df <- sim$data
  levels(df$species) <- paste0("sp", seq_len(n_sp))

  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + trait | species, tree = tree),
    data    = df,
    trait   = "trait",
    unit    = "site",
    cluster = "species"
  )

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
})

# ---- Test 5: phylo_dep() (PHY-05b) -------------------------------------------

test_that("phylo_dep(0 + trait | species, tree = tree) parses and fits (PHY-05)", {
  testthat::skip_if_not_installed("ape")
  set.seed(127)
  n_sp <- 20
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)

  sim <- simulate_site_trait(
    n_sites = 40, n_species = n_sp, n_traits = 3,
    mean_species_per_site = 5,
    Cphy = Cphy, sigma2_phy = rep(0.4, 3), seed = 127
  )
  df <- sim$data
  levels(df$species) <- paste0("sp", seq_len(n_sp))

  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_dep(0 + trait | species, tree = tree),
    data    = df,
    trait   = "trait",
    unit    = "site",
    cluster = "species"
  )

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
})

# ---- Test 6: spatial_indep() (SPA-04a) ---------------------------------------

test_that("spatial_indep(0 + trait | sites, mesh = mesh) parses and fits (SPA-04)", {
  testthat::skip_if_not_installed("fmesher")
  set.seed(128)
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 1, n_traits = 3,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = rep(0.4, 3), seed = 128
  )
  df   <- sim$data
  mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.1)

  fit <- gllvmTMB(
    value ~ 0 + trait + spatial_indep(0 + trait | site, mesh = mesh),
    data  = df,
    trait = "trait",
    unit  = "site",
    mesh  = mesh
  )

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
})

# ---- Test 7: spatial_dep() (SPA-04b) -----------------------------------------

test_that("spatial_dep(0 + trait | sites, mesh = mesh) parses and fits (SPA-04)", {
  testthat::skip_if_not_installed("fmesher")
  set.seed(129)
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 1, n_traits = 3,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = rep(0.4, 3), seed = 129
  )
  df   <- sim$data
  mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.1)

  fit <- gllvmTMB(
    value ~ 0 + trait + spatial_dep(0 + trait | site, mesh = mesh),
    data  = df,
    trait = "trait",
    unit  = "site",
    mesh  = mesh
  )

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
})

# ---- Test 8: spatial_scalar() (SPA-03) ---------------------------------------

test_that("spatial_scalar(0 + trait | sites, mesh = mesh) parses and fits (SPA-03)", {
  testthat::skip_if_not_installed("fmesher")
  set.seed(130)
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 1, n_traits = 3,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = rep(0.4, 3), seed = 130
  )
  df   <- sim$data
  mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.1)

  fit <- gllvmTMB(
    value ~ 0 + trait + spatial_scalar(0 + trait | site, mesh = mesh),
    data  = df,
    trait = "trait",
    unit  = "site",
    mesh  = mesh
  )

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
})

# ---- Test 9: meta_V() single-V additive (MET-01) -----------------------------
# Added in PR-0B.4 once `meta_V` was added as the canonical alias of
# `meta_known_V` in R/brms-sugar.R. Both names desugar identically in
# the parser; this smoke confirms the new canonical name works.

test_that("meta_V(value, V = V) single-V additive fit parses and converges (MET-01)", {
  set.seed(131)
  n_eff   <- 50
  n_trait <- 3
  df <- expand.grid(
    site  = factor(seq_len(n_eff)),
    trait = factor(paste0("t", seq_len(n_trait)))
  )
  df$value <- rnorm(nrow(df), sd = 0.5)
  # Per-row known sampling variance (single-V, no within-study correlation):
  df$sampling_var <- runif(nrow(df), min = 0.02, max = 0.08)
  V <- diag(df$sampling_var)

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
            meta_V(value, V = V),
    data    = df,
    trait   = "trait",
    unit    = "site",
    known_V = V
  )

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
})
