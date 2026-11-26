## #1960: bare `indep()` / `dep()` (no `lhs | group` formula) used to hit
## `e[[2L]]` in the sugar rewriter and surface as "subscript out of bounds".

test_that("bare indep() and dep() abort with a grammar error (#1960)", {
  df <- data.frame(
    unit = factor(rep(1:4, each = 2)),
    trait = factor(rep(c("t1", "t2"), 4)),
    value = c(1, 2, 3, 4, 5, 6, 7, 8)
  )

  indep_msg <- tryCatch(
    gllvmTMB(
      value ~ 0 + trait + indep(),
      data = df,
      unit = "unit",
      trait = "trait",
      family = poisson()
    ),
    error = function(e) conditionMessage(e)
  )
  expect_match(indep_msg, "covariance specification")
  expect_match(indep_msg, "indep\\(0 \\+ trait \\| unit\\)")
  expect_false(grepl("subscript out of bounds", indep_msg, fixed = TRUE))

  dep_msg <- tryCatch(
    gllvmTMB(
      value ~ 0 + trait + dep(),
      data = df,
      unit = "unit",
      trait = "trait",
      family = poisson()
    ),
    error = function(e) conditionMessage(e)
  )
  expect_match(dep_msg, "covariance specification")
  expect_match(dep_msg, "dep\\(0 \\+ trait \\| unit\\)")
  expect_false(grepl("subscript out of bounds", dep_msg, fixed = TRUE))
})