args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) == 1L) args[[1L]] else ""
root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run temporal programme verification from the repository root.", call. = FALSE)
}
allowed <- c("plan", "simulation", "lifecycle", "remote", "phylo", "publication", "combinations", "closeout", "self-test")
if (!mode %in% allowed) {
  stop("usage: Rscript --vanilla dev/temporal-program/verify.R {plan|simulation|lifecycle|remote|phylo|publication|combinations|closeout|self-test}", call. = FALSE)
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

.temporal_program_phylo_summary <- function(results) {
  expected_phi <- c(-.4, 0, .6)
  expected_seed <- 2609181:2609190
  required <- c(
    "phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "phi_estimate",
    paste0("temporal_", 1:3), paste0("phylo_", 1:3), paste0("beta_", 1:3)
  )
  if (!all(required %in% names(results)) || nrow(results) != 30L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("temporal-phylo recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  if (!all(strict)) {
    stop("temporal-phylo recovery has a retained terminal or final-pass failure", call. = FALSE)
  }
  truth <- list(beta = c(.2, -.3, .1), temporal = c(.55, .42, .63)^2,
    phylo = c(.35, .28, .40)^2)
  for (j in 1:3) {
    results[[paste0("temporal_relative_error_", j)]] <-
      abs(results[[paste0("temporal_", j)]] - truth$temporal[[j]]) / truth$temporal[[j]]
    results[[paste0("phylo_relative_error_", j)]] <-
      abs(results[[paste0("phylo_", j)]] - truth$phylo[[j]]) / truth$phylo[[j]]
  }
  results$phi_absolute_error <- abs(results$phi_estimate - results$phi)
  results$fixed_effect_mean_absolute_error <- vapply(seq_len(nrow(results)), function(i) {
    mean(abs(as.numeric(results[i, paste0("beta_", 1:3)]) - truth$beta))
  }, numeric(1))
  summary <- do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]
    data.frame(
      phi = phi, attempts = nrow(x), strict_successes = sum(strict[results$phi == phi]),
      mean_phi_absolute_error = mean(x$phi_absolute_error),
      median_phi_absolute_error = stats::median(x$phi_absolute_error),
      median_temporal_1_relative_error = stats::median(x$temporal_relative_error_1),
      median_temporal_2_relative_error = stats::median(x$temporal_relative_error_2),
      median_temporal_3_relative_error = stats::median(x$temporal_relative_error_3),
      median_phylo_1_relative_error = stats::median(x$phylo_relative_error_1),
      median_phylo_2_relative_error = stats::median(x$phylo_relative_error_2),
      median_phylo_3_relative_error = stats::median(x$phylo_relative_error_3),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error),
      stringsAsFactors = FALSE
    )
  }))
  summary$passes <- with(summary,
    strict_successes == 10L & mean_phi_absolute_error <= .15 &
      median_phi_absolute_error <= .20 &
      median_temporal_1_relative_error <= .35 & median_temporal_2_relative_error <= .35 &
      median_temporal_3_relative_error <= .35 & median_phylo_1_relative_error <= .35 &
      median_phylo_2_relative_error <= .35 & median_phylo_3_relative_error <= .35 &
      mean_fixed_effect_error <= .25)
  summary
}

.temporal_program_validate_phylo_summary <- function(results, summary) {
  recomputed <- .temporal_program_phylo_summary(results)
  required <- names(recomputed)
  if (!all(required %in% names(summary)) || nrow(summary) != nrow(recomputed) ||
      !setequal(summary$phi, recomputed$phi)) {
    stop("temporal-phylo recovery summary has an invalid schema or phi labels", call. = FALSE)
  }
  summary <- summary[match(recomputed$phi, summary$phi), required, drop = FALSE]
  for (nm in setdiff(required, "phi")) {
    if (any(is.na(summary[[nm]])) ||
        !isTRUE(all.equal(summary[[nm]], recomputed[[nm]], tolerance = 1e-10))) {
      stop("temporal-phylo recovery summary is stale or disagrees with retained attempts: ", nm,
        call. = FALSE)
    }
  }
  invisible(recomputed)
}

.temporal_program_verify_phylo <- function(root) {
  fixture <- "tests/testthat/test-temporal-program-phylo-replicated.R"
  result_path <- paste0(
    "dev/temporal-program/results/failed/",
    "phylo-recovery-160-fir-59096255-20260910/",
    "phylo-recovery-160-20260909.csv"
  )
  summary_path <- paste0(
    "dev/temporal-program/results/failed/",
    "phylo-recovery-160-fir-59096255-20260910/",
    "phylo-recovery-160-summary-20260909.csv"
  )
  required <- c(fixture, result_path, summary_path)
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing temporal-phylo evidence: ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  recomputed <- .temporal_program_validate_phylo_summary(results, summary)
  if (!all(recomputed$passes)) {
    stop("temporal-phylo recovery exceeds a frozen summary threshold", call. = FALSE)
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
  phylo_synthetic <- expand.grid(phi = c(-.4, 0, .6), seed = 2609181:2609190)
  phylo_synthetic$terminal <- "success"; phylo_synthetic$convergence <- 0L
  phylo_synthetic$pass_2_convergence <- 0L; phylo_synthetic$pass_2_accepted <- TRUE
  phylo_synthetic$max_gradient <- 0; phylo_synthetic$phi_estimate <- phylo_synthetic$phi
  for (j in 1:3) {
    phylo_synthetic[[paste0("temporal_", j)]] <- c(.55, .42, .63)[[j]]^2
    phylo_synthetic[[paste0("phylo_", j)]] <- c(.35, .28, .40)[[j]]^2
    phylo_synthetic[[paste0("beta_", j)]] <- c(.2, -.3, .1)[[j]]
  }
  phylo_summary <- .temporal_program_phylo_summary(phylo_synthetic)
  .temporal_program_validate_phylo_summary(phylo_synthetic, phylo_summary)
  .temporal_program_expect_reject(
    .temporal_program_phylo_summary(phylo_synthetic[-1L, , drop = FALSE]),
    "an incomplete phylogenetic recovery receipt"
  )
  stale_phylo_summary <- phylo_summary
  stale_phylo_summary$median_phylo_1_relative_error[[1L]] <- .1
  .temporal_program_expect_reject(
    .temporal_program_validate_phylo_summary(phylo_synthetic, stale_phylo_summary),
    "a stale phylogenetic-recovery summary"
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
if (identical(mode, "phylo")) {
  .temporal_program_verify_phylo(root)
  cat("TEMPORAL_PROGRAM_PHYLO_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "combinations")) {
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
  .temporal_program_verify_phylo(root)
  cat("TEMPORAL_PROGRAM_COMBINATIONS_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "closeout")) {
  stop("Closeout requires a retained three-OS publication receipt and completion of the remaining temporal source-pair programme gates.", call. = FALSE)
}
if (identical(mode, "remote")) {
  task <- "dev/temporal-program/remote/phylo-recovery-task.R"
  collector <- "dev/temporal-program/remote/collect-phylo-recovery.R"
  launcher <- "dev/temporal-program/remote/phylo-recovery-drac.sh"
  runtime <- "dev/temporal-program/remote/prepare-phylo-recovery-runtime.sh"
  required <- c(task, collector, launcher, runtime,
    "dev/temporal-program/remote/phylo-recovery-common.R",
    "dev/temporal-program/results/phylo-recovery-160-tasks-20260909.csv")
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing temporal phylogenetic remote artifact(s): ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  task_out <- system2("Rscript", c("--vanilla", task, "--mode=plan"), stdout = TRUE, stderr = TRUE)
  if (!identical(attr(task_out, "status"), NULL) || !any(grepl("TEMPORAL_PHYLO_TASK_PLAN_PASS tasks=22", task_out, fixed = TRUE))) {
    stop("phylogenetic DRAC task manifest does not verify.", call. = FALSE)
  }
  shell_status <- system2("bash", c("-n", launcher))
  runtime_status <- system2("bash", c("-n", runtime))
  if (!identical(shell_status, 0L) || !identical(runtime_status, 0L)) {
    stop("phylogenetic DRAC launcher or runtime-preflight script has invalid shell syntax.", call. = FALSE)
  }
  envelope_dir <- tempfile("temporal-phylo-drac-envelope-")
  launcher_out <- system2("bash", launcher,
    env = c(paste0("RESULTS_DIR=", envelope_dir), "SLURM_ACTION=write"), stdout = TRUE, stderr = TRUE)
  sbatch <- file.path(envelope_dir, "_slurm", "phylo-recovery-160.sbatch")
  manifest <- file.path(envelope_dir, "_slurm", "manifest.tsv")
  if (!identical(attr(launcher_out, "status"), NULL) ||
      !any(grepl("TEMPORAL_PHYLO_DRAC_WRITE_PASS", launcher_out, fixed = TRUE)) ||
      !file.exists(sbatch) || !file.exists(manifest)) {
    stop("phylogenetic DRAC launcher did not create a write-only envelope.", call. = FALSE)
  }
  manifest_data <- utils::read.delim(manifest, header = FALSE, sep = "\t", stringsAsFactors = FALSE)
  sbatch_text <- readLines(sbatch, warn = FALSE)
  if (nrow(manifest_data) != 7L || any(lengths(strsplit(readLines(manifest), "\t", fixed = TRUE)) != 2L) ||
      !all(c("#SBATCH --array=1-22%6", "#SBATCH --cpus-per-task=1", "export OPENBLAS_NUM_THREADS=1", "export GLLVMTMB_TEMPORAL_LOAD=\"pkgload\"") %in% sbatch_text)) {
    stop("phylogenetic DRAC envelope has an invalid manifest or task shape.", call. = FALSE)
  }
  denied_dir <- tempfile("temporal-phylo-drac-denied-")
  denied_out <- suppressWarnings(system2("bash", launcher,
    env = c(paste0("RESULTS_DIR=", denied_dir), "SLURM_ACTION=submit"), stdout = TRUE, stderr = TRUE))
  if (is.null(attr(denied_out, "status")) ||
      !any(grepl("Refusing submission without TEMPORAL_PHYLO_DRAC_APPROVED=YES", denied_out, fixed = TRUE))) {
    stop("phylogenetic DRAC launcher did not fence an unapproved submission.", call. = FALSE)
  }
  collector_out <- suppressWarnings(system2("Rscript", c("--vanilla", collector,
      paste0("--attempt-dir=", envelope_dir), paste0("--output-dir=", tempfile("temporal-phylo-collect-"))),
    stdout = TRUE, stderr = TRUE))
  if (is.null(attr(collector_out, "status")) ||
      !any(grepl("Missing DRAC task receipts", collector_out, fixed = TRUE))) {
    stop("phylogenetic collector did not reject an incomplete task set.", call. = FALSE)
  }
  retained_error_dir <- tempfile("temporal-phylo-retained-error-")
  retained_error_out <- suppressWarnings(system2("Rscript", c("--vanilla", task, "--mode=task",
      "--task-id=1", paste0("--results-dir=", retained_error_dir)),
    env = "GLLVMTMB_TEMPORAL_LOAD=invalid", stdout = TRUE, stderr = TRUE))
  retained_error_path <- file.path(retained_error_dir, "phylo-recovery-attempt-01.csv")
  if (!identical(attr(retained_error_out, "status"), NULL) || !file.exists(retained_error_path)) {
    stop("phylogenetic task did not retain a pre-fit package-load error receipt.", call. = FALSE)
  }
  retained_error <- utils::read.csv(retained_error_path, check.names = FALSE)
  if (nrow(retained_error) != 1L || !identical(retained_error$terminal[[1L]], "error") ||
      !grepl("GLLVMTMB_TEMPORAL_LOAD", retained_error$error_message[[1L]], fixed = TRUE)) {
    stop("phylogenetic task pre-fit package-load receipt is malformed.", call. = FALSE)
  }
  cat("TEMPORAL_PROGRAM_REMOTE_PASS\n")
  quit(save = "no", status = 0L)
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
