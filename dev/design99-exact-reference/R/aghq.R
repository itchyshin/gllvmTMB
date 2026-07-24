d99_log_kernel <- function(u, y, beta, Lambda) {
  eta <- as.numeric(beta + Lambda %*% u)
  sum(y * eta - d99_softplus(eta)) - 0.5 * sum(u^2) - log(2 * pi)
}

d99_log_kernel_increment <- function(u, step, y, beta, Lambda) {
  eta <- as.numeric(beta + Lambda %*% u)
  eta_increment <- as.numeric(Lambda %*% step)
  softplus_increment <- log1p(plogis(eta) * expm1(eta_increment))
  sum(y * eta_increment - softplus_increment) -
    sum(u * step) -
    0.5 * sum(step^2)
}

d99_kernel_derivatives <- function(u, y, beta, Lambda) {
  eta <- as.numeric(beta + Lambda %*% u)
  probability <- plogis(eta)
  residual <- y - probability
  Q <- diag(2) + crossprod(Lambda, Lambda * (probability * (1 - probability)))
  list(
    gradient = as.numeric(crossprod(Lambda, residual) - u),
    Q = Q,
    probability = probability,
    eta = eta
  )
}

d99_conditional_mode <- function(
  y,
  beta,
  Lambda,
  max_iterations = 50L,
  max_halvings = 30L
) {
  y <- as.numeric(y)
  if (length(y) != 6L || any(y != 0 & y != 1)) {
    stop("`y` must be a binary vector of length six.", call. = FALSE)
  }
  parameters <- d99_validate_parameters(beta, Lambda)
  beta <- parameters$beta
  Lambda <- parameters$Lambda
  u <- c(0, 0)
  value <- d99_log_kernel(u, y, beta, Lambda)
  steps <- numeric()
  for (iteration in seq_len(max_iterations)) {
    derivatives <- d99_kernel_derivatives(u, y, beta, Lambda)
    eigenvalues <- eigen(
      derivatives$Q,
      symmetric = TRUE,
      only.values = TRUE
    )$values
    if (any(!is.finite(eigenvalues)) || min(eigenvalues) < 1 - 1e-10) {
      stop(
        "Conditional Hessian failed its positive-definiteness invariant.",
        call. = FALSE
      )
    }
    step <- tryCatch(
      solve(derivatives$Q, derivatives$gradient),
      error = function(e) NULL
    )
    if (is.null(step) || any(!is.finite(step))) {
      stop("Conditional Newton system is not solvable.", call. = FALSE)
    }
    decrement <- sum(derivatives$gradient * step)
    if (max(abs(derivatives$gradient)) < 1e-10 && decrement < 1e-12) {
      return(list(
        u = u,
        Q = derivatives$Q,
        gradient_inf = max(abs(derivatives$gradient)),
        decrement = decrement,
        min_eigenvalue = min(eigenvalues),
        iterations = iteration - 1L,
        steps = steps
      ))
    }
    accepted <- FALSE
    for (halving in 0:max_halvings) {
      alpha <- 2^(-halving)
      accepted_step <- alpha * step
      candidate <- u + accepted_step
      candidate_value <- d99_log_kernel(candidate, y, beta, Lambda)
      kernel_increment <- d99_log_kernel_increment(
        u,
        accepted_step,
        y,
        beta,
        Lambda
      )
      if (
        is.finite(candidate_value) &&
          is.finite(kernel_increment) &&
          kernel_increment > 0
      ) {
        u <- candidate
        value <- candidate_value
        steps <- c(steps, alpha)
        accepted <- TRUE
        break
      }
    }
    if (!accepted) {
      stop(
        "MECHANICAL failure: conditional Newton backtracking did not find a strict increase.",
        call. = FALSE
      )
    }
  }
  derivatives <- d99_kernel_derivatives(u, y, beta, Lambda)
  step <- solve(derivatives$Q, derivatives$gradient)
  decrement <- sum(derivatives$gradient * step)
  if (max(abs(derivatives$gradient)) < 1e-10 && decrement < 1e-12) {
    return(list(
      u = u,
      Q = derivatives$Q,
      gradient_inf = max(abs(derivatives$gradient)),
      decrement = decrement,
      min_eigenvalue = min(
        eigen(derivatives$Q, symmetric = TRUE, only.values = TRUE)$values
      ),
      iterations = max_iterations,
      steps = steps
    ))
  }
  stop(
    "MECHANICAL failure: conditional Newton solver did not meet the mode thresholds in 50 iterations.",
    call. = FALSE
  )
}

d99_aghq_pattern <- function(y, beta, Lambda, gh, need_score = TRUE) {
  validation <- d99_validate_gh(gh)
  parameters <- d99_validate_parameters(beta, Lambda)
  beta <- parameters$beta
  Lambda <- parameters$Lambda
  mode <- d99_conditional_mode(y, beta, Lambda)
  R <- chol(mode$Q)
  A <- t(chol(solve(mode$Q)))
  log_abs_det_A <- -sum(log(diag(R)))
  tensor <- validation$tensor
  u <- sweep(tensor$nodes %*% t(A), 2L, mode$u, "+")
  eta <- sweep(u %*% t(Lambda), 2L, beta, "+")
  log_kernel <- rowSums(sweep(eta, 2L, y, "*") - d99_softplus(eta)) -
    0.5 * rowSums(u^2) -
    log(2 * pi)
  log_terms <- tensor$log_weights +
    log_kernel +
    log(2 * pi) +
    0.5 * rowSums(tensor$nodes^2) +
    log_abs_det_A
  log_probability <- d99_logsumexp(log_terms)
  posterior_weights <- exp(log_terms - log_probability)
  score <- NULL
  if (need_score) {
    residual <- sweep(
      sweep(plogis(eta), 2L, y, function(probability, response) {
        response - probability
      }),
      1L,
      posterior_weights,
      "*"
    )
    score <- c(colSums(residual), as.vector(t(t(residual) %*% u)))
  }
  list(
    log_prob = log_probability,
    prob = exp(log_probability),
    score = score,
    mode = c(mode, list(A = A, log_abs_det_A = log_abs_det_A)),
    log_terms = log_terms
  )
}

d99_aghq_eval <- function(
  counts,
  beta,
  Lambda,
  gh,
  need_score = TRUE,
  all_patterns = TRUE
) {
  counts <- d99_validate_counts(counts)
  parameters <- d99_validate_parameters(beta, Lambda)
  validation <- d99_validate_gh(gh)
  patterns <- d99_pattern_matrix()
  selected <- if (isTRUE(all_patterns)) seq_len(64L) else which(counts > 0)
  if (!length(selected)) {
    stop("At least one response pattern must be selected.", call. = FALSE)
  }
  log_prob <- rep(NA_real_, 64L)
  probability <- rep(NA_real_, 64L)
  score_by_pattern <- matrix(NA_real_, 64L, 18L)
  modes <- vector("list", 64L)
  for (index in selected) {
    result <- d99_aghq_pattern(
      patterns[index, ],
      parameters$beta,
      parameters$Lambda,
      gh,
      need_score
    )
    log_prob[index] <- result$log_prob
    probability[index] <- result$prob
    if (need_score) {
      score_by_pattern[index, ] <- result$score
    }
    modes[[index]] <- result$mode
  }
  observed <- which(counts > 0)
  if (anyNA(log_prob[observed])) {
    stop("Observed response patterns were not evaluated.", call. = FALSE)
  }
  score <- if (need_score) {
    colSums(score_by_pattern[observed, , drop = FALSE] * counts[observed])
  } else {
    NULL
  }
  list(
    loglik = sum(counts[observed] * log_prob[observed]),
    log_prob = log_prob,
    prob = probability,
    score = score,
    score_by_pattern = score_by_pattern,
    modes = modes,
    quadrature = list(
      order = validation$order,
      nodes = validation$nodes,
      weights = validation$weights,
      node_hash = if (!is.null(gh$node_hash)) {
        gh$node_hash
      } else {
        d99_sha256(validation$nodes)
      },
      weight_hash = if (!is.null(gh$weight_hash)) {
        gh$weight_hash
      } else {
        d99_sha256(validation$weights)
      },
      tensor_hash = if (!is.null(gh$tensor_hash)) {
        gh$tensor_hash
      } else {
        d99_sha256(validation$tensor$nodes)
      },
      tensor_order = "first-coordinate-fastest"
    )
  )
}
