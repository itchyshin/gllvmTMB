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

## R2 fixed-coordinate reference harness.  These helpers deliberately live in
## tests/: they are not an estimator, a gllvmTMB() argument, or an API.
.o3_r2_mode <- function(y, n_trials, eta_fixed, loading) {
  loading <- as.matrix(loading)
  q <- ncol(loading)
  stopifnot(q %in% 1:2, nrow(loading) == length(y))
  log_density <- function(u) {
    eta <- eta_fixed + drop(loading %*% u)
    sum(dbinom(y, n_trials, plogis(eta), log = TRUE)) +
      sum(dnorm(u, 0, 1, log = TRUE))
  }
  opt <- optim(rep(0, q), function(u) -log_density(u), method = "BFGS",
               control = list(reltol = 1e-11, maxit = 300L))
  if (opt$convergence != 0L || any(!is.finite(opt$par))) {
    stop("conditional mode did not converge")
  }
  p <- plogis(eta_fixed + drop(loading %*% opt$par))
  h <- crossprod(loading * sqrt(n_trials * p * (1 - p))) + diag(q)
  ee <- eigen(h, symmetric = TRUE, only.values = TRUE)$values
  chol_ok <- all(is.finite(ee)) && min(ee) > 0
  list(
    mode = opt$par,
    R = if (chol_ok) chol(h) else NULL,
    log_density = log_density,
    gradient_norm = sqrt(sum((crossprod(loading, y - n_trials * p) - opt$par)^2)),
    min_eigen = min(ee),
    max_eigen = max(ee),
    condition = max(ee) / min(ee),
    chol_ok = chol_ok
  )
}

.o3_r2_guard <- function(y, n_trials, eta_fixed, loading, limit = 1e8) {
  mode <- .o3_r2_mode(y, n_trials, eta_fixed, loading)
  status <- if (!isTRUE(mode$chol_ok)) {
    "nonpositive_curvature"
  } else if (!is.finite(mode$condition) || mode$condition > limit) {
    "condition_exceeds_limit"
  } else {
    "ok"
  }
  c(mode[c("mode", "gradient_norm", "min_eigen", "max_eigen", "condition", "chol_ok")],
    list(status = status))
}

.o3_r2_log_integral <- function(y, n_trials, eta_fixed, loading, nodes) {
  mode <- .o3_r2_mode(y, n_trials, eta_fixed, loading)
  if (!isTRUE(mode$chol_ok) || !is.finite(mode$condition) || mode$condition > 1e8) {
    stop("conditional curvature rejected before quadrature")
  }
  q <- ncol(as.matrix(loading))
  rule <- .o3_gh(nodes)
  grid <- as.matrix(do.call(expand.grid, rep(list(rule$x), q)))
  log_weight <- rowSums(matrix(vapply(
    seq_len(q),
    function(j) log(rule$w[match(grid[, j], rule$x)]),
    numeric(nrow(grid))
  ), ncol = q))
  u <- sweep(sqrt(2) * t(backsolve(mode$R, t(grid))), 2L, mode$mode, "+")
  a <- apply(u, 1L, mode$log_density) + log_weight + rowSums(grid^2)
  mx <- max(a)
  list(
    log_integral = q * log(sqrt(2)) - sum(log(diag(mode$R))) + mx + log(sum(exp(a - mx))),
    mode = mode$mode,
    gradient_norm = mode$gradient_norm,
    min_eigen = mode$min_eigen,
    max_eigen = mode$max_eigen,
    condition = mode$condition,
    chol_ok = mode$chol_ok
  )
}

.o3_r2_extract <- function(fit) {
  d <- fit$tmb_obj$env$data
  q <- fit$d_B
  if (!inherits(fit, "gllvmTMB_multi") || !isTRUE(fit$use$rr_B) ||
      !q %in% 1:2 || isTRUE(fit$use$diag_B) ||
      !identical(as.integer(d$family_id_vec), rep.int(1L, length(d$y)))) {
    stop("requires a binomial ordinary latent(..., d = 1 or 2, unique = FALSE) gllvmTMB fit")
  }
  par <- fit$tmb_obj$env$last.par.best
  beta <- par[names(par) == "b_fix"]
  if (length(beta) != ncol(d$X_fix)) stop("b_fix extraction mismatch")
  list(
    y = d$y,
    n_trials = d$n_trials,
    eta_fixed = drop(d$X_fix %*% beta),
    loading = fit$report$Lambda_B[d$trait_id + 1L, , drop = FALSE],
    trait_id = d$trait_id,
    unit = d$site_id + 1L,
    tmb_objective = fit$opt$objective,
    q = q
  )
}

.o3_r2_evaluate <- function(extracted, nodes) {
  ids <- split(seq_along(extracted$y), extracted$unit)
  per_unit <- lapply(seq_along(ids), function(j) {
    ii <- ids[[j]]
    ## Canonicalise the within-unit arithmetic order so that a row permutation
    ## cannot change a floating-point sum merely through accumulation order.
    ii <- ii[order(extracted$trait_id[ii], extracted$y[ii],
                   extracted$n_trials[ii], extracted$eta_fixed[ii])]
    ans <- .o3_r2_log_integral(
      extracted$y[ii], extracted$n_trials[ii], extracted$eta_fixed[ii],
      extracted$loading[ii, , drop = FALSE], nodes
    )
    data.frame(unit_id = as.integer(names(ids)[j]), nodes = as.integer(nodes),
               log_integral = ans$log_integral,
               mode = paste(signif(ans$mode, 16), collapse = ";"),
               gradient_norm = ans$gradient_norm, min_eigen = ans$min_eigen,
               max_eigen = ans$max_eigen, condition = ans$condition,
               chol_ok = ans$chol_ok, status = "ok")
  })
  diagnostics <- do.call(rbind, per_unit)
  list(objective = -sum(diagnostics$log_integral), diagnostics = diagnostics)
}

.o3_r2_fixture_data <- function(q, seed, loading_multiplier = 1,
                                 intercept_shift = 0, near_collinear = FALSE) {
  stopifnot(q %in% 1:2, length(seed) == 1L)
  set.seed(seed)
  if (q == 1L) {
    n_unit <- 16L; n_rep <- 3L; traits <- c("t1", "t2")
    beta <- c(-0.2, 0.35) + intercept_shift
    lambda <- matrix(c(0.8, -0.5) * loading_multiplier, ncol = 1L)
    u <- matrix(rnorm(n_unit, 0, 0.7), ncol = 1L)
  } else {
    n_unit <- 20L; n_rep <- 4L
    traits <- if (near_collinear) paste0("t", 1:4) else c("t1", "t2")
    beta <- if (near_collinear) c(-0.25, 0.3, -0.05, 0.15) else c(-0.25, 0.3)
    beta <- beta + intercept_shift
    lambda <- if (near_collinear) {
      ## Lower-triangular leading block; column 2 differs from column 1 by
      ## epsilon = 0.08 only at the first trait.
      matrix(c(0.08, 0, 0.75, 0.75, 0.55, 0.55, 0.35, 0.35), 4L, 2L, byrow = TRUE)
    } else {
      matrix(c(0.8, 0, 0.25, 0.55), 2L, 2L, byrow = TRUE)
    }
    lambda <- lambda * loading_multiplier
    u <- matrix(rnorm(n_unit * 2L), n_unit, 2L) %*% diag(c(0.7, 0.45))
  }
  dat <- expand.grid(rep = seq_len(n_rep), trait = factor(traits, levels = traits),
                     unit = factor(sprintf("u%02d", seq_len(n_unit))))
  dat <- dat[order(dat$unit, dat$trait, dat$rep), , drop = FALSE]
  eta <- beta[as.integer(dat$trait)] + rowSums(
    lambda[as.integer(dat$trait), , drop = FALSE] *
      u[as.integer(dat$unit), , drop = FALSE]
  )
  dat$succ <- rbinom(nrow(dat), 12L, plogis(eta))
  dat$fail <- 12L - dat$succ
  list(data = dat, truth = list(beta = beta, Lambda_B = lambda,
                                Sigma_B = tcrossprod(lambda), seed = seed))
}

.o3_r2_fit_fixture <- function(fixture) {
  dat <- fixture$data
  q <- ncol(fixture$truth$Lambda_B)
  suppressWarnings(gllvmTMB::gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = q, unique = FALSE),
    data = dat, family = binomial(), unit = "unit",
    control = gllvmTMB::gllvmTMBcontrol(n_init = 2L, init_jitter = 0.02, se = FALSE)
  ))
}

o3_r2_run_fixture <- function(fixture_id, q, seed, loading_multiplier = 1,
                               intercept_shift = 0, near_collinear = FALSE) {
  started_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  fixture <- .o3_r2_fixture_data(q, seed, loading_multiplier, intercept_shift,
                                  near_collinear)
  fit <- .o3_r2_fit_fixture(fixture)
  if (fit$opt$convergence != 0L) stop(fixture_id, ": ML fit did not converge")
  fit_gradient <- fit$tmb_obj$gr(fit$opt$par)
  x <- .o3_r2_extract(fit)
  nodes <- if (q == 1L) c(1L, 5L, 9L, 15L, 25L) else c(1L, 3L, 5L, 7L, 9L)
  values <- lapply(nodes, function(nq) .o3_r2_evaluate(x, nq))
  ladder <- data.frame(nodes = nodes, objective = vapply(values, `[[`, numeric(1), "objective"))
  diagnostics <- do.call(rbind, lapply(seq_along(values), function(i) {
    within(values[[i]]$diagnostics, fixture_id <- fixture_id)
  }))
  unit_order <- order(-x$unit, seq_along(x$unit))
  ## Keep whole-unit order fixed here: this is the separately required
  ## within-unit row permutation, not a second unit-order permutation.
  row_order <- unlist(lapply(split(seq_along(x$y), x$unit), rev), use.names = FALSE)
  permute_objective <- function(order_index, nq) {
    xx <- lapply(x, function(v) if (length(v) == length(x$y)) v[order_index] else v)
    xx$loading <- x$loading[order_index, , drop = FALSE]
    .o3_r2_evaluate(xx, nq)$objective
  }
  permutation_unit <- vapply(nodes, function(nq) permute_objective(unit_order, nq), numeric(1)) - ladder$objective
  permutation_row <- vapply(nodes, function(nq) permute_objective(row_order, nq), numeric(1)) - ladder$objective
  one <- ladder$objective[ladder$nodes == 1L]
  terminal <- if (q == 1L) abs(ladder$objective[ladder$nodes == 15L] - ladder$objective[ladder$nodes == 25L]) else abs(ladder$objective[ladder$nodes == 7L] - ladder$objective[ladder$nodes == 9L])
  list(
    fixture_id = fixture_id, q = q, seed = seed, fit = fit, truth = fixture$truth,
    data = fixture$data, ladder = ladder, diagnostics = diagnostics,
    laplace_difference = one - x$tmb_objective, terminal_difference = terminal,
    permutation_unit = permutation_unit, permutation_row = permutation_row,
    max_condition = max(diagnostics$condition), prevalence = mean(fixture$data$succ / 12),
    pd_hessian = isTRUE(fit$fit_health$pd_hessian),
    convergence = fit$opt$convergence, started_at = started_at,
    fit_gradient_norm = sqrt(sum(fit_gradient^2)),
    loading_multiplier = loading_multiplier, intercept_shift = intercept_shift,
    near_collinear = near_collinear
  )
}

o3_r2_condition_reject <- function() {
  loading <- matrix(c(50000, 0, 50000, 1), 2L, 2L, byrow = TRUE)
  ## This declared held-coordinate fixture has exact conditional mode zero:
  ## y - n * plogis(eta) = 0 at eta = 0.  Compute only its curvature guard;
  ## no optimiser, TMB fit, or quadrature is called.
  h <- crossprod(loading * sqrt(c(25, 25))) + diag(2)
  ee <- eigen(h, symmetric = TRUE, only.values = TRUE)$values
  list(
    mode = c(0, 0), gradient_norm = 0,
    min_eigen = min(ee), max_eigen = max(ee),
    condition = max(ee) / min(ee), chol_ok = TRUE,
    status = if (max(ee) / min(ee) > 1e8) "condition_exceeds_limit" else "ok"
  )
}

o3_r2_default_specs <- function() {
  list(
    list("baseline_q1", 1L, 20260719L),
    list("baseline_q2", 2L, 20260720L),
    list("signal_low_q1", 1L, 20260721L, loading_multiplier = 0.35),
    list("signal_high_q2", 2L, 20260722L, loading_multiplier = 1.60),
    list("intercept_shift_q1", 1L, 20260723L, intercept_shift = -1.25),
    list("intercept_shift_q2", 2L, 20260724L, intercept_shift = 1.25),
    list("near_collinear_q2", 2L, 20260725L, near_collinear = TRUE)
  )
}

o3_r2_run_default <- function() {
  lapply(o3_r2_default_specs(), function(spec) do.call(o3_r2_run_fixture, spec))
}

.o3_r2_git <- function(...) {
  out <- suppressWarnings(system2("git", c("-C", getwd(), ...), stdout = TRUE, stderr = FALSE))
  if (length(out) == 1L && nzchar(out)) out else NA_character_
}

o3_r2_write_receipt <- function(results, output_dir) {
  stopifnot(is.list(results), length(results) > 0L, is.character(output_dir), length(output_dir) == 1L)
  is_r2_result <- function(x) {
    is.list(x) && length(x$q) == 1L && is.finite(x$q) &&
      as.integer(x$q) == x$q && as.integer(x$q) %in% 1:2
  }
  if (any(!vapply(results, is_r2_result, logical(1)))) {
    stop("R2 receipt accepts fixed-coordinate q = 1 or q = 2 results only")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(output_dir)) stop("could not create output_dir")
  helper_sha <- .o3_r2_git("hash-object", "tests/testthat/helper-aghq-o3.R")
  commit <- .o3_r2_git("rev-parse", "HEAD")
  platform <- paste(R.version$platform, R.version$version.string, sep = " | ")
  terminal_node <- function(x) if (x$q == 1L) 25L else 9L
  summaries <- lapply(results, function(x) {
    objective_names <- paste0("objective_nodes_", c(1L, 3L, 5L, 7L, 9L, 15L, 25L))
    objectives <- as.list(stats::setNames(rep(NA_real_, length(objective_names)), objective_names))
    objectives[paste0("objective_nodes_", x$ladder$nodes)] <- as.list(x$ladder$objective)
    pass <- abs(x$laplace_difference) < 1e-6 && x$terminal_difference < 1e-4 &&
      max(abs(x$permutation_unit)) <= 1e-10 && max(abs(x$permutation_row)) <= 1e-10 &&
      x$max_condition <= 1e8 && x$convergence == 0L
    as.data.frame(c(list(
      fixture_id = x$fixture_id, seed = x$seed, q = x$q,
      n_rows = nrow(x$data), n_units = nlevels(x$data$unit), n_traits = nlevels(x$data$trait),
      node_vector = paste(x$ladder$nodes, collapse = ";"),
      loading_multiplier = x$loading_multiplier,
      intercept_shift = x$intercept_shift,
      near_collinear = x$near_collinear,
      started_at = x$started_at,
      objective_source = "refit_opt", terminal_nodes = terminal_node(x),
      one_node_difference = x$laplace_difference,
      terminal_ladder_difference = x$terminal_difference,
      unit_permutation_difference = max(abs(x$permutation_unit)),
      row_permutation_difference = max(abs(x$permutation_row)),
      max_condition = x$max_condition, prevalence = x$prevalence,
      fit_convergence = x$convergence, fit_gradient_norm = x$fit_gradient_norm,
      pd_hessian = x$pd_hessian,
      status = if (pass) "pass" else "fail",
      reason = if (pass) "all_fixed_coordinate_identities_pass" else "identity_failure"
    ), objectives), stringsAsFactors = FALSE)
  })
  summary <- do.call(rbind, summaries)
  diagnostics <- do.call(rbind, lapply(results, function(x) {
    transform(x$diagnostics, seed = x$seed)
  }))
  reject <- o3_r2_condition_reject()
  reject_input <- list(
    y = c(50, 50), n_trials = c(100, 100), beta = c(0, 0), eta_fixed = c(0, 0),
    loading = matrix(c(50000, 0, 50000, 1), 2L, 2L, byrow = TRUE)
  )
  diagnostics <- rbind(diagnostics, data.frame(
    unit_id = 1L, nodes = NA_integer_, log_integral = NA_real_, mode = "0;0",
    gradient_norm = reject$gradient_norm, min_eigen = reject$min_eigen,
    max_eigen = reject$max_eigen, condition = reject$condition,
    chol_ok = reject$chol_ok, status = reject$status,
    fixture_id = "condition_reject_q2", seed = NA_integer_, stringsAsFactors = FALSE
  ))
  manifest <- summary[, c(
    "fixture_id", "seed", "q", "n_rows", "n_units", "n_traits", "node_vector",
    "loading_multiplier", "intercept_shift", "near_collinear", "started_at"
  )]
  condition_manifest <- manifest[1L, , drop = FALSE]
  condition_manifest[1L, ] <- NA
  condition_manifest$fixture_id <- "condition_reject_q2"
  condition_manifest$q <- 2L
  condition_manifest$n_rows <- 2L
  condition_manifest$n_units <- 1L
  condition_manifest$n_traits <- 2L
  condition_manifest$node_vector <- "not_attempted"
  condition_manifest$started_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  manifest <- rbind(manifest, condition_manifest)
  manifest$package_commit <- commit
  manifest$source_helper_sha <- helper_sha
  manifest$platform <- platform
  manifest$r_version <- R.version$version.string
  manifest$tmb_version <- as.character(utils::packageVersion("TMB"))
  manifest$command <- "source('tests/testthat/helper-aghq-o3.R'); o3_r2_write_receipt(o3_r2_run_default(), '<output_dir>')"
  manifest$objective_source <- c(rep("refit_opt", length(results)), "prequadrature_guard")
  manifest$terminal_status <- c(summary$status, reject$status)
  manifest$condition_parameters <- NA_character_
  manifest$condition_parameters[nrow(manifest)] <- paste(
    "n_trials=(100,100)", "y=(50,50)", "beta=(0,0)",
    "Lambda=((50000,0),(50000,1))", sep = "; "
  )
  utils::write.csv(manifest, file.path(output_dir, "manifest.csv"), row.names = FALSE)
  utils::write.csv(diagnostics, file.path(output_dir, "unit_diagnostics.csv"), row.names = FALSE)
  utils::write.csv(summary, file.path(output_dir, "fixture_summary.csv"), row.names = FALSE)
  saveRDS(list(
    fixtures = lapply(results, function(x) list(fixture_id = x$fixture_id, data = x$data, truth = x$truth)),
    condition_reject_q2 = c(reject_input, list(telemetry = reject))
  ), file.path(output_dir, "truth.rds"))
  writeLines(c(
    "# R2 fixed-coordinate AGHQ reference receipt",
    "",
    "Rerun from a source checkout:",
    "",
    "```r",
    "source('tests/testthat/helper-aghq-o3.R')",
    "o3_r2_write_receipt(o3_r2_run_default(), 'data-raw/aghq-reference/<date>-r2')",
    "```",
    "",
    "Exit rule: all ordinary q=1/q=2 fixtures must have status `pass`; the",
    "`condition_reject_q2` manifest row must be `condition_exceeds_limit`.",
    "This receipt is research-only. q>=3 was not attempted. It is neither an",
    "AGHQ refit nor a likelihood, REML, interval, recovery, or coverage claim."
  ), file.path(output_dir, "README.md"))
  invisible(list(manifest = manifest, fixture_summary = summary,
                 unit_diagnostics = diagnostics, condition_reject = reject))
}
