d99_oracle_validate_inputs <- function(y, beta, Lambda, chart_jacobian) {
  y <- as.numeric(y)
  if (length(y) != 6L || any(!is.finite(y)) || any(y != 0 & y != 1)) {
    stop("`y` must be a finite binary vector of length six.", call. = FALSE)
  }
  parameters <- d99_validate_parameters(beta, Lambda)
  chart_jacobian <- as.matrix(chart_jacobian)
  storage.mode(chart_jacobian) <- "double"
  if (
    nrow(chart_jacobian) != 18L ||
      ncol(chart_jacobian) < 1L ||
      any(!is.finite(chart_jacobian))
  ) {
    stop("`chart_jacobian` must be a finite 18 by p matrix.", call. = FALSE)
  }
  list(
    y = y,
    beta = parameters$beta,
    Lambda = parameters$Lambda,
    chart_jacobian = chart_jacobian
  )
}

d99_oracle_tail_bounds <- function() {
  B0 <- 4 * pnorm(-10, lower.tail = TRUE)
  B1 <- 2 * dnorm(10) + sqrt(2 / pi) * 2 * pnorm(-10, lower.tail = TRUE)
  list(B0 = B0, B1 = B1, invariant = c(rep(B0, 6L), rep(B1, 12L)))
}

d99_oracle_roundoff_bound <- function(estimate) {
  64 * .Machine$double.eps * pmax(1, abs(estimate))
}

d99_oracle_quotient_intervals <- function(
  denominator,
  denominator_error,
  denominator_tail,
  numerator,
  numerator_error,
  numerator_tail,
  chart_jacobian,
  chart_tail_limit = 5e-7
) {
  if (
    length(denominator) != 1L ||
      length(denominator_error) != 1L ||
      length(denominator_tail) != 1L ||
      any(
        !is.finite(c(
          denominator,
          denominator_error,
          denominator_tail
        ))
      ) ||
      denominator_error < 0 ||
      denominator_tail < 0
  ) {
    stop(
      "Probability estimate and error bounds must be finite non-negative scalars.",
      call. = FALSE
    )
  }
  numerator <- as.numeric(numerator)
  numerator_error <- as.numeric(numerator_error)
  numerator_tail <- as.numeric(numerator_tail)
  if (
    length(numerator) != 18L ||
      length(numerator_error) != 18L ||
      length(numerator_tail) != 18L ||
      any(
        !is.finite(c(
          numerator,
          numerator_error,
          numerator_tail
        ))
      ) ||
      any(numerator_error < 0) ||
      any(numerator_tail < 0)
  ) {
    stop(
      "Invariant numerator estimates and bounds must be finite vectors of length 18.",
      call. = FALSE
    )
  }
  chart_jacobian <- as.matrix(chart_jacobian)
  if (
    nrow(chart_jacobian) != 18L ||
      ncol(chart_jacobian) < 1L ||
      any(!is.finite(chart_jacobian))
  ) {
    stop("`chart_jacobian` must be a finite 18 by p matrix.", call. = FALSE)
  }
  denominator_lower <- denominator - denominator_error - denominator_tail
  denominator_upper <- denominator + denominator_error + denominator_tail
  if (
    !is.finite(denominator_lower) ||
      denominator_lower <= 0 ||
      !is.finite(denominator_upper)
  ) {
    stop(
      "Certified posterior-score denominator is not strictly positive.",
      call. = FALSE
    )
  }
  absolute_jacobian <- abs(chart_jacobian)
  chart_numerator <- as.numeric(crossprod(chart_jacobian, numerator))
  chart_numerical_error <- as.numeric(crossprod(
    absolute_jacobian,
    numerator_error
  ))
  chart_tail <- as.numeric(crossprod(absolute_jacobian, numerator_tail))
  if (any(!is.finite(chart_tail)) || any(chart_tail >= chart_tail_limit)) {
    stop(
      "Transformed chart-score tail bound must be below 5e-7 in every component.",
      call. = FALSE
    )
  }
  numerator_lower <- chart_numerator - chart_numerical_error - chart_tail
  numerator_upper <- chart_numerator + chart_numerical_error + chart_tail
  quotient_bounds <- vapply(
    seq_along(chart_numerator),
    function(index) {
      candidates <- c(
        numerator_lower[index] / denominator_lower,
        numerator_lower[index] / denominator_upper,
        numerator_upper[index] / denominator_lower,
        numerator_upper[index] / denominator_upper
      )
      c(lower = min(candidates), upper = max(candidates))
    },
    numeric(2L)
  )
  list(
    score = chart_numerator / denominator,
    lower = quotient_bounds["lower", ],
    upper = quotient_bounds["upper", ],
    chart_numerator = chart_numerator,
    chart_numerical_error = chart_numerical_error,
    chart_tail = chart_tail,
    denominator = c(
      estimate = denominator,
      lower = denominator_lower,
      upper = denominator_upper,
      numerical_error = denominator_error,
      tail = denominator_tail
    )
  )
}

d99_oracle_cubature_integrand <- function(u, y, beta, Lambda) {
  eta <- as.numeric(beta + Lambda %*% u)
  density <- exp(
    sum(y * eta - d99_softplus(eta)) -
      0.5 * sum(u^2) -
      log(2 * pi)
  )
  residual <- y - plogis(eta)
  c(density, density * c(residual, as.vector(t(residual %o% u))))
}

d99_oracle_nested_integrand <- function(
  first,
  second,
  y,
  beta,
  Lambda,
  component
) {
  eta <- beta + Lambda[, 1L] * first + Lambda[, 2L] * second
  joint <- exp(
    sum(y * eta - d99_softplus(eta)) -
      (first^2 + second^2) / 2 -
      log(2 * pi)
  )
  if (component == 1L) {
    return(joint)
  }
  residual <- y - plogis(eta)
  complete_score <- c(
    residual,
    as.vector(t(cbind(
      residual * first,
      residual * second
    )))
  )
  joint * complete_score[component - 1L]
}

d99_oracle_run_cubature <- function(...) {
  cubature::hcubature(...)
}

d99_oracle_run_integrate <- function(...) {
  stats::integrate(...)
}

d99_oracle_assert_cubature_success <- function(output) {
  if (
    !is.list(output) ||
      length(output$returnCode) != 1L ||
      !is.finite(output$returnCode) ||
      output$returnCode != 0
  ) {
    code <- if (is.list(output) && length(output$returnCode) == 1L) {
      as.character(output$returnCode)
    } else {
      "missing"
    }
    stop(
      paste0(
        "Cubature backend failure: returnCode must be 0; received ",
        code,
        "."
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

d99_oracle_assert_integrate_success <- function(output, context) {
  if (
    !is.list(output) ||
      !identical(output$message, "OK") ||
      length(output$value) != 1L ||
      length(output$abs.error) != 1L ||
      !is.finite(output$value) ||
      !is.finite(output$abs.error) ||
      output$abs.error < 0
  ) {
    message <- if (is.list(output) && length(output$message) == 1L) {
      as.character(output$message)
    } else {
      "missing"
    }
    stop(
      paste0(
        "Nested integrate backend failure in ",
        context,
        ": message must be exactly 'OK' and value/absolute error finite; received '",
        message,
        "'."
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

d99_oracle_cubature_pattern <- function(
  y,
  beta,
  Lambda,
  chart_jacobian = diag(18L)
) {
  if (!requireNamespace("cubature", quietly = TRUE)) {
    stop(
      "Package `cubature` is required for the bounded-domain oracle.",
      call. = FALSE
    )
  }
  inputs <- d99_oracle_validate_inputs(y, beta, Lambda, chart_jacobian)
  output <- d99_oracle_run_cubature(
    f = function(u) {
      d99_oracle_cubature_integrand(
        u,
        inputs$y,
        inputs$beta,
        inputs$Lambda
      )
    },
    lowerLimit = c(-10, -10),
    upperLimit = c(10, 10),
    tol = 1e-11,
    absError = 1e-13,
    maxEval = 5e6,
    fDim = 19L
  )
  d99_oracle_assert_cubature_success(output)
  estimate <- as.numeric(output$integral)
  numerical_error <- pmax(
    as.numeric(output$error),
    d99_oracle_roundoff_bound(estimate)
  )
  if (
    length(estimate) != 19L ||
      length(numerical_error) != 19L ||
      any(!is.finite(c(estimate, numerical_error))) ||
      any(numerical_error < 0)
  ) {
    stop(
      "Cubature returned malformed integral estimates or errors.",
      call. = FALSE
    )
  }
  tail <- d99_oracle_tail_bounds()
  intervals <- d99_oracle_quotient_intervals(
    denominator = estimate[1L],
    denominator_error = numerical_error[1L],
    denominator_tail = tail$B0,
    numerator = estimate[-1L],
    numerator_error = numerical_error[-1L],
    numerator_tail = tail$invariant,
    chart_jacobian = inputs$chart_jacobian
  )
  if (tail$B0 / intervals$denominator["lower"] >= 1e-8) {
    stop("Cubature probability tail bound failed.", call. = FALSE)
  }
  list(
    prob = estimate[1L],
    log_prob = log(estimate[1L]),
    numerator = estimate[-1L],
    score = estimate[-1L] / estimate[1L],
    integral_error = numerical_error,
    lower_bound = intervals$denominator["lower"],
    tail = tail,
    chart_score = intervals$score,
    chart_score_lower = intervals$lower,
    chart_score_upper = intervals$upper,
    chart_numerical_error = intervals$chart_numerical_error,
    chart_tail_bounds = intervals$chart_tail,
    denominator_interval = intervals$denominator,
    return_code = output$returnCode,
    success = TRUE,
    error = NULL,
    backend_status = list(
      success = TRUE,
      return_code = output$returnCode,
      error = NULL
    )
  )
}

d99_oracle_nested_pattern <- function(
  y,
  beta,
  Lambda,
  chart_jacobian = diag(18L)
) {
  inputs <- d99_oracle_validate_inputs(y, beta, Lambda, chart_jacobian)
  integrate_checks <- 0L
  component_integral <- function(component) {
    outer <- d99_oracle_run_integrate(
      f = function(first) {
        vapply(
          first,
          function(first_value) {
            inner <- d99_oracle_run_integrate(
              f = function(second) {
                vapply(
                  second,
                  function(second_value) {
                    d99_oracle_nested_integrand(
                      first_value,
                      second_value,
                      inputs$y,
                      inputs$beta,
                      inputs$Lambda,
                      component
                    )
                  },
                  numeric(1L)
                )
              },
              lower = -Inf,
              upper = Inf,
              subdivisions = 1000L,
              rel.tol = 1e-11,
              abs.tol = 1e-13
            )
            d99_oracle_assert_integrate_success(
              inner,
              paste0("inner component ", component)
            )
            integrate_checks <<- integrate_checks + 1L
            inner$value
          },
          numeric(1L)
        )
      },
      lower = -Inf,
      upper = Inf,
      subdivisions = 1000L,
      rel.tol = 1e-11,
      abs.tol = 1e-13
    )
    d99_oracle_assert_integrate_success(
      outer,
      paste0("outer component ", component)
    )
    integrate_checks <<- integrate_checks + 1L
    c(value = outer$value, abs.error = outer$abs.error)
  }
  values <- vapply(seq_len(19L), component_integral, numeric(2L))
  probability <- unname(values["value", 1L])
  numerator <- unname(values["value", -1L])
  numerical_error <- pmax(
    unname(values["abs.error", ]),
    d99_oracle_roundoff_bound(c(probability, numerator))
  )
  intervals <- d99_oracle_quotient_intervals(
    denominator = probability,
    denominator_error = numerical_error[1L],
    denominator_tail = 0,
    numerator = numerator,
    numerator_error = numerical_error[-1L],
    numerator_tail = numeric(18L),
    chart_jacobian = inputs$chart_jacobian
  )
  list(
    prob = probability,
    log_prob = log(probability),
    numerator = numerator,
    score = numerator / probability,
    integral_error = numerical_error,
    chart_score = intervals$score,
    chart_score_lower = intervals$lower,
    chart_score_upper = intervals$upper,
    chart_numerical_error = intervals$chart_numerical_error,
    chart_tail_bounds = intervals$chart_tail,
    denominator_interval = intervals$denominator,
    success = TRUE,
    error = NULL,
    backend_status = list(
      success = TRUE,
      message = "OK",
      checked_results = integrate_checks,
      error = NULL
    )
  )
}

d99_oracle_fixed_coordinate_comparator <- function(
  y,
  beta,
  Lambda,
  chart_jacobian = diag(18L)
) {
  cubature <- d99_oracle_cubature_pattern(
    y,
    beta,
    Lambda,
    chart_jacobian
  )
  nested <- d99_oracle_nested_pattern(
    y,
    beta,
    Lambda,
    chart_jacobian
  )
  overlap_lower <- pmax(
    cubature$chart_score_lower,
    nested$chart_score_lower
  )
  overlap_upper <- pmin(
    cubature$chart_score_upper,
    nested$chart_score_upper
  )
  list(
    success = TRUE,
    error = NULL,
    cubature = cubature,
    nested = nested,
    chart_score_overlap_lower = overlap_lower,
    chart_score_overlap_upper = overlap_upper,
    intervals_overlap = all(overlap_lower <= overlap_upper),
    log_probability_difference = abs(cubature$log_prob - nested$log_prob),
    implementation = "direct-original-u"
  )
}

d99_oracle_eval <- function(
  counts,
  beta,
  Lambda,
  method = c("cubature", "nested"),
  all_patterns = TRUE,
  chart_jacobian = diag(18L)
) {
  method <- match.arg(method)
  counts <- d99_validate_counts(counts)
  parameters <- d99_validate_parameters(beta, Lambda)
  chart_jacobian <- as.matrix(chart_jacobian)
  if (
    nrow(chart_jacobian) != 18L ||
      ncol(chart_jacobian) < 1L ||
      any(!is.finite(chart_jacobian))
  ) {
    stop("`chart_jacobian` must be a finite 18 by p matrix.", call. = FALSE)
  }
  patterns <- d99_pattern_matrix()
  selected <- if (isTRUE(all_patterns)) seq_len(64L) else which(counts > 0)
  if (!length(selected)) {
    stop("At least one response pattern must be selected.", call. = FALSE)
  }
  chart_dimension <- ncol(chart_jacobian)
  log_prob <- rep(NA_real_, 64L)
  probability <- rep(NA_real_, 64L)
  score_by_pattern <- matrix(NA_real_, 64L, 18L)
  integral_error_by_pattern <- matrix(NA_real_, 64L, 19L)
  lower_bounds <- rep(NA_real_, 64L)
  chart_score_by_pattern <- matrix(NA_real_, 64L, chart_dimension)
  chart_score_lower_by_pattern <- matrix(NA_real_, 64L, chart_dimension)
  chart_score_upper_by_pattern <- matrix(NA_real_, 64L, chart_dimension)
  backend_status_by_pattern <- vector("list", 64L)
  for (index in selected) {
    result <- if (identical(method, "cubature")) {
      d99_oracle_cubature_pattern(
        patterns[index, ],
        parameters$beta,
        parameters$Lambda,
        chart_jacobian
      )
    } else {
      d99_oracle_nested_pattern(
        patterns[index, ],
        parameters$beta,
        parameters$Lambda,
        chart_jacobian
      )
    }
    log_prob[index] <- result$log_prob
    probability[index] <- result$prob
    score_by_pattern[index, ] <- result$score
    integral_error_by_pattern[index, ] <- result$integral_error
    lower_bounds[index] <- result$denominator_interval["lower"]
    chart_score_by_pattern[index, ] <- result$chart_score
    chart_score_lower_by_pattern[index, ] <- result$chart_score_lower
    chart_score_upper_by_pattern[index, ] <- result$chart_score_upper
    backend_status_by_pattern[[index]] <- result$backend_status
  }
  observed <- which(counts > 0)
  list(
    loglik = sum(counts[observed] * log_prob[observed]),
    log_prob = log_prob,
    prob = probability,
    score = colSums(
      score_by_pattern[observed, , drop = FALSE] * counts[observed]
    ),
    score_by_pattern = score_by_pattern,
    chart_score = colSums(
      chart_score_by_pattern[observed, , drop = FALSE] * counts[observed]
    ),
    chart_score_lower = colSums(
      chart_score_lower_by_pattern[observed, , drop = FALSE] * counts[observed]
    ),
    chart_score_upper = colSums(
      chart_score_upper_by_pattern[observed, , drop = FALSE] * counts[observed]
    ),
    chart_score_by_pattern = chart_score_by_pattern,
    chart_score_lower_by_pattern = chart_score_lower_by_pattern,
    chart_score_upper_by_pattern = chart_score_upper_by_pattern,
    integral_error_by_pattern = integral_error_by_pattern,
    lower_bounds = lower_bounds,
    tail_bounds = d99_oracle_tail_bounds(),
    chart_jacobian = chart_jacobian,
    method = method,
    success = TRUE,
    error = NULL,
    backend_status_by_pattern = backend_status_by_pattern
  )
}
