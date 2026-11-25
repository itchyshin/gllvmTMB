## Coverage (2026-11-25): validation paths in R/weights-shape.R not pinned in
## test-weights-unified.R.

nw <- function(...) {
  tryCatch(
    gllvmTMB:::normalise_weights(...),
    error = function(e) conditionMessage(e)
  )
}

test_that("normalise_weights() refuses non-numeric weights", {
  msg <- nw(weights = "bad", response_shape = "long", n_obs = 3L)
  expect_match(msg, "must be numeric")
})

test_that("normalise_weights() refuses negative and non-finite observed weights", {
  expect_match(
    nw(weights = c(1, -0.1, 1), response_shape = "long", n_obs = 3L),
    "non-negative"
  )
  expect_match(
    nw(weights = c(1, NA, 1), response_shape = "long", n_obs = 3L),
    "finite"
  )
  expect_match(
    nw(weights = c(1, Inf, 1), response_shape = "long", n_obs = 3L),
    "finite"
  )
})

test_that("normalise_weights(long) refuses wrong length and matrix weights", {
  expect_match(
    nw(weights = c(1, 2), response_shape = "long", n_obs = 3L),
    "length-3"
  )
  expect_match(
    nw(weights = matrix(1, 2, 2), response_shape = "long", n_obs = 4L),
    "gllvmTMB_wide"
  )
})

test_that("normalise_weights(wide_matrix) pins vector length and dim mismatches", {
  expect_match(
    nw(
      weights = c(1, 2, 3),
      response_shape = "wide_matrix",
      n_obs = 6L,
      n_units = 2L,
      n_traits = 3L
    ),
    "length does not match"
  )
  expect_match(
    nw(
      weights = matrix(1, 3, 3),
      response_shape = "wide_matrix",
      n_obs = 9L,
      n_units = 2L,
      n_traits = 3L
    ),
    "matrix shape must equal"
  )
  expect_match(
    nw(
      weights = array(1, dim = c(2, 2, 2)),
      response_shape = "wide_matrix",
      n_obs = 8L,
      n_units = 2L,
      n_traits = 2L
    ),
    "must be a vector, matrix, or scalar"
  )
})

test_that("normalise_weights(wide_matrix) enforces NA alignment with Y", {
  mask <- matrix(FALSE, 2, 2)
  mask[2, 1] <- TRUE
  w_bad_obs <- matrix(c(1, 2, NA, 4), 2, 2)
  expect_match(
    nw(
      weights = w_bad_obs,
      response_shape = "wide_matrix",
      n_obs = 3L,
      n_units = 2L,
      n_traits = 2L,
      na_mask = mask
    ),
    "NA where"
  )
  w_bad_miss <- matrix(c(1, 2, 3, 4), 2, 2)
  expect_match(
    nw(
      weights = w_bad_miss,
      response_shape = "wide_matrix",
      n_obs = 3L,
      n_units = 2L,
      n_traits = 2L,
      na_mask = mask
    ),
    "value where"
  )
})

test_that("normalise_weights(wide_df) refuses matrices and wrong row counts", {
  expect_match(
    nw(
      weights = matrix(1, 2, 2),
      response_shape = "wide_df",
      n_obs = 4L,
      n_units = 2L,
      n_traits = 2L
    ),
    "gllvmTMB_wide"
  )
  expect_match(
    nw(
      weights = c(1, 2, 3),
      response_shape = "wide_df",
      n_obs = 4L,
      n_units = 2L,
      n_traits = 2L
    ),
    "length-2"
  )
})

test_that(".weights_na_mask() refuses a bad internal mask", {
  expect_error(
    gllvmTMB:::.weights_na_mask(matrix(TRUE, 2, 3), 2L, 2L),
    "na_mask"
  )
  expect_error(
    gllvmTMB:::.weights_na_mask(matrix(c(TRUE, NA), 2, 1), 2L, 1L),
    "cannot contain NA"
  )
})