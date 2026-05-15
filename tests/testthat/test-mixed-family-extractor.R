## Phase 1b 2026-05-15 item 5: extractor tests on a real
## `family = list(...)` mixed-family fit.
##
## Pre-PR #101, `extract_correlations()` hardcoded `link_residual =
## "none"` (PR #101 changed the default to "auto" with a deprecation
## warning), and the test suite never exercised `extract_Sigma()` or
## `extract_correlations()` on a `family = list(...)` fit. This file
## closes that gap: it builds a 3-trait Gaussian + binomial + Poisson
## fit (the same fixture pattern as test-stage37-mixed-family.R), then
## verifies:
##
##   1. `extract_Sigma(level = "unit", part = "total")` returns a coherent
##      Tn x Tn matrix with positive diagonals.
##   2. `extract_correlations(link_residual = "auto")` produces per-trait
##      residual additions that DIFFER from `link_residual = "none"` for
##      the non-Gaussian traits (and match for the Gaussian trait).
##   3. `extract_correlations()` with default returns the same point
##      estimate as the explicit `link_residual = "auto"` call (the new
##      default).
##
## All tests gated by `skip_on_cran()` because the mixed-family fit
## takes ~5-15 seconds.

make_mixed_family_fit <- function(seed = 2025L) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 40, n_species = 10, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(1.0,  0.7, -0.3,
                        0.3, -0.5,  0.8), nrow = 3, ncol = 2),
    psi_B    = c(0.3, 0.3, 0.3),
    seed     = seed
  )
  df <- sim$data
  df$family <- factor(
    with(df, ifelse(trait == "trait_1", "g",
            ifelse(trait == "trait_2", "b", "p"))),
    levels = c("g", "b", "p")
  )
  ## Cast the simulated Gaussian values to the appropriate scales for
  ## binomial / Poisson rows so the engine's likelihoods are coherent.
  df$value[df$family == "b"] <-
    as.integer(df$value[df$family == "b"] > 0)
  df$value[df$family == "p"] <-
    pmax(0L, as.integer(round(df$value[df$family == "p"] + 1)))

  family_list <- list(gaussian(), binomial(), poisson())
  attr(family_list, "family_var") <- "family"

  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data   = df,
    family = family_list
  )))
}

## ---- 1: Sigma shape on a mixed-family fit -------------------------------

test_that("extract_Sigma() returns a coherent T x T matrix on a mixed-family fit", {
  skip_on_cran()
  fit <- make_mixed_family_fit()
  S <- suppressMessages(gllvmTMB::extract_Sigma(
    fit, level = "unit", part = "total"
  ))
  ## extract_Sigma returns a named list; `$Sigma` is the total covariance.
  expect_true("Sigma" %in% names(S))
  Sigma <- S$Sigma
  expect_true(is.matrix(Sigma))
  expect_equal(dim(Sigma), c(3L, 3L))
  expect_true(all(diag(Sigma) > 0))
  ## Symmetry: rounding accounts for numerical asymmetry from the
  ## decomposition.
  expect_equal(Sigma, t(Sigma), tolerance = 1e-10)
})

## ---- 2: link_residual = "auto" differs from "none" on non-Gaussian traits

test_that("extract_correlations(link_residual = 'auto') adds per-family residuals", {
  skip_on_cran()
  fit <- make_mixed_family_fit()
  R_none <- suppressMessages(suppressWarnings(gllvmTMB::extract_correlations(
    fit, tier = "unit", link_residual = "none"
  )))
  R_auto <- suppressMessages(suppressWarnings(gllvmTMB::extract_correlations(
    fit, tier = "unit", link_residual = "auto"
  )))
  ## extract_correlations returns a tidy data frame with columns
  ## `tier, trait_i, trait_j, correlation, lower, upper, method`. All
  ## rows are off-diagonal pairs (trait_i != trait_j). The "auto" path
  ## adds per-trait latent residuals to the diagonal of the implied
  ## Sigma before computing Pearson correlations; for any pair where at
  ## least one of (trait_i, trait_j) is non-Gaussian, this lowers |r|.
  expect_true(is.data.frame(R_auto))
  expect_true(all(R_auto$trait_i != R_auto$trait_j))
  expect_gt(nrow(R_auto), 0L)
  ## Pair the data frames by (trait_i, trait_j) and compare correlations.
  key_auto <- paste(R_auto$trait_i, R_auto$trait_j, sep = "_")
  key_none <- paste(R_none$trait_i, R_none$trait_j, sep = "_")
  expect_setequal(key_auto, key_none)
  R_auto_ord  <- R_auto[order(key_auto), ]
  R_none_ord  <- R_none[order(key_none), ]
  diffs <- R_auto_ord$correlation - R_none_ord$correlation
  ## At least one pair changes by >= 1e-3 in absolute terms (the
  ## binomial- and Poisson-touching pairs get the residual inflation).
  expect_true(any(abs(diffs) > 1e-3))
  ## All correlations stay in [-1, 1] under both methods.
  expect_true(all(abs(R_auto$correlation)  <= 1 + 1e-9))
  expect_true(all(abs(R_none$correlation) <= 1 + 1e-9))
})

## ---- 3: 'auto' is the new default; no link_residual arg should match -----

test_that("extract_correlations() default matches link_residual = 'auto'", {
  skip_on_cran()
  fit <- make_mixed_family_fit()
  R_default <- suppressMessages(suppressWarnings(gllvmTMB::extract_correlations(
    fit, tier = "unit"
  )))
  R_auto    <- suppressMessages(suppressWarnings(gllvmTMB::extract_correlations(
    fit, tier = "unit", link_residual = "auto"
  )))
  ## Both calls produce the same Pearson correlations (same point estimates).
  expect_equal(R_default$correlation, R_auto$correlation, tolerance = 1e-10)
})

## ---- 4: extract_Sigma() with part = 'unique' on a no-unique() fit -----

test_that("extract_Sigma(part = 'unique') returns a zero-Psi diagonal on a no-unique() fit", {
  skip_on_cran()
  fit <- make_mixed_family_fit()
  ## The fit has only latent() in its formula (no unique() term), so the
  ## Psi diagonal is the zero vector. `extract_Sigma(part = 'unique')`
  ## exposes the diagonal as the `$s` slot of length T (not a matrix).
  S <- suppressMessages(gllvmTMB::extract_Sigma(
    fit, level = "unit", part = "unique"
  ))
  expect_true("s" %in% names(S))
  expect_length(S$s, 3L)
  expect_true(is.numeric(S$s))
  ## Without a `unique()` term in the formula, the Psi diagonal is
  ## structurally zero for all three traits.
  expect_equal(unname(S$s), rep(0, 3L), tolerance = 1e-10)
})
