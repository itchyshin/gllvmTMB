test_that(".find_call_named walks nested calls", {
  inner <- call("column_coef", quote(1 + x | trait))
  tree <- call("+", call("latent", quote(1 | unit)), inner)
  hits <- .find_call_named(tree, "column_coef")
  expect_length(hits, 1L)
  expect_equal(hits[[1L]][[1L]], as.name("column_coef"))
  expect_length(.find_call_named(1L, "column_coef"), 0L)
})

test_that(".column_coef_parse_basis enforces intercept and predictors", {
  ok <- .column_coef_parse_basis(
    quote(1 + x),
    row_vars = "x",
    column_vars = character(),
    response_vars = character()
  )
  expect_true(ok$intercept)
  expect_equal(ok$predictors, "x")
  expect_equal(ok$basis, c("(Intercept)", "x"))
  z <- .column_coef_parse_basis(
    quote(0 + a + b),
    row_vars = c("a", "b"),
    column_vars = character(),
    response_vars = character()
  )
  expect_false(z$intercept)
  expect_setequal(z$predictors, c("a", "b"))
  expect_error(
    .column_coef_parse_basis(quote(x), row_vars = "x"),
    "intercept explicitly"
  )
  expect_error(
    .column_coef_parse_basis(quote(1 + 1 + x), row_vars = "x"),
    "repeated"
  )
  expect_error(
    .column_coef_parse_basis(
      quote(1 + `(Intercept)`),
      row_vars = "(Intercept)"
    ),
    "reserved"
  )
})

test_that(".column_coef_drop_nonfixed strips covstruct leaves", {
  lat <- call("latent", quote(1 | unit))
  rhs <- call("+", lat, call("column_coef", quote(1 + z | trait)))
  dropped <- .column_coef_drop_nonfixed(rhs)
  expect_null(dropped)
  only_lat <- .column_coef_drop_nonfixed(call("+", lat, 1))
  expect_equal(only_lat, 1)
  bare <- .column_coef_drop_nonfixed(call("+", 1, call("x", 2)))
  expect_true(is.call(bare))
})

test_that(".column_coef_assert_additive_placement accepts top-level bars", {
  expr <- call("+", call("column_coef", quote(1 + x | trait)), 0)
  expect_true(.column_coef_assert_additive_placement(expr))
  wrapped <- call("(", call("column_coef", quote(1 + x | trait)))
  expect_error(
    .column_coef_assert_additive_placement(wrapped),
    "top-level additive"
  )
})

test_that(".lambda_constraint_decision helpers label methods", {
  expect_equal(
    .lambda_constraint_decision_basis("lower_triangular"),
    "rotation convention"
  )
  expect_equal(
    .lambda_constraint_decision_cost("profile_retention"),
    "one refit per testable loading"
  )
  expect_equal(
    .recommend_lambda_constraint_method(c("pin_top_one", "wald_retention")),
    "wald_retention"
  )
  expect_equal(.recommend_lambda_constraint_method("none"), "none")
})