test_that("loading_ci() accepts legacy level = B / W (#1391)", {
  fit <- structure(
    list(
      report = list(
        Lambda_B = matrix(c(1, 1), nrow = 1L,
                          dimnames = list("trait_1", c("LV1", "LV2")))
      ),
      lambda_constraint = list(B = matrix(c(1, NA_real_), nrow = 1L)),
      sd_report = structure(list(pdHess = TRUE), class = "sdreport")
    ),
    class = "gllvmTMB_multi"
  )
  rho <- matrix(c(0.5, 0.5), nrow = 1L)
  testthat::local_mocked_bindings(
    .standardize_loadings_by_total_variance = function(fit, Lambda, level) rho,
    .loading_delta_at_mle = function(fit, internal_level, loading_scale) {
      list(Lambda = rho, se = matrix(c(0.1, 0.2), nrow = 1L))
    },
    .package = "gllvmTMB"
  )

  withr::local_options(gllvmTMB.warned_level_B = NULL)
  expect_warning(
    out_b <- loading_ci(fit, level = "B", loading_scale = "standardized"),
    class = "lifecycle_warning_deprecated"
  )
  expect_s3_class(out_b, "data.frame")
  expect_equal(nrow(out_b), 2L)

  withr::local_options(gllvmTMB.warned_level_W = NULL)
  fit_w <- fit
  fit_w$report$Lambda_W <- fit_w$report$Lambda_B
  fit_w$lambda_constraint <- list(W = fit_w$lambda_constraint$B)
  fit_w$report$Lambda_B <- NULL
  fit_w$lambda_constraint$B <- NULL
  expect_warning(
    out_w <- loading_ci(fit_w, level = "W", loading_scale = "standardized"),
    class = "lifecycle_warning_deprecated"
  )
  expect_equal(nrow(out_w), 2L)
})
