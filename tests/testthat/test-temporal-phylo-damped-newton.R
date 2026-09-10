source(testthat::test_path("..", "..", "dev", "temporal-program", "remote",
  "phylo-damped-newton-common.R"), local = TRUE)

test_that("damped Newton curvature accepts a stable exact quadratic", {
  A <- matrix(c(4, 1, 1, 3), 2, 2)
  theta <- c(alpha = 1, beta = -2)
  gradient <- function(x) drop(A %*% x)
  result <- temporal_phylo_damped_newton_curvature(theta, gradient)

  expect_true(result$eligible)
  expect_equal(unname(result$direction), -solve(A, gradient(theta)), tolerance = 1e-8)
  expect_equal(result$condition, max(eigen(A, symmetric = TRUE)$values) /
    min(eigen(A, symmetric = TRUE)$values), tolerance = 1e-8)
  expect_lt(result$direction_disagreement, 1e-10)
  expect_lt(result$solve_residual, 1e-12)
  expect_lt(result$g_dot_direction, 0)
})

test_that("damped Newton curvature rejects disagreement and nonpositive curvature", {
  theta <- c(alpha = .4, beta = -.7)
  indefinite <- temporal_phylo_damped_newton_curvature(theta, function(x) c(x[[1L]], -x[[2L]]))
  expect_false(indefinite$eligible)
  expect_true(any(grepl("positive_definite", indefinite$rejection_reasons)))

  unstable <- temporal_phylo_damped_newton_curvature(c(alpha = .001, beta = 0), function(x) {
    c(1e12 * x[[1L]]^3 + 3 * x[[1L]], 2 * x[[2L]])
  })
  expect_false(unstable$eligible)
  expect_true(any(grepl("direction", unstable$rejection_reasons)))
})

test_that("damped Newton chooses the first Armijo-eligible step", {
  baseline <- 10
  direction <- c(a = -1)
  gradient <- c(a = 2)
  result <- temporal_phylo_damped_newton_select_step(
    theta = c(a = 0), direction = direction, gradient = gradient,
    objective = baseline,
    evaluate = function(endpoint) list(
      eligible = TRUE,
      objective = if (endpoint[[1L]] == -1) 9.9 else 9.8,
      endpoint = endpoint
    )
  )
  expect_true(result$accepted)
  expect_identical(result$selected_index, 1L)
  expect_equal(result$selected_alpha, 1)
  expect_length(result$trials, 1L)
})

test_that("damped Newton does not mutate its supplied baseline", {
  theta <- c(alpha = 1, beta = -2)
  snapshot <- theta
  result <- temporal_phylo_damped_newton_select_step(
    theta = theta, direction = c(alpha = -1, beta = 1), gradient = c(alpha = 1, beta = -1),
    objective = 3,
    evaluate = function(endpoint) list(eligible = FALSE, objective = Inf, endpoint = endpoint)
  )
  expect_identical(theta, snapshot)
  expect_false(result$accepted)
  expect_identical(result$rejection_reasons, "no_armijo_eligible_step")
})

test_that("conditional eligibility fails closed on invalid score or Hessian", {
  good <- temporal_phylo_damped_newton_inner_eligibility(
    score = c(1e-10, -2e-10), hessian = diag(2), fixed_state_ok = TRUE
  )
  expect_true(good$eligible)

  high_score <- temporal_phylo_damped_newton_inner_eligibility(
    score = c(2e-7), hessian = matrix(1, 1, 1), fixed_state_ok = TRUE
  )
  expect_false(high_score$eligible)
  expect_true("random_score" %in% high_score$rejection_reasons)

  non_pd <- temporal_phylo_damped_newton_inner_eligibility(
    score = 0, hessian = matrix(-1, 1, 1), fixed_state_ok = TRUE
  )
  expect_false(non_pd$eligible)
  expect_true("random_hessian_positive_definite" %in% non_pd$rejection_reasons)
})

test_that("damped Newton plan retains the three failures and positional controls", {
  plan <- temporal_phylo_damped_newton_plan()
  expect_identical(plan$role, c(
    "retained_failure", "retained_failure", "retained_failure",
    "passing_control", "passing_control", "passing_control"
  ))
  expect_equal(plan$phi, c(0, .6, .6, -.4, 0, .6))
  expect_identical(plan$seed, c(2609188L, 2609183L, 2609185L,
    2609181L, 2609181L, 2609181L))
  expect_true(temporal_phylo_damped_newton_validate_plan(plan))
  expect_false(temporal_phylo_damped_newton_validate_plan(plan[-1L, ]))
})

test_that("runner asks TMB to report from its conditional mode", {
  runner <- readLines(testthat::test_path("..", "..", "dev", "temporal-program", "remote",
    "phylo-damped-newton.R"), warn = FALSE)
  expect_true(any(grepl("report <- obj\\$report\\(\\)", runner)))
  expect_false(any(grepl("report <- obj\\$report\\(theta\\)", runner)))
  expect_silent(parse(file = testthat::test_path("..", "..", "dev", "temporal-program", "remote",
    "phylo-damped-newton.R")))
})

test_that("DRAC envelope has the exact six-cell plan and a submit interlock", {
  root <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  task <- file.path(root, "dev", "temporal-program", "remote", "phylo-damped-newton-task.R")
  old <- setwd(root)
  on.exit(setwd(old), add = TRUE)
  output <- system2("Rscript", c("--vanilla", task, "--mode=plan"), stdout = TRUE, stderr = TRUE)
  expect_true(any(grepl("TEMPORAL_PHYLO_DAMPED_NEWTON_TASK_PLAN_PASS tasks=6", output, fixed = TRUE)))
  envelope <- readLines(file.path(root, "dev", "temporal-program", "remote",
    "phylo-damped-newton-drac.sh"), warn = FALSE)
  expect_true(any(grepl("--array=1-6%6", envelope, fixed = TRUE)))
  expect_true(any(grepl("TEMPORAL_PHYLO_DAMPED_NEWTON_DRAC_APPROVED=YES", envelope, fixed = TRUE)))
  expect_true(any(grepl("Refuse to construct a compute envelope from a dirty source checkout", envelope,
    fixed = TRUE)))
})
