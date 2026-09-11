## Retained direct-DGP recovery for replicated AR1 temporal_latent + phylo_indep.
## The generator is deliberately independent of the package simulation code.
root <- normalizePath(".", mustWork = TRUE)
pkgload::load_all(root, quiet = TRUE, export_all = FALSE)

args <- commandArgs(trailingOnly = TRUE)
smoke <- identical(args, "--smoke")
truth <- list(
  beta = c(.2, -.3, .1), temporal_loading = c(.55, .40, -.35),
  phylo_sd = c(.35, .28, .40), residual = .30
)
truth$temporal_covariance <- tcrossprod(truth$temporal_loading)
n_series <- 80L; n_time <- 16L; n_measurement <- 2L
series <- paste0("s", seq_len(n_series)); traits <- paste0("t", 1:3)
## This fixed tree and its correlation matrix are part of the DGP, not a
## package simulation route.  The model is supplied the same labelled matrix.
set.seed(2609240L)
phylo_tree <- ape::rcoal(n_series)
phylo_tree$tip.label <- series
Cphy <- ape::vcv(phylo_tree, corr = TRUE)

simulate_fixture <- function(phi, seed) {
  set.seed(seed)
  static <- t(chol(Cphy)) %*% sweep(matrix(rnorm(n_series * 3L), n_series, 3L),
    2L, truth$phylo_sd, "*")
  state <- matrix(0, n_series, n_time)
  state[, 1L] <- rnorm(n_series)
  for (tt in 2:n_time) state[, tt] <- phi * state[, tt - 1L] +
    sqrt(1 - phi^2) * rnorm(n_series)
  data <- expand.grid(series = series, occasion = seq_len(n_time), trait = traits,
    stringsAsFactors = FALSE)
  g <- match(data$series, series); tt <- data$occasion; j <- match(data$trait, traits)
  data$mean_value <- truth$beta[j] + state[cbind(g, tt)] * truth$temporal_loading[j] +
    static[cbind(g, j)]
  data <- data[rep(seq_len(nrow(data)), each = n_measurement), , drop = FALSE]
  data$measurement <- rep(paste0("m", seq_len(n_measurement)), times = nrow(data) / n_measurement)
  data$value <- data$mean_value + rnorm(nrow(data), sd = truth$residual)
  data$mean_value <- NULL
  data
}

relative_frobenius <- function(x, y) sqrt(sum((x - y)^2)) / sqrt(sum(y^2))

fit_one <- function(phi, seed) {
  started <- proc.time()[["elapsed"]]
  out <- tryCatch({
    d <- simulate_fixture(phi, seed)
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion,
        replicate = measurement, d = 1, unique = FALSE) +
        phylo_indep(0 + trait | series, vcv = Cphy),
      data = d, unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
      control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
        optArgs = list(method = "BFGS", control = list(maxit = 3000, reltol = 1e-14)),
        optimizer_passes = 2L)
    ))
    history <- fit$optimizer_pass_history
    if (!is.data.frame(history) || nrow(history) != 2L || !all(history$pass == 1:2))
      stop("The requested two-pass optimizer history was not retained.", call. = FALSE)
    par <- fit$tmb_obj$env$parList(fit$opt$par)
    temporal <- extract_temporal(fit)
    temporal_covariance <- tcrossprod(as.matrix(temporal$loading))
    beta <- unname(par$b_fix)
    hessian <- tryCatch(fit$tmb_obj$he(fit$opt$par), error = function(e) e)
    hessian_status <- if (inherits(hessian, "error")) "error" else if (
      all(is.finite(hessian)) && !inherits(try(chol(hessian), silent = TRUE), "try-error")
    ) "positive_definite" else "non_positive_definite"
    data.frame(phi = phi, seed = seed, terminal = "success",
      convergence = fit$opt$convergence,
      pass_1_convergence = history$convergence[[1L]],
      pass_2_convergence = history$convergence[[2L]],
      pass_2_accepted = history$accepted[[2L]],
      max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))), objective = fit$opt$objective,
      hessian_status = hessian_status, phi_estimate = temporal$time$value[[1L]],
      temporal_frobenius_relative_error = relative_frobenius(temporal_covariance,
        truth$temporal_covariance),
      phylo_1 = par$theta_rr_phy[[1L]]^2, phylo_2 = par$theta_rr_phy[[2L]]^2,
      phylo_3 = par$theta_rr_phy[[3L]]^2,
      beta_1 = beta[[1L]], beta_2 = beta[[2L]], beta_3 = beta[[3L]],
      stringsAsFactors = FALSE
    )
  }, error = function(e) data.frame(phi = phi, seed = seed, terminal = "error",
    convergence = NA_integer_, pass_1_convergence = NA_integer_, pass_2_convergence = NA_integer_,
    pass_2_accepted = NA, max_gradient = NA_real_, objective = NA_real_, hessian_status = "error",
    phi_estimate = NA_real_, temporal_frobenius_relative_error = NA_real_,
    phylo_1 = NA_real_, phylo_2 = NA_real_, phylo_3 = NA_real_,
    beta_1 = NA_real_, beta_2 = NA_real_, beta_3 = NA_real_, stringsAsFactors = FALSE))
  out$elapsed_seconds <- proc.time()[["elapsed"]] - started
  out
}

plan <- expand.grid(phi = c(-.4, 0, .6), seed = 2609241:2609243)
plan <- plan[order(plan$phi, plan$seed), , drop = FALSE]
if (smoke) plan <- data.frame(phi = .6, seed = 2609241L)
result <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) fit_one(plan$phi[[i]], plan$seed[[i]])))
for (j in 1:3) result[[paste0("phylo_relative_error_", j)]] <-
  abs(result[[paste0("phylo_", j)]] - truth$phylo_sd[[j]]^2) / truth$phylo_sd[[j]]^2
result$phi_absolute_error <- abs(result$phi_estimate - result$phi)
result$fixed_effect_mean_absolute_error <- vapply(seq_len(nrow(result)), function(i) {
  mean(abs(as.numeric(result[i, paste0("beta_", 1:3)]) - truth$beta))
}, numeric(1))

if (smoke) {
  print(result, row.names = FALSE)
  cat("TEMPORAL_LATENT_PHYLO_RECOVERY_SMOKE_PASS\n")
  quit(save = "no", status = if (all(result$terminal == "success")) 0L else 1L)
}
summary <- do.call(rbind, lapply(split(result, result$phi), function(x) {
  strict <- x$terminal == "success" & x$convergence == 0L &
    x$pass_2_convergence == 0L & x$pass_2_accepted & is.finite(x$max_gradient) & x$max_gradient <= 1e-3
  data.frame(phi = x$phi[[1L]], attempts = nrow(x), strict_successes = sum(strict),
    mean_phi_absolute_error = mean(x$phi_absolute_error[strict]),
    median_phi_absolute_error = median(x$phi_absolute_error[strict]),
    median_temporal_frobenius_relative_error = median(x$temporal_frobenius_relative_error[strict]),
    median_phylo_1_relative_error = median(x$phylo_relative_error_1[strict]),
    median_phylo_2_relative_error = median(x$phylo_relative_error_2[strict]),
    median_phylo_3_relative_error = median(x$phylo_relative_error_3[strict]),
    mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[strict]), stringsAsFactors = FALSE)
}))
summary$passes <- with(summary, strict_successes == 3L &
  mean_phi_absolute_error <= .15 & median_phi_absolute_error <= .20 &
  median_temporal_frobenius_relative_error <= .30 &
  median_phylo_1_relative_error <= .35 & median_phylo_2_relative_error <= .35 &
  median_phylo_3_relative_error <= .35 & mean_fixed_effect_error <= .25)
utils::write.csv(result, file.path(root, "dev/temporal-program/results/latent-phylo-recovery-20260911.csv"), row.names = FALSE)
utils::write.csv(summary, file.path(root, "dev/temporal-program/results/latent-phylo-recovery-summary-20260911.csv"), row.names = FALSE)
print(result, row.names = FALSE); print(summary, row.names = FALSE)
if (!all(summary$passes)) stop("Frozen temporal-latent-phylo recovery campaign fails its predeclared thresholds.", call. = FALSE)
cat("TEMPORAL_LATENT_PHYLO_RECOVERY_PASS\n")
