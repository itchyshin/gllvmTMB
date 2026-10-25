## #1576: wrapper defaults stay at nsim = 500 (NEWS, #1422). A caller who
## keeps that default must not be told it is too small, and the warning
## must name nsim rather than n_boot. The Sigma-diagonal hint is only for
## a bootstrap that asks for Sigma.

warn_text <- function(expr) {
  msgs <- character()
  withCallingHandlers(
    force(expr),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  paste(msgs, collapse = "\n")
}

test_that("bootstrap count defaults stay where NEWS left them", {
  expect_identical(formals(bootstrap_Sigma)$n_boot, 999)
  expect_identical(formals(extract_correlations)$nsim, 500L)
  expect_identical(formals(extract_cross_correlations)$nsim, 500L)
  expect_identical(formals(extract_repeatability)$nsim, 500L)
  expect_identical(formals(extract_communality)$nsim, 500L)
  expect_identical(formals(confint.gllvmTMB_multi)$nsim, 500L)
})

test_that("wrapper calls name nsim for the bootstrap count warning", {
  wrapped <- c(
    deparse(body(extract_correlations)),
    deparse(body(extract_cross_correlations)),
    deparse(body(extract_repeatability)),
    deparse(body(extract_communality)),
    deparse(body(.confint_sigma_bootstrap))
  )
  expect_gte(sum(grepl(".with_bootstrap_count_arg", wrapped, fixed = TRUE)), 5L)
})

test_that("nsim = 500 does not warn, and a smaller nsim names nsim", {
  ceiling_40 <- (40 - 1) / (40 + 1)
  expect_identical(.bootstrap_active_count_arg(), "n_boot")

  default_msg <- .with_bootstrap_count_arg("nsim", warn_text(
    .bootstrap_emit_count_warning(
      500L, 0.95, "R", (500 - 1) / (500 + 1), 39L, .bootstrap_active_count_arg()
    )
  ))
  expect_identical(default_msg, "")
  expect_identical(.bootstrap_active_count_arg(), "n_boot")

  small <- .with_bootstrap_count_arg("nsim", warn_text(
    .bootstrap_emit_count_warning(
      40L, 0.95, "R", ceiling_40, 39L, .bootstrap_active_count_arg()
    )
  ))
  expect_match(small, "nsim", fixed = TRUE)
  expect_no_match(small, "n_boot")
  expect_no_match(small, "n_cores")
  expect_no_match(small, "profile_ci_total_variance")
  expect_match(small, "noisy percentile bounds", fixed = TRUE)

  sigma_hint <- .with_bootstrap_count_arg("nsim", warn_text(
    .bootstrap_emit_count_warning(
      40L, 0.95, "Sigma", ceiling_40, 39L, .bootstrap_active_count_arg()
    )
  ))
  expect_match(sigma_hint, "profile_ci_total_variance", fixed = TRUE)
  expect_match(sigma_hint, "nsim", fixed = TRUE)

  floor_msg <- .with_bootstrap_count_arg("nsim", warn_text(
    .bootstrap_emit_count_warning(
      10L, 0.95, "ICC", (10 - 1) / (10 + 1), 39L, .bootstrap_active_count_arg()
    )
  ))
  expect_match(floor_msg, "cannot deliver", fixed = TRUE)
  expect_match(floor_msg, "nsim", fixed = TRUE)
  expect_match(floor_msg, "500 is the default", fixed = TRUE)
  expect_no_match(floor_msg, "999 is the default")
  expect_no_match(floor_msg, "n_cores")
  expect_no_match(floor_msg, "profile_ci_total_variance")
  expect_no_match(floor_msg, "coverage_ceiling")
})

test_that("bootstrap_Sigma itself still warns below 999 and names n_boot", {
  direct <- warn_text(.bootstrap_emit_count_warning(
    500L, 0.95, "R", (500 - 1) / (500 + 1), 39L, "n_boot"
  ))
  expect_match(direct, "n_boot", fixed = TRUE)
  expect_match(direct, "n_cores", fixed = TRUE)
  expect_match(direct, "noisy percentile bounds", fixed = TRUE)
  expect_no_match(direct, "profile_ci_total_variance")

  sigma <- warn_text(.bootstrap_emit_count_warning(
    500L, 0.95, c("Sigma", "R"), (500 - 1) / (500 + 1), 39L, "n_boot"
  ))
  expect_match(sigma, "profile_ci_total_variance", fixed = TRUE)

  none <- warn_text(.bootstrap_emit_count_warning(
    999L, 0.95, "Sigma", (999 - 1) / (999 + 1), 39L, "n_boot"
  ))
  expect_identical(none, "")

  low <- warn_text(.bootstrap_emit_count_warning(
    10L, 0.95, "Sigma", 9 / 11, 39L, "n_boot"
  ))
  expect_match(low, "cannot deliver", fixed = TRUE)
  expect_match(low, "999 is the default", fixed = TRUE)
  expect_match(low, "n_cores", fixed = TRUE)
  expect_match(low, "n_boot", fixed = TRUE)
  expect_match(low, "coverage_ceiling", fixed = TRUE)
})
