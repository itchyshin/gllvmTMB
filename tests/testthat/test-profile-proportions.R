## Stage 3b of the profile-CI unified framework (2026-05-27):
## `profile_ci_proportions()` and routing through
## `confint.gllvmTMB_multi()` via the `parm = "proportion[:...]"`
## token. Mirrors the Stage 3a test layout (test-confint-derived.R)
## but for the per-(trait, component) proportion decomposition.
##
## Profile refits are slow (full constrained Lagrange refit per
## uniroot probe; ~20 s per (trait, component) cell on the fixture
## below). To keep wall time bounded we:
##   1. Cache the fit object across test_that() blocks.
##   2. Cache the full `profile_ci_proportions(fit, trait_idx = 1L)`
##      result and inspect it from multiple cheap assertion tests.
##   3. Only re-call the function for cases that exercise a
##      different code path (filtering, routing, error paths).

.prop_fit_cache <- new.env(parent = emptyenv())

build_prop_fixture <- function(seed = 42L) {
  if (!is.null(.prop_fit_cache$fit)) {
    return(list(fit = .prop_fit_cache$fit, T = .prop_fit_cache$T))
  }
  set.seed(seed)
  ## Smaller-than-Stage-3a fixture (n_sites = 40) keeps each profile
  ## refit to ~20 s on a single component-trait cell. Stage 3a tests
  ## use n_sites = 80 because their underlying CI machinery is mostly
  ## linear (lincomb tmbprofile); the proportion path uses full
  ## constrained refit and scales worse with n.
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 40L,
    n_species = 5L,
    n_traits = 3L,
    mean_species_per_site = 4L,
    Lambda_B = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
    psi_B = c(0.40, 0.30, 0.50),
    psi_W = c(0.30, 0.40, 0.30),
    beta = matrix(0, 3L, 2L),
    seed = seed
  )
  fit <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | site, d = 1) +
        unique(0 + trait | site) +
        unique(0 + trait | site_species),
      data = s$data,
      silent = TRUE
    )
  ))
  .prop_fit_cache$fit <- fit
  .prop_fit_cache$T <- 3L
  list(fit = fit, T = 3L)
}

.unit_obs_prop_fit_cache <- new.env(parent = emptyenv())

build_unit_obs_prop_fixture <- function(seed = 20260705L) {
  if (!is.null(.unit_obs_prop_fit_cache$fit)) {
    return(list(
      fit = .unit_obs_prop_fit_cache$fit,
      T = .unit_obs_prop_fit_cache$T
    ))
  }
  set.seed(seed)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 30L,
    n_species = 5L,
    n_traits = 3L,
    mean_species_per_site = 4L,
    Lambda_B = matrix(0, 3L, 1L),
    Lambda_W = matrix(c(0.8, 0.45, -0.35), 3L, 1L),
    psi_B = c(0.05, 0.05, 0.05),
    psi_W = c(0.25, 0.35, 0.30),
    beta = matrix(0, 3L, 2L),
    seed = seed
  )
  fit <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | site_species, d = 1) +
        unique(0 + trait | site_species),
      data = s$data,
      control = gllvmTMB::gllvmTMBcontrol(se = TRUE, n_init = 1),
      silent = TRUE
    )
  ))
  .unit_obs_prop_fit_cache$fit <- fit
  .unit_obs_prop_fit_cache$T <- 3L
  list(fit = fit, T = 3L)
}

## Cached "full" profile-CI table on trait_1 (3 components present in
## the fixture). The five "inspection" tests below all read this one
## result, so the slow refit runs once per test session.
get_full_prop_tbl <- function() {
  if (!is.null(.prop_fit_cache$tbl)) {
    return(.prop_fit_cache$tbl)
  }
  fx <- build_prop_fixture()
  tbl <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_ci_proportions(fx$fit, trait_idx = 1L)
  ))
  .prop_fit_cache$tbl <- tbl
  tbl
}

## ============================================================================
##  Direct profile_ci_proportions() API (inspect the cached table)
## ============================================================================

test_that("profile_ci_proportions() default has the right shape and column names", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  tbl <- get_full_prop_tbl()
  expect_s3_class(tbl, "data.frame")
  expect_named(
    tbl,
    c("trait", "component", "proportion", "lower", "upper", "method")
  )
  ## One row per component present (the fixture has shared_unit,
  ## unique_unit, unique_unit_obs).
  comps_present <- unique(as.character(tbl$component))
  expect_setequal(
    comps_present,
    c("shared_unit", "unique_unit", "unique_unit_obs")
  )
  expect_equal(nrow(tbl), length(comps_present))
})

test_that("profile_ci_proportions(): proportion column matches extract_proportions()", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  tbl <- get_full_prop_tbl()
  ref <- suppressMessages(
    gllvmTMB::extract_proportions(fx$fit, format = "long")
  )
  key_tbl <- paste(
    as.character(tbl$trait),
    as.character(tbl$component),
    sep = "::"
  )
  key_ref <- paste(
    as.character(ref$trait),
    as.character(ref$component),
    sep = "::"
  )
  idx <- match(key_tbl, key_ref)
  expect_false(anyNA(idx))
  expect_equal(tbl$proportion, ref$proportion[idx], tolerance = 1e-10)
})

test_that("profile_ci_proportions(): bounds monotonic for all profiled rows (lower <= proportion <= upper)", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  tbl <- get_full_prop_tbl()
  ok <- tbl$method == "profile" &
    is.finite(tbl$lower) &
    is.finite(tbl$upper)
  ## At least the shared_unit row (the stable component) should profile
  ## cleanly. We assert monotonicity only where bounds are finite.
  expect_true(any(ok))
  expect_true(all(tbl$lower[ok] <= tbl$proportion[ok] + 1e-6))
  expect_true(all(tbl$proportion[ok] <= tbl$upper[ok] + 1e-6))
})

test_that("profile_ci_proportions(): bounds in [0, 1] for all profiled rows", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  tbl <- get_full_prop_tbl()
  finite <- is.finite(tbl$lower) & is.finite(tbl$upper)
  expect_true(all(tbl$lower[finite] >= -1e-3))
  expect_true(all(tbl$upper[finite] <= 1 + 1e-3))
})

test_that("profile_ci_proportions(): no phylo components in the no-phylo fixture", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  tbl <- get_full_prop_tbl()
  comps <- as.character(tbl$component)
  expect_false(any(c("shared_phy", "unique_phy") %in% comps))
})

## ============================================================================
##  Filter / parser tests (cheap: separate refits, but use the smallest
##  possible slice -- one component, one trait -- each)
## ============================================================================

test_that("profile_ci_proportions(components = 'shared_unit', trait_idx = 1) filters", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  tbl <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_ci_proportions(
      fx$fit,
      components = "shared_unit",
      trait_idx = 1L
    )
  ))
  expect_equal(nrow(tbl), 1L)
  expect_equal(as.character(tbl$component), "shared_unit")
  expect_equal(as.character(tbl$trait), "trait_1")
})

test_that("profile_ci_proportions() profiles shared and unique unit_obs components on a fitted W tier", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_unit_obs_prop_fixture()
  expect_true(isTRUE(fx$fit$use$rr_W))
  expect_true(isTRUE(fx$fit$use$diag_W))
  expect_false(isTRUE(fx$fit$use$rr_B))
  tbl <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_ci_proportions(
      fx$fit,
      components = c("shared_unit_obs", "unique_unit_obs"),
      trait_idx = 1L
    )
  ))
  expect_s3_class(tbl, "data.frame")
  expect_setequal(
    as.character(tbl$component),
    c("shared_unit_obs", "unique_unit_obs")
  )
  expect_equal(as.character(tbl$trait), rep("trait_1", 2L))
  ref <- suppressMessages(gllvmTMB::extract_proportions(
    fx$fit,
    format = "long"
  ))
  key_tbl <- paste(
    as.character(tbl$trait),
    as.character(tbl$component),
    sep = "::"
  )
  key_ref <- paste(
    as.character(ref$trait),
    as.character(ref$component),
    sep = "::"
  )
  idx <- match(key_tbl, key_ref)
  expect_false(anyNA(idx))
  expect_equal(tbl$proportion, ref$proportion[idx], tolerance = 1e-10)
  ok <- tbl$method == "profile" &
    is.finite(tbl$lower) &
    is.finite(tbl$upper)
  expect_true(any(ok))
  expect_true(all(tbl$lower[ok] >= -1e-3))
  expect_true(all(tbl$upper[ok] <= 1 + 1e-3))
  expect_true(all(tbl$lower[ok] <= tbl$proportion[ok] + 1e-6))
  expect_true(all(tbl$proportion[ok] <= tbl$upper[ok] + 1e-6))
})

## ============================================================================
##  Error paths (no refit -- fail at the parser / filter stage)
## ============================================================================

test_that("profile_ci_proportions(): unknown component errors with available list", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  ## The fixture has no phylogenetic component; "shared_phy" is not in
  ## extract_proportions(fit), so this errors at the validate-components
  ## step before any refit runs.
  expect_error(
    suppressMessages(suppressWarnings(
      gllvmTMB::profile_ci_proportions(
        fx$fit,
        components = "shared_phy",
        trait_idx = 1L
      )
    )),
    "not present|Available"
  )
})

test_that("profile_ci_proportions(trait_idx = 99) errors with a range message", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  expect_error(
    suppressMessages(suppressWarnings(
      gllvmTMB::profile_ci_proportions(fx$fit, trait_idx = 99L)
    )),
    "trait_idx|range|1:"
  )
})

## ============================================================================
##  confint() routing (one slow path, all others parse / error early)
## ============================================================================

test_that("confint(fit, parm = 'proportion:shared_unit:trait_1') returns one row with the right shape", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  ## This is the only confint() test that triggers a refit -- one
  ## (component, trait) cell, ~20 s.
  ci <- suppressMessages(suppressWarnings(
    confint(fx$fit, parm = "proportion:shared_unit:trait_1")
  ))
  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), 1L)
  expect_equal(rownames(ci), "proportion:shared_unit:trait_1")
  expect_equal(ncol(ci), 2L)
  expect_equal(colnames(ci), c("2.5 %", "97.5 %"))
})

test_that("confint(fit, parm = 'proportion'): bare token is recognised and routes (parse-only check)", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  ## We do not actually run a full T x C refit here; instead we check
  ## that the bare "proportion" token does NOT fall through to the
  ## fixed-effects path by inspecting the parser result via the
  ## internal helper. The full-grid case is too slow to run in CI.
  parsed <- gllvmTMB:::.parse_proportion_parm(
    "proportion",
    trait_names = levels(fx$fit$data[[fx$fit$trait_col]])
  )
  expect_null(parsed$components)
  expect_null(parsed$trait_idx)
})

test_that(".parse_proportion_parm splits multi-component tokens", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  trait_names <- levels(fx$fit$data[[fx$fit$trait_col]])
  parsed <- gllvmTMB:::.parse_proportion_parm(
    "proportion:shared_unit;unique_unit",
    trait_names = trait_names
  )
  expect_equal(parsed$components, c("shared_unit", "unique_unit"))
  expect_null(parsed$trait_idx)
})

test_that(".parse_proportion_parm splits (component, trait) tokens", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  trait_names <- levels(fx$fit$data[[fx$fit$trait_col]])
  parsed <- gllvmTMB:::.parse_proportion_parm(
    "proportion:shared_unit:trait_1",
    trait_names = trait_names
  )
  expect_equal(parsed$components, "shared_unit")
  expect_equal(parsed$trait_idx, 1L)
})

test_that(".parse_proportion_parm accepts bracketed indices on the trait portion", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  trait_names <- levels(fx$fit$data[[fx$fit$trait_col]])
  parsed <- gllvmTMB:::.parse_proportion_parm(
    "proportion:shared_unit:[1,3]",
    trait_names = trait_names
  )
  expect_equal(parsed$components, "shared_unit")
  expect_equal(parsed$trait_idx, c(1L, 3L))
})

## ============================================================================
##  Method handling: Wald / bootstrap routes
## ============================================================================

test_that("confint(fit, parm = 'proportion:shared_unit', method = 'wald') returns finite bounds", {
  skip_if_not_heavy()
  ## Phase B-INF Lane 1 A2 wired wald (delta method on logit-p).
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  res <- suppressMessages(suppressWarnings(
    confint(fx$fit, parm = "proportion:shared_unit", method = "wald")
  ))
  expect_true(is.matrix(res))
  expect_equal(ncol(res), 2L)
  expect_true(all(is.finite(res)))
  expect_true(all(res >= 0 & res <= 1))
})

test_that("confint(fit, parm = 'proportion:shared_unit', method = 'bootstrap') returns finite bounds", {
  skip_if_not_heavy()
  ## Phase B-INF Lane 1 A2 wired bootstrap (parametric simulate-refit).
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  res <- suppressMessages(suppressWarnings(
    confint(
      fx$fit,
      parm = "proportion:shared_unit",
      method = "bootstrap",
      nsim = 30L,
      seed = 42L
    )
  ))
  expect_true(is.matrix(res))
  expect_equal(ncol(res), 2L)
  expect_true(all(is.finite(res)))
  expect_true(all(res >= 0 & res <= 1))
})

## ============================================================================
##  Bad inputs (parse errors -- no refit)
## ============================================================================

test_that("confint(fit, parm = 'proportion:bogus') errors on unknown component name", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  expect_error(
    suppressMessages(suppressWarnings(
      confint(fx$fit, parm = "proportion:bogus")
    )),
    "unknown|Available|component"
  )
})

test_that("confint(fit, parm = 'proportion:shared_unit:bogus') errors on unknown trait name", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_prop_fixture()
  expect_error(
    suppressMessages(suppressWarnings(
      confint(fx$fit, parm = "proportion:shared_unit:bogus")
    )),
    "bogus|not found"
  )
})
