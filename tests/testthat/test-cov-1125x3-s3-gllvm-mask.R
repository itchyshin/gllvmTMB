test_that(".gllvm_mask_is_generic() detects S3 generics", {
  expect_true(gllvmTMB:::.gllvm_mask_is_generic(stats::simulate))
  plain <- function(x) x + 1
  expect_false(gllvmTMB:::.gllvm_mask_is_generic(plain))
  expect_false(gllvmTMB:::.gllvm_mask_is_generic("not a function"))
})

test_that(".gllvm_mask_call() maps object to fit", {
  received <- NULL
  fn <- function(fit, ...) {
    received <<- fit
    42L
  }
  obj <- list(foo = 1)
  expect_equal(
    gllvmTMB:::.gllvm_mask_call(fn, obj, extra = "x"),
    42L
  )
  expect_identical(received, obj)
})

test_that(".register_gllvm_masking_methods() is a no-op when gllvm is absent", {
  if (isNamespaceLoaded("gllvm")) {
    skip("gllvm is loaded; unload path is environment-specific")
  }
  expect_false(gllvmTMB:::.register_gllvm_masking_methods())
})

test_that(".gllvm_mask_classes() includes current gllvmTMB fit classes", {
  cls <- gllvmTMB:::.gllvm_mask_classes
  expect_true("gllvmTMB_multi" %in% cls)
  expect_true("gllvmTMB_va" %in% cls)
})