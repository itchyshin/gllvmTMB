## Internal Poisson LA-MSPL atoms (admit-packet science, not admission).
##
## Rate: c_P = 2 * sqrt(p_free / max(sum(y), 1)). Event count is the
## information-size proxy. Not Bernoulli c_n (N_rows) and not Gaussian
## c_N (N_units). Not the unpinned placeholder c = 1.
##
## Loading atom: sum_t (sqrt(1 + ||lambda_t||^2 * ybar_t) - 1).
## All-zero traits contribute 0 (Jeffreys-on-beta owns that path).
## Not Bernoulli V_loading. Not Hirose.
##
## Jeffreys: (1/2) log det(X^T diag(mu) X), GLM-outer W = diag(mu).
## Do not export. Do not flip planned -> admitted from these helpers.

.gllvmTMB_mspl_poisson_event_count <- function(y) {
  s <- sum(as.numeric(y))
  if (!is.finite(s) || s < 1) 1 else s
}

.gllvmTMB_mspl_poisson_rate <- function(p_free, event_count) {
  p_free <- as.numeric(p_free)
  event_count <- as.numeric(event_count)
  if (!is.finite(p_free) || p_free <= 0) {
    stop("Poisson MSPL rate requires positive p_free.", call. = FALSE)
  }
  if (!is.finite(event_count) || event_count < 1) {
    event_count <- 1
  }
  2 * sqrt(p_free / event_count)
}

.gllvmTMB_mspl_poisson_loading_atom <- function(Lambda, ybar) {
  Lambda <- as.matrix(Lambda)
  ybar <- as.numeric(ybar)
  if (length(ybar) != nrow(Lambda)) {
    stop("Poisson loading atom requires ybar length n_traits.", call. = FALSE)
  }
  ybar <- pmax(ybar, 0)
  sum(sqrt(1 + rowSums(Lambda * Lambda) * ybar) - 1)
}

.gllvmTMB_mspl_poisson_jeffreys <- function(X, mu) {
  X <- as.matrix(X)
  w <- as.numeric(mu)
  I <- crossprod(X, X * w)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}
