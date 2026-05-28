## Stage 3c of the profile-CI unified framework (2026-05-28):
## drmTMB-parity profile curves for derived quantities. Tests the new
## profile_X() functions that return LR-curve data.frames mirroring
## loading_profile()'s shape, plus the shared plot.profile_derived()
## S3 method.
##
## The Lagrange-refit machinery (.fix_and_refit_nll() in
## R/profile-derived.R) is slow: ~0.5-2 s per grid point on the
## fixture below. To keep test wall time under 5 minutes we:
##   1. Cache the fit and the small profile curves across tests
##   2. Use small n_grid (default 9-13) per call
##   3. Restrict to a single trait / pair where possible
##   4. Skip on CRAN

.curve_fit_cache <- new.env(parent = emptyenv())

build_curve_fixture <- function(seed = 42L) {
  if (!is.null(.curve_fit_cache$fit)) {
    return(list(fit = .curve_fit_cache$fit, T = .curve_fit_cache$T))
  }
  set.seed(seed)
  ## Same fixture as test-profile-proportions.R (n_sites = 40 keeps the
  ## per-grid-point refit fast).
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
  .curve_fit_cache$fit <- fit
  .curve_fit_cache$T <- 3L
  list(fit = fit, T = 3L)
}

## ---- Cached curve objects (each generated once per session) ---------------

get_rep_curve <- function() {
  if (!is.null(.curve_fit_cache$rep)) {
    return(.curve_fit_cache$rep)
  }
  fx <- build_curve_fixture()
  out <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_repeatability(
      fx$fit,
      trait_idx = 1L,
      n_grid = 9L,
      grid_extent = 4
    )
  ))
  .curve_fit_cache$rep <- out
  out
}

get_com_curve <- function() {
  if (!is.null(.curve_fit_cache$com)) {
    return(.curve_fit_cache$com)
  }
  fx <- build_curve_fixture()
  out <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_communality(
      fx$fit,
      tier = "unit",
      trait_idx = 1L,
      n_grid = 9L,
      grid_extent = 4
    )
  ))
  .curve_fit_cache$com <- out
  out
}

get_rho_curve <- function() {
  if (!is.null(.curve_fit_cache$rho)) {
    return(.curve_fit_cache$rho)
  }
  fx <- build_curve_fixture()
  out <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_correlation(
      fx$fit,
      tier = "unit",
      i = 1L,
      j = 2L,
      n_grid = 9L,
      grid_extent = 4
    )
  ))
  .curve_fit_cache$rho <- out
  out
}

get_prop_curve <- function() {
  if (!is.null(.curve_fit_cache$prop)) {
    return(.curve_fit_cache$prop)
  }
  fx <- build_curve_fixture()
  out <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_proportions(
      fx$fit,
      components = "shared_unit",
      trait_idx = 1L,
      n_grid = 9L,
      grid_extent = 4
    )
  ))
  .curve_fit_cache$prop <- out
  out
}

## ============================================================================
##  Shape / class / column tests (one cached curve per family)
## ============================================================================

test_that("profile_repeatability(): shape, class, columns, n_grid rows", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  out <- get_rep_curve()
  expect_s3_class(out, "profile_repeatability")
  expect_s3_class(out, "profile_derived")
  expect_s3_class(out, "data.frame")
  expect_named(
    out,
    c("target", "profile_value", "objective", "delta_deviance",
      "estimate", "conf_level")
  )
  ## 1 trait x 9 grid points
  expect_equal(nrow(out), 9L)
  expect_equal(length(unique(out$target)), 1L)
  expect_match(unique(out$target), "^repeatability:")
})

test_that("profile_communality(): shape, class, columns, n_grid rows", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  out <- get_com_curve()
  expect_s3_class(out, "profile_communality")
  expect_s3_class(out, "profile_derived")
  expect_equal(nrow(out), 9L)
  expect_match(unique(out$target), "^communality:unit:")
})

test_that("profile_correlation(): shape, class, columns, n_grid rows", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  out <- get_rho_curve()
  expect_s3_class(out, "profile_correlation")
  expect_s3_class(out, "profile_derived")
  expect_equal(nrow(out), 9L)
  expect_match(unique(out$target), "^rho:unit:1,2$")
})

test_that("profile_proportions(): shape, class, columns, n_grid rows", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  out <- get_prop_curve()
  expect_s3_class(out, "profile_proportions")
  expect_s3_class(out, "profile_derived")
  expect_equal(nrow(out), 9L)
  expect_match(unique(out$target), "^proportion:shared_unit:")
})

## ============================================================================
##  Grid values: monotone, finite, in the natural range
## ============================================================================

test_that("profile_repeatability(): grid lies in (0, 1) and is sorted", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  out <- get_rep_curve()
  expect_true(all(out$profile_value > 0 & out$profile_value < 1))
  expect_equal(out$profile_value, sort(out$profile_value))
})

test_that("profile_communality(): grid lies in (0, 1) and is sorted", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  out <- get_com_curve()
  expect_true(all(out$profile_value > 0 & out$profile_value < 1))
  expect_equal(out$profile_value, sort(out$profile_value))
})

test_that("profile_correlation(): grid lies in (-1, 1) and is sorted", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  out <- get_rho_curve()
  expect_true(all(out$profile_value > -1 & out$profile_value < 1))
  expect_equal(out$profile_value, sort(out$profile_value))
})

test_that("profile_proportions(): grid lies in (0, 1) and is sorted", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  out <- get_prop_curve()
  expect_true(all(out$profile_value > 0 & out$profile_value < 1))
  expect_equal(out$profile_value, sort(out$profile_value))
})

## ============================================================================
##  delta_deviance is non-negative at finite rows; estimate matches a
##  call to the corresponding extract_*() / profile_ci_*().
## ============================================================================

test_that("profile_repeatability(): delta_deviance >= 0 and estimate matches extract_repeatability()", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  out <- get_rep_curve()
  finite <- is.finite(out$delta_deviance)
  expect_true(all(out$delta_deviance[finite] >= -1e-6))
  ## extract_repeatability is FULL-Sigma R; our curve is the diag-only R
  ## (same as profile_ci_repeatability). We compare against the
  ## inversion endpoint's estimate.
  rep_ci <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_ci_repeatability(fx$fit, trait_idx = 1L)
  ))
  expect_equal(unique(out$estimate), rep_ci$R, tolerance = 1e-6)
})

test_that("profile_communality(): delta_deviance >= 0 and estimate matches extract_communality()", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  out <- get_com_curve()
  finite <- is.finite(out$delta_deviance)
  expect_true(all(out$delta_deviance[finite] >= -1e-6))
  c2_pt <- suppressMessages(extract_communality(fx$fit, level = "unit"))
  expect_equal(unique(out$estimate), as.numeric(c2_pt[1L]), tolerance = 1e-6)
})

test_that("profile_correlation(): delta_deviance >= 0 and estimate matches extract_Sigma() rho", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  out <- get_rho_curve()
  finite <- is.finite(out$delta_deviance)
  expect_true(all(out$delta_deviance[finite] >= -1e-6))
  S <- suppressMessages(extract_Sigma(
    fx$fit, level = "unit", part = "total", link_residual = "none"
  ))
  expect_equal(unique(out$estimate), S$R[1L, 2L], tolerance = 1e-6)
})

test_that("profile_proportions(): delta_deviance >= 0 and estimate matches extract_proportions()", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  out <- get_prop_curve()
  finite <- is.finite(out$delta_deviance)
  expect_true(all(out$delta_deviance[finite] >= -1e-6))
  pr <- suppressMessages(extract_proportions(fx$fit, format = "long"))
  ref <- pr$proportion[pr$component == "shared_unit" &
                         pr$trait == levels(pr$trait)[1L]]
  expect_equal(unique(out$estimate), as.numeric(ref), tolerance = 1e-6)
})

## ============================================================================
##  Bound-agreement: bounds derived from the curve grid agree with the
##  existing profile_ci_X() bracket-bisect inversion to within 1e-2 on
##  the (proportion / correlation) scale.
## ============================================================================

## Helper: invert a profile_derived data.frame to (lower, upper) using
## the same .invert_profile_derived() that the plot method uses
## (re-uses the internal helper exposed via gllvmTMB:::).
invert_curve <- function(x) {
  gllvmTMB:::.invert_profile_derived(x)
}

test_that("profile_repeatability(): grid-inverted bounds agree with profile_ci_repeatability() to 1e-2", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  out <- get_rep_curve()
  inv <- invert_curve(out)
  ref <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_ci_repeatability(fx$fit, trait_idx = 1L)
  ))
  ## Compare lower/upper. NA-tolerance: if either side reports
  ## infinity (one-sided boundary), skip that side -- the curve
  ## inversion may report a slightly inside-the-boundary number where
  ## the bracket-bisect endpoint reports Inf.
  if (is.finite(inv$lower) && is.finite(ref$lower)) {
    expect_lt(abs(inv$lower - ref$lower), 1e-2)
  }
  if (is.finite(inv$upper) && is.finite(ref$upper)) {
    expect_lt(abs(inv$upper - ref$upper), 1e-2)
  }
})

test_that("profile_communality(): grid-inverted bounds agree with profile_ci_communality() to 1e-2", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  out <- get_com_curve()
  inv <- invert_curve(out)
  ref <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_ci_communality(fx$fit, tier = "unit", trait_idx = 1L)
  ))
  if (is.finite(inv$lower) && is.finite(ref$lower)) {
    expect_lt(abs(inv$lower - ref$lower), 1e-2)
  }
  if (is.finite(inv$upper) && is.finite(ref$upper)) {
    expect_lt(abs(inv$upper - ref$upper), 1e-2)
  }
})

test_that("profile_correlation(): grid-inverted bounds agree with profile_ci_correlation() to 1e-2", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  out <- get_rho_curve()
  inv <- invert_curve(out)
  ref <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_ci_correlation(fx$fit, tier = "unit", i = 1L, j = 2L)
  ))
  ref_lower <- unname(ref["lower"])
  ref_upper <- unname(ref["upper"])
  if (is.finite(inv$lower) && is.finite(ref_lower)) {
    expect_lt(abs(inv$lower - ref_lower), 1e-2)
  }
  if (is.finite(inv$upper) && is.finite(ref_upper)) {
    expect_lt(abs(inv$upper - ref_upper), 1e-2)
  }
})

test_that("profile_proportions(): grid-inverted bounds agree with profile_ci_proportions() to 1e-2", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  out <- get_prop_curve()
  inv <- invert_curve(out)
  ref <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_ci_proportions(
      fx$fit, components = "shared_unit", trait_idx = 1L
    )
  ))
  if (is.finite(inv$lower) && is.finite(ref$lower)) {
    expect_lt(abs(inv$lower - ref$lower), 1e-2)
  }
  if (is.finite(inv$upper) && is.finite(ref$upper)) {
    expect_lt(abs(inv$upper - ref$upper), 1e-2)
  }
})

## ============================================================================
##  plot() returns a ggplot for each class, both with interval = TRUE and FALSE
## ============================================================================

test_that("plot(profile_repeatability) returns a gg object", {
  skip_if_not_installed("TMB")
  skip_if_not_installed("ggplot2")
  skip_on_cran()
  out <- get_rep_curve()
  g <- plot(out)
  expect_s3_class(g, "gg")
  g2 <- plot(out, interval = FALSE)
  expect_s3_class(g2, "gg")
})

test_that("plot(profile_communality) returns a gg object", {
  skip_if_not_installed("TMB")
  skip_if_not_installed("ggplot2")
  skip_on_cran()
  out <- get_com_curve()
  g <- plot(out)
  expect_s3_class(g, "gg")
  g2 <- plot(out, interval = FALSE)
  expect_s3_class(g2, "gg")
})

test_that("plot(profile_correlation) returns a gg object", {
  skip_if_not_installed("TMB")
  skip_if_not_installed("ggplot2")
  skip_on_cran()
  out <- get_rho_curve()
  g <- plot(out)
  expect_s3_class(g, "gg")
  g2 <- plot(out, interval = FALSE)
  expect_s3_class(g2, "gg")
})

test_that("plot(profile_proportions) returns a gg object", {
  skip_if_not_installed("TMB")
  skip_if_not_installed("ggplot2")
  skip_on_cran()
  out <- get_prop_curve()
  g <- plot(out)
  expect_s3_class(g, "gg")
  g2 <- plot(out, interval = FALSE)
  expect_s3_class(g2, "gg")
})

## ============================================================================
##  Error paths (no refit -- fail early)
## ============================================================================

test_that("profile_repeatability(): errors when fit has no theta_diag_W", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  set.seed(42L)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 30L, n_species = 4L, n_traits = 2L,
    mean_species_per_site = 3L,
    Lambda_B = matrix(c(0.7, 0.4), 2L, 1L),
    psi_B = c(0.3, 0.3),
    psi_W = c(0.3, 0.3),
    beta = matrix(0, 2L, 2L),
    seed = 42L
  )
  fit_no_w <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + unique(0 + trait | site),
      data = s$data, silent = TRUE
    )
  ))
  expect_error(
    suppressMessages(suppressWarnings(
      gllvmTMB::profile_repeatability(fit_no_w)
    )),
    "theta_diag_B|theta_diag_W"
  )
})

test_that("profile_phylo_signal(): errors when fit has no phylo component", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  expect_error(
    suppressMessages(suppressWarnings(
      gllvmTMB::profile_phylo_signal(fx$fit)
    )),
    "phylo|phylogenetic"
  )
})

test_that("profile_correlation(): errors when i == j", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  expect_error(
    suppressMessages(suppressWarnings(
      gllvmTMB::profile_correlation(
        fx$fit, tier = "unit", i = 1L, j = 1L
      )
    )),
    "distinct"
  )
})

test_that("profile_correlation(): canonicalises i > j to i < j", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  ## Pass (2, 1); the output should label rho:unit:1,2 (canonical).
  ## We use a tiny n_grid = 3 to keep this cheap; only the labelling is
  ## under test.
  out <- suppressMessages(suppressWarnings(
    gllvmTMB::profile_correlation(
      fx$fit, tier = "unit", i = 2L, j = 1L,
      n_grid = 3L, grid_extent = 4
    )
  ))
  expect_equal(unique(out$target), "rho:unit:1,2")
})

test_that("profile_proportions(): link_residual in components errors", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  expect_error(
    suppressMessages(suppressWarnings(
      gllvmTMB::profile_proportions(
        fx$fit, components = "link_residual", trait_idx = 1L
      )
    )),
    "link_residual|structurally"
  )
})

test_that("profile_proportions(): unknown component errors", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_curve_fixture()
  expect_error(
    suppressMessages(suppressWarnings(
      gllvmTMB::profile_proportions(
        fx$fit, components = "shared_phy", trait_idx = 1L
      )
    )),
    "not present|Available"
  )
})
