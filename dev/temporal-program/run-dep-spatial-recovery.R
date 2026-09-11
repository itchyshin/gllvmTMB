## Retained direct-DGP recovery for replicated AR1 temporal_dep + spatial_indep.
## This generator reconstructs neither production simulation nor temporal states.
root <- normalizePath('.', mustWork = TRUE)
pkgload::load_all(root, quiet = TRUE, export_all = FALSE)

truth <- list(
  beta = c(.2, -.3, .1),
  temporal_loading = rbind(c(.55, 0, 0), c(.12, .50, 0), c(-.08, .10, .48)),
  tau = c(.85, 1.10, 1.35), kappa = 2, residual = .30
)
truth$temporal_covariance <- tcrossprod(truth$temporal_loading)
n_series <- 80L; n_time <- 16L; n_replicate <- 2L
series <- paste0('s', seq_len(n_series)); traits <- paste0('t', 1:3)
locations <- data.frame(
  series = series,
  lon = (seq_len(n_series) - 1L) %% 10L + .15 * sin(2.3 * seq_len(n_series)),
  lat = (seq_len(n_series) - 1L) %/% 10L + .17 * cos(1.7 * seq_len(n_series))
)
template <- expand.grid(series = series, occasion = seq_len(n_time), trait = traits,
  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
template$lon <- locations$lon[match(template$series, locations$series)]
template$lat <- locations$lat[match(template$series, locations$series)]
template <- template[rep(seq_len(nrow(template)), each = n_replicate), , drop = FALSE]
template$measurement <- rep(c('m1', 'm2'), times = nrow(template) / n_replicate)
mesh <- make_mesh(template, c('lon', 'lat'), type = 'kmeans', n_knots = 40L,
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
  state <- array(0, dim = c(n_series, n_time, length(traits)))
  L <- t(chol(truth$temporal_covariance))
  for (g in seq_len(n_series)) {
    state[g, 1L, ] <- drop(L %*% stats::rnorm(length(traits)))
    for (time in 2:n_time) state[g, time, ] <- phi * state[g, time - 1L, ] +
      sqrt(1 - phi^2) * drop(L %*% stats::rnorm(length(traits)))
  }
  data <- template
  group <- match(data$series, series); trait <- match(data$trait, traits)
  data$value <- truth$beta[trait] + state[cbind(group, data$occasion, trait)] +
    spatial[cbind(seq_len(nrow(data)), trait)] + stats::rnorm(nrow(data), sd = truth$residual)
  data
}

rel_frob <- function(x, y) sqrt(sum((x - y)^2)) / sqrt(sum(y^2))
fit_one <- function(phi, seed) {
  started <- proc.time()[['elapsed']]
  diagnostic <- identical(Sys.getenv('DEP_SPATIAL_DIAGNOSTIC'), '1')
  skip_hessian <- identical(Sys.getenv('DEP_SPATIAL_SKIP_HESSIAN'), '1')
  out <- tryCatch({
    data <- simulate_fixture(phi, seed)
    fit_started <- proc.time()[['elapsed']]
    write_diagnostic_phase('fit_started', phi, seed)
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait +
        temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
        spatial_indep(0 + trait | coords, mesh = mesh),
      data = data, unit = 'series', family = gaussian(), silent = TRUE,
      control = gllvmTMBcontrol(se = FALSE, optimizer = 'optim',
        optArgs = list(method = 'BFGS', control = list(maxit = 3000, reltol = 1e-14)),
        optimizer_passes = 2L)
    ))
    fit_elapsed_seconds <- proc.time()[['elapsed']] - fit_started
    write_diagnostic_phase('fit_finished', phi, seed, fit_elapsed_seconds = fit_elapsed_seconds)
    history <- fit$optimizer_pass_history
    if (!is.data.frame(history) || nrow(history) != 2L || !all(history$pass == 1:2))
      stop('The requested two-pass optimizer history was not retained.', call. = FALSE)
    temporal <- extract_temporal(fit); par <- fit$tmb_obj$env$parList(fit$opt$par)
    hessian_started <- proc.time()[['elapsed']]
    write_diagnostic_phase('hessian_started', phi, seed,
      fit_elapsed_seconds = fit_elapsed_seconds)
    if (skip_hessian) {
      hessian <- NULL
      hessian_status <- 'not_requested'
      hessian_elapsed_seconds <- 0
    } else {
      hessian <- tryCatch(fit$tmb_obj$he(fit$opt$par), error = function(e) e)
      hessian_status <- if (inherits(hessian, 'error')) 'error' else if (
        all(is.finite(hessian)) && !inherits(try(chol(hessian), silent = TRUE), 'try-error')
      ) 'positive_definite' else 'non_positive_definite'
      hessian_elapsed_seconds <- proc.time()[['elapsed']] - hessian_started
    }
    write_diagnostic_phase('hessian_finished', phi, seed,
      fit_elapsed_seconds = fit_elapsed_seconds,
      hessian_elapsed_seconds = hessian_elapsed_seconds)
    gradient_started <- proc.time()[['elapsed']]
    max_gradient <- max(abs(fit$tmb_obj$gr(fit$opt$par)))
    gradient_elapsed_seconds <- proc.time()[['elapsed']] - gradient_started
    write_diagnostic_phase('gradient_finished', phi, seed,
      fit_elapsed_seconds = fit_elapsed_seconds,
      hessian_elapsed_seconds = hessian_elapsed_seconds,
      gradient_elapsed_seconds = gradient_elapsed_seconds)
    result <- data.frame(phi = phi, seed = seed, terminal = 'success', convergence = fit$opt$convergence,
      pass_1_convergence = history$convergence[[1L]], pass_2_convergence = history$convergence[[2L]],
      pass_2_accepted = history$accepted[[2L]], max_gradient = max_gradient,
      objective = fit$opt$objective, hessian_status = hessian_status,
      phi_estimate = temporal$time$value[[1L]],
      temporal_frobenius_relative_error = rel_frob(tcrossprod(as.matrix(temporal$loading)), truth$temporal_covariance),
      tau_1 = exp(par$log_tau_spde[[1L]]), tau_2 = exp(par$log_tau_spde[[2L]]),
      tau_3 = exp(par$log_tau_spde[[3L]]), kappa = exp(par$log_kappa_spde[[1L]]),
      beta_1 = par$b_fix[[1L]], beta_2 = par$b_fix[[2L]], beta_3 = par$b_fix[[3L]],
      error_message = NA_character_, stringsAsFactors = FALSE)
    if (diagnostic) {
      result$fit_elapsed_seconds <- fit_elapsed_seconds
      result$hessian_elapsed_seconds <- hessian_elapsed_seconds
      result$gradient_elapsed_seconds <- gradient_elapsed_seconds
      result$hessian_requested <- !skip_hessian
    }
    result
  }, error = function(e) {
    write_diagnostic_phase('error', phi, seed, error_message = conditionMessage(e))
    data.frame(
    phi = phi, seed = seed, terminal = 'error', convergence = NA_integer_,
    pass_1_convergence = NA_integer_, pass_2_convergence = NA_integer_, pass_2_accepted = NA,
    max_gradient = NA_real_, objective = NA_real_, hessian_status = 'error', phi_estimate = NA_real_,
    temporal_frobenius_relative_error = NA_real_, tau_1 = NA_real_, tau_2 = NA_real_, tau_3 = NA_real_,
    kappa = NA_real_, beta_1 = NA_real_, beta_2 = NA_real_, beta_3 = NA_real_,
    error_message = conditionMessage(e), stringsAsFactors = FALSE)
  })
  out$elapsed_seconds <- proc.time()[['elapsed']] - started
  out
}

full_plan <- expand.grid(phi = c(-.4, 0, .6), seed = 2609331:2609333)
full_plan <- full_plan[order(full_plan$phi, full_plan$seed), , drop = FALSE]
smoke <- identical(Sys.getenv('DEP_SPATIAL_SMOKE'), '1')
finalize_only <- identical(commandArgs(trailingOnly = TRUE), '--finalize')
diagnostic <- identical(Sys.getenv('DEP_SPATIAL_DIAGNOSTIC'), '1')
diagnostic_output <- Sys.getenv('DEP_SPATIAL_DIAGNOSTIC_OUTPUT', unset = '')
skip_hessian <- identical(Sys.getenv('DEP_SPATIAL_SKIP_HESSIAN'), '1')
one_text <- Sys.getenv('DEP_SPATIAL_ONE', unset = '')
one_requested <- nzchar(one_text)
diagnostic_dir <- file.path(root, 'dev/temporal-program/results/diagnostics')
if (diagnostic && (!one_requested || !nzchar(diagnostic_output) || finalize_only)) {
  stop('Diagnostic mode requires DEP_SPATIAL_ONE and DEP_SPATIAL_DIAGNOSTIC_OUTPUT so frozen receipts cannot be overwritten.', call. = FALSE)
}
if (skip_hessian && !diagnostic) {
  stop('DEP_SPATIAL_SKIP_HESSIAN is available only with DEP_SPATIAL_DIAGNOSTIC=1.', call. = FALSE)
}
if (diagnostic) {
  diagnostic_output <- normalizePath(diagnostic_output, mustWork = FALSE)
  diagnostic_phase_path <- sub('\\.csv$', '-phase.csv', diagnostic_output)
  if (dirname(diagnostic_output) != normalizePath(diagnostic_dir, mustWork = TRUE) ||
      !grepl('\\.csv$', diagnostic_output) || file.exists(diagnostic_output) ||
      file.exists(diagnostic_phase_path)) {
    stop('Diagnostic output must be a new CSV in dev/temporal-program/results/diagnostics/.', call. = FALSE)
  }
} else {
  diagnostic_phase_path <- NA_character_
}
write_diagnostic_phase <- function(phase, phi, seed,
                                   fit_elapsed_seconds = NA_real_,
                                   hessian_elapsed_seconds = NA_real_,
                                   gradient_elapsed_seconds = NA_real_,
                                   error_message = NA_character_) {
  if (!diagnostic) return(invisible(NULL))
  utils::write.csv(data.frame(phase = phase, phi = phi, seed = seed,
    fit_elapsed_seconds = fit_elapsed_seconds,
    hessian_elapsed_seconds = hessian_elapsed_seconds,
    gradient_elapsed_seconds = gradient_elapsed_seconds,
    error_message = error_message, stringsAsFactors = FALSE),
    diagnostic_phase_path, row.names = FALSE)
  invisible(NULL)
}
attempt_path <- function(index) file.path(root, sprintf(
  'dev/temporal-program/results/dep-spatial-recovery-attempt-%02d-20260911.csv', index))
if (finalize_only) {
  paths <- vapply(seq_len(nrow(full_plan)), attempt_path, character(1))
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop('missing retained dependent-spatial attempt receipt(s): ',
    paste(basename(missing), collapse = ', '), call. = FALSE)
  result <- do.call(rbind, lapply(paths, utils::read.csv, check.names = FALSE))
  if (nrow(result) != nrow(full_plan) || !setequal(result$phi, full_plan$phi) ||
      any(vapply(split(result$seed, result$phi), function(x) !setequal(x, 2609331:2609333), logical(1))))
    stop('attempt receipts do not retain every planned dependent-spatial attempt', call. = FALSE)
} else {
  plan <- full_plan; selected <- seq_len(nrow(plan))
  if (smoke) { plan <- data.frame(phi = .6, seed = 2609331L); selected <- NA_integer_ }
  if (one_requested) {
    one <- suppressWarnings(as.integer(one_text))
    if (is.na(one) || one < 1L || one > nrow(full_plan))
      stop('DEP_SPATIAL_ONE must select one planned attempt', call. = FALSE)
    plan <- full_plan[one, , drop = FALSE]; selected <- one
  }
  result_rows <- vector('list', nrow(plan))
  for (i in seq_len(nrow(plan))) {
    cat(sprintf('DEP_SPATIAL_ATTEMPT phi=%s seed=%s\n', plan$phi[[i]], plan$seed[[i]])); flush.console()
    result_rows[[i]] <- fit_one(plan$phi[[i]], plan$seed[[i]])
    if (!is.na(selected[[i]])) utils::write.csv(result_rows[[i]],
      if (diagnostic) diagnostic_output else attempt_path(selected[[i]]), row.names = FALSE)
  }
  result <- do.call(rbind, result_rows)
}
if (smoke) {
  print(result, row.names = FALSE)
  if (!identical(result$terminal[[1L]], 'success')) stop('Dependent-spatial smoke fit failed.', call. = FALSE)
  cat('TEMPORAL_DEP_SPATIAL_RECOVERY_SMOKE_PASS\n'); quit(save = 'no', status = 0L)
}
if (one_requested && !finalize_only) {
  print(result, row.names = FALSE)
  if (!all(result$terminal == 'success')) stop('Dependent-spatial recovery attempt failed.', call. = FALSE)
  if (diagnostic) cat('TEMPORAL_DEP_SPATIAL_DIAGNOSTIC_PASS\n')
  cat('TEMPORAL_DEP_SPATIAL_ATTEMPT_PASS\n'); quit(save = 'no', status = 0L)
}
for (j in 1:3) result[[paste0('tau_relative_error_', j)]] <-
  abs(result[[paste0('tau_', j)]] - truth$tau[[j]]) / truth$tau[[j]]
result$kappa_relative_error <- abs(result$kappa - truth$kappa) / truth$kappa
result$phi_absolute_error <- abs(result$phi_estimate - result$phi)
result$fixed_effect_mean_absolute_error <- vapply(seq_len(nrow(result)), function(i)
  mean(abs(as.numeric(result[i, paste0('beta_', 1:3)]) - truth$beta)), numeric(1))
summary <- do.call(rbind, lapply(split(result, result$phi), function(x) {
  ok <- x$terminal == 'success' & x$convergence == 0L & x$pass_2_convergence == 0L &
    x$pass_2_accepted & is.finite(x$max_gradient) & x$max_gradient <= 1e-3
  data.frame(phi = x$phi[[1L]], attempts = nrow(x), strict_successes = sum(ok),
    mean_phi_absolute_error = mean(x$phi_absolute_error[ok]),
    median_phi_absolute_error = median(x$phi_absolute_error[ok]),
    median_temporal_frobenius_relative_error = median(x$temporal_frobenius_relative_error[ok]),
    median_tau_1_relative_error = median(x$tau_relative_error_1[ok]),
    median_tau_2_relative_error = median(x$tau_relative_error_2[ok]),
    median_tau_3_relative_error = median(x$tau_relative_error_3[ok]),
    median_kappa_relative_error = median(x$kappa_relative_error[ok]),
    mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[ok]), stringsAsFactors = FALSE)
}))
summary$passes <- with(summary, strict_successes == 3L & mean_phi_absolute_error <= .15 &
  median_phi_absolute_error <= .20 & median_temporal_frobenius_relative_error <= .30 &
  median_tau_1_relative_error <= .35 & median_tau_2_relative_error <= .35 &
  median_tau_3_relative_error <= .35 & median_kappa_relative_error <= .50 &
  mean_fixed_effect_error <= .25)
result_path <- file.path(root, 'dev/temporal-program/results/dep-spatial-recovery-20260911.csv')
utils::write.csv(result, result_path, row.names = FALSE)
utils::write.csv(summary, file.path(root, 'dev/temporal-program/results/dep-spatial-recovery-summary-20260911.csv'), row.names = FALSE)
print(result, row.names = FALSE); print(summary, row.names = FALSE)
if (!all(summary$passes)) stop('Frozen temporal_dep-spatial recovery campaign fails its predeclared thresholds.', call. = FALSE)
cat('TEMPORAL_DEP_SPATIAL_RECOVERY_PASS\n')
