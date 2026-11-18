test_that("warm starts copy reconstructed Gaussian cell effects", {
  conditional_mean <- matrix(c(0.4, -0.2, 0.7, -0.5), nrow = 2L)
  source_params <- list(s_B = matrix(0, 2L, 2L), theta_diag_B = c(-1, -2))
  source_fit <- structure(list(
    integrated_gaussian_diag_B = TRUE,
    report = list(s_B_conditional_mean = conditional_mean),
    opt = list(par = numeric(0)),
    tmb_obj = list(env = list(
      last.par.best = numeric(0),
      parList = function(...) source_params
    ))
  ), class = "gllvmTMB")
  target <- list(s_B = matrix(-9, 2L, 2L), theta_diag_B = c(0, 0))

  warm <- gllvmTMB:::.gllvmTMB_apply_start_from(target, source_fit)
  expect_equal(warm$params$s_B, conditional_mean)
  expect_equal(warm$params$theta_diag_B, source_params$theta_diag_B)
  expect_setequal(warm$copied, names(target))

  ## A legacy source still copies its actual tape parameters even if a report
  ## happens to contain a similarly named field.
  source_fit$integrated_gaussian_diag_B <- FALSE
  legacy <- gllvmTMB:::.gllvmTMB_apply_start_from(target, source_fit)
  expect_equal(legacy$params$s_B, source_params$s_B)

  ## Integration does not widen the existing same-shape copying contract.
  source_fit$integrated_gaussian_diag_B <- TRUE
  different_target <- list(s_B = matrix(-9, 2L, 3L))
  different <- gllvmTMB:::.gllvmTMB_apply_start_from(different_target, source_fit)
  expect_identical(different$params, different_target)
  expect_length(different$copied, 0L)
})
