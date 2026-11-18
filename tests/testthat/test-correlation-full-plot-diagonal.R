test_that("full correlation inputs obey include_diagonal in matrix plots", {
  skip_if_not_installed("ggplot2")
  dat <- data.frame(
    tier = "B", trait_i = c("zeta", "beta", "zeta", "beta"),
    trait_j = c("zeta", "zeta", "beta", "beta"),
    correlation = c(1, .3, .3, 1), lower = NA_real_, upper = NA_real_,
    method = "none", interval_status = "none"
  )
  for (layout in c("by_level", "estimate_ci")) {
    p <- plot_correlations(dat, style = "heatmap", include_diagonal = FALSE,
                          matrix_layout = layout)
    tiles <- ggplot2::ggplot_build(p)$data[[1L]]
    expect_equal(nrow(tiles), 2L)
    expect_true(all(p$data$.row_trait != p$data$.col_trait))
  }
  p <- plot_correlations(dat, style = "heatmap", triangle = "upper",
                        include_diagonal = FALSE)
  expect_equal(nrow(ggplot2::ggplot_build(p)$data[[1L]]), 1L)
})

test_that("full two-tier and one-item tables obey diagonal controls", {
  skip_if_not_installed("ggplot2")
  dat <- data.frame(
    tier = rep(c("B", "W"), each = 4),
    trait_i = rep(c("zeta", "beta", "zeta", "beta"), 2),
    trait_j = rep(c("zeta", "zeta", "beta", "beta"), 2),
    correlation = rep(c(1, .3, .3, 1), 2),
    lower = NA_real_, upper = NA_real_, method = "none"
  )
  p <- plot_correlations(dat, style = "heatmap", matrix_layout = "levels",
                         include_diagonal = FALSE)
  expect_equal(nrow(ggplot2::ggplot_build(p)$data[[1L]]), 2L)
  expect_true(all(p$data$.row_trait != p$data$.col_trait))
  one <- dat[1, , drop = FALSE]
  p <- plot_correlations(one, style = "heatmap", include_diagonal = TRUE)
  expect_equal(nrow(ggplot2::ggplot_build(p)$data[[1L]]), 1L)
  expect_error(plot_correlations(one, style = "heatmap", include_diagonal = FALSE),
               "No correlation matrix cells")
})

test_that("one-item Julia tables expand the empty unique-pair return", {
  fit <- structure(list(family = "gaussian", model = "gaussian_rr", d = 1L,
    n_traits = 1L, n_units = 6L, trait_names = "only", unit_names = paste0("u", 1:6),
    alpha = 0, loadings = matrix(.7, 1, 1), scores = matrix(0, 6, 1),
    Sigma = matrix(.69, 1, 1), correlation = matrix(1, 1, 1),
    loglik = -22, df = 2L, nobs = 6L, converged = TRUE),
    class = c("gllvmTMB_julia", "list"))
  unique <- extract_correlations(fit, tier = "unit", entries = "unique")
  off <- extract_correlations(fit, tier = "unit", entries = "offdiag")
  full <- extract_correlations(fit, tier = "unit", entries = "all")
  expect_equal(nrow(unique), 0L)
  expect_equal(nrow(off), 0L)
  expect_equal(nrow(full), 1L)
  expect_identical(full$trait_i, "only")
  expect_identical(full$trait_j, "only")
  expect_identical(full$correlation, 1)
  expect_identical(full$method, "fixed")
  expect_true(is.na(full$lower))
})
