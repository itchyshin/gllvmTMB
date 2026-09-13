.temporal_dep_kernel_nlminb_dev_path <- function(...) {
  testthat::test_path("..", "..", "dev", "temporal-program", ...)
}

test_that("the nlminb temporal-kernel candidate is independently frozen", {
  script <- .temporal_dep_kernel_nlminb_dev_path("run-dep-kernel-occasion-nlminb-qualification.R")
  skip_if_not(file.exists(script), "developer-only nlminb candidate runner is unavailable")
  source(script, local = environment())
  plan <- .temporal_dep_kernel_nlminb_plan()
  expect_equal(nrow(plan), 9L)
  expect_setequal(plan$phi, c(-.4, 0, .6))
  expect_setequal(plan$seed, 2609381:2609383)
  expect_false(any(plan$seed %in% 2609370:2609373))
  expect_equal(.temporal_dep_kernel_nlminb_prerun(),
    list(phi = .6, seed = 2609380L, n_series = 80L, n_time = 32L))
  expect_error(.temporal_dep_kernel_nlminb_validate(.6, 2609373L), "disjoint")
  expect_error(.temporal_dep_kernel_nlminb_validate(.5, 2609381L), "frozen persistence")
  control <- .temporal_dep_kernel_nlminb_control()
  expect_identical(control$optimizer, "nlminb")
  expect_identical(control$optimizer_passes, 2L)
  expect_identical(control$optArgs$scale, 1)
  expect_identical(control$optArgs$control$iter.max, 3000L)
  expect_identical(control$optArgs$control$eval.max, 12000L)
  expect_true(isTRUE(control$optimizer_diagnostics))
  probe <- data.frame(x = 1)
  attr(probe, "optimizer_diagnostics") <- list(
    pass_history = data.frame(pass = 1:2, message = c("one", "two")),
    final_parameter = c(a = 1), final_gradient = c(a = 0),
    final_objective = 1, warnings = character(), control = control
  )
  round_trip <- unserialize(serialize(probe, NULL))
  retained <- attr(round_trip, "optimizer_diagnostics")
  expect_identical(retained$pass_history$message, c("one", "two"))
  expect_identical(retained$final_parameter, c(a = 1))
  source_text <- paste(readLines(script, warn = FALSE), collapse = "\n")
  expect_false(grepl("simulate\\.gllvmTMB", source_text))
  expect_match(source_text, "NLMINB_CELL_ERROR_RETAINED")
  expect_false(grepl("CELL_PASS", source_text, fixed = TRUE))
})

test_that("nlminb campaign aggregation rejects incomplete or duplicated cells", {
  script <- .temporal_dep_kernel_nlminb_dev_path("run-dep-kernel-occasion-nlminb-qualification.R")
  skip_if_not(file.exists(script), "developer-only nlminb candidate runner is unavailable")
  source(script, local = environment())
  plan <- .temporal_dep_kernel_nlminb_plan()
  expect_silent(.temporal_dep_kernel_nlminb_validate_campaign(plan))
  expect_error(.temporal_dep_kernel_nlminb_validate_campaign(plan[-1L, , drop = FALSE]),
    "missing frozen campaign cell")
  expect_error(.temporal_dep_kernel_nlminb_validate_campaign(rbind(plan, plan[1L, ])),
    "exactly once")
  one <- plan[1L, , drop = FALSE]
  one$terminal <- "success"
  one$convergence <- 0L
  one$pass_1_convergence <- 0L
  one$pass_2_convergence <- 0L
  one$pass_2_accepted <- TRUE
  one$max_gradient <- 0
  one$phi_estimate <- one$phi
  one$temporal_frobenius_relative_error <- 0
  one$kernel_1 <- .35^2
  one$kernel_2 <- .28^2
  one$kernel_3 <- .40^2
  one$beta_1 <- .2
  one$beta_2 <- -.3
  one$beta_3 <- .1
  expect_silent(.temporal_dep_kernel_nlminb_summarise(one))
  expect_error(.temporal_dep_kernel_nlminb_summarise_campaign(one),
    "missing frozen campaign cell")
})
