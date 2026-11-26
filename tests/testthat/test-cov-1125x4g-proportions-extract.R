## Coverage (cursor-cloud-1125x4g): R/proportions-ci.R, R/extract-latent-scores.R, R/column-coef-foundation.R.

.cov1125x4g_gauss <- function() {
  set.seed(112545)
  n <- 12L
  df <- data.frame(
    unit = factor(rep(seq_len(n / 2L), each = 2L)),
    trait = factor(rep(c("a", "b"), n / 2L)),
    value = stats::rnorm(n)
  )
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    unit = "unit",
    trait = "trait",
    family = gaussian(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE, warn_runaway = FALSE),
    silent = TRUE
  )))
}

test_that(".proportions_components_present() reads tier flags", {
  fit <- .cov1125x4g_gauss()
  comps <- gllvmTMB:::.proportions_components_present(fit)
  expect_type(comps, "character")
  expect_gt(length(comps), 0L)
})

test_that(".proportions_validate_inputs() guards trait and component names", {
  fit <- .cov1125x4g_gauss()
  expect_error(
    gllvmTMB:::.proportions_validate_inputs(fit, "residual", trait_idx = 99L, level = 0.95),
    "trait_idx"
  )
  expect_error(
    gllvmTMB:::.proportions_validate_inputs(fit, "not_a_component", trait_idx = 1L, level = 0.95),
    "component"
  )
})

test_that(".proportions_wald_ci() rejects unknown components", {
  fit <- .cov1125x4g_gauss()
  expect_error(
    gllvmTMB:::.proportions_wald_ci(fit, components = "not_a_component"),
    "component"
  )
})

test_that(".proportions_link_resid_fixed() is a logical scalar", {
  fit <- .cov1125x4g_gauss()
  expect_length(gllvmTMB:::.proportions_link_resid_fixed(fit), 1L)
})

test_that("extract_latent_scores() rejects non-multi objects", {
  expect_error(extract_latent_scores(list()), "gllvmTMB")
})

test_that("extract_latent_scores() returns scores on a tiny latent fit", {
  fit <- .cov1125x4g_gauss()
  lv <- extract_latent_scores(fit, level = "unit")
  expect_true(is.matrix(lv) || is.data.frame(lv))
  expect_gt(nrow(lv), 0L)
})

test_that("column_coef() is formula sugar only", {
  expect_null(column_coef(0 + x | trait))
})

test_that("impute_model() rejects one-sided formulas", {
  expect_error(impute_model(~ x), "two-sided")
})

test_that("impute_model() builds a gaussian predictor model", {
  m <- impute_model(x ~ z)
  expect_s3_class(m, "gllvmTMB_impute_model")
  expect_equal(m$family_type, "gaussian")
})