count_named_calls <- function(expr, name) {
  if (!is.call(expr) && !is.pairlist(expr) && !is.expression(expr)) {
    return(0L)
  }
  here <- as.integer(is.call(expr) && identical(expr[[1L]], as.name(name)))
  here + sum(vapply(as.list(expr), count_named_calls, integer(1L), name = name))
}

test_that("augmented-slope family contract has one canonical admission table", {
  contract <- gllvmTMB:::.augmented_slope_family_contract()

  expect_s3_class(contract, "data.frame")
  expect_equal(anyDuplicated(contract$family_id), 0L)
  expect_equal(
    contract$family_id,
    c(0L, 1L, 2L, 3L, 4L, 5L, 7L, 9L, 14L, 15L)
  )
  expect_equal(
    contract$family[contract$admission_basis == "c1_partial"],
    c("lognormal", "student")
  )
  expect_true(all(
    contract$evidence[contract$admission_basis == "c1_partial"] == "RE-14"
  ))
  expect_true(contract$link_0[contract$family == "binomial"])
  expect_true(contract$link_1[contract$family == "binomial"])
  expect_false(contract$link_2[contract$family == "binomial"])
  expect_false(any(contract$link_1[contract$family != "binomial"]))
  expect_false(any(contract$link_2))
})

test_that("augmented-slope family/link admission is exhaustive and link aware", {
  grid <- expand.grid(
    family_id = 0:16,
    link_id = 0:2,
    KEEP.OUT.ATTRS = FALSE
  )
  observed <- gllvmTMB:::.augmented_slope_family_allowed(
    grid$family_id,
    grid$link_id
  )
  expected <-
    grid$family_id %in% c(0L, 1L, 2L, 3L, 4L, 5L, 7L, 9L, 14L, 15L) &
    ((grid$family_id == 1L & grid$link_id %in% c(0L, 1L)) |
      (grid$family_id != 1L & grid$link_id == 0L))

  expect_equal(observed, expected)
  expect_true(gllvmTMB:::.augmented_slope_family_allowed(3L, 0L))
  expect_true(gllvmTMB:::.augmented_slope_family_allowed(9L, 0L))
  expect_false(gllvmTMB:::.augmented_slope_family_allowed(1L, 2L))
  expect_false(gllvmTMB:::.augmented_slope_family_allowed(16L, 0L))
  expect_equal(
    gllvmTMB:::.augmented_slope_family_allowed(
      c(0L, 1L, 3L, 9L),
      c(0L, 1L, 0L, 0L)
    ),
    rep(TRUE, 4L)
  )
  expect_error(
    gllvmTMB:::.augmented_slope_family_allowed(c(0L, 1L), 0L),
    "must have equal length"
  )
})

test_that("all six structured augmented-slope guards use the canonical policy", {
  fit_body <- body(gllvmTMB:::gllvmTMB_multi_fit)

  expect_equal(
    count_named_calls(fit_body, ".augmented_slope_family_allowed"),
    6L
  )
  expect_equal(
    count_named_calls(fit_body, ".augmented_slope_family_scope_text"),
    6L
  )

  scope <- gllvmTMB:::.augmented_slope_family_scope_text()
  expect_match(scope, "lognormal\\(\\)")
  expect_match(scope, "student\\(\\)")
  expect_match(scope, "C1-partial")
  expect_match(scope, "logit/probit only")
})
