## Retained direct-DGP runner for the narrow replicated OU temporal_indep +
## kernel_indep cell. It never calls production simulation.
root <- normalizePath('.', mustWork = TRUE)
pkgload::load_all(root, quiet = TRUE, export_all = FALSE)

output_dir <- Sys.getenv('OU_KERNEL_RECOVERY_OUTPUT', unset = '')
index <- suppressWarnings(as.integer(Sys.getenv('OU_KERNEL_RECOVERY_PLAN_INDEX', unset = NA_character_)))
if (!nzchar(output_dir) || is.na(index)) {
  stop('Set OU_KERNEL_RECOVERY_OUTPUT to a new directory and OU_KERNEL_RECOVERY_PLAN_INDEX to one frozen plan row.', call. = FALSE)
}
output_dir <- normalizePath(output_dir, mustWork = FALSE)
if (dir.exists(output_dir) || file.exists(output_dir)) {
  stop('OU kernel recovery output must name a new directory.', call. = FALSE)
}

truth <- list(beta = c(.2, -.3, .1), temporal = c(.55, .42, .63)^2,
  kernel = c(.35, .28, .40)^2, residual = .30)
series <- paste0('s', seq_len(80L))
traits <- paste0('t', 1:3)
elapsed <- c(0, .4, 1.1, 2.1, 3.4, 5.0, 6.9, 9.1, 11.6, 14.4, 17.5, 21.0)
coords <- cbind(seq_len(80L) / 80, sin(seq_len(80L) * .7))
K_raw <- exp(-as.matrix(dist(coords)) / .16) + diag(.08, 80L)
K <- K_raw / sqrt(outer(diag(K_raw), diag(K_raw)))
dimnames(K) <- list(series, series)
plan <- expand.grid(rate = c(.25, .70, 1.40), seed = 2609371:2609373)
plan <- plan[order(plan$rate, plan$seed), , drop = FALSE]
if (index < 1L || index > nrow(plan)) stop('OU_KERNEL_RECOVERY_PLAN_INDEX is outside the frozen nine-cell plan.', call. = FALSE)

simulate_fixture <- function(rate, seed) {
  set.seed(seed)
  kernel_field <- t(chol(K)) %*% sweep(matrix(rnorm(80L * 3L), 80L, 3L), 2L,
    sqrt(truth$kernel), '*')
  temporal_field <- array(0, c(80L, length(elapsed), 3L))
  for (trait in seq_len(3L)) for (group in seq_len(80L)) {
    temporal_field[group, 1L, trait] <- rnorm(1L, sd = sqrt(truth$temporal[[trait]]))
    for (time in 2:length(elapsed)) {
      correlation <- exp(-rate * (elapsed[[time]] - elapsed[[time - 1L]]))
      temporal_field[group, time, trait] <- correlation * temporal_field[group, time - 1L, trait] +
        sqrt(1 - correlation^2) * rnorm(1L, sd = sqrt(truth$temporal[[trait]]))
    }
  }
  data <- expand.grid(series = series, elapsed = elapsed, trait = traits,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  group <- match(data$series, series); time <- match(data$elapsed, elapsed); trait <- match(data$trait, traits)
  data$mean_value <- truth$beta[trait] + temporal_field[cbind(group, time, trait)] + kernel_field[cbind(group, trait)]
  data <- data[rep(seq_len(nrow(data)), each = 2L), , drop = FALSE]
  data$measurement <- rep(c('m1', 'm2'), times = nrow(data) / 2L)
  data$value <- data$mean_value + rnorm(nrow(data), sd = truth$residual)
  data$mean_value <- NULL
  data
}

fit_one <- function(rate, seed) {
  started <- proc.time()[['elapsed']]
  data <- simulate_fixture(rate, seed)
  result <- tryCatch({
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait + temporal_indep(0 + trait | series, time = elapsed,
        replicate = measurement, structure = 'ou') +
        kernel_indep(series, K = K, name = 'fixed_nonproportional_K'),
      data = data, unit = 'series', cluster = 'series', family = gaussian(), silent = TRUE,
      control = gllvmTMBcontrol(se = FALSE, optimizer = 'optim',
        optArgs = list(method = 'BFGS', control = list(maxit = 3000L, reltol = 1e-14)),
        optimizer_passes = 2L)
    ))
    history <- fit$optimizer_pass_history
    if (!is.data.frame(history) || nrow(history) != 2L || !all(history$pass == 1:2)) {
      stop('The requested two-pass optimizer history was not retained.', call. = FALSE)
    }
    temporal <- extract_temporal(fit)
    par <- fit$tmb_obj$env$parList(fit$opt$par)
    beta <- unname(fit$opt$par[names(fit$opt$par) == 'b_fix'])
    data.frame(rate = rate, seed = seed, terminal = 'success', convergence = fit$opt$convergence,
      pass_1_convergence = history$convergence[[1L]], pass_2_convergence = history$convergence[[2L]],
      pass_2_accepted = history$accepted[[2L]], max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))),
      objective = fit$opt$objective, rate_estimate = temporal$time$value[[1L]],
      temporal_1 = temporal$variance$value[[1L]], temporal_2 = temporal$variance$value[[2L]], temporal_3 = temporal$variance$value[[3L]],
      kernel_1 = par$theta_rr_phy[[1L]]^2, kernel_2 = par$theta_rr_phy[[2L]]^2, kernel_3 = par$theta_rr_phy[[3L]]^2,
      beta_1 = beta[[1L]], beta_2 = beta[[2L]], beta_3 = beta[[3L]], error_message = '', stringsAsFactors = FALSE)
  }, error = function(e) data.frame(rate = rate, seed = seed, terminal = 'error', convergence = NA_integer_,
    pass_1_convergence = NA_integer_, pass_2_convergence = NA_integer_, pass_2_accepted = NA,
    max_gradient = NA_real_, objective = NA_real_, rate_estimate = NA_real_, temporal_1 = NA_real_, temporal_2 = NA_real_, temporal_3 = NA_real_,
    kernel_1 = NA_real_, kernel_2 = NA_real_, kernel_3 = NA_real_, beta_1 = NA_real_, beta_2 = NA_real_, beta_3 = NA_real_,
    error_message = conditionMessage(e), stringsAsFactors = FALSE))
  result$elapsed_seconds <- proc.time()[['elapsed']] - started
  result
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
cell <- plan[index, , drop = FALSE]
result <- fit_one(cell$rate[[1L]], cell$seed[[1L]])
for (trait in 1:3) {
  result[[paste0('temporal_relative_error_', trait)]] <- abs(result[[paste0('temporal_', trait)]] - truth$temporal[[trait]]) / truth$temporal[[trait]]
  result[[paste0('kernel_relative_error_', trait)]] <- abs(result[[paste0('kernel_', trait)]] - truth$kernel[[trait]]) / truth$kernel[[trait]]
}
result$log_rate_absolute_error <- abs(log(result$rate_estimate) - log(result$rate))
result$fixed_effect_mean_absolute_error <- mean(abs(as.numeric(result[paste0('beta_', 1:3)]) - truth$beta))
write.csv(plan, file.path(output_dir, 'frozen-plan.csv'), row.names = FALSE)
write.csv(result, file.path(output_dir, sprintf('attempt-%02d.csv', index)), row.names = FALSE)
cat(sprintf('TEMPORAL_OU_KERNEL_RECOVERY_ATTEMPT_RETAINED index=%d elapsed_seconds=%.3f\n', index, result$elapsed_seconds[[1L]]))
