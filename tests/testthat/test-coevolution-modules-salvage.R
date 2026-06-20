# Focused tests for the two salvaged coevolution exports
# (extract_coevolution_modules, diagnose_kernel_separability) ported from the
# dirty codex/r-bridge-grouped-dispersion working tree onto main.
#
# diagnose_kernel_separability is pure-R (dense kernels) and is covered fully
# here. extract_coevolution_modules requires a fitted gllvmTMB_multi 2-kernel
# coevolution model; its full fit-based recovery test lives in
# test-coevolution-two-kernel.R on the dirty tree and must be ported before this
# PR merges — here we only exercise its input guard.

test_that("diagnose_kernel_separability separates orthogonal kernels", {
  K_phy <- outer(1:4, 1:4, function(i, j) 0.7^abs(i - j))   # AR(1)-like, structured
  K_tip <- diag(4)                                          # identity, orthogonal-ish
  res <- diagnose_kernel_separability(phy = K_phy, tip = K_tip)

  expect_s3_class(res, "gllvmTMB_kernel_separability")
  expect_equal(dim(res$similarity), c(2L, 2L))
  expect_equal(diag(res$similarity), c(phy = 1, tip = 1))
  expect_true(isSymmetric(unname(res$similarity)))
  expect_equal(nrow(res$pairs), 1L)
  expect_true(all(c("level_1", "level_2", "similarity", "overlap_class",
                    "recommendation") %in% names(res$pairs)))
  # structured vs identity should not be highly overlapping
  expect_lt(res$pairs$similarity, 0.70)
})

test_that("diagnose_kernel_separability flags high overlap for duplicate kernels", {
  K <- outer(1:5, 1:5, function(i, j) 0.6^abs(i - j))
  res <- diagnose_kernel_separability(a = K, b = K)
  expect_equal(res$similarity[1L, 2L], 1, tolerance = 1e-8)
  expect_identical(res$pairs$overlap_class, "high")
})

test_that("diagnose_kernel_separability needs at least two kernels", {
  expect_error(
    diagnose_kernel_separability(only = diag(3)),
    "at least two kernel"
  )
})

test_that("diagnose_kernel_separability rejects mismatched dimensions", {
  expect_error(
    diagnose_kernel_separability(a = diag(3), b = diag(4)),
    "same dimensions"
  )
})

test_that("extract_coevolution_modules guards on non-multi input", {
  expect_error(
    extract_coevolution_modules(
      list(x = 1), level = "phy",
      row_traits = c("t1", "t2"), col_traits = c("t1", "t2")
    ),
    "Provide a fit returned by"
  )
})
