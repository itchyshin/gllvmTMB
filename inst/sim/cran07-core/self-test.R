#!/usr/bin/env Rscript
# Tests-of-tests for the v2 detector/truth separation. No model is fitted.
script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
script_dir <- dirname(normalizePath(script_arg, mustWork = TRUE))
repo <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
source(file.path(script_dir, "schema.R"), local = .GlobalEnv)
source(file.path(script_dir, "campaign.R"), local = .GlobalEnv)
source(file.path(script_dir, "batch.R"), local = .GlobalEnv)

make_row <- function(status, detector, catastrophic, boundary = FALSE) {
  data.frame(
    campaign_id = "self-test", registry_sha256 = paste(rep("a", 64), collapse = ""),
    cell_id = "cell", replicate = if (catastrophic) 2L else 1L,
    seed = if (catastrophic) 2L else 1L, status = status, constructed = TRUE,
    optimizer_converged = TRUE, stationary = TRUE, pd_hessian = TRUE,
    finite_estimands = TRUE, boundary = boundary, geometry_flag = FALSE,
    detector_flagged = detector, catastrophic_truth_error = catastrophic,
    relative_covariance_error = if (catastrophic) 3 else 0.1,
    max_eigen_ratio = if (catastrophic) 11 else 1,
    family = "gaussian", n_trials_min = NA_integer_, n_trials_max = NA_integer_,
    diag_B_skip = "", diag_B_all_free = NA,
    error_class = "", error_message = "", elapsed_seconds = 0,
    stringsAsFactors = FALSE
  )
}

# A catastrophic truth error is deliberately allowed to have usable observable
# status. If schema validation ever couples them again, this acceptance test fails.
catastrophic_but_healthy <- make_row("usable", FALSE, TRUE)
cran07_validate_attempt_table(catastrophic_but_healthy)

# The observable rejection half remains active independently of planted truth.
observable_boundary <- make_row("boundary", TRUE, FALSE, boundary = TRUE)
observable_boundary$replicate <- 1L
cran07_validate_attempt_table(observable_boundary)

both <- rbind(observable_boundary, catastrophic_but_healthy)
tab <- cran07_detector_2x2(both, by_cell = FALSE)
stopifnot(nrow(tab) == 4L,
          tab$n[!tab$detector_flagged & tab$catastrophic_truth_error] == 1L,
          tab$n[tab$detector_flagged & !tab$catastrophic_truth_error] == 1L)

bad <- catastrophic_but_healthy
bad$detector_flagged <- TRUE
stopifnot(inherits(try(cran07_validate_attempt_table(bad), silent = TRUE), "try-error"))

# Exact campaign identity, canonical path, and compiled hash are inseparable.
for (id in CRAN07_CAMPAIGNS$campaign_id) {
  registry <- cran07_read_campaign_registry(id, repo)
  spec <- cran07_campaign_spec(id)
  stopifnot(identical(attr(registry, "sha256"), spec$registry_sha256),
            identical(attr(registry, "campaign_id"), id))
}
core_id <- "cran07-core-recovery-v2"
silent_path <- file.path(repo, CRAN07_CAMPAIGNS$registry_relpath[[2L]])
stopifnot(inherits(try(cran07_read_campaign_registry(core_id, repo, silent_path),
                      silent = TRUE), "try-error"),
          inherits(try(cran07_campaign_spec("cran07-core-recovery"), silent = TRUE),
                   "try-error"))
copied_registry <- tempfile(fileext = ".csv")
invisible(file.copy(file.path(repo, CRAN07_CAMPAIGNS$registry_relpath[[1L]]), copied_registry))
stopifnot(inherits(try(cran07_read_campaign_registry(core_id, repo, copied_registry),
                      silent = TRUE), "try-error"))
writeLines("drift", copied_registry)
stopifnot(inherits(try(cran07_read_registry(copied_registry, CRAN07_CORE_SHA256),
                      silent = TRUE), "try-error"))
runner_text <- readLines(file.path(script_dir, "run-batch.R"), warn = FALSE)
stopifnot(any(grepl('value\\("--campaign", "cran07-core-recovery-v2"\\)', runner_text)),
          any(grepl("--expected-sha is forbidden", runner_text, fixed = TRUE)))

# Gate numerators and denominators are explicit and threshold arithmetic is exact.
detector_fixture <- data.frame(
  cell_id = "cell",
  catastrophic_truth_error = c(rep(TRUE, 20L), rep(FALSE, 80L)),
  detector_flagged = c(rep(TRUE, 19L), FALSE, rep(TRUE, 8L), rep(FALSE, 72L)))
dm <- cran07_detector_metrics(detector_fixture)
stopifnot(dm$true_positive == 19L, dm$false_negative == 1L,
          dm$false_positive == 8L, dm$true_negative == 72L,
          dm$sensitivity_denominator == 20L, dm$specificity_denominator == 80L,
          identical(dm$sensitivity, 0.95), identical(dm$specificity, 0.90),
          cran07_exact_binomial_upper(0L, 400L) < 0.02)
attempt_fixture <- data.frame(
  cell_id = "cell", status = c(rep("usable", 95L), rep("boundary", 5L)),
  stationary = TRUE, optimizer_converged = TRUE,
  pd_hessian = c(rep(TRUE, 90L), rep(FALSE, 10L)))
ad <- cran07_attempt_denominators(attempt_fixture)
stopifnot(ad$n_attempts == 100L, ad$n_stationary_usable == 95L,
          ad$stationary_usable_rate == 0.95, ad$n_pd_hessian == 90L,
          ad$pd_hessian_rate == 0.90)
constant_group <- data.frame(cell_id = "cell", estimand = "beta", component = "b",
                             estimate = c(1, 1), truth = c(0, 0), error = c(1, 1))
constant_summary <- cran07_estimand_group_summary(constant_group, 2L)
stopifnot(constant_summary$zero_sd, is.infinite(constant_summary$standardized_abs_bias),
          constant_summary$n_estimates == 2L, constant_summary$n_attempts == 2L)

cat("catastrophic_but_healthy=accepted observable_boundary=flagged coupled_schema=rejected detector_2x2=OK campaign_map=OK mismatch_rejected=OK drift_rejected=OK gate_denominators=OK zero_sd_fail_closed=OK\n")
