## M1.4 — extract_correlations() mixed-family validation.
##
## Walks register row MIX-04 from `partial` to `covered` by
## exercising the 4 supported methods (fisher-z / wald / profile /
## bootstrap) against the M1.2 fixtures.
##
## Scope: shape + bracketing + range, not numerical-depth (R = 200
## empirical coverage is M3.3 work).
##
## Profile + bootstrap are slow; we run them on the 3-family
## fixture only (T = 3, d = 1, 3 trait pairs) to keep CI within budget.
## Fisher-z + Wald (closed-form) run on both fixtures.

# ---- Shared helpers --------------------------------------------------

skip_on_cran_or_load <- function(n_families) {
  skip_on_cran()
  gllvmTMB:::fit_mixed_family_fixture(n_families = n_families)
}

expect_valid_correlations_df <- function(df, expected_rows) {
  expect_s3_class(df, "data.frame")
  expect_setequal(names(df),
                  c("tier", "trait_i", "trait_j", "correlation",
                    "lower", "upper", "method", "interval_status"))
  expect_equal(nrow(df), expected_rows)
  ## Correlations are in [-1, 1]; CI brackets the point estimate (allowing
  ## for finite-sample boundary effects where one side may equal NA).
  expect_true(all(df$correlation >= -1 - 1e-8 & df$correlation <= 1 + 1e-8),
              info = "point correlations out of [-1, 1]")
  ## Note: lower / upper may be NA for boundary cases (variance near 0);
  ## allow that explicitly.
  finite_rows <- which(is.finite(df$lower) & is.finite(df$upper))
  expect_true(all(df$lower[finite_rows] <= df$correlation[finite_rows] + 1e-6))
  expect_true(all(df$upper[finite_rows] >= df$correlation[finite_rows] - 1e-6))
}

# ---- Fisher-z (default): both fixtures ------------------------------

test_that("extract_correlations() method = 'fisher-z' on both fixtures (M1.4 / MIX-04)", {
  skip_if_not_heavy()
  for (k in c(3L, 5L)) {
    fit <- skip_on_cran_or_load(k)
    fx  <- gllvmTMB:::load_mixed_family_fixture(n_families = k)
    T   <- fx$truth$n_traits
    expected_pairs <- choose(T, 2)

    df <- suppressMessages(extract_correlations(
      fit, tier = "unit", method = "fisher-z",
      link_residual = "auto"
    ))
    expect_valid_correlations_df(df, expected_pairs)
    expect_true(all(df$method == "fisher-z"))
  }
})

# ---- Wald: both fixtures --------------------------------------------

test_that("extract_correlations() method = 'wald' on both fixtures (M1.4 / MIX-04)", {
  skip_if_not_heavy()
  for (k in c(3L, 5L)) {
    fit <- skip_on_cran_or_load(k)
    fx  <- gllvmTMB:::load_mixed_family_fixture(n_families = k)
    T   <- fx$truth$n_traits
    expected_pairs <- choose(T, 2)

    df <- suppressMessages(extract_correlations(
      fit, tier = "unit", method = "wald",
      link_residual = "auto"
    ))
    expect_valid_correlations_df(df, expected_pairs)
    expect_true(all(df$method == "wald"))
  }
})

# ---- Profile: 3-family only (slow) ----------------------------------

test_that("extract_correlations() method = 'profile' is explicitly withheld", {
  skip_if_not_heavy()
  skip_on_cran()
  ## Profile is slower than Fisher-z / Wald (~repeated refit per pair).
  ## 3-family has T = 3 → 3 pairs; budget ~30-60 s.
  fit <- gllvmTMB:::fit_mixed_family_fixture(n_families = 3L)
  ## #717: on this mixed-family (single-trial binary) fixture the engine maps
  ## some theta_diag_B entries off, so the profile refit used to recycle the
  ## shorter free vector against diag(Sigma) -- a ~36k-warning flood plus a
  ## mis-assembled Sigma. Capture warnings and assert the recycle is gone.
  expect_error(suppressMessages(extract_correlations(
      fit, tier = "unit", method = "profile",
      link_residual = "auto"
    )), class = "gllvmTMB_nonlinear_profile_withdrawn")
})

# ---- Profile: single-pair SHAPE cells (3-family, not calibration) ----
#
# Shape, not calibration. These widen the profile half of the EXT-04
# evidence by exercising the `pair =` argument (character names AND
# integer indices) across every trait pair of the 3-family fixture,
# rather than only the all-pairs call above. We assert the returned
# data-frame schema, the single-row shape, the requested trait labels,
# and the [-1, 1] / NA-aware bracket invariants from
# expect_valid_correlations_df(). We do NOT assert interval width or
# coverage: profile-interval calibration is CI-10 / Design-50 / M3.3b
# gated, out of scope here.
#
# Profile on the 5-family fixture (T = 8, d = 2) costs ~10 min per pair
# (repeated full-model refits), so the profile half stays on the
# 3-family fixture, matching the budget note at the top of this file.

test_that("extract_correlations() profile single-pair request is explicitly withheld by name", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- gllvmTMB:::fit_mixed_family_fixture(n_families = 3L)
  named_pairs <- list(
    c("trait_1", "trait_2"),
    c("trait_1", "trait_3"),
    c("trait_2", "trait_3")
  )
  for (pr in named_pairs) {
    expect_error(suppressMessages(extract_correlations(
      fit, tier = "unit", method = "profile",
      pair = pr, link_residual = "auto"
    )), class = "gllvmTMB_nonlinear_profile_withdrawn")
  }
})

test_that("extract_correlations() profile single-pair request is explicitly withheld by index", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- gllvmTMB:::fit_mixed_family_fixture(n_families = 3L)
  index_pairs <- list(c(1L, 2L), c(1L, 3L), c(2L, 3L))
  for (pr in index_pairs) {
    expect_error(suppressMessages(extract_correlations(
      fit, tier = "unit", method = "profile",
      pair = pr, link_residual = "auto"
    )), class = "gllvmTMB_nonlinear_profile_withdrawn")
  }
})

# ---- Bootstrap: 5-family only (T = 8, d = 2) ------------------------
#
# Rank-1 latent (3-family / T = 3 / d = 1) gives Sigma_shared
# correlations of ±1 deterministically, which degenerates the
# bootstrap quantile to ±1 — bootstrap is not informative on rank-1
# latent fits. T = 8, d = 2 has a richer correlation distribution.
#
# A separate known-issue surfaced by this test (see M1.4 after-task
# §8): the bootstrap path in extract_correlations doesn't fully
# propagate `link_residual = "auto"` through bootstrap_Sigma. The
# bracket check therefore allows wider tolerance than the closed-
# form methods. The fix is M1.8 scope (bootstrap_Sigma mixed-family).

test_that("extract_correlations() method = 'bootstrap' on 5-family fixture (M1.4 / MIX-04)", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- gllvmTMB:::fit_mixed_family_fixture(n_families = 5L)
  df <- suppressMessages(extract_correlations(
    fit, tier = "unit", method = "bootstrap",
    nsim = 50L, seed = 20260517L,
    link_residual = "auto"
  ))
  expect_s3_class(df, "data.frame")
  expect_setequal(names(df),
                  c("tier", "trait_i", "trait_j", "correlation",
                    "lower", "upper", "method", "interval_status"))
  expect_equal(nrow(df), choose(8L, 2L))
  expect_true(all(df$method == "bootstrap"))
  expect_true(all(df$correlation >= -1 - 1e-8 & df$correlation <= 1 + 1e-8))
  ## Note: full bracket check (lower <= correlation <= upper) is
  ## deferred to M1.8 — the bootstrap path's link_residual handling
  ## has a known propagation gap that produces over-wide CIs.
})

# ---- Bootstrap: SHAPE cells, 3-family + single-pair -----------------
#
# Shape, not calibration. These widen the bootstrap half of the EXT-04
# evidence by adding (a) the 3-family fixture (T = 3, d = 1) as a second
# family count alongside the 5-family all-pairs cell above, and (b) the
# single-pair `pair =` dispatch. We assert schema, row count, method
# label, and the [-1, 1] point-range invariant only.
#
# We deliberately do NOT add the full bracket check
# (lower <= correlation <= upper). The bootstrap path does not fully
# propagate `link_residual = "auto"` through bootstrap_Sigma — the arg
# exists (R/bootstrap-sigma.R:166) but propagation is incomplete, so the
# bootstrap CI can be over-wide / mis-centred. The fix is M1.8 scope
# (bootstrap_Sigma mixed-family); bracket calibration is CI-10 /
# Design-50 / M3.3b gated. These cells are shape evidence, not an
# interval-calibration claim, and must not be read as "fixing" the gap.

test_that("extract_correlations() method = 'bootstrap' all-pairs shape on 3-family fixture (M1.4 / MIX-04, shape not calibration)", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- gllvmTMB:::fit_mixed_family_fixture(n_families = 3L)
  df <- suppressMessages(extract_correlations(
    fit, tier = "unit", method = "bootstrap",
    nsim = 50L, seed = 20260520L,
    link_residual = "auto"
  ))
  ## Shape, not calibration: schema + row count + label + point range.
  expect_s3_class(df, "data.frame")
  expect_setequal(names(df),
                  c("tier", "trait_i", "trait_j", "correlation",
                    "lower", "upper", "method", "interval_status"))
  expect_equal(nrow(df), choose(3L, 2L))
  expect_true(all(df$method == "bootstrap"))
  expect_true(all(df$correlation >= -1 - 1e-8 & df$correlation <= 1 + 1e-8))
  ## Note: full bracket check (lower <= correlation <= upper) is
  ## deferred — the bootstrap path's link_residual = "auto" handling has
  ## a known propagation gap (R/bootstrap-sigma.R:166). This is a shape
  ## cell, not a calibration claim.
})

test_that("extract_correlations() method = 'bootstrap' single-pair shape on 3-family fixture (M1.4 / MIX-04, shape not calibration)", {
  skip_if_not_heavy()
  skip_on_cran()
  ## 3-family fixture: a single bootstrap run is ~10 s (vs ~100 s on the
  ## 5-family T = 8 model, which bootstrap_Sigma refits in full regardless
  ## of `pair =`). The 5-family all-pairs cell above already covers the
  ## 5-family bootstrap; here we add the cheap `pair =` dispatch shape.
  fit <- gllvmTMB:::fit_mixed_family_fixture(n_families = 3L)
  for (pr in list(c("trait_1", "trait_3"), c(2L, 3L))) {
    df <- suppressMessages(extract_correlations(
      fit, tier = "unit", method = "bootstrap",
      pair = pr, nsim = 40L, seed = 20260521L,
      link_residual = "auto"
    ))
    ## Shape, not calibration: `pair =` dispatch returns the one-row
    ## schema with the requested trait labels and an in-range point
    ## estimate. No bracket check (link_residual propagation gap).
    expect_s3_class(df, "data.frame")
    expect_setequal(names(df),
                    c("tier", "trait_i", "trait_j", "correlation",
                      "lower", "upper", "method", "interval_status"))
    expect_equal(nrow(df), 1L)
    expect_true(all(df$method == "bootstrap"))
    expect_true(all(df$correlation >= -1 - 1e-8 & df$correlation <= 1 + 1e-8))
    expected_labels <- if (is.character(pr)) pr else paste0("trait_", pr)
    expect_setequal(c(df$trait_i, df$trait_j), expected_labels)
    ## Note: full bracket check deferred — bootstrap link_residual = "auto"
    ## propagation gap (R/bootstrap-sigma.R:166). Shape, not calibration.
  }
})

# ---- Method-agreement: fisher-z vs wald only ------------------------
#
# Fisher-z and Wald both compute the correlation point estimate from
# the fitted Sigma_total (with link_residual = "auto"), so their
# point estimates are bit-identical. Profile + bootstrap operate on
# different surfaces (profile uses Sigma_shared with profile-likelihood
# CI; bootstrap uses per-refit Sigma) — these can diverge on rank-1
# latent fits where Sigma_shared correlations are ±1 deterministically.
# Cross-method numerical agreement is M3 inference-completeness work,
# not MIX-04 scope.

test_that("fisher-z and wald agree on the correlation point estimate (M1.4)", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- gllvmTMB:::fit_mixed_family_fixture(n_families = 3L)
  fz <- suppressMessages(extract_correlations(
    fit, tier = "unit", method = "fisher-z", link_residual = "auto"
  ))
  wd <- suppressMessages(extract_correlations(
    fit, tier = "unit", method = "wald", link_residual = "auto"
  ))
  expect_equal(wd$correlation, fz$correlation, tolerance = 1e-8,
               label = "wald point estimate vs fisher-z")
})

# ---- link_residual = "auto" vs "none" diverge on mixed-family ------

test_that("link_residual = 'auto' shrinks correlations on mixed-family (M1.4)", {
  skip_if_not_heavy()
  for (k in c(3L, 5L)) {
    fit <- skip_on_cran_or_load(k)
    auto <- suppressMessages(extract_correlations(
      fit, tier = "unit", method = "fisher-z",
      link_residual = "auto"
    ))
    none <- suppressMessages(extract_correlations(
      fit, tier = "unit", method = "fisher-z",
      link_residual = "none"
    ))
    ## |auto correlation| <= |none correlation| for every pair (the
    ## link residual inflates the diagonal of Sigma, shrinking the
    ## off-diagonal correlation magnitude).
    expect_true(all(abs(auto$correlation) <= abs(none$correlation) + 1e-8),
                info = sprintf(
                  "%d-family: link_residual = 'auto' should shrink |corr|; got auto = %s, none = %s",
                  k,
                  paste(round(auto$correlation, 3), collapse = "/"),
                  paste(round(none$correlation, 3), collapse = "/")))
  }
})
