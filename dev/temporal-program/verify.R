args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) == 1L) args[[1L]] else ""
root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run temporal programme verification from the repository root.", call. = FALSE)
}
if (!mode %in% c("plan", "simulation", "combinations")) {
  stop("usage: Rscript --vanilla dev/temporal-program/verify.R {plan|simulation|combinations}", call. = FALSE)
}

.temporal_program_assert_test_results <- function(result, fixture) {
  summary <- as.data.frame(result)
  required <- c("failed", "error", "warning", "skipped")
  if (!all(required %in% names(summary)) || nrow(summary) == 0L) {
    stop("temporal programme verifier ran zero assertions: ", fixture, call. = FALSE)
  }
  if (any(summary$failed > 0L | summary$error > 0L |
          summary$warning > 0L | summary$skipped)) {
    stop("temporal programme verifier found a failed, errored, warned, or skipped assertion: ", fixture, call. = FALSE)
  }
  invisible(summary)
}

if (identical(mode, "plan")) {
  required <- c("dev/temporal-program/PLAN.md", ".unlazy/temporal-program/GATES.md")
  missing <- required[!file.exists(file.path(root, required))]
  if (length(missing)) stop("missing programme artifact(s): ", paste(missing, collapse = ", "), call. = FALSE)
  plan <- readLines(file.path(root, "dev/temporal-program/PLAN.md"), warn = FALSE)
  need <- c("## GOAL", "## Frozen model meaning", "## Prior-work sweep receipt", "## Slices and dependencies", "## Acceptance gates", "## Compute")
  if (!all(need %in% plan)) stop("programme plan is missing a required section", call. = FALSE)
  cat("TEMPORAL_PROGRAM_PLAN_PASS\n")
  quit(save = "no", status = 0L)
}

fixture <- switch(mode,
  simulation = file.path(root, "tests/testthat/test-temporal-program-simulation.R"),
  combinations = file.path(root, "tests/testthat/test-temporal-program-kernel.R")
)
if (!file.exists(fixture)) stop("missing temporal programme fixture", call. = FALSE)
pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
.temporal_program_assert_test_results(
  testthat::test_file(fixture, reporter = "silent"), fixture
)
cat(switch(mode,
  simulation = "TEMPORAL_PROGRAM_SIMULATION_PASS\n",
  combinations = "TEMPORAL_PROGRAM_COMBINATIONS_PASS\n"
))
