## Regression coverage for Ayumi-495/avian_trait_scales#14:
## multi-tier phylogenetic fits should not have empty derived-CI entry points
## where an admitted fallback or phy-tier route exists.

skip_unless_ape_derived_phylo <- function() {
  skip_on_cran()
  skip_if_not_installed("ape")
}

.derived_phylo_ci_cache <- new.env(parent = emptyenv())

make_derived_phylo_ci_fit <- function(seed = 914L) {
  if (!is.null(.derived_phylo_ci_cache$fit)) {
    return(.derived_phylo_ci_cache$fit)
  }
  set.seed(seed)
  n_sp <- 14L
  n_sites <- 3L
  n_traits <- 3L
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites,
    n_species = n_sp,
    n_traits = n_traits,
    mean_species_per_site = n_sp,
    Cphy = Cphy,
    sigma2_phy = rep(0.4, n_traits),
    Lambda_B = matrix(c(0.5, 0.2, -0.3), n_traits, 1L),
    psi_B = rep(0.2, n_traits),
    psi_W = rep(0.1, n_traits),
    beta = matrix(0, n_traits, 2L),
    seed = seed
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_latent(species, d = 1, tree = tree) +
      phylo_unique(species) +
      latent(0 + trait | species, d = 1) +
      unique(0 + trait | species) +
      latent(0 + trait | site_species, d = 1) +
      unique(0 + trait | site_species),
    data = df,
    unit = "species",
    unit_obs = "site_species",
    phylo_tree = tree,
    silent = TRUE
  )))
  .derived_phylo_ci_cache$fit <- fit
  fit
}

test_that("multi-tier phylo_signal profile fallback returns Wald bounds, not empty intervals", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_unless_ape_derived_phylo()
  fit <- make_derived_phylo_ci_fit()
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_true(isTRUE(fit$use$rr_B))
  expect_true(isTRUE(fit$use$rr_W))

  ci <- suppressMessages(profile_ci_phylo_signal(
    fit,
    trait_idx = 1L,
    level = 0.80
  ))
  expect_s3_class(ci, "data.frame")
  expect_equal(nrow(ci), 1L)
  expect_equal(ci$method, "wald(numeric)")
  expect_true(all(is.finite(ci$lower)))
  expect_true(all(is.finite(ci$upper)))
  expect_true(all(ci$lower >= -1e-8 & ci$upper <= 1 + 1e-8))
})

test_that("phylogenetic communality is admitted through extractor, profile helper, and confint token", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_unless_ape_derived_phylo()
  fit <- make_derived_phylo_ci_fit()

  c2 <- suppressMessages(extract_communality(
    fit,
    level = "phy",
    link_residual = "none"
  ))
  expect_type(c2, "double")
  expect_equal(length(c2), fit$n_traits)
  expect_true(all(c2 >= -1e-8 & c2 <= 1 + 1e-8))

  ci_profile <- suppressMessages(profile_ci_communality(
    fit,
    tier = "phy",
    trait_idx = 1L,
    level = 0.80
  ))
  expect_s3_class(ci_profile, "data.frame")
  expect_equal(ci_profile$tier, "phy")
  expect_true(is.finite(ci_profile$lower) || is.finite(ci_profile$upper))
  expect_true(all(
    ci_profile[is.finite(ci_profile$lower), "lower"] >= -1e-8,
    ci_profile[is.finite(ci_profile$upper), "upper"] <= 1 + 1e-8
  ))

  ci_wald <- suppressMessages(confint(
    fit,
    parm = "communality:phy:trait_1",
    method = "wald",
    level = 0.80
  ))
  expect_true(is.matrix(ci_wald))
  expect_equal(rownames(ci_wald), "communality:phy:trait_1")
  expect_equal(ncol(ci_wald), 2L)
  expect_true(all(is.finite(ci_wald)))
  expect_true(all(ci_wald >= -1e-8 & ci_wald <= 1 + 1e-8))
})

test_that("bootstrap summary collector stores phylogenetic communality when requested", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_unless_ape_derived_phylo()
  fit <- make_derived_phylo_ci_fit()

  summaries <- gllvmTMB:::.extract_summaries(
    fit,
    level = "phy",
    what = "communality",
    link_residual = "none"
  )
  expect_true("communality_phy" %in% names(summaries))
  expect_equal(
    unname(summaries$communality_phy),
    unname(suppressMessages(extract_communality(
      fit,
      level = "phy",
      link_residual = "none"
    ))),
    tolerance = 1e-10
  )
})
