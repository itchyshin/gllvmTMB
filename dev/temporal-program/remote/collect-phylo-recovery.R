## Combine one-row DRAC receipts only after every frozen task is present.
## It never overwrites the retained local checkpoint.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name) {
  hit <- grep(paste0("^", name, "="), args, value = TRUE)
  if (length(hit) != 1L) return(NULL)
  sub(paste0("^", name, "", "="), "", hit)
}
root <- normalizePath(".", mustWork = TRUE)
attempt_dir <- arg_value("--attempt-dir")
output_dir <- arg_value("--output-dir")
if (is.null(attempt_dir) || is.null(output_dir) || !nzchar(attempt_dir) || !nzchar(output_dir)) {
  stop("usage: Rscript --vanilla collect-phylo-recovery.R --attempt-dir=PATH --output-dir=PATH", call. = FALSE)
}
attempt_dir <- normalizePath(attempt_dir, mustWork = TRUE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, mustWork = TRUE)
base <- utils::read.csv(file.path(root, "dev/temporal-program/results/phylo-recovery-160-20260909.csv"), check.names = FALSE)
if (!"error_message" %in% names(base)) base$error_message <- NA_character_
tasks <- utils::read.csv(file.path(root, "dev/temporal-program/results/phylo-recovery-160-tasks-20260909.csv"), check.names = FALSE)
expected_files <- file.path(attempt_dir, sprintf("phylo-recovery-attempt-%02d.csv", tasks$task_id))
if (any(!file.exists(expected_files))) {
  stop("Missing DRAC task receipts: ", paste(basename(expected_files[!file.exists(expected_files)]), collapse = ", "), call. = FALSE)
}
attempts <- do.call(rbind, lapply(expected_files, function(path) utils::read.csv(path, check.names = FALSE)))
if (!all(c("phi", "seed", "terminal", "error_message") %in% names(attempts)) || nrow(attempts) != nrow(tasks) ||
    !identical(attempts[c("phi", "seed")], tasks[c("phi", "seed")])) {
  stop("DRAC task receipts are not a complete ordered copy of the frozen task manifest.", call. = FALSE)
}
result <- rbind(base, attempts)
full <- expand.grid(phi = c(-.4, 0, .6), seed = 2609181:2609190)
full <- full[order(full$phi, full$seed), , drop = FALSE]
result <- result[order(result$phi, result$seed), , drop = FALSE]
if (anyDuplicated(result[c("phi", "seed")]) || nrow(result) != nrow(full) ||
    !identical(result[c("phi", "seed")], full)) {
  stop("Combined recovery receipt does not retain each frozen phi--seed cell exactly once.", call. = FALSE)
}
truth <- list(beta = c(.2, -.3, .1), temporal = c(.55, .42, .63)^2, phylo = c(.35, .28, .40)^2)
for (j in 1:3) {
  result[[paste0("temporal_relative_error_", j)]] <- abs(result[[paste0("temporal_", j)]] - truth$temporal[[j]]) / truth$temporal[[j]]
  result[[paste0("phylo_relative_error_", j)]] <- abs(result[[paste0("phylo_", j)]] - truth$phylo[[j]]) / truth$phylo[[j]]
}
result$phi_absolute_error <- abs(result$phi_estimate - result$phi)
result$fixed_effect_mean_absolute_error <- vapply(seq_len(nrow(result)), function(i) {
  mean(abs(as.numeric(result[i, paste0("beta_", 1:3)]) - truth$beta))
}, numeric(1))
summary <- do.call(rbind, lapply(split(result, result$phi), function(x) {
  ok <- x$terminal == "success" & x$convergence == 0L & x$pass_2_convergence == 0L &
    x$pass_2_accepted & is.finite(x$max_gradient) & x$max_gradient <= 1e-3
  data.frame(phi = x$phi[[1L]], attempts = nrow(x), strict_successes = sum(ok),
    mean_phi_absolute_error = mean(x$phi_absolute_error[ok]), median_phi_absolute_error = median(x$phi_absolute_error[ok]),
    median_temporal_1_relative_error = median(x$temporal_relative_error_1[ok]), median_temporal_2_relative_error = median(x$temporal_relative_error_2[ok]), median_temporal_3_relative_error = median(x$temporal_relative_error_3[ok]),
    median_phylo_1_relative_error = median(x$phylo_relative_error_1[ok]), median_phylo_2_relative_error = median(x$phylo_relative_error_2[ok]), median_phylo_3_relative_error = median(x$phylo_relative_error_3[ok]),
    mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[ok]), stringsAsFactors = FALSE)
}))
summary$passes <- with(summary, strict_successes == 10L & mean_phi_absolute_error <= .15 & median_phi_absolute_error <= .20 &
  median_temporal_1_relative_error <= .35 & median_temporal_2_relative_error <= .35 & median_temporal_3_relative_error <= .35 &
  median_phylo_1_relative_error <= .35 & median_phylo_2_relative_error <= .35 & median_phylo_3_relative_error <= .35 & mean_fixed_effect_error <= .25)
utils::write.csv(result, file.path(output_dir, "phylo-recovery-160-20260909.csv"), row.names = FALSE)
utils::write.csv(summary, file.path(output_dir, "phylo-recovery-160-summary-20260909.csv"), row.names = FALSE)
print(summary, row.names = FALSE)
if (!all(summary$passes)) stop("Frozen phylogenetic recovery campaign fails its predeclared thresholds.", call. = FALSE)
cat("TEMPORAL_PHYLO_COLLECTION_PASS\n")
