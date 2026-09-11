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
    is.null(output) || !nzchar(output) || !stage %in% c("full", "baseline", "curvature_probe", "endpoint_probe")) {
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
  selected <- step$selected
  final <- if (!is.null(selected)) temporal_phylo_damped_newton_fresh(baseline$fit, selected$endpoint) else NULL
  replay <- if (!is.null(final) && isTRUE(final$eligible)) {
    temporal_phylo_damped_newton_fresh(baseline$fit, selected$endpoint)
  } else NULL
  temporal_phylo_damped_newton_adjudicate_evaluated(baseline, curvature, step, final, replay)
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

if (identical(stage, "endpoint_probe")) {
  checkpoint_path <- arg_value("--checkpoint")
  purpose <- arg_value("--purpose")
  curvature_path <- arg_value("--curvature")
  step_path <- arg_value("--step")
  if (is.null(checkpoint_path) || !file.exists(checkpoint_path) ||
      !purpose %in% c("line_trial", "final_replay")) {
    stop("endpoint_probe requires an existing checkpoint and a supported purpose.", call. = FALSE)
  }
  checkpoint <- readRDS(checkpoint_path)
  theta <- fit_result$fit$opt$par
  checkpoint_ok <- is.list(checkpoint) &&
    identical(checkpoint$schema, "temporal_phylo_damped_newton_checkpoint_v1") &&
    identical(checkpoint$stage, "baseline") && identical(as.numeric(checkpoint$phi), phi) &&
    identical(as.integer(checkpoint$seed), seed) && identical(checkpoint$theta_names, names(theta)) &&
    isTRUE(all.equal(as.numeric(checkpoint$theta), as.numeric(theta), tolerance = 0))
  if (!checkpoint_ok) stop("endpoint probe does not exactly reproduce its frozen baseline checkpoint.", call. = FALSE)
  if (identical(purpose, "line_trial")) {
    alpha <- suppressWarnings(as.numeric(arg_value("--alpha")))
    if (is.null(curvature_path) || !file.exists(curvature_path) || !is.finite(alpha) ||
        !alpha %in% temporal_phylo_damped_newton_controls()$alpha) {
      stop("line_trial requires a curvature receipt and a frozen line-search alpha.", call. = FALSE)
    }
    source <- readRDS(curvature_path)
    source_ok <- is.list(source) && identical(source$schema, "temporal_phylo_damped_newton_checkpoint_v1") &&
      identical(source$stage, "curvature_collect") && identical(as.numeric(source$phi), phi) &&
      identical(as.integer(source$seed), seed) && identical(source$theta_names, names(theta)) &&
      isTRUE(all.equal(as.numeric(source$theta), as.numeric(theta), tolerance = 0)) && isTRUE(source$curvature$eligible)
    if (!source_ok) stop("line trial does not match an eligible frozen curvature receipt.", call. = FALSE)
    endpoint <- theta + alpha * source$curvature$direction
    source_path <- normalizePath(curvature_path)
  } else {
    replicate_id <- suppressWarnings(as.integer(arg_value("--replicate")))
    if (is.null(step_path) || !file.exists(step_path) || is.na(replicate_id) || !replicate_id %in% 1:2) {
      stop("final_replay requires a step receipt and replicate 1 or 2.", call. = FALSE)
    }
    source <- readRDS(step_path)
    source_ok <- is.list(source) && identical(source$schema, "temporal_phylo_damped_newton_checkpoint_v1") &&
      identical(source$stage, "step_collect") && identical(as.numeric(source$phi), phi) &&
      identical(as.integer(source$seed), seed) && identical(source$theta_names, names(theta)) &&
      isTRUE(all.equal(as.numeric(source$theta), as.numeric(theta), tolerance = 0)) && isTRUE(source$step$accepted) &&
      !is.null(source$step$selected$endpoint)
    if (!source_ok) stop("final replay does not match an accepted frozen step receipt.", call. = FALSE)
    endpoint <- source$step$selected$endpoint
    source_path <- normalizePath(step_path)
    alpha <- source$step$selected_alpha
  }
  evaluated <- temporal_phylo_damped_newton_fresh(fit_result$fit, endpoint)
  receipt <- list(
    schema = "temporal_phylo_damped_newton_checkpoint_v1",
    stage = "endpoint_probe", purpose = purpose, source_commit = unname(commit[[1L]]),
    phi = phi, seed = seed, role = plan$role[[plan_row]], checkpoint = normalizePath(checkpoint_path),
    source = source_path, alpha = alpha, replicate = if (identical(purpose, "final_replay")) replicate_id else NA_integer_,
    endpoint = endpoint, evaluated = evaluated, elapsed_seconds = proc.time()[["elapsed"]] - started
  )
  saveRDS(receipt, output)
  cat(sprintf("TEMPORAL_PHYLO_DAMPED_NEWTON_ENDPOINT_PROBE purpose=%s phi=%s seed=%d output=%s\n",
    purpose, phi, seed, output))
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
