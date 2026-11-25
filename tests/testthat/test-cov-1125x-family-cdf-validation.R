## Coverage (2026-11-25): input validation in R/family-cdf-args.R.

.cov1125_mock_fit <- function() {
  list(
    tmb_data = list(
      trait_id = c(0L, 0L, 1L, 1L),
      family_id_vec = c(2L, 2L, 2L, 2L),
      link_id_vec = c(0L, 0L, 0L, 0L)
    ),
    data = data.frame(trait = factor(rep(c("a", "b"), each = 2L))),
    trait_col = "trait"
  )
}

test_that(".gllvmTMB_report_at() returns NA when the vector is short or null", {
  expect_true(is.na(gllvmTMB:::.gllvmTMB_report_at(NULL, 1L)))
  expect_true(is.na(gllvmTMB:::.gllvmTMB_report_at(c(1), 2L)))
  expect_equal(gllvmTMB:::.gllvmTMB_report_at(c(3.3, 4.4), 2L), 4.4)
})

test_that(".gllvmTMB_family_cdf_args() validates trait_id", {
  fit <- .cov1125_mock_fit()
  expect_error(
    gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 0L),
    "single positive integer"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_family_cdf_args(fit, c(1L, 2L)),
    "single positive integer"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_family_cdf_args(fit, NA_integer_),
    "single positive integer"
  )
})

test_that(".gllvmTMB_family_cdf_args() errors when trait_id has no rows", {
  fit <- .cov1125_mock_fit()
  fit$tmb_data$trait_id <- rep(2L, 4L)
  expect_error(
    gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1L),
    "No rows with trait_id"
  )
})

test_that(".gllvmTMB_family_cdf_args() errors on mixed family_id within one trait", {
  fit <- .cov1125_mock_fit()
  fit$tmb_data$family_id_vec <- c(2L, 5L, 2L, 2L)
  expect_error(
    gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1L),
    "does not map to a single known family_id"
  )
})