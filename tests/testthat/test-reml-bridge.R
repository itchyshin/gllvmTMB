# ML-vs-REML variance-component bridge diagnostic (Design 80 "Bridge
# diagnostic (cheap, ship in the RE arc)",
# docs/design/80-nongaussian-re-evidence-bars.md).
#
# reml_bridge() triggers one extra Gaussian refit with the opposite REML
# flag, so every test here is heavy-gated. For a balanced single scalar
# `(1 | study)` random intercept the ML-vs-REML relative gap on the fitted
# sigma is close to a deterministic function of the number of groups (not
# the noise realisation) -- verified empirically at n_groups = 4 (gap_rel
# ~ 0.135-0.139 across five seeds) and n_groups = 150 (gap_rel ~ 0.003),
# giving a robust margin either side of the default rel_thresh = 0.10.

.make_reml_bridge_data <- function(seed, n_groups, n_traits = 2L, n_rep = 5L,
                                   sd_u = 1.0, sd_resid = 0.5) {
  set.seed(seed)
  trait_levels <- paste0("t", seq_len(n_traits))
  df <- expand.grid(
    study = factor(seq_len(n_groups)),
    trait = factor(trait_levels, levels = trait_levels),
    rep = seq_len(n_rep)
  )
  beta <- stats::setNames(seq(-0.2, 0.3, length.out = n_traits), trait_levels)
  u <- stats::rnorm(n_groups, 0, sd_u)
  df$value <- beta[as.character(df$trait)] + u[as.integer(df$study)] +
    stats::rnorm(nrow(df), 0, sd_resid)
  df
}

test_that("reml_bridge() flags a small-cluster gap and passes at large cluster count", {
  skip_if_not_heavy()

  df_small <- .make_reml_bridge_data(seed = 1001, n_groups = 4L)
  fit_small <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (1 | study),
    data = df_small, unit = "study",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit_small$opt$convergence, 0L)

  bridge_small <- reml_bridge(fit_small)
  expect_true(is.data.frame(bridge_small))
  expect_true(all(
    c("component", "ml", "reml", "gap_abs", "gap_rel", "threshold", "flag") %in%
      names(bridge_small)
  ))
  expect_true(any(bridge_small$flag))
  expect_true(any(bridge_small$gap_rel > 0.10))

  df_large <- .make_reml_bridge_data(seed = 1002, n_groups = 150L)
  fit_large <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (1 | study),
    data = df_large, unit = "study",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit_large$opt$convergence, 0L)

  bridge_large <- reml_bridge(fit_large)
  expect_false(any(bridge_large$flag))
  expect_true(all(bridge_large$gap_rel < 0.10))

  ## check_gllvmTMB() never computes the bridge itself (no extra refit)...
  chk_default <- check_gllvmTMB(fit_small)
  expect_false(any(grepl("^ml_reml_gap_", chk_default$component)))

  ## ...but surfaces it when passed explicitly...
  chk_with_bridge <- check_gllvmTMB(fit_small, reml_bridge = bridge_small)
  bridge_rows <- chk_with_bridge[
    grepl("^ml_reml_gap_", chk_with_bridge$component), ,
    drop = FALSE
  ]
  expect_true(nrow(bridge_rows) > 0L)
  expect_true(any(bridge_rows$status == "WARN"))

  ## ...or attached directly to the fit.
  fit_small_attached <- fit_small
  fit_small_attached$reml_bridge <- bridge_small
  chk_attached <- check_gllvmTMB(fit_small_attached)
  attached_rows <- chk_attached[
    grepl("^ml_reml_gap_", chk_attached$component), ,
    drop = FALSE
  ]
  expect_true(nrow(attached_rows) > 0L)
  expect_true(any(attached_rows$status == "WARN"))
})

test_that("reml_bridge() rejects non-Gaussian fits", {
  skip_if_not_heavy()

  df <- .make_reml_bridge_data(seed = 2001, n_groups = 10L)
  df$value <- stats::rpois(nrow(df), lambda = 3)
  fit_pois <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (1 | study),
    data = df, unit = "study", family = poisson(),
    control = gllvmTMBcontrol(se = FALSE)
  )))

  expect_error(reml_bridge(fit_pois), "Gaussian-only")
})
