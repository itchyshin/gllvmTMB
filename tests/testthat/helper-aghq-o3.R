## Canonical numerical helpers for the research-only O3 scripts.  This lives
## under tests/ so it is available in the installed-package test tree; dev/
## is intentionally excluded from R CMD build.

.o3_gh <- function(nq) {
  stopifnot(length(nq) == 1L, is.finite(nq), nq >= 1L)
  nq <- as.integer(nq)
  if (nq == 1L) return(list(x = 0, w = sqrt(pi)))
  i <- seq_len(nq - 1L); J <- matrix(0, nq, nq)
  J[cbind(i, i + 1L)] <- J[cbind(i + 1L, i)] <- sqrt(i / 2)
  ee <- eigen(J, symmetric = TRUE); ord <- order(ee$values)
  list(x = ee$values[ord], w = sqrt(pi) * ee$vectors[1L, ord]^2)
}

.o3_cluster <- function(u, beta, sd, X, z, y) {
  eta <- drop(X %*% beta) + z * u; p <- plogis(eta)
  list(log_density = sum(y * eta - log1p(exp(eta))) + dnorm(u, 0, sd, log = TRUE),
       score = sum(z * (y - p)) - u / sd^2,
       neg_hessian = sum(z^2 * p * (1 - p)) + 1 / sd^2)
}

.o3_mode <- function(beta, sd, X, z, y, start = 0) {
  u <- start
  for (iter in seq_len(50L)) {
    d <- .o3_cluster(u, beta, sd, X, z, y)
    if (!is.finite(d$neg_hessian) || d$neg_hessian <= 1e-10) break
    step <- d$score / d$neg_hessian; u <- u + step
    if (!is.finite(u)) break
    if (abs(step) < 1e-10) return(list(mode = u, tau = 1 / sqrt(d$neg_hessian)))
  }
  obj <- function(x) -.o3_cluster(x, beta, sd, X, z, y)$log_density
  u <- optimize(obj, c(-8 * sd, 8 * sd), tol = 1e-10)$minimum
  d <- .o3_cluster(u, beta, sd, X, z, y)
  if (!is.finite(d$neg_hessian) || d$neg_hessian <= 1e-10) stop("non-positive conditional curvature")
  list(mode = u, tau = 1 / sqrt(d$neg_hessian))
}

.o3_log_marginal <- function(beta, sd, X, z, y, groups, rule, cache = NULL) {
  ids <- split(seq_along(y), groups); ans <- 0
  for (j in seq_along(ids)) {
    ii <- ids[[j]]; start <- if (is.null(cache) || is.null(cache[[j]])) 0 else cache[[j]]
    m <- .o3_mode(beta, sd, X[ii, , drop = FALSE], z[ii], y[ii], start)
    if (!is.null(cache)) cache[[j]] <- m$mode
    u <- m$mode + sqrt(2) * m$tau * rule$x
    a <- vapply(u, function(ui) .o3_cluster(ui, beta, sd, X[ii, , drop = FALSE], z[ii], y[ii])$log_density, numeric(1)) + log(rule$w) + rule$x^2
    mx <- max(a); ans <- ans + log(sqrt(2) * m$tau) + mx + log(sum(exp(a - mx)))
  }
  ans
}

o3_aghq_fit <- function(y, X, z, group, nodes = 15L, cox_reid = FALSE, sd_bounds = c(0.03, 4)) {
  stopifnot(is.matrix(X), length(y) == nrow(X), length(z) == length(y), all(y %in% c(0, 1)), length(sd_bounds) == 2L, sd_bounds[1] > 0)
  group <- as.integer(as.factor(group)); rule <- .o3_gh(nodes); p <- ncol(X); cache <- vector("list", length(unique(group)))
  nll <- function(beta, log_sd) -.o3_log_marginal(beta, exp(log_sd), X, z, y, group, rule, cache)
  if (!cox_reid) {
    fit <- optim(c(rep(0, p), log(0.7)), function(par) nll(par[seq_len(p)], par[p + 1L]), method = "BFGS", control = list(reltol = 1e-9, maxit = 500L))
    return(list(beta = fit$par[seq_len(p)], sd = exp(fit$par[p + 1L]), objective = fit$value, convergence = fit$convergence, nodes = nodes, estimator = "aghq_ml"))
  }
  beta_cache <- rep(0, p)
  restricted <- function(log_sd) {
    prof <- optim(beta_cache, function(beta) nll(beta, log_sd), method = "BFGS", control = list(reltol = 1e-9, maxit = 500L)); beta_cache <<- prof$par
    ld <- determinant(optimHess(prof$par, function(beta) nll(beta, log_sd)), logarithm = TRUE)
    if (ld$sign <= 0 || !is.finite(ld$modulus)) return(Inf)
    prof$value + 0.5 * as.numeric(ld$modulus)
  }
  outer <- optimize(restricted, log(sd_bounds), tol = 1e-7)
  list(beta = beta_cache, sd = exp(outer$minimum), objective = outer$objective, convergence = 0L, nodes = nodes, estimator = "aghq_cox_reid", log_sd = outer$minimum)
}

.o3_fixture <- function(seed = 20260719L, n_group = 28L, n_per_group = 6L) {
  set.seed(seed); group <- rep(seq_len(n_group), each = n_per_group); x <- rnorm(length(group)); u <- rnorm(n_group, 0, 0.8)
  y <- rbinom(length(group), 1L, plogis(-0.3 + 0.7 * x + u[group]))
  list(y = y, X = cbind(`(Intercept)` = 1, x = x), z = rep(1, length(y)), group = group)
}

o3_scalar_self_test <- function() {
  d <- .o3_fixture(); ladder <- do.call(rbind, lapply(c(1L, 5L, 9L, 15L, 25L), function(nq) {
    fit <- o3_aghq_fit(d$y, d$X, d$z, d$group, nodes = nq); data.frame(nodes = nq, sd = fit$sd, objective = fit$objective, convergence = fit$convergence)
  }))
  if (any(ladder$convergence != 0L) || any(!is.finite(ladder$sd))) stop("AGHQ ladder did not converge")
  if (abs(ladder$sd[ladder$nodes == 15L] - ladder$sd[ladder$nodes == 25L]) > 1e-4) stop("AGHQ node ladder has not stabilized by 15 vs 25 nodes")
  cr <- o3_aghq_fit(d$y, d$X, d$z, d$group, nodes = 25L, cox_reid = TRUE)
  if (!is.finite(cr$sd) || cr$convergence != 0L) stop("Cox--Reid O3 fit failed")
  if (requireNamespace("lme4", quietly = TRUE)) {
    dd <- data.frame(y = d$y, x = d$X[, "x"], group = factor(d$group))
    gm1 <- lme4::glmer(y ~ x + (1 | group), family = binomial(), data = dd, nAGQ = 1L)
    gm <- lme4::glmer(y ~ x + (1 | group), family = binomial(), data = dd, nAGQ = 25L)
    ref1 <- as.numeric(attr(lme4::VarCorr(gm1)$group, "stddev")); ref <- as.numeric(attr(lme4::VarCorr(gm)$group, "stddev"))
    if (abs(ladder$sd[ladder$nodes == 1L] - ref1) > 1e-3) stop("nq = 1 AGHQ disagrees with glmer(nAGQ = 1) Laplace")
    if (abs(ladder$sd[ladder$nodes == 25L] - ref) > 1e-3) stop("AGHQ ML disagrees with glmer(nAGQ = 25)")
  }
  list(ladder = ladder, cox_reid = cr)
}

.o3_hook_mode <- function(y, n_trials, eta_fixed, loading) {
  ld <- function(u) sum(dbinom(y, n_trials, plogis(eta_fixed + loading * u), log = TRUE)) + dnorm(u, 0, 1, log = TRUE)
  mode <- optimize(function(u) -ld(u), c(-10, 10), tol = 1e-12)$minimum; p <- plogis(eta_fixed + loading * mode)
  list(mode = mode, tau = 1 / sqrt(sum(loading^2 * n_trials * p * (1 - p)) + 1), log_density = ld)
}

.o3_hook_log_integral <- function(y, n_trials, eta_fixed, loading, nodes) {
  rule <- .o3_gh(nodes); m <- .o3_hook_mode(y, n_trials, eta_fixed, loading)
  u <- m$mode + sqrt(2) * m$tau * rule$x; a <- vapply(u, m$log_density, numeric(1)) + log(rule$w) + rule$x^2; mx <- max(a)
  log(sqrt(2) * m$tau) + mx + log(sum(exp(a - mx)))
}

.o3_hook_extract <- function(fit) {
  d <- fit$tmb_obj$env$data
  if (!inherits(fit, "gllvmTMB_multi") || !isTRUE(fit$use$rr_B) || fit$d_B != 1L || isTRUE(fit$use$diag_B) || !identical(as.integer(d$family_id_vec), rep.int(1L, length(d$y)))) stop("requires a binomial, ordinary latent(..., d = 1, unique = FALSE) gllvmTMB fit")
  par <- fit$tmb_obj$env$last.par.best; beta <- par[names(par) == "b_fix"]
  if (length(beta) != ncol(d$X_fix)) stop("b_fix extraction mismatch")
  list(y = d$y, n_trials = d$n_trials, eta_fixed = drop(d$X_fix %*% beta), loading = fit$report$Lambda_B[d$trait_id + 1L, 1L], unit = d$site_id + 1L, tmb_objective = fit$opt$objective)
}

o3_gllvm_unit_ladder <- function(fit, nodes = c(1L, 5L, 9L, 15L, 25L)) {
  x <- .o3_hook_extract(fit); ids <- split(seq_along(x$y), x$unit)
  data.frame(nodes = nodes, objective = vapply(nodes, function(nq) -sum(vapply(ids, function(ii) .o3_hook_log_integral(x$y[ii], x$n_trials[ii], x$eta_fixed[ii], x$loading[ii], nq), numeric(1))), numeric(1)))
}

.o3_hook_fixture <- function(seed = 20260719L, n_unit = 16L, n_rep = 3L, n_trials = 12L) {
  set.seed(seed); u <- rnorm(n_unit, 0, 0.7); dat <- expand.grid(rep = seq_len(n_rep), trait = factor(c("t1", "t2")), unit = factor(sprintf("u%02d", seq_len(n_unit))))
  dat <- dat[order(dat$unit, dat$trait, dat$rep), , drop = FALSE]; beta <- c(-0.2, 0.35); lambda <- c(0.8, -0.5)
  p <- plogis(beta[as.integer(dat$trait)] + lambda[as.integer(dat$trait)] * u[as.integer(dat$unit)]); dat$succ <- rbinom(nrow(dat), n_trials, p); dat$fail <- n_trials - dat$succ; dat
}

o3_gllvm_unit_hook_self_test <- function() {
  dat <- .o3_hook_fixture(); fit <- suppressWarnings(gllvmTMB::gllvmTMB(cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE), data = dat, family = binomial(), unit = "unit"))
  if (fit$opt$convergence != 0L || !isTRUE(fit$fit_health$pd_hessian)) stop("deterministic gllvmTMB hook fixture is not healthy")
  ladder <- o3_gllvm_unit_ladder(fit); one <- ladder$objective[ladder$nodes == 1L]
  if (abs(one - fit$opt$objective) > 1e-6) stop("reconstructed scalar Laplace objective disagrees with joint TMB Laplace")
  if (abs(ladder$objective[ladder$nodes == 15L] - ladder$objective[ladder$nodes == 25L]) > 1e-4) stop("scalar gllvmTMB AGHQ node ladder has not stabilized by 15 vs 25")
  list(tmb_objective = fit$opt$objective, ladder = ladder, laplace_difference = one - fit$opt$objective)
}

.o3_q2_mode <- function(y, n_trials, eta_fixed, loading) {
  ld <- function(u) sum(dbinom(y, n_trials, plogis(eta_fixed + drop(loading %*% u)), log = TRUE)) + sum(dnorm(u, 0, 1, log = TRUE))
  opt <- optim(c(0, 0), function(u) -ld(u), method = "BFGS", control = list(reltol = 1e-11, maxit = 200L)); if (opt$convergence != 0L) stop("q = 2 conditional mode did not converge")
  p <- plogis(eta_fixed + drop(loading %*% opt$par)); h <- crossprod(loading * sqrt(n_trials * p * (1 - p))) + diag(2)
  list(mode = opt$par, R = chol(h), log_density = ld, condition = kappa(h, exact = TRUE))
}

.o3_q2_log_integral <- function(y, n_trials, eta_fixed, loading, nodes) {
  rule <- .o3_gh(nodes); m <- .o3_q2_mode(y, n_trials, eta_fixed, loading); grid <- as.matrix(expand.grid(rule$x, rule$x)); lw <- as.vector(outer(log(rule$w), log(rule$w), "+"))
  u <- sweep(sqrt(2) * t(backsolve(m$R, t(grid))), 2L, m$mode, "+"); a <- apply(u, 1L, m$log_density) + lw + rowSums(grid^2); mx <- max(a)
  list(log_integral = 2 * log(sqrt(2)) - sum(log(diag(m$R))) + mx + log(sum(exp(a - mx))), condition = m$condition)
}

.o3_q2_extract <- function(fit) {
  d <- fit$tmb_obj$env$data
  if (!inherits(fit, "gllvmTMB_multi") || !isTRUE(fit$use$rr_B) || fit$d_B != 2L || isTRUE(fit$use$diag_B) || !identical(as.integer(d$family_id_vec), rep.int(1L, length(d$y)))) stop("requires a binomial ordinary latent(..., d = 2, unique = FALSE) gllvmTMB fit")
  par <- fit$tmb_obj$env$last.par.best; beta <- par[names(par) == "b_fix"]; if (length(beta) != ncol(d$X_fix)) stop("b_fix extraction mismatch")
  list(y = d$y, n_trials = d$n_trials, eta_fixed = drop(d$X_fix %*% beta), loading = fit$report$Lambda_B[d$trait_id + 1L, , drop = FALSE], unit = d$site_id + 1L, tmb_objective = fit$opt$objective)
}

o3_q2_gllvm_unit_ladder <- function(fit, nodes = c(1L, 3L, 5L, 7L, 9L)) {
  x <- .o3_q2_extract(fit); ids <- split(seq_along(x$y), x$unit)
  do.call(rbind, lapply(nodes, function(nq) { vals <- lapply(ids, function(ii) .o3_q2_log_integral(x$y[ii], x$n_trials[ii], x$eta_fixed[ii], x$loading[ii, , drop = FALSE], nq)); data.frame(nodes = nq, objective = -sum(vapply(vals, `[[`, numeric(1), "log_integral")), max_condition = max(vapply(vals, `[[`, numeric(1), "condition"))) }))
}

.o3_q2_fixture <- function(seed = 20260720L, n_unit = 20L, n_rep = 4L, n_trials = 12L) {
  set.seed(seed); u <- matrix(rnorm(n_unit * 2L), n_unit, 2L) %*% diag(c(0.7, 0.45)); dat <- expand.grid(rep = seq_len(n_rep), trait = factor(c("t1", "t2")), unit = factor(sprintf("u%02d", seq_len(n_unit))))
  dat <- dat[order(dat$unit, dat$trait, dat$rep), , drop = FALSE]; beta <- c(-0.25, 0.3); lambda <- matrix(c(0.8, 0, 0.25, 0.55), 2L, 2L, byrow = TRUE)
  eta <- beta[as.integer(dat$trait)] + rowSums(lambda[as.integer(dat$trait), , drop = FALSE] * u[as.integer(dat$unit), , drop = FALSE]); dat$succ <- rbinom(nrow(dat), n_trials, plogis(eta)); dat$fail <- n_trials - dat$succ; dat
}

o3_q2_gllvm_unit_self_test <- function() {
  dat <- .o3_q2_fixture(); fit <- suppressWarnings(gllvmTMB::gllvmTMB(cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE), data = dat, family = binomial(), unit = "unit"))
  if (fit$opt$convergence != 0L || !isTRUE(fit$fit_health$pd_hessian)) stop("deterministic q = 2 gllvmTMB fixture is not healthy")
  ladder <- o3_q2_gllvm_unit_ladder(fit); one <- ladder$objective[ladder$nodes == 1L]
  if (abs(one - fit$opt$objective) > 1e-6) stop("reconstructed q = 2 Laplace objective disagrees with joint TMB Laplace")
  if (abs(ladder$objective[ladder$nodes == 7L] - ladder$objective[ladder$nodes == 9L]) > 1e-4) stop("q = 2 AGHQ node ladder has not stabilized by 7 vs 9")
  if (max(ladder$max_condition) > 1e8) stop("q = 2 conditional Hessian is ill-conditioned")
  list(tmb_objective = fit$opt$objective, ladder = ladder, laplace_difference = one - fit$opt$objective)
}
