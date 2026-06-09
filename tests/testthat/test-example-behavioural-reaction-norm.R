load_behavioural_reaction_norm_example <- function() {
  path <- system.file(
    "extdata",
    "examples",
    "behavioural-reaction-norm-example.rds",
    package = "gllvmTMB"
  )
  expect_true(nzchar(path))
  expect_true(file.exists(path))
  readRDS(path)
}

fit_behavioural_reaction_norm_long <- function(ex) {
  suppressMessages(suppressWarnings(gllvmTMB(
    ex$formula_long,
    data = ex$data_long,
    trait = ex$fit_args$trait,
    unit = ex$fit_args$unit,
    unit_obs = ex$fit_args$unit_obs,
    family = ex$fit_args$family,
    control = gllvmTMBcontrol(
      se = FALSE,
      optimizer = "optim",
      optArgs = list(method = "BFGS")
    )
  )))
}

fit_behavioural_reaction_norm_wide <- function(ex) {
  suppressMessages(suppressWarnings(gllvmTMB(
    ex$formula_wide,
    data = ex$data_wide,
    unit = ex$fit_args$unit,
    unit_obs = ex$fit_args$unit_obs,
    family = ex$fit_args$family,
    control = gllvmTMBcontrol(
      se = FALSE,
      optimizer = "optim",
      optArgs = list(method = "BFGS")
    )
  )))
}

unit_slope_comparison_rows <- function(estimate, truth) {
  idx <- which(lower.tri(truth, diag = TRUE), arr.ind = TRUE)
  row_name <- rownames(truth)[idx[, "row"]]
  col_name <- colnames(truth)[idx[, "col"]]
  row_is_slope <- grepl("^slope\\.", row_name)
  col_is_slope <- grepl("^slope\\.", col_name)

  data.frame(
    row = row_name,
    column = col_name,
    estimate = estimate[idx],
    truth = truth[idx],
    block = ifelse(
      row_is_slope & col_is_slope,
      "slope-slope",
      ifelse(
        !row_is_slope & !col_is_slope,
        "intercept-intercept",
        "intercept-slope"
      )
    )
  )
}

test_that("behavioural reaction-norm example object has contract fields", {
  ex <- load_behavioural_reaction_norm_example()

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
  expect_named(ex$fit_args, c("trait", "unit", "unit_obs", "family"))
  expect_named(
    ex$alignment,
    c("symbol", "keyword", "dgp", "extractor", "truth_column")
  )
})

test_that("behavioural reaction-norm example has repeated-measures shapes", {
  ex <- load_behavioural_reaction_norm_example()
  traits <- ex$truth$trait_names
  n_sessions <- ex$truth$n_individuals * ex$truth$n_sessions_per_individual

  expect_equal(levels(ex$data_long$trait), traits)
  expect_equal(nlevels(ex$data_long$individual), ex$truth$n_individuals)
  expect_equal(nlevels(ex$data_long$session_id), n_sessions)
  expect_equal(nrow(ex$data_long), n_sessions * length(traits))
  expect_true(all(
    c("individual", "session", "session_id", "temperature", traits) %in%
      names(ex$data_wide)
  ))
  expect_equal(nrow(ex$data_wide), n_sessions)
  expect_equal(dim(ex$truth$Sigma), c(2L * length(traits), 2L * length(traits)))
  expect_equal(rownames(ex$truth$Sigma), ex$truth$augmented_names)
  expect_equal(colnames(ex$truth$Sigma), ex$truth$augmented_names)
})

test_that("behavioural reaction-norm long and wide fits agree and recover truth", {
  ex <- load_behavioural_reaction_norm_example()

  fit_long <- fit_behavioural_reaction_norm_long(ex)
  fit_wide <- fit_behavioural_reaction_norm_wide(ex)

  expect_equal(fit_long$opt$convergence, 0L)
  expect_equal(fit_wide$opt$convergence, 0L)
  expect_equal(
    as.numeric(logLik(fit_long)),
    as.numeric(logLik(fit_wide)),
    tolerance = 1e-6
  )
  expect_equal(fit_wide$opt$objective, fit_long$opt$objective, tolerance = 1e-6)

  health <- check_gllvmTMB(fit_long)
  expect_equal(
    health$status[health$component == "optimizer_convergence"],
    "PASS"
  )
  expect_equal(health$status[health$component == "max_gradient"], "PASS")

  shared <- extract_Sigma(
    fit_long,
    level = "unit_slope",
    part = "shared"
  )$Sigma
  unique <- extract_Sigma(
    fit_long,
    level = "unit_slope",
    part = "unique"
  )$s
  total <- extract_Sigma(
    fit_long,
    level = "unit_slope",
    part = "total"
  )$Sigma
  truth <- ex$truth$Sigma_unit_slope

  expect_equal(total, shared + diag(unique, nrow = length(unique)),
               tolerance = 1e-8)
  expect_equal(dimnames(total), dimnames(truth))
  expect_lt(norm(total - truth, "F") / norm(truth, "F"), 0.30)
  expect_lt(max(abs(total - truth)), 0.15)

  unit_obs <- extract_Sigma(fit_long, level = "unit_obs", part = "shared")$Sigma
  expect_equal(dim(unit_obs), c(length(ex$truth$trait_names), length(ex$truth$trait_names)))
})

test_that("behavioural reaction-norm recovery figure data are plot-ready", {
  testthat::skip_if_not_installed("ggplot2")
  ex <- load_behavioural_reaction_norm_example()
  fit <- fit_behavioural_reaction_norm_long(ex)

  total <- extract_Sigma(fit, level = "unit_slope", part = "total")$Sigma
  comparison <- unit_slope_comparison_rows(
    estimate = total,
    truth = ex$truth$Sigma_unit_slope
  )

  expect_s3_class(comparison, "data.frame")
  expect_true(all(c("estimate", "truth", "block") %in% names(comparison)))
  expect_setequal(
    unique(comparison$block),
    c("intercept-intercept", "intercept-slope", "slope-slope")
  )

  p <- ggplot2::ggplot(
    comparison,
    ggplot2::aes(truth, estimate, colour = block)
  ) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2) +
    ggplot2::geom_point(size = 2.2, alpha = 0.85) +
    ggplot2::coord_equal()

  expect_s3_class(p, "ggplot")
  expect_silent(ggplot2::ggplot_build(p))
})
