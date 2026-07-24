d99_eval_chart <- function(
  theta,
  counts,
  chart,
  cap,
  gh,
  need_score = TRUE,
  all_patterns = TRUE
) {
  x <- d99_chart_unpack(theta, chart, cap)
  ev <- d99_aghq_eval(
    counts,
    x$beta,
    x$Lambda,
    gh,
    need_score = need_score,
    all_patterns = all_patterns
  )
  c(ev, list(chart_value = x))
}

d99_error_or <- function(error, fallback) {
  if (is.null(error)) fallback else error
}

d99_mean_negloglik <- function(theta, counts, chart, cap, gh) {
  -d99_eval_chart(
    theta,
    counts,
    chart,
    cap,
    gh,
    need_score = FALSE
  )$loglik /
    sum(counts)
}

d99_mean_negloglik_xi <- function(xi, counts, chart, cap, gh) {
  theta <- d99_chart_from_xi(xi, chart, cap)
  d99_mean_negloglik(theta, counts, chart, cap, gh)
}

d99_richardson_gradient <- function(fun, coordinate) {
  numDeriv::grad(
    fun,
    coordinate,
    method = "Richardson",
    method.args = list(
      eps = 1e-5,
      d = 1e-4,
      zero.tol = sqrt(.Machine$double.eps),
      r = 4,
      v = 2
    )
  )
}

d99_finite_rule_gradient <- function(theta, counts, chart, cap, gh) {
  d99_richardson_gradient(
    function(z) d99_mean_negloglik(z, counts, chart, cap, gh),
    theta
  )
}

d99_finite_rule_gradient_xi <- function(xi, counts, chart, cap, gh) {
  d99_richardson_gradient(
    function(z) d99_mean_negloglik_xi(z, counts, chart, cap, gh),
    xi
  )
}

d99_fisher_chart_score <- function(theta, counts, chart, cap, gh) {
  ev <- d99_eval_chart(theta, counts, chart, cap, gh, need_score = TRUE)
  drop(crossprod(d99_chart_jacobian(theta, chart, cap), ev$score)) /
    sum(counts)
}

d99_fisher_xi_score <- function(xi, counts, chart, cap, gh) {
  theta <- d99_chart_from_xi(xi, chart, cap)
  ev <- d99_eval_chart(theta, counts, chart, cap, gh, need_score = TRUE)
  drop(crossprod(d99_xi_jacobian(xi, chart, cap), ev$score)) /
    sum(counts)
}

d99_symmetric_jacobian <- function(fun, theta, step = 1e-5) {
  theta <- as.numeric(theta)
  p <- length(theta)
  value <- as.numeric(fun(theta))
  out <- matrix(NA_real_, length(value), p)
  for (j in seq_len(p)) {
    h <- step * max(1, abs(theta[j]))
    plus <- theta
    minus <- theta
    plus[j] <- plus[j] + h
    minus[j] <- minus[j] - h
    out[, j] <- (fun(plus) - fun(minus)) / (2 * h)
  }
  out
}

d99_symmetric_gradient <- function(fun, theta, step = 1e-5) {
  drop(d99_symmetric_jacobian(
    function(z) as.numeric(fun(z)),
    theta,
    step = step
  ))
}

d99_richardson_jacobian <- function(fun, coordinate) {
  numDeriv::jacobian(
    fun,
    coordinate,
    method = "Richardson",
    method.args = list(
      eps = 1e-5,
      d = 1e-4,
      zero.tol = sqrt(.Machine$double.eps),
      r = 4,
      v = 2
    )
  )
}

d99_observed_information <- function(theta, counts, chart, cap, gh) {
  xi <- d99_chart_to_xi(theta, chart, cap)
  H <- d99_symmetric_jacobian(
    function(z) d99_finite_rule_gradient_xi(z, counts, chart, cap, gh),
    xi
  )
  H <- (H + t(H)) / 2
  scale <- pmax(1, abs(xi))
  scaled <- H * tcrossprod(scale)
  eigenvalues <- eigen(scaled, symmetric = TRUE, only.values = TRUE)$values
  singular_values <- svd(scaled, nu = 0L, nv = 0L)$d
  condition <- if (
    !length(singular_values) ||
      min(singular_values) == 0
  ) {
    Inf
  } else {
    max(singular_values) / min(singular_values)
  }
  list(
    matrix = H,
    scaled_matrix = scaled,
    eigenvalues = eigenvalues,
    singular_values = singular_values,
    condition = condition,
    scale = scale
  )
}

d99_derivative_check <- function(theta, counts, chart, cap, gh) {
  finite <- d99_finite_rule_gradient(theta, counts, chart, cap, gh)
  symmetric <- d99_symmetric_gradient(
    function(z) d99_mean_negloglik(z, counts, chart, cap, gh),
    theta
  )
  fisher <- d99_fisher_chart_score(theta, counts, chart, cap, gh)
  relative <- function(a, b) {
    max(abs(a - b) / pmax(1, abs(a), abs(b)))
  }
  list(
    finite_rule = finite,
    symmetric = symmetric,
    fisher = fisher,
    finite_symmetric_relative_error = relative(finite, symmetric),
    finite_fisher_relative_error = relative(finite, -fisher)
  )
}

d99_pattern_probability_jacobian <- function(
  theta,
  chart,
  cap,
  gh,
  counts = NULL,
  step = 1e-5
) {
  xi <- d99_chart_to_xi(theta, chart, cap)
  probs <- function(z) {
    th <- d99_chart_from_xi(z, chart, cap)
    d99_eval_chart(
      th,
      rep.int(0L, 64L),
      chart,
      cap,
      gh,
      need_score = FALSE,
      all_patterns = TRUE
    )$prob
  }
  symmetric <- d99_symmetric_jacobian(probs, xi, step)
  richardson <- d99_richardson_jacobian(probs, xi)
  relative_error <- max(
    abs(symmetric - richardson) /
      pmax(1e-10, abs(symmetric), abs(richardson))
  )
  probability <- probs(xi)
  scale <- pmax(1, abs(xi))
  identified <- symmetric[-64L, , drop = FALSE]
  scaled <- sweep(identified, 2L, scale, "*")
  decomposition <- svd(scaled)
  weakest <- decomposition$v[, ncol(decomposition$v)]
  displacements <- c(0, -.25, .25, -.5, .5, -1, 1, -2, 2)
  baseline <- if (is.null(counts)) {
    NA_real_
  } else {
    d99_mean_negloglik_xi(xi, counts, chart, cap, gh)
  }
  profile <- lapply(displacements, function(displacement) {
    coordinate <- xi + displacement * scale * weakest
    tryCatch(
      {
        value <- list(
          displacement = displacement,
          xi = coordinate,
          probability = probs(coordinate),
          valid = TRUE
        )
        if (!is.null(counts)) {
          value$mean_negloglik <- d99_mean_negloglik_xi(
            coordinate,
            counts,
            chart,
            cap,
            gh
          )
          value$delta_per_unit <- value$mean_negloglik - baseline
        }
        value
      },
      error = function(error) {
        list(
          displacement = displacement,
          xi = coordinate,
          valid = FALSE,
          error = conditionMessage(error)
        )
      }
    )
  })
  information <- if (is.null(counts)) {
    NULL
  } else {
    d99_observed_information(theta, counts, chart, cap, gh)
  }
  result <- list(
    probability = probability,
    jacobian = identified,
    full_jacobian = symmetric,
    richardson_jacobian = richardson,
    richardson_relative_error = relative_error,
    scaled_jacobian = scaled,
    singular_values = decomposition$d,
    rank = setNames(
      vapply(
        c(1e-6, 1e-8, 1e-10),
        function(cutoff) {
          sum(decomposition$d > max(decomposition$d) * cutoff)
        },
        integer(1)
      ),
      c("1e-06", "1e-08", "1e-10")
    ),
    largest_singular_value = max(decomposition$d),
    smallest_singular_value = min(decomposition$d),
    reciprocal_condition = min(decomposition$d) / max(decomposition$d),
    weakest_direction = weakest,
    profile = profile,
    observed_information = information
  )
  result$verdict <- d99_identification_verdict(
    result,
    counts_supplied = !is.null(counts)
  )
  result
}

d99_identification_verdict <- function(diagnostics, counts_supplied = TRUE) {
  rank_at <- function(name) {
    if (
      is.null(names(diagnostics$rank)) || !name %in% names(diagnostics$rank)
    ) {
      return(NA_integer_)
    }
    value <- diagnostics$rank[[name]]
    if (is.null(value)) NA_integer_ else as.integer(value)
  }
  profile <- diagnostics$profile
  profile_valid <- length(profile) == 9L &&
    all(vapply(profile, function(value) isTRUE(value$valid), logical(1)))
  profile_delta <- if (profile_valid && counts_supplied) {
    vapply(profile, `[[`, numeric(1), "delta_per_unit")
  } else {
    rep(NA_real_, length(profile))
  }
  displacement <- if (profile_valid) {
    vapply(profile, `[[`, numeric(1), "displacement")
  } else {
    rep(NA_real_, length(profile))
  }
  nonzero <- which(displacement != 0)
  center <- which(displacement == 0)
  profile_finite <- profile_valid &&
    counts_supplied &&
    length(nonzero) == 8L &&
    length(center) == 1L &&
    all(is.finite(profile_delta))
  profile_min_rise <- if (profile_finite) {
    min(profile_delta[nonzero])
  } else {
    -Inf
  }
  center_error <- if (profile_finite) {
    abs(profile_delta[center])
  } else {
    Inf
  }
  information <- diagnostics$observed_information
  checks <- c(
    counts_supplied = isTRUE(counts_supplied),
    richardson = is.finite(diagnostics$richardson_relative_error) &&
      diagnostics$richardson_relative_error < 1e-6,
    rank_1e8 = !is.na(rank_at("1e-08")) && rank_at("1e-08") == 17L,
    reciprocal_condition = is.finite(diagnostics$reciprocal_condition) &&
      diagnostics$reciprocal_condition > 1e-8,
    information_finite = !is.null(information) &&
      all(is.finite(information$scaled_matrix)),
    information_condition = !is.null(information) &&
      is.finite(information$condition) &&
      information$condition < 1e8,
    profile_valid = profile_finite,
    profile_center = center_error <= 1e-12,
    profile_rise = profile_min_rise > 1e-8
  )
  terminal <- if (!isTRUE(checks[["richardson"]])) {
    "MECHANICAL_STOP"
  } else if (all(checks)) {
    "PASS"
  } else {
    "WEAK_OR_NONIDENTIFIED_REFERENCE"
  }
  list(
    healthy = all(checks),
    terminal = terminal,
    checks = checks,
    failed_checks = names(checks)[!checks],
    profile_min_rise = profile_min_rise,
    profile_center_error = center_error,
    rank_1e8 = rank_at("1e-08"),
    reciprocal_condition = diagnostics$reciprocal_condition,
    information_condition = if (is.null(information)) {
      Inf
    } else {
      information$condition
    }
  )
}

d99_mode_health <- function(modes) {
  if (length(modes) != 64L || any(vapply(modes, is.null, logical(1)))) {
    return(list(ok = FALSE, reason = "all 64 conditional modes are required"))
  }
  gradient <- vapply(modes, `[[`, numeric(1), "gradient_inf")
  decrement <- vapply(modes, `[[`, numeric(1), "decrement")
  minimum <- vapply(modes, `[[`, numeric(1), "min_eigenvalue")
  finite <- all(vapply(
    modes,
    function(mode) {
      all(is.finite(c(
        mode$u,
        mode$Q,
        mode$gradient_inf,
        mode$decrement,
        mode$min_eigenvalue,
        mode$steps
      )))
    },
    logical(1)
  ))
  list(
    ok = finite &&
      max(gradient) < 1e-10 &&
      max(decrement) < 1e-12 &&
      min(minimum) >= 1 - 1e-10,
    finite = finite,
    max_gradient = max(gradient),
    max_decrement = max(decrement),
    min_eigenvalue = min(minimum)
  )
}

d99_improving_step <- function(xi, gradient, information, objective) {
  decomposition <- svd(information$scaled_matrix)
  keep <- decomposition$d > max(decomposition$d) * 1e-10
  if (!any(keep) || any(!is.finite(decomposition$d))) {
    return(list(
      improvement = Inf,
      accepted_alpha = NA_real_,
      reason = "no finite retained information system"
    ))
  }
  scaled_gradient <- information$scale * gradient
  step_scaled <- -decomposition$v[, keep, drop = FALSE] %*%
    ((t(decomposition$u[, keep, drop = FALSE]) %*% scaled_gradient) /
      decomposition$d[keep])
  step <- drop(step_scaled) * information$scale
  size <- max(abs(step) / information$scale)
  if (size > 1) {
    step <- step / size
  }
  baseline <- objective(xi)
  best <- baseline
  accepted_alpha <- NA_real_
  for (halving in 0:30) {
    alpha <- 2^-halving
    candidate <- tryCatch(
      objective(xi + alpha * step),
      error = function(error) Inf
    )
    if (is.finite(candidate) && candidate < best) {
      best <- candidate
      accepted_alpha <- alpha
    }
  }
  list(
    improvement = baseline - best,
    accepted_alpha = accepted_alpha,
    raw_step = step,
    scaled_step_size = max(abs(step) / information$scale)
  )
}

d99_certify_endpoint <- function(theta, counts, chart, cap, gh21, gh31) {
  n <- sum(counts)
  if (!is.finite(n) || n <= 0) {
    stop("Certification requires positive total pattern count.", call. = FALSE)
  }
  xi <- d99_chart_to_xi(theta, chart, cap)
  scale <- pmax(1, abs(xi))
  eval21 <- d99_eval_chart(theta, counts, chart, cap, gh21, TRUE, TRUE)
  eval31 <- d99_eval_chart(theta, counts, chart, cap, gh31, TRUE, TRUE)
  finite21 <- d99_finite_rule_gradient_xi(
    xi,
    counts,
    chart,
    cap,
    gh21
  )
  finite31 <- d99_finite_rule_gradient_xi(
    xi,
    counts,
    chart,
    cap,
    gh31
  )
  fisher21 <- d99_fisher_xi_score(xi, counts, chart, cap, gh21)
  fisher31 <- d99_fisher_xi_score(xi, counts, chart, cap, gh31)
  observed <- which(counts > 0)
  Jxi <- d99_xi_jacobian(xi, chart, cap)
  posterior21 <- eval21$score_by_pattern[observed, , drop = FALSE] %*% Jxi
  posterior31 <- eval31$score_by_pattern[observed, , drop = FALSE] %*% Jxi
  information <- d99_observed_information(
    theta,
    counts,
    chart,
    cap,
    gh31
  )
  improving <- d99_improving_step(
    xi,
    finite31,
    information,
    function(z) d99_mean_negloglik_xi(z, counts, chart, cap, gh31)
  )
  interior <- d99_chart_interior(theta, chart, cap)
  population21 <- d99_population_probability(
    eval31$chart_value$beta,
    eval31$chart_value$Lambda,
    gh21
  )
  population31 <- d99_population_probability(
    eval31$chart_value$beta,
    eval31$chart_value$Lambda,
    gh31
  )
  metrics <- list(
    loglik_per_unit = abs(eval31$loglik - eval21$loglik) / n,
    finite_score_h21_h31 = max(scale * abs(finite31 - finite21)),
    fisher_score_h21_h31 = max(scale * abs(fisher31 - fisher21)),
    pattern_log_probability = max(
      abs(eval31$log_prob[observed] - eval21$log_prob[observed])
    ),
    posterior_score = max(abs(posterior31 - posterior21)),
    finite_stationarity = max(scale * abs(finite31)),
    fisher_stationarity = max(scale * abs(fisher31)),
    score_discrepancy = max(scale * abs(finite31 + fisher31)),
    population_probability = max(abs(population31 - population21)),
    improving_step = improving$improvement
  )
  checks <- c(
    loglik = metrics$loglik_per_unit < 1e-8,
    finite_score_convergence = metrics$finite_score_h21_h31 < 1e-6,
    fisher_score_convergence = metrics$fisher_score_h21_h31 < 1e-6,
    pattern_log_probability = metrics$pattern_log_probability < 1e-7,
    posterior_score = metrics$posterior_score < 5e-6,
    finite_stationarity = metrics$finite_stationarity < 1e-7,
    fisher_stationarity = metrics$fisher_stationarity < 1e-7,
    score_discrepancy = metrics$score_discrepancy < 1e-6,
    population_probability = metrics$population_probability < 1e-7,
    interiority = isTRUE(interior$ok),
    hessian_finite = all(is.finite(information$scaled_matrix)),
    hessian_curvature = min(information$eigenvalues) >= -1e-8,
    hessian_condition = information$condition < 1e8,
    no_improving_step = is.finite(metrics$improving_step) &&
      metrics$improving_step <= 1e-9,
    modes_h21 = isTRUE(d99_mode_health(eval21$modes)$ok),
    modes_h31 = isTRUE(d99_mode_health(eval31$modes)$ok)
  )
  invariant <- d99_invariants(
    eval31$chart_value$beta,
    eval31$chart_value$Lambda,
    gh31
  )
  list(
    healthy = all(checks),
    checks = checks,
    metrics = metrics,
    theta = theta,
    xi = xi,
    scale = scale,
    chart = chart,
    cap = cap,
    objective = -eval31$loglik / n,
    loglik = eval31$loglik,
    invariant = invariant,
    population_h21 = population21,
    population_h31 = population31,
    interior = interior,
    information = information,
    improving_step = improving,
    finite_rule = list(H21 = finite21, H31 = finite31),
    fisher = list(H21 = fisher21, H31 = fisher31),
    evaluations = list(H21 = eval21, H31 = eval31),
    failed_checks = names(checks)[!checks]
  )
}

d99_endpoint_telemetry <- function(theta, counts, chart, cap, gh) {
  xi <- d99_chart_to_xi(theta, chart, cap)
  evaluation <- d99_eval_chart(theta, counts, chart, cap, gh, TRUE, TRUE)
  finite_rule <- d99_finite_rule_gradient(
    theta,
    counts,
    chart,
    cap,
    gh
  )
  fisher <- d99_fisher_chart_score(theta, counts, chart, cap, gh)
  mode_health <- d99_mode_health(evaluation$modes)
  invariant <- d99_invariants(
    evaluation$chart_value$beta,
    evaluation$chart_value$Lambda
  )
  healthy <- is.finite(evaluation$loglik) &&
    all(is.finite(c(finite_rule, fisher, invariant$beta, invariant$Sigma))) &&
    isTRUE(mode_health$ok)
  list(
    healthy = healthy,
    theta = theta,
    xi = xi,
    chart = chart,
    cap = cap,
    objective = -evaluation$loglik / sum(counts),
    finite_rule = finite_rule,
    fisher = fisher,
    invariant = invariant,
    interior = d99_chart_interior(theta, chart, cap),
    mode_health = mode_health,
    modes = evaluation$modes,
    quadrature = evaluation$quadrature
  )
}

d99_safe_endpoint_telemetry <- function(theta, counts, chart, cap, gh) {
  tryCatch(
    d99_endpoint_telemetry(theta, counts, chart, cap, gh),
    error = function(error) {
      list(healthy = FALSE, error = conditionMessage(error), theta = theta)
    }
  )
}

d99_agreement_metrics <- function(endpoints) {
  objectives <- vapply(
    endpoints,
    function(endpoint) {
      endpoint$certification$objective
    },
    numeric(1)
  )
  invariants <- lapply(endpoints, function(endpoint) {
    endpoint$certification$invariant
  })
  pairwise <- d99_pairwise_invariant_metrics(invariants)
  list(
    objective = max(objectives) - min(objectives),
    beta = unname(pairwise[["beta_max"]]),
    Sigma = unname(pairwise[["Sigma_max"]]),
    population_probability = unname(pairwise[["population_probability_max"]])
  )
}

d99_agreement_checks <- function(metrics) {
  c(
    objective = is.finite(metrics$objective) && metrics$objective < 1e-9,
    beta = is.finite(metrics$beta) && metrics$beta < 1e-3,
    Sigma = is.finite(metrics$Sigma) && metrics$Sigma < 5e-3,
    population_probability = is.finite(metrics$population_probability) &&
      metrics$population_probability < 1e-4
  )
}

d99_select_cell_endpoint <- function(endpoints) {
  if (length(endpoints) != 6L) {
    return(list(
      healthy = FALSE,
      error = "a cell requires exactly six endpoints"
    ))
  }
  starts <- vapply(endpoints, `[[`, character(1), "start")
  guards <- vapply(endpoints, `[[`, character(1), "guard")
  expected <- as.vector(outer(
    c("fixed", "spectral", "truth"),
    c("cap4", "cap8"),
    paste,
    sep = ":"
  ))
  observed <- paste(starts, guards, sep = ":")
  if (!setequal(expected, observed) || anyDuplicated(observed)) {
    return(list(
      healthy = FALSE,
      error = "cell endpoints do not form the frozen start-by-guard grid"
    ))
  }
  endpoint_health <- vapply(
    endpoints,
    function(endpoint) {
      isTRUE(endpoint$healthy) &&
        isTRUE(endpoint$certification$healthy)
    },
    logical(1)
  )
  metrics <- d99_agreement_metrics(endpoints)
  checks <- d99_agreement_checks(metrics)
  if (!all(endpoint_health) || !all(checks)) {
    return(list(
      healthy = FALSE,
      endpoint_health = endpoint_health,
      metrics = metrics,
      checks = checks
    ))
  }
  loglik <- vapply(
    endpoints,
    function(endpoint) {
      endpoint$certification$loglik
    },
    numeric(1)
  )
  ordering <- order(
    -loglik,
    match(guards, c("cap4", "cap8")),
    match(starts, c("fixed", "spectral", "truth"))
  )
  list(
    healthy = TRUE,
    selected = endpoints[[ordering[1L]]],
    selected_index = ordering[1L],
    metrics = metrics,
    checks = checks,
    ordering = ordering
  )
}

d99_compare_representatives <- function(endpoints) {
  if (length(endpoints) < 2L) {
    return(list(
      healthy = FALSE,
      error = "at least two representatives are required"
    ))
  }
  endpoint_health <- vapply(
    endpoints,
    function(endpoint) {
      isTRUE(endpoint$healthy) &&
        isTRUE(endpoint$certification$healthy)
    },
    logical(1)
  )
  metrics <- d99_agreement_metrics(endpoints)
  checks <- d99_agreement_checks(metrics)
  list(
    healthy = all(endpoint_health) && all(checks),
    endpoint_health = endpoint_health,
    metrics = metrics,
    checks = checks
  )
}

d99_route_a <- function(counts, theta0, chart, cap, gh9, gh15, gh21, gh31) {
  started <- proc.time()[["elapsed"]]
  warnings <- list(H9 = character(), H15 = character(), H31 = character())
  telemetry <- list()
  h9 <- tryCatch(
    withCallingHandlers(
      nloptr::nloptr(
        x0 = theta0,
        eval_f = function(z) d99_mean_negloglik(z, counts, chart, cap, gh9),
        lb = rep(-12, 17L),
        ub = rep(12, 17L),
        opts = list(
          algorithm = "NLOPT_LN_BOBYQA",
          xtol_rel = 1e-8,
          ftol_abs = 1e-10,
          maxeval = 2000L,
          print_level = 0L
        )
      ),
      warning = function(warning) {
        warnings$H9 <<- c(warnings$H9, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(error) error
  )
  if (inherits(h9, "error")) {
    return(list(
      healthy = FALSE,
      route = "A",
      error = conditionMessage(h9),
      warnings = warnings,
      phases = list(H9 = h9),
      wall_time = proc.time()[["elapsed"]] - started
    ))
  }
  telemetry$H9 <- d99_safe_endpoint_telemetry(
    h9$solution,
    counts,
    chart,
    cap,
    gh9
  )
  if (!isTRUE(telemetry$H9$healthy)) {
    return(list(
      healthy = FALSE,
      route = "A",
      error = d99_error_or(telemetry$H9$error, "unhealthy H9 endpoint"),
      warnings = warnings,
      phases = list(H9 = h9),
      optimizer = list(
        H9 = list(code = h9$status, message = h9$message)
      ),
      telemetry = telemetry,
      wall_time = proc.time()[["elapsed"]] - started
    ))
  }
  h15 <- tryCatch(
    withCallingHandlers(
      stats::optim(
        h9$solution,
        fn = function(z) d99_mean_negloglik(z, counts, chart, cap, gh15),
        gr = function(z) d99_finite_rule_gradient(z, counts, chart, cap, gh15),
        method = "BFGS",
        control = list(maxit = 500L, reltol = 1e-10)
      ),
      warning = function(warning) {
        warnings$H15 <<- c(warnings$H15, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(error) error
  )
  if (inherits(h15, "error")) {
    return(list(
      healthy = FALSE,
      route = "A",
      error = conditionMessage(h15),
      warnings = warnings,
      phases = list(H9 = h9, H15 = h15),
      telemetry = telemetry,
      wall_time = proc.time()[["elapsed"]] - started
    ))
  }
  telemetry$H15 <- d99_safe_endpoint_telemetry(
    h15$par,
    counts,
    chart,
    cap,
    gh15
  )
  if (!isTRUE(telemetry$H15$healthy)) {
    return(list(
      healthy = FALSE,
      route = "A",
      error = d99_error_or(telemetry$H15$error, "unhealthy H15 endpoint"),
      warnings = warnings,
      phases = list(H9 = h9, H15 = h15),
      optimizer = list(
        H9 = list(code = h9$status, message = h9$message),
        H15 = list(code = h15$convergence, message = h15$message)
      ),
      telemetry = telemetry,
      wall_time = proc.time()[["elapsed"]] - started
    ))
  }
  h31 <- tryCatch(
    withCallingHandlers(
      stats::optim(
        h15$par,
        fn = function(z) d99_mean_negloglik(z, counts, chart, cap, gh31),
        gr = function(z) d99_finite_rule_gradient(z, counts, chart, cap, gh31),
        method = "BFGS",
        control = list(maxit = 200L, reltol = 1e-12)
      ),
      warning = function(warning) {
        warnings$H31 <<- c(warnings$H31, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(error) error
  )
  if (inherits(h31, "error")) {
    return(list(
      healthy = FALSE,
      route = "A",
      error = conditionMessage(h31),
      warnings = warnings,
      phases = list(H9 = h9, H15 = h15, H31 = h31),
      telemetry = telemetry,
      wall_time = proc.time()[["elapsed"]] - started
    ))
  }
  telemetry$H31 <- d99_safe_endpoint_telemetry(
    h31$par,
    counts,
    chart,
    cap,
    gh31
  )
  if (!isTRUE(telemetry$H31$healthy)) {
    return(list(
      healthy = FALSE,
      route = "A",
      error = d99_error_or(telemetry$H31$error, "unhealthy H31 endpoint"),
      warnings = warnings,
      phases = list(H9 = h9, H15 = h15, H31 = h31),
      optimizer = list(
        H9 = list(code = h9$status, message = h9$message),
        H15 = list(code = h15$convergence, message = h15$message),
        H31 = list(code = h31$convergence, message = h31$message)
      ),
      telemetry = telemetry,
      wall_time = proc.time()[["elapsed"]] - started
    ))
  }
  certification <- d99_certify_endpoint(
    h31$par,
    counts,
    chart,
    cap,
    gh21,
    gh31
  )
  list(
    healthy = isTRUE(certification$healthy),
    route = "A",
    warnings = warnings,
    phases = list(H9 = h9, H15 = h15, H31 = h31),
    optimizer = list(
      H9 = list(code = h9$status, message = h9$message),
      H15 = list(code = h15$convergence, message = h15$message),
      H31 = list(code = h31$convergence, message = h31$message)
    ),
    theta = h31$par,
    telemetry = telemetry,
    certification = certification,
    wall_time = proc.time()[["elapsed"]] - started
  )
}

d99_damped_newton_score <- function(theta0, counts, chart, cap, gh, maxit) {
  theta <- as.numeric(theta0)
  trace <- vector("list", maxit)
  score_fun <- function(z) {
    d99_fisher_chart_score(z, counts, chart, cap, gh)
  }
  for (iteration in seq_len(maxit)) {
    score <- score_fun(theta)
    scale <- pmax(1, abs(theta))
    scaled_norm <- max(scale * abs(score))
    if (!all(is.finite(score))) {
      return(list(
        healthy = FALSE,
        error = "non-finite Fisher score",
        theta = theta,
        trace = trace[seq_len(iteration - 1L)]
      ))
    }
    if (scaled_norm < 1e-7) {
      return(list(
        healthy = TRUE,
        converged = TRUE,
        theta = theta,
        trace = trace[seq_len(iteration - 1L)],
        iterations = iteration - 1L,
        scaled_norm = scaled_norm
      ))
    }
    J <- d99_symmetric_jacobian(score_fun, theta)
    decomposition <- svd(J)
    keep <- decomposition$d > max(decomposition$d) * 1e-10
    condition <- max(decomposition$d) / min(decomposition$d[keep])
    if (
      sum(keep) < length(theta) || !is.finite(condition) || condition > 1e12
    ) {
      return(list(
        healthy = FALSE,
        error = "singular or ill-conditioned score Jacobian",
        theta = theta,
        condition = condition,
        trace = trace[seq_len(iteration - 1L)]
      ))
    }
    delta <- -decomposition$v %*%
      ((t(decomposition$u) %*% score) / decomposition$d)
    delta <- drop(delta)
    maximum <- max(abs(delta) / scale)
    if (maximum > 1) {
      delta <- delta / maximum
    }
    accepted <- FALSE
    for (halving in 0:30) {
      alpha <- 2^-halving
      candidate <- theta + alpha * delta
      next_score <- score_fun(candidate)
      if (
        all(is.finite(next_score)) &&
          max(abs(next_score)) <= (1 - 1e-4 * alpha) * max(abs(score))
      ) {
        trace[[iteration]] <- list(
          score = score,
          score_jacobian = J,
          condition = condition,
          singular_values = decomposition$d,
          delta = delta,
          alpha = alpha,
          halvings = halving
        )
        theta <- candidate
        accepted <- TRUE
        break
      }
    }
    if (!accepted) {
      return(list(
        healthy = FALSE,
        error = "no Armijo score-norm decrease within 30 halvings",
        theta = theta,
        trace = trace[seq_len(iteration - 1L)]
      ))
    }
  }
  list(
    healthy = FALSE,
    error = "maximum Newton iterations reached",
    theta = theta,
    trace = trace,
    iterations = maxit,
    scaled_norm = max(
      pmax(1, abs(theta)) * abs(score_fun(theta))
    )
  )
}

d99_route_b <- function(counts, theta0, chart, cap, gh15, gh21, gh31) {
  started <- proc.time()[["elapsed"]]
  telemetry <- list()
  h15 <- d99_damped_newton_score(
    theta0,
    counts,
    chart,
    cap,
    gh15,
    maxit = 100L
  )
  if (!isTRUE(h15$healthy)) {
    return(list(
      healthy = FALSE,
      route = "B",
      phases = list(H15 = h15),
      error = h15$error,
      warnings = list(H15 = character()),
      wall_time = proc.time()[["elapsed"]] - started
    ))
  }
  telemetry$H15 <- d99_safe_endpoint_telemetry(
    h15$theta,
    counts,
    chart,
    cap,
    gh15
  )
  if (!isTRUE(telemetry$H15$healthy)) {
    return(list(
      healthy = FALSE,
      route = "B",
      phases = list(H15 = h15),
      error = d99_error_or(telemetry$H15$error, "unhealthy H15 endpoint"),
      warnings = list(H15 = character()),
      telemetry = telemetry,
      wall_time = proc.time()[["elapsed"]] - started
    ))
  }
  h31 <- d99_damped_newton_score(
    h15$theta,
    counts,
    chart,
    cap,
    gh31,
    maxit = 50L
  )
  if (!isTRUE(h31$healthy)) {
    return(list(
      healthy = FALSE,
      route = "B",
      phases = list(H15 = h15, H31 = h31),
      error = h31$error,
      warnings = list(H15 = character(), H31 = character()),
      telemetry = telemetry,
      wall_time = proc.time()[["elapsed"]] - started
    ))
  }
  telemetry$H31 <- d99_safe_endpoint_telemetry(
    h31$theta,
    counts,
    chart,
    cap,
    gh31
  )
  if (!isTRUE(telemetry$H31$healthy)) {
    return(list(
      healthy = FALSE,
      route = "B",
      phases = list(H15 = h15, H31 = h31),
      error = d99_error_or(telemetry$H31$error, "unhealthy H31 endpoint"),
      warnings = list(H15 = character(), H31 = character()),
      telemetry = telemetry,
      wall_time = proc.time()[["elapsed"]] - started
    ))
  }
  certification <- d99_certify_endpoint(
    h31$theta,
    counts,
    chart,
    cap,
    gh21,
    gh31
  )
  list(
    healthy = isTRUE(certification$healthy),
    route = "B",
    phases = list(H15 = h15, H31 = h31),
    optimizer = list(
      H15 = list(code = 0L, message = "score root converged"),
      H31 = list(code = 0L, message = "score root converged")
    ),
    warnings = list(H15 = character(), H31 = character()),
    theta = h31$theta,
    telemetry = telemetry,
    certification = certification,
    wall_time = proc.time()[["elapsed"]] - started
  )
}
