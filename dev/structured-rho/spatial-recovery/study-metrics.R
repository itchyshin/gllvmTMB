# Frobenius errors without materialising the replicated observation covariance.
spatial_rho_covariance_errors <- function(Kh, Sh, Kt, St,
                                          residual_variance, truth_variance,
                                          replications = 3L) {
  stopifnot(
    length(residual_variance) == 1L, is.finite(residual_variance), residual_variance > 0,
    length(truth_variance) == 1L, is.finite(truth_variance), truth_variance > 0,
    all(is.finite(c(Kh, Sh, Kt, St))), identical(dim(Kh), dim(Kt)),
    identical(dim(Sh), dim(St))
  )
  source_error_sq <- max(0,
    sum(Kh^2) * sum(Sh^2) + sum(Kt^2) * sum(St^2) -
      2 * sum(Kh * Kt) * sum(Sh * St)
  )
  delta <- residual_variance - truth_variance
  n <- nrow(Kt) * nrow(St) * replications
  total_error_sq <- max(0,
    replications^2 * source_error_sq +
      2 * replications * delta *
        (sum(diag(Kh)) * sum(diag(Sh)) - sum(diag(Kt)) * sum(diag(St))) +
      n * delta^2
  )
  source_truth_sq <- sum(Kt^2) * sum(St^2)
  total_truth_sq <- replications^2 * source_truth_sq +
    2 * replications * truth_variance * sum(diag(Kt)) * sum(diag(St)) +
    n * truth_variance^2
  out <- c(
    source = sqrt(source_error_sq / source_truth_sq),
    total = sqrt(total_error_sq / total_truth_sq)
  )
  stopifnot(length(out) == 2L, all(is.finite(out)), all(out >= 0))
  out
}

spatial_rho_source_covariance <- function(A, M0, M1, M2, kappa, rho) {
  stopifnot(length(kappa) == 1L, is.finite(kappa), kappa > 0,
            length(rho) == 1L, is.finite(rho), rho >= 0, rho <= 1)
  Q <- kappa^4 * M0 + 2 * kappa^2 * M1 + M2
  K <- as.matrix(A %*% Matrix::solve(Q, Matrix::t(A)))
  Kr <- rho * K
  diag(Kr) <- diag(K)
  list(K = K, Kr = Kr)
}
