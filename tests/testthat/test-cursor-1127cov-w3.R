## Coverage slice w3 (27 Nov): fast unit tests for uncovered internal helpers
## in R/plot-covariance-tables.R, R/loading-uncertainty-helpers.R, and
## R/normalise-lambda-constraint.R (not targeted by open 1127cov PRs).

# ---- R/plot-covariance-tables.R --------------------------------------------

test_that(".gtmb_require_plot_columns() aborts when columns are missing", {
  df <- data.frame(trait_i = "a", estimate = 0.1)
  expect_error(
    .gtmb_require_plot_columns(df, c("trait_i", "trait_j", "estimate")),
    "missing required column"
  )
  expect_silent(.gtmb_require_plot_columns(df, c("trait_i", "estimate")))
})

test_that(".gtmb_pair_label() distinguishes diagonal labels", {
  out <- .gtmb_pair_label(c("a", "b"), c("b", "b"), diagonal = c(TRUE, FALSE))
  expect_equal(out[[1L]], "a variance")
  expect_equal(out[[2L]], "b - b")
})

test_that(".gtmb_plot_sign() returns the signed factor levels", {
  x <- c(-0.2, 0, 0.3, NA)
  f <- .gtmb_plot_sign(x)
  expect_s3_class(f, "factor")
  expect_equal(as.character(f), c("negative", "zero", "positive", "zero"))
})

test_that(".gtmb_interval_state() classifies coverage patterns", {
  expect_equal(.gtmb_interval_state(c(FALSE, FALSE)), "none")
  expect_equal(.gtmb_interval_state(c(TRUE, TRUE)), "provided")
  expect_equal(.gtmb_interval_state(c(TRUE, FALSE)), "partial")
})

test_that(".gtmb_resolve_interval_line() honours style and validates input", {
  expect_true(.gtmb_resolve_interval_line(NULL, "interval"))
  expect_false(.gtmb_resolve_interval_line(FALSE, "eye"))
  expect_true(.gtmb_resolve_interval_line(TRUE, "eye"))
  expect_error(.gtmb_resolve_interval_line("yes", "interval"), "show_intervals")
})

test_that(".gtmb_validate_interval_level() and eye helpers accept (0,1)", {
  expect_equal(.gtmb_validate_interval_level(0.9), 0.9)
  expect_equal(.gtmb_resolve_eye_level(0.95), 0.95)
  expect_equal(.gtmb_resolve_eye_level(eye_level = 0.9, raindrop_level = 0.8), 0.8)
  expect_error(.gtmb_validate_interval_level(1), "between 0 and 1")
  expect_error(.gtmb_validate_interval_level(0), "between 0 and 1")
})

test_that(".gtmb_normalise_uncertainty_style() maps raindrop to eye", {
  expect_equal(.gtmb_normalise_uncertainty_style("eye"), "eye")
  expect_equal(.gtmb_normalise_uncertainty_style("raindrop"), "eye")
  expect_equal(.gtmb_normalise_uncertainty_style("interval"), "interval")
})

test_that(".gtmb_uncertainty_caption() follows the style contract", {
  missing <- "intervals unavailable"
  expect_equal(.gtmb_uncertainty_caption(c(FALSE, TRUE), "eye", missing), missing)
  expect_match(
    .gtmb_uncertainty_caption(c(TRUE, TRUE), "eye", missing),
    "Confidence eyes"
  )
  expect_match(
    .gtmb_uncertainty_caption(c(TRUE, TRUE), "interval", missing),
    "Finite interval bounds"
  )
})

test_that(".gtmb_validate_plot_labels() and optional text enforce types", {
  expect_silent(.gtmb_validate_plot_labels(TRUE, 2L))
  expect_error(.gtmb_validate_plot_labels("yes", 1L), "label")
  expect_error(.gtmb_validate_plot_labels(TRUE, -1L), "label_digits")
  expect_silent(.gtmb_validate_optional_text(NULL, "subtitle"))
  expect_silent(.gtmb_validate_optional_text("note", "subtitle"))
  expect_error(.gtmb_validate_optional_text(1L, "subtitle"), "subtitle")
})

test_that(".gtmb_format_correlation_matrix_label() formats rows by label_type", {
  dat <- data.frame(
    .estimate = c(0.456, 1, -0.12),
    .diagonal = c(FALSE, TRUE, FALSE),
    .has_interval = c(TRUE, FALSE, FALSE),
    .lower = c(0.1, NA, NA),
    .upper = c(0.8, NA, NA)
  )
  expect_equal(
    .gtmb_format_correlation_matrix_label(dat, "estimate", 2L),
    c("0.46", "1", "-0.12")
  )
  expect_equal(
    .gtmb_format_correlation_matrix_label(dat, "none", 1L),
    c("", "", "")
  )
})

test_that(".gtmb_check_correlation_duplicates() refuses conflicting duplicates", {
  dat <- data.frame(
    tier = c("unit", "unit"),
    trait_i = c("a", "a"),
    trait_j = c("b", "b"),
    estimate = c(0.5, 0.6)
  )
  expect_error(
    .gtmb_check_correlation_duplicates(dat),
    class = "gllvmTMB_correlation_conflicting_duplicates"
  )
  dat$estimate[[2L]] <- 0.5
  expect_identical(.gtmb_check_correlation_duplicates(dat), dat)
})

test_that(".gtmb_order_pair_plot_rows() respects the sort argument", {
  dat <- data.frame(
    .facet = "unit",
    .estimate = c(0.1, -0.5, 0.3),
    .pair_label = c("b - c", "a - b", "a - c")
  )
  ord <- .gtmb_order_pair_plot_rows(dat, "magnitude")
  expect_equal(dat$.pair_label[ord], c("b - c", "a - c", "a - b"))
})

# ---- R/loading-uncertainty-helpers.R ---------------------------------------

test_that(".eye_polygon_df() builds lens polygons and skips pinned rows", {
  df <- data.frame(
    estimate = c(0.5, 0.2),
    se = c(0.1, 0),
    lower = c(0.2, 0.19),
    upper = c(0.8, 0.21)
  )
  poly <- .eye_polygon_df(df, x_pos = c(1, 2), width_max = 0.8, n = 20L)
  expect_true(nrow(poly) > 0L)
  expect_setequal(unique(poly$.id), c(1L, 2L))
  expect_error(.eye_polygon_df(df, x_pos = 1), "x_pos")
  bad <- df
  bad$se <- NULL
  expect_error(.eye_polygon_df(bad, x_pos = c(1, 2)), "estimate")
  empty <- data.frame(
    estimate = 0.5, se = 0.05, lower = 0.5, upper = 0.5
  )
  expect_equal(nrow(.eye_polygon_df(empty, x_pos = 1)), 0L)
})

test_that(".salience_prob_asym() matches the fixed-rho retention rule", {
  prob <- .salience_prob_asym(rho = c(0.6, -0.2), se_rho = c(0.1, 0), threshold_rho = 0.3)
  expect_length(prob, 2L)
  expect_equal(prob[[2L]], 0)
  expect_true(prob[[1L]] > prob[[2L]])
})

test_that(".lambda_ci_asym() propagates fixed entries when se_rho == 0", {
  out <- .lambda_ci_asym(rho = c(0.25, 0.4), se_rho = c(0, 0.12))
  expect_equal(out$lower[[1L]], 0.25)
  expect_equal(out$upper[[1L]], 0.25)
  expect_true(out$lower[[2L]] < out$upper[[2L]])
})

# ---- R/normalise-lambda-constraint.R ---------------------------------------

test_that(".normalise_lambda_constraint_names() maps canonical list names to internal slots", {
  M <- matrix(1, 2, 2)
  out <- .normalise_lambda_constraint_names(list(unit = M, unit_obs = M))
  expect_named(out, c("B", "W"))
  expect_identical(out$B, M)
  expect_identical(.normalise_lambda_constraint_names(NULL), NULL)
})

test_that(".normalise_lambda_constraint_names() keeps phy/spde and errors on bad input", {
  expect_error(.normalise_lambda_constraint_names("notalist"), "must be a list")
  expect_error(
    .normalise_lambda_constraint_names(list(matrix(NA, 1, 1))),
    "must be named"
  )
  phy <- list(phy = matrix(NA, 1, 1))
  expect_identical(names(.normalise_lambda_constraint_names(phy)), "phy")
  expect_error(
    .normalise_lambda_constraint_names(list(banana = matrix(NA, 1, 1))),
    "Unknown element"
  )
})

test_that(".normalise_lambda_constraint_names() accepts legacy B/W without renaming slots", {
  M <- matrix(NA_real_, 2, 2)
  withr::local_options(list(gllvmTMB.warned_lambda_constraint_B = NULL))
  nm <- suppressWarnings(
    names(.normalise_lambda_constraint_names(list(B = M)))
  )
  expect_identical(nm, "B")
})