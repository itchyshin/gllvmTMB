## Independent scalar arithmetic oracles for Design 110.
##
## Symbolic alignment (one response cell):
##
## | Symbol | Implementation object | DGP input | Recovery target | Truth |
## | eta ~ N(mu,v) | .va_oracle_normal_expectation | mu, v | scalar Q | E log p(y|eta) |
## | log p(y|eta) | .va_oracle_log_density | y, n, family parameters | conditional log density | Laplace dispatch at eta |
## | Q^(H) | .va_oracle_gh_expectation | independent GH rule | quadrature value | H-node normal expectation |
## | Q exact | .va_oracle_exact_expectation | closed-form cells | analytic value | Design 110 formula |
## | Q adaptive | .va_oracle_adaptive_expectation | stats::integrate | arithmetic reference | direct scalar integral |
##
## These helpers deliberately do not call .va_r3_gh_rule(), the TMB template, or
## gllvm. They test the scalar mathematics without sharing the implementation
## under test. A later integration test may pass the same fixtures through TMB.

.va_oracle_softplus <- function(x) {
  pmax(x, 0) + log1p(exp(-abs(x)))
}

.va_oracle_or <- function(x, fallback) {
  if (is.null(x)) fallback else x
}

.va_oracle_log1mexp <- function(a) {
  stopifnot(all(a <= 0))
  ifelse(a < -log(2), log1p(-exp(a)), log(-expm1(a)))
}

.va_oracle_log_pnorm_diff <- function(upper, lower) {
  if (is.infinite(upper) && upper > 0) return(pnorm(-lower, log.p = TRUE))
  if (is.infinite(lower) && lower < 0) return(pnorm(upper, log.p = TRUE))
  lu <- pnorm(upper, log.p = TRUE)
  ll <- pnorm(lower, log.p = TRUE)
  lu + .va_oracle_log1mexp(ll - lu)
}

## Independent compound-Poisson/Gamma series for the positive Tweedie density.
## The package oracle `tweedie::dtweedie()` returns the density, not its log,
## and therefore underflows for the adversarial right-tail fixture that caught
## the former eta clamp. This series stays on the log scale. Gate E uses p=1.5,
## where 200 terms are far beyond the numerically relevant range; the explicit
## tail check makes the truncation auditable rather than assumed.
.va_oracle_tweedie_log_density_series <- function(y, eta, phi, power,
                                                   n_terms = 200L) {
  stopifnot(length(y) == 1L, y > 0, phi > 0, power > 1, power < 2)
  mu <- exp(eta)
  lambda <- mu^(2 - power) / (phi * (2 - power))
  alpha <- (2 - power) / (power - 1)
  gamma_scale <- phi * (power - 1) * mu^(power - 1)
  j <- seq_len(as.integer(n_terms))
  log_terms <- j * log(lambda) + j * alpha * log(y) -
    lgamma(j + 1) - lgamma(j * alpha) -
    j * alpha * log(gamma_scale)
  peak <- max(log_terms)
  if (log_terms[[length(log_terms)]] > peak - 100) {
    stop("Tweedie series truncation is not negligible for this fixture.",
         call. = FALSE)
  }
  -lambda - y / gamma_scale - log(y) +
    peak + log(sum(exp(log_terms - peak)))
}

.va_oracle_gh_rule <- function(H) {
  H <- as.integer(H)
  stopifnot(length(H) == 1L, H >= 3L, H %% 2L == 1L)
  J <- matrix(0, H, H)
  off <- sqrt(seq_len(H - 1L) / 2)
  J[cbind(seq_len(H - 1L), 2:H)] <- off
  J[cbind(2:H, seq_len(H - 1L))] <- off
  ee <- eigen(J, symmetric = TRUE)
  ord <- order(ee$values)
  nodes <- unname(ee$values[ord])

  ## Physicists' Hermite weight formula. Unlike eigenvector-squared weights,
  ## this retains the tiny but nonzero extreme weights at H = 61.
  hm2 <- rep(1, H)
  hm1 <- 2 * nodes
  if (H > 2L) {
    for (k in 2:(H - 1L)) {
      hk <- 2 * nodes * hm1 - 2 * (k - 1) * hm2
      hm2 <- hm1
      hm1 <- hk
    }
  }
  weights <- 2^(H - 1L) * gamma(H + 1) * sqrt(pi) / (H^2 * hm1^2)
  weights <- weights * sqrt(pi) / sum(weights)
  list(nodes = nodes, weights = weights)
}

.va_oracle_log_density <- function(cell, eta) {
  y <- cell$y
  n <- .va_oracle_or(cell$n, 1)
  p <- .va_oracle_or(cell$par, list())
  fid <- cell$family_id
  link <- cell$link

  if (fid == 0L) {
    return(dnorm(y, eta, p$sigma, log = TRUE))
  }
  if (fid == 1L) {
    base <- lchoose(n, y)
    if (link == "logit")
      return(base + y * eta - n * .va_oracle_softplus(eta))
    if (link == "probit")
      return(base + y * pnorm(eta, log.p = TRUE) +
               (n - y) * pnorm(-eta, log.p = TRUE))
    if (link == "cloglog")
      return(base + y * .va_oracle_log1mexp(-exp(eta)) -
               (n - y) * exp(eta))
  }
  if (fid == 2L) {
    return(dpois(y, exp(eta), log = TRUE))
  }
  if (fid == 3L) {
    return(dnorm(log(y), eta, p$sigma, log = TRUE) - log(y))
  }
  if (fid == 4L) {
    return(dgamma(y, shape = p$shape, scale = exp(eta) / p$shape,
                  log = TRUE))
  }
  if (fid == 5L) {
    return(dnbinom(y, size = p$phi, mu = exp(eta), log = TRUE))
  }
  if (fid == 6L) {
    return(log(tweedie::dtweedie(y, mu = exp(eta), phi = p$phi,
                                 power = p$power)))
  }
  if (fid == 7L) {
    log_mean <- -.va_oracle_softplus(-eta)
    log_one_minus_mean <- -.va_oracle_softplus(eta)
    return(dbeta(y, shape1 = exp(log_mean) * p$phi,
                 shape2 = exp(log_one_minus_mean) * p$phi, log = TRUE))
  }
  if (fid == 8L) {
    a <- exp(-.va_oracle_softplus(-eta)) * p$phi
    b <- exp(-.va_oracle_softplus(eta)) * p$phi
    return(lchoose(n, y) + lbeta(y + a, n - y + b) - lbeta(a, b))
  }
  if (fid == 9L) {
    return(dt((y - eta) / p$sigma, df = p$df, log = TRUE) - log(p$sigma))
  }
  if (fid == 10L) {
    lambda <- exp(eta)
    return(dpois(y, lambda, log = TRUE) - .va_oracle_log1mexp(-lambda))
  }
  if (fid == 11L) {
    mean <- exp(eta)
    log_p0 <- dnbinom(0, size = p$phi, mu = mean, log = TRUE)
    return(dnbinom(y, size = p$phi, mu = mean, log = TRUE) -
             .va_oracle_log1mexp(log_p0))
  }
  if (fid == 12L) {
    present <- as.numeric(y > 0)
    out <- present * eta - .va_oracle_softplus(eta)
    if (present) out <- out + dnorm(log(y), eta, p$sigma, log = TRUE) - log(y)
    return(out)
  }
  if (fid == 13L) {
    present <- as.numeric(y > 0)
    out <- present * eta - .va_oracle_softplus(eta)
    if (present) {
      shape <- 1 / p$phi^2
      out <- out + dgamma(y, shape = shape, scale = exp(eta) / shape,
                         log = TRUE)
    }
    return(out)
  }
  if (fid == 14L) {
    K <- length(p$cuts) + 1L
    lower <- if (y <= 1) -Inf else p$cuts[[y - 1L]] - eta
    upper <- if (y >= K) Inf else p$cuts[[y]] - eta
    return(.va_oracle_log_pnorm_diff(upper, lower))
  }
  if (fid == 15L) {
    mean <- exp(eta)
    size <- mean / p$phi
    ## Stable NB1 log PMF. `lgamma(y + size) - lgamma(size)` loses nearly all
    ## precision when eta is large, while y is an integer count and the same
    ## ratio is exactly prod_{k=0}^{y-1}(size + k).
    log_coefficient <- if (y == 0) 0 else
      sum(log(size + 0:(as.integer(y) - 1L))) - lgamma(y + 1)
    log_prob <- -log1p(p$phi)
    log_one_minus_prob <- log(p$phi) - log1p(p$phi)
    return(log_coefficient + size * log_prob + y * log_one_minus_prob)
  }
  stop("unknown scalar family/link fixture", call. = FALSE)
}

.va_oracle_gh_expectation <- function(cell, mu = cell$mu, v = cell$v, H = 7L) {
  rule <- .va_oracle_gh_rule(H)
  eta <- mu + sqrt(2 * v) * rule$nodes
  values <- vapply(eta, function(z) .va_oracle_log_density(cell, z), numeric(1))
  sum(rule$weights * values) / sqrt(pi)
}

.va_oracle_adaptive_expectation <- function(cell, mu = cell$mu, v = cell$v,
                                            rel.tol = 2e-11) {
  if (v == 0) return(.va_oracle_log_density(cell, mu))
  f <- function(z) {
    vapply(z, function(zz) .va_oracle_log_density(cell, mu + sqrt(v) * zz),
           numeric(1)) * dnorm(z)
  }
  ## Twelve standard deviations leave less than 4e-33 normal mass outside the
  ## interval and avoid Inf * 0 indeterminacies in exponentially growing tail
  ## kernels such as cloglog.
  integrate(f, -12, 12, rel.tol = rel.tol, abs.tol = 1e-13,
            subdivisions = 1000L, stop.on.error = TRUE)$value
}

.va_oracle_exact_expectation <- function(cell, mu = cell$mu, v = cell$v,
                                         H = 7L) {
  y <- cell$y
  p <- .va_oracle_or(cell$par, list())
  if (cell$family_id == 0L) {
    return(-log(p$sigma) - 0.5 * log(2 * pi) -
             ((y - mu)^2 + v) / (2 * p$sigma^2))
  }
  if (cell$family_id == 2L) {
    return(y * mu - exp(mu + v / 2) - lgamma(y + 1))
  }
  if (cell$family_id == 3L) {
    return(-log(p$sigma) - 0.5 * log(2 * pi) - log(y) -
             ((log(y) - mu)^2 + v) / (2 * p$sigma^2))
  }
  if (cell$family_id == 4L) {
    a <- p$shape
    return(a * log(a) - lgamma(a) + (a - 1) * log(y) - a * mu -
             a * y * exp(-mu + v / 2))
  }
  if (cell$family_id == 12L) {
    occurrence_cell <- list(family_id = 1L, link = "logit", y = 1, n = 1)
    occurrence <- .va_oracle_gh_expectation(occurrence_cell, mu, v, H)
    positive <- -log(p$sigma) - 0.5 * log(2 * pi) - log(y) -
      ((log(y) - mu)^2 + v) / (2 * p$sigma^2)
    return(occurrence + positive)
  }
  if (cell$family_id == 13L) {
    shape <- 1 / p$phi^2
    positive <- shape * log(shape) - lgamma(shape) +
      (shape - 1) * log(y) - shape * mu -
      shape * y * exp(-mu + v / 2)
    occurrence_cell <- list(family_id = 1L, link = "logit", y = 1, n = 1)
    occurrence <- .va_oracle_gh_expectation(occurrence_cell, mu, v, H)
    return(occurrence + positive)
  }
  stop("cell has no exact or hybrid expectation", call. = FALSE)
}

.va_oracle_cells <- list(
  gaussian_identity = list(family_id = 0L, link = "identity", y = 0.4,
    mu = 0.2, v = 0.12, par = list(sigma = 0.8), route = "exact"),
  binomial_logit = list(family_id = 1L, link = "logit", y = 2, n = 5,
    mu = -0.3, v = 0.12, route = "gh"),
  binomial_probit = list(family_id = 1L, link = "probit", y = 2, n = 5,
    mu = -0.3, v = 0.12, route = "gh"),
  binomial_cloglog = list(family_id = 1L, link = "cloglog", y = 2, n = 5,
    mu = -0.3, v = 0.12, route = "gh"),
  poisson_log = list(family_id = 2L, link = "log", y = 3,
    mu = 0.5, v = 0.12, route = "exact"),
  lognormal_log = list(family_id = 3L, link = "log", y = 1.3,
    mu = 0.2, v = 0.12, par = list(sigma = 0.65), route = "exact"),
  gamma_log = list(family_id = 4L, link = "log", y = 1.4,
    mu = 0.25, v = 0.12, par = list(shape = 2.3), route = "exact"),
  nbinom2_log = list(family_id = 5L, link = "log", y = 3,
    mu = 0.4, v = 0.12, par = list(phi = 2.2), route = "gh"),
  tweedie_log = list(family_id = 6L, link = "log", y = 1.2,
    mu = 0.1, v = 0.06, par = list(phi = 0.8, power = 1.5), route = "gh"),
  beta_logit = list(family_id = 7L, link = "logit", y = 0.37,
    mu = -0.2, v = 0.06, par = list(phi = 7), route = "gh"),
  betabinomial_logit = list(family_id = 8L, link = "logit", y = 3, n = 8,
    mu = -0.2, v = 0.08, par = list(phi = 6), route = "gh"),
  student_identity = list(family_id = 9L, link = "identity", y = 0.8,
    mu = 0.1, v = 0.06, par = list(sigma = 0.9, df = 5), route = "gh"),
  truncated_poisson_log = list(family_id = 10L, link = "log", y = 2,
    mu = 0.3, v = 0.08, route = "gh"),
  truncated_nbinom2_log = list(family_id = 11L, link = "log", y = 2,
    mu = 0.3, v = 0.08, par = list(phi = 2.4), route = "gh"),
  delta_lognormal_log = list(family_id = 12L, link = "log", y = 1.3,
    mu = 0.15, v = 0.08, par = list(sigma = 0.7), route = "hybrid"),
  delta_gamma_log = list(family_id = 13L, link = "log", y = 1.4,
    mu = 0.15, v = 0.08, par = list(phi = 0.7), route = "hybrid"),
  ordinal_probit = list(family_id = 14L, link = "probit", y = 2,
    mu = 0.25, v = 0.06, par = list(cuts = c(0, 1.1)), route = "gh"),
  nbinom1_log = list(family_id = 15L, link = "log", y = 3,
    mu = 0.4, v = 0.06, par = list(phi = 0.7), route = "gh")
)

## Predeclared tolerances are cell-specific because the nodewise curvature is
## not: Tweedie series evaluation, beta tail divergence, narrow ordinal cells,
## and NB1's eta-dependent shape are numerically harder than softplus cells.
.va_oracle_ordinary_tolerance <- c(
  binomial_logit = 1e-6, binomial_probit = 1e-6,
  binomial_cloglog = 1e-6, nbinom2_log = 1e-6,
  tweedie_log = 1e-6, beta_logit = 1e-6, betabinomial_logit = 1e-6,
  student_identity = 1e-6, truncated_poisson_log = 1e-6,
  truncated_nbinom2_log = 1e-6, delta_lognormal_log = 1e-6,
  delta_gamma_log = 1e-6, ordinal_probit = 1e-6, nbinom1_log = 1e-6
)

.va_oracle_tail_tolerance <- c(
  binomial_logit = 2e-6, binomial_probit = 2e-6,
  binomial_cloglog = 2e-5, nbinom2_log = 2e-6,
  tweedie_log = 1e-4, beta_logit = 2e-5, betabinomial_logit = 2e-5,
  student_identity = 5e-5, truncated_poisson_log = 2e-5,
  truncated_nbinom2_log = 2e-5, delta_lognormal_log = 2e-6,
  delta_gamma_log = 2e-6, ordinal_probit = 1e-4, nbinom1_log = 5e-5
)

## Interface assumption for the later compiled bridge. This is data, not a
## dependency: pure-R tests remain runnable while the adapter is changing.
.va_oracle_bridge_contract <- list(
  family_ids = 0:15,
  binomial_link_ids = c(logit = 0L, probit = 1L, cloglog = 2L),
  quadrature_order = 7L,
  excluded_family_ids = 16L
)
