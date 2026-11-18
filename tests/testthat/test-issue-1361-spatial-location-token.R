## Issue #1361: the name after `|` in a spatial_*() keyword. At the default
## rho = 1 it is ignored (spell it `| coords`, and the "token is ignored"
## notice fires for anything else). With rho = NULL or a value other than 1 it
## is the location-identifier column and must be a real data column, so the
## notice must stay silent and an article must not write `| coords` there.
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
  ## Both the long and the wide estimated-rho fit must name the column.
  hits <- gregexpr(
    "spatial_latent\\([^\\n]*\\|\\s*location[^\\n]*rho\\s*=\\s*NULL",
    text,
    perl = TRUE
  )[[1L]]
  testthat::expect_gte(
    sum(hits > 0L),
    2L,
    label = "estimated-rho fits that name the `location` column"
  )
})

test_that("spatial rho reads the token as a location column and does not warn it is ignored", {
  skip_if_not_installed("fmesher")
  withr::local_options(gllvmTMB.quiet_grammar_notes = FALSE)
  fx <- .rho_spatial_fixture()
  mesh <- fx$mesh
  wide <- reshape(
    fx$data[c("obs", "group", "trait", "y")],
    idvar = c("obs", "group"), timevar = "trait", direction = "wide"
  )
  names(wide) <- sub("^y\\.", "", names(wide))

  ## The one-shot tracker is package state shared with other test files:
  ## restore exactly what was there when this test ends.
  seen <- getNamespace("gllvmTMB")$.gllvmTMB_deprecation_seen
  helpers <- c("spatial_latent", "spatial_indep", "spatial_dep")
  keys <- paste0("spatial-grouping-token-", helpers)
  had <- vapply(keys, exists, logical(1), envir = seen, inherits = FALSE)
  withr::defer({
    for (i in seq_along(keys)) {
      if (had[[i]]) {
        assign(keys[[i]], TRUE, envir = seen)
      } else if (exists(keys[[i]], envir = seen, inherits = FALSE)) {
        rm(list = keys[[i]], envir = seen)
      }
    }
  })
  reset <- function(h) {
    rlang::env_unbind(seen, nms = paste0("spatial-grouping-token-", h))
  }
  extra <- c(spatial_latent = ", d = 1, unique = TRUE", spatial_indep = "",
             spatial_dep = "")
  long_formula <- function(h, r) as.formula(sprintf(
    "y ~ 0 + trait + %s(0 + trait | group, mesh = mesh%s%s)", h, extra[[h]], r
  ))
  wide_formula <- function(h, r) as.formula(sprintf(
    "traits(t1, t2, t3, t4) ~ 1 + %s(1 | group, mesh = mesh%s%s)", h, extra[[h]], r
  ))

  for (h in helpers) {
    for (r in c(", rho = NULL", ", rho = 0.5")) {
      reset(h)
      expect_no_warning(
        .rho_capture_payload(long_formula(h, r), fx$data),
        message = "grouping token is ignored"
      )
      reset(h)
      expect_no_warning(
        .rho_capture_payload(wide_formula(h, r), wide),
        message = "grouping token is ignored"
      )
    }
  }
  ## The consumed-token state is scoped to one fit.
  expect_null(getNamespace("gllvmTMB")$.gllvmTMB_spatial_token_consumed$token)

  ## Callers that rewrite the formula directly (screen_gllvmTMB(),
  ## suggest_lambda_constraint()) never run gllvmTMB()'s capture, but still
  ## see the literal `rho` argument.
  reset("spatial_latent")
  expect_no_warning(
    gllvmTMB:::desugar_brms_sugar(
      y ~ 0 + trait + spatial_latent(0 + trait | group, mesh = mesh, d = 1, rho = NULL),
      trait_col = "trait"
    ),
    message = "grouping token is ignored"
  )

  ## At the default rho = 1 (omitted or explicit) the token really is
  ## ignored, so the notice stays.
  reset("spatial_latent")
  expect_warning(
    .rho_capture_payload(
      y ~ 0 + trait + spatial_latent(0 + trait | group, mesh = mesh, d = 1, unique = TRUE),
      fx$data
    ),
    "grouping token is ignored"
  )
  reset("spatial_latent")
  expect_warning(
    .rho_capture_payload(
      y ~ 0 + trait + spatial_latent(0 + trait | group, mesh = mesh, d = 1, unique = TRUE, rho = 1),
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
