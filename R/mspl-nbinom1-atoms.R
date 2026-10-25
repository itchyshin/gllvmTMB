## Internal nbinom1 LA-MSPL atoms (admit-packet science, not admission).
##
## Rate: c_NB1 = 2 * sqrt(p_free / max(I_NB1, 1)).
## I_NB1 is the data-plugin information size
##   sum_t n_t * I_eta(ybar_t, phi_hat_t),
## the PMF-summed exact eta-information at the trait mean, with
## per-trait method-of-moments phi_hat from (ybar, s^2).
## Not quasi sum mu/(1+phi), not sum mu, not sum y, not c_P, not c=1.
##
## Loading atom: sum_t (sqrt(1 + ||lambda_t||^2 * Ibar_t) - 1).
## All-zero traits contribute 0. Not Bernoulli V_loading. Not Poisson
## ybar-weighted V_lambda^P. Not Hirose. Not the NB2 wbar atom.
##
## Dedicated phi atom: OPEN / not taped. Mean-atom exact I_eta is
## unchanged. Do not export. Do not flip planned.

.gllvmTMB_mspl_nbinom1_phi_poisson_limit <- 1e-8

.gllvmTMB_mspl_nbinom1_trait_moments <- function(y, trait_id) {
  y <- as.numeric(y)
  trait_id <- as.integer(trait_id)
  if (length(y) != length(trait_id)) {
    stop("nbinom1 MSPL moments require y and trait_id of equal length.",
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

.gllvmTMB_mspl_nbinom1_phi_hat <- function(ybar, s2) {
  ybar <- as.numeric(ybar)
  s2 <- as.numeric(s2)
  ratio <- ifelse(is.finite(ybar) & ybar > 0, s2 / ybar, NA_real_)
  ifelse(
    is.finite(ratio) & ratio > 1 + 1e-8,
    ratio - 1,
    .gllvmTMB_mspl_nbinom1_phi_poisson_limit
  )
}

## Tape-matching exact I_eta (C++ gll_mspl_log_weight_glm family_id 15
## truncation: ymax from mu+12*sd, clipped to [8, 80]). Used for the
## data-plugin rate / loading weights so A7 twins can match. Phase-4
## oracles keep the qnbinom-tail version for GLM-outer science.
.gllvmTMB_mspl_nbinom1_exact_I_eta_tape <- function(mu, phi) {
  mu <- as.numeric(mu)[[1L]]
  phi <- as.numeric(phi)[[1L]]
  if (!is.finite(mu) || mu <= 0 || !is.finite(phi) || phi <= 0) {
    return(0)
  }
  r <- mu / phi
  log_p <- -log1p(phi)
  sd <- sqrt(mu * (1 + phi))
  cap <- mu + 12 * sd
  ymax <- 80L
  if (is.finite(cap) && cap < 80) {
    ymax <- if (cap < 8) 8L else as.integer(cap)
  }
  I <- 0
  log_phi <- log(phi)
  for (y in 0:ymax) {
    log_f <- lgamma(y + r) - lgamma(r) - lgamma(y + 1) +
      r * log_p + y * (log_phi + log_p)
    s <- r * (digamma(y + r) - digamma(r) + log_p)
    I <- I + exp(log_f) * s * s
  }
  I
}

.gllvmTMB_mspl_nbinom1_wbar <- function(ybar, phi_hat) {
  ybar <- as.numeric(ybar)
  phi_hat <- as.numeric(phi_hat)
  vapply(
    seq_along(ybar),
    function(i) {
      if (!is.finite(ybar[[i]]) || ybar[[i]] <= 0) {
        return(0)
      }
      .gllvmTMB_mspl_nbinom1_exact_I_eta_tape(ybar[[i]], phi_hat[[i]])
    },
    numeric(1L)
  )
}

.gllvmTMB_mspl_nbinom1_trait_wbar <- function(y, trait_id) {
  mom <- .gllvmTMB_mspl_nbinom1_trait_moments(y, trait_id)
  mom$phi_hat <- .gllvmTMB_mspl_nbinom1_phi_hat(mom$ybar, mom$s2)
  mom$wbar <- .gllvmTMB_mspl_nbinom1_wbar(mom$ybar, mom$phi_hat)
  mom
}

.gllvmTMB_mspl_nbinom1_info_size <- function(y, trait_id) {
  tw <- .gllvmTMB_mspl_nbinom1_trait_wbar(y, trait_id)
  s <- sum(tw$n * tw$wbar)
  if (!is.finite(s) || s < 1) 1 else s
}

.gllvmTMB_mspl_nbinom1_rate <- function(p_free, y, trait_id) {
  p_free <- as.numeric(p_free)
  if (!is.finite(p_free) || p_free <= 0) {
    stop("nbinom1 MSPL rate requires positive p_free.", call. = FALSE)
  }
  2 * sqrt(p_free / .gllvmTMB_mspl_nbinom1_info_size(y, trait_id))
}

.gllvmTMB_mspl_nbinom1_loading_atom <- function(Lambda, wbar) {
  Lambda <- as.matrix(Lambda)
  wbar <- as.numeric(wbar)
  if (length(wbar) != nrow(Lambda)) {
    stop("nbinom1 loading atom requires wbar length n_traits.", call. = FALSE)
  }
  wbar <- pmax(wbar, 0)
  sum(sqrt(1 + rowSums(Lambda * Lambda) * wbar) - 1)
}

.gllvmTMB_mspl_nbinom1_jeffreys <- function(X, mu, phi) {
  X <- as.matrix(X)
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)[[1L]]
  w <- vapply(
    mu,
    function(m) .gllvmTMB_mspl_nbinom1_exact_I_eta_tape(m, phi),
    numeric(1L)
  )
  I <- crossprod(X, X * w)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}
