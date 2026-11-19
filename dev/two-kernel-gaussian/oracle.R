# Independent dense Gaussian reference. Inputs are original kernels and explicit
# species/trait indices, never TMB precision matrices or model reports.
two_kernel_oracle <- function(y, X, species, trait, kernels, loadings,
                              log_sd, beta, sigma_eps, ridge = c(1e-8, 1e-8)) {
  stopifnot(length(kernels) == 2L, length(loadings) == 2L,
            length(log_sd) == 2L, length(ridge) == 2L,
            length(y) == length(species), length(y) == length(trait),
            nrow(X) == length(y), ncol(X) == length(beta),
            length(sigma_eps) == 1L, is.finite(sigma_eps), sigma_eps > 0,
            all(is.finite(y)), all(is.finite(X)),
            all(species >= 1L), all(trait >= 1L))
  n <- length(y)
  V <- matrix(0, n, n)
  Kobs <- vector('list', 2L)
  for (r in seq_len(2L)) {
    K <- as.matrix(kernels[[r]])
    L <- as.matrix(loadings[[r]])
    a <- log_sd[[r]]
    stopifnot(nrow(K) == ncol(K), max(species) <= nrow(K),
              max(trait) <= nrow(L), length(a) == nrow(L),
              all(is.finite(K)), all(is.finite(L)), all(is.finite(a)),
              is.finite(ridge[r]), ridge[r] >= 0)
    diag(K) <- diag(K) + ridge[r]
    Kobs[[r]] <- K[species, species, drop = FALSE]
    S <- tcrossprod(L) + diag(exp(2 * a), nrow(L))
    V <- V + Kobs[[r]] * S[trait, trait, drop = FALSE]
  }
  diag(V) <- diag(V) + sigma_eps^2
  R <- chol(V)
  residual <- as.numeric(y - X %*% beta)
  alpha <- backsolve(R, forwardsolve(t(R), residual))
  invV <- chol2inv(R)
  W <- invV - tcrossprod(alpha)
  nll <- (n * log(2 * pi) + 2 * sum(log(diag(R))) +
            sum(residual * alpha)) / 2
  grad <- list(beta = as.numeric(-crossprod(X, alpha)), loading = vector('list', 2L),
               log_sd = vector('list', 2L))
  for (r in seq_len(2L)) {
    L <- as.matrix(loadings[[r]])
    a <- log_sd[[r]]
    G <- matrix(0, nrow(L), ncol(L))
    for (t in seq_len(nrow(L))) for (j in seq_len(ncol(L))) {
      dL <- matrix(0, nrow(L), ncol(L)); dL[t, j] <- 1
      dS <- dL %*% t(L) + L %*% t(dL)
      G[t, j] <- sum(W * Kobs[[r]] * dS[trait, trait, drop = FALSE]) / 2
    }
    grad$loading[[r]] <- G
    grad$log_sd[[r]] <- vapply(seq_along(a), function(t) {
      sum(W * Kobs[[r]] * outer(trait == t, trait == t) * 2 * exp(2 * a[t])) / 2
    }, numeric(1))
  }
  list(nll = as.numeric(nll), covariance = V, gradient = grad)
}

two_kernel_gradient_vector <- function(x) {
  unlist(c(list(beta = x$beta),
           setNames(x$loading, paste0('loading', seq_along(x$loading))),
           setNames(x$log_sd, paste0('log_sd', seq_along(x$log_sd)))),
         use.names = TRUE)
}

# The caller must construct the mapping from native coordinates to the oracle
# coordinates independently, then provide named vectors with identical names.
# Fixed observation error is not a free gradient coordinate in this comparison.
two_kernel_compare_native <- function(reference, native_nll, native_gradient,
                                      reference_gradient, nll_tol = 2e-5,
                                      grad_abs_tol = 1e-5, grad_rel_tol = 1e-6) {
  stopifnot(length(native_nll) == 1L, is.finite(native_nll),
            !is.null(names(native_gradient)), !is.null(names(reference_gradient)),
            !anyDuplicated(names(native_gradient)),
            identical(names(native_gradient), names(reference_gradient)),
            all(is.finite(native_gradient)), all(is.finite(reference_gradient)))
  nll_gap <- abs(native_nll - reference$nll)
  grad_gap <- abs(native_gradient - reference_gradient)
  grad_limit <- grad_abs_tol + grad_rel_tol * abs(reference_gradient)
  list(pass = nll_gap <= nll_tol && all(grad_gap <= grad_limit),
       nll_gap = nll_gap, gradient_gap = grad_gap, gradient_limit = grad_limit)
}
