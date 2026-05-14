## Design 07 Stage 2: phylo() mode-dispatch wrapper.
## See dev/design/07-phylo-lme4-bar-syntax.md.
##
## The new `phylo()` keyword accepts an lme4-bar formula + a `mode = ...`
## argument and rewrites to one of the five existing canonical keywords
## (phylo_scalar / phylo_unique / phylo_indep / phylo_latent / phylo_dep)
## via the parser's rewrite_canonical_aliases() pass. Stage 2 covers the
## five existing T-column shapes; augmented LHS (intercept+slope,
## per-trait+slope) errors with a Stage 3 redirect.

## Tiny fixture: 1 site, 20 species, 3 traits, ultrametric tree.
make_phy_fixture <- function(seed = 7) {
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")
  set.seed(seed)
  n_sp <- 20
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy, sigma2_phy = rep(0.5, 3),
    Lambda_B = matrix(c(0.4, 0.2, 0.3), 3, 1),
    psi_B = c(0.05, 0.05, 0.05), seed = seed
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  list(df = df, tree = tree, Cphy = Cphy)
}

## ---- 1. phylo(1 | species) == phylo_scalar(species) ---------------------

test_that("phylo(1 | species) is byte-identical to phylo_scalar (via phylo_vcv global)", {
  skip_on_cran()
  fx <- make_phy_fixture()
  ## phylo_scalar / phylo() with LHS = `1` route through the legacy
  ## propto() engine slot which takes the dense `phylo_vcv =` global
  ## (Phase L Stage 1's in-keyword `tree =` is wired for the
  ## phylo_rr / phylo_diag slots, not the legacy propto slot).
  fit_new <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo(1 | species),
    data = fx$df, phylo_vcv = fx$Cphy, unit = "species"
  )))
  fit_canon <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_scalar(species),
    data = fx$df, phylo_vcv = fx$Cphy, unit = "species"
  )))
  expect_equal(fit_new$opt$convergence, 0L)
  expect_equal(fit_canon$opt$convergence, 0L)
  expect_equal(fit_new$opt$objective, fit_canon$opt$objective,
               tolerance = 1e-8)
})

## ---- 2. phylo(0 + trait | species, mode = "diag") == phylo_unique -------

test_that("phylo(0 + trait | species, mode = 'diag') is byte-identical to phylo_unique", {
  skip_on_cran()
  fx <- make_phy_fixture()
  fit_new <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo(0 + trait | species, mode = "diag",
                              tree = fx$tree),
    data = fx$df, unit = "species"
  )))
  fit_canon <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(species, tree = fx$tree),
    data = fx$df, unit = "species"
  )))
  expect_equal(fit_new$opt$convergence, 0L)
  expect_equal(fit_canon$opt$convergence, 0L)
  expect_equal(fit_new$opt$objective, fit_canon$opt$objective,
               tolerance = 1e-8)
})

## ---- 3. phylo(0 + trait | species, mode = "latent", d = 1) == phylo_latent ----

test_that("phylo(0 + trait | species, mode = 'latent', d = 1) is byte-identical to phylo_latent", {
  skip_on_cran()
  fx <- make_phy_fixture()
  fit_new <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo(0 + trait | species, mode = "latent",
                              d = 1, tree = fx$tree),
    data = fx$df, unit = "species"
  )))
  fit_canon <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1, tree = fx$tree),
    data = fx$df, unit = "species"
  )))
  expect_equal(fit_new$opt$convergence, 0L)
  expect_equal(fit_canon$opt$convergence, 0L)
  expect_equal(fit_new$opt$objective, fit_canon$opt$objective,
               tolerance = 1e-8)
})

## ---- 4. Augmented LHS errors with Stage-3 redirect ----------------------

test_that("phylo(1 + x | species) errors with Stage 3 redirect", {
  skip_on_cran()
  fx <- make_phy_fixture()
  ## Add a covariate to the data so the formula is well-formed for
  ## checking; the parser should reject before fitting.
  fx$df$temp <- stats::rnorm(nrow(fx$df))
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo(1 + temp | species, tree = fx$tree),
      data = fx$df, unit = "species"
    ))),
    regexp = "augmented LHS|intercept.*slope|Stage 3"
  )
})

## ---- 5. Backward compat: phylo(species) (bare name) still works --------

test_that("legacy phylo(species) still rewrites to engine path", {
  skip_on_cran()
  fx <- make_phy_fixture()
  ## Legacy bare-name form: phylo(species, vcv = Cphy) is the
  ## historical alias of phylo_scalar(species, vcv = Cphy).
  fit_legacy <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo(species),
    data = fx$df, phylo_vcv = fx$Cphy, unit = "species"
  )))
  expect_equal(fit_legacy$opt$convergence, 0L)
})

## ---- 6. mode mismatch with LHS errors -----------------------------------

test_that("phylo(0 + trait | species) without mode errors", {
  skip_on_cran()
  fx <- make_phy_fixture()
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo(0 + trait | species, tree = fx$tree),
      data = fx$df, unit = "species"
    ))),
    regexp = "requires `mode`|`mode`.*required|`mode`.*mandatory"
  )
})
