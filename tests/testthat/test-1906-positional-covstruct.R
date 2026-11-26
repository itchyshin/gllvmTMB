## #1906: indep()/latent()/gaussian() as positional args after the formula must
## not surface as an opaque length-12 logical coercion.

test_that("#1906 positional covstruct/family args yield a gllvmTMB cli error", {
  set.seed(1126)
  sim <- simulate_site_trait(
    n_sites = 12,
    n_species = 4,
    n_traits = 2,
    mean_species_per_site = 3,
    n_predictors = 0,
    seed = 1126
  )
  expect_error(
  gllvmTMB(
    value ~ 1,
    indep(),
    latent(1 | site, d = 1),
    gaussian(),
    data = sim$data
  ),
    class = "gllvmTMB_misplaced_covstruct",
    regexp = "data.frame|formula"
  )
})