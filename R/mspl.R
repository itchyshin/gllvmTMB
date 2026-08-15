## Lane B: opt-in maximum softly penalised Laplace likelihood --------------
##
## This file owns the small R-side contract shared by the public API,
## fit assembly, and S3 methods.  The numerical Jeffreys log-determinant and
## loading penalty live in the TMB template; R resolves the fixed-effect map,
## fences the admitted model surface, and labels the resulting point estimate.

.gllvmTMB_is_mspl <- function(x) {
  estimator <- tryCatch(x$estimator, error = function(e) NULL)
  inherits(x, "gllvmTMB_mspl") ||
    identical(toupper(estimator %||% ""), "MSPL")
}

.gllvmTMB_mspl_abort <- function(message, ..., class = "gllvmTMB_mspl_unsupported") {
  cli::cli_abort(c(message, ...), class = class, .envir = parent.frame())
}

.gllvmTMB_mspl_inference_abort <- function(what) {
  cli::cli_abort(c(
    "{.fn {what}} is not available for an {.code estimator = \"mspl\"} fit.",
    "i" = "LA-MSPL is an experimental point estimator; repeated-sampling inference is not yet calibrated.",
    ">" = "Use {.fn coef}, {.fn predict}, or the covariance extractors for point estimates, and fit {.code estimator = \"ml\"} when likelihood-based inference is required."
  ), class = "gllvmTMB_mspl_inference_unsupported")
}

.gllvmTMB_mspl_assert_inference <- function(x, what) {
  if (.gllvmTMB_is_mspl(x)) {
    .gllvmTMB_mspl_inference_abort(what)
  }
  invisible(x)
}

## Internal feasibility diagnostic only.  A Godambe covariance needs additive
## score contributions from the *active* estimating criterion.  The admitted
## LA-MSPL tape is a TMB Laplace marginal objective with global penalties, and
## no validated additive site-score decomposition is exposed. This helper
## records that typed blocker; it does not compute a covariance or an interval.
.gllvmTMB_mspl_sandwich_feasibility <- function(fit) {
  if (!.gllvmTMB_is_mspl(fit)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL sandwich feasibility diagnostic requires an {.code estimator = \"mspl\"} fit.",
      class = "gllvmTMB_mspl_sandwich_input"
    )
  }

  obj <- fit$tmb_obj
  penalty_off <- fit$mspl$unpenalized_tmb_obj
  if (
    is.null(obj) ||
      identical(obj, penalty_off) ||
      !identical(as.integer(obj$env$data$estimator_id), 1L)
  ) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL sandwich feasibility diagnostic could not verify the active penalised TMB objective.",
      class = "gllvmTMB_mspl_sandwich_objective"
    )
  }

  report_names <- names(fit$report %||% list())
  score_fields <- report_names[grepl(
    "(^|_)(score|gradient|estimating)(_|$)",
    report_names
  )]

  list(
    status = "score_decomposition_unavailable",
    objective_source = "fit$tmb_obj (penalised LA-MSPL)",
    estimator_id = 1L,
    outer_gradient = "total_only",
    random_effect_route = "TMB Laplace marginal objective",
    global_penalties = c(
      "N_eff-scaled Jeffreys log-determinant",
      "loading/covariance penalties"
    ),
    reported_per_unit_score_fields = score_fields,
    reason = c(
      "The active TMB outer gradient is total-only; no additive site-score decomposition is exposed.",
      "The Laplace log determinant is added outside the C++ joint objective.",
      "The active MSPL penalties use global design and effective-sample quantities."
    )
  )
}

## Internal feasibility instrument only. This is intentionally separate from
## the public profile/confint dispatch: a finite trace establishes neither
## calibrated standard errors nor confidence-interval coverage.
.gllvmTMB_mspl_profile_feasibility <- function(
  fit,
  which = 1L,
  step = 0.5,
  max_steps = 6L,
  level = 0.95,
  control = list(eval.max = 100L, iter.max = 100L),
  refinement_steps = 12L,
  bracket_tolerance = 1.25e-4
) {
  if (!.gllvmTMB_is_mspl(fit)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile probe requires an {.code estimator = \"mspl\"} fit.",
      class = "gllvmTMB_mspl_profile_input"
    )
  }
  if (
    !is.numeric(which) ||
      length(which) != 1L ||
      which %% 1 != 0 ||
      which < 1L ||
      which > length(fit$opt$par) ||
      names(fit$opt$par)[which] != "b_fix"
  ) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile probe requires one resolved {.field b_fix} coordinate.",
      class = "gllvmTMB_mspl_profile_target"
    )
  }
  if (
    !is.numeric(step) ||
      length(step) != 1L ||
      !is.finite(step) ||
      step <= 0 ||
      !is.numeric(max_steps) ||
      length(max_steps) != 1L ||
      max_steps < 1L ||
      max_steps %% 1 != 0 ||
      !is.numeric(level) ||
      length(level) != 1L ||
      !is.finite(level) ||
      level <= 0 ||
      level >= 1 ||
      !is.numeric(refinement_steps) ||
      length(refinement_steps) != 1L ||
      refinement_steps < 0L ||
      refinement_steps %% 1 != 0 ||
      !is.numeric(bracket_tolerance) ||
      length(bracket_tolerance) != 1L ||
      !is.finite(bracket_tolerance) ||
      bracket_tolerance <= 0
  ) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile grid requires positive finite grid and refinement controls, with {.arg level} in (0, 1).",
      class = "gllvmTMB_mspl_profile_grid"
    )
  }

  obj <- fit$tmb_obj
  penalty_off <- fit$mspl$unpenalized_tmb_obj
  if (
    is.null(obj) ||
      identical(obj, penalty_off) ||
      !identical(as.integer(obj$env$data$estimator_id), 1L)
  ) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile probe could not verify the active penalised TMB objective.",
      class = "gllvmTMB_mspl_profile_objective"
    )
  }
  checkpoint <- .gllvmTMB_profile_tmb_checkpoint(obj)
  on.exit(.gllvmTMB_restore_profile_tmb_checkpoint(obj, checkpoint), add = TRUE)

  mle_par <- as.numeric(fit$opt$par)
  mle_objective <- as.numeric(fit$opt$objective)
  nuisance_index <- setdiff(seq_along(mle_par), as.integer(which))
  threshold <- stats::qchisq(level, df = 1L) / 2

  evaluate_point <- function(target, start, side, stage) {
    objective <- function(nuisance) {
      par <- mle_par
      par[nuisance_index] <- nuisance
      par[which] <- target
      obj$fn(par)
    }
    gradient <- function(nuisance) {
      par <- mle_par
      par[nuisance_index] <- nuisance
      par[which] <- target
      obj$gr(par)[nuisance_index]
    }
    ans <- tryCatch(
      nlminb(start, objective = objective, gradient = gradient, control = control),
      error = identity
    )
    if (inherits(ans, "error")) {
      return(list(
        row = data.frame(
          target = target, objective = NA_real_, objective_delta = NA_real_,
          convergence = NA_integer_, message = conditionMessage(ans),
          finite = FALSE, nuisance_reoptimized = FALSE, side = side,
          stage = stage, stringsAsFactors = FALSE
        ),
        nuisance = start
      ))
    }
    finite <- is.finite(ans$objective)
    list(
      row = data.frame(
        target = target,
        objective = if (finite) as.numeric(ans$objective) else NA_real_,
        objective_delta = if (finite) as.numeric(ans$objective) - mle_objective else NA_real_,
        convergence = as.integer(ans$convergence),
        message = ans$message %||% "", finite = finite,
        nuisance_reoptimized = identical(as.integer(ans$convergence), 0L),
        side = side, stage = stage, stringsAsFactors = FALSE
      ),
      nuisance = as.numeric(ans$par)
    )
  }

  successful <- function(point) {
    is.list(point) && is.data.frame(point$row) &&
      isTRUE(point$row$finite[[1L]]) &&
      identical(point$row$convergence[[1L]], 0L) &&
      is.finite(point$row$objective_delta[[1L]])
  }

  centre_point <- evaluate_point(
    mle_par[which], mle_par[nuisance_index], "centre", "centre"
  )
  centre <- centre_point$row
  centre_tolerance <- 1e-7 * (1 + abs(mle_objective))
  centre_status <- if (!centre$finite) {
    "nonfinite"
  } else if (centre$convergence != 0L) {
    "optimizer_failed"
  } else if (abs(centre$objective_delta) > centre_tolerance) {
    "centre_mismatch"
  } else {
    "matched"
  }

  walk_side <- function(direction) {
    values <- mle_par[which] + direction * step * seq_len(as.integer(max_steps))
    points <- list()
    previous_success <- centre_point
    start <- centre_point$nuisance
    bracket <- NULL
    for (target in values) {
      point <- evaluate_point(
        target, start, if (direction < 0) "lower" else "upper", "grid"
      )
      points[[length(points) + 1L]] <- point
      if (successful(point)) {
        start <- point$nuisance
        if (successful(previous_success) &&
            previous_success$row$objective_delta[[1L]] < threshold &&
            point$row$objective_delta[[1L]] >= threshold) {
          bracket <- list(inside = previous_success, outside = point)
          break
        }
        previous_success <- point
      } else {
        previous_success <- NULL
      }
    }

    if (is.null(bracket)) {
      rows <- do.call(rbind, lapply(points, `[[`, "row"))
      status <- if (any(!rows$finite)) {
        "nonfinite"
      } else if (any(rows$convergence != 0L)) {
        "optimizer_failed"
      } else {
        "truncated"
      }
      return(list(
        status = status, points = points, endpoint = NA_real_,
        bracket = c(NA_real_, NA_real_), refinement_iterations = 0L
      ))
    }

    iterations <- 0L
    while (abs(bracket$outside$row$target - bracket$inside$row$target) >
           bracket_tolerance && iterations < as.integer(refinement_steps)) {
      iterations <- iterations + 1L
      target <- mean(c(
        bracket$inside$row$target[[1L]], bracket$outside$row$target[[1L]]
      ))
      point <- evaluate_point(
        target, bracket$inside$nuisance,
        if (direction < 0) "lower" else "upper", "refinement"
      )
      points[[length(points) + 1L]] <- point
      if (!successful(point)) {
        return(list(
          status = "refinement_failed", points = points, endpoint = NA_real_,
          bracket = c(
            bracket$inside$row$target[[1L]], bracket$outside$row$target[[1L]]
          ), refinement_iterations = iterations
        ))
      }
      if (point$row$objective_delta[[1L]] >= threshold) {
        bracket$outside <- point
      } else {
        bracket$inside <- point
      }
    }

    width <- abs(bracket$outside$row$target - bracket$inside$row$target)
    if (width > bracket_tolerance) {
      return(list(
        status = "refinement_truncated", points = points, endpoint = NA_real_,
        bracket = c(
          bracket$inside$row$target[[1L]], bracket$outside$row$target[[1L]]
        ), refinement_iterations = iterations
      ))
    }
    endpoint <- mean(c(
      bracket$inside$row$target[[1L]], bracket$outside$row$target[[1L]]
    ))
    list(
      status = "crossed", points = points, endpoint = endpoint,
      bracket = c(
        bracket$inside$row$target[[1L]], bracket$outside$row$target[[1L]]
      ), refinement_iterations = iterations
    )
  }

  lower <- walk_side(-1)
  upper <- walk_side(1)
  trace <- rbind(
    do.call(rbind, lapply(lower$points, `[[`, "row")),
    centre,
    do.call(rbind, lapply(upper$points, `[[`, "row"))
  )

  list(
    trace = trace,
    target_index = as.integer(which),
    target_name = names(fit$opt$par)[which],
    mle = mle_par[which],
    mle_objective = mle_objective,
    threshold = threshold,
    centre_status = centre_status,
    lower_status = lower$status,
    upper_status = upper$status,
    lower_endpoint = lower$endpoint,
    upper_endpoint = upper$endpoint,
    lower_bracket = lower$bracket,
    upper_bracket = upper$bracket,
    lower_refinement_iterations = lower$refinement_iterations,
    upper_refinement_iterations = upper$refinement_iterations,
    bracket_tolerance = bracket_tolerance,
    finite_stable = identical(centre_status, "matched") &&
      identical(lower$status, "crossed") &&
      identical(upper$status, "crossed"),
    objective_source = "fit$tmb_obj (penalised LA-MSPL)"
  )
}

## Internal constrained-state instrument for a future bootstrap-test inversion
## study. The target is held exactly while every remaining active outer
## parameter is reoptimised against the penalised LA-MSPL objective. The
## returned fit clone is suitable only for unconditional parametric simulation;
## it deliberately does not expose a confidence interval or public method.
.gllvmTMB_mspl_constrained_simulation_state <- function(
  fit,
  which = 1L,
  target,
  control = list(eval.max = 100L, iter.max = 100L)
) {
  if (!.gllvmTMB_is_mspl(fit)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL constrained-state instrument requires an {.code estimator = \"mspl\"} fit.",
      class = "gllvmTMB_mspl_constrained_state_input"
    )
  }
  if (
    !is.numeric(which) || length(which) != 1L || which %% 1 != 0 ||
      which < 1L || which > length(fit$opt$par) ||
      names(fit$opt$par)[which] != "b_fix"
  ) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL constrained-state instrument requires one resolved {.field b_fix} coordinate.",
      class = "gllvmTMB_mspl_constrained_state_target"
    )
  }
  if (!is.numeric(target) || length(target) != 1L || !is.finite(target)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL constrained-state instrument requires one finite target value.",
      class = "gllvmTMB_mspl_constrained_state_target"
    )
  }

  obj <- fit$tmb_obj
  penalty_off <- fit$mspl$unpenalized_tmb_obj
  if (
    is.null(obj) || identical(obj, penalty_off) ||
      !identical(as.integer(obj$env$data$estimator_id), 1L)
  ) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL constrained-state instrument could not verify the active penalised TMB objective.",
      class = "gllvmTMB_mspl_constrained_state_objective"
    )
  }
  checkpoint <- .gllvmTMB_profile_tmb_checkpoint(obj)
  on.exit(.gllvmTMB_restore_profile_tmb_checkpoint(obj, checkpoint), add = TRUE)

  mle_par <- as.numeric(fit$opt$par)
  nuisance_index <- setdiff(seq_along(mle_par), as.integer(which))
  objective <- function(nuisance) {
    par <- mle_par
    par[nuisance_index] <- nuisance
    par[which] <- target
    obj$fn(par)
  }
  gradient <- function(nuisance) {
    par <- mle_par
    par[nuisance_index] <- nuisance
    par[which] <- target
    obj$gr(par)[nuisance_index]
  }
  ans <- tryCatch(
    nlminb(mle_par[nuisance_index], objective = objective, gradient = gradient,
      control = control),
    error = identity
  )
  if (inherits(ans, "error")) {
    return(list(
      status = "optimizer_failed", message = conditionMessage(ans),
      target_index = as.integer(which), target_name = names(fit$opt$par)[which],
      target = target, objective_source = "fit$tmb_obj (penalised LA-MSPL)",
      estimator_id = 1L
    ))
  }
  if (!identical(as.integer(ans$convergence), 0L) || !is.finite(ans$objective)) {
    return(list(
      status = if (is.finite(ans$objective)) "optimizer_failed" else "nonfinite",
      message = ans$message %||% "", target_index = as.integer(which),
      target_name = names(fit$opt$par)[which], target = target,
      objective_source = "fit$tmb_obj (penalised LA-MSPL)", estimator_id = 1L
    ))
  }

  par <- mle_par
  par[nuisance_index] <- as.numeric(ans$par)
  par[which] <- target
  objective_value <- obj$fn(par)
  full_par <- obj$env$last.par
  report <- tryCatch(obj$report(full_par), error = identity)
  if (!is.finite(objective_value) || inherits(report, "error") ||
      is.null(report$eta) || any(!is.finite(report$eta))) {
    return(list(
      status = "state_construction_failed",
      message = if (inherits(report, "error")) conditionMessage(report) else "",
      target_index = as.integer(which), target_name = names(fit$opt$par)[which],
      target = target, objective_source = "fit$tmb_obj (penalised LA-MSPL)",
      estimator_id = 1L
    ))
  }

  simulation_fit <- fit
  simulation_fit$opt <- fit$opt
  simulation_fit$opt$par <- par
  simulation_fit$opt$objective <- as.numeric(objective_value)
  simulation_fit$report <- report
  list(
    status = "ok", message = ans$message %||% "",
    target_index = as.integer(which), target_name = names(fit$opt$par)[which],
    target = target, objective = as.numeric(objective_value),
    nuisance_reoptimized = TRUE,
    objective_source = "fit$tmb_obj (penalised LA-MSPL)", estimator_id = 1L,
    simulation_fit = simulation_fit
  )
}

## Private paper-style curvature diagnostic. The penalty-off approximate
## Laplace likelihood is evaluated only at the penalised MSPL estimate; it is
## never optimised here and does not turn that estimate into an ML estimate.
.gllvmTMB_mspl_likelihood_hessian_diagnostic <- function(
  fit,
  which = 1L,
  level = 0.95,
  ndeps = c(1e-4, 5e-4),
  relative_tolerance = 0.1
) {
  if (!.gllvmTMB_is_mspl(fit)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL likelihood-curvature diagnostic requires an {.code estimator = \"mspl\"} fit.",
      class = "gllvmTMB_mspl_likelihood_hessian_input"
    )
  }
  if (!is.numeric(which) || length(which) != 1L || which %% 1 != 0 ||
      which < 1L || which > length(fit$opt$par) ||
      names(fit$opt$par)[which] != "b_fix") {
    .gllvmTMB_mspl_abort(
      "The internal MSPL likelihood-curvature diagnostic requires one resolved {.field b_fix} coordinate.",
      class = "gllvmTMB_mspl_likelihood_hessian_target"
    )
  }
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level) ||
      level <= 0 || level >= 1 || !is.numeric(ndeps) || length(ndeps) != 2L ||
      any(!is.finite(ndeps)) || any(ndeps <= 0) ||
      !is.numeric(relative_tolerance) || length(relative_tolerance) != 1L ||
      !is.finite(relative_tolerance) || relative_tolerance < 0) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL likelihood-curvature diagnostic received invalid numerical controls.",
      class = "gllvmTMB_mspl_likelihood_hessian_control"
    )
  }

  obj <- fit$mspl$unpenalized_tmb_obj
  if (is.null(obj) || identical(obj, fit$tmb_obj) ||
      !identical(as.integer(obj$env$data$estimator_id), 2L)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL likelihood-curvature diagnostic could not verify the penalty-off likelihood tape.",
      class = "gllvmTMB_mspl_likelihood_hessian_objective"
    )
  }
  checkpoint <- .gllvmTMB_profile_tmb_checkpoint(obj)
  on.exit(.gllvmTMB_restore_profile_tmb_checkpoint(obj, checkpoint), add = TRUE)

  par <- as.numeric(fit$opt$par)
  base <- list(
    target_index = as.integer(which), target_name = names(fit$opt$par)[which],
    estimate = par[which], level = level,
    objective_source = paste0(
      "fit$mspl$unpenalized_tmb_obj ",
      "(penalty-off approximate Laplace NLL)"
    ),
    objective_role = "curvature_only_at_penalised_mspl_estimate",
    estimator_id = 2L, status = "likelihood_hessian_error",
    hessian_method = "stats::optimHess(penalty-off tape at MSPL estimate)",
    se = NA_real_, diagnostic_lower = NA_real_, diagnostic_upper = NA_real_,
    hessian_rank = NA_integer_, minimum_eigenvalue = NA_real_,
    observed_gradient_max = NA_real_, hessian_relative_difference = NA_real_,
    message = NA_character_
  )
  value <- tryCatch(obj$fn(par), error = identity)
  gradient <- tryCatch(obj$gr(par), error = identity)
  if (inherits(value, "error") || inherits(gradient, "error") ||
      length(value) != 1L || !is.finite(value) ||
      length(gradient) != length(par) || any(!is.finite(gradient))) {
    base$status <- "likelihood_hessian_nonfinite"
    base$message <- if (inherits(value, "error")) conditionMessage(value) else if (
      inherits(gradient, "error")
    ) conditionMessage(gradient) else "Non-finite objective or gradient at the MSPL estimate."
    return(base)
  }
  base$objective_at_estimate <- as.numeric(value)
  base$observed_gradient_max <- max(abs(gradient))

  assess <- function(step) {
    hessian <- tryCatch(
      stats::optimHess(
        par, obj$fn, obj$gr, control = list(ndeps = rep(step, length(par)))
      ),
      error = identity
    )
    if (inherits(hessian, "error")) {
      return(list(status = "likelihood_hessian_error", message = conditionMessage(hessian)))
    }
    hessian <- as.matrix(hessian)
    if (!identical(dim(hessian), rep.int(length(par), 2L)) ||
        any(!is.finite(hessian))) {
      return(list(status = "likelihood_hessian_nonfinite", message = NA_character_))
    }
    hessian <- (hessian + t(hessian)) / 2
    eig <- tryCatch(
      eigen(hessian, symmetric = TRUE, only.values = TRUE)$values,
      error = identity
    )
    if (inherits(eig, "error") || any(!is.finite(eig))) {
      return(list(status = "likelihood_hessian_eigen_error", message = NA_character_))
    }
    tolerance <- sqrt(.Machine$double.eps) * max(1, max(abs(eig)))
    rank <- as.integer(sum(eig > tolerance))
    minimum <- min(eig)
    if (rank != length(par) || minimum <= 0) {
      return(list(
        status = "likelihood_hessian_non_pd", rank = rank,
        minimum = minimum, message = NA_character_
      ))
    }
    chol_hessian <- tryCatch(chol(hessian), error = identity)
    if (inherits(chol_hessian, "error")) {
      return(list(
        status = "likelihood_hessian_solve_error", rank = rank,
        minimum = minimum, message = conditionMessage(chol_hessian)
      ))
    }
    covariance <- chol2inv(chol_hessian)
    variance <- covariance[which, which]
    if (!is.finite(variance) || variance <= 0) {
      return(list(
        status = "likelihood_hessian_variance_invalid", rank = rank,
        minimum = minimum, message = NA_character_
      ))
    }
    list(
      status = "ok", rank = rank, minimum = minimum,
      se = sqrt(variance), hessian = hessian, message = NA_character_
    )
  }

  primary <- assess(ndeps[[1L]])
  base$hessian_rank <- primary$rank %||% NA_integer_
  base$minimum_eigenvalue <- primary$minimum %||% NA_real_
  base$message <- primary$message %||% NA_character_
  if (!identical(primary$status, "ok")) {
    base$status <- primary$status
    return(base)
  }
  sensitivity <- assess(ndeps[[2L]])
  if (!identical(sensitivity$status, "ok")) {
    base$status <- "likelihood_hessian_step_sensitive"
    base$message <- paste("Secondary Hessian check:", sensitivity$status)
    return(base)
  }
  base$hessian_relative_difference <- abs(primary$se - sensitivity$se) /
    max(primary$se, sensitivity$se)
  if (base$hessian_relative_difference > relative_tolerance) {
    base$status <- "likelihood_hessian_step_sensitive"
    return(base)
  }
  base$se <- primary$se
  z_value <- stats::qnorm((1 + level) / 2)
  base$diagnostic_lower <- base$estimate - z_value * base$se
  base$diagnostic_upper <- base$estimate + z_value * base$se
  base$status <- "ok"
  base
}

## Private uncertainty candidate only.  This is a numerical outer Hessian of
## the active penalised LA-MSPL objective. TMB's analytic Hessian is not
## available for these models with random effects. This is not an sdreport(),
## sandwich covariance, or a calibrated standard error.
.gllvmTMB_mspl_penalized_hessian_diagnostic <- function(
  fit,
  which = 1L,
  level = 0.95
) {
  if (!.gllvmTMB_is_mspl(fit)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL Hessian diagnostic requires an {.code estimator = \"mspl\"} fit.",
      class = "gllvmTMB_mspl_hessian_input"
    )
  }
  if (
    !is.numeric(which) || length(which) != 1L || which %% 1 != 0 ||
      which < 1L || which > length(fit$opt$par) ||
      names(fit$opt$par)[which] != "b_fix"
  ) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL Hessian diagnostic requires one resolved {.field b_fix} coordinate.",
      class = "gllvmTMB_mspl_hessian_target"
    )
  }
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level) ||
      level <= 0 || level >= 1) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL Hessian diagnostic requires {.arg level} in (0, 1).",
      class = "gllvmTMB_mspl_hessian_level"
    )
  }

  obj <- fit$tmb_obj
  penalty_off <- fit$mspl$unpenalized_tmb_obj
  if (is.null(obj) || identical(obj, penalty_off) ||
      !identical(as.integer(obj$env$data$estimator_id), 1L)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL Hessian diagnostic could not verify the active penalised TMB objective.",
      class = "gllvmTMB_mspl_hessian_objective"
    )
  }
  checkpoint <- .gllvmTMB_profile_tmb_checkpoint(obj)
  on.exit(.gllvmTMB_restore_profile_tmb_checkpoint(obj, checkpoint), add = TRUE)

  par <- as.numeric(fit$opt$par)
  hessian <- tryCatch(stats::optimHess(par, obj$fn, obj$gr), error = identity)
  base <- list(
    target_index = as.integer(which),
    target_name = names(fit$opt$par)[which],
    estimate = par[which],
    level = level,
    objective_source = "fit$tmb_obj (penalised LA-MSPL)",
    status = "hessian_error",
    hessian_method = "stats::optimHess(fit$tmb_obj)",
    se = NA_real_,
    diagnostic_lower = NA_real_,
    diagnostic_upper = NA_real_,
    hessian_rank = NA_integer_,
    minimum_eigenvalue = NA_real_
  )
  if (inherits(hessian, "error")) {
    base$message <- conditionMessage(hessian)
    return(base)
  }
  hessian <- as.matrix(hessian)
  if (length(dim(hessian)) != 2L ||
      !all(dim(hessian) == rep.int(length(par), 2L)) ||
      any(!is.finite(hessian))) {
    base$status <- "hessian_nonfinite"
    return(base)
  }
  hessian <- (hessian + t(hessian)) / 2
  eig <- tryCatch(eigen(hessian, symmetric = TRUE, only.values = TRUE)$values,
                  error = identity)
  if (inherits(eig, "error") || any(!is.finite(eig))) {
    base$status <- "hessian_eigen_error"
    return(base)
  }
  eigen_tolerance <- sqrt(.Machine$double.eps) * max(1, max(abs(eig)))
  base$hessian_rank <- as.integer(sum(eig > eigen_tolerance))
  base$minimum_eigenvalue <- min(eig)
  if (base$hessian_rank != length(par) || base$minimum_eigenvalue <= 0) {
    base$status <- "hessian_non_pd"
    return(base)
  }
  chol_hessian <- tryCatch(chol(hessian), error = identity)
  if (inherits(chol_hessian, "error")) {
    base$status <- "hessian_solve_error"
    base$message <- conditionMessage(chol_hessian)
    return(base)
  }
  covariance <- chol2inv(chol_hessian)
  variance <- covariance[which, which]
  if (!is.finite(variance) || variance <= 0) {
    base$status <- "hessian_variance_invalid"
    return(base)
  }
  base$se <- sqrt(variance)
  z_value <- stats::qnorm((1 + level) / 2)
  base$diagnostic_lower <- base$estimate - z_value * base$se
  base$diagnostic_upper <- base$estimate + z_value * base$se
  base$status <- "ok"
  base
}

## Private profile candidate only. The feasibility helper supplies endpoints
## from a bounded bisection of a finite, converged penalised-objective bracket.
## These are not confidence-interval endpoints.
.gllvmTMB_mspl_profile_threshold_diagnostic <- function(probe) {
  if (!is.list(probe) || !identical(
    probe$objective_source, "fit$tmb_obj (penalised LA-MSPL)"
  )) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile-threshold diagnostic requires a penalised profile probe.",
      class = "gllvmTMB_mspl_profile_threshold_input"
    )
  }
  required <- c(
    "trace", "mle", "threshold", "centre_status", "lower_status",
    "upper_status", "lower_endpoint", "upper_endpoint", "lower_bracket",
    "upper_bracket"
  )
  if (!all(required %in% names(probe)) || !is.data.frame(probe$trace)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile-threshold diagnostic received an incomplete probe.",
      class = "gllvmTMB_mspl_profile_threshold_input"
    )
  }

  list(
    target_index = probe$target_index,
    target_name = probe$target_name,
    estimate = probe$mle,
    threshold = probe$threshold,
    centre_status = probe$centre_status,
    lower_status = probe$lower_status,
    upper_status = probe$upper_status,
    diagnostic_lower = probe$lower_endpoint,
    diagnostic_upper = probe$upper_endpoint,
    lower_bracket = probe$lower_bracket,
    upper_bracket = probe$upper_bracket,
    objective_source = "fit$tmb_obj (penalised LA-MSPL)"
  )
}

## Resolve b_fix = b_fixed + K gamma and return X_* = X_fix K.  TMB maps use
## factor levels to represent shared free parameters and NA to represent pinned
## coordinates.  The present public Xcoef_fixed surface only pins zeros, but
## handling ties here makes the derivative-design construction agree with TMB's
## general map semantics rather than relying on that temporary API restriction.
.gllvmTMB_mspl_fixed_design <- function(X_fix, b_map = NULL) {
  X_fix <- as.matrix(X_fix)
  if (!is.numeric(X_fix) || any(!is.finite(X_fix))) {
    .gllvmTMB_mspl_abort(
      "LA-MSPL requires a finite numeric fixed-effect design matrix.",
      "x" = "The resolved {.field X_fix} contains a non-finite value."
    )
  }

  n_beta <- ncol(X_fix)
  if (is.null(b_map)) {
    K <- diag(n_beta)
    if (n_beta == 0L) K <- matrix(numeric(0), 0L, 0L)
  } else {
    map_code <- as.integer(b_map)
    if (length(map_code) != n_beta) {
      .gllvmTMB_mspl_abort(
        "Internal LA-MSPL map mismatch.",
        "x" = "The {.field b_fix} map has {length(map_code)} entries for {n_beta} design columns.",
        class = "gllvmTMB_mspl_internal_map"
      )
    }
    n_free <- if (all(is.na(map_code))) 0L else max(map_code, na.rm = TRUE)
    K <- matrix(0, nrow = n_beta, ncol = n_free)
    keep <- which(!is.na(map_code))
    if (length(keep)) K[cbind(keep, map_code[keep])] <- 1
  }

  X_mspl <- unname(X_fix %*% K)
  p_beta <- ncol(X_mspl)
  if (p_beta < 1L) {
    .gllvmTMB_mspl_abort(
      "LA-MSPL requires at least one free fixed-effect coefficient.",
      "i" = "An interceptless or fully pinned fixed-effect model is outside the current LA-MSPL contract."
    )
  }

  singular_values <- svd(X_mspl, nu = 0L, nv = 0L)$d
  rank_tol <- max(dim(X_mspl)) * max(singular_values) * .Machine$double.eps
  rank_x <- sum(singular_values > rank_tol)
  if (rank_x != p_beta) {
    .gllvmTMB_mspl_abort(c(
      "The resolved LA-MSPL fixed-effect design is rank deficient.",
      "x" = "Numerical rank is {rank_x}; {p_beta} free coefficient{?s} remain after maps and ties.",
      ">" = "Remove aliased fixed effects or pin a redundant coefficient with {.arg Xcoef_fixed} before fitting."
    ), class = "gllvmTMB_mspl_rank_deficient")
  }

  list(
    X = X_mspl,
    K = K,
    p_beta = as.integer(p_beta),
    rank = as.integer(rank_x),
    rank_tolerance = rank_tol
  )
}

.gllvmTMB_mspl_tau_representatives <- function(log_tau, tau_map = NULL) {
  n_tau <- length(log_tau)
  if (n_tau < 1L) {
    .gllvmTMB_mspl_abort(
      "Spatial-independent LA-MSPL requires at least one free spatial scale.",
      class = "gllvmTMB_mspl_internal_surface"
    )
  }
  if (is.null(tau_map)) return(as.integer(seq_len(n_tau) - 1L))

  map_code <- as.integer(tau_map)
  if (length(map_code) != n_tau) {
    .gllvmTMB_mspl_abort(
      "Internal LA-MSPL spatial-scale map mismatch.",
      class = "gllvmTMB_mspl_internal_map"
    )
  }
  free_levels <- sort(unique(map_code[!is.na(map_code)]))
  if (!length(free_levels)) {
    .gllvmTMB_mspl_abort(
      "Spatial-independent LA-MSPL requires a free spatial scale.",
      class = "gllvmTMB_mspl_internal_surface"
    )
  }
  as.integer(vapply(
    free_levels,
    function(level) which(map_code == level)[1L] - 1L,
    integer(1L)
  ))
}

.gllvmTMB_mspl_spde_r0 <- function(mesh) {
  if (is.null(mesh) || is.null(mesh$loc_xy)) {
    .gllvmTMB_mspl_abort(
      "Spatial LA-MSPL requires a resolved {.fn make_mesh} object.",
      class = "gllvmTMB_mspl_internal_surface"
    )
  }
  locations <- unique(as.matrix(mesh$loc_xy))
  if (!is.numeric(locations) || ncol(locations) != 2L ||
      nrow(locations) < 2L || any(!is.finite(locations))) {
    .gllvmTMB_mspl_abort(
      "Spatial LA-MSPL requires at least two distinct finite observed locations."
    )
  }
  centred <- sweep(locations, 2L, colMeans(locations), FUN = "-")
  r0 <- sqrt(mean(rowSums(centred^2)))
  if (length(r0) != 1L || !is.finite(r0) || r0 <= 0) {
    .gllvmTMB_mspl_abort(
      "The spatial LA-MSPL reference distance is not positive and finite."
    )
  }
  unname(r0)
}

## Preflight the deliberately narrow point-estimator surface.  This runs
## after maps and the random-effect vector have been resolved, so admission is
## based on the model TMB will actually see rather than formula spelling.
.gllvmTMB_mspl_prepare <- function(
  X_fix, b_map, y, n_trials, is_y_observed, family_id_vec, link_id_vec,
  offset_vec, random, use_rr_B, use_lv_B, use_rr_B_slope, use_diag_B,
  diag_B_all_skipped, d_B, theta_rr_B, lambda_constraint,
  use_spde, is_spatial_indep, is_spatial_scalar, is_spatial_latent,
  is_spatial_dep, use_spde_latent_diag, use_spde_slope,
  use_spde_latent_slope, d_spde_lv, theta_rr_spde_lv, log_tau_spde,
  log_tau_spde_map, mesh, use_mi_predictor, integration, engine, REML,
  ridge_explicit
) {
  if (isTRUE(REML)) {
    .gllvmTMB_mspl_abort("{.code estimator = \"mspl\"} cannot be combined with {.code REML = TRUE}.")
  }
  if (!identical(engine, "tmb") || !identical(integration, "laplace")) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL currently requires the native TMB Laplace route.",
      "x" = "Received engine {.val {engine}} and integration {.val {integration}}."
    ))
  }
  if (isTRUE(ridge_explicit)) {
    .gllvmTMB_mspl_abort(c(
      "Do not combine {.code estimator = \"mspl\"} with an explicit loading ridge.",
      "i" = "MSPL and {.arg loading_ridge} (or its compatibility spelling {.arg aghq_ridge}) are different penalties; combining them would define an unvalidated hybrid estimator."
    ))
  }
  if (length(unique(family_id_vec)) != 1L || !all(family_id_vec == 1L)) {
    .gllvmTMB_mspl_abort("LA-MSPL supports a single binomial response family only.")
  }
  if (length(unique(link_id_vec)) != 1L || !all(link_id_vec %in% 0:2)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires one common supported binary link.",
      "i" = "Use {.code binomial(link = \"logit\")}, {.code \"probit\"}, or {.code \"cloglog\"}."
    ))
  }
  if (!all(is_y_observed == 1L)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires complete responses.",
      "i" = "FIML-MSPL and retained response masks are deferred."
    ))
  }
  if (!all(n_trials == 1) || !all(y %in% c(0, 1))) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires single-trial Bernoulli observations.",
      "i" = "Grouped and weighted binomial MSPL is deferred."
    ))
  }
  if (any(!is.finite(offset_vec))) {
    .gllvmTMB_mspl_abort("LA-MSPL requires finite known offsets.")
  }
  if (any(offset_vec != 0)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires an all-zero offset vector.",
      "i" = "Nonzero binary offsets are mathematically plausible but remain outside the frozen validation campaign."
    ))
  }
  ordinary <- isTRUE(use_rr_B) && !isTRUE(use_spde)
  spatial_indep <- !isTRUE(use_rr_B) && isTRUE(use_spde) &&
    isTRUE(is_spatial_indep) && !isTRUE(is_spatial_scalar) &&
    !isTRUE(is_spatial_latent) && !isTRUE(is_spatial_dep)
  spatial_latent <- !isTRUE(use_rr_B) && isTRUE(use_spde) &&
    isTRUE(is_spatial_latent) && !isTRUE(is_spatial_dep)
  if (sum(c(ordinary, spatial_indep, spatial_latent)) != 1L) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires exactly one admitted covariance structure.",
      "i" = "Use ordinary {.fn latent}, standalone {.fn spatial_indep}, or standalone {.fn spatial_latent} with rank 1 or 2."
    ))
  }

  if (ordinary && (!d_B %in% c(1L, 2L) || isTRUE(use_lv_B) ||
                   isTRUE(use_rr_B_slope))) {
    .gllvmTMB_mspl_abort(c(
      "Ordinary LA-MSPL supports one intercept-only {.fn latent} block with {.arg d} equal to 1 or 2.",
      "i" = "Predictor-informed latent means, latent slopes, and q > 2 are deferred."
    ))
  }
  if (spatial_latent && (!d_spde_lv %in% c(1L, 2L) ||
                         isTRUE(use_spde_latent_diag))) {
    .gllvmTMB_mspl_abort(c(
      "Spatial-latent LA-MSPL supports {.fn spatial_latent} with {.arg d} equal to 1 or 2 and no unique companion.",
      "i" = "Free spatial Psi coordinates and q > 2 are deferred."
    ))
  }
  if (!ordinary && (isTRUE(use_diag_B) || isTRUE(use_rr_B_slope))) {
    .gllvmTMB_mspl_abort(
      "Spatial LA-MSPL cannot be combined with an ordinary latent or Psi block."
    )
  }
  if (isTRUE(use_spde_slope) || isTRUE(use_spde_latent_slope)) {
    .gllvmTMB_mspl_abort(
      "Spatial random slopes are outside the current LA-MSPL contract."
    )
  }
  if (ordinary && isTRUE(use_diag_B) && !isTRUE(diag_B_all_skipped)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL does not estimate a Bernoulli Psi companion.",
      "i" = "The automatic Bernoulli Psi may remain in the parsed formula only when every coordinate is mapped off."
    ))
  }
  expected_random <- if (ordinary) {
    "z_B"
  } else if (spatial_indep) {
    "omega_spde"
  } else {
    "omega_spde_lv"
  }
  if (!identical(random, expected_random)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL admits exactly one structure-specific Laplace-random block.",
      "x" = "Expected {.val {expected_random}}; resolved {.val {random}}.",
      "i" = "Additional random effects and structured covariance tiers are deferred."
    ))
  }
  if (isTRUE(use_mi_predictor)) {
    .gllvmTMB_mspl_abort("Modelled missing predictors are outside the current LA-MSPL contract.")
  }
  if (!is.null(lambda_constraint) && length(Filter(Negate(is.null), lambda_constraint))) {
    .gllvmTMB_mspl_abort(c(
      "Confirmatory loading constraints are outside the current LA-MSPL contract.",
      "i" = "Fit the exploratory lower-triangular ordinary latent model without {.arg lambda_constraint}."
    ))
  }

  fixed <- .gllvmTMB_mspl_fixed_design(X_fix, b_map)
  structure <- if (ordinary) "ordinary" else if (spatial_indep) {
    "spatial_indep"
  } else {
    "spatial_latent"
  }
  tau_representative <- as.integer(-1L)
  spde_r0 <- 1
  if (ordinary) {
    p_loading <- length(theta_rr_B)
    p_covariance <- 0L
    expected_outer <- c("b_fix", "theta_rr_B")
  } else if (spatial_indep) {
    tau_representative <- .gllvmTMB_mspl_tau_representatives(
      log_tau_spde, log_tau_spde_map
    )
    p_loading <- 0L
    p_covariance <- length(tau_representative) + 1L
    expected_outer <- c("b_fix", "log_tau_spde", "log_kappa_spde")
    spde_r0 <- .gllvmTMB_mspl_spde_r0(mesh)
  } else {
    p_loading <- length(theta_rr_spde_lv)
    p_covariance <- 1L
    expected_outer <- c("b_fix", "theta_rr_spde_lv", "log_kappa_spde")
    spde_r0 <- .gllvmTMB_mspl_spde_r0(mesh)
  }
  p_free <- fixed$p_beta + p_loading + p_covariance
  N_eff <- sum(n_trials)
  if (!is.finite(N_eff) || N_eff <= 0) {
    .gllvmTMB_mspl_abort("LA-MSPL requires a positive effective Bernoulli sample size.")
  }

  link_name <- .gllvmTMB_mspl_link_name(unique(link_id_vec))
  q_cell <- if (identical(structure, "ordinary")) {
    as.integer(d_B)
  } else if (identical(structure, "spatial_latent")) {
    as.integer(d_spde_lv)
  } else {
    NA_integer_
  }
  registry_row <- .gllvmTMB_mspl_registry_lookup(
    family = "binomial",
    link = link_name,
    structure = structure,
    q = q_cell
  )
  if (is.null(registry_row) || !identical(registry_row$status, "admitted")) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL resolved a surface that is not an admitted registry cell.",
      "x" = "family binomial, link {.val {link_name}}, structure {.val {structure}}, q {.val {q_cell}}."
    ), class = "gllvmTMB_mspl_registry_miss")
  }

  list(
    estimator_id = 1L,
    X_mspl = fixed$X,
    N_eff = as.numeric(N_eff),
    p_beta = fixed$p_beta,
    p_loading = as.integer(p_loading),
    p_covariance = as.integer(p_covariance),
    p_free = as.integer(p_free),
    rate = 2 * sqrt(p_free / N_eff),
    fixed_design = fixed,
    structure = structure,
    expected_outer = expected_outer,
    expected_random = expected_random,
    spde_r0 = spde_r0,
    tau_representative = tau_representative,
    registry_cell = registry_row$cell_id,
    registry_status = registry_row$status,
    registry_evidence = registry_row$evidence,
    scope = paste0(
      "complete Bernoulli; ", structure,
      if (structure == "spatial_latent") paste0("(q=", d_spde_lv, ")") else
        if (structure == "ordinary") paste0("(q=", d_B, ")") else "",
      "; Laplace; one common logit/probit/cloglog link"
    )
  )
}
