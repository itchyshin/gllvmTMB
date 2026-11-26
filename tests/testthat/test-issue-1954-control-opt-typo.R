test_that("gllvmTMBcontrol(opt = ...) names optArgs (#1954)", {
  expect_error(
    gllvmTMBcontrol(opt = list(iter.max = 200, eval.max = 250)),
    regexp = "optArgs"
  )
  expect_error(
    gllvmTMBcontrol(opt = list(iter.max = 200, eval.max = 250)),
    regexp = "opt"
  )
})