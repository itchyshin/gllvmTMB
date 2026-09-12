## Verify the retained negative recovery result for the narrow replicated OU
## temporal_indep() + kernel_indep() fixture.  This reads the direct-DGP
## receipts only; it neither simulates data nor fits the production model.
root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run the retained OU-kernel verifier from the repository root.", call. = FALSE)
}

receipt_dir <- Sys.getenv("OU_KERNEL_RETAINED_DIR", unset = file.path(
  root, "dev", "temporal-program", "results", "failed", "ou-kernel-recovery-20260912"
))
receipt_dir <- normalizePath(receipt_dir, mustWork = FALSE)
if (!dir.exists(receipt_dir)) {
  stop("Missing retained OU-kernel receipt directory: ", receipt_dir, call. = FALSE)
}

plan <- expand.grid(rate = c(.25, .70, 1.40), seed = 2609371:2609373)
plan <- plan[order(plan$rate, plan$seed), , drop = FALSE]
attempt_paths <- file.path(receipt_dir, paste0("attempt-", seq_len(nrow(plan))),
  sprintf("attempt-%02d.csv", seq_len(nrow(plan))))
plan_paths <- file.path(dirname(attempt_paths), "frozen-plan.csv")
combined_path <- file.path(receipt_dir, "ou-kernel-recovery-20260912.csv")
summary_path <- file.path(receipt_dir, "ou-kernel-recovery-summary-20260912.csv")
required <- c(attempt_paths, plan_paths, combined_path, summary_path)
if (any(!file.exists(required))) {
  stop("Missing retained OU-kernel receipt(s): ",
    paste(required[!file.exists(required)], collapse = ", "), call. = FALSE)
}

same_table <- function(x, y, tolerance = 1e-12) {
  isTRUE(all.equal(x, y, check.attributes = FALSE, tolerance = tolerance))
}
for (path in plan_paths) {
  frozen_plan <- utils::read.csv(path, check.names = FALSE)
  if (!same_table(frozen_plan, plan)) {
    stop("A retained OU-kernel attempt has a changed frozen plan: ", path, call. = FALSE)
  }
}

attempts <- do.call(rbind, lapply(attempt_paths, utils::read.csv, check.names = FALSE))
combined <- utils::read.csv(combined_path, check.names = FALSE)
if (!all(names(attempts) %in% names(combined)) ||
    !same_table(attempts, combined[, names(attempts), drop = FALSE])) {
  stop("The retained OU-kernel combined receipt disagrees with its nine attempts.", call. = FALSE)
}

required_columns <- c("rate", "seed", "terminal", "convergence", "pass_1_convergence",
  "pass_2_convergence", "pass_2_accepted", "max_gradient", "objective", "rate_estimate",
  paste0("temporal_relative_error_", 1:3), paste0("kernel_relative_error_", 1:3),
  "log_rate_absolute_error", "fixed_effect_mean_absolute_error")
if (!all(required_columns %in% names(combined)) || nrow(combined) != nrow(plan) ||
    !same_table(combined[c("rate", "seed")], plan)) {
  stop("The retained OU-kernel attempts have an invalid frozen identity or schema.", call. = FALSE)
}
strict <- combined$terminal == "success" & combined$convergence == 0L &
  combined$pass_1_convergence == 0L & combined$pass_2_convergence == 0L &
  combined$pass_2_accepted & is.finite(combined$objective) &
  is.finite(combined$max_gradient) & combined$max_gradient <= 1e-3
if (!all(strict)) {
  stop("The retained OU-kernel result contains a non-strict attempt.", call. = FALSE)
}

summary <- do.call(rbind, lapply(c(.25, .70, 1.40), function(rate) {
  x <- combined[combined$rate == rate, , drop = FALSE]
  data.frame(
    rate = rate, attempts = nrow(x), strict_successes = sum(strict[combined$rate == rate]),
    mean_log_rate_absolute_error = mean(x$log_rate_absolute_error),
    median_log_rate_absolute_error = stats::median(x$log_rate_absolute_error),
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
thresholds <- c(
  mean_log_rate_absolute_error = .35, median_log_rate_absolute_error = .45,
  median_temporal_1_relative_error = .35, median_temporal_2_relative_error = .35,
  median_temporal_3_relative_error = .35, median_kernel_1_relative_error = .35,
  median_kernel_2_relative_error = .35, median_kernel_3_relative_error = .35,
  mean_fixed_effect_error = .25
)
summary$passes <- summary$strict_successes == 3L & !vapply(seq_len(nrow(summary)), function(i) {
  any(vapply(names(thresholds), function(name) summary[[name]][[i]] > thresholds[[name]], logical(1)))
}, logical(1))
retained_summary <- utils::read.csv(summary_path, check.names = FALSE)
if (!same_table(retained_summary, summary)) {
  stop("The retained OU-kernel summary is stale or does not match the attempts.", call. = FALSE)
}
failure_fields <- lapply(seq_len(nrow(summary)), function(i) {
  names(thresholds)[vapply(names(thresholds), function(name) {
    summary[[name]][[i]] > thresholds[[name]]
  }, logical(1))]
})
if (!identical(as.logical(summary$passes), c(FALSE, TRUE, TRUE)) ||
    !identical(failure_fields, list("median_kernel_1_relative_error", character(), character()))) {
  stop("The retained OU-kernel failure is not the frozen rate-.25 kernel-1 variance failure.", call. = FALSE)
}

cat("TEMPORAL_OU_KERNEL_RETAINED_FAILURE_PASS\n")
