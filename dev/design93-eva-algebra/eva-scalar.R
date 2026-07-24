#!/usr/bin/env Rscript

# Private source-mapped Bernoulli-logit EVA observation comparator.

d93_log1pexp <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))

d93_loglik <- function(y, mu) {
  if (!all(y %in% c(0, 1)) || !all(is.finite(mu))) stop("Binary y and finite mu required.")
  y * mu - d93_log1pexp(mu)
}

d93_eva_loglik <- function(y, mu, variance) {
  if (!all(is.finite(variance)) || any(variance < 0)) stop("Variance must be finite and non-negative.")
  probability <- plogis(mu)
  d93_loglik(y, mu) - 0.5 * probability * (1 - probability) * variance
}

d93_normal_quadrature <- function(order = 61L) {
  j <- seq_len(order - 1L)
  jacobi <- matrix(0, order, order)
  jacobi[cbind(j, j + 1L)] <- sqrt(j / 2)
  jacobi[cbind(j + 1L, j)] <- sqrt(j / 2)
  eigen_result <- eigen(jacobi, symmetric = TRUE)
  list(z = sqrt(2) * eigen_result$values, w = eigen_result$vectors[1L, ]^2)
}

d93_exact_loglik_expectation <- function(y, mu, variance, order = 61L) {
  if (variance == 0) return(d93_loglik(y, mu))
  quad <- d93_normal_quadrature(order)
  sum(quad$w * d93_loglik(y, mu + sqrt(variance) * quad$z))
}
