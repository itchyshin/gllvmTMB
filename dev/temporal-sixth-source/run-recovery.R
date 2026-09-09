## Fixed-seed, eight-cell temporal recovery evidence.
##
## The DGP below constructs dense Gaussian covariance directly. It never calls
## production temporal simulation, report, or extractor code to generate data.
## The earlier two-cell receipt in .unlazy/temporal-grid is retained as a timing
## smoke only; this script is the only G7 recovery program.

root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) stop("Run from the package root.", call. = FALSE)
pkgload::load_all(root, quiet = TRUE, export_all = FALSE)

.temporal_recovery_cells <- data.frame(
  cell = c("ar1_indep", "ar1_dep", "ar1_latent", "ar1_latent_unique",
           "ou_indep", "ou_dep", "ou_latent", "ou_latent_unique"),
  structure = rep(c("ar1", "ou"), each = 4L),
  mode = rep(c("indep", "dep", "latent", "latent"), 2L),
  unique = rep(c(FALSE, FALSE, FALSE, TRUE), 2L),
  stringsAsFactors = FALSE
)

.temporal_recovery_truth <- function(mode, unique) {
  lambda <- c(0.65, -0.45, 0.35)
  if (identical(mode, "indep")) return(diag(c(0.30, 0.55, 0.40)))
  if (identical(mode, "dep")) {
    L <- matrix(c(0.80, 0, 0, 0.25, 0.65, 0, -0.15, 0.20, 0.55), 3, 3, byrow = TRUE)
    return(tcrossprod(L))
  }
  S <- tcrossprod(lambda)
  if (isTRUE(unique)) S <- S + diag(c(0.30, 0.40, 0.25))
  S
}

.temporal_recovery_dgp <- function(cell, seed) {
  set.seed(seed)
  structure <- cell$structure[[1L]]
  time <- if (identical(structure, "ar1")) c(1, 3, 4, 8) else c(0, 0.5, 2, 5)
  time_col <- if (identical(structure, "ar1")) "occasion" else "elapsed"
  phi <- if (identical(structure, "ar1")) 0.55 else NA_real_
  rate <- if (identical(structure, "ou")) 0.7 else NA_real_
  states <- data.frame(series = rep(paste0("s", seq_len(12L)), each = length(time)),
    time = rep(time, times = 12L), stringsAsFactors = FALSE)
  distance <- abs(outer(states$time, states$time, FUN = "-"))
  K <- if (identical(structure, "ar1")) phi^distance else exp(-rate * distance)
  K[outer(states$series, states$series, FUN = "!=")] <- 0
  traits <- paste0("t", 1:3)
  state <- rep(seq_len(nrow(states)), each = length(traits))
  trait <- rep(seq_along(traits), times = nrow(states))
  Sigma <- .temporal_recovery_truth(cell$mode[[1L]], cell$unique[[1L]])
  V <- K[state, state] * Sigma[trait, trait]
  diag(V) <- diag(V) + 0.30^2
  y <- c(0.3, -0.2, 0.15)[trait] + drop(t(chol(V)) %*% stats::rnorm(nrow(V)))
  dat <- states[state, , drop = FALSE]
  names(dat)[names(dat) == "time"] <- time_col
  dat$trait <- traits[trait]
  dat$value <- y
  list(data = dat, Sigma = Sigma, time_truth = if (identical(structure, "ar1")) phi else rate)
}

.temporal_recovery_formula <- function(cell) {
  structure <- cell$structure[[1L]]
  unique_text <- if (isTRUE(cell$unique[[1L]])) "TRUE" else "FALSE"
  if (identical(structure, "ar1")) {
    if (identical(cell$mode[[1L]], "indep")) return(value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion))
    if (identical(cell$mode[[1L]], "dep")) return(value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion))
    return(stats::as.formula(sprintf("value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion, d = 1, unique = %s)", unique_text)))
  }
  if (identical(cell$mode[[1L]], "indep")) return(value ~ 0 + trait + temporal_indep(0 + trait | series, time = elapsed, structure = "ou"))
  if (identical(cell$mode[[1L]], "dep")) return(value ~ 0 + trait + temporal_dep(0 + trait | series, time = elapsed, structure = "ou"))
  stats::as.formula(sprintf("value ~ 0 + trait + temporal_latent(0 + trait | series, time = elapsed, d = 1, unique = %s, structure = \"ou\")", unique_text))
}

.temporal_recovery_sigma <- function(fit) {
  out <- extract_temporal(fit)
  if (identical(out$parameters$mode[[1L]], "indep")) return(diag(out$variance$value))
  S <- tcrossprod(as.matrix(out$loadings))
  if (nrow(out$variance)) S <- S + diag(out$variance$value)
  S
}

.temporal_recovery_fit <- function(cell, seed) {
  dgp <- .temporal_recovery_dgp(cell, seed)
  elapsed <- system.time({
    fit <- tryCatch(suppressWarnings(gllvmTMB(.temporal_recovery_formula(cell),
      data = dgp$data, unit = "series", family = gaussian(), silent = TRUE)), error = identity)
  })[["elapsed"]]
  base <- data.frame(cell = as.character(cell$cell[[1L]]),
    structure = as.character(cell$structure[[1L]]), mode = as.character(cell$mode[[1L]]),
    unique = as.logical(cell$unique[[1L]]), seed = seed, elapsed_seconds = elapsed, convergence = NA_integer_,
    objective = NA_real_, time_estimate = NA_real_, time_error = NA_real_,
    sigma_relative_error = NA_real_, gradient_finite = FALSE,
    terminal = "error", detail = "", stringsAsFactors = FALSE)
  if (inherits(fit, "error")) {
    base$detail <- conditionMessage(fit)
    return(base)
  }
  time_estimate <- extract_temporal(fit)$time$value[[1L]]
  Sigma <- tryCatch(.temporal_recovery_sigma(fit), error = function(e) e)
  gradient <- tryCatch(fit$tmb_obj$gr(fit$opt$par), error = function(e) NA_real_)
  base$convergence <- as.integer(fit$opt$convergence)
  base$objective <- fit$opt$objective
  base$time_estimate <- time_estimate
  base$gradient_finite <- length(gradient) > 0L && all(is.finite(gradient))
  if (!inherits(Sigma, "error")) {
    base$sigma_relative_error <- sqrt(sum((Sigma - dgp$Sigma)^2)) / sqrt(sum(dgp$Sigma^2))
  }
  base$time_error <- if (identical(cell$structure[[1L]], "ar1")) {
    abs(time_estimate - dgp$time_truth)
  } else abs(time_estimate / dgp$time_truth - 1)
  good <- identical(base$convergence, 0L) && is.finite(base$objective) &&
    is.finite(base$time_estimate) && is.finite(base$sigma_relative_error) && base$gradient_finite
  base$terminal <- if (good) "success" else "fit_health_failure"
  base$detail <- if (good) "finite converged fit" else
    "failure criterion: exception, nonzero convergence, or nonfinite objective/time/Sigma/gradient"
  base
}

.temporal_recovery_plan <- function(n_seed = 10L) {
  do.call(rbind, lapply(seq_len(nrow(.temporal_recovery_cells)), function(i) {
    cell <- .temporal_recovery_cells[i, , drop = FALSE]
    data.frame(cell = rep(cell$cell[[1L]], n_seed),
      structure = rep(cell$structure[[1L]], n_seed),
      mode = rep(cell$mode[[1L]], n_seed), unique = rep(cell$unique[[1L]], n_seed),
      seed = 26091300L + 100L * i + seq_len(n_seed), stringsAsFactors = FALSE)
  }))
}

.temporal_recovery_summary <- function(attempts) {
  do.call(rbind, lapply(split(attempts, attempts$cell), function(x) {
    success <- x$terminal == "success"
    time_limit <- if (identical(x$structure[[1L]], "ar1")) 0.35 else 0.75
    sigma_limit <- 0.75
    med_time <- if (any(success)) median(x$time_error[success]) else NA_real_
    med_sigma <- if (any(success)) median(x$sigma_relative_error[success]) else NA_real_
    data.frame(cell = x$cell[[1L]], structure = x$structure[[1L]], mode = x$mode[[1L]],
      unique = x$unique[[1L]], attempts = nrow(x), successes = sum(success), failures = sum(!success),
      median_time_error = med_time, median_sigma_relative_error = med_sigma,
      time_threshold = time_limit, sigma_threshold = sigma_limit,
      bounded_cell_pass = sum(success) >= 8L && is.finite(med_time) && med_time <= time_limit &&
        is.finite(med_sigma) && med_sigma <= sigma_limit, total_seconds = sum(x$elapsed_seconds),
      stringsAsFactors = FALSE)
  }))
}

mode <- commandArgs(trailingOnly = TRUE)
if (length(mode) > 1L || (length(mode) == 1L && !mode %in% c("timing", "campaign", "verify"))) {
  stop("Usage: Rscript --vanilla dev/temporal-sixth-source/run-recovery.R [timing|campaign|verify]", call. = FALSE)
}
mode <- if (length(mode)) mode[[1L]] else "timing"
out_dir <- file.path(root, ".unlazy", "temporal-grid")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
timing_path <- file.path(out_dir, "recovery-eight-cell-timing.csv")
attempt_path <- file.path(out_dir, "recovery-eight-cell-attempts.csv")
summary_path <- file.path(out_dir, "recovery-eight-cell-summary.csv")

if (identical(mode, "timing")) {
  timing <- do.call(rbind, lapply(seq_len(nrow(.temporal_recovery_cells)), function(i) {
    .temporal_recovery_fit(.temporal_recovery_cells[i, , drop = FALSE], 26091200L + i)
  }))
  utils::write.csv(timing, timing_path, row.names = FALSE)
  projection_minutes <- nrow(.temporal_recovery_plan()) * max(timing$elapsed_seconds) / 60
  print(timing[c("cell", "terminal", "elapsed_seconds")], row.names = FALSE)
  cat(sprintf("TEMPORAL_SIXTH_EIGHT_CELL_80_FIT_PROJECTION_MINUTES %.3f\n", projection_minutes))
  if (!all(timing$terminal == "success")) stop("An eight-cell timing fit failed its predeclared terminal criteria.", call. = FALSE)
  cat("TEMPORAL_SIXTH_TIMING_PASS\n")
  quit(save = "no", status = 0L)
}

plan <- .temporal_recovery_plan()
if (identical(mode, "verify")) {
  if (!file.exists(attempt_path) || !file.exists(summary_path)) stop("No eight-cell retained recovery receipt is available.", call. = FALSE)
  attempts <- utils::read.csv(attempt_path, stringsAsFactors = FALSE)
  if (nrow(attempts) != nrow(plan) || !identical(attempts[c("cell", "seed")], plan[c("cell", "seed")]) ||
      any(!attempts$terminal %in% c("success", "error", "fit_health_failure"))) {
    stop("Eight-cell recovery receipt is incomplete or differs from its frozen plan.", call. = FALSE)
  }
  recomputed <- .temporal_recovery_summary(attempts)
  recorded <- utils::read.csv(summary_path, stringsAsFactors = FALSE)
  check_columns <- c("cell", "attempts", "successes", "failures", "median_time_error",
    "median_sigma_relative_error", "time_threshold", "sigma_threshold", "bounded_cell_pass")
  if (!identical(recorded$cell, recomputed$cell) ||
      !isTRUE(all.equal(recorded[check_columns], recomputed[check_columns], check.attributes = FALSE))) {
    stop("Eight-cell recovery summary does not reproduce the frozen thresholds and recorded results.", call. = FALSE)
  }
  if (!all(recomputed$bounded_cell_pass)) {
    stop("Eight-cell recovery receipt fails one or more frozen per-cell recovery thresholds.", call. = FALSE)
  }
  cat("TEMPORAL_SIXTH_RECOVERY_PASS\n")
  quit(save = "no", status = 0L)
}

if (!file.exists(timing_path)) stop("Run eight-cell timing before its retained campaign.", call. = FALSE)
timing <- utils::read.csv(timing_path, stringsAsFactors = FALSE)
if (nrow(timing) != nrow(.temporal_recovery_cells) || !all(timing$terminal == "success")) {
  stop("Eight-cell campaign requires eight successful timing fixtures.", call. = FALSE)
}
if (file.exists(attempt_path)) stop("Eight-cell attempt receipt already exists; refusing to replace retained evidence.", call. = FALSE)
budget_seconds <- nrow(plan) * max(timing$elapsed_seconds)
started <- proc.time()[["elapsed"]]
for (i in seq_len(nrow(plan))) {
  result <- .temporal_recovery_fit(plan[i, names(.temporal_recovery_cells), drop = FALSE], plan$seed[[i]])
  utils::write.table(result, attempt_path, sep = ",", row.names = FALSE,
    col.names = !file.exists(attempt_path), append = file.exists(attempt_path), quote = TRUE)
  if ((proc.time()[["elapsed"]] - started) > budget_seconds) {
    stop(sprintf("Eight-cell campaign exceeded its frozen %.3f-second budget after %d attempts.", budget_seconds, i), call. = FALSE)
  }
}
attempts <- utils::read.csv(attempt_path, stringsAsFactors = FALSE)
if (nrow(attempts) != nrow(plan) || anyDuplicated(attempts[c("cell", "seed")])) {
  stop("Eight-cell campaign did not retain exactly one terminal row for every fixed seed.", call. = FALSE)
}
summary <- .temporal_recovery_summary(attempts)
utils::write.csv(summary, summary_path, row.names = FALSE)
print(summary, row.names = FALSE)
cat("TEMPORAL_SIXTH_RECOVERY_PASS\n")
