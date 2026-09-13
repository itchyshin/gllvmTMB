#!/usr/bin/env Rscript
## Pre-run and retained campaign for the direct temporal AR1 profile endpoint.
## The DGP below is deliberately independent of production temporal simulation.

args <- commandArgs(trailingOnly = TRUE)
smoke <- identical(args, "--smoke")
if (length(args) && !smoke) stop("Only --smoke is accepted.", call. = FALSE)
result_path <- "dev/temporal-main-lifecycle/results/temporal-profile-coverage-20260913.csv"

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))

truth <- list(
  phi = 0.6,
  temporal_variance = c(t1 = 0.7, t2 = 0.45, t3 = 0.3),
  residual_variance = c(t1 = 0.25, t2 = 0.35, t3 = 0.2)
)

simulate_profile_fixture <- function(seed) {
  set.seed(seed)
  n_series <- 12L
  n_time <- 8L
  traits <- names(truth$temporal_variance)
  ans <- expand.grid(
    series = sprintf("s%02d", seq_len(n_series)), occasion = seq_len(n_time),
    trait = traits, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  ans$value <- NA_real_
  for (g in seq_len(n_series)) for (j in seq_along(traits)) {
    z <- numeric(n_time)
    z[[1L]] <- stats::rnorm(1L, sd = sqrt(truth$temporal_variance[[j]]))
    for (tt in 2:n_time) {
      z[[tt]] <- truth$phi * z[[tt - 1L]] +
        sqrt(1 - truth$phi^2) * stats::rnorm(1L, sd = sqrt(truth$temporal_variance[[j]]))
    }
    idx <- ans$series == sprintf("s%02d", g) & ans$trait == traits[[j]]
    ans$value[idx] <- z + stats::rnorm(n_time, sd = sqrt(truth$residual_variance[[j]]))
  }
  ans
}

run_one <- function(seed) {
  data <- simulate_profile_fixture(seed)
  fit_started <- proc.time()[["elapsed"]]
  fit <- tryCatch(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = data, unit = "series", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )), error = identity)
  fit_elapsed <- proc.time()[["elapsed"]] - fit_started
  if (inherits(fit, "error")) return(data.frame(
    seed, terminal = "fit_error", fit_seconds = fit_elapsed,
    profile_seconds = NA_real_, convergence = NA_integer_, max_gradient = NA_real_,
    objective = NA_real_, estimate = NA_real_, lower = NA_real_, upper = NA_real_,
    finite_endpoints = FALSE, covers = FALSE, error = conditionMessage(fit)
  ))
  grad <- max(abs(fit$tmb_obj$gr(fit$opt$par)))
  profile_started <- proc.time()[["elapsed"]]
  endpoint <- tryCatch(profile_temporal(fit, ystep = 0.25, ytol = 1), error = identity)
  profile_elapsed <- proc.time()[["elapsed"]] - profile_started
  if (inherits(endpoint, "error")) return(data.frame(
    seed, terminal = "profile_error", fit_seconds = fit_elapsed,
    profile_seconds = profile_elapsed, convergence = fit$opt$convergence,
    max_gradient = grad, objective = fit$opt$objective, estimate = NA_real_,
    lower = NA_real_, upper = NA_real_, finite_endpoints = FALSE, covers = FALSE,
    error = conditionMessage(endpoint)
  ))
  finite <- all(is.finite(endpoint[c("lower", "upper")]))
  data.frame(
    seed, terminal = "success", fit_seconds = fit_elapsed,
    profile_seconds = profile_elapsed, convergence = fit$opt$convergence,
    max_gradient = grad, objective = fit$opt$objective,
    estimate = endpoint[["estimate"]], lower = endpoint[["lower"]],
    upper = endpoint[["upper"]], finite_endpoints = finite,
    covers = finite && endpoint[["lower"]] <= truth$phi && truth$phi <= endpoint[["upper"]],
    error = NA_character_
  )
}

seeds <- if (smoke) 2609131L else 2609131:2609160
out <- do.call(rbind, lapply(seeds, run_one))
print(out, row.names = FALSE)
if (smoke) {
  cat(sprintf("TEMPORAL_PROFILE_PRERUN_PASS total_seconds=%.3f\n",
    out$fit_seconds[[1L]] + out$profile_seconds[[1L]]))
} else {
  dir.create(dirname(result_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(out, result_path, row.names = FALSE)
  n_cover <- sum(out$covers)
  ci <- stats::binom.test(n_cover, nrow(out), conf.level = .95)$conf.int
  cat(sprintf("TEMPORAL_PROFILE_COVERAGE rows=%d finite=%d covers=%d ci_lower=%.4f\n",
    nrow(out), sum(out$finite_endpoints), n_cover, ci[[1L]]))
}
