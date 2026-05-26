load_joint_sdm_example <- function() {
  path <- system.file(
    "extdata",
    "examples",
    "joint-sdm-example.rds",
    package = "gllvmTMB"
  )
  expect_true(nzchar(path))
  expect_true(file.exists(path))
  readRDS(path)
}

test_that("joint-SDM example object has the required contract fields", {
  ex <- load_joint_sdm_example()

  expect_setequal(
    names(ex),
    c(
      "data_long",
      "data_wide",
      "truth",
      "estimands",
      "formula_long",
      "formula_wide",
      "fit_args",
      "story",
      "alignment",
      "generator"
    )
  )
  expect_s3_class(ex$data_long, "data.frame")
  expect_s3_class(ex$data_wide, "data.frame")
  expect_s3_class(ex$formula_long, "formula")
  expect_s3_class(ex$formula_wide, "formula")
  expect_named(ex$fit_args, c("trait", "unit", "family"))
  expect_named(
    ex$alignment,
    c("symbol", "keyword", "dgp", "extractor", "truth_column")
  )
})

test_that("joint-SDM example object has complete long and wide shapes", {
  ex <- load_joint_sdm_example()
  traits <- ex$truth$trait_names

  expect_equal(levels(ex$data_long$trait), traits)
  expect_equal(nlevels(ex$data_long$site), ex$truth$n_sites)
  expect_equal(nrow(ex$data_long), ex$truth$n_sites * length(traits))
  expect_true(all(c("site", "env_1", traits) %in% names(ex$data_wide)))
  expect_equal(nrow(ex$data_wide), ex$truth$n_sites)
  expect_true(all(ex$data_long$value %in% c(0L, 1L)))
  expect_true(all(unlist(ex$data_wide[traits]) %in% c(0L, 1L)))
  expect_equal(dim(ex$truth$Sigma_latent), c(length(traits), length(traits)))
  expect_equal(rownames(ex$truth$Sigma_latent), traits)
  expect_equal(colnames(ex$truth$Sigma_latent), traits)
})

test_that("joint-SDM example long and wide fits are likelihood-equivalent", {
  ex <- load_joint_sdm_example()
  ctl <- gllvmTMBcontrol(se = FALSE)

  fit_long <- suppressMessages(suppressWarnings(gllvmTMB(
    ex$formula_long,
    data = ex$data_long,
    trait = ex$fit_args$trait,
    unit = ex$fit_args$unit,
    family = ex$fit_args$family,
    control = ctl
  )))
  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB(
    ex$formula_wide,
    data = ex$data_wide,
    unit = ex$fit_args$unit,
    family = ex$fit_args$family,
    control = ctl
  )))

  expect_equal(fit_long$opt$convergence, 0L)
  expect_equal(fit_wide$opt$convergence, 0L)
  expect_equal(
    as.numeric(logLik(fit_long)),
    as.numeric(logLik(fit_wide)),
    tolerance = 1e-8
  )
  expect_equal(fit_wide$opt$objective, fit_long$opt$objective, tolerance = 1e-8)
  expect_equal(fit_wide$tmb_data$y, fit_long$tmb_data$y)
  expect_equal(fit_wide$tmb_data$family_id_vec, fit_long$tmb_data$family_id_vec)
  expect_equal(fit_wide$tmb_data$link_id_vec, fit_long$tmb_data$link_id_vec)
})

test_that("joint-SDM example is correlation- and ordination-plot ready", {
  testthat::skip_if_not_installed("ggplot2")
  ex <- load_joint_sdm_example()

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    ex$formula_long,
    data = ex$data_long,
    trait = ex$fit_args$trait,
    unit = ex$fit_args$unit,
    family = ex$fit_args$family
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_lt(max(abs(fit$report$Lambda_B)), 5)

  corr_rows <- suppressMessages(extract_correlations(
    fit,
    tier = "unit",
    method = "fisher-z",
    link_residual = "auto"
  ))
  expect_s3_class(corr_rows, "data.frame")
  expect_true(all(c("correlation", "lower", "upper") %in% names(corr_rows)))
  expect_true(all(corr_rows$correlation >= -1 - 1e-8))
  expect_true(all(corr_rows$correlation <= 1 + 1e-8))
  expect_true(all(is.finite(corr_rows$lower)))
  expect_true(all(is.finite(corr_rows$upper)))

  p_cor <- plot_correlations(
    corr_rows,
    style = "heatmap",
    matrix_layout = "by_level",
    label_type = "estimate",
    include_diagonal = TRUE
  )
  expect_s3_class(p_cor, "ggplot")
  expect_equal(attr(p_cor, "gllvmTMB_meta")$type, "correlations_heatmap")
  expect_silent(ggplot2::ggplot_build(p_cor))

  p_ord <- plot(
    fit,
    type = "ordination",
    level = "unit",
    rotation = "varimax",
    sign_anchor = "auto",
    standardize_loadings = TRUE
  )
  expect_s3_class(p_ord, "ggplot")
  expect_equal(attr(p_ord, "gllvmTMB_meta")$type, "ordination")
  expect_equal(
    attr(p_ord, "gllvmTMB_meta")$rotation_status,
    "varimax_ordered_sign_anchored"
  )
  expect_silent(ggplot2::ggplot_build(p_ord))
})
