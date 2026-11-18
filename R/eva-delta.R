## Issue #938: per-observation EVA approximation error, Delta_i.
##
## At a fitted EVA solution every observation i has a Gaussian linear predictor
## eta_i ~ N(mu_i, v_i) under the variational q. EVA replaces
## E_q[log p(y_i | eta_i)] by the second-order Taylor surrogate
##
##   log p(y_i | mu_i) + (1/2) * v_i * d2/d eta^2 log p(y_i | eta)|_{mu_i}
##
## and Delta_i is the Gauss--Hermite evaluation of that same expectation minus
## the surrogate. It holds q fixed, so it isolates the Taylor error. Because
## eta_i is univariate Gaussian regardless of the latent dimension, this is one
## 1-D quadrature per observation at a fixed parameter value, outside the
## optimisation loop.
##
## Scope: DIAGNOSTIC ONLY (use 1 of the issue). Selective evaluation (partition
## the observations between the EVA surrogate and GH, held fixed after a pure
## EVA fit) and adaptive H are deliberately not implemented; they are gated on
## this diagnostic showing the error is concentrated in a minority of
## observations (see .eva_delta_summary()). If they are built, call them a
## partition of observations between two evaluators, never "EVA-GH": once GH
## evaluates the expectation the Taylor step is redundant.
##
## This file is separate from the sealed R/eva-proto.R on purpose.

## Full log density, vectorised over an n_obs x H matrix of eta (y and n are
## recycled down the rows). family: 0 Gaussian (known sd), 1 binomial-logit,
## 2 Poisson-log -- the codes of inst/tmb/gllvmTMB_eva.cpp.
.eva_delta_log_density <- function(y, n_trials, eta, family, gaussian_sd) {
  if (family == 0L) {
    stats::dnorm(y, mean = eta, sd = gaussian_sd, log = TRUE)
  } else if (family == 1L) {
    lchoose(n_trials, y) + y * eta - n_trials * .eva_softplus_R(eta)
  } else {
    y * eta - exp(eta) - lgamma(y + 1)
  }
}

## d2/d eta^2 of the log density at eta = mu.
.eva_delta_curvature <- function(n_trials, mu, family, gaussian_sd) {
  if (family == 0L) {
    rep(-1 / gaussian_sd^2, length(mu))
  } else if (family == 1L) {
    p <- stats::plogis(mu)
    -n_trials * p * (1 - p)
  } else {
    -exp(mu)
  }
}

.eva_delta_surrogate <- function(y, n_trials, mu, v, family, gaussian_sd = 1) {
  drop(.eva_delta_log_density(y, n_trials, matrix(mu, ncol = 1L), family, gaussian_sd)) +
    0.5 * v * .eva_delta_curvature(n_trials, mu, family, gaussian_sd)
}

## Delta_i = E_GH[log p(y | eta)] - surrogate, eta ~ N(mu, v). `H` is the
## (odd) Gauss--Hermite order; the default is a reference order, not the
## order a fit would use.
.eva_delta_i <- function(y, n_trials, mu, v, family, gaussian_sd = 1, H = 21L) {
  n <- length(y)
  if (!family %in% c(0L, 1L, 2L)) {
    stop("family must be 0 (Gaussian), 1 (binomial-logit) or 2 (Poisson-log).",
         call. = FALSE)
  }
  if (length(n_trials) != n || length(mu) != n || length(v) != n) {
    stop("y, n_trials, mu and v must have equal length.", call. = FALSE)
  }
  if (any(!is.finite(mu)) || any(!is.finite(v)) || any(v < 0)) {
    stop("mu must be finite and v finite and non-negative.", call. = FALSE)
  }
  rule <- .va_r3_gh_rule(H)
  eta <- mu + sqrt(2 * v) %o% rule$nodes
  ell <- .eva_delta_log_density(y, n_trials, eta, family, gaussian_sd)
  expected <- drop(ell %*% rule$weights) / sqrt(pi)
  unname(expected - .eva_delta_surrogate(y, n_trials, mu, v, family, gaussian_sd))
}

## Distribution of Delta_i: tails, which observation dominates, and how
## concentrated the absolute error is. `top_decile_share` is the share of
## sum(|Delta_i|) carried by the worst 10% of observations and `n_for_half` the
## fewest observations carrying half of it; a share near 0.1 (diffuse error)
## means selective evaluation would buy nothing.
.eva_delta_summary <- function(delta, probs = c(0.5, 0.9, 0.95, 0.99, 1)) {
  if (!is.numeric(delta) || length(delta) < 1L || any(!is.finite(delta))) {
    stop("delta must be a non-empty finite numeric vector.", call. = FALSE)
  }
  a <- abs(delta)
  total_abs <- sum(a)
  ord <- order(a, decreasing = TRUE)
  k10 <- ceiling(0.1 * length(a))
  cum <- cumsum(a[ord])
  list(
    n = length(delta),
    total = sum(delta),
    max_abs = max(a),
    which_max = which.max(a),
    quantiles = stats::quantile(a, probs = probs, names = TRUE),
    top_decile_share = if (total_abs > 0) sum(a[ord][seq_len(k10)]) / total_abs else NA_real_,
    n_for_half = if (total_abs > 0) {
      as.integer(which(cum >= 0.5 * total_abs * (1 - 1e-12))[1L])
    } else NA_integer_
  )
}

## Delta_i at the solution returned by .eva_fit(). Uses the fitted mu and v
## the C++ template already reports, and the data held by its objective.
.eva_delta_from_fit <- function(fit, H = 21L) {
  rep <- fit$report
  if (is.null(rep) || is.null(rep$mu_by_obs) || is.null(rep$v_by_obs)) {
    stop("fit has no usable report (mu_by_obs / v_by_obs); the EVA fit did not return one.",
         call. = FALSE)
  }
  if (!identical(fit$status, "healthy")) {
    warning("The EVA fit is not healthy (status '", fit$status,
            "'); Delta_i describes a point that is not a verified optimum.",
            call. = FALSE)
  }
  d <- fit$objective$env$data
  mu <- as.numeric(rep$mu_by_obs)
  v <- as.numeric(rep$v_by_obs)
  delta <- .eva_delta_i(d$y, d$n_trials, mu, v, family = as.integer(d$family),
                        gaussian_sd = d$gaussian_sd, H = H)
  data <- data.frame(
    obs = seq_along(delta),
    unit_id = as.integer(d$unit_id),
    trait_id = as.integer(d$trait_id),
    mu = mu,
    v = v,
    surrogate = .eva_delta_surrogate(d$y, d$n_trials, mu, v, as.integer(d$family),
                                     d$gaussian_sd),
    delta = delta
  )
  list(data = data, summary = .eva_delta_summary(delta), H = as.integer(H))
}
