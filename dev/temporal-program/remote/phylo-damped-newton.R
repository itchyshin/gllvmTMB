## One frozen damped-Newton correction from an independently recreated two-pass
## BFGS endpoint.  It never changes the retained campaign or retries BFGS.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name) {
  hit <- grep(paste0("^", name, "="), args, value = TRUE)
  if (length(hit) != 1L) return(NULL)
  sub(paste0("^", name, "="), "", hit)
}
root <- normalizePath(".", mustWork = TRUE)
mode <- arg_value("--mode")
if (is.null(mode)) mode <- "run"
script_dir <- file.path(root, "dev", "temporal-program", "remote")
sys.source(file.path(script_dir, "phylo-recovery-common.R"), envir = globalenv())
sys.source(file.path(script_dir, "phylo-third-pass-common.R"), envir = globalenv())
sys.source(file.path(script_dir, "phylo-damped-newton-common.R"), envir = globalenv())

if (identical(mode, "plan")) {
  cat("TEMPORAL_PHYLO_DAMPED_NEWTON_PLAN_PASS cells=6 correction=one-step\n")
  quit(save = "no", status = 0L)
}
if (!identical(mode, "run")) {
  stop("usage: Rscript --vanilla phylo-damped-newton.R --mode=plan | --mode=run --phi=NUMERIC --seed=INTEGER --output=PATH", call. = FALSE)
}
phi <- suppressWarnings(as.numeric(arg_value("--phi")))
seed <- suppressWarnings(as.integer(arg_value("--seed")))
output <- arg_value("--output")
stage <- arg_value("--stage")
if (is.null(stage)) stage <- "full"
if (length(phi) != 1L || !is.finite(phi) || length(seed) != 1L || is.na(seed) ||
    is.null(output) || !nzchar(output) || !stage %in% c("full", "baseline", "curvature_probe")) {
  stop("run mode requires finite --phi, integer --seed, non-empty --output, and a supported --stage.", call. = FALSE)
}
plan <- temporal_phylo_damped_newton_plan()
plan_row <- which(plan$phi == phi & plan$seed == seed)
if (length(plan_row) != 1L) {
  stop("phi and seed must name exactly one frozen damped-Newton plan row.", call. = FALSE)
}
output <- normalizePath(output, mustWork = FALSE)
if (file.exists(output)) stop("Refusing to overwrite an existing damped-Newton receipt.", call. = FALSE)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)

temporal_phylo_damped_newton_labels <- function(x) {
  raw <- names(x)
  if (is.null(raw) || length(raw) != length(x)) raw <- rep("outer", length(x))
  paste0(raw, "[", ave(seq_along(raw), raw, FUN = seq_along), "]")
}

temporal_phylo_damped_newton_new_object <- function(fit) {
  TMB::MakeADFun(data = fit$tmb_data, parameters = fit$tmb_params,
    map = fit$tmb_map, random = fit$random, DLL = "gllvmTMB", silent = TRUE)
}

temporal_phylo_damped_newton_state <- function(obj, theta) {
  par <- obj$env$parList(theta)
  ## `fn(theta)` has already placed the random effects at their conditional
  ## mode in `last.par`.  TMB's report method reads that full state; passing
  ## the outer parameter vector to report() is a wrong-length call.
  report <- obj$report()
  list(
    phi = as.numeric((1 - 1e-6) * tanh(par$theta_temporal_time[[1L]])),
    temporal_variance = as.numeric(exp(2 * par$theta_temporal_diag)),
    phylo_variance = as.numeric(par$theta_rr_phy^2),
    residual_variance = as.numeric(exp(2 * par$log_sigma_eps[[1L]])),
    eta = as.numeric(report$eta)
  )
}

temporal_phylo_damped_newton_fresh <- function(fit, theta) {
  obj <- tryCatch(temporal_phylo_damped_newton_new_object(fit), error = function(e) e)
  if (inherits(obj, "error")) return(list(eligible = FALSE, error = conditionMessage(obj)))
  labels <- temporal_phylo_damped_newton_labels(theta)
  if (!identical(temporal_phylo_damped_newton_labels(obj$par), labels)) {
    return(list(eligible = FALSE, error = "fresh outer-coordinate order differs"))
  }
  objective <- tryCatch(as.numeric(obj$fn(theta)), error = function(e) NA_real_)
  gradient <- tryCatch(as.numeric(obj$gr(theta)), error = function(e) rep(NA_real_, length(theta)))
  names(gradient) <- labels
  full <- tryCatch(obj$env$last.par, error = function(e) NULL)
  random <- tryCatch(as.integer(obj$env$random), error = function(e) integer())
  n_full <- tryCatch(length(obj$env$par), error = function(e) NA_integer_)
  fixed <- if (is.finite(n_full)) setdiff(seq_len(n_full), random) else integer()
  fixed_ok <- is.numeric(full) && length(full) == n_full && all(is.finite(full)) &&
    length(fixed) == length(theta) && all(abs(full[fixed] - theta) <=
      64 * .Machine$double.eps * max(1, max(abs(theta))))
  score <- tryCatch(TMB:::EvalADFunObject(obj$env$ADGrad, full, order = 0L)[random],
    error = function(e) rep(NA_real_, length(random)))
  hessian <- tryCatch(obj$env$spHess(full, random = TRUE), error = function(e) matrix(NA_real_, 0L, 0L))
  inner <- temporal_phylo_damped_newton_inner_eligibility(score, hessian, fixed_ok)
  fd <- tryCatch(gllvmTMB:::.gllvmTMB_optimizer_finite_difference_audit(
    theta, gradient, obj$fn, relative_step = 1e-5
  ), error = function(e) list(all_finite = FALSE, error = conditionMessage(e)))
  state_result <- tryCatch(list(value = temporal_phylo_damped_newton_state(obj, theta), error = NULL),
    error = function(e) list(value = NULL, error = conditionMessage(e)))
  state <- state_result$value
  list(eligible = is.finite(objective) && all(is.finite(gradient)) && inner$eligible &&
      isTRUE(fd$all_finite) && !is.null(state), objective = objective, gradient = gradient,
    inner = inner, finite_difference = fd, state = state,
    tmb_version = as.character(utils::packageVersion("TMB")), error = state_result$error)
}

temporal_phylo_damped_newton_baseline <- function(fit, role) {
  history <- fit$optimizer_pass_history
  controls <- temporal_phylo_damped_newton_controls()
  expected_gradient <- if (identical(role, "retained_failure")) c(1e-3, 1e-2) else c(0, 1e-3)
  historical_gates <- c(
    two_passes = is.data.frame(history) && nrow(history) == 2L && identical(history$pass, 1:2),
    convergence = is.data.frame(history) && all(history$convergence == 0L),
    accepted = is.data.frame(history) && all(history$accepted),
    derivatives = is.data.frame(history) && all(history$finite_difference_all_finite) &&
      identical(history$finite_difference_n_coordinates, history$finite_difference_n_finite),
    fresh_outer = is.data.frame(history) && all(history$fresh_state_ok),
    inner = is.data.frame(history) && all(history$inner_hessian_available) &&
      all(history$inner_fixed_state_ok) && all(history$inner_score_max <= controls$inner_score_gate),
    gradient = is.data.frame(history) && is.finite(history$outer_gradient_max[[2L]]) &&
      history$outer_gradient_max[[2L]] > expected_gradient[[1L]] &&
      history$outer_gradient_max[[2L]] <= expected_gradient[[2L]]
  )
  fresh <- temporal_phylo_damped_newton_fresh(fit, fit$opt$par)
  objective_tolerance <- 64 * .Machine$double.eps * max(1, abs(fit$opt$objective))
  gradient_tolerance <- 1e-7 * pmax(1, abs(fit$tmb_obj$gr(fit$opt$par)))
  fresh_gates <- c(
    fresh_objective = isTRUE(fresh$eligible) && abs(fresh$objective - fit$opt$objective) <= objective_tolerance,
    fresh_gradient = isTRUE(fresh$eligible) && length(fresh$gradient) == length(fit$opt$par) &&
      all(abs(fresh$gradient - fit$tmb_obj$gr(fit$opt$par)) <= gradient_tolerance)
  )
  list(eligible = all(historical_gates) && all(fresh_gates),
    gates = c(historical_gates, fresh_gates), fresh = fresh, history = history)
}

temporal_phylo_damped_newton_adjudicate <- function(baseline, curvature, step) {
  controls <- temporal_phylo_damped_newton_controls()
  selected <- step$selected
  final <- if (!is.null(selected)) temporal_phylo_damped_newton_fresh(baseline$fit, selected$endpoint) else NULL
  replay <- if (!is.null(final) && isTRUE(final$eligible)) {
    temporal_phylo_damped_newton_fresh(baseline$fit, selected$endpoint)
  } else NULL
  tolerance <- 64 * .Machine$double.eps * max(1, abs(baseline$fresh$objective))
  replay_ok <- !is.null(final) && !is.null(replay) && isTRUE(final$eligible) && isTRUE(replay$eligible) &&
    abs(final$objective - replay$objective) <= tolerance &&
    length(final$gradient) == length(replay$gradient) &&
    all(abs(final$gradient - replay$gradient) <= 1e-7 * pmax(1, abs(final$gradient)))
  drift <- if (!is.null(final) && isTRUE(final$eligible)) c(
    phi = abs(final$state$phi - baseline$fresh$state$phi),
    covariance = max(temporal_phylo_damped_newton_relative_change(final$state$temporal_variance,
      baseline$fresh$state$temporal_variance), temporal_phylo_damped_newton_relative_change(
        final$state$phylo_variance, baseline$fresh$state$phylo_variance)),
    residual = temporal_phylo_damped_newton_relative_change(final$state$residual_variance,
      baseline$fresh$state$residual_variance),
    prediction = temporal_phylo_damped_newton_relative_change(final$state$eta, baseline$fresh$state$eta)
  ) else c(phi = Inf, covariance = Inf, residual = Inf, prediction = Inf)
  gates <- c(
    baseline = baseline$eligible,
    curvature = curvature$eligible,
    step = step$accepted,
    final = !is.null(final) && isTRUE(final$eligible),
    replay = replay_ok,
    objective = !is.null(final) && final$objective <= baseline$fresh$objective + tolerance,
    gradient = !is.null(final) && max(abs(final$gradient)) <= 1e-3,
    phi = drift[["phi"]] <= 1e-5,
    covariance = drift[["covariance"]] <= 1e-4,
    residual = drift[["residual"]] <= 1e-4,
    prediction = drift[["prediction"]] <= 1e-4
  )
  list(accepted = all(gates), gates = gates, rejection_reasons = names(gates)[!gates],
    final = final, replay = replay, drift = drift)
}

load_temporal_program_package(root)
started <- proc.time()[["elapsed"]]
fit_result <- tryCatch(temporal_phylo_third_pass_fit(phi, seed, optimizer_passes = 2L), error = function(e) e)
if (inherits(fit_result, "error")) {
  receipt <- list(schema = "temporal_phylo_damped_newton_v1", phi = phi, seed = seed,
    role = plan$role[[plan_row]], error = conditionMessage(fit_result), accepted = FALSE)
  saveRDS(receipt, output)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_REJECT phi=%s seed=%d output=%s\n", phi, seed, output))
  quit(save = "no", status = 0L)
}
baseline <- temporal_phylo_damped_newton_baseline(fit_result$fit, plan$role[[plan_row]])
baseline$fit <- fit_result$fit
commit <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)

## The checkpoint stages deliberately recreate the frozen two-pass endpoint in
## each worker.  TMB objects contain external pointers and must not be passed
## between processes.  This makes each probe independently auditable and lets
## a scheduler use one core per probe without changing the numerical rule.
if (identical(stage, "baseline")) {
  baseline_receipt <- baseline
  baseline_receipt$fit <- NULL
  receipt <- list(
    schema = "temporal_phylo_damped_newton_checkpoint_v1",
    stage = "baseline", source_commit = unname(commit[[1L]]),
    phi = phi, seed = seed, role = plan$role[[plan_row]], plan = plan,
    theta = unname(fit_result$fit$opt$par), theta_names = names(fit_result$fit$opt$par),
    baseline = baseline_receipt,
    elapsed_seconds = proc.time()[["elapsed"]] - started
  )
  saveRDS(receipt, output)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_BASELINE phi=%s seed=%d output=%s\n", phi, seed, output))
  quit(save = "no", status = 0L)
}

if (identical(stage, "curvature_probe")) {
  checkpoint_path <- arg_value("--checkpoint")
  coordinate <- suppressWarnings(as.integer(arg_value("--coordinate")))
  multiplier <- suppressWarnings(as.numeric(arg_value("--multiplier")))
  direction <- arg_value("--direction")
  if (is.null(checkpoint_path) || !file.exists(checkpoint_path) || is.na(coordinate) ||
      coordinate < 1L || coordinate > length(fit_result$fit$opt$par) ||
      !is.finite(multiplier) || !multiplier %in% temporal_phylo_damped_newton_controls()$fd_multipliers ||
      !direction %in% c("plus", "minus")) {
    stop("curvature_probe requires an existing checkpoint, valid coordinate, fixed multiplier, and plus/minus direction.", call. = FALSE)
  }
  checkpoint <- readRDS(checkpoint_path)
  theta <- fit_result$fit$opt$par
  checkpoint_ok <- is.list(checkpoint) &&
    identical(checkpoint$schema, "temporal_phylo_damped_newton_checkpoint_v1") &&
    identical(checkpoint$stage, "baseline") && identical(as.numeric(checkpoint$phi), phi) &&
    identical(as.integer(checkpoint$seed), seed) && identical(checkpoint$theta_names, names(theta)) &&
    isTRUE(all.equal(as.numeric(checkpoint$theta), as.numeric(theta), tolerance = 0))
  if (!checkpoint_ok) stop("curvature_probe endpoint does not exactly reproduce its frozen baseline checkpoint.", call. = FALSE)
  h <- multiplier * .Machine$double.eps^(1 / 3) * max(1, abs(theta[[coordinate]]))
  endpoint <- theta
  endpoint[[coordinate]] <- endpoint[[coordinate]] + if (identical(direction, "plus")) h else -h
  evaluated <- temporal_phylo_damped_newton_fresh(fit_result$fit, endpoint)
  receipt <- list(
    schema = "temporal_phylo_damped_newton_checkpoint_v1",
    stage = "curvature_probe", source_commit = unname(commit[[1L]]),
    phi = phi, seed = seed, role = plan$role[[plan_row]],
    checkpoint = normalizePath(checkpoint_path), coordinate = coordinate,
    coordinate_name = names(theta)[[coordinate]], multiplier = multiplier,
    direction = direction, step = h, endpoint = endpoint, evaluated = evaluated,
    elapsed_seconds = proc.time()[["elapsed"]] - started
  )
  saveRDS(receipt, output)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_CURVATURE_PROBE phi=%s seed=%d coordinate=%d multiplier=%s direction=%s output=%s\n",
    phi, seed, coordinate, multiplier, direction, output))
  quit(save = "no", status = 0L)
}

curvature <- if (baseline$eligible) temporal_phylo_damped_newton_curvature(
  fit_result$fit$opt$par, function(theta) temporal_phylo_damped_newton_fresh(fit_result$fit, theta)$gradient
) else list(eligible = FALSE, rejection_reasons = "baseline_ineligible")
step <- if (isTRUE(curvature$eligible)) temporal_phylo_damped_newton_select_step(
  theta = fit_result$fit$opt$par, direction = curvature$direction,
  gradient = curvature$gradient, objective = baseline$fresh$objective,
  evaluate = function(endpoint) temporal_phylo_damped_newton_fresh(fit_result$fit, endpoint)
) else list(accepted = FALSE, selected = NULL, trials = list(), rejection_reasons = "curvature_ineligible")
adjudication <- temporal_phylo_damped_newton_adjudicate(baseline, curvature, step)
baseline_receipt <- baseline
baseline_receipt$fit <- NULL
receipt <- list(
  schema = "temporal_phylo_damped_newton_v1", source_commit = unname(commit[[1L]]),
  tmb_version = as.character(utils::packageVersion("TMB")), phi = phi, seed = seed,
  role = plan$role[[plan_row]], plan = plan, controls = temporal_phylo_damped_newton_controls(),
  baseline = baseline_receipt, curvature = curvature, step = step, adjudication = adjudication,
  elapsed_seconds = proc.time()[["elapsed"]] - started
)
saveRDS(receipt, output)
cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_%s phi=%s seed=%d output=%s\n",
  if (isTRUE(adjudication$accepted)) "ACCEPT" else "REJECT", phi, seed, output))
