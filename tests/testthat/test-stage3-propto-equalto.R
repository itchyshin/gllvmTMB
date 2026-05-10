# Stage 3: propto() (phylogenetic random effect) and equalto() (known V).
# Cross-validate against glmmTMB on identical formulas.

skip_if_not_glmmTMB <- function() {
  testthat::skip_if_not_installed("glmmTMB")
  testthat::skip_if_not_installed("ape")
}

simulate_phylo_data <- function(n_sites = 50, n_species = 12, n_traits = 3,
                                sigma2_phy = c(0.6, 0.6, 0.6), seed = 11) {
  set.seed(seed)
  tree <- ape::rcoal(n_species)
  tree$tip.label <- paste0("sp", seq_len(n_species))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- simulate_site_trait(
    n_sites = n_sites, n_species = n_species, n_traits = n_traits,
    mean_species_per_site = 5,
    Cphy = Cphy, sigma2_phy = sigma2_phy,
    seed = seed
  )
  df <- sim$data
  levels(df$species) <- paste0("sp", seq_len(n_species))
  list(data = df, Cphy = Cphy, sim = sim)
}

test_that("Stage 3: propto() matches glmmTMB log-likelihood exactly", {
  skip_if_not_glmmTMB()
  s <- simulate_phylo_data()
  df <- s$data; Cphy <- s$Cphy
  fit_g <- gllvmTMB(
    value ~ 0 + trait + propto(0 + species | trait, Cphy),
    data = df, phylo_vcv = Cphy
  )
  expect_s3_class(fit_g, "gllvmTMB_multi")
  expect_equal(fit_g$opt$convergence, 0L)

  ll_g <- -fit_g$opt$objective
  fit_t <- suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + propto(0 + species | trait, Cphy),
    data = df, REML = FALSE
  ))
  ll_t <- as.numeric(stats::logLik(fit_t))
  testthat::skip_if(is.na(ll_t),
                    "glmmTMB hit non-PD Hessian on this dataset")
  expect_equal(ll_g, ll_t, tolerance = 1e-4)
})

test_that("Stage 3: propto() recovers loglambda_phy reasonably", {
  s <- simulate_phylo_data(sigma2_phy = c(0.8, 0.8, 0.8), seed = 23)
  fit_g <- gllvmTMB(
    value ~ 0 + trait + propto(0 + species | trait, Cphy),
    data = s$data, phylo_vcv = s$Cphy
  )
  expect_equal(fit_g$opt$convergence, 0L)
  ## True log-lambda = log(sigma2_phy) = log(0.8) = -0.22
  est <- fit_g$opt$par["loglambda_phy"]
  expect_equal(unname(as.numeric(est)), log(0.8), tolerance = 0.7)
})

test_that("Stage 3: rr + diag + propto can run together (smoke test)", {
  skip_if_not_glmmTMB()
  s <- simulate_phylo_data(n_sites = 80, n_species = 14, n_traits = 4,
                           sigma2_phy = c(0.5, 0.5, 0.5, 0.5), seed = 13)
  df <- s$data; Cphy <- s$Cphy

  ## Add a between-site rr+diag layer to the simulated data.
  ## This is just a smoke test that the combined model fits without error.
  fit_g <- gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
            latent(0 + trait | site, d = 2) +
            unique(0 + trait | site) +
            propto(0 + species | trait, Cphy),
    data = df, phylo_vcv = Cphy
  )
  expect_equal(fit_g$opt$convergence, 0L)
  expect_true(fit_g$use$propto)
  expect_true(fit_g$use$rr_B)
  expect_true(fit_g$use$diag_B)

  ## Cross-check LL against glmmTMB on the same formula. glmmTMB-side
  ## uses its own `rr()` / `diag()` keywords (NOT gllvmTMB's canonical
  ## latent()/unique()).
  ll_g <- -fit_g$opt$objective
  fit_t <- suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
            rr(0 + trait | site, d = 2) +
            diag(0 + trait | site) +
            propto(0 + species | trait, Cphy),
    data = df, REML = FALSE
  ))
  ll_t <- as.numeric(stats::logLik(fit_t))
  testthat::skip_if(is.na(ll_t),
                    "glmmTMB hit non-PD Hessian on combined model")
  expect_equal(ll_g, ll_t, tolerance = 1e-3)
})

test_that("Stage 3: propto() requires phylo_vcv argument", {
  s <- simulate_phylo_data()
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + propto(0 + species | trait, Cphy),
      data = s$data, phylo_vcv = NULL
    ),
    "phylo_vcv"
  )
})
