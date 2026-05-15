## Phase 1b validation milestone 2026-05-15:
## confint_inspect(fit, parm) tests. The function returns a structured
## object exposing the full profile curve + Wald comparison + plot.
##
## All tests use the same tiny Gaussian rank-1 fit fixture as
## test-profile-targets.R. Heavy tests gated by `skip_on_cran()`.

make_tiny_fit_for_inspect <- function(seed = 1L) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 20, n_species = 4, n_traits = 3,
    mean_species_per_site = 3,
    Lambda_B = matrix(c(0.8, 0.4, -0.3), 3, 1),
    psi_B    = c(0.3, 0.3, 0.3),
    seed     = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
            unique(0 + trait | site),
    data = sim$data
  )))
}

## ---- input validation ---------------------------------------------------

test_that("confint_inspect() errors on non-gllvmTMB_multi", {
  expect_error(
    gllvmTMB::confint_inspect(list(foo = 1), parm = "sigma_eps"),
    "gllvmTMB_multi"
  )
})

test_that("confint_inspect() errors on missing or multi-element parm", {
  skip_on_cran()
  fit <- make_tiny_fit_for_inspect()
  expect_error(gllvmTMB::confint_inspect(fit),
               "single character target label")
  expect_error(
    gllvmTMB::confint_inspect(fit, parm = c("sigma_eps", "b_fix[1]")),
    "single character target label"
  )
})

test_that("confint_inspect() errors on a derived target", {
  skip_on_cran()
  fit <- make_tiny_fit_for_inspect()
  expect_error(
    gllvmTMB::confint_inspect(fit, parm = "communality"),
    "does not handle derived targets"
  )
})

test_that("confint_inspect() errors on an unknown target label", {
  skip_on_cran()
  fit <- make_tiny_fit_for_inspect()
  expect_error(
    gllvmTMB::confint_inspect(fit, parm = "not_a_real_parm"),
    "No matching profile target"
  )
})

## ---- structure of the returned object -----------------------------------

test_that("confint_inspect() returns the documented structure", {
  skip_on_cran()
  fit <- make_tiny_fit_for_inspect()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::confint_inspect(fit, parm = "sigma_eps")
  ))
  expect_s3_class(res, "gllvmTMB_confint_inspect")
  expect_named(res, c("curve", "bounds", "plot", "diagnostics", "call"))
  ## $curve is a data.frame with the documented columns and >= 3 rows.
  expect_s3_class(res$curve, "data.frame")
  expect_gte(nrow(res$curve), 3L)
  expected_curve_cols <- c("parm", "parm_value_natural",
                           "parm_value_link", "nll", "deviance_drop",
                           "excess_over_threshold", "in_ci")
  expect_true(all(expected_curve_cols %in% colnames(res$curve)))
  ## $bounds is a 1-row data.frame with the documented columns.
  expect_s3_class(res$bounds, "data.frame")
  expect_equal(nrow(res$bounds), 1L)
  expected_bounds_cols <- c("parm", "estimate_natural",
                            "lower_natural", "upper_natural",
                            "wald_lower_natural", "wald_upper_natural",
                            "wald_profile_disagree_lower",
                            "wald_profile_disagree_upper")
  expect_true(all(expected_bounds_cols %in% colnames(res$bounds)))
})

## ---- well-behaved Gaussian sigma_eps profile ----------------------------

test_that("sigma_eps profile is well-behaved and matches Wald to within 10%", {
  skip_on_cran()
  fit <- make_tiny_fit_for_inspect()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::confint_inspect(fit, parm = "sigma_eps")
  ))
  ## Diagnostic should flag the profile as quadratic / well-behaved.
  expect_equal(res$diagnostics, "quadratic")
  ## Profile bounds are finite and positive (variance components > 0).
  expect_true(is.finite(res$bounds$lower_natural))
  expect_true(is.finite(res$bounds$upper_natural))
  expect_gt(res$bounds$lower_natural, 0)
  ## Profile and Wald should be within 10% half-width of each other
  ## for a smooth Gaussian fit.
  wald_hw <- (res$bounds$wald_upper_natural -
              res$bounds$wald_lower_natural) / 2
  expect_lt(
    abs(res$bounds$lower_natural - res$bounds$wald_lower_natural),
    0.10 * wald_hw
  )
  expect_lt(
    abs(res$bounds$upper_natural - res$bounds$wald_upper_natural),
    0.10 * wald_hw
  )
})

## ---- ggplot returned when ggplot2 is available --------------------------

test_that("confint_inspect() returns a ggplot when ggplot2 is available", {
  skip_on_cran()
  skip_if_not_installed("ggplot2")
  fit <- make_tiny_fit_for_inspect()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::confint_inspect(fit, parm = "sigma_eps")
  ))
  expect_s3_class(res$plot, "ggplot")
})

## ---- fixed-effect target works ------------------------------------------

test_that("confint_inspect() works for a fixed-effect target", {
  skip_on_cran()
  fit <- make_tiny_fit_for_inspect()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::confint_inspect(fit, parm = "b_fix[1]")
  ))
  expect_s3_class(res, "gllvmTMB_confint_inspect")
  expect_true(is.finite(res$bounds$lower_natural))
  expect_true(is.finite(res$bounds$upper_natural))
  ## b_fix is symmetric (linear predictor) -- profile should match
  ## Wald even more tightly than sigma_eps.
  wald_hw <- (res$bounds$wald_upper_natural -
              res$bounds$wald_lower_natural) / 2
  expect_lt(
    abs(res$bounds$lower_natural - res$bounds$wald_lower_natural),
    0.05 * wald_hw
  )
})

## ---- print method runs ---------------------------------------------------

test_that("print.gllvmTMB_confint_inspect runs without error", {
  skip_on_cran()
  fit <- make_tiny_fit_for_inspect()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::confint_inspect(fit, parm = "sigma_eps")
  ))
  ## cli::cli_h1 etc. write to stderr; test that the data-frame portion
  ## (printed via base::print()) appears on stdout, and the cli headers
  ## go to messages.
  expect_message(print(res), "gllvmTMB confint_inspect")
  expect_output(print(res), "sigma_eps")
})
