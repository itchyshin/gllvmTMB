# Independent R oracle for the private Design 98 q = 2 discriminator.
# This file is not part of the package API.

d98_softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))

d98_jj_smooth_r <- function(r) {
  if (any(!is.finite(r)) || any(r < 0)) {
    stop("r must be finite and non-negative")
  }
  root <- sqrt(pmax(r, 1e-8))
  ifelse(
    r < 1e-8,
    -log(2) - r / 8 + r^2 / 192,
    -log(2) - log(cosh(root / 2))
  )
}

d98_expected_softplus <- function(mu, variance, gh) {
  if (!identical(dim(mu), dim(variance)) ||
      any(!is.finite(mu)) || any(!is.finite(variance)) ||
      any(variance < -1e-12)) {
    stop("mu and variance must be conformable and variance non-negative")
  }
  variance <- pmax(variance, 0)
  regular <- matrix(0, nrow(mu), ncol(mu))
  sd_safe <- sqrt(pmax(variance, 1e-8))
  for (h in seq_along(gh$z)) {
    regular <- regular +
      gh$w[h] * d98_softplus(mu + sd_safe * gh$z[h])
  }
  probability <- plogis(mu)
  second <- probability * (1 - probability)
  fourth <- second * (1 - 6 * probability + 6 * probability^2)
  series <- d98_softplus(mu) +
    0.5 * variance * second +
    variance^2 * fourth / 8
  ifelse(variance < 1e-8, series, regular)
}

d98_gh <- local({
  cache <- new.env(parent = emptyenv())
  function(order = 31L) {
    order <- as.integer(order)
    if (length(order) != 1L || is.na(order) || order < 1L) {
      stop("order must be one positive integer")
    }
    key <- as.character(order)
    if (exists(key, envir = cache, inherits = FALSE)) {
      return(get(key, envir = cache, inherits = FALSE))
    }
    if (order == 1L) {
      ans <- list(z = 0, w = 1)
    } else {
      j <- seq_len(order - 1L)
      jacobi <- matrix(0, order, order)
      jacobi[cbind(j, j + 1L)] <- sqrt(j / 2)
      jacobi[cbind(j + 1L, j)] <- sqrt(j / 2)
      eig <- eigen(jacobi, symmetric = TRUE)
      physicist_node <- eig$values
      h_prev <- rep(1, order)
      h_curr <- 2 * physicist_node
      if (order > 2L) {
        for (degree in 2L:(order - 1L)) {
          h_next <- 2 * physicist_node * h_curr -
            2 * (degree - 1L) * h_prev
          h_prev <- h_curr
          h_curr <- h_next
        }
      }
      h_n_minus_1 <- if (order == 2L) h_curr else h_curr
      log_weight <- (order - 1L) * log(2) + lgamma(order + 1) -
        2 * log(order) - 2 * log(abs(h_n_minus_1))
      normalized_weight <- exp(log_weight - max(log_weight))
      normalized_weight <- normalized_weight / sum(normalized_weight)
      ans <- list(
        z = sqrt(2) * physicist_node,
        w = normalized_weight
      )
    }
    assign(key, ans, envir = cache)
    ans
  }
})

d98_loading_from_free <- function(loading_free, traits) {
  traits <- as.integer(traits)
  if (length(traits) != 1L || is.na(traits) || traits < 2L) {
    stop("traits must be at least two")
  }
  if (length(loading_free) != 2L * traits - 1L ||
      any(!is.finite(loading_free))) {
    stop("loading_free has the wrong length or contains non-finite values")
  }
  loading <- matrix(0, traits, 2L)
  loading[1L, 1L] <- exp(loading_free[1L])
  loading[2L, ] <- c(loading_free[2L], exp(loading_free[3L]))
  if (traits > 2L) {
    loading[3L:traits, ] <- matrix(
      loading_free[4L:length(loading_free)],
      nrow = traits - 2L,
      ncol = 2L,
      byrow = TRUE
    )
  }
  loading
}

d98_loading_to_free <- function(loading) {
  if (!is.matrix(loading) || ncol(loading) != 2L ||
      nrow(loading) < 2L || any(!is.finite(loading)) ||
      loading[1L, 1L] <= 0 || loading[2L, 2L] <= 0 ||
      loading[1L, 2L] != 0) {
    stop("loading must follow the positive lower-triangular leading-block convention")
  }
  trailing <- if (nrow(loading) > 2L) {
    as.vector(t(loading[3L:nrow(loading), , drop = FALSE]))
  } else {
    numeric()
  }
  c(log(loading[1L, 1L]), loading[2L, 1L],
    log(loading[2L, 2L]), trailing)
}

d98_validate_response <- function(y) {
  if (!is.matrix(y) || ncol(y) < 2L || nrow(y) < 1L ||
      any(!is.finite(y)) || any(!y %in% c(0, 1))) {
    stop("y must be a finite, complete Bernoulli matrix with at least two traits")
  }
  invisible(TRUE)
}

d98_geometry <- function(chol_free, full) {
  if (!is.matrix(chol_free) || any(!is.finite(chol_free))) {
    stop("chol_free must be a finite matrix")
  }
  expected_cols <- if (isTRUE(full)) 3L else 2L
  if (ncol(chol_free) != expected_cols) {
    stop("chol_free has the wrong number of columns for the geometry")
  }
  a <- chol_free[, 1L]
  if (isTRUE(full)) {
    b <- chol_free[, 2L]
    cpar <- chol_free[, 3L]
  } else {
    b <- rep(0, nrow(chol_free))
    cpar <- chol_free[, 2L]
  }
  l11 <- exp(a)
  l22 <- exp(cpar)
  list(
    a = a,
    b = b,
    c = cpar,
    s11 = l11^2,
    s12 = l11 * b,
    s22 = b^2 + l22^2,
    logdet = 2 * (a + cpar)
  )
}

d98_variational_elbo <- function(
    y, beta, loading_free, mean, chol_free,
    method = c("QD", "QF", "JD", "JF"), gh = d98_gh(31L)) {
  method <- match.arg(method)
  d98_validate_response(y)
  n <- nrow(y)
  traits <- ncol(y)
  if (length(beta) != traits || any(!is.finite(beta)) ||
      !identical(dim(mean), c(n, 2L)) || any(!is.finite(mean))) {
    stop("beta or mean has incompatible dimensions or non-finite values")
  }
  if (!is.list(gh) || length(gh$z) != length(gh$w) ||
      any(!is.finite(gh$z)) || any(!is.finite(gh$w)) ||
      any(gh$w <= 0) || abs(sum(gh$w) - 1) > 1e-12) {
    stop("gh must contain normalized standard-normal nodes and positive weights")
  }
  full <- method %in% c("QF", "JF")
  direct <- method %in% c("QD", "QF")
  geom <- d98_geometry(chol_free, full)
  loading <- d98_loading_from_free(loading_free, traits)
  mu <- sweep(mean %*% t(loading), 2L, beta, "+")
  variance <- outer(geom$s11, loading[, 1L]^2) +
    2 * outer(geom$s12, loading[, 1L] * loading[, 2L]) +
    outer(geom$s22, loading[, 2L]^2)
  if (any(variance < -1e-12)) {
    stop("projected variational variance is negative")
  }
  variance <- pmax(variance, 0)

  if (direct) {
    expected_softplus <- d98_expected_softplus(mu, variance, gh)
    observation <- sum(y * mu - expected_softplus)
  } else {
    r <- mu^2 + variance
    observation <- sum(d98_jj_smooth_r(r) + (y - 0.5) * mu)
  }

  kl <- 0.5 * sum(
    geom$s11 + geom$s22 + rowSums(mean^2) - geom$logdet - 2
  )
  observation - kl
}

d98_logsumexp <- function(x) {
  anchor <- max(x)
  anchor + log(sum(exp(x - anchor)))
}

d98_gh_log_marginal_matrix <- function(
    y, beta, loading, gh = d98_gh(31L)) {
  d98_validate_response(y)
  if (!is.matrix(loading) || !identical(dim(loading), c(ncol(y), 2L)) ||
      length(beta) != ncol(y) || any(!is.finite(beta)) ||
      any(!is.finite(loading)) || length(gh$z) != length(gh$w) ||
      any(gh$w <= 0) || abs(sum(gh$w) - 1) > 1e-12) {
    stop("invalid marginal-likelihood inputs")
  }
  logw <- log(gh$w)
  total <- 0
  for (i in seq_len(nrow(y))) {
    terms <- numeric(length(gh$z)^2)
    cursor <- 0L
    for (r in seq_along(gh$z)) {
      for (s in seq_along(gh$z)) {
        cursor <- cursor + 1L
        eta <- beta + loading[, 1L] * gh$z[r] +
          loading[, 2L] * gh$z[s]
        terms[cursor] <- logw[r] + logw[s] +
          sum(y[i, ] * eta - d98_softplus(eta))
      }
    }
    total <- total + d98_logsumexp(terms)
  }
  total
}

d98_gh_log_marginal <- function(
    y, beta, loading_free, gh = d98_gh(31L)) {
  d98_gh_log_marginal_matrix(
    y, beta, d98_loading_from_free(loading_free, ncol(y)), gh
  )
}

d98_posterior_moments <- function(
    y, beta, loading_free, gh = d98_gh(61L)) {
  d98_validate_response(y)
  loading <- d98_loading_from_free(loading_free, ncol(y))
  if (length(beta) != ncol(y) || any(!is.finite(beta)) ||
      length(gh$z) != length(gh$w) || any(gh$w <= 0) ||
      abs(sum(gh$w) - 1) > 1e-12) {
    stop("invalid posterior-moment inputs")
  }
  grid <- as.matrix(expand.grid(u1 = gh$z, u2 = gh$z))
  prior_weight <- as.vector(outer(gh$w, gh$w))
  posterior_mean <- matrix(0, nrow(y), 2L)
  posterior_covariance <- array(0, c(nrow(y), 2L, 2L))
  log_normalizer <- numeric(nrow(y))
  for (i in seq_len(nrow(y))) {
    eta <- sweep(grid %*% t(loading), 2L, beta, "+")
    log_kernel <- log(prior_weight) +
      rowSums(sweep(eta, 2L, y[i, ], "*") - d98_softplus(eta))
    log_normalizer[i] <- d98_logsumexp(log_kernel)
    weight <- exp(log_kernel - log_normalizer[i])
    posterior_mean[i, ] <- colSums(grid * weight)
    centered <- sweep(grid, 2L, posterior_mean[i, ], "-")
    posterior_covariance[i, , ] <-
      crossprod(centered, centered * weight)
  }
  list(
    mean = posterior_mean,
    covariance = posterior_covariance,
    log_normalizer = log_normalizer
  )
}

d98_marginal_probability <- function(
    beta, loading_free, gh = d98_gh(61L)) {
  loading <- d98_loading_from_free(loading_free, length(beta))
  weight <- outer(gh$w, gh$w)
  vapply(seq_along(beta), function(t) {
    probability <- outer(gh$z, gh$z, function(u1, u2) {
      plogis(beta[t] + loading[t, 1L] * u1 + loading[t, 2L] * u2)
    })
    sum(weight * probability)
  }, numeric(1))
}

d98_pack_variational <- function(
    beta, loading_free, mean, chol_free) {
  c(beta, loading_free, as.vector(mean), as.vector(chol_free))
}

d98_unpack_variational <- function(theta, n, traits, full) {
  global_end <- traits + 2L * traits - 1L
  mean_end <- global_end + 2L * n
  chol_cols <- if (isTRUE(full)) 3L else 2L
  expected <- mean_end + chol_cols * n
  if (length(theta) != expected) {
    stop("theta has the wrong length")
  }
  list(
    beta = theta[seq_len(traits)],
    loading_free = theta[(traits + 1L):global_end],
    mean = matrix(theta[(global_end + 1L):mean_end], n, 2L),
    chol_free = matrix(theta[(mean_end + 1L):expected], n, chol_cols)
  )
}

d98_pack_global <- function(beta, loading_free) c(beta, loading_free)

d98_unpack_global <- function(theta, traits) {
  expected <- 3L * traits - 1L
  if (length(theta) != expected) {
    stop("global theta has the wrong length")
  }
  list(
    beta = theta[seq_len(traits)],
    loading_free = theta[(traits + 1L):expected]
  )
}

d98_central_gradient <- function(fn, theta, step = 1e-6) {
  vapply(seq_along(theta), function(j) {
    plus <- minus <- theta
    plus[j] <- plus[j] + step
    minus[j] <- minus[j] - step
    (fn(plus) - fn(minus)) / (2 * step)
  }, numeric(1))
}

d98_relative_gradient_error <- function(reference, candidate) {
  max(abs(reference - candidate) /
        pmax(1, abs(reference), abs(candidate)))
}
