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

test_that("G2d preflight seals a writable root without fitting", {
  pkg_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = TRUE)
  script <- file.path(pkg_root, "dev", "isdm-package-recovery", "run-g2d-six-species-recovery.R")
  out_abs <- file.path(pkg_root, "dev", "isdm-package-recovery", "results", paste0("testthat-g2d-preflight-", Sys.getpid()))
  on.exit(unlink(out_abs, recursive = TRUE, force = TRUE), add = TRUE)
  sha <- system2("git", c("-C", pkg_root, "rev-parse", "HEAD"), stdout = TRUE)
  result <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", script, "--mode=preflight", paste0("--output=", out_abs), paste0("--pkg=", pkg_root), paste0("--campaign-sha=", sha)), stdout = TRUE, stderr = TRUE)
  expect_true(is.null(attr(result, "status")) || identical(attr(result, "status"), 0L))
  expect_true(any(grepl("G2D_PREFLIGHT_PASS (no fit)", result, fixed = TRUE)))
  expect_true(all(file.exists(file.path(out_abs, c("root-receipt.rds", "root-receipt.md", "preflight-sentinel.rds", "preflight-file-manifest.csv", "preflight-receipt.md")))))
  expect_identical(readRDS(file.path(out_abs, "preflight-sentinel.rds"))$kind, "G2D_PREFLIGHT_SENTINEL")
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
  expect_match(runner, "G2D_PREFLIGHT_PASS", fixed = TRUE)
  expect_match(runner, "G2D_SMOKE_PASS", fixed = TRUE)
  expect_match(runner, 'fit$tmb_map[["theta_diag_B", exact = TRUE]]', fixed = TRUE)
  expect_match(protocol, "GBIF-only", fixed = TRUE)
  expect_match(protocol, "18 of all 20", fixed = TRUE)
})
