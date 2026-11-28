## Coverage (2026-11-25): `.normalise_level()` deprecation cache in R/normalise-level.R.

test_that(".normalise_level(.skip_warn = TRUE) suppresses legacy alias warnings", {
  expect_equal(gllvmTMB:::.normalise_level("B", .skip_warn = TRUE), "B")
  expect_silent(gllvmTMB:::.normalise_level("B", .skip_warn = TRUE))
})

test_that(".normalise_level() emits at most one deprecation per alias per session", {
  opt <- "gllvmTMB.warned_tier_W"
  withr::local_options(setNames(list(NULL), opt))
  expect_warning(
    gllvmTMB:::.normalise_level("W", arg_name = "tier"),
    class = "lifecycle_warning_deprecated"
  )
  expect_silent(gllvmTMB:::.normalise_level("W", arg_name = "tier"))
})

test_that(".normalise_level() passes non-scalar character level through", {
  expect_equal(gllvmTMB:::.normalise_level(c("unit", "B")), c("unit", "B"))
})