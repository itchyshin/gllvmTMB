test_that("unsupported formula helpers fail before model-matrix evaluation", {
  cases <- list(
    s = value ~ trait + s(x),
    te = value ~ trait + te(x, z),
    strata = value ~ trait + strata(block),
    cluster = value ~ trait + cluster(unit),
    weights = value ~ trait + weights(w)
  )
  alternatives <- c(
    s = "Precompute the intended basis",
    te = "Precompute the intended basis",
    strata = "documented grouping and covariance keywords",
    cluster = "documented grouping and covariance keywords",
    weights = "top-level weights = argument"
  )

  for (nm in names(cases)) {
    expect_error(
      gllvmTMB:::parse_multi_formula(cases[[nm]]),
      alternatives[[nm]],
      class = "gllvmTMB_unsupported_formula_helper",
      fixed = TRUE,
      info = nm
    )
  }
})

test_that("formula helper guard inspects nested calls without rejecting variables", {
  expect_error(
    gllvmTMB:::parse_multi_formula(value ~ trait + I(s(x))),
    "Unsupported formula helper",
    class = "gllvmTMB_unsupported_formula_helper"
  )

  parsed <- gllvmTMB:::parse_multi_formula(
    value ~ trait + s + log(weights) + x:cluster
  )
  expect_identical(
    deparse(parsed$fixed[[3L]]),
    "trait + s + log(weights) + x:cluster"
  )
})
