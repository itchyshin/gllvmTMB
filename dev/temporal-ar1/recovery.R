#!/usr/bin/env Rscript

## Independent fixed-fixture DGP for temporal AR1 recovery checks.  It does
## not call the package simulator: the covariance contract is encoded directly
## here so implementation and evidence do not share a simulation path.

.temporal_recovery_data <- function(workflow, seed, phi = 0.6,
                                    n_series = 12L, n_time = 20L) {
  stopifnot(workflow %in% c("unreplicated", "replicated"))
  set.seed(seed)
  traits <- paste0("t", 1:3)
  series <- paste0("s", seq_len(n_series))
  intercept <- c(0.2, -0.3, 0.1)
  loading <- c(1, 0.7, -0.5)
  total <- c(0.52, 0.45, 0.61)
  psi <- c(0.16, 0.09, 0.25)
  sigma_eps <- 0.6
  score <- vapply(seq_len(n_series), function(i) {
    z <- numeric(n_time)
    z[1L] <- stats::rnorm(1L)
    for (tt in 2:n_time) {
      z[tt] <- phi * z[tt - 1L] + sqrt(1 - phi^2) * stats::rnorm(1L)
    }
    z
  }, numeric(n_time))
  out <- vector("list", n_series * n_time * length(traits) *
    if (identical(workflow, "replicated")) 2L else 1L)
  k <- 0L
  for (g in seq_along(series)) for (tt in seq_len(n_time)) {
    occasion_noise <- stats::rnorm(length(traits), sd = sqrt(psi))
    measurements <- if (identical(workflow, "replicated")) 1:2 else 1L
    for (rr in measurements) for (j in seq_along(traits)) {
      k <- k + 1L
      independent <- if (identical(workflow, "replicated")) {
        occasion_noise[j] + stats::rnorm(1L, sd = sigma_eps)
      } else {
        stats::rnorm(1L, sd = sqrt(total[j]))
      }
      out[[k]] <- data.frame(
        series = series[g], occasion = tt, measurement = rr, trait = traits[j],
        value = intercept[j] + loading[j] * score[tt, g] + independent,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, out)
}

.temporal_recovery_fit <- function(workflow, seed, phi = 0.6,
                                   control = gllvmTMBcontrol()) {
  dat <- .temporal_recovery_data(workflow, seed, phi = phi)
  formula <- if (identical(workflow, "replicated")) {
    value ~ 0 + trait + temporal_latent(
      0 + trait | series, time = occasion, replicate = measurement
    )
  } else {
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion)
  }
  fit <- suppressWarnings(gllvmTMB(
    formula, data = dat, unit = "series", family = gaussian(),
    control = control, silent = TRUE
  ))
  list(
    fit = fit,
    truth = list(phi = phi, loading = c(1, 0.7, -0.5),
      independent = if (identical(workflow, "replicated")) c(0.16, 0.09, 0.25) else c(0.52, 0.45, 0.61),
      intercept = c(0.2, -0.3, 0.1))
  )
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 3L || !args[1L] %in% c("unreplicated", "replicated")) {
    stop("Usage: Rscript --vanilla dev/temporal-ar1/recovery.R {unreplicated|replicated} SEED PHI", call. = FALSE)
  }
  devtools::load_all(".", quiet = TRUE)
  started <- proc.time()[["elapsed"]]
  result <- .temporal_recovery_fit(args[1L], as.integer(args[2L]), as.numeric(args[3L]))
  elapsed <- proc.time()[["elapsed"]] - started
  gradient <- max(abs(result$fit$tmb_obj$gr(result$fit$opt$par)))
  cat(sprintf("workflow=%s seed=%s phi_truth=%.8g elapsed_seconds=%.3f convergence=%d max_gradient=%.8g phi=%.8g\n",
    args[1L], args[2L], result$truth$phi, elapsed, result$fit$opt$convergence, gradient,
    result$fit$report$phi))
}
