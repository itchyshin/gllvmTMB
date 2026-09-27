## Lane auto-d-20260926 (maintainer decision D-293, 2026-09-27): ordinary
## `latent()` gains `d = "auto"`. `gllvmTMB()` detects a literal `d = "auto"`
## on the formula's single ordinary `latent()` term (before any covstruct
## desugaring -- see `.gllvmTMB_scan_auto_d()` in R/select-lv.R) and, when
## found, dispatches the whole fit through `select_lv()` instead of the
## ordinary path. This file tests the WIRING (formula scan, dispatch,
## refusals); `select_lv()`'s own sweep/guard logic is exercised by
## test-select-lv-guard.R and test-select-lv-anova.R.
##
## Only test (a) below runs a real TMB fit (four small Poisson fits via
## `optimizer = "optim"`/BFGS, `se = FALSE`, mirroring the fast-fit
## convention in test-select-lv-anova.R's `.select_lv_test_ctrl()`); every
## refusal-path test aborts before any fitting is attempted, so the whole
## file runs in well under a minute.

## ---- Helpers ---------------------------------------------------------------

## Simulate one small Poisson dataset from a rank-1 ordinary latent() DGP:
## eta_it = beta_t + Lambda[t, 1] * z_i, z_i ~ N(0, 1), y_it ~ Poisson(exp(eta_it)).
.latent_auto_test_dgp <- function(n_units = 60L, n_traits = 5L, seed = 4021) {
  set.seed(seed)
  traits <- paste0("t", seq_len(n_traits))
  units <- paste0("u", seq_len(n_units))
  Lambda <- matrix(c(0.55, -0.5, 0.5, -0.45, 0.4)[seq_len(n_traits)], ncol = 1L)
  beta <- seq(-0.1, 0.1, length.out = n_traits)
  scores <- matrix(stats::rnorm(n_units), n_units, 1L)
  eta <- outer(rep(1, n_units), beta) + scores %*% t(Lambda)
  df <- do.call(rbind, lapply(seq_along(units), function(i) {
    data.frame(
      unit = units[i], trait = traits,
      value = stats::rpois(n_traits, lambda = exp(eta[i, ]))
    )
  }))
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  df
}

.latent_auto_test_ctrl <- function() {
  gllvmTMBcontrol(optimizer = "optim", optArgs = list(method = "BFGS"), se = FALSE)
}

## Simulate one Poisson dataset from a rank-2 ordinary latent() DGP with
## strong loadings (8 traits x 100 units): every criterion picking d = 1 on
## test (a)'s rank-1 DGP cannot tell a real selection from a fit that always
## returns the d = 1 candidate (review finding), so this DGP is needed to
## pin the true positive. Seed 6 gives selected_d == 2 with bic_sites
## (verified by a seed sweep over seeds 1-10; seeds 6, 7 and 8 all recover
## d = 2, seed 6 used here).
.latent_auto_test_dgp2 <- function(n_units = 100L, n_traits = 8L, seed = 6) {
  set.seed(seed)
  traits <- paste0("t", seq_len(n_traits))
  units <- paste0("u", seq_len(n_units))
  Lambda <- matrix(stats::rnorm(n_traits * 2L, sd = 1.2), n_traits, 2L)
  beta <- seq(-0.1, 0.1, length.out = n_traits)
  scores <- matrix(stats::rnorm(n_units * 2L), n_units, 2L)
  eta <- outer(rep(1, n_units), beta) + scores %*% t(Lambda)
  df <- do.call(rbind, lapply(seq_along(units), function(i) {
    data.frame(
      unit = units[i], trait = traits,
      value = stats::rpois(n_traits, lambda = exp(eta[i, ]))
    )
  }))
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  df
}

## A minimal one-row long-format data frame: enough for `unit`/`trait`
## columns to exist so gllvmTMB()'s own auto-d scan runs and either
## dispatches or refuses, well before any real parsing or fitting is
## attempted. Used only by the refusal-path tests below.
.latent_auto_test_stub_data <- data.frame(
  unit = factor("u1"), trait = factor("t1"), value = 1
)

## ---- (a) a real Poisson fit: wiring matches calling select_lv() directly ---

test_that("gllvmTMB() with latent(d = \"auto\") matches select_lv() directly", {
  data <- .latent_auto_test_dgp()
  ctrl <- .latent_auto_test_ctrl()

  msgs <- testthat::capture_messages(
    fit <- gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = "auto", unique = FALSE),
      data = data, family = stats::poisson(), unit = "unit", trait = "trait",
      control = ctrl
    )
  )
  expect_s3_class(fit, "gllvmTMB_multi")
  ## The message must name the chosen d, the criterion, and the
  ## conditional-on-d caveat -- not just contain the substring "chose d"
  ## (a message with the wrong d, no criterion, and no caveat also matches
  ## that substring; review finding).
  msgs_flat <- gsub("\\s+", " ", paste(msgs, collapse = " "))
  expect_true(grepl("chose d = 1 by bic_sites over d = 1:4", msgs_flat, fixed = TRUE))
  expect_true(grepl("conditional on the chosen d", msgs_flat, fixed = TRUE))
  expect_equal(sum(grepl("chose d", msgs, fixed = TRUE)), 1L)
  expect_s3_class(fit$select_lv, "gllvmTMB_select_lv")
  expect_identical(fit$select_lv$d_max, 4L)
  expect_identical(fit$select_lv$criterion, "bic_sites")
  ## The attached object is trimmed: no duplicate fits (review finding).
  expect_null(fit$select_lv$fits)
  expect_null(fit$select_lv$selected_fit)

  sel_direct <- select_lv(
    value ~ 0 + trait + latent(0 + trait | unit, unique = FALSE),
    data = data, family = stats::poisson(), unit = "unit", trait = "trait",
    control = ctrl, d_max = 4L ## min(5, n_traits - 1) = min(5, 4)
  )
  expect_equal(fit$select_lv$selected_d, sel_direct$selected_d)
  expect_equal(as.numeric(stats::logLik(fit)),
               as.numeric(stats::logLik(sel_direct$selected_fit)))

  ## The fitted rank matches selected_d.
  Lambda_hat <- getLoadings(fit, level = "unit", rotate = "none")
  expect_equal(ncol(Lambda_hat), fit$select_lv$selected_d)
})

## ---- (a2) a real Poisson fit with true d = 2: auto-d actually selects -----
## Test (a) uses a rank-1 DGP on which every criterion picks d = 1, so it
## cannot tell a real selection from a fit that always returns the d = 1
## candidate (review finding). This DGP has strong rank-2 loadings; seed 6
## is confirmed (by a seed sweep) to make bic_sites choose d = 2.

test_that("gllvmTMB() with latent(d = \"auto\") selects d = 2 on a true rank-2 DGP", {
  data <- .latent_auto_test_dgp2()
  ctrl <- .latent_auto_test_ctrl()

  msgs <- testthat::capture_messages(
    fit <- gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = "auto", unique = FALSE),
      data = data, family = stats::poisson(), unit = "unit", trait = "trait",
      control = ctrl
    )
  )
  expect_identical(fit$select_lv$selected_d, 2L)
  msgs_flat <- gsub("\\s+", " ", paste(msgs, collapse = " "))
  expect_true(grepl("chose d = 2 by bic_sites over d = 1:5", msgs_flat, fixed = TRUE))
  expect_true(grepl("conditional on the chosen d", msgs_flat, fixed = TRUE))
  Lambda_hat <- getLoadings(fit, level = "unit", rotate = "none")
  expect_equal(ncol(Lambda_hat), 2L)
})

## ---- (b) more than one latent(d = "auto") term is refused ------------------

test_that("gllvmTMB() refuses more than one latent(d = \"auto\") term", {
  expect_error(
    gllvmTMB(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = "auto") +
        latent(0 + trait | unit_obs, d = "auto"),
      data = .latent_auto_test_stub_data, unit = "unit", trait = "trait"
    ),
    class = "gllvmTMB_auto_d_multiple"
  )
})

## ---- (c) an invalid d on latent() (neither "auto" nor a positive integer) --

test_that("gllvmTMB() refuses an invalid d on latent()", {
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = "bogus"),
      data = .latent_auto_test_stub_data, unit = "unit", trait = "trait"
    ),
    class = "gllvmTMB_latent_d_invalid"
  )
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 0),
      data = .latent_auto_test_stub_data, unit = "unit", trait = "trait"
    ),
    class = "gllvmTMB_latent_d_invalid"
  )
  ## A finite d beyond .Machine$integer.max used to make as.integer()
  ## return NA, crashing the scan with an unclassed "missing value where
  ## TRUE/FALSE needed" instead of this classed error (review fix).
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1e10),
      data = .latent_auto_test_stub_data, unit = "unit", trait = "trait"
    ),
    class = "gllvmTMB_latent_d_invalid"
  )
})

## ---- (c2) formulas select_lv() always refuses are caught up front ----------
## Before the review fix, these formulas passed gllvmTMB()'s scan and reached
## select_lv(), which aborts with an error worded for a function the user
## never called (gllvmTMB_select_lv_ambiguous_latent_term /
## gllvmTMB_select_lv_unsupported_source_latent /
## gllvmTMB_temporal_selection_unsupported). They are now refused up front,
## before ever calling select_lv(), with one class naming the real
## restriction.

test_that("gllvmTMB() refuses a second latent() term even with an explicit integer d", {
  expect_error(
    gllvmTMB(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = "auto") +
        latent(0 + trait | unit_obs, d = 1),
      data = .latent_auto_test_stub_data, unit = "unit", trait = "trait"
    ),
    class = "gllvmTMB_auto_d_unsupported_formula"
  )
})

test_that("gllvmTMB() refuses a structured source-specific latent term alongside d = \"auto\"", {
  expect_error(
    gllvmTMB(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = "auto") +
        phylo_latent(species, d = 1, tree = NULL),
      data = .latent_auto_test_stub_data, unit = "unit", trait = "trait"
    ),
    class = "gllvmTMB_auto_d_unsupported_formula"
  )
})

test_that("gllvmTMB() refuses a temporal_*() term alongside d = \"auto\"", {
  expect_error(
    gllvmTMB(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = "auto") +
        temporal_indep(0 + trait | unit, time = obs_time),
      data = .latent_auto_test_stub_data, unit = "unit", trait = "trait"
    ),
    class = "gllvmTMB_auto_d_unsupported_formula"
  )
})

## ---- (d) "auto" on another d-bearing covariance term is refused ------------

test_that("gllvmTMB() refuses d = \"auto\" on a non-latent covariance term", {
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + spatial_latent(0 + trait | unit, d = "auto"),
      data = .latent_auto_test_stub_data, unit = "unit", trait = "trait"
    ),
    class = "gllvmTMB_auto_d_unsupported_term"
  )
  ## `rr()` is a deprecated bare alias for `latent()` and is never a real,
  ## exported R function -- `d = "auto"` on it used to reach the fitting
  ## engine and crash with an unclassed base-R error (review fix).
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + rr(0 + trait | unit, d = "auto"),
      data = .latent_auto_test_stub_data, unit = "unit", trait = "trait"
    ),
    class = "gllvmTMB_auto_d_unsupported_term"
  )
})

## ---- (d2) the deprecated species= alias forwards its resolved value -------
## Review fix: `cluster_supplied` (computed from the `cluster` argument
## alone) was FALSE whenever the caller used `species = ...` instead, so the
## auto-d branch never forwarded the resolved cluster to select_lv() and
## every refit silently fell back to the default cluster "species". Checked
## with a mocked select_lv() spy (no fitting) so the test is fast and exact.

test_that("gllvmTMB() forwards the resolved cluster to select_lv() when species= was used", {
  captured <- NULL
  fake_select_lv <- function(formula, data, ..., d_max) {
    captured <<- list(...)
    structure(
      list(
        selected_d = 1L, criterion = "bic_sites", d_max = d_max,
        table = data.frame(d = 1L),
        selected_fit = structure(list(), class = "gllvmTMB_multi"),
        fits = list(`1` = structure(list(), class = "gllvmTMB_multi"))
      ),
      class = "gllvmTMB_select_lv"
    )
  }
  data <- data.frame(
    unit = factor(rep(c("u1", "u2", "u3", "u4"), each = 2)),
    trait = factor(rep(c("t1", "t2"), times = 4)),
    value = 1,
    sp = factor(rep(c("a", "a", "b", "b"), each = 2))
  )
  msgs <- testthat::with_mocked_bindings(
    select_lv = fake_select_lv,
    .package = "gllvmTMB",
    testthat::capture_messages(
      gllvmTMB(
        value ~ 0 + trait + latent(0 + trait | unit, d = "auto"),
        data = data, unit = "unit", trait = "trait", species = "sp"
      )
    )
  )
  expect_true(any(grepl("deprecated alias", msgs)))
  expect_identical(captured$cluster, "sp")
})

## ---- (e) default latent() is unchanged (d = 1) -----------------------------

test_that("latent()'s own default d is still 1 and an ordinary fit is unaffected", {
  expect_equal(formals(latent)$d, 1)

  ## No "auto" anywhere: the scan is a no-op and gllvmTMB() takes its
  ## ordinary path (no message, no $select_lv attached).
  data <- .latent_auto_test_dgp(n_units = 20L, n_traits = 3L, seed = 99)
  ctrl <- .latent_auto_test_ctrl()
  msgs <- testthat::capture_messages(
    fit <- gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit),
      data = data, family = stats::poisson(), unit = "unit", trait = "trait",
      control = ctrl
    )
  )
  expect_false(any(grepl("chose d", msgs, fixed = TRUE)))
  expect_null(fit$select_lv)
})

## ---- Direct unit tests of the formula scan ---------------------------------
## Fast, deterministic coverage of `.gllvmTMB_scan_auto_d()` itself, including
## a variable (symbol) `d` -- resolved by evaluating it in the formula's own
## environment, not misread as an invalid literal.

test_that(".gllvmTMB_scan_auto_d() resolves auto/invalid/variable d values correctly", {
  d_var <- 3L
  f_var <- value ~ 0 + trait + latent(0 + trait | unit, d = d_var)
  res_var <- .gllvmTMB_scan_auto_d(f_var)
  expect_equal(res_var$latent_auto, 0L)
  expect_length(res_var$invalid_latent_d, 0L)

  f_auto <- value ~ 0 + trait + latent(0 + trait | unit, d = "auto")
  expect_equal(.gllvmTMB_scan_auto_d(f_auto)$latent_auto, 1L)

  f_two_auto <- value ~ 0 + trait +
    latent(0 + trait | unit, d = "auto") +
    latent(0 + trait | unit_obs, d = "auto")
  expect_equal(.gllvmTMB_scan_auto_d(f_two_auto)$latent_auto, 2L)

  f_bogus <- value ~ 0 + trait + latent(0 + trait | unit, d = "bogus")
  expect_equal(.gllvmTMB_scan_auto_d(f_bogus)$invalid_latent_d, "bogus")

  f_zero <- value ~ 0 + trait + latent(0 + trait | unit, d = 0)
  expect_equal(.gllvmTMB_scan_auto_d(f_zero)$invalid_latent_d, "0")

  f_other <- value ~ 0 + trait + spatial_latent(0 + trait | unit, d = "auto")
  expect_equal(.gllvmTMB_scan_auto_d(f_other)$other_auto, "spatial_latent")

  f_default <- value ~ 0 + trait + latent(0 + trait | unit)
  res_default <- .gllvmTMB_scan_auto_d(f_default)
  expect_equal(res_default$latent_auto, 0L)
  expect_length(res_default$invalid_latent_d, 0L)
  expect_length(res_default$other_auto, 0L)
})
