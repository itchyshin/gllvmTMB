## Tests for eval_method = "ac2" (inst/tmb/gllvmTMB_va_r3.cpp,
## va_r3_probit_ac2_expectation), the curvature-corrected sibling of "ac".
##
## Diagnosis being tested: "ac" (va_r3_probit_ac_expectation) hard-codes BOTH
## second derivatives of the probit log-likelihood to their worst-case value
## -1, over-charging the variance penalty by up to pi/2 = 1.571x. "ac2" uses
## the EXACT mu-dependent curvature instead
##   (log Phi(mu))''    = -h(mu) (mu + h(mu)),  h(mu) = phi(mu)/Phi(mu)
##   (log(1-Phi(mu)))'' =  g(mu) (mu - g(mu)),  g(mu) = phi(mu)/(1-Phi(mu))
## a standard second-order delta-method expansion of E_q[log p] for
## eta ~ N(mu, v) (Hui, Warton, Ormerod et al. 2017, JCGS).
##
## Two independent checks:
##   1. PRIMARY (this is what the task asked for): a pure R-level grid check
##      against a high-order numerical quadrature "truth" -- stats::integrate()
##      (adaptive Gauss-Kronrod), deliberately NOT the package's own 61-node
##      Gauss-Hermite tier, so there is no circularity between the oracle and
##      the "gh" tier ac2 is ultimately trying to approximate.
##   2. SECONDARY (regression guard beyond the letter of the task): builds
##      ONE tiny real VA-R3 objective and reads the COMPILED C++ function's
##      actual output via REPORT(), cross-checked against the same formula.
##      This is the only check here that would catch a transcription bug
##      between the verified math and the shipped C++ (check 1 alone would
##      not, since it never touches the compiled DLL).
##
## ac2 is NOT a proven ELBO lower bound (see the C++ comment beside
## va_r3_probit_ac2_expectation and R/va-r3-proto.R's .va_r3_objective_type,
## which labels it "APPROX_AC2" rather than "ELBO_AC2" for exactly this
## reason) -- so this file asserts ac2 is CLOSER to the truth than ac, never
## that it falls on a particular side of it.

skip_on_cran()

## ---------------------------------------------------------------------
## Section 1 -- primary grid check (R-level, independent quadrature oracle).
## ---------------------------------------------------------------------

## High-order numerical quadrature of the TRUE E_q[log p(y|eta)],
## eta ~ N(mu, v), y in {0, n}. stats::integrate() is adaptive Gauss-Kronrod
## quadrature -- a different algorithm family from the package's own
## fixed-node Gauss-Hermite rule, so agreement between "gh" and this oracle
## (checked implicitly below: ac2 tracks this oracle much more closely than
## ac does) is not circular.
.ac2_truth <- function(mu, v, y, n = 1) {
  sd <- sqrt(v)
  integrand <- function(eta) {
    g <- y * pnorm(eta, log.p = TRUE) + (n - y) * pnorm(-eta, log.p = TRUE)
    g * dnorm(eta, mean = mu, sd = sd)
  }
  stats::integrate(integrand, lower = -Inf, upper = Inf,
                    rel.tol = 1e-12, subdivisions = 500L)
}

## R mirror of va_r3_probit_ac_expectation (inst/tmb/gllvmTMB_va_r3.cpp) --
## the EXISTING, unmodified "ac" branch, for comparison only.
.ac2_ac_value <- function(mu, v, y, n = 1) {
  y * pnorm(mu, log.p = TRUE) + (n - y) * pnorm(-mu, log.p = TRUE) - n * v / 2
}

## R mirror of va_r3_probit_ac2_expectation (inst/tmb/gllvmTMB_va_r3.cpp).
## Uses the same log-space-stable Mills-ratio identity the C++ helper
## va_r3_inv_mills relies on (h = exp(dnorm_log(mu) - log_pnorm(mu))): R's
## own dnorm/pnorm(log.p = TRUE) resolve to the same Rmath.h primitives TMB
## calls for Type = double, so this is not a second, independent numerical
## method -- it is the SAME identity, re-expressed in R for testing.
.ac2_ac2_value <- function(mu, v, y, n = 1) {
  h <- exp(dnorm(mu, log = TRUE) - pnorm(mu, log.p = TRUE))
  g <- exp(dnorm(mu, log = TRUE) - pnorm(-mu, log.p = TRUE))
  d2_log_p <- -h * (mu + h)
  d2_log_1mp <- g * (mu - g)
  y * pnorm(mu, log.p = TRUE) + (n - y) * pnorm(-mu, log.p = TRUE) +
    v * (y * d2_log_p + (n - y) * d2_log_1mp) / 2
}

.ac2_grid <- expand.grid(
  mu = c(-3, -2, -1, -0.5, 0, 0.5, 1, 2, 3),
  v  = c(0.05, 0.2, 0.5, 1.0),
  y  = c(0, 1)
)

test_that("ac2 grid: quadrature truth is itself reliable (self-check on the oracle)", {
  errs <- mapply(function(mu, v, y) .ac2_truth(mu, v, y)$abs.error,
                  .ac2_grid$mu, .ac2_grid$v, .ac2_grid$y)
  ## integrate()'s own reported error must be far below any difference this
  ## file measures between ac/ac2 and the truth (those start around 1e-7,
  ## see the tolerance rationale below) -- otherwise the oracle itself would
  ## not be trustworthy at the precision this test relies on.
  expect_lt(max(errs), 1e-8)
})

test_that("ac2 is closer to the quadrature truth than ac, in EVERY grid cell", {
  truth <- mapply(function(mu, v, y) .ac2_truth(mu, v, y)$value,
                   .ac2_grid$mu, .ac2_grid$v, .ac2_grid$y)
  ac  <- mapply(.ac2_ac_value,  .ac2_grid$mu, .ac2_grid$v, .ac2_grid$y)
  ac2 <- mapply(.ac2_ac2_value, .ac2_grid$mu, .ac2_grid$v, .ac2_grid$y)

  err_ac  <- abs(ac  - truth)
  err_ac2 <- abs(ac2 - truth)
  closer <- err_ac2 < err_ac

  ## Report the failing cells explicitly rather than a bare TRUE/FALSE --
  ## measured on 2026-08-05, all 72/72 cells pass, with err_ac2/err_ac
  ## ranging 1.4e-05 to 0.089 (median 0.016), so this has comfortable margin,
  ## not a knife-edge result. If a future change regresses it, this message
  ## names the exact (mu, v, y) cell(s), not just "some cell failed".
  if (!all(closer)) {
    bad <- which(!closer)
    msg <- paste(sprintf(
      "mu=%.1f v=%.2f y=%d: err_ac=%.6g err_ac2=%.6g (ac2 NOT closer)",
      .ac2_grid$mu[bad], .ac2_grid$v[bad], .ac2_grid$y[bad],
      err_ac[bad], err_ac2[bad]), collapse = "\n")
    testthat::fail(paste0(sum(!closer), "/", length(closer),
                           " cells: ac2 was not closer to truth than ac:\n", msg))
  } else {
    expect_true(all(closer))
  }
})

test_that("ac2 matches the quadrature truth to a stated tolerance for small v", {
  ## "Small v" = v = 0.05, the smallest grid value. Rationale for 1e-4:
  ## ac2's leading truncation error is the NEXT (4th-derivative) term of the
  ## delta-method expansion, O(v^2) by construction (the same argument
  ## va_r3_probit_expectation's own small-v branch documents for its
  ## analogous truncation, inst/tmb/gllvmTMB_va_r3.cpp). Measured on this
  ## grid at v = 0.05 (18 cells: 9 mu x 2 y), max|ac2 - truth| = 5.76e-05;
  ## the O(v^2) scaling was confirmed directly (e.g. at mu = -3, y = 0, the
  ## error ratio between v = 0.2 and v = 0.05 is 16.4x for a 4x v-ratio,
  ## against the 16x an exact v^2 law predicts). 1e-4 sits comfortably above
  ## the observed maximum (~1.7x) without being so loose it would miss a
  ## real regression.
  small_v <- .ac2_grid$v == 0.05
  truth <- mapply(function(mu, v, y) .ac2_truth(mu, v, y)$value,
                   .ac2_grid$mu[small_v], .ac2_grid$v[small_v], .ac2_grid$y[small_v])
  ac2 <- mapply(.ac2_ac2_value,
                .ac2_grid$mu[small_v], .ac2_grid$v[small_v], .ac2_grid$y[small_v])
  expect_lt(max(abs(ac2 - truth)), 1e-4)
})

## ---------------------------------------------------------------------
## Section 2 -- compiled-DLL cross-check (regression guard on the actual
## shipped C++, not just the R-level mirror above). Mirrors the fixture
## style of test-va-r3-ai-collapse.R's .va_r3_ai_sim()/.va_r3_ai_obj().
## ---------------------------------------------------------------------

.ac2_sim <- function(N = 25L, Tn = 6L, q = 1L, n_trials = 1L, seed = 4L) {
  set.seed(seed)
  lam <- matrix(stats::rnorm(Tn * q, 0, 0.8), Tn, q)
  a <- matrix(stats::rnorm(N * q), N, q)
  eta <- sweep(a %*% t(lam), 2, stats::rnorm(Tn, 0, 0.3), "+")
  d <- data.frame(y = stats::rbinom(N * Tn, n_trials, stats::pnorm(as.vector(eta))),
                  unit = rep(seq_len(N), times = Tn),
                  trait = rep(seq_len(Tn), each = N))
  list(y = d$y, n_trials = rep(n_trials, nrow(d)),
       X = unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(Tn)))),
       unit_id = d$unit, trait_id = d$trait, q = q,
       family = "binomial_probit", link = "probit")
}

test_that("compiled ac2 output matches its formula exactly, at real emitted (mu, v)", {
  skip_on_cran()
  a <- .ac2_sim()
  vd <- do.call(gllvmTMB:::.va_r3_validate_data,
                a[intersect(names(a), names(formals(gllvmTMB:::.va_r3_validate_data)))])

  obj_ac  <- gllvmTMB:::.va_r3_make_objective(vd, H = 15L, eval_method = "ac")
  obj_ac2 <- gllvmTMB:::.va_r3_make_objective(vd, H = 15L, eval_method = "ac2")

  ## Same latent structure -> identical parameter vector shape across tiers
  ## (the derivation's own alignment-table requirement for "ac", carried over
  ## to "ac2" since it shares the same closed-form skeleton).
  expect_identical(names(obj_ac$par), names(obj_ac2$par))

  par0 <- obj_ac2$par
  expect_true(is.finite(obj_ac2$fn(par0)))
  expect_true(all(is.finite(obj_ac2$gr(par0))))
  expect_true(all(is.finite(obj_ac2$he(par0))))

  ## Dispatch sanity: eval_method = "ac2" must not silently alias to "ac".
  expect_false(isTRUE(all.equal(obj_ac$fn(par0), obj_ac2$fn(par0))))

  ## The direct cross-check: the COMPILED expected_loglik_by_obs against the
  ## R mirror of va_r3_probit_ac2_expectation, evaluated at the mu/v the
  ## compiled code itself reports -- not a target grid, but real output.
  ## n_trials = 1 everywhere, so log_choose = 0 and expected_loglik_by_obs
  ## equals the probit_expectation value directly.
  rep_ac2 <- obj_ac2$report(par0)
  mirror <- .ac2_ac2_value(rep_ac2$mu_by_obs, rep_ac2$v_by_obs, vd$y, vd$n_trials)
  expect_lt(max(abs(rep_ac2$expected_loglik_by_obs - mirror)), 1e-10)

  ## Regression check: "ac" itself is untouched (byte-identical function
  ## body; this confirms its COMPILED behaviour is also unaffected).
  rep_ac <- obj_ac$report(par0)
  ac_mirror <- .ac2_ac_value(rep_ac$mu_by_obs, rep_ac$v_by_obs, vd$y, vd$n_trials)
  expect_equal(rep_ac$expected_loglik_by_obs, ac_mirror, tolerance = 0)
})

test_that("eval_method = \"ac2\" is wired through the registry exactly like \"ac\"", {
  ## family_code = 4L is binomial_probit's registry code (R/va-r3-proto.R),
  ## the same value .va_r3_resolve_eval_method()/.va_r3_eval_method_code()
  ## expect as `family` -- a per-row integer code vector (validated$family),
  ## not the family NAME string.
  expect_identical(gllvmTMB:::.va_r3_resolve_eval_method("ac2", 4L), "ac2")
  expect_identical(gllvmTMB:::.va_r3_eval_method_code("ac2", 4L), 3L)
  expect_identical(gllvmTMB:::.va_r3_objective_type("ac2"), "APPROX_AC2")

  ## Same single-family restriction as "ac" (dev/va-speed/ALBERT-CHIB-DERIVATION.md
  ## s4.1's scope caveat applies identically -- ac2 shares the closed-form skeleton).
  expect_error(
    gllvmTMB:::.va_r3_resolve_eval_method("ac2", c(1L, 4L)),
    "only defined for pure binomial-probit"
  )

  entry <- gllvmTMB:::.va_r3_family_entry(4L)
  expect_true("ac2" %in% entry$tiers)
  expect_identical(entry$optimizer_by_tier$ac2, "nlminb")

  ## "ac" itself must be completely unaffected by adding "ac2".
  expect_identical(gllvmTMB:::.va_r3_resolve_eval_method("ac", 4L), "ac")
  expect_identical(gllvmTMB:::.va_r3_eval_method_code("ac", 4L), 2L)
  expect_identical(gllvmTMB:::.va_r3_objective_type("ac"), "ELBO_AC")
})
