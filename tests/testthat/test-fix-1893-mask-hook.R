test_that(".gllvm_mask_hook_installed is reconciled when stale (#1893)", {
  has_hook <- function(fn = .gllvm_mask_on_gllvm_load) {
    on_load <- getHook(packageEvent("gllvm", "onLoad"))
    any(vapply(on_load, function(h) identical(h, fn), logical(1L)))
  }

  expect_true(has_hook())
  expect_true(.gllvm_mask_hook_installed)

  ns <- asNamespace("gllvmTMB")
  unlockBinding(".gllvm_mask_hook_installed", ns)
  assign(".gllvm_mask_hook_installed", TRUE, envir = ns)
  lockBinding(".gllvm_mask_hook_installed", ns)
  setHook(packageEvent("gllvm", "onLoad"), list(), action = "replace")
  expect_false(has_hook())

  ns$.onLoad(libname = .libPaths()[1L], pkgname = "gllvmTMB")
  expect_true(has_hook())
  expect_true(.gllvm_mask_hook_installed)
})