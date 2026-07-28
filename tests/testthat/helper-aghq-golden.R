## E3 golden-test helpers: an INDEPENDENT brute-force oracle for the AGHQ
## marginal likelihood, plus a harness that runs the package's own AGHQ path
## across a node-count ladder and compares it to that oracle.
##
## Independence is the entire point of this file. The functions below
## re-derive the marginal likelihood from the model definition itself --
## bernoulli-logit observations, a N(0, 1) latent score, q = 1 (one
## dimension, so the per-site integral is 1-D and stats::integrate() is a
## genuinely separate numerical method from anything TMB or gllvmTMB does
## internally). Nothing here calls gllvmTMB:::.aghq_gate, .aghq_resolve, or
## .aghq_grid, and nothing here reuses the TMB template. If this file ever
## grows a dependency on those, the golden test built on it becomes vacuous
## -- see docs/dev-log/... AGHQ interface notes for the four earlier
## silently-vacuous verifications found in this project.
##
## This lives under tests/testthat/ (not dev/) for the same reason
## helper-aghq-o3.R does: testthat auto-sources helper-*.R files, and dev/
## is excluded from R CMD build.

## ---------------------------------------------------------------------
## q = 1 brute-force oracle: per-site integral is 1-D.
## ---------------------------------------------------------------------

## Log marginal likelihood for one site's row vector y_site (length T,
## ordered to match beta/lambda), integrating out a single N(0,1) latent
## score u by direct numerical integration.
.golden_site_log_marginal_q1 <- function(y_site, beta, lambda) {
  stopifnot(length(y_site) == length(beta), length(beta) == length(lambda))
  integrand <- function(u) {
    vapply(u, function(uu) {
      eta <- beta + lambda * uu
      p <- plogis(eta)
      prod(dbinom(y_site, 1L, p)) * dnorm(uu)
    }, numeric(1))
  }
  val <- stats::integrate(integrand, lower = -Inf, upper = Inf,
                           rel.tol = 1e-12, abs.tol = 1e-15)
  log(val$value)
}

## Cross-check for the oracle above: a fixed, very fine Simpson's-rule
## quadrature over a wide finite range. This shares NO code with
## stats::integrate()'s adaptive algorithm, so agreement between the two is
## real evidence the oracle formula is correct rather than a shared bug.
.golden_site_log_marginal_q1_simpson <- function(y_site, beta, lambda,
                                                  lim = 12, n = 2000001L) {
  u <- seq(-lim, lim, length.out = n)
  h <- u[2L] - u[1L]
  vals <- vapply(u, function(uu) {
    eta <- beta + lambda * uu
    prod(dbinom(y_site, 1L, plogis(eta))) * dnorm(uu)
  }, numeric(1))
  w <- rep(c(4, 2), length.out = n)
  w[1L] <- 1; w[n] <- 1
  log(h / 3 * sum(w * vals))
}

## Total brute-force negative log-likelihood for a q = 1 data set, summing
## the per-site log marginal over all sites. beta/lambda are length-T
## vectors in the SAME order as levels(dat[[trait_col]]).
.golden_brute_force_nll_q1 <- function(dat, beta, lambda,
                                       site_col = "site", trait_col = "trait",
                                       y_col = "y") {
  ids <- split(seq_len(nrow(dat)), dat[[site_col]])
  total <- 0
  for (ii in ids) {
    ord <- order(as.integer(dat[[trait_col]][ii]))
    y_site <- dat[[y_col]][ii][ord]
    total <- total + .golden_site_log_marginal_q1(y_site, beta, lambda)
  }
  -total
}

## Deterministic q = 1 fixture: n_site sites, length(beta) traits,
## bernoulli-logit, single shared latent score per site, no Psi. Matches the
## required GOLDEN 2 shape at the defaults (n = 3, T = 2, q = 1).
.golden_dgp_q1 <- function(seed = 6L, n_site = 3L,
                            beta = c(-0.3, 0.5), lambda = c(0.9, -0.6)) {
  stopifnot(length(beta) == length(lambda), n_site >= 1L)
  n_trait <- length(beta)
  set.seed(seed)
  u <- rnorm(n_site)
  site <- factor(rep(paste0("s", seq_len(n_site)), each = n_trait))
  trait <- factor(rep(paste0("t", seq_len(n_trait)), n_site),
                  levels = paste0("t", seq_len(n_trait)))
  eta <- beta[as.integer(trait)] + lambda[as.integer(trait)] * u[as.integer(site)]
  y <- rbinom(length(eta), 1L, plogis(eta))
  list(data = data.frame(site = site, trait = trait, y = y),
       beta = beta, lambda = lambda, u = u, seed = seed)
}

## ---------------------------------------------------------------------
## q = 2 bonus oracle: per-site integral is 2-D, via nested integrate().
## Not the required deliverable; kept separate and allowed to be skipped.
## ---------------------------------------------------------------------

.golden_site_log_marginal_q2 <- function(y_site, beta, Lambda) {
  Lambda <- as.matrix(Lambda)
  stopifnot(nrow(Lambda) == length(y_site), ncol(Lambda) == 2L)
  outer_fn <- function(u1) {
    vapply(u1, function(uu1) {
      inner_fn <- function(u2) {
        vapply(u2, function(uu2) {
          eta <- beta + Lambda[, 1L] * uu1 + Lambda[, 2L] * uu2
          prod(dbinom(y_site, 1L, plogis(eta))) * dnorm(uu2)
        }, numeric(1))
      }
      val <- stats::integrate(inner_fn, -Inf, Inf,
                               rel.tol = 1e-10, abs.tol = 1e-13)$value
      val * dnorm(uu1)
    }, numeric(1))
  }
  val <- stats::integrate(outer_fn, -Inf, Inf, rel.tol = 1e-9, abs.tol = 1e-12)
  log(val$value)
}

.golden_brute_force_nll_q2 <- function(dat, beta, Lambda,
                                       site_col = "site", trait_col = "trait",
                                       y_col = "y") {
  Lambda <- as.matrix(Lambda)
  ids <- split(seq_len(nrow(dat)), dat[[site_col]])
  total <- 0
  for (ii in ids) {
    ord <- order(as.integer(dat[[trait_col]][ii]))
    y_site <- dat[[y_col]][ii][ord]
    total <- total + .golden_site_log_marginal_q2(y_site, beta, Lambda)
  }
  -total
}

.golden_dgp_q2 <- function(seed = 6L, n_site = 3L,
                            beta = c(-0.3, 0.5),
                            Lambda = matrix(c(0.9, 0.3, -0.6, 0.5), 2L, 2L, byrow = TRUE)) {
  n_trait <- length(beta)
  stopifnot(nrow(Lambda) == n_trait, ncol(Lambda) == 2L, n_site >= 1L)
  set.seed(seed)
  u <- matrix(rnorm(n_site * 2L), n_site, 2L)
  site <- factor(rep(paste0("s", seq_len(n_site)), each = n_trait))
  trait <- factor(rep(paste0("t", seq_len(n_trait)), n_site),
                  levels = paste0("t", seq_len(n_trait)))
  eta <- beta[as.integer(trait)] +
    rowSums(Lambda[as.integer(trait), , drop = FALSE] * u[as.integer(site), , drop = FALSE])
  y <- rbinom(length(eta), 1L, plogis(eta))
  list(data = data.frame(site = site, trait = trait, y = y),
       beta = beta, Lambda = Lambda, u = u, seed = seed)
}

## ---------------------------------------------------------------------
## Package-side plumbing: availability guard and the node-count ladder.
## ---------------------------------------------------------------------

## Build a gllvmTMBcontrol()-based control list requesting AGHQ at k nodes.
## `aghq` is NOT (yet) a formal argument of gllvmTMBcontrol() -- the
## interface contract's eventual `gllvmTMBcontrol(aghq = k)` surface has not
## landed as of this file. The actual wiring (R/fit-multi.R's
## .gllvmTMB_aghq_k()) reads `control$aghq` off the control LIST, so this
## sets it directly after construction. This is a stopgap against the
## documented contract, not a guess: verified against
## .gllvmTMB_aghq_k(control, d_B) in R/fit-multi.R, which does exactly
## `a <- control$aghq`.
.golden_aghq_control <- function(k, ...) {
  ctrl <- gllvmTMB::gllvmTMBcontrol(...)
  ctrl$aghq <- k
  ctrl
}

## Formula used by every golden fit in this file: ordinary latent(), loadings
## only (unique = FALSE => no Psi), matching the GOLDEN 2 spec.
.golden_formula_q1 <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)

## Full end-to-end smoke test: does an actual gllvmTMB() call requesting
## AGHQ at k = 1 run to a finite objective, with fit$aghq$used TRUE? Probing
## by USING the capability (a real toy fit), not by checking whether a
## function/argument merely exists, since a negative exists()/formals()
## check cannot prove the kernel is absent or ready. This is the gate the
## golden tests use to decide skip() vs run-for-real, since E1's kernel may
## land (or partially land) at any point while this file is in use.
.golden_aghq_smoke_ok <- function(dat) {
  ok <- tryCatch({
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      .golden_formula_q1, data = dat, family = binomial(), unit = "site",
      control = .golden_aghq_control(1L, n_init = 1L, init_jitter = 0, se = FALSE)
    ))
    is.finite(fit$opt$objective) && isTRUE(fit$aghq$used)
  }, error = function(e) FALSE)
  isTRUE(ok)
}

## Fit the q = 1 golden fixture at one AGHQ node count k and return the
## package's reported objective alongside the INDEPENDENT brute-force
## marginal evaluated at that same fit's own converged (beta, Lambda) --
## i.e. "is the number the package reports accurate at the point it landed
## on", decoupled from where different k happen to converge.
.golden_fit_one_k <- function(dat, k) {
  fit <- suppressWarnings(gllvmTMB::gllvmTMB(
    .golden_formula_q1, data = dat, family = binomial(), unit = "site",
    control = .golden_aghq_control(k, n_init = 1L, init_jitter = 0, se = FALSE)
  ))
  par <- fit$tmb_obj$env$last.par.best
  beta_hat <- unname(par[names(par) == "b_fix"])
  lambda_hat <- as.numeric(fit$report$Lambda_B[, 1L])
  if (length(beta_hat) != length(lambda_hat)) {
    stop("golden ladder: b_fix / Lambda_B length mismatch at k = ", k)
  }
  brute <- .golden_brute_force_nll_q1(dat, beta_hat, lambda_hat)
  data.frame(k = k, aghq_objective = fit$opt$objective,
             brute_force_nll = brute,
             abs_error = abs(fit$opt$objective - brute),
             convergence = fit$opt$convergence)
}

## The convergence ladder itself: one row per k, each an independent fit.
.golden_run_ladder_q1 <- function(dat, ks = c(1L, 3L, 5L, 7L, 9L, 15L)) {
  do.call(rbind, lapply(ks, .golden_fit_one_k, dat = dat))
}
