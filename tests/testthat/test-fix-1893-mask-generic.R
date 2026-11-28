test_that(".gllvm_mask_is_generic() matches UseMethod calls, not substrings (#1893)", {
  fake <- function(x) {
    stop("Do not call UseMethod in this message")
  }
  expect_false(.gllvm_mask_is_generic(fake))

  real <- function(x, ...) {
    UseMethod("real")
  }
  expect_true(.gllvm_mask_is_generic(real))
  expect_true(.gllvm_mask_is_generic(print))

  expect_false(.gllvm_mask_is_generic(NULL))
  expect_false(.gllvm_mask_is_generic("not a function"))
})