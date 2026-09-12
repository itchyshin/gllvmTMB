## Direct-DGP, disjoint 160-series qualification; never calls production simulation.

.temporal_dep_kernel_160_plan <- function() {
  x <- expand.grid(phi = c(-.4, 0, .6), seed = 2609341:2609343, KEEP.OUT.ATTRS = FALSE)
  x$n_series <- 160L
  x[order(x$phi, x$seed), c("phi", "seed", "n_series")]
}

.temporal_dep_kernel_160_validate <- function(phi, seed) {
  if (length(phi) != 1L || !is.numeric(phi) || !is.finite(phi) ||
      !any(abs(phi - c(-.4, 0, .6)) < .Machine$double.eps^0.5))
    stop("phi must be one frozen persistence value: -0.4, 0, or 0.6", call. = FALSE)
  if (length(seed) != 1L || !is.numeric(seed) || !is.finite(seed) ||
      !(as.integer(seed) %in% 2609341:2609343))
    stop("seed must be one disjoint qualification seed: 2609341:2609343", call. = FALSE)
  list(phi = as.numeric(phi), seed = as.integer(seed), n_series = 160L)
}

.temporal_dep_kernel_160_prerun <- function() list(phi = .6, seed = 2609340L, n_series = 160L)
.temporal_dep_kernel_160_truth <- function() list(beta = c(.2, -.3, .1),
  temporal_loading = rbind(c(.55, 0, 0), c(.12, .50, 0), c(-.08, .10, .48)),
  kernel_sd = c(.35, .28, .40), residual = .30)

.temporal_dep_kernel_160_fixture <- function(phi, seed) {
  key <- if (identical(as.integer(seed), 2609340L)) .temporal_dep_kernel_160_prerun() else .temporal_dep_kernel_160_validate(phi, seed)
  truth <- .temporal_dep_kernel_160_truth(); n_time <- 16L
  series <- paste0("s", seq_len(key$n_series)); traits <- paste0("t", 1:3)
  coordinate <- cbind(seq_len(key$n_series) / key$n_series, sin(seq_len(key$n_series) * .7))
  raw_K <- exp(-as.matrix(stats::dist(coordinate)) / .16) + diag(.08, key$n_series)
  K <- raw_K / sqrt(outer(diag(raw_K), diag(raw_K))); dimnames(K) <- list(series, series)
  set.seed(key$seed)
  static <- t(chol(K)) %*% sweep(matrix(stats::rnorm(key$n_series * 3L), key$n_series, 3L), 2L, truth$kernel_sd, "*")
  time_chol <- t(chol(tcrossprod(truth$temporal_loading))); state <- array(0, c(key$n_series, n_time, 3L))
  for (g in seq_len(key$n_series)) {
    state[g, 1L, ] <- drop(time_chol %*% stats::rnorm(3L))
    for (tt in 2:n_time) state[g, tt, ] <- key$phi * state[g, tt - 1L, ] + sqrt(1 - key$phi^2) * drop(time_chol %*% stats::rnorm(3L))
  }
  data <- expand.grid(series = series, occasion = seq_len(n_time), trait = traits, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  g <- match(data$series, series); tt <- data$occasion; j <- match(data$trait, traits)
  data$mean_value <- truth$beta[j] + state[cbind(g, tt, j)] + static[cbind(g, j)]
  data <- data[rep(seq_len(nrow(data)), each = 2L), , drop = FALSE]
  data$measurement <- rep(c("m1", "m2"), times = nrow(data) / 2L)
  data$value <- data$mean_value + stats::rnorm(nrow(data), sd = truth$residual); data$mean_value <- NULL
  list(data = data, K = K, truth = truth, phi = key$phi, seed = key$seed, n_series = key$n_series)
}

.temporal_dep_kernel_160_one <- function(phi, seed) {
  started <- proc.time()[["elapsed"]]
  key <- if (identical(as.integer(seed), 2609340L)) .temporal_dep_kernel_160_prerun() else .temporal_dep_kernel_160_validate(phi, seed)
  out <- tryCatch({
    fixture <- .temporal_dep_kernel_160_fixture(key$phi, key$seed)
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(value ~ 0 + trait +
      gllvmTMB::temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
      gllvmTMB::kernel_indep(series, K = fixture$K, name = "fixed_nonproportional_K"),
      data = fixture$data, unit = "series", cluster = "series", family = stats::gaussian(), silent = TRUE,
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE, optimizer = "optim",
        optArgs = list(method = "BFGS", control = list(maxit = 3000L, reltol = 1e-14)), optimizer_passes = 2L)))
    history <- fit$optimizer_pass_history
    if (!is.data.frame(history) || nrow(history) != 2L || !identical(history$pass, 1:2)) stop("fit did not retain the requested two optimizer passes", call. = FALSE)
    par <- fit$tmb_obj$env$parList(fit$opt$par); temporal <- gllvmTMB::extract_temporal(fit)
    hessian <- tryCatch(fit$tmb_obj$he(fit$opt$par), error = function(e) e)
    hs <- if (inherits(hessian, "error")) "error" else if (all(is.finite(hessian)) && !inherits(try(chol(hessian), silent = TRUE), "try-error")) "positive_definite" else "non_positive_definite"
    data.frame(phi = key$phi, seed = key$seed, n_series = key$n_series, terminal = "success", convergence = fit$opt$convergence,
      pass_1_convergence = history$convergence[[1L]], pass_2_convergence = history$convergence[[2L]], pass_2_accepted = history$accepted[[2L]],
      max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))), objective = fit$opt$objective, hessian_status = hs,
      phi_estimate = temporal$time$value[[1L]], temporal_frobenius_relative_error = sqrt(sum((tcrossprod(as.matrix(temporal$loading)) - tcrossprod(fixture$truth$temporal_loading))^2)) / sqrt(sum(tcrossprod(fixture$truth$temporal_loading)^2)),
      kernel_1 = par$theta_rr_phy[[1L]]^2, kernel_2 = par$theta_rr_phy[[2L]]^2, kernel_3 = par$theta_rr_phy[[3L]]^2,
      beta_1 = par$b_fix[[1L]], beta_2 = par$b_fix[[2L]], beta_3 = par$b_fix[[3L]], stringsAsFactors = FALSE)
  }, error = function(e) data.frame(phi = key$phi, seed = key$seed, n_series = key$n_series, terminal = "error", convergence = NA_integer_, pass_1_convergence = NA_integer_, pass_2_convergence = NA_integer_, pass_2_accepted = NA, max_gradient = NA_real_, objective = NA_real_, hessian_status = "error", phi_estimate = NA_real_, temporal_frobenius_relative_error = NA_real_, kernel_1 = NA_real_, kernel_2 = NA_real_, kernel_3 = NA_real_, beta_1 = NA_real_, beta_2 = NA_real_, beta_3 = NA_real_, stringsAsFactors = FALSE))
  out$elapsed_seconds <- proc.time()[["elapsed"]] - started; out
}

.temporal_dep_kernel_160_summarise <- function(result) {
  truth <- .temporal_dep_kernel_160_truth()
  for (j in 1:3) result[[paste0("kernel_relative_error_", j)]] <- abs(result[[paste0("kernel_", j)]] - truth$kernel_sd[[j]]^2) / truth$kernel_sd[[j]]^2
  result$phi_absolute_error <- abs(result$phi_estimate - result$phi)
  result$fixed_effect_mean_absolute_error <- rowMeans(abs(as.matrix(result[paste0("beta_", 1:3)]) - truth$beta))
  summary <- do.call(rbind, lapply(split(result, result$phi), function(x) {
    strict <- x$terminal == "success" & x$convergence == 0L & x$pass_2_convergence == 0L & x$pass_2_accepted & is.finite(x$max_gradient) & x$max_gradient <= 1e-3
    data.frame(phi = x$phi[[1L]], attempts = nrow(x), strict_successes = sum(strict), mean_phi_absolute_error = mean(x$phi_absolute_error[strict]), median_phi_absolute_error = stats::median(x$phi_absolute_error[strict]), median_temporal_frobenius_relative_error = stats::median(x$temporal_frobenius_relative_error[strict]), median_kernel_1_relative_error = stats::median(x$kernel_relative_error_1[strict]), median_kernel_2_relative_error = stats::median(x$kernel_relative_error_2[strict]), median_kernel_3_relative_error = stats::median(x$kernel_relative_error_3[strict]), mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[strict]), stringsAsFactors = FALSE)
  }))
  summary$passes <- with(summary, strict_successes == 3L & mean_phi_absolute_error <= .15 & median_phi_absolute_error <= .20 & median_temporal_frobenius_relative_error <= .30 & median_kernel_1_relative_error <= .35 & median_kernel_2_relative_error <= .35 & median_kernel_3_relative_error <= .35 & mean_fixed_effect_error <= .25)
  list(result = result, summary = summary, contract = "disjoint 160-series qualification only; no general recovery, solver, or release claim")
}

.temporal_dep_kernel_160_run <- function(phi = NULL, seed = NULL, pre_run = FALSE) {
  if (isTRUE(pre_run)) {
    if (!is.null(phi) || !is.null(seed)) stop("--pre-run cannot be combined with a campaign cell", call. = FALSE)
    x <- .temporal_dep_kernel_160_prerun(); return(list(result = .temporal_dep_kernel_160_one(x$phi, x$seed), summary = NULL, contract = "non-campaign timing pre-run only"))
  }
  if (xor(is.null(phi), is.null(seed))) stop("a campaign cell requires both phi and seed", call. = FALSE)
  if (is.null(phi)) { plan <- .temporal_dep_kernel_160_plan(); result <- do.call(rbind, Map(.temporal_dep_kernel_160_one, plan$phi, plan$seed)) } else { key <- .temporal_dep_kernel_160_validate(phi, seed); result <- .temporal_dep_kernel_160_one(key$phi, key$seed) }
  .temporal_dep_kernel_160_summarise(result)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE); pre_run <- "--pre-run" %in% args
  phi_arg <- grep("^--phi=", args, value = TRUE); seed_arg <- grep("^--seed=", args, value = TRUE); output_arg <- grep("^--output=", args, value = TRUE)
  allowed <- c("--pre-run", phi_arg, seed_arg, output_arg)
  if (length(phi_arg) > 1L || length(seed_arg) > 1L || length(output_arg) != 1L || !all(args %in% allowed) || xor(length(phi_arg) == 1L, length(seed_arg) == 1L) || (pre_run && (length(phi_arg) || length(seed_arg)))) stop("usage: Rscript --vanilla run-dep-kernel-160-qualification.R [--pre-run | --phi=VALUE --seed=N] --output=PATH", call. = FALSE)
  output <- sub("^--output=", "", output_arg); if (!nzchar(output) || file.exists(output)) stop("output must name a new result file", call. = FALSE)
  if (!dir.exists(dirname(output))) stop("output directory does not exist", call. = FALSE)
  pkgload::load_all(normalizePath(".", mustWork = TRUE), quiet = TRUE, export_all = FALSE)
  value <- .temporal_dep_kernel_160_run(if (length(phi_arg)) as.numeric(sub("^--phi=", "", phi_arg)) else NULL, if (length(seed_arg)) as.integer(sub("^--seed=", "", seed_arg)) else NULL, pre_run)
  temporary <- tempfile("dep-kernel-160-", tmpdir = dirname(output), fileext = ".rds"); saveRDS(value, temporary)
  if (!file.rename(temporary, output)) stop("could not atomically retain qualification output", call. = FALSE)
  print(value$result, row.names = FALSE); if (!is.null(value$summary)) print(value$summary, row.names = FALSE)
  cat(if (pre_run) "TEMPORAL_DEP_KERNEL_160_PRERUN_PASS\n" else "TEMPORAL_DEP_KERNEL_160_CELL_PASS\n")
}
