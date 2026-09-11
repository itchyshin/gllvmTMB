## Information-size diagnostic for the retained temporal_dep() + kernel_indep()
## positive-AR1 recovery deficit.  The direct generator is independently
## authored in verify-dep-kernel-retained-oracle.R; this file never calls the
## production temporal simulator and never changes the frozen recovery receipt.

.temporal_dep_kernel_information_source <- function() {
  candidates <- c(
    file.path("dev", "temporal-program", "verify-dep-kernel-retained-oracle.R"),
    file.path("..", "dev", "temporal-program", "verify-dep-kernel-retained-oracle.R")
  )
  path <- candidates[file.exists(candidates)][1L]
  if (is.na(path)) stop("cannot locate the retained independent oracle", call. = FALSE)
  source(path, local = globalenv())
  invisible(normalizePath(path))
}

.temporal_dep_kernel_information_seeds <- function() 2609221:2609223
.temporal_dep_kernel_information_sizes <- function() c(80L, 160L)

.temporal_dep_kernel_information_require_oracle <- function() {
  required <- c(".temporal_dep_kernel_retained_fixture",
    ".temporal_dep_kernel_retained_fit", ".temporal_dep_kernel_retained_parameter",
    ".temporal_dep_kernel_retained_unpack", ".temporal_dep_kernel_retained_relative_frobenius")
  missing <- required[!vapply(required, exists, logical(1), inherits = TRUE)]
  if (length(missing)) stop("source the retained independent oracle first: ",
    paste(missing, collapse = ", "), call. = FALSE)
}

.temporal_dep_kernel_information_validate <- function(n_series, seed) {
  if (length(n_series) != 1L || !is.numeric(n_series) ||
      !(as.integer(n_series) %in% .temporal_dep_kernel_information_sizes())) {
    stop("n_series must be one frozen diagnostic size: 80 or 160", call. = FALSE)
  }
  if (length(seed) != 1L || !is.numeric(seed) ||
      !(as.integer(seed) %in% .temporal_dep_kernel_information_seeds())) {
    stop("seed must be one retained diagnostic seed: 2609221:2609223", call. = FALSE)
  }
  list(n_series = as.integer(n_series), seed = as.integer(seed))
}

.temporal_dep_kernel_information_one <- function(n_series, seed) {
  .temporal_dep_kernel_information_require_oracle()
  key <- .temporal_dep_kernel_information_validate(n_series, seed)
  started <- proc.time()[["elapsed"]]
  out <- tryCatch({
    fixture <- .temporal_dep_kernel_retained_fixture(
      seed = key$seed, phi = .6, n_series = key$n_series, n_time = 16L
    )
    fit <- .temporal_dep_kernel_retained_fit(fixture)
    history <- fit$optimizer_pass_history
    if (!is.data.frame(history) || nrow(history) != 2L || !identical(history$pass, 1:2)) {
      stop("fit did not retain the requested two optimizer passes", call. = FALSE)
    }
    fixed <- fit$opt$par
    par <- .temporal_dep_kernel_retained_parameter(fit, fixed)
    temporal <- tcrossprod(.temporal_dep_kernel_retained_unpack(par$theta_temporal_rr))
    kernel <- par$theta_rr_phy[1:3]^2
    data.frame(
      n_series = key$n_series, seed = key$seed, terminal = "success",
      convergence = fit$opt$convergence,
      pass_1_convergence = history$convergence[[1L]],
      pass_2_convergence = history$convergence[[2L]],
      pass_2_accepted = history$accepted[[2L]],
      objective = fit$opt$objective,
      max_gradient = max(abs(fit$tmb_obj$gr(fixed))),
      phi_estimate = (1 - 1e-6) * tanh(par$theta_temporal_time[[1L]]),
      phi_absolute_error = abs((1 - 1e-6) * tanh(par$theta_temporal_time[[1L]]) - fixture$phi),
      temporal_frobenius_relative_error = .temporal_dep_kernel_retained_relative_frobenius(
        temporal, tcrossprod(fixture$truth$temporal_loading)
      ),
      kernel_1_relative_error = abs(kernel[[1L]] - fixture$truth$kernel_sd[[1L]]^2) /
        fixture$truth$kernel_sd[[1L]]^2,
      kernel_2_relative_error = abs(kernel[[2L]] - fixture$truth$kernel_sd[[2L]]^2) /
        fixture$truth$kernel_sd[[2L]]^2,
      kernel_3_relative_error = abs(kernel[[3L]] - fixture$truth$kernel_sd[[3L]]^2) /
        fixture$truth$kernel_sd[[3L]]^2,
      stringsAsFactors = FALSE
    )
  }, error = function(e) data.frame(
    n_series = key$n_series, seed = key$seed, terminal = "error",
    convergence = NA_integer_, pass_1_convergence = NA_integer_,
    pass_2_convergence = NA_integer_, pass_2_accepted = NA,
    objective = NA_real_, max_gradient = NA_real_, phi_estimate = NA_real_,
    phi_absolute_error = NA_real_, temporal_frobenius_relative_error = NA_real_,
    kernel_1_relative_error = NA_real_, kernel_2_relative_error = NA_real_,
    kernel_3_relative_error = NA_real_, stringsAsFactors = FALSE
  ))
  out$elapsed_seconds <- proc.time()[["elapsed"]] - started
  out
}

.temporal_dep_kernel_information_summary <- function(result) {
  required <- c("n_series", "seed", "terminal", "kernel_1_relative_error",
    "kernel_2_relative_error", "kernel_3_relative_error")
  if (!is.data.frame(result) || !all(required %in% names(result))) {
    stop("result does not have the diagnostic schema", call. = FALSE)
  }
  do.call(rbind, lapply(split(result, result$n_series), function(x) data.frame(
    n_series = x$n_series[[1L]], attempts = nrow(x), terminal_successes = sum(x$terminal == "success"),
    median_kernel_1_relative_error = stats::median(x$kernel_1_relative_error, na.rm = TRUE),
    median_kernel_2_relative_error = stats::median(x$kernel_2_relative_error, na.rm = TRUE),
    median_kernel_3_relative_error = stats::median(x$kernel_3_relative_error, na.rm = TRUE),
    stringsAsFactors = FALSE
  )))
}

.temporal_dep_kernel_information_run <- function(one = FALSE) {
  .temporal_dep_kernel_information_source()
  plan <- expand.grid(n_series = .temporal_dep_kernel_information_sizes(),
    seed = .temporal_dep_kernel_information_seeds(), KEEP.OUT.ATTRS = FALSE)
  plan <- plan[order(plan$n_series, plan$seed), , drop = FALSE]
  if (isTRUE(one)) plan <- plan[plan$n_series == 160L & plan$seed == 2609221L, , drop = FALSE]
  result <- do.call(rbind, Map(.temporal_dep_kernel_information_one, plan$n_series, plan$seed))
  list(result = result, summary = .temporal_dep_kernel_information_summary(result),
    contract = "information-size diagnostic only; no recovery pass or solver claim")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  one <- "--one" %in% args
  output_args <- grep("^--output=", args, value = TRUE)
  if (length(output_args) > 1L || !all(args %in% c("--one", output_args))) {
    stop("usage: Rscript --vanilla diagnose-dep-kernel-information.R [--one] [--output=PATH]", call. = FALSE)
  }
  output_path <- if (length(output_args)) sub("^--output=", "", output_args) else NULL
  if (!is.null(output_path) && (!nzchar(output_path) || file.exists(output_path))) {
    stop("output must name a new result file", call. = FALSE)
  }
  root <- normalizePath(".", mustWork = TRUE)
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  diagnostic <- .temporal_dep_kernel_information_run(one = one)
  if (!is.null(output_path)) {
    directory <- dirname(output_path)
    if (!dir.exists(directory)) stop("output directory does not exist", call. = FALSE)
    temporary <- tempfile("dep-kernel-information-", tmpdir = directory, fileext = ".rds")
    saveRDS(diagnostic, temporary)
    if (!file.rename(temporary, output_path)) stop("could not atomically retain diagnostic output", call. = FALSE)
  }
  print(diagnostic$result, row.names = FALSE)
  print(diagnostic$summary, row.names = FALSE)
  cat(if (one) "TEMPORAL_DEP_KERNEL_INFORMATION_PRERUN_PASS\n" else
    "TEMPORAL_DEP_KERNEL_INFORMATION_PASS\n")
}
