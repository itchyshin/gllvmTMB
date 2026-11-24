## #1397: a collapsed ordinal cutpoint increment (empty intermediate
## category) must raise a boundary flag instead of passing check_gllvmTMB().

test_that("#1397: collapsed ordinal log-increment fires boundary_ordinal_cutpoint", {
  fake_fit <- list(
    report = list(),
    opt = list(par = c(b_fix = 0.67, ordinal_log_increments = -0.6,
                       ordinal_log_increments = -21.5,
                       ordinal_log_increments = 0.2)),
    use = list()
  )
  expect_true("boundary_ordinal_cutpoint" %in%
                gllvmTMB:::.gllvmTMB_boundary_flags(fake_fit))
})

test_that("#1397: healthy ordinal log-increments do not fire the flag", {
  fake_fit <- list(
    report = list(),
    opt = list(par = c(b_fix = 0.67, ordinal_log_increments = -0.6,
                       ordinal_log_increments = 0.1)),
    use = list()
  )
  expect_false("boundary_ordinal_cutpoint" %in%
                 gllvmTMB:::.gllvmTMB_boundary_flags(fake_fit))
})
