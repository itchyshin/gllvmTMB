## Retained recovery campaign: replicated AR1 temporal_indep + spatial_indep.
## The DGP samples the SPDE precision directly; it never calls production
## temporal simulation.  The full plan is deliberately dormant until the
## measured smoke fit and separate compute decision are recorded.
root <- normalizePath(".", mustWork = TRUE)
pkgload::load_all(root, quiet = TRUE, export_all = FALSE)

truth <- list(
  beta = c(.2, -.3, .1),
  temporal = c(.55, .42, .63)^2,
  tau = c(.85, 1.10, 1.35),
  kappa = 2,
  residual = .30
)
n_series <- 80L; n_time <- 16L; n_replicate <- 2L
series <- paste0("s", seq_len(n_series)); traits <- paste0("t", 1:3)

## Static locations make the source a spatial field across series, while the
## temporal state evolves within each series.  The deterministic, staggered
## layout prevents the source and temporal bases from being proportional.
locations <- data.frame(
  series = series,
  lon = (seq_len(n_series) - 1L) %% 10L + .15 * sin(2.3 * seq_len(n_series)),
  lat = (seq_len(n_series) - 1L) %/% 10L + .17 * cos(1.7 * seq_len(n_series))
)
template <- expand.grid(
  series = series, occasion = seq_len(n_time), trait = traits,
  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
)
template$lon <- locations$lon[match(template$series, locations$series)]
template$lat <- locations$lat[match(template$series, locations$series)]
template <- template[rep(seq_len(nrow(template)), each = n_replicate), , drop = FALSE]
template$measurement <- rep(c("m1", "m2"), times = nrow(template) / n_replicate)
mesh <- make_mesh(template, c("lon", "lat"), type = "kmeans", n_knots = 40L,
  seed = 2609211L)

simulate_fixture <- function(phi, seed) {
  set.seed(seed)
  Q <- truth$kappa^4 * as.matrix(mesh$spde$c0) +
    2 * truth$kappa^2 * as.matrix(mesh$spde$g1) + as.matrix(mesh$spde$g2)
  U <- chol(Q)
  omega <- vapply(truth$tau, function(tau) {
    backsolve(U, stats::rnorm(ncol(mesh$A_st))) / tau
  }, numeric(ncol(mesh$A_st)))
  spatial <- as.matrix(mesh$A_st %*% omega)

  temporal <- array(0, c(n_series, n_time, length(traits)))
  for (trait in seq_along(traits)) for (group in seq_len(n_series)) {
    temporal[group, 1L, trait] <- stats::rnorm(1L, sd = sqrt(truth$temporal[[trait]]))
    for (time in 2:n_time) {
      temporal[group, time, trait] <- phi * temporal[group, time - 1L, trait] +
        sqrt(1 - phi^2) * stats::rnorm(1L, sd = sqrt(truth$temporal[[trait]]))
    }
  }
  data <- template
  group <- match(data$series, series)
  trait <- match(data$trait, traits)
  data$value <- truth$beta[trait] +
    temporal[cbind(group, data$occasion, trait)] +
    spatial[cbind(seq_len(nrow(data)), trait)] +
    stats::rnorm(nrow(data), sd = truth$residual)
  data
}

fit_one <- function(phi, seed) {
  started <- proc.time()[["elapsed"]]
  data <- simulate_fixture(phi, seed)
  out <- tryCatch({
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait +
        temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
        spatial_indep(0 + trait | coords, mesh = mesh),
      data = data, unit = "series", family = gaussian(), silent = TRUE,
      control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
        optArgs = list(method = "BFGS", control = list(maxit = 3000, reltol = 1e-14)),
        optimizer_passes = 2L)
    ))
    history <- fit$optimizer_pass_history
    if (!is.data.frame(history) || nrow(history) != 2L || !all(history$pass == 1:2)) {
      stop("The requested two-pass optimizer history was not retained.", call. = FALSE)
    }
    temporal <- extract_temporal(fit)
    par <- fit$tmb_obj$env$parList(fit$opt$par)
    beta <- unname(fit$opt$par[names(fit$opt$par) == "b_fix"])
    data.frame(
      phi = phi, seed = seed, terminal = "success", convergence = fit$opt$convergence,
      pass_1_convergence = history$convergence[[1L]],
      pass_2_convergence = history$convergence[[2L]],
      pass_2_accepted = history$accepted[[2L]],
      max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))), objective = fit$opt$objective,
      phi_estimate = temporal$time$value[[1L]],
      temporal_1 = temporal$variance$value[[1L]], temporal_2 = temporal$variance$value[[2L]],
      temporal_3 = temporal$variance$value[[3L]],
      tau_1 = par$log_tau_spde[[1L]], tau_2 = par$log_tau_spde[[2L]],
      tau_3 = par$log_tau_spde[[3L]], kappa = exp(par$log_kappa_spde[[1L]]),
      beta_1 = beta[[1L]], beta_2 = beta[[2L]], beta_3 = beta[[3L]],
      stringsAsFactors = FALSE
    )
  }, error = function(e) data.frame(
    phi = phi, seed = seed, terminal = "error", convergence = NA_integer_,
    pass_1_convergence = NA_integer_, pass_2_convergence = NA_integer_,
    pass_2_accepted = NA, max_gradient = NA_real_, objective = NA_real_,
    phi_estimate = NA_real_, temporal_1 = NA_real_, temporal_2 = NA_real_,
    temporal_3 = NA_real_, tau_1 = NA_real_, tau_2 = NA_real_, tau_3 = NA_real_,
    kappa = NA_real_, beta_1 = NA_real_, beta_2 = NA_real_, beta_3 = NA_real_,
    stringsAsFactors = FALSE
  ))
  out$elapsed_seconds <- proc.time()[["elapsed"]] - started
  out
}

plan <- expand.grid(phi = c(-.4, 0, .6), seed = 2609211:2609220)
plan <- plan[order(plan$phi, plan$seed), , drop = FALSE]
is_smoke <- identical(Sys.getenv("TEMPORAL_RECOVERY_SMOKE"), "1")
if (is_smoke) plan <- data.frame(phi = .6, seed = 2609210L)
result_path <- if (is_smoke) tempfile("temporal-spatial-smoke-", fileext = ".csv") else
  file.path(root, "dev/temporal-program/results/spatial-recovery-20260909.csv")
result <- if (file.exists(result_path)) utils::read.csv(result_path, check.names = FALSE) else NULL
if (!is.null(result) && anyDuplicated(result[c("phi", "seed")])) {
  stop("Spatial recovery checkpoint has duplicate phi--seed attempts.", call. = FALSE)
}
if (!is.null(result) && any(!paste(result$phi, result$seed) %in% paste(plan$phi, plan$seed))) {
  stop("Spatial recovery checkpoint contains attempts outside the frozen plan.", call. = FALSE)
}
for (i in seq_len(nrow(plan))) {
  phi_i <- plan$phi[[i]]; seed_i <- plan$seed[[i]]
  if (!is.null(result) && any(result$phi == phi_i & result$seed == seed_i)) next
  attempt <- fit_one(phi_i, seed_i)
  result <- if (is.null(result)) attempt else rbind(result, attempt)
  result <- result[order(result$phi, result$seed), , drop = FALSE]
  utils::write.csv(result, result_path, row.names = FALSE)
  cat(sprintf("CHECKPOINT phi=%s seed=%s elapsed=%.3f\n", phi_i, seed_i, attempt$elapsed_seconds[[1L]]))
  flush.console(); gc(verbose = FALSE)
}
if (is_smoke) {
  print(result, row.names = FALSE)
  if (!identical(result$terminal[[1L]], "success")) stop("Spatial smoke fit failed.", call. = FALSE)
  cat("TEMPORAL_SPATIAL_RECOVERY_SMOKE_PASS\n")
  quit(save = "no", status = 0L)
}

for (trait in seq_along(traits)) {
  result[[paste0("temporal_relative_error_", trait)]] <-
    abs(result[[paste0("temporal_", trait)]] - truth$temporal[[trait]]) / truth$temporal[[trait]]
  result[[paste0("tau_relative_error_", trait)]] <-
    abs(exp(result[[paste0("tau_", trait)]]) - truth$tau[[trait]]) / truth$tau[[trait]]
}
result$kappa_relative_error <- abs(result$kappa - truth$kappa) / truth$kappa
result$phi_absolute_error <- abs(result$phi_estimate - result$phi)
result$fixed_effect_mean_absolute_error <- vapply(seq_len(nrow(result)), function(i) {
  mean(abs(as.numeric(result[i, paste0("beta_", 1:3)]) - truth$beta))
}, numeric(1))
summary <- do.call(rbind, lapply(split(result, result$phi), function(x) {
  ok <- x$terminal == "success" & x$convergence == 0L & x$pass_2_convergence == 0L &
    x$pass_2_accepted & is.finite(x$max_gradient) & x$max_gradient <= 1e-3
  data.frame(
    phi = x$phi[[1L]], attempts = nrow(x), strict_successes = sum(ok),
    mean_phi_absolute_error = mean(x$phi_absolute_error[ok]),
    median_phi_absolute_error = stats::median(x$phi_absolute_error[ok]),
    median_temporal_1_relative_error = stats::median(x$temporal_relative_error_1[ok]),
    median_temporal_2_relative_error = stats::median(x$temporal_relative_error_2[ok]),
    median_temporal_3_relative_error = stats::median(x$temporal_relative_error_3[ok]),
    median_tau_1_relative_error = stats::median(x$tau_relative_error_1[ok]),
    median_tau_2_relative_error = stats::median(x$tau_relative_error_2[ok]),
    median_tau_3_relative_error = stats::median(x$tau_relative_error_3[ok]),
    median_kappa_relative_error = stats::median(x$kappa_relative_error[ok]),
    mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[ok]),
    stringsAsFactors = FALSE
  )
}))
summary$passes <- with(summary, strict_successes == 10L &
  mean_phi_absolute_error <= .15 & median_phi_absolute_error <= .20 &
  median_temporal_1_relative_error <= .35 & median_temporal_2_relative_error <= .35 &
  median_temporal_3_relative_error <= .35 & median_tau_1_relative_error <= .35 &
  median_tau_2_relative_error <= .35 & median_tau_3_relative_error <= .35 &
  median_kappa_relative_error <= .50 & mean_fixed_effect_error <= .25)
utils::write.csv(result, result_path, row.names = FALSE)
utils::write.csv(summary,
  file.path(root, "dev/temporal-program/results/spatial-recovery-160-summary-20260909.csv"),
  row.names = FALSE)
print(result, row.names = FALSE); print(summary, row.names = FALSE)
if (!all(summary$passes)) stop("Frozen spatial recovery campaign fails its predeclared thresholds.", call. = FALSE)
cat("TEMPORAL_SPATIAL_RECOVERY_PASS\n")
