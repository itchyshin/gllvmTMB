## Stage 2 of the profile-CI unified framework: exposes Lambda entries
## through `confint.gllvmTMB_multi()` via parm = "Lambda" / "Lambda:i,j"
## / "Lambda:i,j;k,l", with `method = c("wald", "wald_asym", "profile")`
## routing to Stage 1's loading_ci() / loading_profile().
##
## Mirrors the binary-probit fixture from test-loading-ci.R so both
## stages exercise the same model.

## ---- Helper: build the same confirmatory binary JSDM fit -----------

build_fit_for_confint <- function(n_sites = 60L, seed = 20260527L) {
  set.seed(seed)
  species_names <- c(paste0("A_", 1:3), paste0("B_", 1:3), paste0("C_", 1:4))
  group <- c(rep("A", 3), rep("B", 3), rep("C", 4))
  Lambda <- matrix(0, length(species_names), 2L)
  Lambda[1:3, 1]   <- runif(3, 0.6, 1.0)
  Lambda[4:6, 2]   <- runif(3, 0.6, 1.0)
  Lambda[7:10,  ]  <- runif(8, -0.8, 0.8)
  U <- matrix(rnorm(n_sites * 2L), n_sites, 2L)
  alpha <- rnorm(length(species_names), 0, 0.3)
  eta <- matrix(alpha, n_sites, length(species_names), byrow = TRUE) +
    U %*% t(Lambda)
  y_wide <- matrix(rbinom(length(eta), 1, pnorm(eta)),
                   n_sites, length(species_names))
  colnames(y_wide) <- species_names
  df_long <- data.frame(
    site  = factor(rep(seq_len(n_sites), times = length(species_names))),
    trait = factor(rep(species_names, each = n_sites), levels = species_names),
    value = as.integer(c(y_wide))
  )
  M <- confirmatory_lambda(
    species = species_names, group = group, d = 2L,
    loads_on = list(A = 1L, B = 2L)
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2L),
    data              = df_long,
    family            = stats::binomial(link = "probit"),
    lambda_constraint = list(unit = M)
  )
  list(fit = fit, M = M, species = species_names)
}

## ---- parm = "Lambda" returns all entries ----------------------------

test_that("confint(fit, parm = 'Lambda') returns one row per entry", {
  skip_if_not_installed("TMB")
  bf <- build_fit_for_confint()
  ci <- confint(bf$fit, parm = "Lambda")

  expect_s3_class(ci, "data.frame")
  expect_true(all(c("parameter", "estimate", "lower", "upper",
                    "method", "pd_hessian", "ci_status") %in% names(ci)))
  ## 10 species x 2 axes = 20 entries
  expect_equal(nrow(ci), 20L)
  ## Default method is "wald" for Lambda
  expect_true(all(ci$method == "wald"))
  ## Parameter labels follow "Lambda[trait,axis]" pattern
  expect_true(all(grepl("^Lambda\\[", ci$parameter)))
})

## ---- parm = "Lambda:i,j" returns a single entry --------------------

test_that("confint(fit, parm = 'Lambda:1,1') returns exactly one row", {
  skip_if_not_installed("TMB")
  bf <- build_fit_for_confint()
  ci <- confint(bf$fit, parm = "Lambda:1,1")

  expect_s3_class(ci, "data.frame")
  expect_equal(nrow(ci), 1L)
  expect_match(ci$parameter[1], "^Lambda\\[")
})

## ---- parm = "Lambda:i,j;k,l" returns multiple entries --------------

test_that("confint(fit, parm = 'Lambda:1,1;2,1') returns two rows", {
  skip_if_not_installed("TMB")
  bf <- build_fit_for_confint()
  ci <- confint(bf$fit, parm = "Lambda:1,1;2,1")

  expect_s3_class(ci, "data.frame")
  expect_equal(nrow(ci), 2L)
  ## Each method-method row should follow the parameter label pattern.
  expect_true(all(grepl("^Lambda\\[", ci$parameter)))
})

## ---- Each of the three methods returns sensible bounds ---------------

test_that("method = 'wald' returns finite lower < estimate < upper for free entries", {
  skip_if_not_installed("TMB")
  bf <- build_fit_for_confint()
  ci <- confint(bf$fit, parm = "Lambda", method = "wald")
  ## All free entries on a PD fit should have finite bounds and
  ## lower <= estimate <= upper (the equality holds only for pinned).
  ## Use the loading_ci()'s pinned column via a back-channel: ci_status
  ## == "pinned" indicates pinned entries.
  free <- ci$ci_status != "pinned"
  expect_true(any(free))   # ensure we have free entries to test
  expect_true(all(is.finite(ci$lower[free])))
  expect_true(all(is.finite(ci$upper[free])))
  expect_true(all(ci$lower[free] < ci$estimate[free]))
  expect_true(all(ci$upper[free] > ci$estimate[free]))
})

test_that("method = 'wald_asym' returns finite asymmetric bounds for free entries", {
  skip_if_not_installed("TMB")
  bf <- build_fit_for_confint()
  ci <- confint(bf$fit, parm = "Lambda", method = "wald_asym")
  expect_true(all(ci$method == "wald_asym"))
  free <- ci$ci_status != "pinned"
  expect_true(any(free))
  expect_true(all(is.finite(ci$lower[free])))
  expect_true(all(is.finite(ci$upper[free])))
  expect_true(all(ci$lower[free] < ci$estimate[free]))
  expect_true(all(ci$upper[free] > ci$estimate[free]))
})

test_that("method = 'profile' returns finite bounds on at least one free entry", {
  ## Profile is expensive (refit per grid point per entry), so we use
  ## a small parm spec (one entry) to keep runtime modest.
  skip_if_not_installed("TMB")
  skip_on_cran()
  bf <- build_fit_for_confint()
  ## Pick a known-free entry: Lambda[2, 1] (A_2 loads on LV1, not pinned
  ## by the confirmatory_lambda anchor)
  ci <- confint(bf$fit, parm = "Lambda:2,1", method = "profile")
  expect_equal(nrow(ci), 1L)
  expect_true(all(ci$method == "profile"))
  ## Bounds should bracket the estimate. (Grid extent default = 6 SE;
  ## bracket reliability is a Stage-1 contract.)
  ## A finite lower OR upper is acceptable for the smoke test.
  expect_true(is.finite(ci$lower) || is.finite(ci$upper))
})

## ---- Malformed parm strings error clearly --------------------------

test_that("confint(fit, parm = 'Lambda:foo') errors with a clear message", {
  skip_if_not_installed("TMB")
  bf <- build_fit_for_confint()
  expect_error(
    confint(bf$fit, parm = "Lambda:foo"),
    "Lambda"
  )
})

test_that("confint(fit, parm = 'Lambda:9,9') errors when indices out of range", {
  skip_if_not_installed("TMB")
  bf <- build_fit_for_confint()
  ## n_traits = 10, K = 2; so (9, 9) is out of range in the K dimension.
  expect_error(
    confint(bf$fit, parm = "Lambda:9,9"),
    "range"
  )
})

test_that("confint(fit, parm = 'Lambda:1') errors (single index, expected 2)", {
  skip_if_not_installed("TMB")
  bf <- build_fit_for_confint()
  expect_error(
    confint(bf$fit, parm = "Lambda:1"),
    "Lambda"
  )
})

## ---- pdHess = FALSE behaviour --------------------------------------

test_that("pdHess = FALSE: Wald paths return NA + pd_hessian = FALSE", {
  skip_if_not_installed("TMB")
  bf <- build_fit_for_confint()
  bf$fit$sd_report$pdHess <- FALSE

  ## Wald
  ci_w <- suppressWarnings(confint(bf$fit, parm = "Lambda", method = "wald"))
  expect_true(all(is.na(ci_w$lower)))
  expect_true(all(is.na(ci_w$upper)))
  expect_true(all(ci_w$pd_hessian == FALSE))
  expect_true(all(ci_w$ci_status == "not_available_non_positive_definite_hessian"))

  ## Wald-asym
  ci_a <- suppressWarnings(confint(bf$fit, parm = "Lambda", method = "wald_asym"))
  expect_true(all(is.na(ci_a$lower)))
  expect_true(all(is.na(ci_a$upper)))
  expect_true(all(ci_a$pd_hessian == FALSE))
})

test_that("pdHess = FALSE: profile path produces finite bounds (bypasses gate)", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  bf <- build_fit_for_confint()
  bf$fit$sd_report$pdHess <- FALSE

  ## Restrict to a single entry to keep runtime modest.
  ci_p <- confint(bf$fit, parm = "Lambda:2,1", method = "profile")
  expect_equal(nrow(ci_p), 1L)
  expect_true(all(ci_p$method == "profile"))
  ## Profile bypasses the pdHess gate: at least one of lower / upper
  ## should be finite (the curve was built; only bracket-coverage can
  ## fail, which is a separate failure mode reported via ci_status).
  expect_true(is.finite(ci_p$lower) || is.finite(ci_p$upper))
})
