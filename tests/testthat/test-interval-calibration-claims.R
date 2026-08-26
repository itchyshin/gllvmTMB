claims_verifier <- testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "verify-claims.R"
)
claims_contract <- testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "claim-contract.R"
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

test_that("route-census promotion fails closed on the exact route/state map", {
  env <- new.env(parent = globalenv())
  source(claims_contract, local = env)
  census <- read.csv(
    testthat::test_path(
      "..",
      "..",
      "docs",
      "dev-log",
      "artifacts",
      "interval-calibration",
      "public-route-census.csv"
    ),
    stringsAsFactors = FALSE
  )

  expect_silent(env$validate_interval_route_census(census))

  bad_state <- census
  bad_state$terminal_state[[1L]] <- "available"
  expect_error(
    env$validate_interval_route_census(bad_state),
    "terminal state"
  )

  widened <- census
  widened$terminal_state[
    widened$route_id == "CI13-standardized-loading"
  ] <- "certified"
  expect_error(
    env$validate_interval_route_census(widened),
    "exact route/state map"
  )

  renamed <- census
  renamed$route_id[
    renamed$route_id == "CI14-ordinary-slope-sd"
  ] <- "CI14-arbitrary-route"
  expect_error(
    env$validate_interval_route_census(renamed),
    "exact route/state map"
  )

  pvt_promoted <- census
  pvt_promoted$terminal_state[
    pvt_promoted$route_id == "CI08-PVT02-n400-d2"
  ] <- "limited"
  expect_error(
    env$validate_interval_route_census(pvt_promoted),
    "exact route/state map"
  )
})

`%||%` <- function(x, y) if (is.null(x)) y else x
