## Internal nbinom2 LA-MSPL atoms (admit-packet science, not admission).
##
## Rate: c_NB2 = 2 * sqrt(p_free / max(I_NB2, 1)).
## I_NB2 is the data-plugin information size
##   sum_t n_t * wbar_t,  wbar_t = ybar_t * phi_hat_t / (phi_hat_t + ybar_t),
## with per-trait method-of-moments phi_hat from (ybar, s^2).
## Not Bernoulli c_n (N_rows), not Gaussian c_N (N_units), not Poisson
## c_P (sum y), and not the placeholder c = 1.
##
## Loading atom: sum_t (sqrt(1 + ||lambda_t||^2 * wbar_t) - 1).
## All-zero traits contribute 0 (Jeffreys-on-beta owns that path).
## Not Bernoulli V_loading. Not Poisson ybar-weighted V_lambda^P. Not Hirose.
##
## Jeffreys-on-phi: DROPPED from the live tape. Mean-atom GLM-outer
## W = mu*phi/(phi+mu) is unchanged. Do not export. Do not flip planned.

.gllvmTMB_mspl_nbinom2_phi_poisson_limit <- 1e8

.gllvmTMB_mspl_nbinom2_trait_moments <- function(y, trait_id) {
  y <- as.numeric(y)
  trait_id <- as.integer(trait_id)
  if (length(y) != length(trait_id)) {
    stop("nbinom2 MSPL moments require y and trait_id of equal length.",
         call. = FALSE)
  }
  traits <- sort(unique(trait_id))
  out <- lapply(traits, function(t) {
    yt <- y[trait_id == t]
    n <- length(yt)
    ybar <- if (n) mean(yt) else 0
    s2 <- if (n >= 2L) stats::var(yt) else 0
    list(trait = t, n = n, ybar = ybar, s2 = s2)
  })
  data.frame(
    trait = vapply(out, `[[`, integer(1L), "trait"),
    n = vapply(out, `[[`, integer(1L), "n"),
    ybar = vapply(out, `[[`, numeric(1L), "ybar"),
    s2 = vapply(out, `[[`, numeric(1L), "s2"),
    stringsAsFactors = FALSE
  )
}

.gllvmTMB_mspl_nbinom2_phi_hat <- function(ybar, s2) {
  ybar <- as.numeric(ybar)
  s2 <- as.numeric(s2)
  excess <- s2 - ybar
  ifelse(
    is.finite(ybar) & ybar > 0 & is.finite(excess) & excess > 1e-8,
    (ybar * ybar) / excess,
    .gllvmTMB_mspl_nbinom2_phi_poisson_limit
  )
}

.gllvmTMB_mspl_nbinom2_wbar <- function(ybar, phi_hat) {
  ybar <- pmax(as.numeric(ybar), 0)
  phi_hat <- as.numeric(phi_hat)
  ifelse(
    ybar > 0 & is.finite(phi_hat) & phi_hat > 0,
    ybar * phi_hat / (phi_hat + ybar),
    0
  )
}

.gllvmTMB_mspl_nbinom2_trait_wbar <- function(y, trait_id) {
  mom <- .gllvmTMB_mspl_nbinom2_trait_moments(y, trait_id)
  mom$phi_hat <- .gllvmTMB_mspl_nbinom2_phi_hat(mom$ybar, mom$s2)
  mom$wbar <- .gllvmTMB_mspl_nbinom2_wbar(mom$ybar, mom$phi_hat)
  mom
}

.gllvmTMB_mspl_nbinom2_info_size <- function(y, trait_id) {
  tw <- .gllvmTMB_mspl_nbinom2_trait_wbar(y, trait_id)
  s <- sum(tw$n * tw$wbar)
  if (!is.finite(s) || s < 1) 1 else s
}

.gllvmTMB_mspl_nbinom2_rate <- function(p_free, y, trait_id) {
  p_free <- as.numeric(p_free)
  if (!is.finite(p_free) || p_free <= 0) {
    stop("nbinom2 MSPL rate requires positive p_free.", call. = FALSE)
  }
  2 * sqrt(p_free / .gllvmTMB_mspl_nbinom2_info_size(y, trait_id))
}

.gllvmTMB_mspl_nbinom2_loading_atom <- function(Lambda, wbar) {
  Lambda <- as.matrix(Lambda)
  wbar <- as.numeric(wbar)
  if (length(wbar) != nrow(Lambda)) {
    stop("nbinom2 loading atom requires wbar length n_traits.", call. = FALSE)
  }
  wbar <- pmax(wbar, 0)
  sum(sqrt(1 + rowSums(Lambda * Lambda) * wbar) - 1)
}

.gllvmTMB_mspl_nbinom2_jeffreys <- function(X, mu, phi) {
  X <- as.matrix(X)
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  if (length(phi) == 1L) {
    phi <- rep(phi, length(mu))
  }
  if (length(phi) != length(mu)) {
    stop("nbinom2 Jeffreys requires phi recycled to mu.", call. = FALSE)
  }
  w <- mu * phi / (phi + mu)
  I <- crossprod(X, X * w)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.gllvmTMB_mspl_nbinom2_I_phi_one <- function(mu, phi, y_max = NULL) {
  mu <- as.numeric(mu)[[1L]]
  phi <- as.numeric(phi)[[1L]]
  if (is.null(y_max)) {
    v <- mu + (mu * mu) / phi
    y_max <- max(80L, as.integer(ceiling(mu + 30 * sqrt(max(v, 1e-12)))))
  }
  y <- 0:y_max
  p <- stats::dnbinom(y, mu = mu, size = phi)
  p_sum <- sum(p)
  if (!is.finite(p_sum) || p_sum <= 0) {
    return(NA_real_)
  }
  p <- p / p_sum
  score <- digamma(y + phi) - digamma(phi) + log(phi / (phi + mu)) +
    (mu - y) / (phi + mu)
  sum(p * score^2) - (sum(p * score))^2
}

.gllvmTMB_mspl_nbinom2_I_phi <- function(mu, phi) {
  mu <- as.numeric(mu)
  vapply(mu, function(m) .gllvmTMB_mspl_nbinom2_I_phi_one(m, phi), numeric(1L))
}

.gllvmTMB_mspl_nbinom2_I_log_phi <- function(mu, phi) {
  phi <- as.numeric(phi)[[1L]]
  phi * phi * sum(.gllvmTMB_mspl_nbinom2_I_phi(mu, phi))
}
