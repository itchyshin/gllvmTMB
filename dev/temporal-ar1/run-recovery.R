#!/usr/bin/env Rscript

## Retained bounded recovery fixture.  All 18 fixed-seed results are written,
## including failures, before the cell-level smoke criteria are evaluated.
source("dev/temporal-ar1/recovery.R")
devtools::load_all(".", quiet = TRUE)
recovery_control <- gllvmTMBcontrol(
  optimizer = "optim",
  optArgs = list(method = "BFGS", control = list(maxit = 10000, reltol = 1e-12))
)

rows <- list()
k <- 0L
independent_error_columns <- paste0("independent_relative_error_trait_", 1:3)
for (workflow in c("unreplicated", "replicated")) {
  for (phi in c(-0.4, 0, 0.6)) for (seed in 2609081:2609083) {
    k <- k + 1L
    started <- proc.time()[["elapsed"]]
    result <- tryCatch(.temporal_recovery_fit(workflow, seed, phi, recovery_control), error = identity)
    elapsed <- proc.time()[["elapsed"]] - started
    if (inherits(result, "error")) {
      row <- data.frame(workflow, phi_truth = phi, seed, elapsed_seconds = elapsed,
        convergence = NA_integer_, max_gradient = NA_real_, phi_estimate = NA_real_,
        phi_abs_error = NA_real_, loading_frobenius_error = NA_real_,
        independent_max_relative_error = NA_real_, fixed_effect_mean_abs_error = NA_real_,
        pd_hessian = NA, phi_boundary = NA, error = conditionMessage(result), stringsAsFactors = FALSE)
      row[independent_error_columns] <- as.list(rep(NA_real_, length(independent_error_columns)))
      rows[[k]] <- row
      next
    }
    fit <- result$fit
    par <- fit$tmb_obj$env$parList(fit$opt$par)
    variance <- extract_temporal(fit)$variance
    independent <- variance$value[variance$component %in% c("iid_total_variance", "occasion_variance")]
    lambda <- as.matrix(fit$report$Lambda_B)
    lambda_truth <- tcrossprod(result$truth$loading)
    lambda_error <- norm(tcrossprod(lambda) - lambda_truth, "F") / norm(lambda_truth, "F")
    independent_error <- abs(independent - result$truth$independent) / result$truth$independent
    b_fix <- as.numeric(par$b_fix)
    k <- k + 0L
    row <- data.frame(
      workflow, phi_truth = phi, seed, elapsed_seconds = elapsed,
      convergence = fit$opt$convergence,
      max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))),
      phi_estimate = as.numeric(fit$report$phi),
      phi_abs_error = abs(as.numeric(fit$report$phi) - phi),
      loading_frobenius_error = lambda_error,
      independent_max_relative_error = max(independent_error),
      fixed_effect_mean_abs_error = mean(abs(b_fix - result$truth$intercept)),
      pd_hessian = isTRUE(fit$sd_report$pdHess),
      phi_boundary = abs(as.numeric(fit$report$phi)) > .99,
      error = "", stringsAsFactors = FALSE
    )
    if (length(independent_error) != length(independent_error_columns)) {
      stop("Recovery fit did not return the required three independent-variance estimates.", call. = FALSE)
    }
    row[independent_error_columns] <- as.list(as.numeric(independent_error))
    rows[[k]] <- row
  }
}
out <- do.call(rbind, rows)
write.csv(out, "dev/temporal-ar1/recovery-results-bfgs.csv", row.names = FALSE)
print(out)

cell <- split(out, interaction(out$workflow, out$phi_truth, drop = TRUE))
cell_summary <- do.call(rbind, lapply(cell, function(x) {
  finite <- all(is.finite(x$phi_estimate))
  convergence <- all(x$convergence == 0L)
  gradient <- all(x$max_gradient <= 1e-3)
  phi_mean <- mean(x$phi_abs_error)
  phi_median <- median(x$phi_abs_error)
  loading_median <- median(x$loading_frobenius_error)
  any_phi_boundary <- any(x$phi_boundary)
  ## The accepted criterion is per identifiable variance: take its median
  ## over the three retained seeds, then require every variance to pass. The
  ## median of a per-seed maximum is retained below only as a diagnostic; it
  ## is a different, stricter quantity and must not decide this gate.
  independent_median <- vapply(independent_error_columns, function(column) {
    median(x[[column]])
  }, numeric(1L))
  fixed_mean <- mean(x$fixed_effect_mean_abs_error)
  criteria <- c(
    finite = finite,
    convergence = convergence,
    max_gradient = gradient,
    phi_mean = phi_mean <= .15,
    phi_median = phi_median <= .20,
    loading_median = loading_median <= .30,
    stats::setNames(independent_median <= .36,
      paste0("independent_median_trait_", seq_along(independent_median))),
    fixed_mean = fixed_mean <= .25
  )
  row <- data.frame(
    workflow = x$workflow[1L], phi_truth = x$phi_truth[1L],
    finite, convergence, gradient,
    any_phi_boundary,
    phi_mean_abs_error = phi_mean,
    phi_median_abs_error = phi_median,
    loading_median_frobenius_error = loading_median,
    independent_median_max_relative_error_diagnostic = median(x$independent_max_relative_error),
    fixed_effect_mean_abs_error = fixed_mean,
    pass = all(criteria),
    failed_criteria = paste(names(criteria)[!criteria], collapse = ";"),
    stringsAsFactors = FALSE
  )
  row[paste0("independent_median_relative_error_trait_", seq_along(independent_median))] <-
    as.list(independent_median)
  row
}))
write.csv(cell_summary, "dev/temporal-ar1/recovery-cell-summary.csv", row.names = FALSE)
pass <- cell_summary$pass
cat(sprintf("TEMPORAL_RECOVERY_%s\n", if (all(pass)) "PASS" else "FAIL"))
if (!all(pass)) quit(status = 1L)
