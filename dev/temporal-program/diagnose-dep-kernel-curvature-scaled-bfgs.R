## One-cell curvature-scaled BFGS continuation.  It never edits a frozen receipt.

args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run the curvature-scaled BFGS diagnostic from the repository root.", call. = FALSE)
}
script_dir <- file.path(root, "dev", "temporal-program")
source(file.path(script_dir, "diagnose-dep-kernel-occasion-optimizer.R"), local = FALSE)

.scaled_target <- function(phi = 0, seed = 2609373L) {
  .temporal_dep_kernel_occasion_validate(phi, seed)
}

.scaled_baseline_fit <- function(fixture) {
  warnings <- character()
  control <- gllvmTMB::gllvmTMBcontrol(
    se = FALSE, optimizer = "optim", optimizer_passes = 2L,
    optArgs = list(method = "BFGS", control = list(maxit = 3000L, reltol = 1e-14))
  )
  fit <- withCallingHandlers(gllvmTMB::gllvmTMB(value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = fixture$K, name = "fixed_nonproportional_K"),
    data = fixture$data, unit = "series", cluster = "series", family = stats::gaussian(),
    silent = TRUE, control = control), warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
    })
  if (!is.data.frame(fit$optimizer_pass_history) || nrow(fit$optimizer_pass_history) != 2L ||
      !identical(fit$optimizer_pass_history$pass, 1:2)) {
    stop("baseline did not retain exactly two optimizer passes", call. = FALSE)
  }
  list(fit = fit, warnings = unique(warnings))
}

.scaled_curvature <- function(obj, par) {
  gradient <- obj$gr(par)
  h <- 1e-4 * (1 + abs(par))
  diagonal <- vapply(seq_along(par), function(i) {
    plus <- minus <- par
    plus[[i]] <- plus[[i]] + h[[i]]
    minus[[i]] <- minus[[i]] - h[[i]]
    (obj$gr(plus)[[i]] - obj$gr(minus)[[i]]) / (2 * h[[i]])
  }, numeric(1))
  if (any(!is.finite(gradient)) || any(!is.finite(diagonal)) || any(diagonal <= 0)) {
    stop("native central-difference diagonal curvature is not finite and positive", call. = FALSE)
  }
  list(step = h, diagonal = diagonal,
    parscale = pmin(1e4, pmax(1e-4, 1 / sqrt(diagonal))))
}

.scaled_fit <- function(fixture, start_from, parscale) {
  warnings <- character()
  control <- gllvmTMB::gllvmTMBcontrol(
    se = FALSE, optimizer = "optim", optimizer_passes = 1L,
    start_from = start_from,
    optArgs = list(method = "BFGS", control = list(
      maxit = 3000L, reltol = 1e-14, parscale = unname(parscale)
    ))
  )
  fit <- withCallingHandlers(gllvmTMB::gllvmTMB(value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = fixture$K, name = "fixed_nonproportional_K"),
    data = fixture$data, unit = "series", cluster = "series", family = stats::gaussian(),
    silent = TRUE, control = control), warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
    })
  if (!is.data.frame(fit$optimizer_pass_history) || nrow(fit$optimizer_pass_history) != 1L ||
      !identical(fit$optimizer_pass_history$pass, 1L)) {
    stop("scaled continuation did not retain exactly one optimizer pass", call. = FALSE)
  }
  list(fit = fit, warnings = unique(warnings))
}

.scaled_adjudicate <- function(baseline, candidate) {
  reasons <- character()
  if (!identical(baseline$endpoint$convergence, 0L) ||
      !isTRUE(baseline$endpoint$optimizer_pass_history$accepted[[2L]])) {
    reasons <- c(reasons, "baseline")
  }
  if (!identical(candidate$endpoint$convergence, 0L) ||
      !isTRUE(candidate$endpoint$optimizer_pass_history$accepted[[1L]])) {
    reasons <- c(reasons, "candidate_convergence")
  }
  if (!is.finite(candidate$endpoint$objective) ||
      candidate$endpoint$objective > baseline$endpoint$objective + 1e-8) reasons <- c(reasons, "objective")
  if (!is.finite(candidate$endpoint$max_gradient) || candidate$endpoint$max_gradient > 1e-3) {
    reasons <- c(reasons, "outer_gradient")
  }
  for (label in c("baseline", "candidate")) {
    oracle <- get(label)$oracle
    if (!is.finite(oracle$nll_absolute_error) || oracle$nll_absolute_error > 1e-6 ||
        any(!is.finite(oracle$gradient_absolute_error)) || max(oracle$gradient_absolute_error) > 1e-4) {
      reasons <- c(reasons, paste0(label, "_independent_oracle"))
    }
  }
  list(accepted = !length(reasons), reasons = unique(reasons))
}

.scaled_run <- function(output, target = .scaled_target()) {
  if (!is.character(output) || length(output) != 1L || !nzchar(output) ||
      file.exists(output) || !dir.exists(dirname(output))) {
    stop("--output must name a new RDS file in an existing directory", call. = FALSE)
  }
  started <- Sys.time()
  receipt <- tryCatch({
    pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
    fixture <- .temporal_dep_kernel_occasion_fixture(target$phi, target$seed)
    fixture$series <- paste0("s", seq_len(target$n_series)); fixture$traits <- paste0("t", 1:3)
    baseline_fit <- .scaled_baseline_fit(fixture)
    baseline <- list(endpoint = .temporal_dep_kernel_optimizer_endpoint(baseline_fit$fit),
      oracle = .temporal_dep_kernel_optimizer_oracle(baseline_fit$fit, fixture, baseline_fit$fit$opt$par),
      warnings = baseline_fit$warnings)
    curvature <- .scaled_curvature(baseline_fit$fit$tmb_obj, baseline_fit$fit$opt$par)
    scaled_fit <- .scaled_fit(fixture, baseline_fit$fit, curvature$parscale)
    candidate <- list(endpoint = .temporal_dep_kernel_optimizer_endpoint(scaled_fit$fit),
      oracle = .temporal_dep_kernel_optimizer_oracle(scaled_fit$fit, fixture, scaled_fit$fit$opt$par),
      warnings = scaled_fit$warnings, start_provenance = scaled_fit$fit$start_provenance)
    list(schema = "temporal-dep-kernel-curvature-scaled-bfgs-v1", terminal = "success",
      target = target, baseline = baseline, curvature = curvature, candidate = candidate,
      adjudication = .scaled_adjudicate(baseline, candidate))
  }, error = function(e) list(schema = "temporal-dep-kernel-curvature-scaled-bfgs-v1",
    terminal = "error", target = target, error_message = conditionMessage(e)))
  receipt$contract <- "One-cell curvature-scaled BFGS diagnostic only; no recovery, optimizer, coverage, or admission claim."
  receipt$started_at_utc <- format(started, tz = "UTC", usetz = TRUE)
  receipt$ended_at_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  saveRDS(receipt, output)
  cat(if (identical(receipt$terminal, "success") && isTRUE(receipt$adjudication$accepted))
    "TEMPORAL_DEP_KERNEL_SCALED_BFGS_ACCEPT\n" else "TEMPORAL_DEP_KERNEL_SCALED_BFGS_REJECT\n")
  invisible(receipt)
}

.scaled_self_test <- function() {
  obj <- list(gr = function(p) c(4 * p[[1L]], 9 * p[[2L]]))
  out <- .scaled_curvature(obj, c(2, 3))
  if (!isTRUE(all.equal(out$diagonal, c(4, 9), tolerance = 1e-6)) ||
      !isTRUE(all.equal(out$parscale, c(.5, 1 / 3), tolerance = 1e-6))) {
    stop("curvature-scaled BFGS self-test did not recover diagonal scaling", call. = FALSE)
  }
  cat("TEMPORAL_DEP_KERNEL_SCALED_BFGS_SELF_TEST_PASS\n")
}

if (sys.nframe() == 0L) {
verify_arg <- grep("^--verify=", args, value = TRUE)
output_arg <- grep("^--output=", args, value = TRUE)
if (identical(args, "--self-test")) {
  .scaled_self_test()
} else if (length(verify_arg) == 1L && length(args) == 1L) {
  receipt <- readRDS(sub("^--verify=", "", verify_arg))
  target <- .scaled_target()
  endpoint_ok <- function(x, passes) is.list(x) && is.list(x$endpoint) && is.list(x$oracle) &&
    is.data.frame(x$endpoint$optimizer_pass_history) && nrow(x$endpoint$optimizer_pass_history) == passes &&
    identical(x$endpoint$optimizer_pass_history$pass, seq_len(passes)) &&
    is.finite(x$endpoint$objective) && is.finite(x$endpoint$max_gradient) &&
    is.finite(x$oracle$nll_absolute_error) && x$oracle$nll_absolute_error <= 1e-6 &&
    is.numeric(x$oracle$gradient_absolute_error) && all(is.finite(x$oracle$gradient_absolute_error)) &&
    max(x$oracle$gradient_absolute_error) <= 1e-4
  curvature_ok <- is.list(receipt$curvature) && is.numeric(receipt$curvature$step) &&
    is.numeric(receipt$curvature$diagonal) && is.numeric(receipt$curvature$parscale) &&
    length(receipt$curvature$step) == length(receipt$curvature$diagonal) &&
    identical(length(receipt$curvature$step), length(receipt$curvature$parscale)) &&
    all(is.finite(receipt$curvature$step)) && all(receipt$curvature$step > 0) &&
    all(is.finite(receipt$curvature$diagonal)) && all(receipt$curvature$diagonal > 0) &&
    all(is.finite(receipt$curvature$parscale)) && all(receipt$curvature$parscale >= 1e-4) &&
    all(receipt$curvature$parscale <= 1e4)
  accepted <- is.list(receipt$adjudication) && identical(receipt$adjudication$accepted, TRUE) &&
    identical(receipt$adjudication$reasons, character()) &&
    endpoint_ok(receipt$baseline, 2L) && endpoint_ok(receipt$candidate, 1L) &&
    identical(receipt$baseline$endpoint$convergence, 0L) &&
    isTRUE(receipt$baseline$endpoint$optimizer_pass_history$accepted[[2L]]) &&
    identical(receipt$candidate$endpoint$convergence, 0L) &&
    isTRUE(receipt$candidate$endpoint$optimizer_pass_history$accepted[[1L]]) &&
    receipt$candidate$endpoint$objective <= receipt$baseline$endpoint$objective + 1e-8 &&
    receipt$candidate$endpoint$max_gradient <= 1e-3
  if (!is.list(receipt) || !identical(receipt$schema, "temporal-dep-kernel-curvature-scaled-bfgs-v1") ||
      !identical(receipt$target, target) || !identical(receipt$terminal, "success") || !curvature_ok || !accepted ||
      !identical(receipt$contract, "One-cell curvature-scaled BFGS diagnostic only; no recovery, optimizer, coverage, or admission claim.")) {
    stop("scaled BFGS receipt has invalid identity", call. = FALSE)
  }
  cat("TEMPORAL_DEP_KERNEL_SCALED_BFGS_RECEIPT_PASS\n")
} else if (length(output_arg) == 1L && length(args) == 1L) {
  .scaled_run(sub("^--output=", "", output_arg))
} else {
  stop("usage: diagnose-dep-kernel-curvature-scaled-bfgs.R --self-test | --output=PATH | --verify=PATH", call. = FALSE)
}
}
