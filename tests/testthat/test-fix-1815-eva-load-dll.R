## #1815: `.eva_load_dll(rebuild = TRUE)` must not dyn.unload() a live
## gllvmTMB_eva DLL while other ADFuns still hold external pointers.

test_that("a loaded EVA DLL stays loaded when a later call asks to rebuild (#1815)", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  first <- .eva_load_dll(rebuild = FALSE)
  expect_identical(first$DLL, "gllvmTMB_eva")
  expect_false(is.null(getLoadedDLLs()[["gllvmTMB_eva"]]))
  again <- .eva_load_dll(rebuild = TRUE)
  expect_identical(again$DLL, "gllvmTMB_eva")
  expect_identical(again$checksum, first$checksum)
  expect_false(is.null(getLoadedDLLs()[["gllvmTMB_eva"]]))
})