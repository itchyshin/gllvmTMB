## Retained local recovery campaign: replicated AR1 temporal_indep + animal_indep.
## Direct DGP only; it never calls production temporal simulation.
## Frozen redesign after the retained 80-series initial fixture: 160 series,
## exact same dense covariance construction rule, 16 occasions, two measures,
## three traits, unchanged truths/thresholds/optimizer, and 10 fresh seeds/cell.
root <- normalizePath(".", mustWork = TRUE)
pkgload::load_all(root, quiet = TRUE, export_all = FALSE)

truth <- list(beta = c(.2, -.3, .1), temporal = c(.55, .42, .63)^2,
  animal = c(.35, .28, .40)^2, residual = .30)
n_series <- 160L; n_time <- 16L; n_replicate <- 2L
series <- paste0("sp", seq_len(n_series)); traits <- paste0("t", 1:3)
## One fixed, labelled pedigree relationship matrix. The two founders are
## unobserved parents of every remaining series, so the animal route exercises
## the sparse precision/marginalisation path rather than a generic kernel.
pedigree <- data.frame(
  id = series,
  sire = c(NA_character_, NA_character_, rep(series[[1L]], n_series - 2L)),
  dam = c(NA_character_, NA_character_, rep(series[[2L]], n_series - 2L)),
  stringsAsFactors = FALSE
)
A_animal <- pedigree_to_A(pedigree)
stopifnot(identical(rownames(A_animal), series),
  all(eigen(A_animal, symmetric = TRUE, only.values = TRUE)$values > 0))

simulate_fixture <- function(phi, seed) {
  set.seed(seed)
  U <- t(chol(A_animal)) %*% sweep(matrix(rnorm(n_series * 3L), n_series, 3L), 2L,
    sqrt(truth$animal), "*")
  Z <- array(0, c(n_series, n_time, 3L))
  for (j in 1:3) for (g in seq_len(n_series)) {
    Z[g, 1L, j] <- rnorm(1L, sd = sqrt(truth$temporal[j]))
    for (tt in 2:n_time) Z[g, tt, j] <- phi * Z[g, tt - 1L, j] +
      sqrt(1 - phi^2) * rnorm(1L, sd = sqrt(truth$temporal[j]))
  }
  data <- expand.grid(series = series, occasion = seq_len(n_time), trait = traits,
    stringsAsFactors = FALSE)
  g <- match(data$series, series); tt <- data$occasion; j <- match(data$trait, traits)
  data$mean_value <- truth$beta[j] + Z[cbind(g, tt, j)] + U[cbind(g, j)]
  data <- data[rep(seq_len(nrow(data)), each = n_replicate), , drop = FALSE]
  data$measurement <- rep(c("m1", "m2"), times = nrow(data) / n_replicate)
  data$value <- data$mean_value + rnorm(nrow(data), sd = truth$residual)
  data$mean_value <- NULL
  data
}

fit_one <- function(phi, seed) {
  started <- proc.time()[["elapsed"]]
  d <- simulate_fixture(phi, seed)
  out <- tryCatch({
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait +
        temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
        animal_indep(0 + trait | series, pedigree = pedigree),
      data = d, unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
      control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
        optArgs = list(method = "BFGS", control = list(maxit = 3000, reltol = 1e-14)),
        optimizer_passes = 2L)
    ))
    h <- fit$optimizer_pass_history
    if (!is.data.frame(h) || nrow(h) != 2L || !all(h$pass == 1:2))
      stop("The requested two-pass optimizer history was not retained.", call. = FALSE)
    temporal <- extract_temporal(fit); beta <- unname(fit$opt$par[names(fit$opt$par) == "b_fix"])
    p <- fit$tmb_obj$env$parList(fit$opt$par)
    data.frame(phi = phi, seed = seed, terminal = "success", convergence = fit$opt$convergence,
      pass_1_convergence = h$convergence[[1L]], pass_2_convergence = h$convergence[[2L]],
      pass_2_accepted = h$accepted[[2L]], max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))),
      objective = fit$opt$objective, phi_estimate = temporal$time$value[[1L]],
      temporal_1 = temporal$variance$value[[1L]], temporal_2 = temporal$variance$value[[2L]], temporal_3 = temporal$variance$value[[3L]],
      animal_1 = p$theta_rr_phy[1L]^2, animal_2 = p$theta_rr_phy[2L]^2, animal_3 = p$theta_rr_phy[3L]^2,
      beta_1 = beta[[1L]], beta_2 = beta[[2L]], beta_3 = beta[[3L]], stringsAsFactors = FALSE)
  }, error = function(e) data.frame(phi = phi, seed = seed, terminal = "error",
    convergence = NA_integer_, pass_1_convergence = NA_integer_, pass_2_convergence = NA_integer_,
    pass_2_accepted = NA, max_gradient = NA_real_, objective = NA_real_, phi_estimate = NA_real_,
    temporal_1 = NA_real_, temporal_2 = NA_real_, temporal_3 = NA_real_, animal_1 = NA_real_,
    animal_2 = NA_real_, animal_3 = NA_real_, beta_1 = NA_real_, beta_2 = NA_real_, beta_3 = NA_real_))
  out$elapsed_seconds <- proc.time()[["elapsed"]] - started; out
}

plan <- expand.grid(phi = c(-.4, 0, .6), seed = 2609201:2609210)
plan <- plan[order(plan$phi, plan$seed), , drop = FALSE]
is_smoke <- identical(Sys.getenv("TEMPORAL_RECOVERY_SMOKE"), "1")
if (is_smoke) plan <- data.frame(phi = .6, seed = 2609200L)
result_path <- if (is_smoke) tempfile("temporal-animal-smoke-", fileext = ".csv") else
  file.path(root, "dev/temporal-program/results/animal-recovery-160-20260909.csv")
## Checkpoint each retained attempt. A stopped process can therefore resume the
## exact frozen plan without discarding already completed seed--phi cells.
result <- if (file.exists(result_path)) utils::read.csv(result_path, check.names = FALSE) else NULL
if (!is.null(result) && anyDuplicated(result[c("phi", "seed")])) {
  stop("Animal recovery checkpoint has duplicate phi--seed attempts.", call. = FALSE)
}
if (!is.null(result) && any(!paste(result$phi, result$seed) %in%
    paste(plan$phi, plan$seed))) {
  stop("Animal recovery checkpoint contains attempts outside the frozen plan.", call. = FALSE)
}
for (i in seq_len(nrow(plan))) {
  phi_i <- plan$phi[[i]]; seed_i <- plan$seed[[i]]
  already_done <- !is.null(result) && any(result$phi == phi_i & result$seed == seed_i)
  if (already_done) next
  attempt <- fit_one(phi_i, seed_i)
  result <- if (is.null(result)) attempt else rbind(result, attempt)
  result <- result[order(result$phi, result$seed), , drop = FALSE]
  utils::write.csv(result, result_path, row.names = FALSE)
  cat(sprintf("CHECKPOINT phi=%s seed=%s elapsed=%.3f\\n", phi_i, seed_i, attempt$elapsed_seconds[[1L]]))
  flush.console()
  gc(verbose = FALSE)
}
if (nrow(result) == 1L) {
  print(result, row.names = FALSE); cat("TEMPORAL_ANIMAL_RECOVERY_SMOKE_PASS\n")
  quit(save = "no", status = if (identical(result$terminal, "success")) 0L else 1L)
}
for (j in 1:3) {
  result[[paste0("temporal_relative_error_", j)]] <- abs(result[[paste0("temporal_", j)]] - truth$temporal[j]) / truth$temporal[j]
  result[[paste0("animal_relative_error_", j)]] <- abs(result[[paste0("animal_", j)]] - truth$animal[j]) / truth$animal[j]
}
result$phi_absolute_error <- abs(result$phi_estimate - result$phi)
result$fixed_effect_mean_absolute_error <- vapply(seq_len(nrow(result)), function(i) mean(abs(as.numeric(result[i, paste0("beta_", 1:3)]) - truth$beta)), numeric(1))
summary <- do.call(rbind, lapply(split(result, result$phi), function(x) {
  ok <- x$terminal == "success" & x$convergence == 0L & x$pass_2_convergence == 0L & x$pass_2_accepted &
    is.finite(x$max_gradient) & x$max_gradient <= 1e-3
  data.frame(phi = x$phi[[1L]], attempts = nrow(x), strict_successes = sum(ok),
    mean_phi_absolute_error = mean(x$phi_absolute_error[ok]), median_phi_absolute_error = median(x$phi_absolute_error[ok]),
    median_temporal_1_relative_error = median(x$temporal_relative_error_1[ok]), median_temporal_2_relative_error = median(x$temporal_relative_error_2[ok]), median_temporal_3_relative_error = median(x$temporal_relative_error_3[ok]),
    median_animal_1_relative_error = median(x$animal_relative_error_1[ok]), median_animal_2_relative_error = median(x$animal_relative_error_2[ok]), median_animal_3_relative_error = median(x$animal_relative_error_3[ok]),
    mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[ok]), stringsAsFactors = FALSE)
}))
summary$passes <- with(summary, strict_successes == 10L & mean_phi_absolute_error <= .15 & median_phi_absolute_error <= .20 &
  median_temporal_1_relative_error <= .35 & median_temporal_2_relative_error <= .35 & median_temporal_3_relative_error <= .35 &
  median_animal_1_relative_error <= .35 & median_animal_2_relative_error <= .35 & median_animal_3_relative_error <= .35 & mean_fixed_effect_error <= .25)
write.csv(result, result_path, row.names = FALSE)
write.csv(summary, file.path(root, "dev/temporal-program/results/animal-recovery-160-summary-20260909.csv"), row.names = FALSE)
print(result, row.names = FALSE); print(summary, row.names = FALSE)
if (!all(summary$passes)) stop("Frozen 160-series animal recovery campaign fails its predeclared thresholds.", call. = FALSE)
cat("TEMPORAL_ANIMAL_RECOVERY_PASS\n")
