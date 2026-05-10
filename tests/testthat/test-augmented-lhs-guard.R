## Design 07 Stage 2.5 follow-up: fail-loud parser guard against augmented
## LHS in the BARE covstruct keywords (`latent`, `unique`, `indep`, `dep`).
##
## Today (pre-fix) writing
##
##     latent(0 + trait + (0 + trait):temp | g, d = 1)
##
## silently fits with only T columns -- the augmented `(0 + trait):temp`
## slope columns are dropped by the engine sizing (`n_traits` hardcoded
## at nine sites in `R/fit-multi.R`; see `dev/dev-log/after-task/15-design-
## 07-oq1-engine-audit.md`). Half the user's model is ignored without any
## warning. Sokal-funcbio's `7e90f036` work confirmed empirically: two
## fits with intercept-only and augmented LHS produced byte-identical
## objectives (677.4103) and identical T x d_B Lambda_hat instead of
## 2T x d_B.
##
## The `phylo()` and `spatial()` mode-dispatch wrappers (df76c705 /
## 8b1ddc92) already abort fail-loud on augmented LHS with a Stage 3
## redirect. This test file covers the same guard for the bare keywords.
##
## TDD discipline: tests 1-3 are RED before the fix, GREEN after.
## Tests 4-6 are GREEN before AND after (no-regression).

## Tiny fixture for fast non-phylo, non-spatial fits.
make_lhs_fixture <- function(seed = 42) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 4, n_traits = 3,
    mean_species_per_site = 4, seed = seed
  )
  df <- sim$data
  ## Add a continuous covariate to play the role of the `:temp` slope
  ## column the augmented LHS would multiply against.
  df$temp <- stats::rnorm(nrow(df))
  df
}

## ---- 1. latent() augmented LHS errors with Stage-3 redirect -------------

test_that("latent(0 + trait + (0 + trait):temp | g, d = 1) errors with Stage 3 redirect", {
  skip_on_cran()
  df <- make_lhs_fixture()
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
              latent(0 + trait + (0 + trait):temp | site, d = 1),
      data = df, unit = "site"
    ))),
    regexp = "augmented LHS|Stage 3|n_lhs_cols|reaction.norm"
  )
})

## ---- 2. unique() augmented LHS errors with Stage-3 redirect -------------

test_that("unique(0 + trait + (0 + trait):temp | g) errors with Stage 3 redirect", {
  skip_on_cran()
  df <- make_lhs_fixture()
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
              latent(0 + trait | site, d = 1) +
              unique(0 + trait + (0 + trait):temp | site),
      data = df, unit = "site"
    ))),
    regexp = "augmented LHS|Stage 3|n_lhs_cols|reaction.norm"
  )
})

## ---- 3. indep() augmented LHS errors with Stage-3 redirect --------------

test_that("indep(0 + trait + (0 + trait):temp | g) errors with Stage 3 redirect", {
  skip_on_cran()
  df <- make_lhs_fixture()
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
              indep(0 + trait + (0 + trait):temp | site),
      data = df, unit = "site"
    ))),
    regexp = "augmented LHS|Stage 3|n_lhs_cols|reaction.norm"
  )
})

## ---- 4. latent(0 + trait | g, d = 1) keeps fitting ----------------------

test_that("latent(0 + trait | g, d = 1) does NOT error -- fits as expected", {
  skip_on_cran()
  df <- make_lhs_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = df, unit = "site"
  )))
  expect_equal(fit$opt$convergence, 0L)
})

## ---- 5. unique(0 + trait | g) keeps fitting -----------------------------

test_that("unique(0 + trait | g) does NOT error -- fits as expected", {
  skip_on_cran()
  df <- make_lhs_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 1) +
            unique(0 + trait | site),
    data = df, unit = "site"
  )))
  expect_equal(fit$opt$convergence, 0L)
})

## ---- 6. unique(1 | g) keeps fitting (intercept-only LHS) ----------------

test_that("unique(1 | g) (intercept-only) does NOT error -- engine path handles it", {
  skip_on_cran()
  df <- make_lhs_fixture()
  ## Note: `unique(1 | g)` is the intercept-only random-intercept form;
  ## it routes via `diag(1 | g)` and is the standard scalar random
  ## intercept in glmmTMB. The augmented-LHS guard must NOT fire here.
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 1) +
            unique(1 | site),
    data = df, unit = "site"
  )))
  expect_equal(fit$opt$convergence, 0L)
})
