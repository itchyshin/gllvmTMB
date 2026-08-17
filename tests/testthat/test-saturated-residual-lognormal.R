## #1083: `gllvmTMB_conditional_residual_saturated` was gated to
## `family_id == 0L` (gaussian) only, even though gaussian and lognormal
## share ONE literal `sigma_eps` and are auto-suppressed identically at
## fit time when a diagonal random effect is indexed at the observed
## (unit x trait) resolution (R/fit-multi.R:5177,
## `any_sigma_eps <- any(family_id_vec %in% c(0L, 3L))`). The gate at
## R/predictive-diagnostics.R:423 is widened to `family_id %in% c(0L, 3L)`
## to stay consistent with that fit-time decision.
##
## NOTE: the fixture-construction premise behind #1083 was itself partly
## wrong -- `sigma_eps` fit to ~0.0007 is the *deliberate*, announced
## suppression constant (~1e-3 * sd(y)), not a silent collapse. See
## docs/dev-log/2026-08-17-sigma-eps-suppression-not-a-defect.md. The real
## gap closed here is narrower: the RESIDUALS-time warning did not fire for
## lognormal even though the identical structural mechanism applies.

make_saturating_lognormal_fit <- function(seed = 1L) {
  set.seed(seed)
  n_ind <- 36L
  Tn <- 2L
  trait_names <- c("a", "b")
  u <- stats::rnorm(n_ind, sd = 0.35)
  eta <- cbind(0.2 + u, -0.15 + 0.7 * u)
  sigma_true <- 0.4
  y <- exp(eta + matrix(stats::rnorm(n_ind * Tn, sd = sigma_true), n_ind, Tn))

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )

  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    ## Default `unique = TRUE`: adds the diagonal Psi random effect at the
    ## observed (individual x trait) resolution -- one row per cell.
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df,
    unit = "individual",
    family = gllvmTMB::lognormal()
  )))
}

make_nonsaturating_lognormal_fit <- function(seed = 1L) {
  set.seed(seed)
  n_ind <- 36L
  Tn <- 2L
  trait_names <- c("a", "b")
  u <- stats::rnorm(n_ind, sd = 0.35)
  eta <- cbind(0.2 + u, -0.15 + 0.7 * u)
  sigma_true <- 0.4
  y <- exp(eta + matrix(stats::rnorm(n_ind * Tn, sd = sigma_true), n_ind, Tn))

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )

  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    ## `unique = FALSE`: rotation-invariant loadings-only latent term, no
    ## diagonal Psi random effect at all -- `object$use$diag_B` /
    ## `object$use$diag_W` stay FALSE, so the structural condition the
    ## warning checks for is absent.
    value ~ 0 + trait + latent(0 + trait | individual, d = 1, unique = FALSE),
    data = df,
    unit = "individual",
    family = gllvmTMB::lognormal()
  )))
}

test_that("residuals() warns gllvmTMB_conditional_residual_saturated for a saturating lognormal fit", {
  skip_on_cran()

  fit <- make_saturating_lognormal_fit(seed = 1L)

  expect_warning(
    res <- stats::residuals(fit, type = "randomized_quantile", seed = 100L),
    class = "gllvmTMB_conditional_residual_saturated"
  )

  ## The pathology the warning exists to flag: residuals collapse near
  ## zero and are not a goodness-of-fit check.
  expect_true(stats::sd(res$residual, na.rm = TRUE) < 0.05)
})

test_that("residuals() does NOT warn gllvmTMB_conditional_residual_saturated for a non-saturating lognormal fit", {
  skip_on_cran()

  fit <- make_nonsaturating_lognormal_fit(seed = 1L)

  expect_false(fit$use$diag_B)
  expect_false(fit$use$diag_W)

  warnings_seen <- character(0)
  withCallingHandlers(
    res <- stats::residuals(fit, type = "randomized_quantile", seed = 101L),
    warning = function(w) {
      warnings_seen <<- c(warnings_seen, paste(class(w), collapse = ","))
      invokeRestart("muffleWarning")
    }
  )
  expect_false(any(grepl(
    "gllvmTMB_conditional_residual_saturated",
    warnings_seen,
    fixed = TRUE
  )))

  ## Residuals are informative here (not collapsed near zero).
  expect_true(stats::sd(res$residual, na.rm = TRUE) > 0.3)
})
