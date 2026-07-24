#!/usr/bin/env Rscript

# Private Design-92 q=1 Bernoulli-logit VA foundation.  No gllvmTMB code is used.

d92_log1pexp <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))

# Bernoulli-logit log-likelihood derivatives, retained as an EVA-preparation
# kernel only.  No extended-VA objective is defined in Design 92.
d92_bernoulli_derivatives <- function(y, eta) {
  if (!all(y %in% c(0, 1)) || !all(is.finite(eta))) stop("Binary y and finite eta required.")
  probability <- plogis(eta)
  curvature <- probability * (1 - probability)
  list(loglik = y * eta - d92_log1pexp(eta),
       first = y - probability,
       second = -curvature,
       third = -curvature * (1 - 2 * probability),
       fourth = -curvature * (1 - 6 * probability + 6 * probability^2))
}

d92_expected_softplus <- function(mu, variance, order = 31L) {
  if (!is.finite(mu) || !is.finite(variance) || variance < 0) stop("Finite mu and non-negative variance required.")
  if (variance == 0) return(d92_log1pexp(mu))
  quad <- d92_normal_quadrature(order)
  sum(quad$w * d92_log1pexp(mu + sqrt(variance) * quad$z))
}

d92_expected_softplus_oracle <- function(mu, variance) {
  if (variance == 0) return(d92_log1pexp(mu))
  integrand <- function(z) d92_log1pexp(mu + sqrt(variance) * z) * dnorm(z)
  integrate(integrand, lower = -Inf, upper = Inf, subdivisions = 1000L, rel.tol = 1e-12)$value
}

d92_normal_quadrature <- function(order = 31L) {
  if (order < 3L || order %% 2L == 0L) stop("Quadrature order must be odd and at least 3.")
  j <- seq_len(order - 1L)
  jacobi <- matrix(0, order, order)
  jacobi[cbind(j, j + 1L)] <- sqrt(j / 2)
  jacobi[cbind(j + 1L, j)] <- sqrt(j / 2)
  eigen_result <- eigen(jacobi, symmetric = TRUE)
  list(z = sqrt(2) * eigen_result$values, w = eigen_result$vectors[1L, ]^2)
}

d92_validate_inputs <- function(y, intercept, loading, mean, log_sd) {
  if (!is.matrix(y) || !all(y %in% c(0, 1))) stop("y must be a binary matrix.")
  if (length(intercept) != ncol(y) || length(loading) != ncol(y)) stop("Trait parameters have incompatible length.")
  if (length(mean) != nrow(y) || length(log_sd) != nrow(y)) stop("Variational parameters have incompatible length.")
  if (!all(is.finite(c(intercept, loading, mean, log_sd)))) stop("All parameters must be finite.")
  invisible(TRUE)
}

d92_elbo_q1 <- function(y, intercept, loading, mean, log_sd, order = 31L) {
  d92_validate_inputs(y, intercept, loading, mean, log_sd)
  quad <- d92_normal_quadrature(order)
  sd <- exp(log_sd)
  expected_loglik <- 0
  for (i in seq_len(nrow(y))) {
    u <- mean[i] + sd[i] * quad$z
    eta <- outer(u, loading, "*") + rep(intercept, each = length(u))
    loglik <- sweep(eta, 2L, y[i, ], "*") - d92_log1pexp(eta)
    expected_loglik <- expected_loglik + sum(quad$w * rowSums(loglik))
  }
  kl <- 0.5 * sum(mean^2 + sd^2 - 1 - 2 * log_sd)
  expected_loglik - kl
}

d92_gradient_q1 <- function(y, intercept, loading, mean, log_sd, order = 31L) {
  d92_validate_inputs(y, intercept, loading, mean, log_sd)
  quad <- d92_normal_quadrature(order)
  sd <- exp(log_sd)
  gradient_mean <- gradient_log_sd <- numeric(nrow(y))
  for (i in seq_len(nrow(y))) {
    u <- mean[i] + sd[i] * quad$z
    eta <- outer(u, loading, "*") + rep(intercept, each = length(u))
    residual <- matrix(y[i, ], nrow(eta), ncol(eta), byrow = TRUE) - plogis(eta)
    weighted <- colSums(residual * quad$w)
    gradient_mean[i] <- sum(loading * weighted) - mean[i]
    weighted_z <- colSums(residual * (quad$w * quad$z))
    gradient_log_sd[i] <- sd[i] * sum(loading * weighted_z) + 1 - sd[i]^2
  }
  c(mean = gradient_mean, log_sd = gradient_log_sd)
}

d92_fit_va_q1 <- function(y, intercept, loading, start_mean = rep(0, nrow(y)),
                          start_log_sd = rep(0, nrow(y)), order = 31L) {
  start <- c(start_mean, start_log_sd)
  n <- nrow(y)
  value <- function(theta) -d92_elbo_q1(y, intercept, loading, theta[seq_len(n)],
                                         theta[n + seq_len(n)], order)
  gradient <- function(theta) -d92_gradient_q1(y, intercept, loading, theta[seq_len(n)],
                                                theta[n + seq_len(n)], order)
  fit <- optim(start, value, gradient, method = "BFGS", control = list(reltol = 1e-10))
  list(optim = fit, mean = fit$par[seq_len(n)], log_sd = fit$par[n + seq_len(n)],
       elbo = -fit$value, gradient = -gradient(fit$par))
}

d92_scalar_oracle <- function(y, intercept, loading, mean, log_sd) {
  sd <- exp(log_sd)
  integrate(function(z) {
    eta <- intercept + loading * (mean + sd * z)
    (y * eta - d92_log1pexp(eta)) * dnorm(z)
  }, lower = -Inf, upper = Inf, subdivisions = 1000L, rel.tol = 1e-12)$value
}

d92_central_gradient <- function(fn, theta, step = 1e-6) {
  vapply(seq_along(theta), function(j) {
    plus <- minus <- theta
    plus[j] <- plus[j] + step
    minus[j] <- minus[j] - step
    (fn(plus) - fn(minus)) / (2 * step)
  }, numeric(1))
}

d92_validate_q2_inputs <- function(y, intercept, loading, mean, log_sd) {
  if (!is.matrix(y) || !all(y %in% c(0, 1))) stop("y must be a complete binary matrix.")
  if (!is.matrix(loading) || !identical(dim(loading), c(ncol(y), 2L))) stop("loading must be traits by 2.")
  if (!is.matrix(mean) || !identical(dim(mean), c(nrow(y), 2L))) stop("mean must be units by 2.")
  if (!is.matrix(log_sd) || !identical(dim(log_sd), c(nrow(y), 2L))) stop("log_sd must be units by 2.")
  if (length(intercept) != ncol(y) || !all(is.finite(c(intercept, loading, mean, log_sd)))) {
    stop("q=2 parameters must be finite and conformable.")
  }
  invisible(TRUE)
}

d92_elbo_q2 <- function(y, intercept, loading, mean, log_sd, order = 31L) {
  d92_validate_q2_inputs(y, intercept, loading, mean, log_sd)
  quad <- d92_normal_quadrature(order)
  sd <- exp(log_sd)
  mu <- sweep(mean %*% t(loading), 2L, intercept, "+")
  variance <- (sd^2) %*% t(loading^2)
  expected_loglik <- 0
  for (i in seq_len(nrow(y))) for (trait in seq_len(ncol(y))) {
    eta <- mu[i, trait] + sqrt(variance[i, trait]) * quad$z
    expected_loglik <- expected_loglik + sum(quad$w * (y[i, trait] * eta - d92_log1pexp(eta)))
  }
  expected_loglik - 0.5 * sum(mean^2 + sd^2 - 1 - 2 * log_sd)
}

d92_gradient_q2 <- function(y, intercept, loading, mean, log_sd, order = 31L) {
  d92_validate_q2_inputs(y, intercept, loading, mean, log_sd)
  quad <- d92_normal_quadrature(order)
  sd <- exp(log_sd)
  mu <- sweep(mean %*% t(loading), 2L, intercept, "+")
  variance <- (sd^2) %*% t(loading^2)
  gradient_mean <- -mean
  gradient_log_sd <- 1 - sd^2
  for (i in seq_len(nrow(y))) for (trait in seq_len(ncol(y))) {
    eta <- mu[i, trait] + sqrt(variance[i, trait]) * quad$z
    probability <- plogis(eta)
    mean_residual <- sum(quad$w * (y[i, trait] - probability))
    mean_curvature <- sum(quad$w * probability * (1 - probability))
    gradient_mean[i, ] <- gradient_mean[i, ] + loading[trait, ] * mean_residual
    gradient_log_sd[i, ] <- gradient_log_sd[i, ] -
      loading[trait, ]^2 * sd[i, ]^2 * mean_curvature
  }
  c(mean = as.vector(gradient_mean), log_sd = as.vector(gradient_log_sd))
}

d92_fit_va_q2 <- function(y, intercept, loading, start_mean = matrix(0, nrow(y), 2L),
                          start_log_sd = matrix(0, nrow(y), 2L), order = 31L) {
  d92_validate_q2_inputs(y, intercept, loading, start_mean, start_log_sd)
  n <- nrow(y)
  start <- c(as.vector(start_mean), as.vector(start_log_sd))
  unpack <- function(theta) list(mean = matrix(theta[seq_len(2L * n)], nrow = n, ncol = 2L),
    log_sd = matrix(theta[2L * n + seq_len(2L * n)], nrow = n, ncol = 2L))
  value <- function(theta) {
    x <- unpack(theta)
    -d92_elbo_q2(y, intercept, loading, x$mean, x$log_sd, order)
  }
  gradient <- function(theta) {
    x <- unpack(theta)
    -d92_gradient_q2(y, intercept, loading, x$mean, x$log_sd, order)
  }
  fit <- optim(start, value, gradient, method = "BFGS", control = list(reltol = 1e-10))
  parameters <- unpack(fit$par)
  list(optim = fit, mean = parameters$mean, log_sd = parameters$log_sd,
       elbo = -fit$value, gradient = -gradient(fit$par))
}

d92_log_marginal_q1 <- function(y_row, intercept, loading) {
  integrand <- function(u) vapply(u, function(u_one) {
    eta <- intercept + loading * u_one
    exp(sum(y_row * eta - d92_log1pexp(eta))) * dnorm(u_one)
  }, numeric(1))
  log(integrate(integrand, lower = -Inf, upper = Inf, subdivisions = 1000L, rel.tol = 1e-12)$value)
}
