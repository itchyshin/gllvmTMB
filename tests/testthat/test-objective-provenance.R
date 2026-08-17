## #25 (Ayumi B3): objective provenance. `report$joint_nll_unpenalized` /
## `report$joint_nll_penalized` (src/gllvmTMB.cpp:3327, :3460) are conditional
## joint quantities computed on the TMB tape; they see only TMB-side (MSPL)
## penalties, gated by `estimator_id == 1` (`estimator = "mspl"`), and NEVER
## see the R-level `aghq_ridge` loading ridge (applied outside the TMB
## objective -- see `.gllvmTMB_penalised_gradient()`, #1092).
## `fit$objective_components` (R/fit-multi.R:304, `.gllvmTMB_objective_
## components()`) is the marginal surface and the only place the ridge
## appears: `likelihood_nll` / `ridge_penalty` / `optimization_nll` /
## `optimizer_reported`. The two surfaces are not expected to match, and
## their difference is not an error -- this is now documented in
## `?gllvmTMB`'s "Objective provenance" section. This test file checks the
## documented contract, not the C++ fields' computation (unchanged).

.op_bernoulli_fit <- function(ridge = Inf, seed = 811L, n = 30L, p = 3L) {
  set.seed(seed)
  L <- matrix(stats::rnorm(p), p, 1L)
  u <- stats::rnorm(n)
  eta <- outer(u, as.numeric(L))
  Y <- matrix(stats::rbinom(n * p, 1, stats::plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  dat <- as.data.frame(Y)
  dat$site <- factor(seq_len(n))
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(sp1, sp2, sp3) ~ 1 + latent(1 | site, d = 1),
    data = dat,
    family = stats::binomial(),
    control = gllvmTMB::gllvmTMBcontrol(
      aghq_ridge = ridge, se = FALSE, warn_runaway = FALSE
    )
  )))
}

test_that("#25 B3: an unridged fit has zero ridge_penalty and optimization_nll == likelihood_nll", {
  skip_on_cran()
  fit <- .op_bernoulli_fit(ridge = Inf)
  expect_false(isTRUE(fit$aghq$penalised))
  oc <- fit$objective_components
  expect_identical(oc$ridge_penalty, 0)
  expect_equal(oc$optimization_nll, oc$likelihood_nll, tolerance = 0)
})

test_that("#25 B3: a ridged fit's marginal surface carries the ridge; the tape does not see it", {
  skip_on_cran()
  fit <- .op_bernoulli_fit(ridge = 2)
  expect_true(isTRUE(fit$aghq$penalised))
  expect_identical(fit$aghq$ridge_tau, 2)

  oc <- fit$objective_components
  expect_gt(oc$ridge_penalty, 0)
  expect_equal(
    oc$optimization_nll,
    oc$likelihood_nll + oc$ridge_penalty,
    tolerance = 0
  )

  ## THE documented non-identity: the TMB tape's conditional-joint quantities
  ## never see the R-level ridge, so unpenalized == penalized on this
  ## default `estimator = "ml"` fit (estimator_id == 0, so the C++ MSPL block
  ## that would otherwise separate them never runs either).
  expect_identical(
    fit$report$joint_nll_penalized,
    fit$report$joint_nll_unpenalized
  )
})

test_that("#25 B3: optimizer_reported agrees with optimization_nll for a ridged Laplace fit", {
  skip_on_cran()
  fit <- .op_bernoulli_fit(ridge = 2, seed = 812L)
  oc <- fit$objective_components
  expect_equal(oc$optimizer_reported, oc$optimization_nll, tolerance = 1e-6)
})
