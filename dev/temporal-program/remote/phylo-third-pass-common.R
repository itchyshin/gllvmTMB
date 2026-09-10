## Frozen numerical continuation candidate for the retained temporal--phylo
## recovery failure.  This file changes only the number of identical BFGS
## passes from two to three.  It does not change the model, DGP, start,
## optimizer method, tolerance, thresholds, or which attempts are retained.

temporal_phylo_third_pass_controls <- function() {
  list(
    optimizer = "optim",
    method = "BFGS",
    optimizer_passes = 3L,
    maxit = 3000L,
    reltol = 1e-14,
    gradient_gate = 1e-3
  )
}

temporal_phylo_third_pass_validate_controls <- function(controls) {
  identical(controls, temporal_phylo_third_pass_controls())
}

## The three original strict-gradient failures, followed by the first retained
## successful seed in each persistence stratum.  The controls are fixed by
## position, not selected for their objective or parameter recovery.
temporal_phylo_third_pass_plan <- function() {
  data.frame(
    role = c(rep("retained_failure", 3L), rep("passing_control", 3L)),
    phi = c(0, .6, .6, -.4, 0, .6),
    seed = c(2609188L, 2609183L, 2609185L, 2609181L, 2609181L, 2609181L),
    stringsAsFactors = FALSE
  )
}

temporal_phylo_third_pass_validate_plan <- function(plan) {
  identical(plan, temporal_phylo_third_pass_plan())
}

temporal_phylo_third_pass_validate_receipt <- function(receipt) {
  required <- c(
    "role", "phi", "seed", "pass_1_convergence", "pass_2_convergence",
    "pass_3_convergence", "pass_2_accepted", "pass_3_accepted",
    "final_objective", "final_outer_gradient", "final_fresh_state_ok",
    "final_fd_all_coordinates"
  )
  is.data.frame(receipt) && nrow(receipt) == 1L &&
    all(required %in% names(receipt)) &&
    identical(as.integer(receipt$pass_1_convergence), 0L) &&
    identical(as.integer(receipt$pass_2_convergence), 0L) &&
    identical(as.integer(receipt$pass_3_convergence), 0L) &&
    isTRUE(receipt$pass_2_accepted) && isTRUE(receipt$pass_3_accepted) &&
    is.finite(receipt$final_objective) &&
    is.finite(receipt$final_outer_gradient) &&
    receipt$final_outer_gradient <= temporal_phylo_third_pass_controls()$gradient_gate &&
    isTRUE(receipt$final_fresh_state_ok) &&
    isTRUE(receipt$final_fd_all_coordinates)
}

temporal_phylo_third_pass_fit <- function(phi, seed, optimizer_passes) {
  if (!exists("simulate_fixture", mode = "function") || !exists("Cphy", inherits = TRUE)) {
    stop("source phylo-recovery-common.R before fitting the third-pass candidate", call. = FALSE)
  }
  controls <- temporal_phylo_third_pass_controls()
  data <- simulate_fixture(phi, seed)
  control <- gllvmTMBcontrol(
    se = FALSE, optimizer = controls$optimizer,
    optArgs = list(method = controls$method,
      control = list(maxit = controls$maxit, reltol = controls$reltol)),
    optimizer_passes = as.integer(optimizer_passes)
  )
  control$optimizer_diagnostics <- TRUE
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
      phylo_indep(0 + trait | series, vcv = Cphy),
    data = data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = control
  ))
  history <- fit$optimizer_pass_history
  if (!is.data.frame(history) || nrow(history) != optimizer_passes ||
      !identical(history$pass, seq_len(optimizer_passes))) {
    stop("third-pass candidate did not retain its complete optimizer history", call. = FALSE)
  }
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  temporal <- extract_temporal(fit)
  list(
    fit = fit,
    history = history,
    state = list(
      objective = as.numeric(fit$opt$objective),
      phi = as.numeric(temporal$time$value[[1L]]),
      temporal_variance = as.numeric(temporal$variance$value),
      phylo_variance = as.numeric(par$theta_rr_phy^2),
      residual_variance = as.numeric(exp(2 * par$log_sigma_eps[[1L]])),
      eta = as.numeric(fit$report$eta)
    )
  )
}

temporal_phylo_third_pass_relative_change <- function(x, y) {
  if (length(x) != length(y) || any(!is.finite(x)) || any(!is.finite(y))) return(Inf)
  sqrt(sum((x - y)^2)) / max(1, sqrt(sum(y^2)))
}

temporal_phylo_third_pass_adjudicate <- function(baseline, candidate) {
  controls <- temporal_phylo_third_pass_controls()
  base_history <- baseline$history
  candidate_history <- candidate$history
  same_first_two <- nrow(base_history) == 2L && nrow(candidate_history) == 3L &&
    identical(base_history$pass, 1:2) && identical(candidate_history$pass, 1:3) &&
    isTRUE(all.equal(base_history$end, candidate_history$end[1:2], tolerance = 1e-10)) &&
    isTRUE(all.equal(base_history$objective, candidate_history$objective[1:2], tolerance = 1e-10))
  final <- candidate_history[3L, , drop = FALSE]
  covariance_change <- max(
    temporal_phylo_third_pass_relative_change(candidate$state$temporal_variance,
      baseline$state$temporal_variance),
    temporal_phylo_third_pass_relative_change(candidate$state$phylo_variance,
      baseline$state$phylo_variance)
  )
  residual_change <- temporal_phylo_third_pass_relative_change(
    candidate$state$residual_variance, baseline$state$residual_variance
  )
  prediction_change <- temporal_phylo_third_pass_relative_change(
    candidate$state$eta, baseline$state$eta
  )
  objective_tolerance <- 64 * .Machine$double.eps * max(1, abs(baseline$state$objective))
  gates <- c(
    same_first_two = same_first_two,
    convergence = identical(as.integer(final$convergence[[1L]]), 0L),
    accepted = isTRUE(final$accepted[[1L]]),
    finite_difference_complete = isTRUE(final$finite_difference_all_finite[[1L]]) &&
      identical(as.integer(final$finite_difference_n_coordinates[[1L]]),
        as.integer(final$finite_difference_n_finite[[1L]])),
    fresh_state = isTRUE(final$fresh_state_ok[[1L]]),
    gradient = is.finite(final$outer_gradient_max[[1L]]) &&
      final$outer_gradient_max[[1L]] <= controls$gradient_gate,
    objective = is.finite(final$fresh_objective[[1L]]) &&
      final$fresh_objective[[1L]] <= baseline$state$objective + objective_tolerance,
    phi = abs(candidate$state$phi - baseline$state$phi) <= 1e-5,
    covariance = covariance_change <= 1e-4,
    residual = residual_change <= 1e-4,
    prediction = prediction_change <= 1e-4
  )
  list(
    accepted = all(gates), gates = gates,
    final_outer_gradient = final$outer_gradient_max[[1L]],
    final_objective = final$fresh_objective[[1L]],
    covariance_relative_change = covariance_change,
    residual_relative_change = residual_change,
    prediction_relative_change = prediction_change,
    phi_absolute_change = abs(candidate$state$phi - baseline$state$phi)
  )
}
