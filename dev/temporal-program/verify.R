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

.temporal_program_kernel_summary <- function(results) {
  expected_phi <- c(-.4, 0, .6)
  expected_seed <- 2609151:2609153
  required <- c(
    "phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "temporal_relative_error_1",
    "temporal_relative_error_2", "temporal_relative_error_3",
    "kernel_relative_error_1", "kernel_relative_error_2",
    "kernel_relative_error_3", "phi_absolute_error",
    "fixed_effect_mean_absolute_error"
  )
  if (!all(required %in% names(results)) || nrow(results) != 9L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("temporal-kernel recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  if (!all(strict)) {
    stop("temporal-kernel recovery has a retained terminal or final-pass failure", call. = FALSE)
  }
  do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]
    data.frame(
      phi = phi, attempts = nrow(x), strict_successes = sum(strict[results$phi == phi]),
      mean_phi_absolute_error = mean(x$phi_absolute_error),
      median_phi_absolute_error = stats::median(x$phi_absolute_error),
      median_temporal_1_relative_error = stats::median(x$temporal_relative_error_1),
      median_temporal_2_relative_error = stats::median(x$temporal_relative_error_2),
      median_temporal_3_relative_error = stats::median(x$temporal_relative_error_3),
      median_kernel_1_relative_error = stats::median(x$kernel_relative_error_1),
      median_kernel_2_relative_error = stats::median(x$kernel_relative_error_2),
      median_kernel_3_relative_error = stats::median(x$kernel_relative_error_3),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error),
      stringsAsFactors = FALSE
    )
  }))
}

.temporal_program_validate_kernel_summary <- function(results, summary) {
  recomputed <- .temporal_program_kernel_summary(results)
  required <- names(recomputed)
  if (!all(required %in% names(summary)) || nrow(summary) != nrow(recomputed) ||
      !setequal(summary$phi, recomputed$phi)) {
    stop("temporal-kernel recovery summary has an invalid schema or phi labels", call. = FALSE)
  }
  summary <- summary[match(recomputed$phi, summary$phi), required, drop = FALSE]
  for (nm in setdiff(required, "phi")) {
    if (any(!is.finite(summary[[nm]])) ||
        !isTRUE(all.equal(summary[[nm]], recomputed[[nm]], tolerance = 1e-10))) {
      stop("temporal-kernel recovery summary is stale or disagrees with retained attempts: ", nm,
        call. = FALSE)
    }
  }
  invisible(recomputed)
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
  synthetic <- expand.grid(phi = c(-.4, 0, .6), seed = 2609151:2609153)
  synthetic$terminal <- "success"; synthetic$convergence <- 0L
  synthetic$pass_2_convergence <- 0L; synthetic$pass_2_accepted <- TRUE
  synthetic$max_gradient <- 0
  for (nm in c("temporal_relative_error_1", "temporal_relative_error_2",
               "temporal_relative_error_3", "kernel_relative_error_1",
               "kernel_relative_error_2", "kernel_relative_error_3",
               "phi_absolute_error", "fixed_effect_mean_absolute_error")) {
    synthetic[[nm]] <- .1
  }
  synthetic_summary <- .temporal_program_kernel_summary(synthetic)
  .temporal_program_validate_kernel_summary(synthetic, synthetic_summary)
  stale_summary <- synthetic_summary
  stale_summary$mean_phi_absolute_error[[1L]] <- .2
  .temporal_program_expect_reject(
    .temporal_program_validate_kernel_summary(synthetic, stale_summary),
    "a stale kernel-recovery summary"
  )
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
  ## Do not let the previously green kernel-only receipt stand in for every
  ## public source pair. The phylogenetic fixture is intentionally a separate
  ## retained campaign and this runner remains fail-closed until it has a
  ## complete 30-attempt receipt plus a source-specific recomputation path.
  if (file.exists(file.path(root, "tests/testthat/test-temporal-program-phylo-replicated.R"))) {
    stop("temporal-phylo source pair is admitted but its retained recovery/verifier gate is incomplete; combinations cannot certify every admitted pair", call. = FALSE)
  }
  fixture <- "tests/testthat/test-temporal-program-kernel-replicated.R"
  result_path <- "dev/temporal-program/results/kernel-recovery-20260909.csv"
  summary_path <- "dev/temporal-program/results/kernel-recovery-summary-20260909.csv"
  required_paths <- c(fixture, result_path, summary_path)
  if (any(!file.exists(file.path(root, required_paths)))) {
    stop("missing temporal-kernel evidence: ",
      paste(required_paths[!file.exists(file.path(root, required_paths))], collapse = ", "),
      call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  need_results <- c(
    "phi", "seed", "terminal", "convergence", "pass_1_convergence",
    "pass_2_convergence", "pass_2_accepted", "max_gradient",
    "temporal_relative_error_1", "temporal_relative_error_2",
    "temporal_relative_error_3", "kernel_relative_error_1",
    "kernel_relative_error_2", "kernel_relative_error_3",
    "phi_absolute_error", "fixed_effect_mean_absolute_error"
  )
  need_summary <- c(
    "phi", "attempts", "strict_successes", "mean_phi_absolute_error",
    "median_phi_absolute_error", "median_temporal_1_relative_error",
    "median_temporal_2_relative_error", "median_temporal_3_relative_error",
    "median_kernel_1_relative_error", "median_kernel_2_relative_error",
    "median_kernel_3_relative_error", "mean_fixed_effect_error", "passes"
  )
  if (!all(need_results %in% names(results)) || !all(need_summary %in% names(summary))) {
    stop("temporal-kernel evidence schema is incomplete", call. = FALSE)
  }
  expected_phi <- c(-.4, 0, .6)
  expected_seed <- 2609151:2609153
  if (nrow(results) != 9L || nrow(summary) != 3L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("temporal-kernel recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  if (!all(strict) || !all(summary$attempts == 3L) ||
      !all(summary$strict_successes == 3L) || !all(summary$passes)) {
    stop("temporal-kernel recovery has a retained terminal or final-pass failure", call. = FALSE)
  }
  recomputed_summary <- .temporal_program_validate_kernel_summary(results, summary)
  threshold_columns <- c(
    mean_phi_absolute_error = .15,
    median_phi_absolute_error = .20,
    median_temporal_1_relative_error = .35,
    median_temporal_2_relative_error = .35,
    median_temporal_3_relative_error = .35,
    median_kernel_1_relative_error = .35,
    median_kernel_2_relative_error = .35,
    median_kernel_3_relative_error = .35,
    mean_fixed_effect_error = .25
  )
  if (any(!is.finite(as.matrix(recomputed_summary[names(threshold_columns)]))) ||
      any(vapply(names(threshold_columns), function(nm) {
        any(recomputed_summary[[nm]] > threshold_columns[[nm]])
      }, logical(1)))) {
    stop("temporal-kernel recovery exceeds a frozen summary threshold", call. = FALSE)
  }
  cat("TEMPORAL_PROGRAM_COMBINATIONS_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "closeout")) {
  stop("Closeout requires a retained three-OS publication receipt and completion of the remaining temporal source-pair programme gates.", call. = FALSE)
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
