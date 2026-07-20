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
  expect_false(grepl(
    "unique\\(",
    paste(deparse(ex$formula_long), collapse = " ")
  ))
  expect_false(grepl(
    "unique\\(",
    paste(deparse(ex$formula_wide), collapse = " ")
  ))
  expect_true("latent() default Psi" %in% ex$alignment$keyword)
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
    c(
      "individual",
      "session",
      "session_id",
      "temperature_C",
      "temperature",
      traits
    ) %in%
      names(ex$data_wide)
  ))
  expect_equal(nrow(ex$data_wide), n_sessions)
  expect_equal(dim(ex$truth$Sigma), c(2L * length(traits), 2L * length(traits)))
  expect_equal(rownames(ex$truth$Sigma), ex$truth$augmented_names)
  expect_equal(colnames(ex$truth$Sigma), ex$truth$augmented_names)
})

test_that("every individual traverses the planned temperature gradient", {
  ex <- load_behavioural_reaction_norm_example()
  design <- unique(ex$data_long[
    c("individual", "session", "temperature_C", "temperature")
  ])

  by_individual <- split(design, design$individual)
  expect_true(all(vapply(
    by_individual,
    function(x) length(unique(x$session)) == ex$truth$n_sessions_per_individual,
    logical(1)
  )))

  within_sd_C <- vapply(
    by_individual,
    function(x) stats::sd(x$temperature_C),
    numeric(1)
  )
  within_range_C <- vapply(
    by_individual,
    function(x) diff(range(x$temperature_C)),
    numeric(1)
  )
  individual_means_C <- vapply(
    by_individual,
    function(x) mean(x$temperature_C),
    numeric(1)
  )

  expect_gt(min(within_sd_C), 5)
  expect_gt(min(within_range_C), 14)
  expect_lt(stats::sd(individual_means_C), 0.5)
  expect_equal(
    design$temperature,
    (design$temperature_C - ex$truth$temperature_center_C) /
      ex$truth$temperature_scale_C,
    tolerance = 1e-12
  )
})

test_that("behavioural reaction-norm long and wide fits agree and recover truth", {
  ex <- load_behavioural_reaction_norm_example()

  fit_long <- fit_behavioural_reaction_norm_long(ex)
  fit_wide <- fit_behavioural_reaction_norm_wide(ex)

  expect_equal(fit_long$opt$convergence, 0L)
  expect_equal(fit_wide$opt$convergence, 0L)
  expect_true(isTRUE(fit_long$use$diag_B_slope_default))
  expect_true(isTRUE(fit_wide$use$diag_B_slope_default))
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

  expect_equal(
    total,
    shared + diag(unique, nrow = length(unique)),
    tolerance = 1e-8
  )
  expect_equal(dimnames(total), dimnames(truth))
  expect_lt(norm(total - truth, "F") / norm(truth, "F"), 0.30)
  expect_lt(max(abs(total - truth)), 0.15)

  intercept_names <- paste0("intercept.", ex$truth$trait_names)
  slope_names <- paste0("slope.temperature.", ex$truth$trait_names)
  error <- total - truth
  expect_lt(
    norm(error[intercept_names, intercept_names], "F") /
      norm(truth[intercept_names, intercept_names], "F"),
    0.30
  )
  expect_lt(
    norm(error[slope_names, slope_names], "F") /
      norm(truth[slope_names, slope_names], "F"),
    0.30
  )
  expect_lt(
    norm(error[intercept_names, slope_names], "F") /
      norm(truth[intercept_names, slope_names], "F"),
    0.30
  )

  fixed <- tidy(fit_long, effects = "fixed")
  fitted_slopes <- fixed$estimate[grepl(":temperature$", fixed$term)]
  expect_equal(length(fitted_slopes), length(ex$truth$beta))
  expect_lt(max(abs(fitted_slopes - unname(ex$truth$beta))), 0.05)

  unit_obs <- extract_Sigma(
    fit_long,
    level = "unit_obs",
    part = "total"
  )$Sigma
  unit_obs_truth <- ex$truth$Sigma_unit_obs +
    diag(ex$truth$sigma_eps^2, nrow = length(ex$truth$trait_names))
  expect_equal(
    dim(unit_obs),
    c(length(ex$truth$trait_names), length(ex$truth$trait_names))
  )
  expect_lt(
    norm(unit_obs - unit_obs_truth, "F") / norm(unit_obs_truth, "F"),
    0.10
  )

  design <- unique(ex$data_long[c("individual", "temperature")])
  support <- split(design$temperature, design$individual)
  x_grid <- seq(
    max(vapply(support, min, numeric(1))),
    min(vapply(support, max, numeric(1))),
    length.out = 50
  )
  repeatability_error <- numeric(0)
  for (trait in ex$truth$trait_names) {
    intercept <- paste0("intercept.", trait)
    slope <- paste0("slope.temperature.", trait)
    fitted_between <-
      total[intercept, intercept] +
      2 * x_grid * total[intercept, slope] +
      x_grid^2 * total[slope, slope]
    true_between <-
      truth[intercept, intercept] +
      2 * x_grid * truth[intercept, slope] +
      x_grid^2 * truth[slope, slope]
    fitted_repeatability <- fitted_between /
      (fitted_between + unit_obs[trait, trait])
    true_repeatability <- true_between /
      (true_between + unit_obs_truth[trait, trait])
    repeatability_error <- c(
      repeatability_error,
      fitted_repeatability - true_repeatability
    )
  }
  expect_lt(mean(abs(repeatability_error)), 0.03)
  expect_lt(max(abs(repeatability_error)), 0.06)
})

test_that("behavioural reaction-norm audited fit reports curvature diagnostics", {
  ex <- load_behavioural_reaction_norm_example()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    ex$formula_long,
    data = ex$data_long,
    trait = ex$fit_args$trait,
    unit = ex$fit_args$unit,
    unit_obs = ex$fit_args$unit_obs,
    family = ex$fit_args$family,
    control = gllvmTMBcontrol(se = TRUE)
  )))

  health <- check_gllvmTMB(fit)
  curvature_required <- c(
    "optimizer_convergence",
    "sdreport",
    "pd_hessian",
    "hessian_rank"
  )
  expect_setequal(
    intersect(health$component, curvature_required),
    curvature_required
  )
  ## This is a worked-example diagnostic contract, not a recovery certificate:
  ## the refit may legitimately be flagged differently across platforms. Known
  ## DGP recovery tests, rather than this reader fixture, establish fit health.
  curvature_rows <- health[match(curvature_required, health$component), ]
  expect_true(all(curvature_rows$status %in% c("PASS", "WARN", "FAIL")))
  expect_true(all(nzchar(curvature_rows$message)))
  expect_true(all(nzchar(curvature_rows$action)))
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
