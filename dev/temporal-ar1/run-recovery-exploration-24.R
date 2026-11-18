#!/usr/bin/env Rscript

## Diagnostic-only companion to the fixed G4 fixture. It changes only the
## number of independent series from 12 to 24, retains the same DGP, seeds,
## workflows and phi values, and never supplies acceptance evidence.
source("dev/temporal-ar1/recovery.R")
devtools::load_all(".", quiet = TRUE)

fit_one <- function(workflow, seed, phi) {
  dat <- .temporal_recovery_data(workflow, seed = seed, phi = phi,
    n_series = 24L, n_time = 20L)
  formula <- if (identical(workflow, "replicated")) {
    value ~ 0 + trait + temporal_latent(0 + trait | series,
      time = occasion, replicate = measurement)
  } else {
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion)
  }
  started <- proc.time()[["elapsed"]]
  fit <- suppressWarnings(gllvmTMB(
    formula, data = dat, unit = "series", family = gaussian(),
    control = gllvmTMBcontrol(optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 10000, reltol = 1e-12))),
    silent = TRUE
  ))
  truth <- if (identical(workflow, "replicated")) c(.16, .09, .25) else c(.52, .45, .61)
  variance <- extract_temporal(fit)$variance
  estimate <- variance$value[variance$component %in% c("iid_total_variance", "occasion_variance")]
  row <- data.frame(
    workflow = workflow, phi_truth = phi, seed = seed, n_series = 24L,
    elapsed_seconds = proc.time()[["elapsed"]] - started,
    convergence = fit$opt$convergence,
    max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))),
    phi_estimate = fit$report$phi,
    phi_abs_error = abs(fit$report$phi - phi),
    pd_hessian = isTRUE(fit$sd_report$pdHess),
    phi_boundary = abs(fit$report$phi) > .99,
    stringsAsFactors = FALSE
  )
  row[paste0("independent_relative_error_trait_", 1:3)] <-
    as.list(abs(estimate - truth) / truth)
  row
}

rows <- do.call(rbind, lapply(c("unreplicated", "replicated"), function(workflow) {
  do.call(rbind, lapply(c(-.4, 0, .6), function(phi) {
    do.call(rbind, lapply(2609081:2609083, fit_one, workflow = workflow, phi = phi))
  }))
}))
write.csv(rows, "dev/temporal-ar1/recovery-exploration-24-results.csv", row.names = FALSE)
cell <- split(rows, interaction(rows$workflow, rows$phi_truth, drop = TRUE))
summary <- do.call(rbind, lapply(cell, function(x) {
  med <- vapply(x[grep("^independent_relative_error_trait_", names(x))], median, numeric(1L))
  data.frame(
    workflow = x$workflow[1L], phi_truth = x$phi_truth[1L], n_series = 24L,
    finite = all(is.finite(x$phi_estimate)), convergence = all(x$convergence == 0L),
    gradient = all(x$max_gradient <= 1e-3), pd_hessian = all(x$pd_hessian),
    any_phi_boundary = any(x$phi_boundary),
    phi_mean_abs_error = mean(x$phi_abs_error),
    phi_median_abs_error = median(x$phi_abs_error),
    independent_median_relative_error_trait_1 = med[1L],
    independent_median_relative_error_trait_2 = med[2L],
    independent_median_relative_error_trait_3 = med[3L],
    stringsAsFactors = FALSE
  )
}))
summary$meets_original_numeric_criteria <- with(summary,
  finite & convergence & gradient & pd_hessian &
    phi_mean_abs_error <= .15 & phi_median_abs_error <= .20 &
    independent_median_relative_error_trait_1 <= .35 &
    independent_median_relative_error_trait_2 <= .35 &
    independent_median_relative_error_trait_3 <= .35)
write.csv(summary, "dev/temporal-ar1/recovery-exploration-24-summary.csv", row.names = FALSE)
print(summary)
cat("TEMPORAL_EXPLORATION_24_COMPLETE\n")
