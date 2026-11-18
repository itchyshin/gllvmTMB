# block_V() must refuse NA in study_id, sampling_var, or rho_within.
# An NA study label used to become a silent zero row/column (the strongest
# possible meta-analysis weight if that V is passed to meta_V()). NA in
# sampling_var or rho_within used to throw a raw R comparison error (#1420).

test_that("block_V() refuses NA in study_id (#1420)", {
  expect_error(
    block_V(c("a", "a", NA, "b"), c(0.1, 0.2, 0.3, 0.4)),
    regexp = "study_id",
    class = "rlang_error"
  )
})

test_that("block_V() refuses NA in sampling_var (#1420)", {
  expect_error(
    block_V(c("a", "a", "b"), c(0.1, NA, 0.3)),
    regexp = "sampling_var",
    class = "rlang_error"
  )
})

test_that("block_V() refuses NA in rho_within (#1420)", {
  expect_error(
    block_V(c("a", "a", "b"), c(0.1, 0.2, 0.3), rho_within = NA_real_),
    regexp = "rho_within",
    class = "rlang_error"
  )
})
