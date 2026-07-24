d95_log1pexp <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))
d95_logsigmoid <- function(x) -d95_log1pexp(-x)
d95_omega <- function(x) ifelse(abs(x) < 1e-6, 1 / 8 - x^2 / 96, tanh(x / 2) / (4 * x))

d95_loading_from_free <- function(loading_free, traits) {
  stopifnot(traits >= 2L, length(loading_free) == 2L * traits - 1L)
  loading <- matrix(0, traits, 2L)
  loading[1L, 1L] <- exp(loading_free[1L])
  loading[2L, 1L] <- loading_free[2L]
  loading[2L, 2L] <- exp(loading_free[3L])
  if (traits > 2L) loading[3:traits, ] <- matrix(loading_free[4:length(loading_free)], traits - 2L, 2L, byrow = TRUE)
  loading
}

d95_loading_to_free <- function(loading, tolerance = 1e-12) {
  stopifnot(is.matrix(loading), ncol(loading) == 2L, nrow(loading) >= 2L,
    loading[1L, 1L] > 0, loading[2L, 2L] > 0, abs(loading[1L, 2L]) < tolerance)
  tail <- if (nrow(loading) > 2L) as.vector(t(loading[3:nrow(loading), , drop = FALSE])) else numeric()
  c(log(loading[1L, 1L]), loading[2L, 1L], log(loading[2L, 2L]), tail)
}

d95_jj_elbo <- function(y, beta, loading_free, mean, log_sd) {
  stopifnot(is.matrix(y), all(y %in% c(0, 1)), length(beta) == ncol(y), ncol(y) >= 2L,
    identical(dim(mean), c(nrow(y), 2L)), identical(dim(log_sd), c(nrow(y), 2L)))
  loading <- d95_loading_from_free(loading_free, ncol(y)); sd <- exp(log_sd)
  mu <- sweep(mean %*% t(loading), 2L, beta, "+")
  variance <- (sd^2) %*% t(loading^2); xi <- sqrt(mu^2 + variance); omega <- d95_omega(xi)
  bound <- d95_logsigmoid(xi) - xi / 2 + omega * xi^2 + (y - .5) * mu - omega * (mu^2 + variance)
  sum(bound) - .5 * sum(mean^2 + sd^2 - 1 - 2 * log_sd)
}

d95_exact_elbo <- function(y, beta, loading_free, mean, log_sd, order = 61L) {
  j <- seq_len(order - 1L); jacobi <- matrix(0, order, order)
  jacobi[cbind(j, j + 1L)] <- sqrt(j / 2); jacobi[cbind(j + 1L, j)] <- sqrt(j / 2)
  eig <- eigen(jacobi, symmetric = TRUE); z <- sqrt(2) * eig$values; w <- eig$vectors[1, ]^2
  loading <- d95_loading_from_free(loading_free, ncol(y)); sd <- exp(log_sd); total <- 0
  for (i in seq_len(nrow(y))) for (trait in seq_len(ncol(y))) {
    mu <- beta[trait] + sum(loading[trait, ] * mean[i, ])
    variance <- sum(loading[trait, ]^2 * sd[i, ]^2)
    eta <- mu + sqrt(variance) * z
    total <- total + sum(w * (y[i, trait] * eta - d95_log1pexp(eta)))
  }
  total - .5 * sum(mean^2 + sd^2 - 1 - 2 * log_sd)
}

d95_pack <- function(beta, loading_free, mean, log_sd) c(beta, loading_free, as.vector(mean), as.vector(log_sd))
d95_unpack <- function(theta, n, traits) {
  n_loading <- 2L * traits - 1L; a <- traits; b <- a + n_loading; c <- b + 2L * n
  list(beta = theta[seq_len(a)], loading_free = theta[(a + 1L):b],
    mean = matrix(theta[(b + 1L):c], n, 2L), log_sd = matrix(theta[(c + 1L):(c + 2L * n)], n, 2L))
}
d95_central_gradient <- function(fn, theta, step = 1e-6) vapply(seq_along(theta), function(j) {
  up <- down <- theta; up[j] <- up[j] + step; down[j] <- down[j] - step
  (fn(up) - fn(down)) / (2 * step)
}, numeric(1))
