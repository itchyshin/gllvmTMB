.d86_optimizer_harness_root <- function() {
  root <- normalizePath(getwd(), mustWork = TRUE)
  repeat {
    if (file.exists(file.path(root, "dev", "design86-optimizer-diagnostic-harness.R"))) {
      return(root)
    }
    parent <- dirname(root)
    if (identical(parent, root)) break
    root <- parent
  }
  stop("Run this test from the gllvmTMB worktree.", call. = FALSE)
}

source(file.path(.d86_optimizer_harness_root(), "dev", "design86-optimizer-diagnostic-harness.R"))

test_that("controlled optimizer trace records every stage", {
  controlled <- design86_controlled_quadratic_objective()
  trace <- design86_optimizer_diagnostic_trace(
    objective = controlled$objective,
    gradient = controlled$gradient,
    start = controlled$start
  )

  expect_length(trace$stages, 4L)
  expect_equal(vapply(trace$stages, `[[`, character(1), "stage"),
               c("nlminb_1", "nlminb_2", "nlminb_3", "bfgs"))
  expect_equal(vapply(trace$stages, `[[`, character(1), "optimizer"),
               c("nlminb", "nlminb", "nlminb", "BFGS"))

  required <- c("stage", "optimizer", "parameter", "objective", "max_abs_gradient",
                "convergence", "message", "counts")
  for (stage in trace$stages) {
    expect_named(stage, required)
    expect_equal(names(stage$parameter), names(controlled$solution))
    expect_type(stage$objective, "double")
    expect_type(stage$max_abs_gradient, "double")
    expect_type(stage$convergence, "integer")
    expect_type(stage$message, "character")
    expect_named(stage$counts, c("function", "gradient"))
    expect_equal(all(stage$counts >= 0L), TRUE)
  }

  final <- trace$stages[[4L]]
  expect_equal(final$parameter, controlled$solution, tolerance = 1e-8)
  expect_equal(final$objective, 0, tolerance = 1e-12)
  expect_lte(final$max_abs_gradient, 1e-7)
  expect_equal(final$convergence, 0L)
})

test_that("controlled optimizer trace retains a deliberately non-stationary outcome", {
  controlled <- design86_controlled_nonstationary_objective()
  trace <- design86_optimizer_diagnostic_trace(
    objective = controlled$objective,
    gradient = controlled$gradient,
    start = controlled$start,
    nlminb_control = list(eval.max = 5L, iter.max = 5L),
    bfgs_control = list(maxit = 5L, reltol = 1e-12)
  )

  expect_length(trace$stages, 4L)
  expect_true(any(vapply(trace$stages, function(x) x$convergence != 0L, logical(1))))
  expect_true(all(vapply(trace$stages, function(x) is.finite(x$max_abs_gradient) && x$max_abs_gradient > 0, logical(1))))
})
