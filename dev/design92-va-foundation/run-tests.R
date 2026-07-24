#!/usr/bin/env Rscript

source(file.path("dev", "design92-va-foundation", "va-q1.R"))

# Scalar quadrature oracle: a single Bernoulli term agrees with independent integrate().
scalar_quad <- d92_elbo_q1(matrix(1, 1, 1), intercept = -0.35, loading = 0.8,
                            mean = 0.2, log_sd = log(0.7)) +
  0.5 * (0.2^2 + 0.7^2 - 1 - 2 * log(0.7))
scalar_ref <- d92_scalar_oracle(1, -0.35, 0.8, 0.2, log(0.7))
stopifnot(abs(scalar_quad - scalar_ref) < 1e-10)
eta_kernel <- c(-7, -1, 0, 1, 7)
derivative_kernel <- d92_bernoulli_derivatives(c(0, 1, 0, 1, 0), eta_kernel)
step <- 1e-6
first_difference <- (d92_bernoulli_derivatives(c(0, 1, 0, 1, 0), eta_kernel + step)$loglik -
  d92_bernoulli_derivatives(c(0, 1, 0, 1, 0), eta_kernel - step)$loglik) / (2 * step)
stopifnot(max(abs(first_difference - derivative_kernel$first)) < 1e-8)
for (mu_grid in c(-20, -5, 0, 5, 20)) for (variance_grid in c(0, 1e-8, 1e-4, 0.1, 1, 4)) {
  stopifnot(abs(d92_expected_softplus(mu_grid, variance_grid, order = 61L) -
    d92_expected_softplus_oracle(mu_grid, variance_grid)) < 1e-10)
}

y <- rbind(c(1, 0, 1), c(0, 1, 0), c(1, 1, 0), c(0, 0, 1))
intercept <- c(-0.4, 0.1, 0.5)
loading <- c(0.7, -0.5, 0.3)
mean <- c(0.2, -0.1, 0.3, -0.25)
log_sd <- log(c(0.8, 1.1, 0.9, 1.2))
theta <- c(mean, log_sd)
objective <- function(x) d92_elbo_q1(y, intercept, loading, x[1:4], x[5:8])
analytic <- d92_gradient_q1(y, intercept, loading, mean, log_sd)
numeric <- d92_central_gradient(objective, theta)
stopifnot(max(abs(analytic - numeric)) < 1e-5)

permutation <- c(3, 1, 2)
permuted <- d92_elbo_q1(y[, permutation], intercept[permutation], loading[permutation], mean, log_sd)
stopifnot(abs(permuted - objective(theta)) < 1e-12)

fit <- d92_fit_va_q1(y, intercept, loading)
stopifnot(is.finite(fit$elbo), fit$optim$convergence == 0L, max(abs(fit$gradient)) < 1e-5)
log_marginal <- sum(vapply(seq_len(nrow(y)), function(i) d92_log_marginal_q1(y[i, ], intercept, loading), numeric(1)))
stopifnot(fit$elbo <= log_marginal + 1e-8)

loading_q2 <- rbind(c(0.7, 0), c(-0.5, 0.4), c(0.3, -0.2))
mean_q2 <- cbind(mean, c(-0.15, 0.2, -0.05, 0.1))
log_sd_q2 <- cbind(log_sd, log(c(0.9, 1.05, 0.85, 1.1)))
theta_q2 <- c(as.vector(mean_q2), as.vector(log_sd_q2))
objective_q2 <- function(x) d92_elbo_q2(y, intercept, loading_q2,
  matrix(x[1:8], nrow = 4, ncol = 2), matrix(x[9:16], nrow = 4, ncol = 2))
analytic_q2 <- d92_gradient_q2(y, intercept, loading_q2, mean_q2, log_sd_q2)
numeric_q2 <- d92_central_gradient(objective_q2, theta_q2)
stopifnot(max(abs(analytic_q2 - numeric_q2)) < 1e-5)

embedding_loading <- cbind(loading, 0)
embedding_mean <- cbind(mean, 0)
embedding_log_sd <- cbind(log_sd, 0)
stopifnot(abs(d92_elbo_q2(y, intercept, embedding_loading, embedding_mean, embedding_log_sd) -
  objective(theta)) < 1e-10)
fit_q2 <- d92_fit_va_q2(y, intercept, loading_q2)
stopifnot(is.finite(fit_q2$elbo), fit_q2$optim$convergence == 0L,
          max(abs(fit_q2$gradient)) < 1e-5)
bad_y <- y; bad_y[1L, 1L] <- 2
stopifnot(inherits(try(d92_elbo_q1(bad_y, intercept, loading, mean, log_sd), silent = TRUE), "try-error"))
missing_y <- y; missing_y[1L, 1L] <- NA
stopifnot(inherits(try(d92_elbo_q2(missing_y, intercept, loading_q2, mean_q2, log_sd_q2), silent = TRUE), "try-error"))
cat("Design 92 q=1/q=2 VA foundation tests: PASS\n")
