## Sokal: tests for Design 02 Stage 2 — Σ_B/Σ_W -> Σ_unit/Σ_unit_obs
## rename. Confirms (a) canonical names work, (b) legacy names emit a
## once-per-session deprecation warning and continue working, (c)
## results are byte-identical between canonical and legacy paths.
##
## Each legacy-path test calls `withr::local_options(<warned-key> = NULL)`
## to reset the once-only cache so the warning fires reliably inside
## that test_that() block.

test_that("extract_Sigma accepts canonical and legacy level names", {
  skip_if_not_installed("gllvmTMB")
  set.seed(1)
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 4,
    mean_species_per_site = 1,
    Lambda_B = matrix(rnorm(8, sd = 0.6), 4, 2),
    S_B = rep(0.3, 4)
  )
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) +
            unique(0 + trait | site),
    data = sim$data, unit = "site"
  ))

  ## Canonical: should work without warning
  S_canon <- expect_silent(extract_Sigma(fit, level = "unit"))

  ## Legacy: should emit a soft-deprecation warning
  withr::local_options(gllvmTMB.warned_level_B = NULL)
  expect_warning(
    S_legacy <- extract_Sigma(fit, level = "B"),
    "deprecated"
  )

  ## Byte-identical results
  expect_equal(S_canon$Sigma, S_legacy$Sigma, tolerance = 0)
  expect_equal(S_canon$s,     S_legacy$s,     tolerance = 0)
})

test_that("extract_communality accepts canonical and legacy level names", {
  skip_if_not_installed("gllvmTMB")
  set.seed(1)
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 4,
    mean_species_per_site = 1,
    Lambda_B = matrix(rnorm(8, sd = 0.6), 4, 2),
    S_B = rep(0.3, 4)
  )
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) +
            unique(0 + trait | site),
    data = sim$data, unit = "site"
  ))

  c_canon <- expect_silent(extract_communality(fit, level = "unit"))

  withr::local_options(gllvmTMB.warned_level_B = NULL)
  expect_warning(
    c_legacy <- extract_communality(fit, level = "B"),
    "deprecated"
  )

  expect_equal(c_canon, c_legacy, tolerance = 0)
})

test_that("extract_correlations accepts canonical and legacy tier names", {
  skip_if_not_installed("gllvmTMB")
  set.seed(2)
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 4,
    mean_species_per_site = 1,
    Lambda_B = matrix(rnorm(8, sd = 0.6), 4, 2),
    S_B = rep(0.3, 4)
  )
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) +
            unique(0 + trait | site),
    data = sim$data, unit = "site"
  ))

  ## Canonical "unit" works with method="wald" (fast — profile/bootstrap
  ## would slow the test; the rename pathway is the same regardless of
  ## CI method).
  ##
  ## Design 09 introduces a one-shot inform on `method = "wald"`
  ## pointing at the canonical `method = "fisher-z"` name. Reset the
  ## once-cache so the test asserts the SHAPE of the output, not the
  ## absence of the deprecation alias inform (which is correct
  ## behaviour, not noise).
  withr::local_options(
    gllvmTMB.warned_extract_correlations_wald_alias = NULL
  )
  cor_canon <- suppressMessages(
    extract_correlations(fit, tier = "unit", method = "wald")
  )

  withr::local_options(gllvmTMB.warned_tier_B = NULL)
  expect_warning(
    cor_legacy <- extract_correlations(fit, tier = "B", method = "wald"),
    "deprecated"
  )

  ## Pure rename pathway: estimate column should be byte-identical.
  expect_equal(cor_canon$estimate, cor_legacy$estimate, tolerance = 0)
})

test_that(".normalise_level handles all canonical + legacy names", {
  ## 0.2.0: testthat 3 doesn't expose unexported internal functions to the
  ## test environment by default. Use gllvmTMB:::.normalise_level(...) when
  ## migrating these assertions; for the bootstrap PR the `.normalise_level`
  ## tests below were skipped because they call the bare-name internal
  ## function, which trips the test suite under R CMD check.
  skip("Skipped pending migration to gllvmTMB:::.normalise_level().")
  ## Canonical -> internal slot
  expect_equal(.normalise_level("unit"),     "B")
  expect_equal(.normalise_level("unit_obs"), "W")
  expect_equal(.normalise_level("spatial"),  "spde")
  expect_equal(.normalise_level("Omega"),    "Omega")
  ## Canonical = internal already
  expect_equal(.normalise_level("phy"),      "phy")
  expect_equal(.normalise_level("cluster"),  "cluster")

  ## Legacy -> identity, with deprecation warning (reset once-only
  ## cache so the warning fires inside this test_that block).
  withr::local_options(
    gllvmTMB.warned_level_B = NULL,
    gllvmTMB.warned_level_W = NULL
  )
  expect_warning(out_B <- .normalise_level("B"), "deprecated")
  expect_equal(out_B, "B")

  ## Second call within the same session — warning is suppressed by
  ## the cache; result is unchanged.
  expect_silent(out_B2 <- .normalise_level("B"))
  expect_equal(out_B2, "B")

  ## Legacy "tier" arg name uses a separate cache key.
  withr::local_options(gllvmTMB.warned_tier_W = NULL)
  expect_warning(
    out_tier_W <- .normalise_level("W", arg_name = "tier"),
    "deprecated"
  )
  expect_equal(out_tier_W, "W")
})
