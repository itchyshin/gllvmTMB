# tidy(effects = "fixed") must not report standard errors from a Hessian that
# is not positive definite (#1351, part 1).

.tidy_nonpd_fit <- function() {
  set.seed(1351)
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 8, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.5, -0.3), nrow = 3, ncol = 1),
    psi_B = c(0.3, 0.3, 0.3),
    seed = 1351
  )
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 + latent(0 + trait | site, d = 1),
    data = sim$data
  ))
}

test_that("tidy(fixed) returns NA std.error and a status when pdHess is FALSE", {
  skip_on_cran()
  fit <- .tidy_nonpd_fit()
  ok <- tidy(fit, "fixed", conf.int = TRUE)
  expect_true(isTRUE(fit$sd_report$pdHess))
  expect_true(all(is.finite(ok$std.error)))
  expect_false("inference_status" %in% names(ok))

  bad <- fit
  bad$sd_report$pdHess <- FALSE
  tf <- tidy(bad, "fixed", conf.int = TRUE)
  expect_equal(tf$estimate, ok$estimate)
  expect_true(all(is.na(tf$std.error)))
  expect_true(all(is.na(tf$conf.low)))
  expect_true(all(is.na(tf$conf.high)))
  expect_true("inference_status" %in% names(tf))
  expect_true(all(tf$inference_status == "non_positive_definite_hessian"))
})

test_that("tidy(fixed) withholds std.error when the sdreport is missing", {
  skip_on_cran()
  fit <- .tidy_nonpd_fit()
  fit$sd_report <- NULL
  tf <- tidy(fit, "fixed")
  expect_true(all(is.na(tf$std.error)))
  expect_true("inference_status" %in% names(tf))
  expect_true(all(tf$inference_status == "sdreport_unavailable"))
})

test_that("tidy(fixed) on a PD fit is unchanged", {
  skip_on_cran()
  fit <- .tidy_nonpd_fit()
  tf <- tidy(fit, "fixed")
  expect_equal(tf$std.error, .gllvmTMB_b_fix_table(fit)$Std.Err)
  expect_false("inference_status" %in% names(tf))
})
