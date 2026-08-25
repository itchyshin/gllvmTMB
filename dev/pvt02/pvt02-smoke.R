## Bounded PVT-02 local smoke.
##
## This is plumbing evidence only. It fixes the new cell and seed window but
## intentionally runs two replicates, never the 5,000-attempt campaign.

args <- commandArgs(trailingOnly = TRUE)
out_path <- if (length(args) >= 1L) {
  args[[1L]]
} else {
  file.path("docs", "dev-log", "artifacts", "pvt02", "2026-08-25-pvt02-smoke-receipt.csv")
}
if (length(args) > 1L) stop("usage: Rscript dev/pvt02/pvt02-smoke.R [output.csv]")

source(file.path("dev", "pvt02", "pvt02-contract.R"))
source(file.path("dev", "m3-grid.R"))

pvt02_smoke_one <- function(rep_index) {
  seed <- pvt02_m3_seed(rep_index, d = 2L)
  started <- Sys.time()
  truth <- m3_sample_truth(
    family = "gaussian", d = 2L, n_traits = 3L, n_units = 400L,
    seed = seed, lambda_scale = M3_DEFAULT_LAMBDA_SCALE,
    psi_scale = M3_DEFAULT_PSI_SCALE
  )
  sim <- m3_simulate_response(truth)
  fit_error <- NULL
  fit <- tryCatch(
    withCallingHandlers(
      gllvmTMB::gllvmTMB(
        value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = TRUE),
        data = sim$data, family = stats::gaussian(), unit = "unit",
        control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
      ),
      warning = function(w) invokeRestart("muffleWarning")
    ),
    error = function(e) {
      fit_error <<- conditionMessage(e)
      NULL
    }
  )
  fit_converged <- inherits(fit, "gllvmTMB_multi") &&
    isTRUE(fit$opt$convergence == 0L) && isTRUE(fit$fit_health$converged)
  profile_error <- NULL
  ci <- if (fit_converged) tryCatch(
    gllvmTMB:::.profile_ci_total_variance(
      fit, tier = "unit", trait_idx = 1L, level = 0.95
    ),
    error = function(e) {
      profile_error <<- conditionMessage(e)
      NULL
    }
  ) else {
    NULL
  }
  estimate <- if (!is.null(ci) && nrow(ci) == 1L) ci$estimate[[1L]] else NA_real_
  lower <- if (!is.null(ci) && nrow(ci) == 1L) ci$lower[[1L]] else NA_real_
  upper <- if (!is.null(ci) && nrow(ci) == 1L) ci$upper[[1L]] else NA_real_
  reason <- if (!is.null(fit_error)) {
    paste0("fit_error: ", fit_error)
  } else if (!is.null(profile_error)) {
    paste0("profile_error: ", profile_error)
  } else {
    "profile_endpoint_invalid"
  }
  row <- pvt02_attempt_row(
    rep = rep_index, seed = seed, truth = truth$diag_Sigma[[1L]],
    estimate = estimate, lower = lower, upper = upper,
    fit_converged = fit_converged, endpoint_reason = reason
  )
  row$family <- "gaussian"
  row$tier <- "unit"
  row$mode <- "latent"
  row$unique <- TRUE
  row$d <- 2L
  row$n_units <- 400L
  row$trait <- 1L
  row$profile_scale <- "log_V"
  row$level <- 0.95
  row$runtime_s <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  row
}

reps <- pvt02_seed_window(50001L, 2L)
rows <- do.call(rbind, lapply(reps, pvt02_smoke_one))
pvt02_validate_attempt_rows(rows, reps)
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(rows, out_path, row.names = FALSE)
cat(sprintf("PVT02_SMOKE_WROTE %s (%d retained attempts)\n", out_path, nrow(rows)))
