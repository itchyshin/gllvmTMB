#!/usr/bin/env Rscript
## Pure claim-boundary verifier for the interval-calibration programme.

argv <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", argv[grepl("^--file=", argv)])
script <- normalizePath(file_arg[[1L]], mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", ".."), mustWork = TRUE)
setwd(repo)

read_text <- function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}
require_fixed <- function(path, needles) {
  text <- read_text(path)
  missing <- needles[
    !vapply(needles, grepl, logical(1), x = text, fixed = TRUE)
  ]
  if (length(missing)) {
    stop(
      path,
      " is missing required claim boundary: ",
      paste(missing, collapse = " | "),
      call. = FALSE
    )
  }
}
forbid_fixed <- function(path, needles) {
  text <- read_text(path)
  found <- needles[vapply(needles, grepl, logical(1), x = text, fixed = TRUE)]
  if (length(found)) {
    stop(
      path,
      " retains stale broad-certification wording: ",
      paste(found, collapse = " | "),
      call. = FALSE
    )
  }
}

scoped_claim_files <- c(
  "R/profile-derived.R",
  "man/profile_ci_total_variance.Rd",
  "vignettes/articles/current-limits.Rmd",
  "vignettes/articles/profile-likelihood-ci.Rmd",
  "docs/design/75-inference-route-truth-matrix.md"
)
for (path in scoped_claim_files) {
  forbid_fixed(path, c("n_units >= 150", "n_units >=150"))
}

require_fixed(
  "R/profile-derived.R",
  c(
    "identical(as.integer(fit$n_sites), 150L)",
    "any `n_units` other than 150"
  )
)
require_fixed(
  "tests/testthat/test-profile-ci-total-variance-export.R",
  c(
    "certified_stub(n_sites = 400L)",
    '"route-only"'
  )
)
require_fixed(
  "docs/design/75-inference-route-truth-matrix.md",
  c(
    "No status in this matrix is itself empirical-coverage evidence.",
    "n_units = 150",
    "no other sample size"
  )
)
require_fixed(
  "vignettes/articles/current-limits.Rmd",
  c(
    "exactly `n_units = 150`",
    "larger-sample fits do not inherit this"
  )
)
require_fixed(
  "vignettes/articles/profile-likelihood-ci.Rmd",
  c(
    "exactly `n_units = 150`",
    "larger-sample"
  )
)

census <- utils::read.csv(
  "docs/dev-log/artifacts/interval-calibration/public-route-census.csv",
  stringsAsFactors = FALSE
)
ci08 <- census[census$route_id == "CI08-PV-profile", , drop = FALSE]
if (
  nrow(ci08) != 1L ||
    !identical(ci08$terminal_state, "limited") ||
    !grepl("n_units=150 and d=1/2", ci08$current_evidence, fixed = TRUE)
) {
  stop(
    "CI-08 route census must remain limited outside its exact two-cell certificate",
    call. = FALSE
  )
}
refused <- census[census$ci_id %in% c("CI-11", "CI-12"), , drop = FALSE]
if (nrow(refused) != 2L || any(refused$terminal_state != "refused")) {
  stop("CI-11/12 typed-refusal dispositions changed", call. = FALSE)
}

r_text <- paste(
  vapply(
    list.files("R", pattern = "[.]R$", full.names = TRUE),
    read_text,
    character(1)
  ),
  collapse = "\n"
)
if (!grepl("gllvmTMB_nonlinear_profile_withdrawn", r_text, fixed = TRUE)) {
  stop(
    "public nonlinear-profile typed refusal is no longer live",
    call. = FALSE
  )
}
require_fixed("NAMESPACE", "export(profile_ci_total_variance)")

cat("INTERVAL_CLAIMS_OK\n")
