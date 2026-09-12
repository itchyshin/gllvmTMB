## A one-cell, independently checked third-BFGS-pass diagnostic.  It never
## changes an existing campaign receipt or calls production simulation.

args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run the temporal dep-kernel third-pass diagnostic from the repository root.", call. = FALSE)
}
script_dir <- file.path(root, "dev", "temporal-program")
source(file.path(script_dir, "diagnose-dep-kernel-occasion-optimizer.R"), local = FALSE)

.temporal_dep_kernel_third_pass_target <- function() {
  list(phi = 0, seed = 2609373L, n_series = 80L, n_time = 32L)
}

.temporal_dep_kernel_third_pass_fit <- function(fixture, passes) {
  if (!identical(as.integer(passes), 2L) && !identical(as.integer(passes), 3L)) {
    stop("passes must be 2 or 3", call. = FALSE)
  }
  warnings <- character()
  control <- gllvmTMB::gllvmTMBcontrol(
    se = FALSE, optimizer = "optim",
    optArgs = list(method = "BFGS", control = list(maxit = 3000L, reltol = 1e-14)),
    optimizer_passes = as.integer(passes)
  )
  fit <- withCallingHandlers(gllvmTMB::gllvmTMB(value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    kernel_indep(series, K = fixture$K, name = "fixed_nonproportional_K"),
    data = fixture$data, unit = "series", cluster = "series", family = stats::gaussian(),
    silent = TRUE, control = control), warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
    })
  history <- fit$optimizer_pass_history
  if (!is.data.frame(history) || nrow(history) != passes ||
      !identical(history$pass, seq_len(passes))) {
    stop("fit did not retain the requested optimizer-pass history", call. = FALSE)
  }
  list(fit = fit, warnings = unique(warnings))
}

.temporal_dep_kernel_third_pass_adjudicate <- function(two, three) {
  two_history <- two$endpoint$optimizer_pass_history
  three_history <- three$endpoint$optimizer_pass_history
  third <- three_history[3L, , drop = FALSE]
  reasons <- character()
  if (!identical(nrow(two_history), 2L) || !identical(nrow(three_history), 3L)) {
    reasons <- c(reasons, "history_shape")
  }
  if (!identical(two$endpoint$convergence, 0L) || !isTRUE(two_history$accepted[[2L]])) {
    reasons <- c(reasons, "two_pass_baseline")
  }
  if (!identical(three$endpoint$convergence, 0L) || !isTRUE(third$accepted[[1L]])) {
    reasons <- c(reasons, "third_pass_convergence")
  }
  if (!is.finite(three$endpoint$objective) ||
      three$endpoint$objective > two$endpoint$objective + 1e-8) {
    reasons <- c(reasons, "objective")
  }
  if (!is.finite(three$endpoint$max_gradient) || three$endpoint$max_gradient > 1e-3) {
    reasons <- c(reasons, "outer_gradient")
  }
  for (label in c("two", "three")) {
    oracle <- get(label)$oracle
    if (!is.finite(oracle$nll_absolute_error) || oracle$nll_absolute_error > 1e-6 ||
        any(!is.finite(oracle$gradient_absolute_error)) ||
        max(oracle$gradient_absolute_error) > 1e-4) {
      reasons <- c(reasons, paste0(label, "_independent_oracle"))
    }
  }
  list(accepted = !length(reasons), reasons = unique(reasons))
}

.temporal_dep_kernel_third_pass_self_test <- function() {
  make_endpoint <- function(passes, objective, gradient, accepted = TRUE) {
    list(endpoint = list(
      optimizer_pass_history = data.frame(pass = seq_len(passes),
        accepted = rep(accepted, passes), stringsAsFactors = FALSE),
      convergence = 0L, objective = objective, max_gradient = gradient
    ), oracle = list(nll_absolute_error = 0, gradient_absolute_error = c(a = 0, b = 0)))
  }
  accepted <- .temporal_dep_kernel_third_pass_adjudicate(
    make_endpoint(2L, 10, 2e-3), make_endpoint(3L, 9, 9e-4)
  )
  rejected <- .temporal_dep_kernel_third_pass_adjudicate(
    make_endpoint(2L, 10, 2e-3), make_endpoint(3L, 9, 1.1e-3)
  )
  if (!isTRUE(accepted$accepted) || isTRUE(rejected$accepted) ||
      !identical(rejected$reasons, "outer_gradient")) {
    stop("third-pass diagnostic self-test did not distinguish the gradient gate", call. = FALSE)
  }
  cat("TEMPORAL_DEP_KERNEL_THIRD_PASS_SELF_TEST_PASS\n")
}

.temporal_dep_kernel_third_pass_run <- function(output) {
  if (!is.character(output) || length(output) != 1L || !nzchar(output) ||
      file.exists(output) || !dir.exists(dirname(output))) {
    stop("--output must name a new RDS file in an existing directory", call. = FALSE)
  }
  started <- Sys.time()
  receipt <- tryCatch({
    pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
    target <- .temporal_dep_kernel_third_pass_target()
    fixture <- .temporal_dep_kernel_occasion_fixture(target$phi, target$seed)
    fixture$series <- paste0("s", seq_len(target$n_series))
    fixture$traits <- paste0("t", 1:3)
    two_fit <- .temporal_dep_kernel_third_pass_fit(fixture, 2L)
    three_fit <- .temporal_dep_kernel_third_pass_fit(fixture, 3L)
    two <- list(endpoint = .temporal_dep_kernel_optimizer_endpoint(two_fit$fit),
      oracle = .temporal_dep_kernel_optimizer_oracle(two_fit$fit, fixture, two_fit$fit$opt$par),
      warnings = two_fit$warnings)
    three <- list(endpoint = .temporal_dep_kernel_optimizer_endpoint(three_fit$fit),
      oracle = .temporal_dep_kernel_optimizer_oracle(three_fit$fit, fixture, three_fit$fit$opt$par),
      warnings = three_fit$warnings)
    list(schema = "temporal-dep-kernel-third-pass-v1", terminal = "success", target = target,
      two_pass = two, three_pass = three,
      adjudication = .temporal_dep_kernel_third_pass_adjudicate(two, three))
  }, error = function(e) list(schema = "temporal-dep-kernel-third-pass-v1", terminal = "error",
    target = .temporal_dep_kernel_third_pass_target(), error_message = conditionMessage(e)))
  receipt$started_at_utc <- format(started, tz = "UTC", usetz = TRUE)
  receipt$ended_at_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  receipt$contract <- "One-cell third-pass diagnostic only; no recovery, optimizer, coverage, or admission claim."
  saveRDS(receipt, output)
  marker <- if (identical(receipt$terminal, "success") && isTRUE(receipt$adjudication$accepted)) {
    "TEMPORAL_DEP_KERNEL_THIRD_PASS_ACCEPT"
  } else {
    "TEMPORAL_DEP_KERNEL_THIRD_PASS_REJECT"
  }
  cat(marker, "\n", sep = "")
  invisible(receipt)
}

.temporal_dep_kernel_third_pass_verify <- function(path) {
  if (!file.exists(path)) stop("missing third-pass diagnostic receipt: ", path, call. = FALSE)
  receipt <- readRDS(path)
  target <- .temporal_dep_kernel_third_pass_target()
  required_endpoint <- function(x, passes) {
    is.list(x) && is.list(x$endpoint) && is.list(x$oracle) &&
      is.data.frame(x$endpoint$optimizer_pass_history) &&
      nrow(x$endpoint$optimizer_pass_history) == passes &&
      identical(x$endpoint$optimizer_pass_history$pass, seq_len(passes)) &&
      is.finite(x$endpoint$objective) && is.finite(x$endpoint$max_gradient) &&
      is.finite(x$oracle$nll_absolute_error) && x$oracle$nll_absolute_error <= 1e-6 &&
      is.numeric(x$oracle$gradient_absolute_error) &&
      all(is.finite(x$oracle$gradient_absolute_error)) &&
      max(x$oracle$gradient_absolute_error) <= 1e-4
  }
  valid <- is.list(receipt) && identical(receipt$schema, "temporal-dep-kernel-third-pass-v1") &&
    identical(receipt$terminal, "success") && identical(receipt$target, target) &&
    identical(receipt$contract, "One-cell third-pass diagnostic only; no recovery, optimizer, coverage, or admission claim.") &&
    required_endpoint(receipt$two_pass, 2L) && required_endpoint(receipt$three_pass, 3L) &&
    is.list(receipt$adjudication) && identical(receipt$adjudication$accepted, FALSE) &&
    identical(receipt$adjudication$reasons, "outer_gradient") &&
    receipt$two_pass$endpoint$max_gradient > 1e-3 &&
    receipt$three_pass$endpoint$max_gradient > receipt$two_pass$endpoint$max_gradient &&
    receipt$three_pass$endpoint$objective <= receipt$two_pass$endpoint$objective + 1e-8
  if (!valid) stop("third-pass diagnostic receipt is not the retained independent gradient rejection", call. = FALSE)
  cat("TEMPORAL_DEP_KERNEL_THIRD_PASS_RETAINED_REJECT_PASS\n")
}

if (identical(args, "--self-test")) {
  .temporal_dep_kernel_third_pass_self_test()
} else {
  verify_arg <- grep("^--verify=", args, value = TRUE)
  output_arg <- grep("^--output=", args, value = TRUE)
  if (length(verify_arg) == 1L && length(args) == 1L) {
    .temporal_dep_kernel_third_pass_verify(sub("^--verify=", "", verify_arg))
  } else if (length(output_arg) != 1L || length(args) != 1L) {
    stop("usage: Rscript --vanilla diagnose-dep-kernel-occasion-third-pass.R --self-test | --output=PATH", call. = FALSE)
  } else {
    .temporal_dep_kernel_third_pass_run(sub("^--output=", "", output_arg))
  }
}
