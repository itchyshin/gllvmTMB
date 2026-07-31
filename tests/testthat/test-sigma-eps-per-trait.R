## Issue #856: `src/gllvmTMB.cpp:582` declares `PARAMETER(log_sigma_eps)` as a
## single SCALAR residual log-SD shared across every gaussian (fid 0) and
## lognormal (fid 3) row, while every other family gets a
## `PARAMETER_VECTOR` of length n_traits (e.g. `log_phi_gamma`,
## `log_phi_nbinom2`). This file asserts the target post-fix behaviour:
## `fit$report$sigma_eps` must be a length-n_traits vector that recovers
## distinct per-trait residual SDs, not one shared compromise value.
##
## On current main this MUST fail: `report$sigma_eps` is length 1 and holds
## a single scalar that trades off across traits (empirically close to the
## RMS of the true per-trait SDs, not either one individually -- see
## docs/dev-log for the #856 archaeology).
##
## DGP: `n_unit` units x 2 gaussian traits x `n_rep` replicate rows per
## (unit, trait) cell. The replication matters: with >1 row per (unit,
## trait) cell, the per-trait `indep()` diagonal term at the unit level is
## NOT at per-row resolution, so the Q7 auto-suppression rule
## (`fit-multi.R`, "Auto-suppressing sigma_eps") does not fire and
## sigma_eps is genuinely, jointly estimated alongside the per-trait
## unit-level random intercepts (verified empirically at authoring time:
## `"log_sigma_eps" %in% names(fit$tmb_obj$env$map)` is FALSE for this
## fixture). True residual SDs are set 10x apart (0.2 vs 2.0) so a single
## shared scalar cannot fit both, and only a genuine per-trait vector can
## recover them.
##
## Tolerance: 30% relative. A model-free sanity check -- the pooled
## within-unit residual SD per trait, which differences out the unit-level
## random intercept without fitting anything -- recovers the two true SDs
## to within 1-8% on this exact fixture (seed 8560, df = 240 per trait), so
## 30% leaves ample headroom for a real per-trait MLE while still catching
## a degenerate/broadcast implementation (e.g. one that just repeats the
## shared scalar into both trait slots).

build_two_scale_gaussian_data <- function(n_unit = 120L, n_rep = 3L,
                                           true_sigma_eps = c(0.2, 2.0),
                                           true_sd_unit = c(1.0, 1.0),
                                           seed = 8560L) {
  set.seed(seed)
  n_traits <- length(true_sigma_eps)
  trait_names <- paste0("t", seq_len(n_traits))

  grid <- expand.grid(rep = seq_len(n_rep), unit = seq_len(n_unit))
  long <- do.call(rbind, lapply(seq_len(n_traits), function(t) {
    data.frame(unit = grid$unit, rep = grid$rep, trait_idx = t)
  }))

  b_unit <- vapply(seq_len(n_traits), function(t) {
    stats::rnorm(n_unit, 0, true_sd_unit[t])
  }, numeric(n_unit))
  eta <- b_unit[cbind(long$unit, long$trait_idx)]
  long$value <- stats::rnorm(nrow(long), mean = eta,
                              sd = true_sigma_eps[long$trait_idx])

  long$unit  <- factor(long$unit)
  long$trait <- factor(trait_names[long$trait_idx], levels = trait_names)
  long
}

test_that("gaussian indep(): sigma_eps recovers distinct per-trait residual SDs (#856)", {
  skip_if_not_heavy()
  skip_on_cran()

  n_traits <- 2L
  true_sigma_eps <- c(0.2, 2.0)
  long <- build_two_scale_gaussian_data(true_sigma_eps = true_sigma_eps)

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | unit),
    data = long, unit = "unit", trait = "trait"
  )))

  ## Honest skip on non-convergence -- never fake-pass/fake-fail.
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("two-scale gaussian sigma_eps fixture did not converge / Hessian not PD")
  }

  ## Guard the DGP assumption above: this fixture must NOT trip the Q7
  ## per-row auto-suppression rule, or sigma_eps would be fixed near-zero
  ## for a reason unrelated to #856 (mirrors the idiom in
  ## test-sigma-eps-autosuppress.R's "multi-row diag does NOT suppress" case).
  expect_true(!("log_sigma_eps" %in% names(fit$tmb_obj$env$map)) ||
              !is.na(fit$tmb_obj$env$map$log_sigma_eps[1]),
              label = "sigma_eps is genuinely estimated, not Q7-auto-suppressed")

  ## --- the core #856 assertion: sigma_eps is per-trait, not scalar -------
  sigma_eps_hat <- as.numeric(fit$report$sigma_eps)
  expect_length(sigma_eps_hat, n_traits)

  for (t in seq_len(n_traits)) {
    expect_equal(sigma_eps_hat[t], true_sigma_eps[t], tolerance = 0.3,
                 label = paste0("sigma_eps[", t, "] (per-trait residual SD, #856)"))
  }
})
