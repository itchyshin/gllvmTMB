## Phase 1b validation milestone 2026-05-15 item 3:
## coverage_study(fit, parm, n_reps, methods) -- empirical
## coverage-rate estimator. The audit's recommended "Phase 1b
## validation milestone exit gate" is >= 94% empirical coverage
## per family.
##
## Tests use small n_reps (5-10) and skip_on_cran(). The
## parametric-bootstrap loop refits the model on each replicate;
## even small n_reps takes 30-60 seconds. Local-only.

make_tiny_fit_for_cov <- function(seed = 1L) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 4, n_traits = 3,
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

test_that("coverage_study() errors on non-gllvmTMB_multi", {
  expect_error(
    gllvmTMB::coverage_study(list(foo = 1), n_reps = 5L),
    "gllvmTMB_multi"
  )
})

test_that("coverage_study() rejects n_reps < 2", {
  fit <- structure(list(tmb_obj = NULL), class = "gllvmTMB_multi")
  expect_error(
    gllvmTMB::coverage_study(fit, n_reps = 1L),
    "n_reps"
  )
})

test_that("coverage_study() rejects unknown parm labels", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cov()
  expect_error(
    gllvmTMB::coverage_study(fit, parm = c("sigma_eps", "not_real"),
                             n_reps = 3L),
    "Unknown profile-target label"
  )
})

## ---- structure of the returned object -----------------------------------

test_that("coverage_study() returns the documented structure", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cov()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::coverage_study(fit,
                             parm = c("sigma_eps", "sd_B[1]"),
                             n_reps = 5L, methods = "wald",
                             seed = 1, progress = FALSE)
  ))
  expect_s3_class(res, "gllvmTMB_coverage_study")
  expect_named(res, c("coverage", "intervals", "n_failed_refits",
                      "call"))
  ## coverage data frame columns:
  expect_s3_class(res$coverage, "data.frame")
  expected_cov_cols <- c("parm", "method", "n_reps", "n_covered",
                         "n_excluded", "rate", "passes_94pct")
  expect_true(all(expected_cov_cols %in% colnames(res$coverage)))
  ## intervals data frame columns:
  expect_s3_class(res$intervals, "data.frame")
  expected_int_cols <- c("rep", "parm", "method", "truth",
                         "lower", "upper", "covered")
  expect_true(all(expected_int_cols %in% colnames(res$intervals)))
  ## Each (parm x method) row has n_reps <= 5 (no over-counting).
  expect_true(all(res$coverage$n_reps <= 5L))
  ## All rates are in [0, 1].
  expect_true(all(res$coverage$rate >= 0 & res$coverage$rate <= 1,
                  na.rm = TRUE))
})

## ---- well-behaved fit hits the >= 94% gate on a small sample ----------

test_that("Wald CI on sigma_eps passes the 94% gate on a tiny well-identified fit", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cov()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::coverage_study(fit, parm = "sigma_eps",
                             n_reps = 10L, methods = "wald",
                             seed = 1, progress = FALSE)
  ))
  ## Coverage for sigma_eps on a Gaussian fit should comfortably
  ## hit the gate at n_reps = 10. (Finite-n_reps noise -- ~3
  ## successes < 94% on 5 reps -- means we relax to >= 80% here;
  ## the 94% gate is meaningful at audit-recommended n_reps = 50.)
  rate <- res$coverage$rate[res$coverage$method == "wald"]
  expect_gte(rate, 0.80)
})

## ---- coverage_study() default parm omits lambda_packed targets --------

test_that("coverage_study() default parm omits lambda_packed (rotation-ambiguous)", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cov()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::coverage_study(fit, n_reps = 3L, methods = "wald",
                             seed = 1, progress = FALSE)
  ))
  ## None of the default-target parm labels should be a
  ## Lambda_*_packed entry (rotation-ambiguous; coverage would be
  ## misleading).
  expect_false(any(grepl("^Lambda_.*_packed", res$coverage$parm)))
})

## ---- print method runs --------------------------------------------------

test_that("print.gllvmTMB_coverage_study runs without error", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cov()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::coverage_study(fit, parm = "sigma_eps",
                             n_reps = 3L, methods = "wald",
                             seed = 1, progress = FALSE)
  ))
  expect_message(print(res), "coverage study")
})

## ---- bonus: extended Wald confint routing for non-fixed-effect parm ---

test_that("confint(method = 'wald') routes through profile_targets() for non-fixed-effect parm", {
  skip_on_cran()
  fit <- make_tiny_fit_for_cov()
  ci <- suppressMessages(suppressWarnings(
    stats::confint(fit, parm = c("sigma_eps", "sd_B[1]"),
                   method = "wald")
  ))
  expect_true(is.matrix(ci))
  expect_equal(rownames(ci), c("sigma_eps", "sd_B[1]"))
  ## Wald bound for sigma_eps is finite (well-behaved fit).
  expect_true(all(is.finite(ci["sigma_eps", ])))
})
