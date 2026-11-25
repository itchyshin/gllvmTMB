test_that("gll_split and gll_rebuild round-trip additive RHS", {
  e <- quote(1 + x + latent(1 | unit))
  parts <- gll_split_additive_rhs(e)
  expect_length(parts, 3L)
  back <- gll_rebuild_additive_rhs(parts)
  rebuilt <- gll_split_additive_rhs(back)
  expect_equal(length(rebuilt), 3L)
  expect_true(gll_is_one_expr(parts[[1L]]))
  expect_false(gll_is_one_expr(quote(x)))
})

test_that("gll_unwrap_parentheses strips nesting", {
  e <- quote(((x + y)))
  expect_equal(gll_unwrap_parentheses(e), quote(x + y))
  expect_equal(gll_unwrap_parentheses(quote(x)), quote(x))
})

test_that("gll_formula_contains_call finds nested bar calls", {
  e <- quote(1 + (1 | g) + x)
  expect_true(gll_formula_contains_call(e, "|"))
  expect_false(gll_formula_contains_call(quote(1 + x), "|"))
  wrapped <- quote(((1 | g)))
  expect_true(gll_formula_contains_call(wrapped, "|"))
})

test_that("gll_impute_family_type maps admitted families", {
  expect_equal(gll_impute_family_type(stats::gaussian()), "gaussian")
  expect_equal(
    gll_impute_family_type(stats::binomial(link = "logit")),
    "bernoulli"
  )
  expect_error(
    gll_impute_family_type(stats::binomial(link = "probit")),
    "logit"
  )
  expect_equal(
    gll_impute_family_type(cumulative_logit()),
    "ordinal"
  )
  expect_equal(
    gll_impute_family_type(categorical()),
    "categorical"
  )
  expect_error(gll_impute_family_type(stats::poisson()), "Unsupported")
})

test_that("gll_standardize_impute_model accepts formula or impute_model", {
  m <- impute_model(y ~ x, family = stats::gaussian())
  expect_identical(gll_standardize_impute_model(m), m)
  f <- gll_standardize_impute_model(y ~ z)
  expect_s3_class(f, "gllvmTMB_impute_model")
  expect_error(gll_standardize_impute_model(1L))
})

test_that("gll_empty_mi_setup returns zero-row mi scaffold", {
  empty <- gll_empty_mi_setup()
  expect_type(empty, "list")
  expect_true(length(empty$impute_cols) == 0L || is.null(empty$impute_cols))
})