#!/usr/bin/env Rscript

## Design-only G2m contract validator.  It reads text only: it never builds an
## objective, optimizes, profiles, simulates, or loads the private iJSDM route.
args <- commandArgs(trailingOnly = TRUE)
if (!identical(args, "--mode=validate")) {
  stop("G2m design validator requires exactly --mode=validate", call. = FALSE)
}

protocol <- file.path("dev", "isdm-package-recovery",
                      "2026-08-12-g2m-numerical-admission-protocol.md")
engine <- file.path("R", "fit-multi.R")
predecessor <- file.path("dev", "isdm-package-recovery",
                         "2026-08-12-g2k-gradient-diagnostic-decision.md")
for (path in c(protocol, engine, predecessor)) {
  if (!file.exists(path)) stop("required G2m input is missing: ", path, call. = FALSE)
}
text <- paste(readLines(protocol, warn = FALSE), collapse = "\n")
engine_text <- paste(readLines(engine, warn = FALSE), collapse = "\n")
predecessor_text <- paste(readLines(predecessor, warn = FALSE), collapse = "\n")

required_protocol <- c(
  "A. Raw pass / polish ineligible",
  "B. Boundary repair candidate",
  "C. Non-boundary residual",
  "D. Other raw failure",
  "E. Impossible overlap",
  "`NOT_REQUIRED`", "`NO_CANDIDATE`", "conditional repair evidence",
  "may not be applied retrospectively", "Local pre-run decision gate",
  "candidate_method", "dimname-misaligned covariance"
)
stopifnot(all(vapply(required_protocol, grepl, logical(1L), x = text, fixed = TRUE)))
stopifnot(grepl("## Decision: `NO_REPAIR`", predecessor_text, fixed = TRUE))

## Existing implementation facts that constrain the prospective table.
stopifnot(grepl(".gllvmTMB_isdm_polish_eligible", engine_text, fixed = TRUE))
stopifnot(grepl("identical(boundary_flags, \"near_zero_sd_B\")", engine_text, fixed = TRUE))
stopifnot(grepl("max_gradient > raw_gradient_gate", engine_text, fixed = TRUE))
stopifnot(grepl("max(abs(gradient)) >= gradient_threshold", engine_text, fixed = TRUE))

cat("G2M numerical-admission protocol validation PASS (design-only; no fit)\n")
