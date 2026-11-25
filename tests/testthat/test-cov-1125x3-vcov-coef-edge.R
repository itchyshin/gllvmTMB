test_that("coef.gllvmTMB_multi() returns empty named vector without fixed names", {
  obj <- structure(
    list(X_fix_names = character(0), report = list(b_fix = numeric(0))),
    class = "gllvmTMB_multi"
  )
  out <- coef(obj)
  expect_length(out, 0L)
  expect_type(out, "double")
})

test_that("vcov.gllvmTMB_multi() returns empty matrix without fixed names", {
  obj <- structure(
    list(
      X_fix_names = character(0),
      estimator = "ML",
      report = list(b_fix = numeric(0)),
      sd_report = NULL
    ),
    class = "gllvmTMB_multi"
  )
  V <- vcov(obj)
  expect_equal(dim(V), c(0L, 0L))
})

test_that("vcov.gllvmTMB_multi() refuses MSPL fits", {
  obj <- structure(
    list(
      X_fix_names = "x",
      estimator = "MSPL",
      class = c("gllvmTMB_mspl", "gllvmTMB_multi")
    ),
    class = c("gllvmTMB_mspl", "gllvmTMB_multi")
  )
  expect_error(vcov(obj), "MSPL")
})

test_that("coef.gllvmTMB_multi() reads b_fix from opt$par", {
  obj <- structure(
    list(
      X_fix_names = c("(Intercept):a"),
      opt = list(par = c(b_fix = 1.25))
    ),
    class = "gllvmTMB_multi"
  )
  expect_equal(coef(obj), c("(Intercept):a" = 1.25))
})