## Issue #1361: spatial_latent() articles must not use the ignored `| location` token.
##
## R CMD check runs tests from <pkg>.Rcheck/tests/testthat.  ../../vignettes
## is the check tree, not the source package, so the naive path misses the
## file.  The tarball copy lives at ../../00_pkg_src/gllvmTMB/ (same layout
## as test-isdm-developer-fit.R).

.pkg_source_file <- function(...) {
  rel <- do.call(file.path, list(...))
  candidates <- c(
    testthat::test_path("..", "..", rel),
    testthat::test_path("..", "..", "00_pkg_src", "gllvmTMB", rel),
    testthat::test_path("..", "..", "..", "00_pkg_src", "gllvmTMB", rel)
  )
  found <- candidates[file.exists(candidates)]
  if (length(found) == 0L) {
    return(NA_character_)
  }
  found[[1L]]
}

## `rho = NULL` (estimated attenuation) reads the token right of `|` as the
## location-identifier column, so it must name a real data column; the
## placeholder `| coords` aborts there ("Spatial attenuation requires an
## observed grouping column"), which broke the scheduled pkgdown build.
test_that("structured-source-strength.Rmd names a real location column in spatial rho terms", {
  rmd <- .pkg_source_file(
    "vignettes", "articles", "structured-source-strength.Rmd"
  )
  testthat::skip_if_not(
    is.character(rmd) && !is.na(rmd) && file.exists(rmd),
    "article missing"
  )

  text <- paste(readLines(rmd, warn = FALSE), collapse = "\n")
  testthat::expect_no_match(
    text,
    "spatial_latent\\([^\\n]*\\|\\s*coords[^\\n]*rho\\s*=\\s*NULL",
    perl = TRUE,
    info = "`rho = NULL` needs a location column after the bar, not `| coords`"
  )
  testthat::expect_match(
    text,
    "spatial_latent\\([^\\n]*\\|\\s*location[^\\n]*rho\\s*=\\s*NULL",
    perl = TRUE,
    info = "the estimated-rho spatial fits should name the `location` column"
  )
})

test_that("spatial rho reads the token as a location column and does not warn it is ignored", {
  skip_if_not_installed("fmesher")
  withr::local_options(gllvmTMB.quiet_grammar_notes = FALSE)
  fx <- .rho_spatial_fixture()
  mesh <- fx$mesh
  seen <- getNamespace("gllvmTMB")$.gllvmTMB_deprecation_seen
  key <- "spatial-grouping-token-spatial_latent"
  for (r in c("NULL", "0.5")) {
    rlang::env_unbind(seen, nms = key)
    f <- as.formula(sprintf(
      "y ~ 0 + trait + spatial_latent(0 + trait | group, mesh = mesh, d = 1, unique = TRUE, rho = %s)",
      r
    ))
    expect_no_warning(
      .rho_capture_payload(f, fx$data),
      message = "grouping token is ignored"
    )
  }
  ## The consumed-token state is scoped to one fit.
  expect_null(getNamespace("gllvmTMB")$.gllvmTMB_spatial_token_consumed$token)

  ## At the default rho = 1 the token really is ignored, so the notice stays.
  rlang::env_unbind(seen, nms = key)
  expect_warning(
    .rho_capture_payload(
      y ~ 0 + trait + spatial_latent(0 + trait | group, mesh = mesh, d = 1, unique = TRUE),
      fx$data
    ),
    "grouping token is ignored"
  )
})

psi_note <- "one-time warning.*per-trait Psi by default"

test_that("articles note the expected once-per-session latent() Psi warning", {
  articles <- c(
    "convergence-start-values.Rmd",
    "pre-fit-response-screening.Rmd",
    "pitfalls.Rmd"
  )
  for (nm in articles) {
    rmd <- .pkg_source_file("vignettes", "articles", nm)
    testthat::skip_if_not(
      is.character(rmd) && !is.na(rmd) && file.exists(rmd),
      paste("missing", nm)
    )
    text <- paste(readLines(rmd, warn = FALSE), collapse = "\n")
    testthat::expect_match(
      text,
      psi_note,
      info = paste0(nm, " should explain the once-per-session Psi warning")
    )
  }
})
