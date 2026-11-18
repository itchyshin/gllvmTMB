# Prepare response replacement in MODEL-row order (the order simulate() uses).
# Keep a two-column response as a matrix column rather than trying to invert
# arbitrary expressions such as cbind(s, n - s), or changing their RHS inputs.
.bootstrap_response_setup <- function(
  fit,
  formula = .reconstruct_multi_formula(fit)
) {
  data <- fit$data
  lhs <- fit$formula[[2L]]
  raw <- eval(lhs, data, environment(fit$formula))
  paired <- is.matrix(raw) && ncol(raw) == 2L
  name <- if (is.symbol(lhs) && !paired) {
    as.character(lhs)
  } else {
    utils::tail(make.unique(c(names(data), ".bootstrap_response")), 1L)
  }
  formula[[2L]] <- as.name(name)
  td <- fit$tmb_data
  binomial <- td$family_id_vec %in% c(1L, 8L, 19L)
  # family_id_vec is the engine's per-row vector, never trait-level family.
  if (!length(binomial)) {
    binomial <- rep(FALSE, nrow(data))
  }
  observed <- td$is_y_observed
  if (is.null(observed)) {
    observed <- rep(1L, nrow(data))
  }
  weights <- NULL
  trial_weights <- td$family_id_vec %in% c(1L, 8L)
  if (!paired && any(trial_weights)) {
    weights <- td$weights_i %||% rep(1, nrow(data))
    weights[trial_weights] <- td$n_trials[trial_weights]
  } else if (isTRUE(fit$likelihood_weights$active)) {
    weights <- td$weights_i
  }
  # Unit weights carry no trial-count or likelihood information. Omit them
  # rather than changing an unweighted call's contract (isdm_sources() refuses
  # every explicit weights argument, including an all-unit vector).
  if (!is.null(weights) && all(weights == 1)) {
    weights <- NULL
  }
  list(
    data = data,
    formula = formula,
    name = name,
    paired = paired,
    second = if (paired) raw[, 2L] else NULL,
    binomial = binomial,
    trials = td$n_trials,
    observed = observed,
    weights = weights,
    missing = if (any(observed == 0L)) {
      miss_control(response = "include")
    } else {
      NULL
    }
  )
}

.bootstrap_response_data <- function(response, y) {
  data <- response$data
  if (length(y) != nrow(data)) {
    cli::cli_abort(
      "Simulated response length differs from the fitted model row count."
    )
  }
  y <- as.numeric(y)
  y[response$observed == 0L] <- NA_real_
  if (response$paired) {
    second <- response$second
    b <- response$binomial
    second[b] <- response$trials[b] - y[b]
    second[response$observed == 0L] <- NA_real_
    data[[response$name]] <- cbind(y, second)
  } else {
    data[[response$name]] <- y
  }
  data
}
