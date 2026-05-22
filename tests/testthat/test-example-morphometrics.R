load_morphometrics_example <- function() {
  path <- system.file(
    "extdata",
    "examples",
    "morphometrics-example.rds",
    package = "gllvmTMB"
  )
  expect_true(nzchar(path))
  expect_true(file.exists(path))
  readRDS(path)
}

load_morphometrics_bootstrap_r <- function() {
  path <- system.file(
    "extdata",
    "examples",
    "morphometrics-bootstrap-r.rds",
    package = "gllvmTMB"
  )
  expect_true(nzchar(path))
  expect_true(file.exists(path))
  readRDS(path)
}

test_that("morphometrics example object has the required contract fields", {
  ex <- load_morphometrics_example()

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

test_that("morphometrics example object has matching long and wide shapes", {
  ex <- load_morphometrics_example()
  traits <- ex$truth$trait_names

  expect_equal(levels(ex$data_long$trait), traits)
  expect_equal(nlevels(ex$data_long$individual), ex$truth$n_individuals)
  expect_equal(nrow(ex$data_long), ex$truth$n_individuals * length(traits))
  expect_true(all(c("individual", traits) %in% names(ex$data_wide)))
  expect_equal(nrow(ex$data_wide), ex$truth$n_individuals)
  expect_equal(dim(ex$truth$Sigma), c(length(traits), length(traits)))
  expect_equal(rownames(ex$truth$Sigma), traits)
  expect_equal(colnames(ex$truth$Sigma), traits)
})

test_that("morphometrics example long and wide fits agree and recover truth", {
  ex <- load_morphometrics_example()
  ctl <- gllvmTMBcontrol(se = FALSE)

  fit_long <- suppressMessages(gllvmTMB(
    ex$formula_long,
    data = ex$data_long,
    trait = ex$fit_args$trait,
    unit = ex$fit_args$unit,
    family = ex$fit_args$family,
    control = ctl
  ))
  fit_wide <- suppressMessages(gllvmTMB(
    ex$formula_wide,
    data = ex$data_wide,
    unit = ex$fit_args$unit,
    family = ex$fit_args$family,
    control = ctl
  ))

  expect_equal(
    as.numeric(logLik(fit_long)),
    as.numeric(logLik(fit_wide)),
    tolerance = 1e-6
  )

  health <- check_gllvmTMB(fit_long)
  expect_equal(
    health$status[health$component == "optimizer_convergence"],
    "PASS"
  )
  expect_equal(health$status[health$component == "max_gradient"], "PASS")

  Sigma_hat <- extract_Sigma(fit_long, level = "unit")$Sigma
  Sigma_true <- ex$truth$Sigma
  off <- upper.tri(Sigma_true)

  expect_gt(stats::cor(Sigma_hat[off], Sigma_true[off]), 0.9)
  expect_lt(
    norm(Sigma_hat - Sigma_true, "F") / norm(Sigma_true, "F"),
    0.35
  )
})

test_that("morphometrics bootstrap correlation fixture is plot-ready", {
  testthat::skip_if_not_installed("ggplot2")
  ex <- load_morphometrics_example()
  boot <- load_morphometrics_bootstrap_r()

  expect_s3_class(boot, "bootstrap_Sigma")
  expect_equal(boot$what, "R")
  expect_equal(boot$n_boot, 100L)
  expect_lte(boot$n_failed, 5L)
  expect_named(boot$point_est, "R_B")
  expect_named(boot$ci_lower, "R_B")
  expect_named(boot$ci_upper, "R_B")
  expect_equal(rownames(boot$point_est$R_B), ex$truth$trait_names)
  expect_equal(colnames(boot$point_est$R_B), ex$truth$trait_names)

  p <- plot_correlations(boot, tier = "unit", style = "raindrop")
  expect_s3_class(p, "ggplot")
  meta <- attr(p, "gllvmTMB_meta")
  expect_equal(meta$type, "correlations_raindrop")
  expect_equal(meta$source, "extract_Sigma_table")
  expect_equal(meta$interval_status, "provided")
  expect_equal(nrow(attr(p, "gllvmTMB_data")), 10L)
  expect_silent(ggplot2::ggplot_build(p))
})
