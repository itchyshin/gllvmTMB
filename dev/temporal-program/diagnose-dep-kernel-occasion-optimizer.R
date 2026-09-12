## Diagnostic-only endpoint audit for the retained failed long-occasion cell.
## It uses a direct DGP and an independently authored block Gaussian oracle.

.temporal_dep_kernel_optimizer_dev_file <- function(name) {
  roots <- unique(normalizePath(c(getwd(), file.path(getwd(), "..", "..")),
    mustWork = FALSE))
  path <- file.path(roots, "dev", "temporal-program", name)
  hit <- path[file.exists(path)]
  if (!length(hit)) stop("cannot locate temporal-program developer dependency", call. = FALSE)
  hit[[1L]]
}

source(.temporal_dep_kernel_optimizer_dev_file("run-dep-kernel-occasion-qualification.R"), local = FALSE)
source(.temporal_dep_kernel_optimizer_dev_file("verify-dep-kernel-retained-oracle.R"), local = FALSE)

.temporal_dep_kernel_optimizer_target <- function() {
  list(phi = 0, seed = 2609373L, n_series = 80L, n_time = 32L)
}

.temporal_dep_kernel_optimizer_provenance <- function() {
  commit <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE,
    stderr = FALSE), error = function(e) character())
  dirty <- tryCatch(system2("git", c("status", "--porcelain"), stdout = TRUE,
    stderr = FALSE), error = function(e) NA_character_)
  list(schema = "temporal-dep-kernel-optimizer-diagnostic-v1",
    source_commit = if (length(commit) == 1L) trimws(commit) else NA_character_,
    r_version = R.version.string, platform = R.version$platform,
    tmb_version = as.character(utils::packageVersion("TMB")),
    source_tree_clean = identical(dirty, character()))
}

.temporal_dep_kernel_optimizer_output <- function(path) {
  if (!is.character(path) || length(path) != 1L || !nzchar(path) ||
      !grepl("[.]rds$", path) || file.exists(path) || !dir.exists(dirname(path))) {
    stop("diagnostic output must be a new RDS file in an existing directory", call. = FALSE)
  }
  invisible(path)
}

.temporal_dep_kernel_optimizer_fit <- function(fixture) {
  warnings <- character()
  fit <- withCallingHandlers(gllvmTMB::gllvmTMB(value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = fixture$K, name = "fixed_nonproportional_K"),
    data = fixture$data, unit = "series", cluster = "series", family = stats::gaussian(),
    silent = TRUE, control = gllvmTMB::gllvmTMBcontrol(se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 3000L, reltol = 1e-14)),
      optimizer_passes = 2L)), warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
  })
  list(fit = fit, warnings = unique(warnings))
}

.temporal_dep_kernel_optimizer_endpoint <- function(fit) {
  fixed <- fit$opt$par
  gradient <- fit$tmb_obj$gr(fixed)
  labels <- .temporal_dep_kernel_retained_labels(fixed)
  names(gradient) <- labels
  hessian <- tryCatch(fit$tmb_obj$he(fixed), error = function(e) e)
  hessian_status <- if (inherits(hessian, "error")) "error" else if (
    all(is.finite(hessian)) && !inherits(try(chol(hessian), silent = TRUE), "try-error")
  ) "positive_definite" else "non_positive_definite"
  list(outer_parameter = stats::setNames(unname(fixed), labels),
    native_gradient = gradient, objective = as.numeric(fit$tmb_obj$fn(fixed)),
    max_gradient = max(abs(gradient)), optimizer_pass_history = fit$optimizer_pass_history,
    convergence = fit$opt$convergence, parameter_blocks = fit$tmb_obj$env$parList(fixed),
    hessian_status = hessian_status,
    hessian_error_message = if (inherits(hessian, "error")) conditionMessage(hessian) else NA_character_)
}

.temporal_dep_kernel_optimizer_oracle <- function(fit, fixture, fixed) {
  native_nll <- as.numeric(fit$tmb_obj$fn(fixed))
  independent_nll <- .temporal_dep_kernel_retained_block_nll(fit, fixed, fixture)
  independent_gradient <- .temporal_dep_kernel_retained_central_gradient(fit, fixed, fixture)
  native_gradient <- stats::setNames(fit$tmb_obj$gr(fixed), names(independent_gradient))
  list(native_nll = native_nll, independent_block_nll = independent_nll,
    nll_absolute_error = abs(native_nll - independent_nll),
    native_gradient = native_gradient,
    independent_block_gradient = independent_gradient,
    gradient_absolute_error = abs(native_gradient - independent_gradient))
}

temporal_dep_kernel_optimizer_diagnostic <- function(output) {
  .temporal_dep_kernel_optimizer_output(output)
  started <- Sys.time(); target <- .temporal_dep_kernel_optimizer_target()
  receipt <- tryCatch({
    pkgload::load_all(normalizePath(".", mustWork = TRUE), quiet = TRUE, export_all = FALSE)
    fixture <- .temporal_dep_kernel_occasion_fixture(target$phi, target$seed)
    fixture$series <- paste0("s", seq_len(target$n_series))
    fixture$traits <- paste0("t", 1:3)
    fitted <- .temporal_dep_kernel_optimizer_fit(fixture)
    endpoint <- .temporal_dep_kernel_optimizer_endpoint(fitted$fit)
    oracle <- .temporal_dep_kernel_optimizer_oracle(fitted$fit, fixture,
      fitted$fit$opt$par)
    list(provenance = .temporal_dep_kernel_optimizer_provenance(), target = target,
      terminal = "success", started_at_utc = format(started, tz = "UTC", usetz = TRUE),
      ended_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), warnings = fitted$warnings,
      endpoint = endpoint, oracle = oracle)
  }, error = function(e) list(provenance = .temporal_dep_kernel_optimizer_provenance(),
    target = target, terminal = "error", started_at_utc = format(started, tz = "UTC", usetz = TRUE),
    ended_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), error_message = conditionMessage(e)))
  receipt$contract <- paste("Diagnostic only; cannot replace the failed qualification",
    "or alter its criterion, seeds, fixture, or verdict.")
  temporary <- tempfile("dep-kernel-optimizer-", tmpdir = dirname(output), fileext = ".rds")
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  saveRDS(receipt, temporary)
  if (file.exists(output) || !file.rename(temporary, output)) {
    stop("could not atomically retain the diagnostic receipt", call. = FALSE)
  }
  invisible(receipt)
}
