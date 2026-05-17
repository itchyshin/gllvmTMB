## M1.2 smoke tests for the mixed-family fixture.
##
## The fixture (3-family + 5-family) lives in:
##   inst/extdata/mixed-family-fixture.rds  -- data + DGP truth (cached)
##   R/data-mixed-family.R                  -- builder + loader + fit_*()
##
## These smoke tests verify:
##   (a) the cached RDS loads cleanly via load_mixed_family_fixture();
##   (b) the cached data has the expected shape (n_sites x n_traits
##       in long format, with `family` column);
##   (c) re-running the builder from scratch is bit-identical to the
##       cache (the DGP is deterministic);
##   (d) fit_mixed_family_fixture() converges on both fixtures.
##
## All tests are skip_on_cran() because the fit step takes a few
## seconds and the binary RDS adds package weight.

# ---- shape + load ---------------------------------------------------

test_that("3-family fixture loads from cache with expected shape (M1.2; T=3 d=1)", {
  skip_on_cran()
  fx <- gllvmTMB:::load_mixed_family_fixture(n_families = 3L)
  expect_named(fx, c("data", "truth", "family_list", "family_var"),
               ignore.order = TRUE)
  expect_equal(fx$family_var, "family")
  expect_identical(fx$truth$families,
                   c("gaussian", "binomial", "poisson"))
  expect_equal(fx$truth$n_traits, 3L)
  expect_equal(fx$truth$d_B, 1L)
  expect_equal(nrow(fx$data), 60L * 3L)
  expect_true(all(c("trait", "family", "value", "site") %in% names(fx$data)))
  expect_identical(levels(fx$data$family),
                   c("gaussian", "binomial", "poisson"))
})

test_that("5-family fixture loads from cache with expected shape (M1.2; T=8 d=2)", {
  skip_on_cran()
  fx <- gllvmTMB:::load_mixed_family_fixture(n_families = 5L)
  expect_equal(fx$family_var, "family")
  expect_identical(fx$truth$families,
                   c("gaussian", "binomial", "poisson", "Gamma", "nbinom2"))
  expect_equal(fx$truth$n_traits, 8L)
  expect_equal(fx$truth$d_B, 2L)
  expect_equal(nrow(fx$data), 60L * 8L)
  expect_identical(levels(fx$data$family),
                   c("gaussian", "binomial", "poisson", "Gamma", "nbinom2"))
  ## 8 traits split as (gaussian x 2, binomial x 2, poisson x 2, Gamma x 1, nbinom2 x 1)
  expect_equal(nlevels(fx$data$trait), 8L)
})

# ---- cache vs in-process builder are bit-identical ------------------

test_that("cached fixture matches the in-process builder on load-bearing columns (M1.2)", {
  skip_on_cran()
  ## We check the columns the M1 extractor tests actually consume:
  ## site, trait, family, value. The `site_species` factor's level
  ## ORDER is locale-dependent (testthat sets C-locale via withr,
  ## while the cached RDS was built in the maintainer's system
  ## locale), so we deliberately don't compare it as a factor.
  ## Its underlying STRING values are still asserted to match.
  for (k in c(3L, 5L)) {
    cached <- gllvmTMB:::load_mixed_family_fixture(n_families = k)
    fresh  <- gllvmTMB:::.build_mixed_family_fixture(n_families = k)
    for (col in c("site", "trait", "family", "value", "env_1", "env_2")) {
      expect_equal(cached$data[[col]], fresh$data[[col]],
                   info = sprintf("%d-family: column %s drift between cache and builder",
                                  k, col))
    }
    expect_equal(as.character(cached$data$site_species),
                 as.character(fresh$data$site_species),
                 info = sprintf("%d-family: site_species string drift", k))
    expect_equal(cached$truth, fresh$truth,
                 info = sprintf("%d-family truth drift between cache and builder", k))
  }
})

# ---- fit converges on both fixtures ---------------------------------

test_that("fit_mixed_family_fixture(3) converges (M1.2)", {
  skip_on_cran()
  fit <- gllvmTMB:::fit_mixed_family_fixture(n_families = 3L)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(as.numeric(stats::logLik(fit))))
})

test_that("fit_mixed_family_fixture(5) converges (M1.2)", {
  skip_on_cran()
  fit <- gllvmTMB:::fit_mixed_family_fixture(n_families = 5L)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(as.numeric(stats::logLik(fit))))
})

# ---- value distribution sanity (rule 3 — feature combination) -------

test_that("each fixture family has a non-degenerate value distribution (M1.2)", {
  skip_on_cran()
  for (k in c(3L, 5L)) {
    fx <- gllvmTMB:::load_mixed_family_fixture(n_families = k)
    spread <- tapply(fx$data$value, fx$data$family,
                     function(v) sd(as.numeric(v)))
    expect_true(all(spread > 0.1),
                info = sprintf(
                  "%d-family: every family must have sd(value) > 0.1; got %s",
                  k, paste(round(spread, 3), collapse = " / ")))
    ## Each *trait* (not family) has exactly 60 observations
    ## (one row per (site, trait) pair). Families with multiple
    ## traits (5-family has gaussian/binomial/poisson x 2 each)
    ## therefore have 60 or 120 observations depending on count.
    trait_counts <- tapply(fx$data$value, fx$data$trait, length)
    expect_true(all(trait_counts == 60L),
                info = sprintf("%d-family: each trait should have 60 obs", k))
  }
})
