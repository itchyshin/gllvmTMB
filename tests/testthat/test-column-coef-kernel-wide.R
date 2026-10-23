test_that("kernel pathway intercept and slope models match long and wide forms", {
  fx <- .make_kernel_coef_fixture(seed = 13244L, n_traits = 4L, n_unit = 18L)
  column_data <- data.frame(
    trait = fx$traits,
    pathway = factor(rep(c("C3", "C4"), each = 2L), levels = c("C3", "C4"))
  )
  for (bar in c("|", "||")) for (rho in c("0.37", "NULL")) {
    long <- stats::as.formula(paste0(
      "value ~ 0 + pathway + x:pathway + kernel_coef(1 + x ", bar,
      " trait, K = fx$K, name = 'env', rho = ", rho, ")"
    ), env = environment())
    wide <- stats::as.formula(paste0(
      "traits(t1,t2,t3,t4) ~ 0 + pathway + x:pathway + ",
      "kernel_coef(1 + x ", bar,
      " trait, K = fx$K, name = 'env', rho = ", rho, ")"
    ), env = environment())
    long_fit <- suppressMessages(gllvmTMB::gllvmTMB(
      long, data = fx$long, column_data = column_data, trait = "trait",
      unit = "unit", family = stats::gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
    ))
    wide_fit <- suppressMessages(gllvmTMB::gllvmTMB(
      wide, data = fx$wide, column_data = column_data, unit = "unit",
      family = stats::gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
    ))
    expect_identical(wide_fit$tmb_data, long_fit$tmb_data)
    expect_identical(.kernel_map_signature(wide_fit),
                     .kernel_map_signature(long_fit))
    expect_identical(wide_fit$opt$objective, long_fit$opt$objective)
    expect_identical(wide_fit$opt$par, long_fit$opt$par)
    expect_identical(gllvmTMB::extract_Sigma(wide_fit, level = "column_coef"),
                     gllvmTMB::extract_Sigma(long_fit, level = "column_coef"))
  }
})
