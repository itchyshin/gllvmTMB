d94_log1pexp <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))
d94_logsigmoid <- function(x) -d94_log1pexp(-x)
d94_omega <- function(xi) tanh(xi / 2) / (4 * xi)

d94_jj_elbo <- function(y, intercept, loading, mean, log_sd) {
  stopifnot(is.matrix(y), all(y %in% c(0, 1)), is.matrix(loading), ncol(loading) == 2L,
            identical(dim(mean), c(nrow(y), 2L)), identical(dim(log_sd), c(nrow(y), 2L)))
  sd <- exp(log_sd)
  mu <- sweep(mean %*% t(loading), 2L, intercept, "+")
  variance <- (sd^2) %*% t(loading^2)
  xi <- sqrt(mu^2 + variance + 1e-12)
  constant <- d94_logsigmoid(xi) - xi / 2 + d94_omega(xi) * xi^2
  bound <- constant + (y - 0.5) * mu - d94_omega(xi) * (mu^2 + variance)
  kl <- 0.5 * sum(mean^2 + sd^2 - 1 - 2 * log_sd)
  sum(bound) - kl
}

d94_exact_elbo <- function(y, intercept, loading, mean, log_sd, order = 61L) {
  j <- seq_len(order - 1L); jacobi <- matrix(0, order, order)
  jacobi[cbind(j, j + 1L)] <- sqrt(j / 2); jacobi[cbind(j + 1L, j)] <- sqrt(j / 2)
  eigen_result <- eigen(jacobi, symmetric = TRUE); z <- sqrt(2) * eigen_result$values; w <- eigen_result$vectors[1, ]^2
  sd <- exp(log_sd); total <- 0
  for (i in seq_len(nrow(y))) for (trait in seq_len(ncol(y))) {
    mu <- intercept[trait] + sum(loading[trait, ] * mean[i, ])
    variance <- sum(loading[trait, ]^2 * sd[i, ]^2)
    eta <- mu + sqrt(variance) * z
    total <- total + sum(w * (y[i, trait] * eta - d94_log1pexp(eta)))
  }
  total - 0.5 * sum(mean^2 + sd^2 - 1 - 2 * log_sd)
}

d94_central_gradient <- function(fn, theta, step = 1e-6) vapply(seq_along(theta), function(j) {
  plus <- minus <- theta; plus[j] <- plus[j] + step; minus[j] <- minus[j] - step
  (fn(plus) - fn(minus)) / (2 * step)
}, numeric(1))
