## Retained direct-DGP recovery for replicated AR1 temporal_dep + animal_indep.
## This generator is deliberately independent of the package simulation code.
root <- normalizePath(".", mustWork = TRUE)
pkgload::load_all(root, quiet = TRUE, export_all = FALSE)

args <- commandArgs(trailingOnly = TRUE)
smoke <- identical(args, "--smoke")
finalize_only <- identical(args, "--finalize")
truth <- list(
  beta = c(.2, -.3, .1),
  temporal_loading = rbind(c(.55, 0, 0), c(.12, .50, 0), c(-.08, .10, .48)),
  animal_sd = c(.35, .28, .40), residual = .30
)
truth$temporal_covariance <- tcrossprod(truth$temporal_loading)
n_series <- 80L; n_time <- 16L; n_measurement <- 2L
animal <- paste0("a", seq_len(n_series)); traits <- paste0("t", 1:3)
## A fixed labelled SPD relatedness matrix defines the direct animal DGP.
## This simulator does not call package simulation code.
Aanimal <- .45^abs(outer(seq_len(n_series), seq_len(n_series), `-`))
dimnames(Aanimal) <- list(animal, animal)

simulate_fixture <- function(phi, seed) {
  set.seed(seed)
  chol_time <- t(chol(truth$temporal_covariance))
  chol_animal <- t(chol(Aanimal))
  static <- chol_animal %*% sweep(matrix(rnorm(n_series * 3L), n_series, 3L),
    2L, truth$animal_sd, "*")
  state <- array(0, c(n_series, n_time, 3L))
  for (g in seq_len(n_series)) {
    state[g, 1L, ] <- drop(chol_time %*% rnorm(3L))
    for (tt in 2:n_time) {
      state[g, tt, ] <- phi * state[g, tt - 1L, ] +
        sqrt(1 - phi^2) * drop(chol_time %*% rnorm(3L))
    }
  }
  data <- expand.grid(animal = animal, occasion = seq_len(n_time), trait = traits,
    stringsAsFactors = FALSE)
  g <- match(data$animal, animal); tt <- data$occasion; j <- match(data$trait, traits)
  data$mean_value <- truth$beta[j] + state[cbind(g, tt, j)] + static[cbind(g, j)]
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
      value ~ 0 + trait + temporal_dep(0 + trait | animal, time = occasion,
        replicate = measurement) + animal_indep(0 + trait | animal, A = Aanimal),
      data = d, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE,
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
      max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))),
      objective = fit$opt$objective,
      hessian_status = hessian_status,
      phi_estimate = temporal$time$value[[1L]],
      temporal_frobenius_relative_error = relative_frobenius(temporal_covariance,
        truth$temporal_covariance),
      animal_1 = par$theta_rr_phy[[1L]]^2,
      animal_2 = par$theta_rr_phy[[2L]]^2,
      animal_3 = par$theta_rr_phy[[3L]]^2,
      beta_1 = beta[[1L]], beta_2 = beta[[2L]], beta_3 = beta[[3L]],
      stringsAsFactors = FALSE
    )
  }, error = function(e) data.frame(phi = phi, seed = seed, terminal = "error",
    convergence = NA_integer_, pass_1_convergence = NA_integer_,
    pass_2_convergence = NA_integer_, pass_2_accepted = NA,
    max_gradient = NA_real_, objective = NA_real_, hessian_status = "error", phi_estimate = NA_real_,
    temporal_frobenius_relative_error = NA_real_, animal_1 = NA_real_, animal_2 = NA_real_,
    animal_3 = NA_real_, beta_1 = NA_real_, beta_2 = NA_real_, beta_3 = NA_real_,
    stringsAsFactors = FALSE))
  out$elapsed_seconds <- proc.time()[["elapsed"]] - started
  out
}

full_plan <- expand.grid(phi = c(-.4, 0, .6), seed = 2609311:2609313)
full_plan <- full_plan[order(full_plan$phi, full_plan$seed), , drop = FALSE]
one_text <- Sys.getenv("DEP_ANIMAL_ONE", unset = "")
one_requested <- nzchar(one_text)
attempt_path <- function(index) file.path(root, sprintf(
  "dev/temporal-program/results/dep-animal-recovery-attempt-%02d-20260911.csv", index))
if (finalize_only) {
  paths <- vapply(seq_len(nrow(full_plan)), attempt_path, character(1))
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop("missing retained dependent-animal attempt receipt(s): ",
    paste(basename(missing), collapse = ", "), call. = FALSE)
  result <- do.call(rbind, lapply(paths, utils::read.csv, check.names = FALSE))
  if (nrow(result) != nrow(full_plan) || !setequal(result$phi, full_plan$phi) ||
      any(vapply(split(result$seed, result$phi), function(x) !setequal(x, 2609311:2609313), logical(1))))
    stop("attempt receipts do not retain every planned dependent-animal attempt", call. = FALSE)
} else {
  plan <- full_plan
  selected <- seq_len(nrow(plan))
  if (smoke) {
    plan <- data.frame(phi = .6, seed = 2609311L)
    selected <- NA_integer_
  }
  if (one_requested) {
    one <- suppressWarnings(as.integer(one_text))
    if (is.na(one) || one < 1L || one > nrow(full_plan))
      stop("DEP_ANIMAL_ONE must select one planned attempt", call. = FALSE)
    plan <- full_plan[one, , drop = FALSE]
    selected <- one
  }
  result_rows <- vector("list", nrow(plan))
  for (i in seq_len(nrow(plan))) {
    cat(sprintf("DEP_ANIMAL_ATTEMPT phi=%s seed=%s\n", plan$phi[[i]], plan$seed[[i]]))
    flush.console()
    result_rows[[i]] <- fit_one(plan$phi[[i]], plan$seed[[i]])
    if (!is.na(selected[[i]]))
      utils::write.csv(result_rows[[i]], attempt_path(selected[[i]]), row.names = FALSE)
  }
  result <- do.call(rbind, result_rows)
}

for (j in 1:3) result[[paste0("animal_relative_error_", j)]] <-
  abs(result[[paste0("animal_", j)]] - truth$animal_sd[[j]]^2) / truth$animal_sd[[j]]^2
result$phi_absolute_error <- abs(result$phi_estimate - result$phi)
result$fixed_effect_mean_absolute_error <- vapply(seq_len(nrow(result)), function(i) {
  mean(abs(as.numeric(result[i, paste0("beta_", 1:3)]) - truth$beta))
}, numeric(1))

if (smoke) {
  print(result, row.names = FALSE)
  if (!all(result$terminal == "success"))
    stop("temporal dep-animal recovery smoke fit failed", call. = FALSE)
  cat("TEMPORAL_DEP_ANIMAL_RECOVERY_SMOKE_PASS\n")
  quit(save = "no", status = 0L)
}
if (one_requested && !finalize_only) {
  print(result, row.names = FALSE)
  if (!all(result$terminal == "success"))
    stop("temporal dep-animal recovery attempt failed", call. = FALSE)
  cat("TEMPORAL_DEP_ANIMAL_ATTEMPT_PASS\n")
  quit(save = "no", status = 0L)
}
summary <- do.call(rbind, lapply(split(result, result$phi), function(x) {
  strict <- x$terminal == "success" & x$convergence == 0L &
    x$pass_2_convergence == 0L & x$pass_2_accepted &
    is.finite(x$max_gradient) & x$max_gradient <= 1e-3
  data.frame(phi = x$phi[[1L]], attempts = nrow(x), strict_successes = sum(strict),
    mean_phi_absolute_error = mean(x$phi_absolute_error[strict]),
    median_phi_absolute_error = median(x$phi_absolute_error[strict]),
    median_temporal_frobenius_relative_error = median(x$temporal_frobenius_relative_error[strict]),
    median_animal_1_relative_error = median(x$animal_relative_error_1[strict]),
    median_animal_2_relative_error = median(x$animal_relative_error_2[strict]),
    median_animal_3_relative_error = median(x$animal_relative_error_3[strict]),
    mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[strict]),
    stringsAsFactors = FALSE)
}))
summary$passes <- with(summary, strict_successes == 3L &
  mean_phi_absolute_error <= .15 & median_phi_absolute_error <= .20 &
  median_temporal_frobenius_relative_error <= .30 &
  median_animal_1_relative_error <= .35 & median_animal_2_relative_error <= .35 &
  median_animal_3_relative_error <= .35 & mean_fixed_effect_error <= .25)
utils::write.csv(result, file.path(root, "dev/temporal-program/results/dep-animal-recovery-20260911.csv"), row.names = FALSE)
utils::write.csv(summary, file.path(root, "dev/temporal-program/results/dep-animal-recovery-summary-20260911.csv"), row.names = FALSE)
print(result, row.names = FALSE); print(summary, row.names = FALSE)
if (!all(summary$passes)) stop("Frozen temporal_dep-animal recovery campaign fails its predeclared thresholds.", call. = FALSE)
cat("TEMPORAL_DEP_ANIMAL_RECOVERY_PASS\n")
