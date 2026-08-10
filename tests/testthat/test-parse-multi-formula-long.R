test_that("long public fixed formulas are reconstituted without a character warning", {
  old_width <- getOption("width")
  on.exit(options(width = old_width), add = TRUE)
  options(width = 25)
  formula <- stats::as.formula(
    "value ~ 0 + trait + trait:x1 + trait:x2 + trait:x3 + trait:x4 + trait:x5"
  )

  expect_no_warning(parsed <- parse_multi_formula(formula))
  expect_s3_class(parsed$fixed, "formula")
  expect_identical(environment(parsed$fixed), environment(formula))
})
