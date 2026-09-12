## Separate native-nlminb candidate.  It sources, but never alters, the frozen
## BFGS generator and metric code; all candidate identifiers are distinct.

.temporal_dep_kernel_nlminb_dev_file <- function(name) {
  roots <- unique(normalizePath(c(getwd(), file.path(getwd(), "..", "..")),
    mustWork = FALSE))
  path <- file.path(roots, "dev", "temporal-program", name)
  hit <- path[file.exists(path)]
  if (!length(hit)) stop("cannot locate temporal-program developer dependency", call. = FALSE)
  hit[[1L]]
}

source(.temporal_dep_kernel_nlminb_dev_file("run-dep-kernel-occasion-qualification.R"),
  local = FALSE)

.temporal_dep_kernel_nlminb_plan <- function() {
  x <- expand.grid(phi = c(-.4, 0, .6), seed = 2609381:2609383,
    KEEP.OUT.ATTRS = FALSE)
  x$n_series <- 80L; x$n_time <- 32L
  x[order(x$phi, x$seed), c("phi", "seed", "n_series", "n_time")]
}

.temporal_dep_kernel_nlminb_validate <- function(phi, seed) {
  if (length(phi) != 1L || !is.numeric(phi) || !is.finite(phi) ||
      !any(abs(phi - c(-.4, 0, .6)) < .Machine$double.eps^0.5)) {
    stop("phi must be one frozen persistence value: -0.4, 0, or 0.6", call. = FALSE)
  }
  if (length(seed) != 1L || !is.numeric(seed) || !is.finite(seed) ||
      !(as.integer(seed) %in% 2609381:2609383)) {
    stop("seed must be one disjoint nlminb qualification seed: 2609381:2609383", call. = FALSE)
  }
  list(phi = as.numeric(phi), seed = as.integer(seed), n_series = 80L, n_time = 32L)
}

.temporal_dep_kernel_nlminb_prerun <- function() {
  list(phi = .6, seed = 2609380L, n_series = 80L, n_time = 32L)
}

.temporal_dep_kernel_nlminb_control <- function() {
  control <- gllvmTMB::gllvmTMBcontrol(
    se = FALSE, integration = "laplace", aghq = FALSE, loading_ridge = NULL,
    n_init = 1L, init_strategy = "default", init_jitter = .3,
    start_method = list(method = NULL, jitter.sd = 0), start_from = NULL,
    optimizer = "nlminb", optimizer_passes = 2L,
    optArgs = list(scale = 1, lower = -Inf, upper = Inf,
      control = list(iter.max = 3000L, eval.max = 12000L, rel.tol = 1e-14,
        x.tol = 1e-10, abs.tol = 0, xf.tol = 2.2e-14, sing.tol = 1e-14,
        trace = 0))
  )
  control$optimizer_diagnostics <- TRUE
  control
}

.temporal_dep_kernel_nlminb_fixture <- function(phi, seed) {
  key <- if (identical(as.integer(seed), 2609380L)) {
    .temporal_dep_kernel_nlminb_prerun()
  } else .temporal_dep_kernel_nlminb_validate(phi, seed)
  ## The old generator validates its own seed set; retain the direct DGP body
  ## by temporarily providing the same fixed dimensions with a disjoint seed.
  truth <- .temporal_dep_kernel_occasion_truth(); n_time <- key$n_time
  series <- paste0("s", seq_len(key$n_series)); traits <- paste0("t", 1:3)
  coordinate <- cbind(seq_len(key$n_series) / key$n_series, sin(seq_len(key$n_series) * .7))
  raw_K <- exp(-as.matrix(stats::dist(coordinate)) / .16) + diag(.08, key$n_series)
  K <- raw_K / sqrt(outer(diag(raw_K), diag(raw_K))); dimnames(K) <- list(series, series)
  set.seed(key$seed)
  static <- t(chol(K)) %*% sweep(matrix(stats::rnorm(key$n_series * 3L), key$n_series, 3L), 2L, truth$kernel_sd, "*")
  time_chol <- t(chol(tcrossprod(truth$temporal_loading)))
  state <- array(0, c(key$n_series, n_time, 3L))
  for (g in seq_len(key$n_series)) {
    state[g, 1L, ] <- drop(time_chol %*% stats::rnorm(3L))
    for (tt in 2:n_time) state[g, tt, ] <- key$phi * state[g, tt - 1L, ] +
      sqrt(1 - key$phi^2) * drop(time_chol %*% stats::rnorm(3L))
  }
  data <- expand.grid(series = series, occasion = seq_len(n_time), trait = traits,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  g <- match(data$series, series); tt <- data$occasion; j <- match(data$trait, traits)
  data$mean_value <- truth$beta[j] + state[cbind(g, tt, j)] + static[cbind(g, j)]
  data <- data[rep(seq_len(nrow(data)), each = 2L), , drop = FALSE]
  data$measurement <- rep(c("m1", "m2"), times = nrow(data) / 2L)
  data$value <- data$mean_value + stats::rnorm(nrow(data), sd = truth$residual)
  data$mean_value <- NULL
  list(data = data, K = K, truth = truth, phi = key$phi, seed = key$seed,
    n_series = key$n_series, n_time = key$n_time)
}

.temporal_dep_kernel_nlminb_one <- function(phi, seed) {
  started <- proc.time()[["elapsed"]]
  key <- if (identical(as.integer(seed), 2609380L)) {
    .temporal_dep_kernel_nlminb_prerun()
  } else .temporal_dep_kernel_nlminb_validate(phi, seed)
  out <- tryCatch({
    fixture <- .temporal_dep_kernel_nlminb_fixture(key$phi, key$seed)
    warnings <- character()
    fit <- withCallingHandlers(gllvmTMB::gllvmTMB(value ~ 0 + trait +
      temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
      kernel_indep(series, K = fixture$K, name = "fixed_nonproportional_K"),
      data = fixture$data, unit = "series", cluster = "series", family = stats::gaussian(),
      silent = TRUE, control = .temporal_dep_kernel_nlminb_control()), warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
      })
    history <- fit$optimizer_pass_history
    if (!is.data.frame(history) || nrow(history) != 2L || !identical(history$pass, 1:2)) {
      stop("fit did not retain the requested two optimizer passes", call. = FALSE)
    }
    if (!identical(history$evaluations, history$gr_evaluations) ||
        any(!is.finite(history$fn_evaluations)) || any(!is.finite(history$gr_evaluations))) {
      stop("fit did not retain normalized optimizer counters", call. = FALSE)
    }
    par <- fit$tmb_obj$env$parList(fit$opt$par); temporal <- gllvmTMB::extract_temporal(fit)
    hessian <- tryCatch(fit$tmb_obj$he(fit$opt$par), error = function(e) e)
    hs <- if (inherits(hessian, "error")) "error" else if (all(is.finite(hessian)) &&
      !inherits(try(chol(hessian), silent = TRUE), "try-error")) "positive_definite" else "non_positive_definite"
    native_gradient <- stats::setNames(fit$tmb_obj$gr(fit$opt$par), names(fit$opt$par))
    result <- data.frame(phi = key$phi, seed = key$seed, n_series = key$n_series, n_time = key$n_time,
      terminal = "success", convergence = fit$opt$convergence,
      pass_1_convergence = history$convergence[[1L]], pass_2_convergence = history$convergence[[2L]],
      pass_2_accepted = history$accepted[[2L]], max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))),
      objective = fit$opt$objective, hessian_status = hs,
      hessian_error_message = if (inherits(hessian, "error")) conditionMessage(hessian) else NA_character_,
      phi_estimate = temporal$time$value[[1L]],
      temporal_frobenius_relative_error = sqrt(sum((tcrossprod(as.matrix(temporal$loading)) - tcrossprod(fixture$truth$temporal_loading))^2)) / sqrt(sum(tcrossprod(fixture$truth$temporal_loading)^2)),
      kernel_1 = par$theta_rr_phy[[1L]]^2, kernel_2 = par$theta_rr_phy[[2L]]^2,
      kernel_3 = par$theta_rr_phy[[3L]]^2, beta_1 = par$b_fix[[1L]],
      beta_2 = par$b_fix[[2L]], beta_3 = par$b_fix[[3L]], error_message = NA_character_,
      stringsAsFactors = FALSE)
    attr(result, "optimizer_diagnostics") <- list(
      pass_history = history, final_parameter = fit$opt$par,
      final_gradient = native_gradient, final_objective = as.numeric(fit$tmb_obj$fn(fit$opt$par)),
      warnings = unique(warnings), control = .temporal_dep_kernel_nlminb_control()
    )
    result
  }, error = function(e) data.frame(phi = key$phi, seed = key$seed, n_series = key$n_series,
    n_time = key$n_time, terminal = "error", convergence = NA_integer_,
    pass_1_convergence = NA_integer_, pass_2_convergence = NA_integer_, pass_2_accepted = NA,
    max_gradient = NA_real_, objective = NA_real_, hessian_status = "error",
    hessian_error_message = NA_character_, phi_estimate = NA_real_,
    temporal_frobenius_relative_error = NA_real_, kernel_1 = NA_real_, kernel_2 = NA_real_,
    kernel_3 = NA_real_, beta_1 = NA_real_, beta_2 = NA_real_, beta_3 = NA_real_,
    error_message = conditionMessage(e), stringsAsFactors = FALSE))
  out$elapsed_seconds <- proc.time()[["elapsed"]] - started
  out
}

.temporal_dep_kernel_nlminb_validate_campaign <- function(result) {
  if (!is.data.frame(result) || !all(c("phi", "seed") %in% names(result))) {
    stop("campaign results must contain phi and seed", call. = FALSE)
  }
  key <- function(x) paste(sprintf("%.17g", as.numeric(x$phi)), as.integer(x$seed), sep = "/")
  observed <- key(result); expected <- key(.temporal_dep_kernel_nlminb_plan())
  if (anyDuplicated(observed)) stop("every frozen campaign cell must occur exactly once", call. = FALSE)
  if (length(unexpected <- setdiff(observed, expected))) stop("unexpected campaign cell: ", unexpected[[1L]], call. = FALSE)
  if (length(missing <- setdiff(expected, observed))) stop("missing frozen campaign cell: ", missing[[1L]], call. = FALSE)
  invisible(result)
}

.temporal_dep_kernel_nlminb_summarise <- function(result) {
  result$optimizer <- "nlminb"
  .temporal_dep_kernel_occasion_summarise(result)
}

.temporal_dep_kernel_nlminb_summarise_campaign <- function(result) {
  .temporal_dep_kernel_nlminb_validate_campaign(result)
  .temporal_dep_kernel_nlminb_summarise(result)
}

.temporal_dep_kernel_nlminb_provenance <- function() {
  out <- .temporal_dep_kernel_occasion_provenance()
  out$schema <- "temporal-dep-kernel-nlminb-receipt-v1"
  out$optimizer <- "nlminb"
  out
}

.temporal_dep_kernel_nlminb_run <- function(phi = NULL, seed = NULL, pre_run = FALSE) {
  if (isTRUE(pre_run)) {
    if (!is.null(phi) || !is.null(seed)) stop("--pre-run cannot be combined with a campaign cell", call. = FALSE)
    x <- .temporal_dep_kernel_nlminb_prerun()
    return(list(result = .temporal_dep_kernel_nlminb_one(x$phi, x$seed), summary = NULL,
      contract = "nlminb timing pre-run only"))
  }
  if (xor(is.null(phi), is.null(seed)) || is.null(phi)) {
    stop("a qualification invocation must name both frozen phi and seed", call. = FALSE)
  }
  key <- .temporal_dep_kernel_nlminb_validate(phi, seed)
  .temporal_dep_kernel_nlminb_summarise(.temporal_dep_kernel_nlminb_one(key$phi, key$seed))
}

.temporal_dep_kernel_nlminb_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  pre_run <- "--pre-run" %in% args
  phi_arg <- grep("^--phi=", args, value = TRUE); seed_arg <- grep("^--seed=", args, value = TRUE)
  output_arg <- grep("^--output=", args, value = TRUE)
  allowed <- c("--pre-run", phi_arg, seed_arg, output_arg)
  if (length(phi_arg) > 1L || length(seed_arg) > 1L || length(output_arg) != 1L ||
      !all(args %in% allowed) || xor(length(phi_arg) == 1L, length(seed_arg) == 1L) ||
      (pre_run && (length(phi_arg) || length(seed_arg))) || (!pre_run && !length(phi_arg))) {
    stop("usage: Rscript --vanilla run-dep-kernel-occasion-nlminb-qualification.R [--pre-run | --phi=VALUE --seed=N] --output=PATH", call. = FALSE)
  }
  output <- sub("^--output=", "", output_arg)
  if (!dir.exists(dirname(output))) stop("output directory does not exist", call. = FALSE)
  .temporal_dep_kernel_occasion_with_reservation(output, {
    pkgload::load_all(normalizePath(".", mustWork = TRUE), quiet = TRUE, export_all = FALSE)
    value <- .temporal_dep_kernel_nlminb_run(
      if (length(phi_arg)) as.numeric(sub("^--phi=", "", phi_arg)) else NULL,
      if (length(seed_arg)) as.integer(sub("^--seed=", "", seed_arg)) else NULL, pre_run)
    value$provenance <- .temporal_dep_kernel_nlminb_provenance()
    temporary <- tempfile("dep-kernel-nlminb-", tmpdir = dirname(output), fileext = ".rds")
    saveRDS(value, temporary)
    if (file.exists(output) || !file.rename(temporary, output)) stop("could not atomically retain qualification output", call. = FALSE)
    print(value$result, row.names = FALSE); if (!is.null(value$summary)) print(value$summary, row.names = FALSE)
    cat(if (identical(value$result$terminal[[1L]], "success")) {
      if (pre_run) "TEMPORAL_DEP_KERNEL_NLMINB_PRERUN_RETAINED\n" else "TEMPORAL_DEP_KERNEL_NLMINB_CELL_RETAINED\n"
    } else if (pre_run) "TEMPORAL_DEP_KERNEL_NLMINB_PRERUN_ERROR_RETAINED\n" else "TEMPORAL_DEP_KERNEL_NLMINB_CELL_ERROR_RETAINED\n")
    as.integer(!identical(value$result$terminal[[1L]], "success"))
  })
}

if (sys.nframe() == 0L) quit(save = "no", status = .temporal_dep_kernel_nlminb_cli())
