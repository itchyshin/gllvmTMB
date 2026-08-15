#!/usr/bin/env Rscript

## Private, fixed-grid constrained parametric-bootstrap test-inversion pilot
## for LA-MSPL.  This is a developer receipt generator, not a public interval
## method.  It simulates from a target-constrained, nuisance-reoptimised
## penalised MSPL state and retains every failed refit rather than replacing it.

args <- commandArgs(trailingOnly = TRUE)
`%||%` <- function(x, y) if (is.null(x)) y else x

arg_value <- function(name, default = NULL) {
  hit <- match(name, args)
  if (is.na(hit)) return(default)
  if (hit == length(args)) stop("Missing value for ", name, call. = FALSE)
  args[[hit + 1L]]
}

atomic_write_rds <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(".mspl-inversion-", dirname(path), fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, compress = "gzip", version = 3L)
  if (!file.rename(tmp, path)) stop("Could not atomically publish ", path, call. = FALSE)
  invisible(path)
}

pilot_cases <- function() {
  data.frame(
    case_id = c("C001", "C011"),
    regime = c("baseline", "high_prevalence"),
    link = c("logit", "cloglog"),
    beta_shift = c(0, 1.5),
    lambda_scale = c(1, 1),
    seed = c(815101L, 815111L),
    stringsAsFactors = FALSE
  )
}

validate_contract <- function() {
  cases <- pilot_cases()
  if (!identical(cases$case_id, c("C001", "C011")) ||
      !identical(cases$link, c("logit", "cloglog"))) {
    stop("The constrained-inversion pilot case contract drifted.", call. = FALSE)
  }
  offsets <- c(-1, -0.5, 0, 0.5, 1)
  if (!identical(offsets, sort(offsets)) || !identical(offsets[[3L]], 0)) {
    stop("The constrained-inversion pilot grid must be fixed and centred.", call. = FALSE)
  }
  invisible(TRUE)
}

inverse_link <- function(eta, link) {
  switch(link,
    logit = stats::plogis(eta),
    probit = stats::pnorm(eta),
    cloglog = -expm1(-exp(eta)),
    stop("Unsupported pilot link.", call. = FALSE)
  )
}

simulate_fixture <- function(case) {
  set.seed(as.integer(case$seed[[1L]]))
  n_site <- 24L
  trait <- factor(rep(sprintf("t%d", seq_len(3L)), n_site),
    levels = sprintf("t%d", seq_len(3L)))
  site <- factor(rep(sprintf("s%02d", seq_len(n_site)), each = 3L))
  z <- stats::rnorm(n_site)
  beta <- c(-0.5, 0.1, 0.55) + case$beta_shift[[1L]]
  lambda <- case$lambda_scale[[1L]] * c(0.8, -0.55, 0.35)
  eta <- beta[as.integer(trait)] + z[as.integer(site)] * lambda[as.integer(trait)]
  data.frame(
    site = site, trait = trait,
    y = stats::rbinom(length(eta), 1L, inverse_link(eta, case$link[[1L]])),
    stringsAsFactors = FALSE
  )
}

fit_mspl <- function(data, link) {
  gllvmTMB::gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1L, unique = FALSE),
    data = data, family = stats::binomial(link = link), estimator = "mspl",
    control = gllvmTMB::gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    ),
    silent = TRUE
  )
}

fit_status <- function(fit) {
  if (inherits(fit, "error")) return(list(status = "refit_error", message = conditionMessage(fit)))
  ids <- tryCatch(as.integer(fit$tmb_obj$env$data$estimator_id), error = function(e) NA_integer_)
  if (!identical(ids, 1L)) return(list(status = "objective_identity_failed", message = "active estimator_id is not 1"))
  if (!identical(as.integer(fit$opt$convergence), 0L)) {
    return(list(status = "refit_optimizer_failed", message = fit$opt$message %||% ""))
  }
  list(status = "ok", message = "")
}

run_target <- function(case, fit, target_index, target_value, bootstrap_reps, seed) {
  state <- gllvmTMB:::.gllvmTMB_mspl_constrained_simulation_state(
    fit, which = target_index, target = target_value
  )
  base <- data.frame(
    case_id = case$case_id[[1L]], regime = case$regime[[1L]], link = case$link[[1L]],
    target = 1L, target_value = target_value, bootstrap_reps = as.integer(bootstrap_reps),
    constrained_status = state$status, constrained_message = state$message %||% "",
    objective_source = state$objective_source %||% NA_character_,
    estimator_id = state$estimator_id %||% NA_integer_, stringsAsFactors = FALSE
  )
  if (!identical(state$status, "ok") || !identical(state$estimator_id, 1L) ||
      !identical(state$objective_source, "fit$tmb_obj (penalised LA-MSPL)")) {
    base$test_status <- "constrained_state_failed"
    base$usable_reps <- 0L
    base$p_value <- NA_real_
    return(list(trace = base, attempts = data.frame()))
  }

  observed <- abs(fit$opt$par[[target_index]] - target_value)
  attempts <- vector("list", bootstrap_reps)
  for (rep_id in seq_len(bootstrap_reps)) {
    draw <- tryCatch(
      stats::simulate(state$simulation_fit, nsim = 1L, seed = as.integer(seed + rep_id),
        condition_on_RE = FALSE),
      error = identity
    )
    if (inherits(draw, "error")) {
      attempts[[rep_id]] <- data.frame(replicate = rep_id, status = "simulate_error",
        message = conditionMessage(draw), estimate = NA_real_, statistic = NA_real_)
      next
    }
    data <- simulate_fixture(case)
    data$y <- as.integer(draw[, 1L])
    refit <- tryCatch(fit_mspl(data, case$link[[1L]]), error = identity)
    status <- fit_status(refit)
    estimate <- if (identical(status$status, "ok")) refit$opt$par[[target_index]] else NA_real_
    attempts[[rep_id]] <- data.frame(replicate = rep_id, status = status$status,
      message = status$message, estimate = estimate,
      statistic = if (is.finite(estimate)) abs(estimate - target_value) else NA_real_)
  }
  attempts <- do.call(rbind, attempts)
  usable <- attempts$status == "ok" & is.finite(attempts$statistic)
  p_value <- if (any(usable)) {
    (1 + sum(attempts$statistic[usable] >= observed)) / (1 + sum(usable))
  } else NA_real_
  base$test_status <- if (is.finite(p_value)) "ok" else "no_usable_bootstrap_refits"
  base$usable_reps <- sum(usable)
  base$p_value <- p_value
  base$observed_statistic <- observed
  attempts$case_id <- case$case_id[[1L]]
  attempts$target_value <- target_value
  list(trace = base, attempts = attempts)
}

run_pilot <- function(mode, output) {
  validate_contract()
  settings <- switch(mode,
    smoke = list(bootstrap_reps = 2L, offsets = c(-0.5, 0, 0.5)),
    pilot = list(bootstrap_reps = 20L, offsets = c(-1, -0.5, 0, 0.5, 1)),
    stop("Use smoke or pilot.", call. = FALSE)
  )
  if (identical(Sys.getenv("GLLVM_TMB_PILOT_SOURCE"), "true")) devtools::load_all(quiet = TRUE) else library(gllvmTMB)
  pieces <- lapply(seq_len(nrow(pilot_cases())), function(i) {
    case <- pilot_cases()[i, , drop = FALSE]
    fit <- fit_mspl(simulate_fixture(case), case$link[[1L]])
    status <- fit_status(fit)
    if (!identical(status$status, "ok")) {
      return(list(trace = data.frame(case_id = case$case_id, regime = case$regime, link = case$link,
        target = 1L, target_value = NA_real_, bootstrap_reps = settings$bootstrap_reps,
        constrained_status = status$status, constrained_message = status$message,
        objective_source = NA_character_, estimator_id = NA_integer_,
        test_status = "outer_fit_failed", usable_reps = 0L, p_value = NA_real_), attempts = data.frame()))
    }
    idx <- which(names(fit$opt$par) == "b_fix")
    target_index <- idx[[1L]]
    lapply(seq_along(settings$offsets), function(j) run_target(
      case, fit, target_index, fit$opt$par[[target_index]] + settings$offsets[[j]],
      settings$bootstrap_reps, seed = as.integer(case$seed[[1L]] + 1000L * j)
    ))
  })
  flat <- unlist(pieces, recursive = FALSE)
  trace <- do.call(rbind, lapply(flat, `[[`, "trace"))
  attempt_parts <- Filter(function(x) nrow(x) > 0L, lapply(flat, `[[`, "attempts"))
  attempts <- if (length(attempt_parts)) {
    do.call(rbind, attempt_parts)
  } else {
    data.frame(
      replicate = integer(), status = character(), message = character(),
      estimate = numeric(), statistic = numeric(), case_id = character(),
      target_value = numeric(), stringsAsFactors = FALSE
    )
  }
  expected <- sum(trace$constrained_status == "ok") * settings$bootstrap_reps
  if (nrow(attempts) != expected) stop("Every bootstrap attempt must be retained.", call. = FALSE)
  if (any(trace$constrained_status == "ok" & trace$estimator_id != 1L) ||
      any(trace$constrained_status == "ok" & trace$objective_source != "fit$tmb_obj (penalised LA-MSPL)")) {
    stop("The pilot objective identity contract failed.", call. = FALSE)
  }
  receipt <- list(
    kind = "private_mspl_constrained_bootstrap_test_inversion_pilot_v1",
    mode = mode, cases = pilot_cases(), settings = settings, trace = trace,
    attempts = attempts, public_fence = "unchanged",
    claim_boundary = "finite fixed-grid pilot only; not calibrated coverage or a public confidence interval"
  )
  atomic_write_rds(receipt, file.path(output, "receipt.rds"))
  invisible(receipt)
}

run_cli <- function() {
  command <- if (length(args)) args[[1L]] else ""
  if (identical(command, "validate")) return(validate_contract())
  output <- arg_value("--output")
  if (!nzchar(output %||% "")) stop("Use --output <outside-repository-root>.", call. = FALSE)
  if (command %in% c("smoke", "pilot")) return(run_pilot(command, output))
  stop("Use validate, smoke, or pilot.", call. = FALSE)
}

if (!identical(Sys.getenv("MSPL_INVERSION_SOURCE_ONLY"), "true")) run_cli()
