## #1083 (continuation): `gllvmTMB_conditional_residual_saturated` was
## widened from `family_id %in% c(0L, 3L)` (gaussian, lognormal) to also
## cover Gamma (4), Beta (7), and student (9) -- the OTHER exact-CDF
## continuous families that share the identical per-row-diagonal
## degeneracy mechanism: a diagonal random effect indexed at the observed
## (unit x trait) resolution interpolates the response, driving the
## family's dispersion/scale parameter toward a degenerate confound
## (Gamma shape -> Inf, Beta precision -> Inf, student sigma -> 0).
##
## Multi-seed evidence (docs/dev-log/2026-08-17-sigma-eps-suppression-not-a-defect.md
## judged single-seed evidence inconclusive and asked for exactly this): a
## 15-seed sweep at n_ind = 36 found Gamma's phi_gamma running away past
## 1e6 (true 6) in 9/15 seeds and student's sigma_student collapsing below
## 0.1 (true 0.4) in 6/15 seeds. Poisson (no continuous dispersion), swept
## the same way across 8 seeds, showed no such collapse.
##
## Gamma is used here as the anchor reproduction because it gave the
## largest and most reliable runaway across seeds.

make_saturating_gamma_fit <- function(seed = 2L) {
  set.seed(seed)
  n_ind <- 36L
  Tn <- 2L
  trait_names <- c("a", "b")
  u <- stats::rnorm(n_ind, sd = 0.35)
  eta <- cbind(0.2 + u, -0.15 + 0.7 * u)
  shape_true <- 6
  mu <- exp(eta)
  y <- matrix(
    stats::rgamma(n_ind * Tn, shape = shape_true, rate = shape_true / as.vector(mu)),
    n_ind, Tn
  )

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
    family = stats::Gamma(link = "log")
  )))
}

test_that("residuals() warns gllvmTMB_conditional_residual_saturated for a saturating Gamma fit (seed = 2, the reproduction that ran away past 1e6)", {
  skip_on_cran()

  fit <- make_saturating_gamma_fit(seed = 2L)
  expect_true(fit$use$diag_B || fit$use$diag_W)

  expect_warning(
    res <- stats::residuals(fit, type = "randomized_quantile", seed = 100L),
    class = "gllvmTMB_conditional_residual_saturated"
  )
  expect_true(all(is.na(res$residual) | is.finite(res$residual)))
})

test_that("residuals() does NOT warn gllvmTMB_conditional_residual_saturated for Poisson under the identical per-row-diagonal structure (no continuous dispersion to degenerate)", {
  skip_on_cran()

  set.seed(1L)
  n_ind <- 36L
  Tn <- 2L
  trait_names <- c("a", "b")
  u <- stats::rnorm(n_ind, sd = 0.35)
  eta <- cbind(0.2 + u, -0.15 + 0.7 * u)
  mu <- exp(eta)
  y <- matrix(stats::rpois(n_ind * Tn, lambda = as.vector(mu)), n_ind, Tn)

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df,
    unit = "individual",
    family = stats::poisson(link = "log")
  )))
  expect_true(fit$use$diag_B || fit$use$diag_W)

  warnings_seen <- character(0)
  withCallingHandlers(
    stats::residuals(fit, type = "randomized_quantile", seed = 101L),
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
})
