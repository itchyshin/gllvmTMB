## #1766: phylo_*() with a non-default bare grouping and omitted cluster
## must adopt that column instead of the placeholder species factor.

test_that("phylo_latent(taxon, vcv = Cphy) fits when cluster is omitted (#1766)", {
  skip_on_cran()
  skip_if_not_installed("ape")
  set.seed(1766L)
  n_sp <- 8L
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- simulate_site_trait(
    n_sites = 1L, n_species = n_sp, n_traits = 3L,
    mean_species_per_site = n_sp,
    Cphy = Cphy, sigma2_phy = rep(0.5, 3L),
    Lambda_B = matrix(c(0.4, 0.2, 0.3), 3L, 1L),
    psi_B = c(0.05, 0.05, 0.05), seed = 1766L
  )
  df <- sim$data
  df$taxon <- df$species
  df$species <- NULL
  lv <- levels(df$taxon)
  rownames(Cphy) <- colnames(Cphy) <- lv
  ctrl <- gllvmTMBcontrol(n_init = 1L, se = FALSE, laplace_auto_refit = FALSE)

  fit_omit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + phylo_latent(taxon, d = 1, vcv = Cphy),
    data = df, unit = "site",
    family = gaussian(), control = ctrl, silent = TRUE
  )))
  fit_cluster <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + phylo_latent(taxon, d = 1, vcv = Cphy),
    data = df, unit = "site", cluster = "taxon",
    family = gaussian(), control = ctrl, silent = TRUE
  )))

  expect_s3_class(fit_omit, "gllvmTMB")
  expect_equal(fit_omit$opt$convergence, 0L)
  expect_equal(
    as.numeric(stats::logLik(fit_omit)),
    as.numeric(stats::logLik(fit_cluster)),
    tolerance = 1e-8
  )
})