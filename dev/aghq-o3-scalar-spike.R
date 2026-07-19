#!/usr/bin/env Rscript
## Research-only O3 spike: scalar binomial-logit random-intercept AGHQ plus
## Cox--Reid adjustment.  This is deliberately not package API and does not
## touch TMB.  It establishes the numerical contract before considering the
## gllvmTMB unit-score block (whose scalar d = 1 integral factorises by unit).

.o3_gh <- function(nq) {
  stopifnot(length(nq) == 1L, is.finite(nq), nq >= 1L)
  nq <- as.integer(nq)
  if (nq == 1L) return(list(x = 0, w = sqrt(pi)))
  i <- seq_len(nq - 1L)
  off <- sqrt(i / 2)
  J <- matrix(0, nq, nq)
  J[cbind(i, i + 1L)] <- off
  J[cbind(i + 1L, i)] <- off
  ee <- eigen(J, symmetric = TRUE)
  ord <- order(ee$values)
  list(x = ee$values[ord], w = sqrt(pi) * ee$vectors[1L, ord]^2)
}

.o3_cluster <- function(u, beta, sd, X, z, y) {
  eta <- drop(X %*% beta) + z * u
  p <- plogis(eta)
  list(
    log_density = sum(y * eta - log1p(exp(eta))) + stats::dnorm(u, 0, sd, log = TRUE),
    score = sum(z * (y - p)) - u / sd^2,
    neg_hessian = sum(z^2 * p * (1 - p)) + 1 / sd^2
  )
}

.o3_mode <- function(beta, sd, X, z, y, start = 0) {
  u <- start
  for (iter in seq_len(50L)) {
    d <- .o3_cluster(u, beta, sd, X, z, y)
    if (!is.finite(d$neg_hessian) || d$neg_hessian <= 1e-10) break
    step <- d$score / d$neg_hessian
    u <- u + step
    if (!is.finite(u)) break
    if (abs(step) < 1e-10) return(list(mode = u, tau = 1 / sqrt(d$neg_hessian)))
  }
  obj <- function(x) -.o3_cluster(x, beta, sd, X, z, y)$log_density
  u <- stats::optimize(obj, interval = c(-8 * sd, 8 * sd), tol = 1e-10)$minimum
  d <- .o3_cluster(u, beta, sd, X, z, y)
  if (!is.finite(d$neg_hessian) || d$neg_hessian <= 1e-10) stop("non-positive conditional curvature")
  list(mode = u, tau = 1 / sqrt(d$neg_hessian))
}

.o3_log_marginal <- function(beta, sd, X, z, y, groups, rule, cache = NULL) {
  ids <- split(seq_along(y), groups)
  ans <- 0
  for (j in seq_along(ids)) {
    ii <- ids[[j]]
    start <- if (is.null(cache) || is.null(cache[[j]])) 0 else cache[[j]]
    m <- .o3_mode(beta, sd, X[ii, , drop = FALSE], z[ii], y[ii], start)
    if (!is.null(cache)) cache[[j]] <- m$mode
    u <- m$mode + sqrt(2) * m$tau * rule$x
    a <- vapply(u, function(ui) {
      .o3_cluster(ui, beta, sd, X[ii, , drop = FALSE], z[ii], y[ii])$log_density
    }, numeric(1)) + log(rule$w) + rule$x^2
    mx <- max(a)
    ans <- ans + log(sqrt(2) * m$tau) + mx + log(sum(exp(a - mx)))
  }
  ans
}

o3_aghq_fit <- function(y, X, z, group, nodes = 15L, cox_reid = FALSE,
                        sd_bounds = c(0.03, 4)) {
  stopifnot(is.matrix(X), length(y) == nrow(X), length(z) == length(y),
            all(y %in% c(0, 1)), length(sd_bounds) == 2L, sd_bounds[1] > 0)
  group <- as.integer(as.factor(group))
  rule <- .o3_gh(nodes)
  p <- ncol(X)
  cache <- vector("list", length(unique(group)))
  marginal_nll <- function(beta, log_sd) {
    -.o3_log_marginal(beta, exp(log_sd), X, z, y, group, rule, cache)
  }
  if (!cox_reid) {
    obj <- function(par) marginal_nll(par[seq_len(p)], par[p + 1L])
    fit <- stats::optim(c(rep(0, p), log(0.7)), obj, method = "BFGS",
                        control = list(reltol = 1e-9, maxit = 500L))
    return(list(beta = fit$par[seq_len(p)], sd = exp(fit$par[p + 1L]),
                objective = fit$value, convergence = fit$convergence,
                nodes = nodes, estimator = "aghq_ml"))
  }

  ## Cox--Reid is evaluated in the explicitly fixed beta coordinates of this
  ## scalar model. No latent-loading rotation is present in this reference.
  beta_cache <- rep(0, p)
  restricted <- function(log_sd) {
    prof <- stats::optim(beta_cache, function(beta) marginal_nll(beta, log_sd),
                         method = "BFGS", control = list(reltol = 1e-9, maxit = 500L))
    beta_cache <<- prof$par
    H <- stats::optimHess(prof$par, function(beta) marginal_nll(beta, log_sd))
    ld <- determinant(H, logarithm = TRUE)
    if (ld$sign <= 0 || !is.finite(ld$modulus)) return(Inf)
    prof$value + 0.5 * as.numeric(ld$modulus)
  }
  outer <- stats::optimize(restricted, interval = log(sd_bounds), tol = 1e-7)
  list(beta = beta_cache, sd = exp(outer$minimum), objective = outer$objective,
       convergence = 0L, nodes = nodes, estimator = "aghq_cox_reid",
       log_sd = outer$minimum)
}

.o3_fixture <- function(seed = 20260719L, n_group = 28L, n_per_group = 6L) {
  set.seed(seed)
  group <- rep(seq_len(n_group), each = n_per_group)
  x <- stats::rnorm(length(group))
  u <- stats::rnorm(n_group, 0, 0.8)
  y <- stats::rbinom(length(group), 1L, plogis(-0.3 + 0.7 * x + u[group]))
  list(y = y, X = cbind(`(Intercept)` = 1, x = x), z = rep(1, length(y)), group = group)
}

o3_scalar_self_test <- function() {
  d <- .o3_fixture()
  ladder <- do.call(rbind, lapply(c(1L, 5L, 9L, 15L, 25L), function(nq) {
    fit <- o3_aghq_fit(d$y, d$X, d$z, d$group, nodes = nq)
    data.frame(nodes = nq, sd = fit$sd, objective = fit$objective,
               convergence = fit$convergence)
  }))
  if (any(ladder$convergence != 0L) || any(!is.finite(ladder$sd))) {
    stop("AGHQ ladder did not converge")
  }
  ## Node 15 and 25 are the local numerical-convergence comparison. This is a
  ## gate for the fixed fixture, not a universal convergence-rate claim.
  if (abs(ladder$sd[ladder$nodes == 15L] - ladder$sd[ladder$nodes == 25L]) > 1e-4) {
    stop("AGHQ node ladder has not stabilized by 15 vs 25 nodes")
  }
  cr <- o3_aghq_fit(d$y, d$X, d$z, d$group, nodes = 25L, cox_reid = TRUE)
  if (!is.finite(cr$sd) || cr$convergence != 0L) stop("Cox--Reid O3 fit failed")
  if (requireNamespace("lme4", quietly = TRUE)) {
    gm1 <- lme4::glmer(y ~ x + (1 | group), family = stats::binomial(),
                        data = data.frame(y = d$y, x = d$X[, "x"], group = factor(d$group)),
                        nAGQ = 1L)
    gm <- lme4::glmer(y ~ x + (1 | group), family = stats::binomial(),
                       data = data.frame(y = d$y, x = d$X[, "x"], group = factor(d$group)),
                       nAGQ = 25L)
    ref1 <- as.numeric(attr(lme4::VarCorr(gm1)$group, "stddev"))
    ref <- as.numeric(attr(lme4::VarCorr(gm)$group, "stddev"))
    if (abs(ladder$sd[ladder$nodes == 1L] - ref1) > 1e-3) {
      stop("nq = 1 AGHQ disagrees with glmer(nAGQ = 1) Laplace")
    }
    if (abs(ladder$sd[ladder$nodes == 25L] - ref) > 1e-3) {
      stop("AGHQ ML disagrees with glmer(nAGQ = 25)")
    }
  }
  list(ladder = ladder, cox_reid = cr)
}

## A direct `Rscript dev/aghq-o3-scalar-spike.R` executes the receipt; a
## testthat source only loads the helpers and controls the assertions itself.
if (sys.nframe() == 0L && !interactive()) {
  print(o3_scalar_self_test())
}
