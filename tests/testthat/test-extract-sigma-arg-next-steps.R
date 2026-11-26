## #1247 follow-up 4: argument checks in R/extract-sigma.R tell the reader
## what to pass. The first line of each message is unchanged.

test_that(".gamma_trait_arg() names a next step for bad trait vectors", {
  expect_error(
    .gamma_trait_arg(NULL, "row_traits"),
    "row_traits.*must be a non-empty character vector.*Pass the trait names"
  )
  expect_error(
    .gamma_trait_arg(c("a", NA), "col_traits"),
    "col_traits.*must be a non-empty character vector.*Pass the trait names"
  )
  expect_error(
    .gamma_trait_arg(c("a", "a"), "row_traits"),
    "must not contain duplicate trait names.*Pass each trait name once"
  )
  expect_identical(.gamma_trait_arg(c("a", "b"), "row_traits"), c("a", "b"))
})

test_that(".cross_covariance_arg() names a next step for bad level vectors", {
  expect_error(
    .cross_covariance_arg(character(0), "row_levels"),
    "row_levels.*must be a non-empty character vector.*Pass the level names"
  )
  expect_error(
    .cross_covariance_arg(c("a", "a"), "col_levels"),
    "must not contain duplicate names.*Pass each level name once"
  )
  expect_identical(.cross_covariance_arg(c("a", "b"), "row_levels"), c("a", "b"))
})

test_that("stored-K checks in .kernel_level_matrix() name the refit step", {
  fit <- list(
    kernel_levels = data.frame(name = "cross", internal_level = "phy"),
    kernel_matrices = list(cross = matrix(c("a", "b", "c", "d"), 2))
  )
  testthat::local_mocked_bindings(
    .kernel_level_alias = function(fit, level) {
      list(internal_level = "phy", index = NULL)
    }
  )
  expect_error(
    .kernel_level_matrix(fit, "cross"),
    "is not a numeric matrix.*Refit with `K` supplied"
  )
  fit$kernel_matrices <- list(cross = matrix(1:4 + 0.5, 2))
  expect_error(
    .kernel_level_matrix(fit, "cross"),
    "must have row and column names.*Refit with `K` supplied"
  )
})

test_that("extract_Gamma() and the module helper name a next step for bad scalars", {
  fit <- structure(list(), class = "gllvmTMB_multi")
  expect_error(
    extract_Gamma(fit, level = c("a", "b"), row_traits = "x", col_traits = "y"),
    "level.*must be one non-empty character string.*Pass the name of one fitted"
  )
})
