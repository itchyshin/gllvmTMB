args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) == 1L) args[[1L]] else ""
root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run temporal programme verification from the repository root.", call. = FALSE)
}
allowed <- c("plan", "simulation", "lifecycle", "publication", "combinations", "closeout", "self-test")
if (!mode %in% allowed) {
  stop("usage: Rscript --vanilla dev/temporal-program/verify.R {plan|simulation|lifecycle|publication|combinations|closeout|self-test}", call. = FALSE)
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

.temporal_program_expect_reject <- function(expr, label) {
  rejected <- inherits(try(force(expr), silent = TRUE), "try-error")
  if (!rejected) stop("temporal programme verifier did not reject ", label, call. = FALSE)
  invisible(TRUE)
}

if (identical(mode, "self-test")) {
  base <- data.frame(failed = 0L, error = 0L, warning = 0L, skipped = FALSE)
  .temporal_program_expect_reject(
    .temporal_program_assert_test_results(base[FALSE, , drop = FALSE], "self-test"),
    "zero assertions"
  )
  for (field in names(base)) {
    bad <- base
    bad[[field]] <- if (identical(field, "skipped")) TRUE else 1L
    .temporal_program_expect_reject(
      .temporal_program_assert_test_results(bad, "self-test"),
      paste0("a ", field, " result")
    )
  }
  cat("TEMPORAL_PROGRAM_SELF_TEST_PASS\n")
  quit(save = "no", status = 0L)
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

if (identical(mode, "publication")) {
  stop("Publication verification requires a retained three-OS CI receipt; none is available in this local worktree.", call. = FALSE)
}
if (identical(mode, "combinations")) {
  stop("Combination verification requires an admitted temporal-source pair and retained dense-oracle, lifecycle, and recovery evidence; no source pair is admitted.", call. = FALSE)
}
if (identical(mode, "closeout")) {
  stop("Closeout requires passing publication and temporal-source-pair gates; both remain pending.", call. = FALSE)
}

fixture <- switch(mode,
  simulation = c(
    "tests/testthat/test-temporal-program-simulation.R",
    "tests/testthat/test-temporal-program-composed-simulation.R"
  ),
  lifecycle = c(
    "tests/testthat/test-temporal-program-forecast.R",
    "tests/testthat/test-temporal-program-profile.R",
    "tests/testthat/test-temporal-program-bootstrap.R",
    "tests/testthat/test-temporal-program-selection.R"
  )
)
if (any(!file.exists(file.path(root, fixture)))) {
  stop("missing temporal programme fixture: ",
    paste(fixture[!file.exists(file.path(root, fixture))], collapse = ", "), call. = FALSE)
}
pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
for (path in fixture) {
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, path), reporter = "silent"), path
  )
}
cat(sprintf("TEMPORAL_PROGRAM_%s_PASS\n", toupper(mode)))
