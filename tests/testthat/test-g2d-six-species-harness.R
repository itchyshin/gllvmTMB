test_that("G2d six-species fixture contract validates without fitting", {
  pkg_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = TRUE)
  script <- file.path(pkg_root, "dev", "isdm-package-recovery", "run-g2d-six-species-recovery.R")
  skip_if_not(file.exists(script), "developer-only G2d recovery harness is unavailable")
  out <- tempfile("g2d-validate-")
  result <- system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", script, "--mode=validate", paste0("--output=", out), paste0("--pkg=", pkg_root)),
    stdout = TRUE, stderr = TRUE
  )
  expect_true(is.null(attr(result, "status")) || identical(attr(result, "status"), 0L))
  expect_true(any(grepl("G2D fixture/support/profile contract validation PASS", result, fixed = TRUE)))
  expect_false(dir.exists(out))
})

test_that("G2d private artifacts freeze the six-species contract", {
  pkg_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = TRUE)
  artifact <- function(name) {
    paste(readLines(file.path(pkg_root, "dev", "isdm-package-recovery", name), warn = FALSE), collapse = "\n")
  }
  runner <- artifact("run-g2d-six-species-recovery.R")
  protocol <- artifact("2026-08-10-g2d-six-species-protocol.md")
  expect_match(runner, "86101:86120", fixed = TRUE)
  expect_match(runner, "theta_diag_B_sp", fixed = TRUE)
  expect_match(runner, "c(-2, -1, 0, 1, 2)", fixed = TRUE)
  expect_match(runner, "G2D_SIX_SPECIES_PASS", fixed = TRUE)
  expect_match(runner, "abs(stats::cor", fixed = TRUE)
  expect_match(runner, "ensure_result_root <- function()", fixed = TRUE)
  expect_match(runner, "ensure_result_root()", fixed = TRUE)
  expect_match(protocol, "GBIF-only", fixed = TRUE)
  expect_match(protocol, "18 of all 20", fixed = TRUE)
})
