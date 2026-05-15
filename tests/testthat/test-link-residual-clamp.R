## Tests for the Phase 1b mu_t clamp in `link_residual_per_trait()`.
##
## Pre-fix behaviour (before 2026-05-15 PR): a saturated Beta or
## betabinom fit (eta -> +/- Inf, so plogis(eta) -> 0 or 1) collapsed
## one of (a_t, b_t) to the 1e-12 floor, making trigamma(1e-12) ~ 1e24
## and crushing any reported correlation to ~0.
##
## Post-fix behaviour: mu_t is clamped to [1e-6, 1 - 1e-6] BEFORE
## forming a_t, b_t. The fit's degeneracy is now flagged numerically
## (a large but finite trigamma value) rather than silently producing
## meaningless correlations.
##
## Gauss persona consult 2026-05-14 (captured in
## `docs/dev-log/after-task/2026-05-14-phase-1a-batch-d.md`) named this
## as a correctness footgun to fix before shipping
## `extract_correlations(link_residual = "auto")` as the default.

## ---- mock fit constructor ---------------------------------------------------
## `link_residual_per_trait()` is an unexported helper that takes a fitted
## `gllvmTMB_multi` object and reads:
##   - fit$trait_col, fit$data[[trait_col]] (factor with levels = trait names)
##   - fit$tmb_data$family_id_vec, $link_id_vec, $trait_id (0-based)
##   - fit$report$eta
##   - fit$report$phi_beta or $phi_betabinom (for the families we test)
## We mock the minimum surface for two families.

make_mock_beta_fit <- function(eta_value, phi_beta = 5, n_rows = 8) {
  trait_levels <- "y"
  list(
    trait_col = "trait",
    data = data.frame(
      trait = factor(rep("y", n_rows), levels = trait_levels)
    ),
    tmb_data = list(
      family_id_vec = rep(7L, n_rows),    # Beta
      link_id_vec   = rep(0L, n_rows),    # logit
      trait_id      = rep(0L, n_rows)     # 0-based
    ),
    report = list(
      eta      = rep(eta_value, n_rows),
      phi_beta = phi_beta
    )
  )
}

make_mock_betabinom_fit <- function(eta_value, phi_bb = 5, n_rows = 8) {
  trait_levels <- "y"
  list(
    trait_col = "trait",
    data = data.frame(
      trait = factor(rep("y", n_rows), levels = trait_levels)
    ),
    tmb_data = list(
      family_id_vec = rep(8L, n_rows),    # betabinom
      link_id_vec   = rep(0L, n_rows),    # logit
      trait_id      = rep(0L, n_rows)
    ),
    report = list(
      eta            = rep(eta_value, n_rows),
      phi_betabinom  = phi_bb
    )
  )
}

## ---- Beta saturation -------------------------------------------------------

test_that("Beta link residual is finite for saturated eta (mu_t clamp works)", {
  fit_sat_high <- make_mock_beta_fit(eta_value = 20, phi_beta = 5)
  fit_sat_low  <- make_mock_beta_fit(eta_value = -20, phi_beta = 5)
  res_high <- gllvmTMB:::link_residual_per_trait(fit_sat_high)
  res_low  <- gllvmTMB:::link_residual_per_trait(fit_sat_low)
  ## Pre-clamp these would have been trigamma(1e-12) ~ 1e24.
  ## Post-clamp at mu_t in [1e-6, 1 - 1e-6] with phi = 5:
  ## one of (a_t, b_t) is ~ 5 * 1e-6 = 5e-6, giving trigamma(5e-6) ~ 4e10.
  ## The other is ~ 5 * (1 - 1e-6) = 5, giving trigamma(5) ~ 0.22.
  ## Sum is finite and well below 1e11.
  expect_true(is.finite(res_high))
  expect_true(is.finite(res_low))
  expect_lt(res_high, 1e11)
  expect_lt(res_low,  1e11)
  ## Symmetry of the clamp: saturating high vs low should give the same
  ## numerical residual (because trigamma is symmetric in a_t, b_t).
  expect_equal(res_high, res_low, tolerance = 1e-9)
})

test_that("Beta link residual matches the closed form for mid mu (eta = 0)", {
  fit_mid <- make_mock_beta_fit(eta_value = 0, phi_beta = 5)
  res <- gllvmTMB:::link_residual_per_trait(fit_mid)
  ## mu_t = plogis(0) = 0.5; phi = 5; a_t = b_t = 2.5.
  ## Var(logit Y) = trigamma(2.5) + trigamma(2.5).
  expected <- 2 * trigamma(2.5)
  expect_equal(unname(res), expected, tolerance = 1e-9)
})

## ---- betabinom saturation --------------------------------------------------

test_that("betabinom link residual is finite for saturated eta (mu_t clamp)", {
  fit_sat <- make_mock_betabinom_fit(eta_value = 20, phi_bb = 5)
  res <- gllvmTMB:::link_residual_per_trait(fit_sat)
  ## Pre-clamp: pi^2/3 + trigamma(1e-12) ~ 1e24. Post-clamp: bounded.
  expect_true(is.finite(res))
  expect_lt(res, 1e11)
  ## Must be at least the binomial-logit baseline pi^2 / 3.
  expect_gt(res, pi^2 / 3 - 1e-9)
})

test_that("betabinom link residual matches closed form for mid mu (eta = 0)", {
  fit_mid <- make_mock_betabinom_fit(eta_value = 0, phi_bb = 5)
  res <- gllvmTMB:::link_residual_per_trait(fit_mid)
  ## pi^2 / 3 + 2 * trigamma(2.5)
  expected <- pi^2 / 3 + 2 * trigamma(2.5)
  expect_equal(unname(res), expected, tolerance = 1e-9)
})
