source("dev/structured-rho/spatial-recovery/study-metrics.R")
A <- diag(3)
M0 <- diag(c(1, 2, 3))
M1 <- diag(c(.2, .3, .4))
M2 <- diag(c(2, 1.5, 1))
got <- spatial_rho_source_covariance(A, M0, M1, M2, kappa = .7, rho = .3)
Q <- .7^4 * M0 + 2 * .7^2 * M1 + M2
K <- solve(Q)
Kr <- .3 * K
diag(Kr) <- diag(K)
stopifnot(max(abs(got$K - K)) < 1e-12, max(abs(got$Kr - Kr)) < 1e-12)
S <- matrix(c(1, .2, .2, .8), 2)
zero <- spatial_rho_covariance_errors(Kr, S, Kr, S, .36, .36)
stopifnot(max(abs(zero)) < 1e-12)
changed <- spatial_rho_covariance_errors(Kr, S * 1.1, Kr, S, .40, .36)
stopifnot(all(is.finite(changed)), all(changed > 0))
stopifnot(inherits(try(spatial_rho_source_covariance(A, M0, M1, M2, 0, .3),
                     silent = TRUE), "try-error"))
cat("SPATIAL_RECOVERY_PREFLIGHT_OK\n")
