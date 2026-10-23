## Serial collector for the retained local phylogenetic recovery fixture.
## The direct DGP and fitting code are shared with the one-row DRAC task.
root <- normalizePath(".", mustWork = TRUE)
sys.source(file.path(root, "dev/temporal-program/remote/phylo-recovery-common.R"), envir = globalenv())

plan <- expand.grid(phi = c(-.4, 0, .6), seed = 2609181:2609190)
plan <- plan[order(plan$phi, plan$seed), , drop = FALSE]
is_smoke <- identical(Sys.getenv("TEMPORAL_RECOVERY_SMOKE"), "1")
if (is_smoke) plan <- data.frame(phi = .6, seed = 2609180L)
result_path <- if (is_smoke) tempfile("temporal-phylo-smoke-", fileext = ".csv") else
  file.path(root, "dev/temporal-program/results/phylo-recovery-160-20260909.csv")
## Checkpoint each retained attempt. A stopped process can therefore resume the
## exact frozen plan without discarding already completed seed--phi cells.
result <- if (file.exists(result_path)) utils::read.csv(result_path, check.names = FALSE) else NULL
if (!is.null(result) && !"error_message" %in% names(result)) {
  result$error_message <- NA_character_
}
if (!is.null(result) && anyDuplicated(result[c("phi", "seed")])) {
  stop("Phylogenetic recovery checkpoint has duplicate phi--seed attempts.", call. = FALSE)
}
if (!is.null(result) && any(!paste(result$phi, result$seed) %in%
    paste(plan$phi, plan$seed))) {
  stop("Phylogenetic recovery checkpoint contains attempts outside the frozen plan.", call. = FALSE)
}
for (i in seq_len(nrow(plan))) {
  phi_i <- plan$phi[[i]]; seed_i <- plan$seed[[i]]
  already_done <- !is.null(result) && any(result$phi == phi_i & result$seed == seed_i)
  if (already_done) next
  attempt <- fit_one(phi_i, seed_i)
  result <- if (is.null(result)) attempt else rbind(result, attempt)
  result <- result[order(result$phi, result$seed), , drop = FALSE]
  utils::write.csv(result, result_path, row.names = FALSE)
  cat(sprintf("CHECKPOINT phi=%s seed=%s elapsed=%.3f\\n", phi_i, seed_i, attempt$elapsed_seconds[[1L]]))
  flush.console()
  gc(verbose = FALSE)
}
if (nrow(result) == 1L) {
  print(result, row.names = FALSE); cat("TEMPORAL_PHYLO_RECOVERY_SMOKE_PASS\n")
  quit(save = "no", status = if (identical(result$terminal, "success")) 0L else 1L)
}
for (j in 1:3) {
  result[[paste0("temporal_relative_error_", j)]] <- abs(result[[paste0("temporal_", j)]] - truth$temporal[j]) / truth$temporal[j]
  result[[paste0("phylo_relative_error_", j)]] <- abs(result[[paste0("phylo_", j)]] - truth$phylo[j]) / truth$phylo[j]
}
result$phi_absolute_error <- abs(result$phi_estimate - result$phi)
result$fixed_effect_mean_absolute_error <- vapply(seq_len(nrow(result)), function(i) mean(abs(as.numeric(result[i, paste0("beta_", 1:3)]) - truth$beta)), numeric(1))
summary <- do.call(rbind, lapply(split(result, result$phi), function(x) {
  ok <- x$terminal == "success" & x$convergence == 0L & x$pass_2_convergence == 0L & x$pass_2_accepted &
    is.finite(x$max_gradient) & x$max_gradient <= 1e-3
  data.frame(phi = x$phi[[1L]], attempts = nrow(x), strict_successes = sum(ok),
    mean_phi_absolute_error = mean(x$phi_absolute_error[ok]), median_phi_absolute_error = median(x$phi_absolute_error[ok]),
    median_temporal_1_relative_error = median(x$temporal_relative_error_1[ok]), median_temporal_2_relative_error = median(x$temporal_relative_error_2[ok]), median_temporal_3_relative_error = median(x$temporal_relative_error_3[ok]),
    median_phylo_1_relative_error = median(x$phylo_relative_error_1[ok]), median_phylo_2_relative_error = median(x$phylo_relative_error_2[ok]), median_phylo_3_relative_error = median(x$phylo_relative_error_3[ok]),
    mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[ok]), stringsAsFactors = FALSE)
}))
summary$passes <- with(summary, strict_successes == 10L & mean_phi_absolute_error <= .15 & median_phi_absolute_error <= .20 &
  median_temporal_1_relative_error <= .35 & median_temporal_2_relative_error <= .35 & median_temporal_3_relative_error <= .35 &
  median_phylo_1_relative_error <= .35 & median_phylo_2_relative_error <= .35 & median_phylo_3_relative_error <= .35 & mean_fixed_effect_error <= .25)
write.csv(result, result_path, row.names = FALSE)
write.csv(summary, file.path(root, "dev/temporal-program/results/phylo-recovery-160-summary-20260909.csv"), row.names = FALSE)
print(result, row.names = FALSE); print(summary, row.names = FALSE)
if (!all(summary$passes)) stop("Frozen 160-series phylogenetic recovery campaign fails its predeclared thresholds.", call. = FALSE)
cat("TEMPORAL_PHYLO_RECOVERY_PASS\n")
