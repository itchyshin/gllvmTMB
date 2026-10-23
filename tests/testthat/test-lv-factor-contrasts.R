# Preflight-only regressions: no optimiser or compiled likelihood is needed.
lv_contrast_setup <- function(lv_formula, predictor) {
  data <- data.frame(
    unit = factor(rep(seq_along(predictor), each = 3L)),
    trait = factor(rep(c("a", "b", "c"), length(predictor))),
    value = seq_len(3L * length(predictor)) / 10
  )
  data$predictor <- rep(predictor, each = 3L)
  if (is.factor(predictor) && !is.null(attr(predictor, "contrasts"))) {
    contrasts(data$predictor) <- attr(predictor, "contrasts")
  }
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ predictor)
  f[[3L]][[3L]][["lv"]] <- lv_formula
  parsed <- gllvmTMB:::parse_multi_formula(gllvmTMB:::desugar_brms_sugar(f))
  gllvmTMB:::gll_prepare_lv_predictor_setup(
    parsed, data, trait = "trait", site = "unit",
    family_id_vec = rep(0L, nrow(data)), link_id_vec = rep(0L, nrow(data))
  )$X_lv_B
}

test_that("factor LV designs retain contrasts and cannot span the intercept", {
  x <- factor(c("a", "b", "a", "b"))
  X <- lv_contrast_setup(~ predictor, x)
  expect_equal(ncol(X), 1L)
  expect_equal(as.numeric(X), c(0, 1, 0, 1))
  expect_equal(qr(cbind(1, X))$rank, ncol(X) + 1L)
})

test_that("LV numeric and character predictors preserve their design", {
  x <- c(-1, 0, 1, 2)
  expect_equal(as.numeric(lv_contrast_setup(~ predictor, x)), x)
  expect_equal(as.numeric(lv_contrast_setup(~ 0 + predictor, x)), x)
  expect_equal(as.numeric(lv_contrast_setup(~ predictor, c("a", "b", "a", "b"))), c(0, 1, 0, 1))
})

test_that("LV factors respect levels, reference changes and custom contrasts", {
  x <- factor(c("a", "b", "c", "a", "b", "c"))
  check <- function(x) {
    X <- lv_contrast_setup(~ predictor, x)
    expected <- stats::model.matrix(~ predictor, data.frame(predictor = x))[, -1L, drop = FALSE]
    expect_equal(unname(X), unname(expected), ignore_attr = TRUE)
    expect_equal(colnames(X), colnames(expected))
    expect_equal(ncol(X), 2L)
    expect_equal(qr(cbind(1, X))$rank, 3L)
  }
  check(x)
  check(stats::relevel(x, ref = "c"))
  contrasts(x) <- stats::contr.sum(3)
  check(x)
  contrasts(x) <- stats::contr.helmert(3)
  check(x)
})

test_that("LV preflight rejects intercept directions and malformed designs", {
  x <- factor(c("a", "b", "a", "b"))
  expect_error(lv_contrast_setup(~ 0 + predictor, x), "spans a constant")
  expect_error(lv_contrast_setup(~ predictor, rep(1, 4)), "spans a constant")
  expect_error(lv_contrast_setup(~ predictor + I(2 * predictor), 1:4), "rank deficient")
  expect_error(lv_contrast_setup(~ 1, x), "at least one predictor|intercept-only")
  expect_error(lv_contrast_setup(~ predictor, factor(x, levels = c("a", "b", "c"))), "rank deficient|empty factor levels")
})

test_that("LV rejects constant directions assembled from numeric predictors", {
  expect_error(
    lv_contrast_setup(~ predictor + I(1 - predictor), c(-1, 0, 1, 2)),
    "spans a constant"
  )
})

test_that("LV rejects full factor-only interaction indicator designs", {
  factor1 <- factor(rep(c("a", "b"), each = 4L))
  factor2 <- factor(rep(c("c", "d"), times = 4L))
  interaction_formula <- ~ factor1:factor2
  X <- stats::model.matrix(interaction_formula)[, -1L, drop = FALSE]
  expect_equal(qr(cbind(1, X))$rank, ncol(X))

  data <- data.frame(
    unit = factor(rep(seq_along(factor1), each = 3L)),
    trait = factor(rep(c("a", "b", "c"), length(factor1))),
    value = seq_len(3L * length(factor1)) / 10,
    factor1 = rep(factor1, each = 3L),
    factor2 = rep(factor2, each = 3L)
  )
  f <- value ~ 0 + trait +
    latent(0 + trait | unit, d = 1, lv = ~ factor1:factor2)
  parsed <- gllvmTMB:::parse_multi_formula(gllvmTMB:::desugar_brms_sugar(f))
  expect_error(
    gllvmTMB:::gll_prepare_lv_predictor_setup(
      parsed, data, trait = "trait", site = "unit",
      family_id_vec = rep(0L, nrow(data)), link_id_vec = rep(0L, nrow(data))
    ),
    "spans a constant"
  )
})
