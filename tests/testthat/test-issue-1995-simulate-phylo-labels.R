## #1995: simulate_site_trait() uses species factor levels 1..I; ape::vcv() /
## in-keyword tree = keep tip labels. Naive sim -> fit must name the mismatch
## and how to relabel (not only "do not cover all species levels").

skip_if_no_ape <- function() {
  testthat::skip_if_not_installed("ape")
}

test_that("#1995 phylo_vcv mismatch after simulate_site_trait names relabel path", {
  skip_if_no_ape()
  set.seed(11271127L)
  n_species <- 10L
  tree <- ape::rcoal(n_species)
  Cphy <- ape::vcv(tree, corr = TRUE)

  sim <- simulate_site_trait(
    n_sites = 12L,
    n_species = n_species,
    n_traits = 2L,
    mean_species_per_site = 4L,
    n_predictors = 0L,
    sigma2_eps = 0.3,
    sigma2_phy = 0.4,
    Cphy = Cphy,
    seed = 1127L
  )
  df <- sim$data
  df$site <- factor(df$site)
  df$trait <- factor(df$trait)
  expect_equal(levels(df$species), as.character(seq_len(n_species)))
  expect_false(all(levels(df$species) %in% rownames(Cphy)))

  err <- tryCatch(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1),
      data = df,
      family = gaussian(),
      phylo_vcv = Cphy,
      unit = "site",
      silent = TRUE
    )),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(msg, "phylo_vcv")
  expect_match(msg, "simulate_site_trait")
  expect_match(msg, "rownames\\(phylo_vcv\\)")
})

test_that("#1995 in-keyword tree = mismatch names relabel path", {
  skip_if_no_ape()
  set.seed(11271127L)
  n_species <- 8L
  tree <- ape::rcoal(n_species)
  Cphy <- ape::vcv(tree, corr = TRUE)

  sim <- simulate_site_trait(
    n_sites = 10L,
    n_species = n_species,
    n_traits = 2L,
    mean_species_per_site = n_species,
    sigma2_phy = 0.3,
    Cphy = Cphy,
    seed = 42L
  )

  err <- tryCatch(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1, tree = tree),
      data = sim$data,
      family = gaussian(),
      unit = "site",
      silent = TRUE
    )),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(msg, "simulate_site_trait")
  expect_match(msg, "tip.label")
})