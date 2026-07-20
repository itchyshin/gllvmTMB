## Visual regression tests for publication-facing plot helpers.
##
## These snapshots are intentionally sparse. They guard the figures whose
## appearance carries interpretation: Confidence Eye correlation plots,
## matrix-style correlation plots, Sigma-table Confidence Eye plots, plus
## rotated ordination biplots.
##
## The block at the end broadens rendered-figure QA across the remaining
## panels of the plot.gllvmTMB_multi() dispatcher (correlation,
## correlation_ellipse, loadings, integration, communality, variance).
## Those panels read model internals through the extractors, so they are
## driven by a small fitted fixture rather than hand-built data frames. The
## fixture is deterministic on a fixed seed (verified byte-identical across
## independent fits), but a TMB optimum can drift across BLAS/OS builds, so
## the fit-based dispatcher snapshots run as a developer-local visual gate
## via skip_on_ci(). Object-shape coverage of the same dispatcher lives in
## test-plot-gllvmTMB.R; these cells add the rendered-figure layer only and
## change no engine code.
##
## The two stacked-bar panels retain exact fitted proportions in their plot-data
## contract but render components below 1e-7 as zero and renormalise the stack.
## This prevents platform-dependent 1e-6-point SVG widths for visually zero
## bars. A remaining snapshot change therefore requires visual review; do not
## regenerate the committed SVG merely to make a local run green.

skip_if_no_visual_snapshot <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("vdiffr")
}

## Fitted fixture for the dispatcher snapshots. Mirrors
## make_BW_fit_for_plot() in test-plot-gllvmTMB.R: both rr() and unique()
## at both tiers (the recommended decomposition) so every dispatcher panel
## has data to render.
make_snapshot_dispatcher_fit <- function(seed = 1L) {
  Tn <- 4L
  Lambda_B <- matrix(
    c(1.0, 0.5, -0.4, 0.3, 0.0, 0.8, 0.4, -0.2),
    Tn,
    2
  )
  Lambda_W <- matrix(c(0.4, 0.2, -0.1, 0.3), Tn, 1)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 30,
    n_species = 6,
    n_traits = Tn,
    mean_species_per_site = 4,
    Lambda_B = Lambda_B,
    psi_B = c(0.20, 0.15, 0.10, 0.25),
    Lambda_W = Lambda_W,
    psi_W = c(0.10, 0.08, 0.05, 0.12),
    beta = matrix(0, Tn, 2),
    seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 2) +
      unique(0 + trait | site) +
      latent(0 + trait | site_species, d = 1) +
      unique(0 + trait | site_species),
    data = s$data
  )))
}

make_snapshot_ordination_fit <- function() {
  traits <- paste0("T", 1:4)
  units <- paste0("unit", 1:10)
  scores <- cbind(
    LV1 = seq(-1.35, 1.35, length.out = length(units)),
    LV2 = c(-0.60, -0.35, -0.10, 0.18, 0.45, 0.52, 0.26, -0.05, -0.32, -0.58)
  )
  Lambda <- matrix(
    c(
      0.76,
      0.18,
      0.52,
      0.34,
      -0.20,
      0.70,
      -0.42,
      0.48
    ),
    nrow = length(traits),
    byrow = TRUE,
    dimnames = list(traits, c("LV1", "LV2"))
  )
  structure(
    list(
      data = data.frame(
        trait = factor(rep(traits, each = length(units)), levels = traits),
        unit = factor(rep(units, times = length(traits)), levels = units)
      ),
      trait_col = "trait",
      unit_col = "unit",
      use = list(rr_B = TRUE, rr_W = FALSE),
      d_B = 2L,
      d_W = 0L,
      n_sites = length(units),
      report = list(Lambda_B = Lambda),
      tmb_obj = list(
        env = list(
          last.par.best = stats::setNames(
            as.vector(t(scores)),
            rep("z_B", length(units) * 2L)
          )
        )
      )
    ),
    class = "gllvmTMB_multi"
  )
}

test_that("confidence-eye correlation plot has stable visual output", {
  skip_if_no_visual_snapshot()
  cors <- data.frame(
    tier = c("unit", "unit", "unit", "unit"),
    trait_i = c("length", "length", "mass", "beak"),
    trait_j = c("mass", "wing", "wing", "wing"),
    correlation = c(0.42, -0.28, 0.34, 0.58),
    lower = c(0.12, -0.53, 0.05, 0.31),
    upper = c(0.66, 0.02, 0.57, 0.76),
    method = "fisher-z",
    stringsAsFactors = FALSE
  )

  p <- plot_correlations(cors, style = "eye")

  vdiffr::expect_doppelganger(
    "confidence-eye-correlation-plot",
    p
  )
})

test_that("correlation estimate-CI matrix has stable visual output", {
  skip_if_no_visual_snapshot()
  cors <- data.frame(
    tier = "unit",
    trait_i = c("length", "length", "length", "mass", "mass", "wing"),
    trait_j = c("mass", "wing", "bill", "wing", "bill", "bill"),
    correlation = c(0.62, -0.38, 0.18, 0.44, -0.22, 0.31),
    lower = c(0.32, -0.61, -0.08, 0.18, -0.45, 0.05),
    upper = c(0.80, -0.10, 0.41, 0.64, 0.03, 0.53),
    method = "fisher-z",
    stringsAsFactors = FALSE
  )

  p <- plot_correlations(
    cors,
    style = "heatmap",
    matrix_layout = "estimate_ci"
  )

  vdiffr::expect_doppelganger(
    "correlation-estimate-ci-matrix-plot",
    p
  )
})

test_that("two-level correlation ellipse matrix has stable visual output", {
  skip_if_no_visual_snapshot()
  cors <- data.frame(
    tier = rep(c("unit", "unit_obs"), each = 6L),
    trait_i = rep(c("length", "length", "length", "mass", "mass", "wing"), 2L),
    trait_j = rep(c("mass", "wing", "bill", "wing", "bill", "bill"), 2L),
    correlation = c(
      0.62,
      -0.38,
      0.18,
      0.44,
      -0.22,
      0.31,
      0.22,
      -0.12,
      0.07,
      0.29,
      -0.08,
      0.17
    ),
    lower = c(
      0.32,
      -0.61,
      -0.08,
      0.18,
      -0.45,
      0.05,
      -0.04,
      -0.35,
      -0.19,
      0.02,
      -0.30,
      -0.07
    ),
    upper = c(
      0.80,
      -0.10,
      0.41,
      0.64,
      0.03,
      0.53,
      0.45,
      0.11,
      0.32,
      0.50,
      0.16,
      0.39
    ),
    method = "fisher-z",
    stringsAsFactors = FALSE
  )

  p <- plot_correlations(
    cors,
    style = "oval",
    matrix_layout = "levels",
    label_type = "estimate"
  )

  vdiffr::expect_doppelganger(
    "correlation-two-level-ellipse-matrix-plot",
    p
  )
})

test_that("Sigma-table confidence-eye plot has stable visual output", {
  skip_if_no_visual_snapshot()
  sigma_rows <- data.frame(
    level = rep(c("unit", "unit_obs"), each = 3L),
    trait_i = rep(c("length", "length", "mass"), 2L),
    trait_j = rep(c("mass", "wing", "wing"), 2L),
    estimate = c(0.22, -0.14, 0.38, 0.08, -0.24, 0.16),
    lower = c(0.08, -0.32, 0.18, -0.05, -0.45, 0.01),
    upper = c(0.35, 0.04, 0.59, 0.22, -0.02, 0.31),
    matrix = "Sigma",
    component = "total",
    diagonal = FALSE,
    triangle = "upper",
    stringsAsFactors = FALSE
  )

  p <- plot_Sigma_table(sigma_rows, style = "eye", sort = "trait")

  vdiffr::expect_doppelganger(
    "sigma-table-confidence-eye-plot",
    p
  )
})

test_that("anchored rotated ordination has stable visual output", {
  skip_if_no_visual_snapshot()
  fit <- make_snapshot_ordination_fit()

  p <- suppressMessages(plot(
    fit,
    type = "ordination",
    level = "unit",
    rotation = "varimax",
    anchor_traits = c("T1", "T3"),
    standardize_loadings = TRUE
  ))

  vdiffr::expect_doppelganger(
    "anchored-rotated-ordination-plot",
    p
  )
})

test_that("dispatcher correlation heatmap has stable visual output", {
  skip_if_no_visual_snapshot()
  testthat::skip_on_ci()
  fit <- make_snapshot_dispatcher_fit()

  p <- suppressMessages(plot(fit, type = "correlation"))

  vdiffr::expect_doppelganger(
    "dispatcher-correlation-heatmap-plot",
    p
  )
})

test_that("dispatcher correlation ellipse matrix has stable visual output", {
  skip_if_no_visual_snapshot()
  testthat::skip_on_ci()
  fit <- make_snapshot_dispatcher_fit()

  p <- suppressMessages(plot(fit, type = "correlation_ellipse"))

  vdiffr::expect_doppelganger(
    "dispatcher-correlation-ellipse-plot",
    p
  )
})

test_that("dispatcher loadings heatmap has stable visual output", {
  skip_if_no_visual_snapshot()
  testthat::skip_on_ci()
  fit <- make_snapshot_dispatcher_fit()

  p <- suppressMessages(plot(fit, type = "loadings"))

  vdiffr::expect_doppelganger(
    "dispatcher-loadings-heatmap-plot",
    p
  )
})

test_that("dispatcher integration dot-whisker has stable visual output", {
  skip_if_no_visual_snapshot()
  testthat::skip_on_ci()
  fit <- make_snapshot_dispatcher_fit()

  p <- suppressMessages(plot(fit, type = "integration"))

  vdiffr::expect_doppelganger(
    "dispatcher-integration-dot-whisker-plot",
    p
  )
})

test_that("dispatcher communality stacked bars have stable visual output", {
  skip_if_no_visual_snapshot()
  testthat::skip_on_ci()
  fit <- make_snapshot_dispatcher_fit()

  p <- suppressMessages(plot(fit, type = "communality"))

  vdiffr::expect_doppelganger(
    "dispatcher-communality-stacked-bars-plot",
    p
  )
})

test_that("dispatcher variance partition has stable visual output", {
  skip_if_no_visual_snapshot()
  testthat::skip_on_ci()
  fit <- make_snapshot_dispatcher_fit()

  p <- suppressMessages(plot(fit, type = "variance"))

  vdiffr::expect_doppelganger(
    "dispatcher-variance-partition-plot",
    p
  )
})
