## Pure numerical controls for the one-step temporal--phylogenetic damped
## Newton qualification.  This is intentionally independent of the ISDM
## continuation helper: its only caller is the frozen six-cell candidate.

temporal_phylo_damped_newton_controls <- function() {
  list(
    inner_score_gate = 1e-7,
    hessian_antisymmetry_gate = 1e-7,
    hessian_condition_gate = 1e8,
    direction_disagreement_gate = 1e-6,
    solve_residual_gate = 1e-10,
    armijo_c = 1e-4,
    alpha = 2^-(0:8),
    fd_scale = .Machine$double.eps^(1 / 3),
    fd_multipliers = c(.5, 1, 2)
  )
}

## This ordering is frozen before the numerical result.  The first three rows
## are precisely the retained C3 strict-gradient failures; the remaining rows
## are the first positional passing seed in each persistence stratum.
temporal_phylo_damped_newton_plan <- function() {
  data.frame(
    role = c(rep("retained_failure", 3L), rep("passing_control", 3L)),
    phi = c(0, .6, .6, -.4, 0, .6),
    seed = c(2609188L, 2609183L, 2609185L, 2609181L, 2609181L, 2609181L),
    stringsAsFactors = FALSE
  )
}

temporal_phylo_damped_newton_validate_plan <- function(plan) {
  identical(plan, temporal_phylo_damped_newton_plan())
}

temporal_phylo_damped_newton_relative_change <- function(x, y) {
  if (length(x) != length(y) || any(!is.finite(x)) || any(!is.finite(y))) return(Inf)
  sqrt(sum((x - y)^2)) / max(1, sqrt(sum(y^2)))
}

temporal_phylo_damped_newton_inner_eligibility <- function(score, hessian, fixed_state_ok) {
  controls <- temporal_phylo_damped_newton_controls()
  dimension_ok <- (is.matrix(hessian) || inherits(hessian, "Matrix")) &&
    nrow(hessian) == ncol(hessian) && nrow(hessian) == length(score) && nrow(hessian) > 0L
  finite <- dimension_ok && all(is.finite(score)) && all(is.finite(hessian))
  symmetric <- finite && isTRUE(Matrix::isSymmetric(hessian, tol = 1e-10))
  eigenvalues <- if (symmetric) tryCatch(
    eigen(as.matrix(hessian), symmetric = TRUE, only.values = TRUE)$values,
    error = function(e) rep(NA_real_, nrow(hessian))
  ) else rep(NA_real_, if (dimension_ok) nrow(hessian) else 0L)
  pd <- symmetric && all(is.finite(eigenvalues)) && min(eigenvalues) > 0
  score_max <- if (length(score) && all(is.finite(score))) max(abs(score)) else NA_real_
  gates <- c(
    fixed_state = isTRUE(fixed_state_ok),
    random_score = is.finite(score_max) && score_max <= controls$inner_score_gate,
    random_hessian_dimension = dimension_ok,
    random_hessian_finite = finite,
    random_hessian_symmetric = symmetric,
    random_hessian_positive_definite = pd
  )
  list(
    eligible = all(gates), gates = gates, rejection_reasons = names(gates)[!gates],
    score_max = score_max, dimension = if (dimension_ok) nrow(hessian) else NA_integer_,
    symmetric = symmetric, positive_definite = pd
  )
}

temporal_phylo_damped_newton_curvature <- function(theta, gradient_fn) {
  controls <- temporal_phylo_damped_newton_controls()
  theta_names <- names(theta)
  theta <- as.numeric(theta)
  names(theta) <- theta_names
  if (is.null(names(theta))) names(theta) <- paste0("theta[", seq_along(theta), "]")
  gradient <- as.numeric(gradient_fn(theta))
  if (length(gradient) != length(theta) || any(!is.finite(gradient))) {
    return(list(eligible = FALSE, rejection_reasons = "baseline_gradient", gradient = gradient))
  }
  names(gradient) <- names(theta)
  steps <- outer(controls$fd_multipliers,
    controls$fd_scale * pmax(1, abs(theta)), "*")
  colnames(steps) <- names(theta)
  scales <- vector("list", length(controls$fd_multipliers))
  for (k in seq_along(controls$fd_multipliers)) {
    h <- steps[k, ]
    raw <- matrix(NA_real_, length(theta), length(theta), dimnames = list(names(theta), names(theta)))
    perturbations <- vector("list", length(theta))
    for (j in seq_along(theta)) {
      plus <- theta; minus <- theta
      plus[[j]] <- plus[[j]] + h[[j]]; minus[[j]] <- minus[[j]] - h[[j]]
      g_plus <- as.numeric(gradient_fn(plus)); g_minus <- as.numeric(gradient_fn(minus))
      if (length(g_plus) == length(theta) && length(g_minus) == length(theta) &&
          all(is.finite(g_plus)) && all(is.finite(g_minus))) {
        raw[, j] <- (g_plus - g_minus) / (2 * h[[j]])
      }
      perturbations[[j]] <- list(plus = plus, minus = minus, gradient_plus = g_plus,
        gradient_minus = g_minus)
    }
    symmetric <- (raw + t(raw)) / 2
    antisymmetry <- if (all(is.finite(raw))) {
      max(abs(raw - t(raw))) / max(1, max(abs(raw)))
    } else Inf
    eigenvalues <- if (all(is.finite(symmetric))) {
      tryCatch(eigen(symmetric, symmetric = TRUE, only.values = TRUE)$values,
        error = function(e) rep(NA_real_, length(theta)))
    } else rep(NA_real_, length(theta))
    pd <- all(is.finite(eigenvalues)) && min(eigenvalues) > 0
    condition <- if (pd) max(eigenvalues) / min(eigenvalues) else Inf
    direction <- if (pd && is.finite(condition) && condition <= controls$hessian_condition_gate) {
      tryCatch(-solve(symmetric, gradient), error = function(e) rep(NA_real_, length(theta)))
    } else rep(NA_real_, length(theta))
    solve_residual <- if (all(is.finite(direction))) {
      max(abs(symmetric %*% direction + gradient))
    } else Inf
    scales[[k]] <- list(multiplier = controls$fd_multipliers[[k]], step = h,
      perturbations = perturbations, raw_hessian = raw, hessian = symmetric,
      antisymmetry = antisymmetry, eigenvalues = eigenvalues, positive_definite = pd,
      condition = condition, direction = stats::setNames(direction, names(theta)),
      solve_residual = solve_residual)
  }
  default <- scales[[which(controls$fd_multipliers == 1)[[1L]]]]
  directions <- lapply(scales, `[[`, "direction")
  direction_disagreement <- max(vapply(directions, function(d) {
    if (length(d) != length(default$direction) || any(!is.finite(d)) ||
        any(!is.finite(default$direction))) return(Inf)
    sqrt(sum((d - default$direction)^2)) /
      max(.Machine$double.eps, sqrt(sum(default$direction^2)))
  }, numeric(1)))
  scale_symmetric <- vapply(scales, function(s) is.finite(s$antisymmetry) &&
    s$antisymmetry <= controls$hessian_antisymmetry_gate, logical(1))
  scale_pd <- vapply(scales, `[[`, logical(1), "positive_definite")
  scale_condition <- vapply(scales, function(s) is.finite(s$condition) &&
    s$condition <= controls$hessian_condition_gate, logical(1))
  scale_direction <- vapply(scales, function(s) all(is.finite(s$direction)), logical(1))
  g_dot_direction <- sum(gradient * default$direction)
  gates <- c(
    finite_gradient = all(is.finite(gradient)),
    symmetric = all(scale_symmetric),
    positive_definite = all(scale_pd),
    condition = all(scale_condition),
    finite_direction = all(scale_direction),
    direction_agreement = is.finite(direction_disagreement) &&
      direction_disagreement <= controls$direction_disagreement_gate,
    default_solve = is.finite(default$solve_residual) &&
      default$solve_residual <= controls$solve_residual_gate * max(1, max(abs(gradient))),
    descent = is.finite(g_dot_direction) && g_dot_direction < 0
  )
  list(eligible = all(gates), gates = gates, rejection_reasons = names(gates)[!gates],
    gradient = gradient, scales = scales, direction = default$direction,
    condition = default$condition, solve_residual = default$solve_residual,
    direction_disagreement = direction_disagreement, g_dot_direction = g_dot_direction)
}

temporal_phylo_damped_newton_select_step <- function(theta, direction, gradient, objective, evaluate) {
  controls <- temporal_phylo_damped_newton_controls()
  theta <- theta + 0
  trials <- vector("list", 0L)
  for (i in seq_along(controls$alpha)) {
    alpha <- controls$alpha[[i]]
    endpoint <- theta + alpha * direction
    evaluated <- tryCatch(evaluate(endpoint), error = function(e) list(
      eligible = FALSE, objective = NA_real_, error = conditionMessage(e), endpoint = endpoint
    ))
    armijo_limit <- objective + controls$armijo_c * alpha * sum(gradient * direction)
    armijo <- isTRUE(evaluated$eligible) && is.finite(evaluated$objective) &&
      evaluated$objective <= armijo_limit + 64 * .Machine$double.eps * max(1, abs(objective))
    trial <- c(list(index = as.integer(i), alpha = alpha, endpoint = endpoint,
      armijo_limit = armijo_limit, armijo = armijo), evaluated)
    trials[[i]] <- trial
    if (armijo) return(list(accepted = TRUE, selected_index = as.integer(i),
      selected_alpha = alpha, selected = trial, trials = trials, rejection_reasons = character()))
  }
  list(accepted = FALSE, selected_index = NA_integer_, selected_alpha = NA_real_,
    selected = NULL, trials = trials, rejection_reasons = "no_armijo_eligible_step")
}

## This final gate is deliberately pure: the sequential runner supplies fresh
## TMB evaluations, while the checkpointed runner supplies independently
## retained endpoint receipts. Keeping the decision here makes their criteria
## identical.
temporal_phylo_damped_newton_adjudicate_evaluated <- function(baseline, curvature, step, final, replay) {
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
