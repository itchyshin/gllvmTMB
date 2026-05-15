## Phase 1b 2026-05-15 item 5: 15-family fixture for
## `link_residual_per_trait()`.
##
## The function in `R/extract-sigma.R` (lines 99-300) maps each of 15
## family IDs to a per-trait latent-scale residual variance. Pre-PR #101
## the only families exercised by the test suite were Gaussian (via the
## Gaussian-only path), Beta (via test-link-residual-clamp.R), and
## betabinom (same). The other 12 families went silently — a refactor
## that broke any single branch would not have been caught.
##
## This file is the canonical fixture: one mock-fit test per family ID,
## with the expected value computed by hand from the formula in
## extract-sigma.R. The pattern mirrors test-link-residual-clamp.R and
## test-check-auto-residual.R (mock fits constructed directly; no actual
## gllvmTMB() call needed because `link_residual_per_trait()` only reads
## `fit$tmb_data$*` + `fit$report$*` + `fit$data[[fit$trait_col]]`).
##
## Family ID → formula reference (from extract-sigma.R):
##   0  gaussian             → 0
##   1  binomial logit/probit/cloglog → pi^2/3, 1, pi^2/6
##   2  poisson              → log1p(1/mu_t)
##   3  lognormal            → 0
##   4  Gamma                → trigamma(1 / sigma_eps^2)
##   5  nbinom2              → trigamma(phi_nbinom2)
##   6  tweedie              → log1p(phi * mu^(p-2))
##   7  Beta                 → trigamma(a_t) + trigamma(b_t)
##   8  betabinom            → pi^2/3 + trigamma(a_t) + trigamma(b_t)
##   9  student-t (df > 2)   → sigma^2 * df / (df - 2)
##   9  student-t (df <= 2)  → sigma^2 with warning
##   10 truncated_poisson    → log1p(1/mu_t)
##   11 truncated_nbinom2    → trigamma(phi_truncnb2)
##   12 delta_lognormal      → sigma_lognormal^2 + pi^2/3
##   13 delta_gamma          → trigamma(1/phi^2) + pi^2/3
##   14 ordinal_probit       → 1

## ---- mock-fit factory ----------------------------------------------------

make_mock_single_family_fit <- function(family_id,
                                        link_id  = 0L,
                                        n_rows   = 8L,
                                        eta      = 0,
                                        report_extra = list()) {
  trait_levels <- "y"
  base_report <- list(eta = rep(eta, n_rows))
  list(
    trait_col = "trait",
    data = data.frame(
      trait = factor(rep("y", n_rows), levels = trait_levels)
    ),
    tmb_data = list(
      family_id_vec = rep(as.integer(family_id), n_rows),
      link_id_vec   = rep(as.integer(link_id),   n_rows),
      trait_id      = rep(0L, n_rows)
    ),
    report = modifyList(base_report, report_extra)
  )
}

## ---- 0  Gaussian ---------------------------------------------------------

test_that("family_id 0 (Gaussian, identity) returns 0", {
  fit <- make_mock_single_family_fit(family_id = 0L)
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), 0)
})

## ---- 1  Binomial (3 links) ---------------------------------------------

test_that("family_id 1 (binomial, logit link_id 0) returns pi^2 / 3", {
  fit <- make_mock_single_family_fit(family_id = 1L, link_id = 0L)
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), pi^2 / 3, tolerance = 1e-12)
})

test_that("family_id 1 (binomial, probit link_id 1) returns 1", {
  fit <- make_mock_single_family_fit(family_id = 1L, link_id = 1L)
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), 1)
})

test_that("family_id 1 (binomial, cloglog link_id 2) returns pi^2 / 6", {
  fit <- make_mock_single_family_fit(family_id = 1L, link_id = 2L)
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), pi^2 / 6, tolerance = 1e-12)
})

## ---- 2  Poisson ----------------------------------------------------------

test_that("family_id 2 (poisson, log link) returns log1p(1 / mu_t)", {
  ## eta = log(5) -> mu_t = 5 -> log1p(1/5) = log(1.2)
  fit <- make_mock_single_family_fit(
    family_id = 2L,
    eta       = log(5)
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), log(1.2), tolerance = 1e-12)
})

## ---- 3  Lognormal --------------------------------------------------------

test_that("family_id 3 (lognormal) returns 0", {
  fit <- make_mock_single_family_fit(family_id = 3L)
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), 0)
})

## ---- 4  Gamma ------------------------------------------------------------

test_that("family_id 4 (Gamma, log link) returns trigamma(1 / sigma_eps^2)", {
  ## sigma_eps = 0.5 -> shape nu = 1 / 0.25 = 4 -> trigamma(4)
  fit <- make_mock_single_family_fit(
    family_id    = 4L,
    report_extra = list(sigma_eps = 0.5)
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), trigamma(4), tolerance = 1e-12)
})

## ---- 5  NB2 --------------------------------------------------------------

test_that("family_id 5 (nbinom2) returns trigamma(phi_nbinom2)", {
  fit <- make_mock_single_family_fit(
    family_id    = 5L,
    report_extra = list(phi_nbinom2 = 2)
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), trigamma(2), tolerance = 1e-12)
})

test_that("family_id 5 (nbinom2) clamps phi at 1e-12 (defence-in-depth)", {
  fit <- make_mock_single_family_fit(
    family_id    = 5L,
    report_extra = list(phi_nbinom2 = -1)  # implausible; should clamp
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_true(is.finite(res))
  expect_equal(unname(res), trigamma(1e-12), tolerance = 0)
})

## ---- 6  Tweedie ----------------------------------------------------------

test_that("family_id 6 (tweedie) returns log1p(phi * mu^(p-2))", {
  ## eta = log(2) -> mu = 2; phi = 1; p = 1.5
  ## phi * mu^(p-2) = 1 * 2^(-0.5) = 1/sqrt(2)
  ## expected = log1p(1/sqrt(2))
  fit <- make_mock_single_family_fit(
    family_id    = 6L,
    eta          = log(2),
    report_extra = list(phi_tweedie = 1, p_tweedie = 1.5)
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), log1p(1 / sqrt(2)), tolerance = 1e-12)
})

## ---- 7  Beta -------------------------------------------------------------

test_that("family_id 7 (Beta) returns trigamma(a) + trigamma(b) at eta = 0", {
  ## eta = 0 -> mu = 0.5; phi = 4; a = b = 2
  ## expected = trigamma(2) + trigamma(2)
  fit <- make_mock_single_family_fit(
    family_id    = 7L,
    eta          = 0,
    report_extra = list(phi_beta = 4)
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), 2 * trigamma(2), tolerance = 1e-12)
})

## ---- 8  Betabinom --------------------------------------------------------

test_that("family_id 8 (betabinom) returns pi^2/3 + trigamma(a) + trigamma(b) at eta = 0", {
  ## eta = 0 -> mu = 0.5; phi = 4; a = b = 2
  fit <- make_mock_single_family_fit(
    family_id    = 8L,
    eta          = 0,
    report_extra = list(phi_betabinom = 4)
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res),
               pi^2 / 3 + 2 * trigamma(2),
               tolerance = 1e-12)
})

## ---- 9  Student-t --------------------------------------------------------

test_that("family_id 9 (student-t, df > 2) returns sigma^2 * df / (df - 2)", {
  ## sigma = 1, df = 4 -> 1 * 4 / 2 = 2
  fit <- make_mock_single_family_fit(
    family_id    = 9L,
    report_extra = list(sigma_student = 1, df_student = 4)
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), 2)
})

test_that("family_id 9 (student-t, df = 2) warns and falls back to sigma^2", {
  fit <- make_mock_single_family_fit(
    family_id    = 9L,
    report_extra = list(sigma_student = 1.5, df_student = 2)
  )
  expect_warning(
    res <- gllvmTMB:::link_residual_per_trait(fit),
    "Student-t df"
  )
  expect_equal(unname(res), 1.5^2)
})

## ---- 10 Truncated Poisson ------------------------------------------------

test_that("family_id 10 (truncated_poisson) returns log1p(1 / mu_t)", {
  fit <- make_mock_single_family_fit(
    family_id = 10L,
    eta       = log(5)
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), log(1.2), tolerance = 1e-12)
})

## ---- 11 Truncated NB2 ----------------------------------------------------

test_that("family_id 11 (truncated_nbinom2) returns trigamma(phi_truncnb2)", {
  fit <- make_mock_single_family_fit(
    family_id    = 11L,
    report_extra = list(phi_truncnb2 = 3)
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), trigamma(3), tolerance = 1e-12)
})

## ---- 12 Delta-lognormal --------------------------------------------------

test_that("family_id 12 (delta_lognormal) returns sigma^2 + pi^2/3", {
  fit <- make_mock_single_family_fit(
    family_id    = 12L,
    report_extra = list(sigma_lognormal_delta = 0.5)
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), 0.25 + pi^2 / 3, tolerance = 1e-12)
})

## ---- 13 Delta-gamma ------------------------------------------------------

test_that("family_id 13 (delta_gamma) returns trigamma(1/phi^2) + pi^2/3", {
  ## phi = 0.5 -> shape = 1 / 0.25 = 4 -> trigamma(4) + pi^2/3
  fit <- make_mock_single_family_fit(
    family_id    = 13L,
    report_extra = list(phi_gamma_delta = 0.5)
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res),
               trigamma(4) + pi^2 / 3,
               tolerance = 1e-12)
})

## ---- 14 Ordinal-probit ---------------------------------------------------

test_that("family_id 14 (ordinal_probit) returns exactly 1", {
  fit <- make_mock_single_family_fit(family_id = 14L)
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(res), 1)
})

## ---- vector shape: per-trait output --------------------------------------

test_that("link_residual_per_trait() returns a per-trait vector named by trait levels", {
  ## Three traits, each from a different family.
  fit <- list(
    trait_col = "trait",
    data = data.frame(
      trait = factor(rep(c("y1", "y2", "y3"), each = 4L),
                     levels = c("y1", "y2", "y3"))
    ),
    tmb_data = list(
      family_id_vec = c(rep(0L, 4L),   # Gaussian -> 0
                        rep(1L, 4L),   # binomial logit -> pi^2/3
                        rep(2L, 4L)),  # poisson -> log1p(1/mu_t)
      link_id_vec   = rep(0L, 12L),
      trait_id      = c(rep(0L, 4L), rep(1L, 4L), rep(2L, 4L))
    ),
    report = list(eta = c(rep(0, 4L),  rep(0, 4L), rep(log(5), 4L)))
  )
  res <- gllvmTMB:::link_residual_per_trait(fit)
  expect_length(res, 3L)
  expect_equal(names(res), c("y1", "y2", "y3"))
  expect_equal(unname(res[1]), 0)
  expect_equal(unname(res[2]), pi^2 / 3, tolerance = 1e-12)
  expect_equal(unname(res[3]), log(1.2), tolerance = 1e-12)
})
