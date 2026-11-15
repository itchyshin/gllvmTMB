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
## Not the required deliverable; kept separate and allowed to be skipped
## only when the AGHQ kernel itself is unavailable (see the test).
## ---------------------------------------------------------------------

## Prior window, in standard deviations of N(0, 1). Each nested integrand
## is a Bernoulli likelihood (at most 1) times a standard normal density, so
## the integral outside [-K, K] is at most the prior tail
## t = 2 * pnorm(-K) = 3.55e-33. The square [-K, K]^2 therefore drops at most
## 2*t - t^2 = 7.11e-33 of the joint integral. That is far below the inner
## abs.tol of 1e-13 and the outer abs.tol of 1e-12, so the finite window does
## not relax either absolute tolerance. That bound is not necessarily small
## relative to a rare likelihood, so the site-level oracle checks it against
## the returned integral and refuses an uncontrolled tail. K = 12 is the same
## truncation used by the one-dimensional VA oracle.
.golden_q2_prior_K <- 12

## stats::integrate() on (-Inf, Inf) rewrites the axis through a rational map
## and then runs Wynn extrapolation. A narrow ridge, or a nested integrand
## whose inner integral is only smooth up to its own tolerance, makes that
## extrapolation report "roundoff error", exhaust its subdivisions, or, on a
## finite window, declare "the integral is probably divergent" (QUADPACK
## ier = 5 once extrapolation has failed five times). covr's -O0 fits land on
## such (beta, Lambda) points often enough to fail shard 2/4. Integrate the
## same function on a finite, mode-centred interval instead. rel.tol and
## abs.tol are the caller's, unchanged. "probably divergent", bad integrand
## behaviour, and a non-finite sample are caught like roundoff, but they are
## not retried with more subdivisions: that repeats the same extrapolation
## test. The bounded window is then integrated with a fixed composite
## Gauss-Legendre rule, which has no extrapolation table.
.golden_gl_rule <- local({
  cache <- new.env(parent = emptyenv())
  function(n) {
    key <- as.character(n)
    if (exists(key, envir = cache, inherits = FALSE)) {
      return(get(key, envir = cache, inherits = FALSE))
    }
    n <- as.integer(n)
    J <- matrix(0, n, n)
    k <- seq_len(n - 1L)
    b <- k / sqrt(4 * k * k - 1)
    J[cbind(k, k + 1L)] <- b
    J[cbind(k + 1L, k)] <- b
    ev <- eigen(J, symmetric = TRUE)
    o <- order(ev$values)
    rule <- list(x = ev$values[o], w = 2 * ev$vectors[1L, o]^2)
    assign(key, rule, envir = cache)
    rule
  }
})

## Equal-panel Gauss-Legendre. Nodes and weights are fixed, so the rule has
## no subdivision cap and no extrapolation table to declare divergence.
## Samples that are not finite are 0: a log-shift that underflowed or a
## saturated logit that produced NaN must not reach the sum as Inf.
.golden_composite_gl <- function(f, lower, upper, n_panel = 24L, n_gl = 16L) {
  if (!is.finite(lower) || !is.finite(upper) || upper < lower) return(NA_real_)
  if (upper == lower) return(0)
  g <- .golden_gl_rule(n_gl)
  edges <- seq(lower, upper, length.out = n_panel + 1L)
  half <- (upper - lower) / (2 * n_panel)
  mids <- (edges[-length(edges)] + edges[-1L]) / 2
  x <- rep(mids, each = n_gl) + rep(g$x * half, times = n_panel)
  w <- rep(g$w * half, times = n_panel)
  fx <- f(x)
  fx[!is.finite(fx) | fx < 0] <- 0
  sum(w * fx)
}

.golden_integrate_finite <- function(f, lower, upper, rel.tol, abs.tol) {
  width <- upper - lower
  if (!is.finite(width) || width < 0) {
    stop("stats::integrate() failed for nested AGHQ golden oracle", call. = FALSE)
  }
  if (width == 0) return(0)
  retryable <- function(msg) {
    grepl("maximum number of subdivisions reached", msg, fixed = TRUE) ||
      grepl("roundoff error", msg, fixed = TRUE) ||
      grepl("probably divergent", msg, fixed = TRUE) ||
      grepl("extremely bad integrand behaviour", msg, fixed = TRUE) ||
      grepl("non-finite function value", msg, fixed = TRUE)
  }
  ## More subdivisions repeat the same extrapolation test. A divergent,
  ## non-finite, or "bad behaviour" report will not become a success that way.
  hard_fail <- function(msg) {
    grepl("probably divergent", msg, fixed = TRUE) ||
      grepl("extremely bad integrand behaviour", msg, fixed = TRUE) ||
      grepl("non-finite function value", msg, fixed = TRUE)
  }
  once <- function(lo, hi, sub) {
    tryCatch(
      stats::integrate(f, lo, hi, rel.tol = rel.tol, abs.tol = abs.tol,
                       subdivisions = sub),
      error = function(e) {
        msg <- conditionMessage(e)
        if (retryable(msg)) structure(list(message = msg), class = "golden_int_fail")
        else stop(e)
      }
    )
  }
  ## Height of every integrand passed here is at most 1 (log-shift) or the
  ## Laplace jacobian, which is itself at most 1. A panel narrower than
  ## abs.tol then contributes less than abs.tol even at that height, so a
  ## midpoint value cannot loosen the caller's absolute tolerance.
  midpoint <- function(lo, hi) {
    mid <- f((lo + hi) / 2)
    if (!is.finite(mid)) mid <- 0
    ## Rescaled integrands peak at or below 1. A value above 2 means the
    ## log-shift missed the mode and this panel is not a negligible tail.
    if (mid < 0 || mid > 2) {
      stop("stats::integrate() failed for nested AGHQ golden oracle", call. = FALSE)
    }
    mid * (hi - lo)
  }
  fixed_rule <- function(lo, hi) {
    est <- .golden_composite_gl(f, lo, hi)
    if (is.finite(est) && est >= 0) return(est)
    stop("stats::integrate() failed for nested AGHQ golden oracle", call. = FALSE)
  }
  attempt <- function(lo, hi, depth) {
    w <- hi - lo
    if (w == 0) return(0)
    if (w < abs.tol) return(midpoint(lo, hi))
    out <- once(lo, hi, 100L)
    if (!inherits(out, "golden_int_fail") && is.finite(out$value) && out$value >= 0) {
      return(out$value)
    }
    ## Divergent / non-finite / bad-behaviour: more subdivisions repeat the
    ## same extrapolation test. A fixed rule on this bounded window does not.
    if (inherits(out, "golden_int_fail") && hard_fail(out$message)) {
      return(fixed_rule(lo, hi))
    }
    for (sub in c(2000L, 5000L)) {
      out <- once(lo, hi, sub)
      if (!inherits(out, "golden_int_fail") && is.finite(out$value) && out$value >= 0) {
        return(out$value)
      }
      if (inherits(out, "golden_int_fail") && hard_fail(out$message)) {
        return(fixed_rule(lo, hi))
      }
    }
    if (depth <= 0) return(fixed_rule(lo, hi))
    mid_x <- (lo + hi) / 2
    attempt(lo, mid_x, depth - 1L) + attempt(mid_x, hi, depth - 1L)
  }
  attempt(lower, upper, 8L)
}

## Stable log Bernoulli pmf on the logit scale. eta may be a matrix with one
## column per quadrature node; y is recycled down each column.
## At a saturated logit, log(p) or log(1-p) is -Inf. The term whose
## coefficient is 0 must be 0, not 0 * (-Inf) = NaN, or the outer
## quadrature sees a non-finite integrand and reports divergence.
.golden_q2_log_bern <- function(y, eta) {
  eta <- as.matrix(eta)
  lp <- plogis(eta, log.p = TRUE)
  lq <- plogis(eta, lower.tail = FALSE, log.p = TRUE)
  y <- as.numeric(y)
  ly <- y * lp
  ln <- (1 - y) * lq
  ly[!is.finite(ly) & rep(y == 0, length.out = length(ly))] <- 0
  ln[!is.finite(ln) & rep((1 - y) == 0, length.out = length(ln))] <- 0
  colSums(ly + ln)
}

## Conditional mode and Laplace sd of u2 | u1. The log posterior is concave
## (Hessian <= -1), so there is one mode. A full Newton step can leave the
## region where the local Hessian is valid (a large loading saturates the
## logistic), so the step is shortened until the log posterior increases.
## The returned sd is 1/sqrt(-Hessian) and is at most 1.
.golden_q2_inner_mode <- function(u1, y, beta, lam1, lam2) {
  logpost <- function(u) {
    eta <- beta + lam1 * u1 + lam2 * u
    sum(.golden_q2_log_bern(y, eta)) + dnorm(u, log = TRUE)
  }
  u <- 0
  hess <- -1
  for (iter in seq_len(40L)) {
    eta <- beta + lam1 * u1 + lam2 * u
    p <- plogis(eta)
    score <- sum((y - p) * lam2) - u
    hess <- -sum(p * (1 - p) * lam2 * lam2) - 1
    if (!is.finite(hess) || hess >= 0) break
    delta <- score / hess
    if (!is.finite(delta)) break
    if (abs(delta) < 1e-12) break
    base <- logpost(u)
    frac <- 1
    u_try <- u
    for (bt in seq_len(30L)) {
      u_try <- u - frac * delta
      if (is.finite(u_try) && logpost(u_try) >= base - 1e-12) break
      frac <- frac / 2
    }
    if (!is.finite(u_try) || abs(u_try - u) < 1e-12) break
    u <- u_try
  }
  if (!is.finite(u)) u <- 0
  eta <- beta + lam1 * u1 + lam2 * u
  p <- plogis(eta)
  hess <- -sum(p * (1 - p) * lam2 * lam2) - 1
  if (!is.finite(hess) || hess >= 0) hess <- -1
  list(u = u, sd = 1 / sqrt(-hess))
}

## Log-integral of exp(log_f) on [-K, K]. The core is the image of
## z in about [-K, K] under u = mode + sd * z, so a narrow conditional
## ridge fills the quadrature panel instead of sitting between nodes.
## Whatever part of [-K, K] that core does not cover is integrated as a
## tail, at the same rel.tol and abs.tol. The shift is the maximum of
## log_f on the window, so the rescaled integrand peaks at 1 and does not
## underflow. rel.tol is invariant to that shift, and abs.tol becomes
## stricter whenever the peak density is below 1.
.golden_q2_log_integral <- function(log_f, mode, sd, rel.tol, abs.tol) {
  K <- .golden_q2_prior_K
  mode <- max(min(mode, K), -K)
  sd <- max(min(sd, 1), 1e-12)
  ## The shift has to be the maximum on the window. The mode is that point
  ## when Newton has converged; the endpoints cover a monotone tail whose
  ## unconstrained mode lies outside [-K, K].
  probes <- c(mode, -K, K, mode + sd * seq(-4, 4, by = 1))
  probes <- probes[is.finite(probes) & probes >= -K & probes <= K]
  probe_lv <- log_f(probes)
  probe_lv[!is.finite(probe_lv)] <- -Inf
  M <- suppressWarnings(max(probe_lv))
  if (!is.finite(M)) return(-Inf)
  ## A node whose log is not finite (saturated logit, or an inner integral
  ## that underflowed) must contribute 0, not NaN. NaN is what makes the
  ## outer integrate() report the integral as divergent or non-finite.
  ## Finite values are unchanged, so a log-shift that already peaked at 1
  ## integrates exactly as before.
  scaled <- function(u) {
    lv <- log_f(u)
    lv[!is.finite(lv)] <- -Inf
    pmax(exp(lv - M), 0)
  }
  core_lo <- max(-K, mode - K * sd)
  core_hi <- min(K, mode + K * sd)
  z_lo <- (core_lo - mode) / sd
  z_hi <- (core_hi - mode) / sd
  core <- .golden_integrate_finite(
    function(z) scaled(mode + sd * z) * sd,
    z_lo, z_hi, rel.tol, abs.tol
  )
  left <- if (core_lo > -K) {
    .golden_integrate_finite(scaled, -K, core_lo, rel.tol, abs.tol)
  } else 0
  right <- if (core_hi < K) {
    .golden_integrate_finite(scaled, core_hi, K, rel.tol, abs.tol)
  } else 0
  total <- core + left + right
  if (!is.finite(total) || total <= 0) {
    stop("stats::integrate() failed for nested AGHQ golden oracle", call. = FALSE)
  }
  M + log(total)
}

.golden_q2_inner_log <- function(u1, y, beta, Lambda, rel.tol, abs.tol) {
  lam1 <- Lambda[, 1L]
  lam2 <- Lambda[, 2L]
  md <- .golden_q2_inner_mode(u1, y, beta, lam1, lam2)
  log_h <- function(u2) {
    eta <- beta + lam1 * u1 + outer(lam2, u2)
    .golden_q2_log_bern(y, eta) + dnorm(u2, log = TRUE)
  }
  .golden_q2_log_integral(log_h, md$u, md$sd, rel.tol, abs.tol)
}

## Marginal Laplace sd of u1 from the joint Hessian at the joint mode.
## Precision is I + Lambda' W Lambda, so this sd is at most 1. It only
## places the outer core; the tails still run out to +/- K.
.golden_q2_marginal_sd <- function(y, beta, Lambda) {
  logpost <- function(u) {
    eta <- drop(beta + Lambda %*% u)
    sum(.golden_q2_log_bern(y, eta)) - sum(u * u) / 2
  }
  u <- c(0, 0)
  H <- diag(-1, 2L)
  for (iter in seq_len(40L)) {
    eta <- drop(beta + Lambda %*% u)
    p <- plogis(eta)
    sw <- sqrt(pmax(p * (1 - p), 0))
    grad <- drop(crossprod(Lambda, y - p) - u)
    H <- -crossprod(Lambda * sw, Lambda * sw) - diag(2L)
    step <- tryCatch(solve(H, grad), error = function(e) c(NA_real_, NA_real_))
    if (any(!is.finite(step))) break
    if (max(abs(step)) < 1e-12) break
    base <- logpost(u)
    frac <- 1
    u_try <- u
    for (bt in seq_len(30L)) {
      u_try <- u - frac * step
      if (all(is.finite(u_try)) && logpost(u_try) >= base - 1e-12) break
      frac <- frac / 2
    }
    if (any(!is.finite(u_try)) || max(abs(u_try - u)) < 1e-12) break
    u <- u_try
  }
  eta <- drop(beta + Lambda %*% u)
  p <- plogis(eta)
  sw <- sqrt(pmax(p * (1 - p), 0))
  H <- -crossprod(Lambda * sw, Lambda * sw) - diag(2L)
  sd <- tryCatch(sqrt(solve(-H)[1L, 1L]), error = function(e) 1)
  if (!is.finite(sd) || sd <= 0) sd <- 1
  min(sd, 1)
}

.golden_site_log_marginal_q2 <- function(y_site, beta, Lambda) {
  Lambda <- as.matrix(Lambda)
  stopifnot(nrow(Lambda) == length(y_site), ncol(Lambda) == 2L,
            length(beta) == length(y_site))
  if (!(is.numeric(y_site) || is.logical(y_site)) || is.object(y_site)) {
    stop("q2 golden oracle: observations must be plain binary values", call. = FALSE)
  }
  y_site <- as.numeric(y_site)
  if (anyNA(y_site) || !all(y_site %in% c(0, 1))) {
    stop("q2 golden oracle: observations must be plain binary values", call. = FALSE)
  }
  log_g <- function(u1) {
    vapply(u1, function(uu) {
      .golden_q2_inner_log(uu, y_site, beta, Lambda,
                           rel.tol = 1e-10, abs.tol = 1e-13) +
        dnorm(uu, log = TRUE)
    }, numeric(1))
  }
  K <- .golden_q2_prior_K
  opt <- stats::optimize(function(u) -log_g(u), interval = c(-K, K))
  sd <- .golden_q2_marginal_sd(y_site, beta, Lambda)
  value <- .golden_q2_log_integral(log_g, opt$minimum, sd,
                                   rel.tol = 1e-9, abs.tol = 1e-12)
  ## Union bound for either standard-normal coordinate leaving the square.
  ## The absolute bound cannot certify relative error for a rare event.
  ## This checks omitted prior tails, not quadrature error inside the square.
  log_tail_bound <- log(4) + pnorm(-K, log.p = TRUE)
  if (!is.finite(value) || log_tail_bound > value + log(1e-9)) {
    stop("q2 golden oracle: prior tail bound is too large relative to the integral",
         call. = FALSE)
  }
  value
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
## `aghq` IS a formal, validated argument of gllvmTMBcontrol() (see
## test-aghq-surface.R section 5, "THE CONTROL SURFACE"); this helper sets
## `ctrl$aghq <- k` on the constructed list rather than passing `aghq = k`
## through, so callers of `.golden_aghq_control(k, ...)` only need to name
## the OTHER control arguments (n_init, init_jitter, se, ...) via `...`.
## THE GOLDEN TESTS MEASURE QUADRATURE ACCURACY, so they must run the quadrature
## UNPENALISED: aghq_ridge = Inf. Two reasons, both concrete.
##
## 1. A penalised fit does not land at the maximum of the likelihood these tests
##    compare against, so "does the package's reported objective match a
##    brute-force integral at its own optimum" becomes a question about the MAP
##    point rather than about the integral. That is a different test.
## 2. At the ridge optimum the honest gradient is lambda/tau^2 ~ 0.25 against
##    grad_tol = 1e-4, so a ridge-on fit can NEVER satisfy the gradient
##    convergence leg. With the ridge left on (the shipped default), GOLDEN 2
##    fails on `all(ladder$convergence == 0L)` -- NOT on accuracy. That is the
##    MAP-point/ML-curvature defect a D-43 lens identified on 2026-07-28,
##    surfacing here as a test failure now that these tests actually run.
##
## Keeping the ridge on here would have conflated an accuracy test with a
## convergence-reporting defect. The defect is real and tracked separately; it
## does not belong inside the instrument that measures the integral.
.golden_aghq_control <- function(k, ...) {
  ctrl <- gllvmTMB::gllvmTMBcontrol(...)
  ctrl$aghq <- k
  ctrl$aghq_ridge <- Inf
  ctrl
}

## Formula used by every golden fit in this file: ordinary latent(), loadings
## only (unique = FALSE => no Psi), matching the GOLDEN 2 spec.
.golden_formula_q1 <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)

## Full end-to-end smoke test: does an actual gllvmTMB() call requesting AGHQ run
## to a finite objective, with fit$aghq$used TRUE? Probing by USING the capability
## (a real toy fit) rather than checking whether a function or argument merely
## exists, since a negative exists()/formals() check cannot prove the kernel is
## absent or ready. This is the gate the golden tests use to decide skip() vs
## run-for-real.
##
## PROBE AT k = 3, NOT k = 1 -- and this is not cosmetic. A full fit at k = 1 is
## DELIBERATELY routed to the plain-Laplace branch (k = 1 IS the Laplace
## approximation, and with the adaptation frozen as DATA the k = 1 gradient is
## missing d(logdet)/d(theta)), so fit$aghq$used is FALSE BY DESIGN there. Probing
## at k = 1 therefore could NEVER observe used = TRUE, and every accuracy test in
## this file skipped SILENTLY -- reported as "5 passed, 3 skipped" while the three
## that actually prove quadrature accuracy had never executed once. Found by a D-43
## review lens on 2026-07-28, not by the suite, because a skip is not a failure and
## nothing was watching the skip count.
##
## The lesson generalises: a capability probe must request a configuration the
## capability can actually satisfy. `.golden_gate_is_honest()` asserts exactly that.
.golden_aghq_smoke_ok <- function(dat) {
  ok <- tryCatch({
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      .golden_formula_q1, data = dat, family = binomial(), unit = "site",
      control = .golden_aghq_control(3L, n_init = 1L, init_jitter = 0, se = FALSE)
    ))
    is.finite(fit$opt$objective) && isTRUE(fit$aghq$used)
  }, error = function(e) FALSE)
  isTRUE(ok)
}

## Self-check on the GATE, so the gate cannot lie in either direction: k = 1 must
## NOT report used = TRUE (it is Laplace), and k = 3 MUST. If either flips, the
## golden tests are silently skipping or silently running against the wrong branch.
.golden_gate_is_honest <- function(dat) {
  probe <- function(k) tryCatch({
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      .golden_formula_q1, data = dat, family = binomial(), unit = "site",
      control = .golden_aghq_control(k, n_init = 1L, init_jitter = 0, se = FALSE)
    ))
    isTRUE(fit$aghq$used)
  }, error = function(e) NA)
  list(k1_used = probe(1L), k3_used = probe(3L))
}

## ---------------------------------------------------------------------
## GOLDEN 2 harness: AGHQ objective at a FIXED parameter point.
## ---------------------------------------------------------------------
##
## WHY A FIXED POINT, NOT A FRESH FITTED OPTIMUM PER k. An earlier version of
## GOLDEN 2 fitted a fresh model at each k and compared the FITTED objective
## to the oracle evaluated at that fit's OWN (different-per-k) converged
## point. That conflates two questions: "is the reported number the true
## integral AT THE POINT THE FIT LANDED ON" (accuracy -- what GOLDEN 2 exists
## to measure) and "did the outer optimiser converge" (a separate, harder
## problem on any weakly-identified GLLVM surface). It failed on the second
## while the first was fine: the error against the oracle was genuinely
## falling with k, but every fit reported convergence = 1 ("no honest
## descent at cap 1 after backtracking"), so the OLD test's
## `all(ladder$convergence == 0L)` assertion failed for a reason that had
## nothing to do with quadrature accuracy. See
## dev/aghq-evidence/02-template-vs-oracle.R, which reaches 1.2e-09 agreement
## against the same kind of oracle by evaluating at a fixed parameter vector
## instead of a fitted one.
##
## THE MECHANISM. `aghq_n_adapt = 1L` makes the AGHQ outer adaptation loop
## (R/fit-multi.R) take exactly ONE pass: it re-adapts the quadrature nodes
## at `par_cur` (the pass's starting point), evaluates the honest AGHQ
## objective F(par_cur) there, and only THEN would take an optimiser step --
## but with n_adapt capped at 1 that step's output is never used, because
## the pass loop ends before a second iteration could consume it, and
## FINALISE just re-adapts and re-evaluates at that same `par_best ==
## par_cur`. So the returned `fit$opt$par`/`fit$opt$objective` are exactly
## the AGHQ objective, quadrature nodes freshly adapted, evaluated at
## whichever point the pass started from -- with NO optimiser move in
## between. That starting point is `aghq_starts[[1]]`, the PRECEDING plain
## Laplace fit's own optimum (computed identically inside the same
## gllvmTMB() call), PROVIDED `aghq_ridge = Inf` (set by
## `.golden_aghq_control()`) so the ridge-based alternative-start selection
## never engages and `aghq_starts[[1]]` is used unconditionally.
##
## This uses the package's REAL AGHQ code path end to end -- the same
## `.gllvmTMB_aghq_grid()`/`TMB::MakeADFun()`/adaptation machinery a real
## k = 9 fit uses -- not a re-implementation; only the OUTER optimiser is
## short-circuited. What varies with k is exactly the quadrature grid, at a
## point held fixed by construction and RE-VERIFIED on every call (see
## `par_shift` below) rather than assumed.
.golden_aghq_control_fixed_point <- function(k, ...) {
  ctrl <- .golden_aghq_control(k, ...)
  ctrl$aghq_n_adapt <- 1L
  ctrl
}

## One row of the ladder: fit at (fixed-point) k, and confirm the parameter
## vector really did stay pinned at `par_fixed` (par_shift ~ 0) rather than
## assuming the mechanism above still holds.
.golden_fit_one_k_fixed_point <- function(dat, k, par_fixed, oracle_nll) {
  fit <- suppressWarnings(gllvmTMB::gllvmTMB(
    .golden_formula_q1, data = dat, family = binomial(), unit = "site",
    control = .golden_aghq_control_fixed_point(k, n_init = 1L, init_jitter = 0, se = FALSE)
  ))
  data.frame(k = k, aghq_objective = fit$opt$objective,
             oracle_nll = oracle_nll,
             abs_error = abs(fit$opt$objective - oracle_nll),
             aghq_used = isTRUE(fit$aghq$used),
             par_shift = max(abs(fit$opt$par - par_fixed)))
}

## The ladder itself: the SAME fixed point at every k, only the quadrature
## grid changes across rows.
.golden_run_ladder_q1_fixed_point <- function(dat, par_fixed, oracle_nll, ks = c(3L, 9L, 25L)) {
  do.call(rbind, lapply(ks, .golden_fit_one_k_fixed_point,
                         dat = dat, par_fixed = par_fixed, oracle_nll = oracle_nll))
}

## ---------------------------------------------------------------------
## GOLDEN 3 fixture: poisson (log link), q = 1 -- the null-control DGP.
## ---------------------------------------------------------------------
##
## Structurally the same shape as .golden_dgp_q1() (one shared N(0,1) latent
## score per site, no Psi) but poisson counts instead of bernoulli, and a
## larger, well-identified n_site (30, matching test-aghq-surface.R's own
## gaussian/binomial fixtures) since GOLDEN 3 compares two REAL fitted
## optima to each other rather than to a brute-force integral, and needs a
## non-degenerate fit on both sides for that comparison to mean anything.
.golden_poisson_data <- function(seed = 103L, n_site = 30L,
                                  beta = c(0.2, -0.1, 0.3), lambda = c(0.6, -0.5, 0.4)) {
  n_trait <- length(beta)
  stopifnot(length(beta) == length(lambda), n_site >= 1L)
  set.seed(seed)
  u <- rnorm(n_site)
  site  <- factor(rep(paste0("s", seq_len(n_site)), each = n_trait))
  trait <- factor(rep(paste0("t", seq_len(n_trait)), n_site),
                  levels = paste0("t", seq_len(n_trait)))
  eta <- beta[as.integer(trait)] + lambda[as.integer(trait)] * u[as.integer(site)]
  y <- rpois(length(eta), exp(eta))
  data.frame(site = site, trait = trait, y = y)
}
