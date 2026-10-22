## Retained local recovery campaign for the replicated AR1 temporal_indep +
## kernel_indep cell. The DGP is direct and never calls production simulation.
root <- normalizePath(".", mustWork = TRUE)
pkgload::load_all(root, quiet = TRUE, export_all = FALSE)

truth <- list(beta = c(0.2, -0.3, 0.1), temporal = c(.55, .42, .63)^2,
  kernel = c(.35, .28, .40)^2, residual = .30)
series <- paste0('s', seq_len(80L)); traits <- paste0('t', 1:3); n_time <- 16L
coords <- cbind(seq_len(80L) / 80, sin(seq_len(80L) * 0.7))
K_raw <- exp(-as.matrix(dist(coords)) / .16) + diag(.08, 80L)
K <- K_raw / sqrt(outer(diag(K_raw), diag(K_raw)))
dimnames(K) <- list(series, series)

simulate_fixture <- function(phi, seed) {
  set.seed(seed)
  U <- t(chol(K)) %*% sweep(matrix(rnorm(80L * 3L), 80L, 3L), 2L,
    sqrt(truth$kernel), '*')
  Z <- array(0, c(80L, n_time, 3L))
  for (j in 1:3) for (g in 1:80) {
    Z[g, 1L, j] <- rnorm(1L, sd = sqrt(truth$temporal[j]))
    for (tt in 2:n_time) Z[g, tt, j] <- phi * Z[g, tt - 1L, j] +
      sqrt(1 - phi^2) * rnorm(1L, sd = sqrt(truth$temporal[j]))
  }
  data <- expand.grid(series = series, occasion = seq_len(n_time), trait = traits,
    stringsAsFactors = FALSE)
  g <- match(data$series, series); tt <- data$occasion; j <- match(data$trait, traits)
  data$mean_value <- truth$beta[j] + Z[cbind(g, tt, j)] + U[cbind(g, j)]
  data <- data[rep(seq_len(nrow(data)), each = 2L), , drop = FALSE]
  data$measurement <- rep(c('m1', 'm2'), times = nrow(data) / 2L)
  data$value <- data$mean_value + rnorm(nrow(data), sd = truth$residual)
  data$mean_value <- NULL
  data
}

fit_one <- function(phi, seed) {
  started <- proc.time()[['elapsed']]
  d <- simulate_fixture(phi, seed)
  out <- tryCatch({
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
        kernel_indep(series, K = K, name = 'fixed_nonproportional_K'),
      data = d, unit = 'series', cluster = 'series', family = gaussian(), silent = TRUE,
      control = gllvmTMBcontrol(se = FALSE, optimizer = 'optim',
        optArgs = list(method = 'BFGS', control = list(maxit = 3000, reltol = 1e-14)),
        optimizer_passes = 2L)
    ))
    pass_history <- fit$optimizer_pass_history
    if (!is.data.frame(pass_history) || nrow(pass_history) != 2L ||
        !all(pass_history$pass == 1:2)) {
      stop("The requested two-pass optimizer history was not retained.", call. = FALSE)
    }
    temporal <- extract_temporal(fit)
    beta <- unname(fit$opt$par[names(fit$opt$par) == 'b_fix'])
    data.frame(phi = phi, seed = seed, terminal = 'success',
      convergence = fit$opt$convergence,
      pass_1_convergence = pass_history$convergence[[1L]],
      pass_2_convergence = pass_history$convergence[[2L]],
      pass_2_accepted = pass_history$accepted[[2L]],
      max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))),
      objective = fit$opt$objective,
      phi_estimate = temporal$time$value[[1L]],
      temporal_1 = temporal$variance$value[[1L]], temporal_2 = temporal$variance$value[[2L]], temporal_3 = temporal$variance$value[[3L]],
      kernel_1 = fit$tmb_obj$env$parList(fit$opt$par)$theta_rr_phy[1L]^2, kernel_2 = fit$tmb_obj$env$parList(fit$opt$par)$theta_rr_phy[2L]^2, kernel_3 = fit$tmb_obj$env$parList(fit$opt$par)$theta_rr_phy[3L]^2,
      beta_1 = beta[[1L]], beta_2 = beta[[2L]], beta_3 = beta[[3L]], stringsAsFactors = FALSE
    )
  }, error = function(e) data.frame(phi = phi, seed = seed, terminal = 'error',
    convergence = NA_integer_, pass_1_convergence = NA_integer_,
    pass_2_convergence = NA_integer_, pass_2_accepted = NA,
    max_gradient = NA_real_, objective = NA_real_, phi_estimate = NA_real_,
    temporal_1 = NA_real_, temporal_2 = NA_real_, temporal_3 = NA_real_,
    kernel_1 = NA_real_, kernel_2 = NA_real_, kernel_3 = NA_real_,
    beta_1 = NA_real_, beta_2 = NA_real_, beta_3 = NA_real_, stringsAsFactors = FALSE))
  out$elapsed_seconds <- proc.time()[['elapsed']] - started
  out
}

plan <- expand.grid(phi = c(-.4, 0, .6), seed = 2609151:2609153)
plan <- plan[order(plan$phi, plan$seed), , drop = FALSE]
result <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) fit_one(plan$phi[[i]], plan$seed[[i]])))
for (j in 1:3) {
  result[[paste0('temporal_relative_error_', j)]] <- abs(result[[paste0('temporal_',j)]] - truth$temporal[j]) / truth$temporal[j]
  result[[paste0('kernel_relative_error_', j)]] <- abs(result[[paste0('kernel_',j)]] - truth$kernel[j]) / truth$kernel[j]
}
result$phi_absolute_error <- abs(result$phi_estimate - result$phi)
result$fixed_effect_mean_absolute_error <- vapply(seq_len(nrow(result)), function(i) mean(abs(as.numeric(result[i, paste0('beta_', 1:3)]) - truth$beta)), numeric(1))
summary <- do.call(rbind, lapply(split(result, result$phi), function(x) {
  ok <- x$terminal == 'success' & x$convergence == 0L &
    x$pass_2_convergence == 0L & x$pass_2_accepted &
    is.finite(x$max_gradient) & x$max_gradient <= 1e-3
  data.frame(phi = x$phi[[1L]], attempts = nrow(x), strict_successes = sum(ok),
    mean_phi_absolute_error = mean(x$phi_absolute_error[ok]), median_phi_absolute_error = median(x$phi_absolute_error[ok]),
    median_temporal_1_relative_error = median(x$temporal_relative_error_1[ok]), median_temporal_2_relative_error = median(x$temporal_relative_error_2[ok]), median_temporal_3_relative_error = median(x$temporal_relative_error_3[ok]),
    median_kernel_1_relative_error = median(x$kernel_relative_error_1[ok]), median_kernel_2_relative_error = median(x$kernel_relative_error_2[ok]), median_kernel_3_relative_error = median(x$kernel_relative_error_3[ok]),
    mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[ok]), stringsAsFactors = FALSE)
}))
summary$passes <- with(summary, strict_successes == 3L & mean_phi_absolute_error <= .15 & median_phi_absolute_error <= .20 &
  median_temporal_1_relative_error <= .35 & median_temporal_2_relative_error <= .35 & median_temporal_3_relative_error <= .35 &
  median_kernel_1_relative_error <= .35 & median_kernel_2_relative_error <= .35 & median_kernel_3_relative_error <= .35 &
  mean_fixed_effect_error <= .25)
write.csv(result, file.path(root, 'dev/temporal-program/results/kernel-recovery-20260909.csv'), row.names = FALSE)
write.csv(summary, file.path(root, 'dev/temporal-program/results/kernel-recovery-summary-20260909.csv'), row.names = FALSE)
print(result, row.names = FALSE)
print(summary, row.names = FALSE)
if (!all(summary$passes)) stop('Frozen disposable kernel recovery campaign fails its predeclared thresholds.', call. = FALSE)
cat('TEMPORAL_KERNEL_RECOVERY_PASS\n')
