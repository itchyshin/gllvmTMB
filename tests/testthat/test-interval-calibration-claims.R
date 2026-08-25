claims_verifier <- testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "verify-claims.R"
)

test_that("interval claim verification passes on the synchronized surfaces", {
  expect_true(file.exists(claims_verifier))
  out <- system2(
    "Rscript",
    c("--vanilla", claims_verifier),
    stdout = TRUE,
    stderr = TRUE
  )
  expect_equal(
    attr(out, "status") %||% 0L,
    0L,
    info = paste(out, collapse = "\n")
  )
  expect_true(any(grepl("INTERVAL_CLAIMS_OK", out, fixed = TRUE)))
})

test_that("every public-route census row has a live repository evidence pointer", {
  census_path <- testthat::test_path(
    "..",
    "..",
    "docs",
    "dev-log",
    "artifacts",
    "interval-calibration",
    "public-route-census.csv"
  )
  census <- read.csv(census_path, stringsAsFactors = FALSE)
  repo_root <- normalizePath(testthat::test_path("..", ".."))
  evidence <- file.path(repo_root, census$evidence_path)
  expect_true(all(
    c(
      "CI10-bootstrap-multiple-r",
      "CI10-profile-contrast-r"
    ) %in%
      census$route_id
  ))
  expect_true(
    all(file.exists(evidence)),
    info = paste(evidence[!file.exists(evidence)], collapse = "\n")
  )
})

`%||%` <- function(x, y) if (is.null(x)) y else x
