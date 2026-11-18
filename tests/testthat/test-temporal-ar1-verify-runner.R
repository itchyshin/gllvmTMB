.temporal_verify_runner <- function(fixture) {
  root <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  runner <- file.path(root, "dev", "temporal-ar1", "verify.R")
  old <- setwd(root)
  on.exit(setwd(old), add = TRUE)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", runner, "parser"),
    stdout = TRUE,
    stderr = TRUE,
    env = paste0("TEMPORAL_VERIFY_FIXTURE=", fixture)
  ))
  list(output = out, status = attr(out, "status") %||% 0L)
}

test_that("temporal verification runner rejects missing, skipped, and failed fixtures", {
  skip_if_not(file.exists(testthat::test_path("..", "..", "dev", "temporal-ar1", "verify.R")))
  missing <- .temporal_verify_runner("tests/testthat/no-such-temporal-fixture.R")
  expect_gt(missing$status, 0L)
  expect_match(paste(missing$output, collapse = "\n"), "Missing required temporal fixture")

  skipped_fixture <- tempfile("temporal-all-skipped-", fileext = ".R")
  writeLines("testthat::test_that('skipped', testthat::skip('fixture skip'))", skipped_fixture)
  skipped <- .temporal_verify_runner(skipped_fixture)
  expect_gt(skipped$status, 0L)
  expect_match(paste(skipped$output, collapse = "\n"), "contains skipped")

  failed_fixture <- tempfile("temporal-failing-", fileext = ".R")
  writeLines("testthat::test_that('fails', testthat::expect_true(FALSE))", failed_fixture)
  failed <- .temporal_verify_runner(failed_fixture)
  expect_gt(failed$status, 0L)
  expect_match(paste(failed$output, collapse = "\n"), "contains skipped, failed, errored, or warning results")
})
