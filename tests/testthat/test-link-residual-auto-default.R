## Phase 1b 2026-05-15: `extract_correlations()` `link_residual` default
## changed from "none" to "auto". Verify:
##   * No warning + zero numerical impact on Gaussian fits.
##   * Once-per-session warning fires on non-Gaussian fits when the
##     argument is missing.
##   * No warning when the user passes link_residual explicitly.
##   * Numerical: link_residual = "auto" reduces off-diagonal correlation
##     magnitudes on a binomial fit (the latent-liability diagonal grows
##     by pi^2/3, shrinking the standardised off-diagonals).
##
## Per Gauss's mu_t clamp (PR #100) the Beta / betabinomial saturation
## blow-up is fixed, so this default change is safe to ship.

## ---- fixtures -------------------------------------------------------------

make_gaussian_fit_for_default_test <- function(seed = 1L) {
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 30L, n_species = 4L, n_traits = 3L,
    mean_species_per_site = 3L,
    Lambda_B = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
    psi_B    = c(0.4, 0.3, 0.5),
    seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 1) +
            unique(0 + trait | site),
    data = s$data
  )))
}

make_binomial_fit_for_default_test <- function(seed = 2L) {
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 30L, n_species = 4L, n_traits = 3L,
    mean_species_per_site = 3L,
    Lambda_B = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
    psi_B    = c(0.4, 0.3, 0.5),
    sigma2_eps = 0.01, seed = seed
  )
  df <- s$data
  df$value <- as.integer(df$value > 0)
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = df,
    family = binomial()
  )))
}

reset_link_residual_warning_cache <- function() {
  options("gllvmTMB.warned_link_residual_default_changed" = NULL)
}

## ---- no warning on Gaussian fit ------------------------------------------

test_that("extract_correlations() emits NO link_residual warning on Gaussian fit", {
  skip_on_cran()
  reset_link_residual_warning_cache()
  fit_g <- make_gaussian_fit_for_default_test()
  expect_no_warning(
    suppressMessages(gllvmTMB::extract_correlations(fit_g, tier = "unit"))
  )
})

## ---- warning fires once on non-Gaussian + missing arg --------------------

test_that("extract_correlations() emits a one-shot warning on non-Gaussian + missing link_residual", {
  skip_on_cran()
  reset_link_residual_warning_cache()
  fit_b <- make_binomial_fit_for_default_test()
  ## First call -- warning fires.
  expect_warning(
    suppressMessages(gllvmTMB::extract_correlations(fit_b, tier = "unit")),
    class = "gllvmTMB_link_residual_default_changed"
  )
  ## Second call in the same session -- warning suppressed.
  expect_no_warning(
    suppressMessages(gllvmTMB::extract_correlations(fit_b, tier = "unit"))
  )
})

## ---- no warning when caller specifies the argument -----------------------

test_that("extract_correlations() emits NO warning when link_residual is passed explicitly", {
  skip_on_cran()
  reset_link_residual_warning_cache()
  fit_b <- make_binomial_fit_for_default_test()
  ## Both explicit values should be warning-free.
  expect_no_warning(
    suppressMessages(gllvmTMB::extract_correlations(
      fit_b, tier = "unit", link_residual = "auto"))
  )
  expect_no_warning(
    suppressMessages(gllvmTMB::extract_correlations(
      fit_b, tier = "unit", link_residual = "none"))
  )
})

## ---- numerical: auto shrinks off-diagonal magnitudes for non-Gaussian ----

test_that("extract_correlations(link_residual = 'auto') shrinks off-diagonal magnitudes vs 'none' for binomial fit", {
  skip_on_cran()
  reset_link_residual_warning_cache()
  fit_b <- make_binomial_fit_for_default_test()
  ## Use Wald (fast) so this stays a sub-second numerical comparison.
  cors_auto <- suppressMessages(suppressWarnings(gllvmTMB::extract_correlations(
    fit_b, tier = "unit", method = "wald", link_residual = "auto")))
  cors_none <- suppressMessages(gllvmTMB::extract_correlations(
    fit_b, tier = "unit", method = "wald", link_residual = "none"))
  ## Same trait pairs, same shape.
  expect_equal(nrow(cors_auto), nrow(cors_none))
  ## Off-diagonal absolute magnitudes should be SMALLER under 'auto',
  ## because the latent-liability diagonal grows by pi^2/3 and the
  ## standardised correlation shrinks. We compare the mean |r| across
  ## pairs to dodge per-pair simulation noise.
  expect_lt(mean(abs(cors_auto$correlation)),
            mean(abs(cors_none$correlation)))
})
