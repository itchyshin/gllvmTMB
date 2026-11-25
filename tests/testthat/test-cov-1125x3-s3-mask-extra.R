test_that(".gllvm_mask_methods() lists every forwarded generic", {
  meth <- gllvmTMB:::.gllvm_mask_methods
  expect_true(is.list(meth))
  expect_true(all(c(
    "getLoadings", "getLV", "getResidualCov", "getResidualCor", "VP", "simulate"
  ) %in% names(meth)))
})

test_that("mask forwarding functions are functions", {
  meth <- gllvmTMB:::.gllvm_mask_methods
  expect_true(all(vapply(meth, is.function, logical(1L))))
})

test_that(".gllvm_mask_getLV() is a function", {
  expect_true(is.function(gllvmTMB:::.gllvm_mask_getLV))
})

test_that(".gllvm_mask_hook flag is a scalar logical", {
  expect_type(gllvmTMB:::.gllvm_mask_hook_installed, "logical")
  expect_length(gllvmTMB:::.gllvm_mask_hook_installed, 1L)
})