## #1590: an unconverged tau = Inf row must not anchor the boundary comparison.

test_that("unconverged Inf falls back to the elasticity comparison", {
  tau <- c(1, 2, Inf)
  loading <- c(1, 1, 10)
  failed <- gllvmTMB:::.ridge_path_verdict(
    tau, loading, convergence = c(0L, 0L, 1L)
  )
  expect_identical(failed$mode, "elasticity")
  expect_identical(failed$verdict, "interior")
  expect_true(failed$inf_unconverged)

  converged <- gllvmTMB:::.ridge_path_verdict(
    tau, loading, convergence = c(0L, 0L, 0L)
  )
  expect_identical(converged$mode, "boundary")
  expect_identical(converged$verdict, "penalty-determined")
  expect_false(converged$inf_unconverged)

  omitted <- gllvmTMB:::.ridge_path_verdict(tau, loading)
  expect_identical(omitted$mode, "boundary")
  expect_false(omitted$inf_unconverged)
})

test_that("print says when the Inf refit did not converge", {
  x <- data.frame(
    tau = c(1, 2, Inf),
    trait = "sp1",
    max_loading = c(1, 1, 10),
    convergence = c(0L, 0L, 1L),
    stringsAsFactors = FALSE
  )
  class(x) <- c("gllvmTMB_ridge_path", "data.frame")
  out <- paste(capture.output(print(x)), collapse = "\n")
  expect_match(out, "log-log elasticity", fixed = TRUE)
  expect_match(out, "The tau = Inf refit did not converge.", fixed = TRUE)
  expect_false(grepl("relative change to Inf", out, fixed = TRUE))
})
