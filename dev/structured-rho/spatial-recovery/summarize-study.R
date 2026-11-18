# ADEMP summaries with all-attempt denominators and conditional recovery metrics.
args <- commandArgs(TRUE)
root <- normalizePath(args[[1L]])
out <- args[[2L]]
if (dir.exists(out)) stop("Refusing to overwrite spatial recovery summaries")
dir.create(out, recursive = TRUE)
fixture_dir <- file.path(root, "dev/structured-rho/spatial-recovery/fixtures")
jobs <- read.csv(file.path(fixture_dir, "jobs.csv"), stringsAsFactors = FALSE)
receipts <- list.files(file.path(root, "results"), pattern = "^receipt.json$",
                       recursive = TRUE, full.names = TRUE)
records <- list(); k <- 0L
for (path in receipts) {
  receipt <- jsonlite::read_json(path, simplifyVector = TRUE)
  if (is.null(receipt$job$attempt_id) ||
      !startsWith(receipt$job$attempt_id, "spatial-retained-")) next
  job <- jobs[jobs$attempt_id == receipt$job$attempt_id, , drop = FALSE]
  stopifnot(nrow(job) == 1L)
  result_path <- file.path(dirname(path), "result.rds")
  result <- if (file.exists(result_path)) readRDS(result_path) else list()
  take <- function(name, default = NA_real_)
    if (length(result[[name]]) == 1L) result[[name]] else default
  success <- identical(receipt$exit_status, 0L) &&
    isTRUE(take("numerical_success", FALSE)) &&
    identical(as.integer(take("optimizer_entries")), 1L)
  k <- k + 1L
  records[[k]] <- data.frame(
    job, wrapper_status = receipt$status, wrapper_exit = receipt$exit_status,
    returned = identical(take("status", "missing"), "returned"),
    numerical_success = success, rho_hat = take("rho"),
    kappa_hat = take("kappa"), kappa_truth = take("kappa_truth"),
    kappa_relative_error = take("kappa_relative_error"),
    boundary = take("boundary", NA),
    source_covariance_relative_error = take("source_covariance_relative_error"),
    total_covariance_relative_error = take("total_covariance_relative_error"),
    max_gradient = take("max_gradient"), convergence = take("convergence"),
    pd_hessian = take("pd_hessian", NA), objective = take("objective"),
    optimizer_entries = take("optimizer_entries"),
    elapsed_seconds = receipt$elapsed_seconds,
    peak_rss_kib = if (length(receipt$peak_rss_kib)) receipt$peak_rss_kib else NA_real_,
    error = take("error", ""), warnings = paste(result$warnings, collapse = " | "),
    evidence = dirname(path)
  )
}
if (!length(records)) stop("No retained spatial attempt receipts")
attempts <- do.call(rbind, records)
stopifnot(!anyDuplicated(attempts$attempt_id), nrow(attempts) <= 1600L)
write.csv(attempts, file.path(out, "attempts.csv"), row.names = FALSE)

mean_mcse <- function(x) {
  x <- x[is.finite(x)]
  c(mean = if (length(x)) mean(x) else NA_real_,
    mcse = if (length(x) > 1L) sd(x) / sqrt(length(x)) else NA_real_)
}
rmse_mcse <- function(x) {
  x <- x[is.finite(x)]
  value <- if (length(x)) sqrt(mean(x^2)) else NA_real_
  mcse <- if (length(x) > 1L && is.finite(value) && value > 0)
    sd(x^2) / (2 * value * sqrt(length(x))) else NA_real_
  c(value = value, mcse = mcse)
}
wilson <- function(events, n) {
  if (!n) return(c(low = NA_real_, high = NA_real_))
  z <- qnorm(.975); p <- events / n; den <- 1 + z^2 / n
  centre <- (p + z^2 / (2*n)) / den
  half <- z * sqrt(p*(1-p)/n + z^2/(4*n^2)) / den
  c(low = max(0, centre-half), high = min(1, centre+half))
}

cells <- unique(jobs[c("regime", "mode", "rho", "method")])
summaries <- list()
for (i in seq_len(nrow(cells))) {
  cell <- cells[i, , drop = FALSE]
  a <- subset(attempts, regime == cell$regime & mode == cell$mode &
                        rho == cell$rho & method == cell$method)
  good <- a[a$numerical_success, , drop = FALSE]
  n <- nrow(a); ng <- nrow(good)
  rho_error <- if (cell$method == "estimated") good$rho_hat - cell$rho else numeric()
  rho_bias <- mean_mcse(rho_error); rho_rmse <- rmse_mcse(rho_error)
  kappa_bias <- mean_mcse(good$kappa_relative_error)
  kappa_rmse <- rmse_mcse(good$kappa_relative_error)
  separation_correlation <- if (cell$method == "estimated" && ng >= 3L &&
    sd(good$rho_hat - cell$rho) > 0 && sd(log(good$kappa_hat / good$kappa_truth)) > 0)
      cor(good$rho_hat - cell$rho, log(good$kappa_hat / good$kappa_truth)) else NA_real_
  boundary <- wilson(sum(good$boundary, na.rm = TRUE), ng)
  failure <- wilson(n-ng, n)
  optimizer_failures <- sum(a$returned &
    (!is.finite(a$convergence) | a$convergence != 0))
  hessian_failures <- sum(a$returned &
    (is.na(a$pd_hessian) | !a$pd_hessian))
  gradient_failures <- sum(a$returned &
    (!is.finite(a$max_gradient) | a$max_gradient > .01))
  timeouts <- sum(a$wrapper_status == "timeout")
  process_failures <- sum(!a$returned & a$wrapper_status != "timeout")
  optimizer_entry_violations <- sum(is.finite(a$optimizer_entries) & a$optimizer_entries != 1)
  summaries[[i]] <- data.frame(
    cell, n_planned = 50L, n_attempted = n, n_returned = sum(a$returned),
    n_success = ng, success_frequency = if (n) ng/n else NA_real_,
    failure_mc_low = failure[["low"]], failure_mc_high = failure[["high"]],
    rho_bias = rho_bias[["mean"]], rho_bias_mcse = rho_bias[["mcse"]],
    rho_rmse = rho_rmse[["value"]], rho_rmse_mcse = rho_rmse[["mcse"]],
    kappa_relative_bias = kappa_bias[["mean"]],
    kappa_relative_bias_mcse = kappa_bias[["mcse"]],
    kappa_relative_rmse = kappa_rmse[["value"]],
    kappa_relative_rmse_mcse = kappa_rmse[["mcse"]],
    rho_logkappa_error_correlation = separation_correlation,
    boundary_frequency = if (ng) sum(good$boundary, na.rm=TRUE)/ng else NA_real_,
    boundary_mc_low = boundary[["low"]], boundary_mc_high = boundary[["high"]],
    source_covariance_error_mean = mean(good$source_covariance_relative_error, na.rm=TRUE),
    total_covariance_error_mean = mean(good$total_covariance_relative_error, na.rm=TRUE),
    total_covariance_error_median = median(good$total_covariance_relative_error, na.rm=TRUE),
    optimizer_failures = optimizer_failures,
    hessian_failures = hessian_failures,
    gradient_failures = gradient_failures,
    timeouts = timeouts,
    process_or_fit_errors = process_failures,
    optimizer_entry_violations = optimizer_entry_violations,
    runtime_mean = mean(a$elapsed_seconds, na.rm=TRUE),
    peak_rss_kib = max(a$peak_rss_kib, na.rm=TRUE)
  )
}
cells_out <- do.call(rbind, summaries)
cells_out$total_covariance_fixed_median <- NA_real_
cells_out$verdict <- ifelse(cells_out$n_attempted < 50L, "pending", NA_character_)
for (i in which(cells_out$method == "estimated" & cells_out$n_attempted == 50L)) {
  fixed <- subset(cells_out, regime == cells_out$regime[i] & mode == cells_out$mode[i] &
                             rho == cells_out$rho[i] & method == "fixed")
  stopifnot(nrow(fixed) == 1L)
  cells_out$total_covariance_fixed_median[i] <- fixed$total_covariance_error_median
  pass <- cells_out$success_frequency[i] >= .8 &&
    abs(cells_out$rho_bias[i]) + 2*cells_out$rho_bias_mcse[i] <= .10 &&
    cells_out$rho_rmse[i] + 2*cells_out$rho_rmse_mcse[i] <= .20 &&
    abs(cells_out$kappa_relative_bias[i]) + 2*cells_out$kappa_relative_bias_mcse[i] <= .20 &&
    cells_out$kappa_relative_rmse[i] + 2*cells_out$kappa_relative_rmse_mcse[i] <= .35 &&
    cells_out$boundary_mc_high[i] <= .20 &&
    cells_out$total_covariance_error_median[i] <= fixed$total_covariance_error_median + .10
  blocked <- cells_out$success_frequency[i] < .6 ||
    isTRUE(cells_out$boundary_frequency[i] >= .5) ||
    (is.finite(cells_out$rho_logkappa_error_correlation[i]) &&
      abs(cells_out$rho_logkappa_error_correlation[i]) >= .80 &&
      (cells_out$rho_rmse[i] > .20 || cells_out$kappa_relative_rmse[i] > .35))
  cells_out$verdict[i] <- if (blocked) "blocked_pending_fisher" else
    if (pass) "pass_pending_fisher" else "partial_pending_fisher"
}
write.csv(cells_out, file.path(out, "cells.csv"), row.names = FALSE)
pairs <- merge(attempts[attempts$method == "fixed", ],
               attempts[attempts$method == "estimated", ],
               by = "dataset_id", suffixes = c("_fixed", "_estimated"))
write.csv(pairs, file.path(out, "paired-diagnostics.csv"), row.names = FALSE)
writeLines(c(
  "All failure frequencies use all attempted jobs in each cell.",
  "Recovery and boundary summaries are conditional on the immutable numerical-success rule.",
  "Fixed-at-truth fits are diagnostic benchmarks, not estimators.",
  "MCSE and Wilson limits describe simulation precision, not fitted-rho confidence intervals.",
  "Pilot cells remain pending because one dataset cannot earn a recovery verdict."
), file.path(out, "README.txt"))
cat(sprintf("SPATIAL_RECOVERY_SUMMARY_%d_ATTEMPTS\n", nrow(attempts)))
