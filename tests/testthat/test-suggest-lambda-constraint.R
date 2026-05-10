# Tests for suggest_lambda_constraint(): produces a default rotational-fix
# matrix that users can pass to `gllvmTMB(..., lambda_constraint = ...)`.
#
# Implementation: R/suggest-lambda-constraint.R

test_that("lower_triangular for T = 5, K = 2 pins the upper triangle to 0", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:5), 4)),
    site  = factor(rep(paste0("s", 1:4), each = 5)),
    value = rnorm(20)
  )
  res <- suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = d
  )
  M <- res$constraint
  expect_equal(dim(M), c(5L, 2L))
  expect_equal(M[1, 2], 0)            # upper triangle pinned
  expect_true(is.na(M[2, 1]))         # strict lower triangle free
  expect_true(is.na(M[1, 1]))         # diagonal free
  expect_true(is.na(M[2, 2]))         # diagonal free
  expect_equal(res$n_pins, 1L)        # K(K-1)/2 = 1
  expect_equal(res$d, 2L)
  expect_equal(rownames(M), paste0("t", 1:5))
  expect_equal(colnames(M), c("f1", "f2"))
  expect_match(res$usage_hint, "lambda_constraint = list\\(B =")
})

test_that("lower_triangular for T = 4, K = 3 pins K(K-1)/2 = 3 entries", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:4), 5)),
    site  = factor(rep(paste0("s", 1:5), each = 4)),
    value = rnorm(20)
  )
  res <- suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 3),
    data = d
  )
  M <- res$constraint
  expect_equal(dim(M), c(4L, 3L))
  expect_equal(res$n_pins, 3L)
  expect_equal(M[1, 2], 0); expect_equal(M[1, 3], 0); expect_equal(M[2, 3], 0)
  expect_true(is.na(M[2, 1]))
  expect_true(is.na(M[3, 1]))
  expect_true(is.na(M[3, 3]))
  # Total pins = number of zeros = 3
  expect_equal(sum(!is.na(M) & M == 0), 3L)
})

test_that("K = 1 returns an all-NA matrix with explanatory note", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:3), 4)),
    site  = factor(rep(paste0("s", 1:4), each = 3)),
    value = rnorm(12)
  )
  res <- suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = d
  )
  expect_equal(dim(res$constraint), c(3L, 1L))
  expect_true(all(is.na(res$constraint)))
  expect_equal(res$n_pins, 0L)
  expect_match(res$note, "K = 1")
})

test_that("convention = 'pin_top_one' returns M[1, 1] = 1 and rest NA", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:4), 4)),
    site  = factor(rep(paste0("s", 1:4), each = 4)),
    value = rnorm(16)
  )
  res <- suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = d,
    convention = "pin_top_one"
  )
  expect_equal(res$constraint[1, 1], 1)
  expect_equal(sum(!is.na(res$constraint)), 1L)
  expect_equal(res$n_pins, 1L)
  expect_equal(res$convention, "pin_top_one")
})

test_that("convention = 'none' returns an all-NA matrix", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:4), 4)),
    site  = factor(rep(paste0("s", 1:4), each = 4)),
    value = rnorm(16)
  )
  res <- suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = d,
    convention = "none"
  )
  expect_true(all(is.na(res$constraint)))
  expect_equal(res$n_pins, 0L)
})

test_that("K > T errors", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:2), 4)),
    site  = factor(rep(paste0("s", 1:4), each = 2)),
    value = rnorm(8)
  )
  expect_error(
    suggest_lambda_constraint(
      value ~ 0 + trait + latent(0 + trait | site, d = 3),
      data = d
    ),
    "exceeds number of traits"
  )
})

test_that("level = 'W' on a formula without a within-unit latent() term errors", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:4), 4)),
    site  = factor(rep(paste0("s", 1:4), each = 4)),
    value = rnorm(16)
  )
  expect_error(
    suggest_lambda_constraint(
      value ~ 0 + trait + latent(0 + trait | site, d = 2),
      data = d,
      level = "W"
    ),
    "no .*latent.*term"
  )
})
