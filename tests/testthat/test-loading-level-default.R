test_that("loading flags default to the unit tier and preserve explicit aliases", {
  seen <- character()
  ci <- data.frame(estimate = 0.5, lower = 0.2, upper = 0.8,
                   pinned = FALSE, loading_scale = "raw")
  local_mocked_bindings(loading_ci = function(fit, level, ...) {
    seen <<- c(seen, level)
    if (length(level) != 1L) stop("level must be scalar")
    ci
  }, .package = "gllvmTMB")
  fit <- structure(list(), class = "gllvmTMB_multi")
  expect_no_error(out <- flag_unreliable_loadings(fit))
  expect_identical(seen, "unit")
  for (level in c("unit", "unit_obs", "B", "W")) {
    expect_no_error(flag_unreliable_loadings(fit, level = level))
    expect_identical(tail(seen, 1L), level)
  }
  expect_identical(flag_unreliable_loadings(fit, level = "unit")$unreliable, FALSE)
})
