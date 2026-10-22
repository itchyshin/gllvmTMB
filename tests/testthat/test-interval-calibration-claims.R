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
.interval_claim_sources_available <- all(file.exists(c(
  claims_verifier,
  claims_contract
)))

if (.interval_claim_sources_available) {

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

  widened_regime <- census
  certified_row <- match("CI13-loading-n150-d2", widened_regime$route_id)
  widened_regime$current_evidence[[certified_row]] <-
    "native pinned unrotated n_units=150 d=2 only"
  expect_error(
    env$validate_interval_route_census(widened_regime),
    "frozen-DGP eligible-fit condition"
  )
})

test_that("CI-13 certificates name the frozen DGP and eligible-fit condition", {
  repo_root <- normalizePath(testthat::test_path("..", ".."))
  ## A3-gapclose (see dev/gapclose/A3-fixes-report.md) rewrote the "frozen
  ## DGP" / "conditional on eligible fits" boundary into plain language on
  ## these four reader-first surfaces; every other surface still carries the
  ## original wording. Both groups are checked with the phrasing they
  ## actually contain, so the test still fails if either boundary sentence
  ## is deleted or the two groups drift apart.
  plain_language_surfaces <- c(
    "R/zzz.R",
    "DESCRIPTION",
    "README.md",
    "man/gllvmTMB-package.Rd"
  )
  original_wording_surfaces <- c(
    "R/loading-ci.R",
    "NEWS.md",
    "_pkgdown.yml",
    "cran-comments.md",
    "man/loading_ci.Rd",
    "vignettes/articles/current-limits.Rmd",
    "docs/design/35-validation-debt-register.md",
    "docs/design/75-inference-route-truth-matrix.md",
    "docs/dev-log/known-limitations.md",
    "docs/dev-log/release/2026-08-08-0.7-release-claim-matrix.md",
    "docs/dev-log/artifacts/interval-calibration/interval-target-ledger.md",
    "docs/dev-log/artifacts/interval-calibration/2026-08-25-terminal-campaign-evidence.md",
    "docs/dev-log/artifacts/interval-calibration/public-route-census.csv"
  )
  claim_surfaces <- c(plain_language_surfaces, original_wording_surfaces)
  text <- vapply(
    file.path(repo_root, claim_surfaces),
    function(path) paste(readLines(path, warn = FALSE), collapse = "\n"),
    character(1)
  )
  names(text) <- claim_surfaces

  plain_text <- text[plain_language_surfaces]
  original_text <- text[original_wording_surfaces]

  expect_true(
    all(grepl(
      "one fixed simulated dataset with known true values",
      plain_text,
      fixed = TRUE
    )),
    info = paste(
      plain_language_surfaces[!grepl(
        "one fixed simulated dataset with known true values",
        plain_text,
        fixed = TRUE
      )],
      collapse = "\n"
    )
  )
  expect_true(
    all(grepl(
      "only for fits that converge cleanly",
      plain_text,
      fixed = TRUE
    )),
    info = paste(
      plain_language_surfaces[!grepl(
        "only for fits that converge cleanly",
        plain_text,
        fixed = TRUE
      )],
      collapse = "\n"
    )
  )
  expect_true(
    all(grepl("frozen DGP", original_text, fixed = TRUE)),
    info = paste(
      original_wording_surfaces[!grepl("frozen DGP", original_text, fixed = TRUE)],
      collapse = "\n"
    )
  )
  expect_true(
    all(grepl("conditional on eligible fits", original_text, fixed = TRUE)),
    info = paste(
      original_wording_surfaces[
        !grepl("conditional on eligible fits", original_text, fixed = TRUE)
      ],
      collapse = "\n"
    )
  )

  detailed <- paste(
    text[c(
      "R/loading-ci.R",
      "NEWS.md",
      "vignettes/articles/current-limits.Rmd"
    )],
    collapse = "\n"
  )
  expect_true(grepl("(0.80, 0.45, -0.35)", detailed, fixed = TRUE))
  expect_true(grepl("(0.70, 0.80, 0.90)", detailed, fixed = TRUE))
  expect_true(grepl("(-0.20, 0.10, 0.25)", detailed, fixed = TRUE))
})

test_that("the CI-08 profile test comment uses the live total-variance contract", {
  path <- testthat::test_path("test-profile-ci.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_false(grepl("certificate candidate", text, fixed = TRUE))
  expect_true(grepl("+ psi_t^2", text, fixed = TRUE))
})

test_that("the release-wide CI-13 boundary retains the unrotated fence", {
  path <- testthat::test_path(
    "..",
    "..",
    "docs",
    "dev-log",
    "release",
    "2026-08-08-0.7-release-claim-matrix.md"
  )
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_true(grepl(
    "native pinned unrotated ordinary-Gaussian standardized-loading",
    text,
    fixed = TRUE
  ))
})

`%||%` <- function(x, y) if (is.null(x)) y else x
} else {
  test_that("interval claim evidence checks are source-checkout only", {
    skip("dev/interval-calibration and docs/ are absent from the built package")
  })
}
