## Issue #1398: extract_phylo_signal(ci = TRUE, method = "bootstrap") used to
## log "running N replicates" and return NA bounds without refitting anything.

test_that("extract_phylo_signal(ci=TRUE, method='bootstrap') runs the bootstrap (#1398)", {
  skip_on_cran()
  skip_if_not_installed("ape")
  set.seed(7)
  n_sp <- 20L
  Tn <- 3L
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 15,
    n_species = n_sp,
    n_traits = Tn,
    mean_species_per_site = n_sp,
    Cphy = Cphy,
    sigma2_phy = rep(1.5, Tn),
    sigma2_sp = rep(0.7, Tn),
    Lambda_B = matrix(0, Tn, 1L),
    psi_B = rep(0, Tn),
    sigma2_eps = 0.3,
    seed = 7
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(species) + unique(0 + trait | species),
    data = df,
    phylo_tree = tree,
    cluster = "species",
    family = stats::gaussian(),
    silent = TRUE
  )))

  b <- suppressMessages(
    extract_phylo_signal(fit, ci = TRUE, method = "bootstrap", nsim = 10L, seed = 1L)
  )
  expect_true(all(b$H2_method == "bootstrap"))
  expect_false(anyNA(b$H2_lower))
  expect_false(anyNA(b$H2_upper))

  ## Same target + method + seed must agree with the confint() worker.
  ref <- gllvmTMB:::.phylo_signal_bootstrap_ci(fit, level = 0.95, nsim = 10L, seed = 1L)
  expect_equal(b$H2_lower, ref$lower, tolerance = 1e-8)
  expect_equal(b$H2_upper, ref$upper, tolerance = 1e-8)
})
