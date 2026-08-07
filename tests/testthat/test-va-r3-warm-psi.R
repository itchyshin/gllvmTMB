## The warm route (.va_r3_fit_warm) must not inherit AC's psi collapse.
##
## This is a REGRESSION test for a defect that survived because the original
## evidence could not see it. `dev/va-speed/13-warmstart-gh.R` validated the warm
## route on a DGP that plants NO psi (its `eta` has no `u` term) while still
## fitting `unique = TRUE`, and its log had no psi column. On that data,
## collapsing psi to zero IS the right answer, so the failure was invisible.
##
## Measured at psi = 0.6, the unfixed route returned psi ~ 1e-4 where cold GH
## returned ~0.6, and landed 19-52 nats worse. See
## dev/va-speed/25-WARM-ROUTE-PSI-FINDING.md.
##
## The rule this encodes: TEST THE VARIANCE ON DATA THAT HAS ONE. A loadings-only
## score cannot see a collapsed variance -- in the measurements above the
## COLLAPSING arm actually scored BETTER on rel_frob, because variance denied to
## psi is absorbed into the loadings.

.va_r3_warm_psi_sim <- function(N = 60L, T = 8L, q = 1L, n_trials = 6L,
                                psi = 0.6, seed = 1L) {
  set.seed(seed)
  lam <- matrix(stats::rnorm(T * q, 0, 0.8), T, q)
  lam[upper.tri(lam)] <- 0
  a <- matrix(stats::rnorm(N * q), N, q)
  u <- matrix(stats::rnorm(N * T, 0, psi), N, T)   # <- the psi the test exists for
  eta <- sweep(a %*% t(lam), 2, stats::rnorm(T, 0, 0.3), "+") + u
  d <- data.frame(y = stats::rbinom(N * T, n_trials, stats::pnorm(as.vector(eta))),
                  unit = rep(seq_len(N), times = T),
                  trait = rep(seq_len(T), each = N))
  list(args = list(y = d$y, n_trials = rep(n_trials, nrow(d)),
                   X = unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T)))),
                   unit_id = d$unit, trait_id = d$trait, q = q,
                   family = "binomial_probit", link = "probit",
                   unique = TRUE, profile_variational = TRUE),
       truth_psi = psi)
}

.va_r3_warm_psi_of <- function(par) {
  stats::median(exp(par[names(par) == "log_sd_tier"]))
}

test_that("the warm route recovers a planted psi instead of collapsing it", {
  skip_on_cran()
  sim <- .va_r3_warm_psi_sim()
  fit <- do.call(gllvmTMB:::.va_r3_fit_warm,
                 c(sim$args, list(H = 15L,
                                  control = list(eval.max = 800L, iter.max = 400L))))
  psi_hat <- .va_r3_warm_psi_of(fit$best$par)

  ## The defect returned psi ~ 1e-4 against a planted 0.6. A generous floor is
  ## used deliberately: this asserts "did not COLLAPSE", not "estimated well".
  expect_gt(psi_hat, 0.25)
  expect_true(is.finite(fit$best$objective))
})

test_that("the warm route lands on the same optimum as cold GH", {
  skip_on_cran()
  sim <- .va_r3_warm_psi_sim()
  ctl <- list(eval.max = 800L, iter.max = 400L)
  warm <- do.call(gllvmTMB:::.va_r3_fit_warm, c(sim$args, list(H = 15L, control = ctl)))
  cold <- do.call(gllvmTMB:::.va_r3_fit,
                  c(sim$args, list(eval_method = "gh", n_starts = 1L, H = 15L, control = ctl)))

  ## With the boundary reset in place these agreed to 4-5 significant figures at
  ## N=100/T=10. Without it the warm arm was 19-52 nats worse, so a loose
  ## relative tolerance still separates fixed from broken.
  expect_equal(warm$best$objective, cold$best$objective, tolerance = 1e-3)
  expect_equal(.va_r3_warm_psi_of(warm$best$par),
               .va_r3_warm_psi_of(cold$best$par), tolerance = 0.1)
})
