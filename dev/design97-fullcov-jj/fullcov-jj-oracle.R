d97_log1pexp <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))
d97_logsigmoid <- function(x) -d97_log1pexp(-x)
d97_omega <- function(x) ifelse(abs(x) < 1e-6, 1 / 8 - x^2 / 96, tanh(x / 2) / (4 * x))

d97_loading_from_free <- function(x, traits) {
  stopifnot(traits >= 2L, length(x) == 2L * traits - 1L)
  L <- matrix(0, traits, 2L); L[1L, 1L] <- exp(x[1L]); L[2L, ] <- c(x[2L], exp(x[3L]))
  if (traits > 2L) L[3:traits, ] <- matrix(x[4:length(x)], traits - 2L, 2L, byrow = TRUE)
  L
}

d97_chol_to_cov <- function(chol_free) {
  stopifnot(is.matrix(chol_free), ncol(chol_free) == 3L)
  l11 <- exp(chol_free[, 1L]); l21 <- chol_free[, 2L]; l22 <- exp(chol_free[, 3L])
  cbind(s11 = l11^2, s12 = l11 * l21, s22 = l21^2 + l22^2)
}

d97_jj_elbo <- function(y, beta, loading_free, mean, chol_free) {
  stopifnot(is.matrix(y), all(y %in% c(0, 1)), ncol(mean) == 2L,
    identical(dim(mean), c(nrow(y), 2L)), identical(dim(chol_free), c(nrow(y), 3L)))
  L <- d97_loading_from_free(loading_free, ncol(y)); S <- d97_chol_to_cov(chol_free)
  mu <- sweep(mean %*% t(L), 2L, beta, "+")
  variance <- outer(S[, 1L], L[, 1L]^2) + 2 * outer(S[, 2L], L[, 1L] * L[, 2L]) + outer(S[, 3L], L[, 2L]^2)
  r <- mu^2 + variance
  # Profiled omega terms cancel exactly. This avoids differentiating sqrt(r) at zero.
  root <- sqrt(pmax(r, 1e-8))
  smooth <- ifelse(r < 1e-8, -log(2) - r / 8 + r^2 / 192, -log(2) - log(cosh(root / 2)))
  bound <- smooth + (y - .5) * mu
  kl <- .5 * sum(S[, 1L] + S[, 3L] + rowSums(mean^2) - 2 * chol_free[, 1L] - 2 * chol_free[, 3L] - 2)
  sum(bound) - kl
}

d97_gh <- local({ cache <- list(); function(order = 31L) {
  key <- as.character(order); if (!is.null(cache[[key]])) return(cache[[key]])
  j <- seq_len(order - 1L); J <- matrix(0, order, order)
  J[cbind(j, j + 1L)] <- sqrt(j / 2); J[cbind(j + 1L, j)] <- sqrt(j / 2)
  e <- eigen(J, symmetric = TRUE); cache[[key]] <<- list(z = sqrt(2) * e$values, w = e$vectors[1L, ]^2); cache[[key]]
} })

d97_gh_log_marginal <- function(y, beta, loading_free, order = 31L) {
  h <- d97_gh(order); L <- d97_loading_from_free(loading_free, ncol(y)); total <- 0
  for (i in seq_len(nrow(y))) {
    terms <- numeric(order * order); k <- 0L
    for (r in seq_len(order)) for (s in seq_len(order)) {
      k <- k + 1L; eta <- beta + L[, 1L] * h$z[r] + L[, 2L] * h$z[s]
      terms[k] <- log(h$w[r]) + log(h$w[s]) + sum(y[i, ] * eta - d97_log1pexp(eta))
    }
    a <- max(terms); total <- total + a + log(sum(exp(terms - a)))
  }
  total
}

d97_exact_elbo <- function(y, beta, loading_free, mean, chol_free, order = 31L) {
  h <- d97_gh(order); L <- d97_loading_from_free(loading_free, ncol(y)); total <- 0
  for (i in seq_len(nrow(y))) {
    l11 <- exp(chol_free[i, 1L]); l21 <- chol_free[i, 2L]; l22 <- exp(chol_free[i, 3L])
    for (t in seq_len(ncol(y))) {
      terms <- numeric(order * order); k <- 0L
      for (r in seq_len(order)) for (s in seq_len(order)) {
        k <- k + 1L; u <- mean[i, ] + c(l11 * h$z[r], l21 * h$z[r] + l22 * h$z[s])
        eta <- beta[t] + sum(L[t, ] * u); terms[k] <- log(h$w[r]) + log(h$w[s]) + y[i, t] * eta - d97_log1pexp(eta)
      }
      a <- max(terms); total <- total + a + log(sum(exp(terms - a)))
    }
  }
  S <- d97_chol_to_cov(chol_free)
  total - .5 * sum(S[, 1L] + S[, 3L] + rowSums(mean^2) - 2 * chol_free[, 1L] - 2 * chol_free[, 3L] - 2)
}

d97_marginal_probability <- function(beta, loading_free, order = 61L) {
  h <- d97_gh(order); L <- d97_loading_from_free(loading_free, length(beta))
  vapply(seq_along(beta), function(t) {
    p <- outer(h$z, h$z, function(a, b) plogis(beta[t] + L[t, 1L] * a + L[t, 2L] * b))
    sum(outer(h$w, h$w) * p)
  }, numeric(1))
}

d97_diagonal_elbo <- function(y, beta, loading_free, mean, log_sd) {
  stopifnot(identical(dim(mean), c(nrow(y), 2L)), identical(dim(log_sd), c(nrow(y), 2L)))
  d97_jj_elbo(y, beta, loading_free, mean, cbind(log_sd[, 1L], 0, log_sd[, 2L]))
}

d97_pack <- function(beta, loading_free, mean, chol_free) c(beta, loading_free, as.vector(mean), as.vector(chol_free))
d97_unpack <- function(theta, n, traits) {
  p <- traits; q <- p + 2L * traits - 1L; r <- q + 2L * n
  list(beta = theta[seq_len(p)], loading_free = theta[(p + 1L):q], mean = matrix(theta[(q + 1L):r], n, 2L), chol_free = matrix(theta[(r + 1L):(r + 3L * n)], n, 3L))
}
d97_central_gradient <- function(fn, theta, step = 1e-6) vapply(seq_along(theta), function(j) { a <- b <- theta; a[j] <- a[j] + step; b[j] <- b[j] - step; (fn(a) - fn(b)) / (2 * step) }, numeric(1))
d97_global_pack <- function(beta, loading_free) c(beta, loading_free)
d97_global_unpack <- function(x, traits) list(beta = x[seq_len(traits)], loading_free = x[(traits + 1L):(traits + 2L * traits - 1L)])
