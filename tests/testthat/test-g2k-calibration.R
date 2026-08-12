test_that("G2k calibration contract freezes the 150-seed all-attempt grid", {
  runner <- test_path("..", "..", "dev", "isdm-package-recovery", "run-g2k-calibration.R")
  text <- paste(readLines(runner, warn = FALSE), collapse = "\n")
  expect_match(text, "86201L:86350L")
  expect_match(text, "n_requested = length\\(seeds\\)")
  expect_match(text, "n_missing")
  expect_match(text, "No fit was run")
})
