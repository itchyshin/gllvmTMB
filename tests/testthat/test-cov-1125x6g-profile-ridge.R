test_that("profile-derived par helpers read opt$par", {
  fit <- list(opt = list(par = c(b = 1, a = 2, c = 3)))
  expect_equal(length(.zero_lincomb(fit)), 3L)
  expect_true(all(.zero_lincomb(fit) == 0))
  expect_equal(.par_indices(fit, "a"), 2L)
  expect_false(.has_param(fit, "theta_rr_B"))
  expect_true(.has_param(fit, "b"))
})

test_that(".ridge_path_verdict returns insufficient on empty input", {
  out <- .ridge_path_verdict(
    tau = c(1, 2),
    max_loading = c(NA_real_, 1.2)
  )
  expect_equal(out$verdict, "insufficient")
  expect_equal(out$mode, "none")
  out2 <- .ridge_path_verdict(numeric(0), numeric(0))
  expect_equal(out2$verdict, "insufficient")
})

test_that(".ridge_path_verdict classifies elasticity path", {
  out <- .ridge_path_verdict(
    tau = c(0.1, 1, 10),
    max_loading = c(5, 4, 2)
  )
  expect_true(out$mode %in% c("elasticity", "boundary", "none"))
  expect_true(out$verdict %in% c("penalty-determined", "interior", "insufficient"))
  expect_true(is.logical(out$inf_unconverged))
})

test_that(".ridge_path_verdict boundary mode uses converged Inf tau", {
  out <- .ridge_path_verdict(
    tau = c(1, Inf),
    max_loading = c(3, 8),
    convergence = c(0L, 0L)
  )
  expect_equal(out$mode, "boundary")
  expect_true(is.finite(out$statistic))
  bad <- .ridge_path_verdict(
    tau = c(1, Inf),
    max_loading = c(3, 99),
    convergence = c(0L, 1L)
  )
  expect_equal(bad$verdict, "insufficient")
  expect_true(bad$inf_unconverged)
})

test_that(".ridge_path_verdict validates convergence length", {
  expect_error(
    .ridge_path_verdict(c(1, 2), c(1, 2), convergence = 0L),
    "convergence"
  )
})

test_that("print.gllvmTMB_ridge_path formats data frame", {
  x <- structure(
    data.frame(tau = c(0, 1), max_abs_loading = c(2, 1.5)),
    class = c("gllvmTMB_ridge_path", "data.frame")
  )
  expect_output(print(x), "ridge-path sensitivity")
})