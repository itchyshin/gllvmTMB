#!/usr/bin/env Rscript

source(file.path("dev", "design93-eva-algebra", "eva-scalar.R"))
mu <- c(-8, -2, 0, 2, 8)
y <- c(0, 1, 0, 1, 0)
variance <- c(0, 1e-8, 1e-4, 0.1, 1)
probability <- plogis(mu)
source_formula <- d93_loglik(y, mu) - probability * (1 - probability) * variance / 2
stopifnot(max(abs(d93_eva_loglik(y, mu, variance) - source_formula)) < 1e-14)
stopifnot(max(abs(d93_eva_loglik(y, mu, 0) - d93_loglik(y, mu))) < 1e-14)

for (mu_one in c(-5, 0, 5)) {
  error_large <- abs(d93_eva_loglik(1, mu_one, 1e-2) - d93_exact_loglik_expectation(1, mu_one, 1e-2))
  error_small <- abs(d93_eva_loglik(1, mu_one, 1e-4) - d93_exact_loglik_expectation(1, mu_one, 1e-4))
  stopifnot(error_small < error_large)
}
stopifnot(inherits(try(d93_eva_loglik(2, 0, 1), silent = TRUE), "try-error"))
stopifnot(inherits(try(d93_eva_loglik(1, 0, -1), silent = TRUE), "try-error"))
cat("Design 93 scalar EVA comparator tests: PASS\n")
