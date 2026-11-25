## Coverage (cursor-cloud-1125x5g): brms-sugar LHS flatten / slope matchers (no fits).

test_that(".strip_lhs_parens() peels redundant parentheses", {
  e <- quote(((1 + x)))
  expect_equal(
    deparse(gllvmTMB:::.strip_lhs_parens(e)),
    "1 + x"
  )
  expect_identical(gllvmTMB:::.strip_lhs_parens(quote(x)), quote(x))
})

test_that(".is_one_lhs() recognises intercept one", {
  expect_true(gllvmTMB:::.is_one_lhs(quote(1)))
  expect_true(gllvmTMB:::.is_one_lhs(quote((1))))
  expect_false(gllvmTMB:::.is_one_lhs(quote(0 + trait)))
})

test_that(".is_zero_plus_trait() recognises 0 + trait heads", {
  expect_true(gllvmTMB:::.is_zero_plus_trait(quote(0 + trait)))
  expect_true(gllvmTMB:::.is_zero_plus_trait(quote(0 + t), trait_col = "t"))
  expect_false(gllvmTMB:::.is_zero_plus_trait(quote(1 + trait)))
})

test_that(".flatten_lhs_plus() preserves source order for nested plus", {
  e <- quote(1 + x1 + x2)
  flat <- gllvmTMB:::.flatten_lhs_plus(e)
  expect_length(flat, 3L)
  expect_true(gllvmTMB:::.is_one_lhs(flat[[1L]]))
  expect_equal(vapply(flat[-1L], deparse, ""), c("x1", "x2"))

  atomic <- gllvmTMB:::.flatten_lhs_plus(quote(0 + trait))
  expect_length(atomic, 1L)
  expect_true(gllvmTMB:::.is_zero_plus_trait(atomic[[1L]]))
})

test_that(".assert_distinct_slope_cols() refuses duplicate slope names", {
  expect_error(
    gllvmTMB:::.assert_distinct_slope_cols(c("x", "x")),
    "Duplicate slope"
  )
  expect_invisible(gllvmTMB:::.assert_distinct_slope_cols(c("x", "y")))
})

test_that(".match_wide_intercept_slopes() parses 1 + covariate wide LHS", {
  cols <- gllvmTMB:::.match_wide_intercept_slopes(quote(1 + temp + rain))
  expect_equal(cols, c("temp", "rain"))
  expect_null(gllvmTMB:::.match_wide_intercept_slopes(quote(0 + trait)))
  expect_null(gllvmTMB:::.match_wide_intercept_slopes(quote(1 + trait)))
  expect_equal(
    gllvmTMB:::.match_wide_intercept_slopes(quote(1 + (temp))),
    "temp"
  )
})

test_that(".match_long_intercept_slopes() parses trait interaction slopes", {
  lhs <- quote(0 + trait + (0 + trait):temp + (0 + trait):rain)
  cols <- gllvmTMB:::.match_long_intercept_slopes(lhs)
  expect_equal(cols, c("temp", "rain"))
  expect_null(
    gllvmTMB:::.match_long_intercept_slopes(quote(0 + trait + temp))
  )
})

test_that(".gllvmTMB_lhs_form() labels wide vs long shapes", {
  wide <- gllvmTMB:::.gllvmTMB_lhs_form(quote(1 + x), trait_col = "trait")
  expect_equal(wide$lhs_form, "wide_intercept_slope")
  expect_equal(wide$slope_cols, "x")

  long <- gllvmTMB:::.gllvmTMB_lhs_form(quote(0 + trait), trait_col = "trait")
  expect_equal(long$lhs_form, "intercept_only")

  bare <- gllvmTMB:::.gllvmTMB_lhs_form(quote(1), trait_col = "trait")
  expect_equal(bare$lhs_form, "intercept_only")
})

test_that(".slope_only_covariate() extracts a lone slope column when present", {
  expect_equal(
    gllvmTMB:::.slope_only_covariate(quote(env_temp)),
    "env_temp"
  )
  expect_equal(
    gllvmTMB:::.slope_only_covariate(quote(0 + env_temp)),
    "env_temp"
  )
  expect_null(gllvmTMB:::.slope_only_covariate(quote(1)))
})

test_that(".slope_only_next_step() names the wide formula route", {
  msg <- gllvmTMB:::.slope_only_next_step("temp")
  expect_type(msg, "character")
  expect_match(msg, "slope")
  expect_match(msg, "temp")
})