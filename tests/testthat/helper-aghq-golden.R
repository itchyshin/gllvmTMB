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
