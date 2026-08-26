#!/usr/bin/env Rscript
## Pure claim-boundary verifier for the interval-calibration programme.

argv <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", argv[grepl("^--file=", argv)])
script <- normalizePath(file_arg[[1L]], mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", ".."), mustWork = TRUE)
setwd(repo)
source("dev/interval-calibration/claim-contract.R")

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

require_fixed(
  "R/profile-derived.R",
  c(
    'status <- rep("route-only", length(lower))',
    "Every computed row"
  )
)
require_fixed(
  "tests/testthat/test-profile-ci-total-variance-export.R",
  c(
    "historically measured total-variance cells fail closed to route-only",
    'status_of(certified_stub()), "route-only"'
  )
)
require_fixed(
  "docs/design/75-inference-route-truth-matrix.md",
  c(
    "No status in this matrix is itself empirical-coverage evidence.",
    "no `CI-08` cell is certified",
    "the exact PVT-02 campaign is blocked",
    "structurally free strict-lower targets"
  )
)
require_fixed(
  "vignettes/articles/current-limits.Rmd",
  c(
    "withdrawn until the mechanism is repaired and recalibrated",
    "structurally free strict-lower"
  )
)
require_fixed(
  "vignettes/articles/profile-likelihood-ci.Rmd",
  c(
    "Every computed interval is labelled `route-only`",
    "exact constrained-refit convergence"
  )
)
require_fixed(
  "R/loading-ci.R",
  c(
    "structurally free strict-lower targets",
    "Pinned diagnostic rows, Fisher-z Wald"
  )
)
require_fixed(
  "docs/dev-log/known-limitations.md",
  c(
    "The former exact-cell certificate is therefore withdrawn.",
    "structurally free strict-lower targets"
  )
)
require_fixed(
  "docs/design/35-validation-debt-register.md",
  c(
    "CI-08 withdrawal addendum (2026-08-25)",
    "The former profile-total certificate is withdrawn",
    "CI-09 calibration addendum (2026-08-25)",
    "CI-14 calibration addendum (2026-08-25)",
    "CI-15 calibration addendum (2026-08-25)"
  )
)

for (claim_surface in c("_pkgdown.yml", "cran-comments.md")) {
  require_fixed(
    claim_surface,
    c("pinned unrotated ordinary-Gaussian standardized-loading Wald cells")
  )
}
require_fixed(
  "R/zzz.R",
  c(
    "pinned unrotated ordinary-Gaussian",
    "standardized-loading Wald cells"
  )
)

profile_source <- read_text("R/profile-derived.R")
forbidden_profile_claims <- c(
  "the certificate candidate",
  "CERTIFICATE CANDIDATE",
  "Route B is never the certificate"
)
if (any(vapply(
  forbidden_profile_claims,
  grepl,
  logical(1),
  x = profile_source,
  fixed = TRUE
))) {
  stop(
    "R/profile-derived.R retains a withdrawn total-variance certificate comment",
    call. = FALSE
  )
}

census <- utils::read.csv(
  "docs/dev-log/artifacts/interval-calibration/public-route-census.csv",
  stringsAsFactors = FALSE
)
validate_interval_route_census(census)
ci08 <- census[census$route_id == "CI08-PV-profile", , drop = FALSE]
ci08_exact <- census[census$route_id %in% c(
  "CI08-PV-n150-d1", "CI08-PV-n150-d2"
), , drop = FALSE]
ci08_pvt <- census[
  census$route_id == "CI08-PVT02-n400-d2",
  ,
  drop = FALSE
]
if (
  nrow(ci08) != 1L ||
    !identical(ci08$terminal_state, "limited") ||
    nrow(ci08_exact) != 2L ||
    any(ci08_exact$terminal_state != "limited") ||
    nrow(ci08_pvt) != 1L ||
    !identical(ci08_pvt$terminal_state, "blocked") ||
    !grepl("route-only everywhere", ci08$current_evidence, fixed = TRUE)
) {
  stop(
    paste(
      "CI-08 route census must keep callable and historical rows limited",
      "and the PVT-02 campaign blocked"
    ),
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
