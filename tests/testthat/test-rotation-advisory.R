## Tests for the rotation advisory hook in getLoadings(): when a user
## fits an rr() model with d > 1 and no lambda_constraint, accessing the
## raw Lambda via getLoadings(level, rotate = "none") should surface a
## one-shot informational message pointing at suggest_lambda_constraint()
## or rotate_loadings().

test_that("rr B fit with d > 1 and no constraint stores advisory flag", {
  set.seed(1)
  s <- simulate_site_trait(
    n_sites = 40,
    n_species = 1,
    n_traits = 4,
    mean_species_per_site = 1,
    Lambda_B = matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), 4, 2),
    psi_B = rep(0, 4),
    beta = matrix(0, 4, 2),
    seed = 1
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = s$data
  )
  expect_true(isTRUE(fit$needs_rotation_advice$B))
  expect_false(isTRUE(fit$needs_rotation_advice$W))
  expect_false(isTRUE(fit$needs_rotation_advice$phy))
})

test_that("rr B fit with lambda_constraint clears the advisory flag", {
  set.seed(1)
  s <- simulate_site_trait(
    n_sites = 40,
    n_species = 1,
    n_traits = 4,
    mean_species_per_site = 1,
    Lambda_B = matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), 4, 2),
    psi_B = rep(0, 4),
    beta = matrix(0, 4, 2),
    seed = 1
  )
  cnst <- matrix(NA_real_, 4, 2)
  diag(cnst) <- 1
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = s$data,
    lambda_constraint = list(unit = cnst)
  )
  expect_false(isTRUE(fit$needs_rotation_advice$B))
})

test_that("rr B fit with d = 1 does NOT trigger advisory (no rotational ambiguity)", {
  set.seed(1)
  s <- simulate_site_trait(
    n_sites = 40,
    n_species = 1,
    n_traits = 4,
    mean_species_per_site = 1,
    Lambda_B = matrix(c(1, 0.5, -0.4, 0.3), 4, 1),
    psi_B = rep(0, 4),
    beta = matrix(0, 4, 2),
    seed = 1
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = s$data
  )
  expect_false(isTRUE(fit$needs_rotation_advice$B))
})

test_that("phylo_dep is not diagnosed as a rotation-ambiguous latent fit", {
  skip_if_not_installed("ape")
  set.seed(20260711)
  n_species <- 24L
  n_traits <- 3L
  tree <- ape::rcoal(n_species)
  tree$tip.label <- paste0("sp", seq_len(n_species))
  dat <- expand.grid(
    species = tree$tip.label,
    trait = paste0("trait_", seq_len(n_traits)),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  dat$species <- factor(dat$species, levels = tree$tip.label)
  dat$trait <- factor(dat$trait, levels = paste0("trait_", seq_len(n_traits)))
  dat$value <- stats::rnorm(nrow(dat))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + phylo_dep(0 + trait | species, tree = tree),
    data = dat,
    trait = "trait",
    unit = "species",
    control = gllvmTMBcontrol(se = FALSE)
  )))

  expect_false(isTRUE(fit$needs_rotation_advice$phy))
  health <- check_gllvmTMB(fit)
  expect_false(any(health$component %in% c(
    "rotation_convention_phylo",
    "weak_axis_phylo"
  )))
})

test_that("getLoadings(rotate = 'none') emits the informational message", {
  set.seed(1)
  s <- simulate_site_trait(
    n_sites = 40,
    n_species = 1,
    n_traits = 4,
    mean_species_per_site = 1,
    Lambda_B = matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), 4, 2),
    psi_B = rep(0, 4),
    beta = matrix(0, 4, 2),
    seed = 1
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = s$data
  )
  expect_message(
    getLoadings(fit, level = "unit", rotate = "none"),
    regexp = "rotation"
  )
})

test_that("getLoadings(rotate = 'varimax') does NOT emit the message", {
  set.seed(1)
  s <- simulate_site_trait(
    n_sites = 40,
    n_species = 1,
    n_traits = 4,
    mean_species_per_site = 1,
    Lambda_B = matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), 4, 2),
    psi_B = rep(0, 4),
    beta = matrix(0, 4, 2),
    seed = 1
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = s$data
  )
  expect_no_message(getLoadings(fit, level = "unit", rotate = "varimax"))
})
