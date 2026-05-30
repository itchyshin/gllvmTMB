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

## ---- 7-9. phylo_latent() augmented-LHS guard (Design 56 §7 / §9.5a) ------
##
## Companion to the bare-keyword guard above. On `main`, the combined
## rename branch in `R/brms-sugar.R` (`fn %in% c("latent", "phylo_latent",
## "spatial_unique", "spatial")`) renamed `phylo_latent(...)` straight to
## `phylo_rr(...)` WITHOUT inspecting the bar LHS. The `phylo_rr` engine
## reads only the RHS species factor, so the slope covariate in
## `phylo_latent(1 + x | sp, d = K)` (and the long form
## `phylo_latent(0 + trait + (0 + trait):x | sp, d = K)`) was SILENTLY
## DROPPED: the fit was byte-identical to intercept-only
## `phylo_latent(species, d = K)` (same logLik, same param count, identical
## Sigma_phy). A fail-loud-invariant violation (Design 56 §7).
##
## The reduced-rank phylo_latent random-slope engine is Design 56 §9.5a
## (not yet landed). Until it lands the parser must ABORT, not silently
## fit. Tests 7-8 are RED before the guard, GREEN after. Test 9 is the
## no-regression control (intercept-only must still parse + fit).

skip_if_not_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
}

## Tiny phylo fixture: small `ape::rcoal` tree, Gaussian, 2 traits.
## The augmented-LHS abort fires at PARSE time (before the optimiser), so
## the fit never reaches TMB -- the tree only needs to be well-formed.
make_phylo_lhs_fixture <- function(seed = 99L, n_sp = 6L, n_traits = 2L,
                                   n_rep = 4L) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  trait_levels <- paste0("t", seq_len(n_traits))
  df <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep     = seq_len(n_rep),
    trait   = factor(trait_levels, levels = trait_levels)
  )
  df$x <- stats::rnorm(nrow(df))
  df$value <- stats::rnorm(nrow(df))
  list(df = df, tree = tree)
}

test_that("phylo_latent(1 + x | sp, d = 1) Gaussian routes to the latent-slope engine (Design 56 Sec. 9.5a)", {
  skip_if_not_ape()
  fx <- make_phylo_lhs_fixture()
  ## The Design 56 Sec. 9.5a augmented phylo_latent engine is now live for the
  ## Gaussian anchor: the call must PARSE + FIT and drive the dedicated
  ## block-diagonal reduced-rank latent-slope block, NOT the intercept-only
  ## phylo_rr block and NOT the b_phy_aug (dep/unique) block.
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_latent(1 + x | species, d = 1),
    data = fx$df, phylo_tree = fx$tree, unit = "species"
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$phylo_latent_slope))
  expect_false(isTRUE(fit$use$phylo_rr))
  expect_equal(as.integer(fit$tmb_data$n_lhs_cols_lat), 2L)
  ## Per-column Sigma matrices are reported (intercept + slope blocks).
  expect_false(is.null(fit$report$Sigma_phy_slope_intercept))
  expect_false(is.null(fit$report$Sigma_phy_slope_slope))
})

test_that("phylo_latent(0 + trait + (0 + trait):x | sp, d = 1) long form routes to the latent-slope engine", {
  skip_if_not_ape()
  fx <- make_phylo_lhs_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            phylo_latent(0 + trait + (0 + trait):x | species, d = 1),
    data = fx$df, phylo_tree = fx$tree, unit = "species"
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$phylo_latent_slope))
  expect_equal(as.integer(fit$tmb_data$n_lhs_cols_lat), 2L)
})

test_that("phylo_latent(1 + x | sp, d = 1) non-Gaussian fails loud (Gaussian anchor only)", {
  skip_if_not_ape()
  fx <- make_phylo_lhs_fixture()
  fx$df$value <- rpois(nrow(fx$df), lambda = 2)
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_latent(1 + x | species, d = 1),
      data = fx$df, phylo_tree = fx$tree, unit = "species",
      family = poisson()
    ))),
    regexp = "gaussian|Gaussian anchor|deferred"
  )
})

test_that("phylo_latent(species, d = 1) (intercept-only) still parses + fits", {
  skip_if_not_ape()
  fx <- make_phylo_lhs_fixture()
  ## No-regression: the intercept-only reduced-rank phylo factor must NOT
  ## be caught by the augmented-LHS guard.
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1),
    data = fx$df, phylo_tree = fx$tree, unit = "species"
  )))
  expect_equal(fit$opt$convergence, 0L)
})
