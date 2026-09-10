test_that("the temporal phylogenetic third-pass candidate is frozen", {
  source(testthat::test_path("..", "..", "dev", "temporal-program", "remote",
    "phylo-third-pass-common.R"), local = TRUE)
  controls <- temporal_phylo_third_pass_controls()

  expect_true(temporal_phylo_third_pass_validate_controls(controls))
  expect_identical(controls$optimizer, "optim")
  expect_identical(controls$method, "BFGS")
  expect_identical(controls$optimizer_passes, 3L)
  expect_identical(controls$maxit, 3000L)
  expect_identical(controls$reltol, 1e-14)
  expect_identical(controls$gradient_gate, 1e-3)
})

test_that("third-pass qualification plan retains failures and fixed controls", {
  source(testthat::test_path("..", "..", "dev", "temporal-program", "remote",
    "phylo-third-pass-common.R"), local = TRUE)
  plan <- temporal_phylo_third_pass_plan()

  expect_identical(names(plan), c("role", "phi", "seed"))
  expect_identical(plan$role, c(
    "retained_failure", "retained_failure", "retained_failure",
    "passing_control", "passing_control", "passing_control"
  ))
  expect_equal(plan$phi, c(0, .6, .6, -.4, 0, .6))
  expect_identical(plan$seed, c(2609188L, 2609183L, 2609185L,
    2609181L, 2609181L, 2609181L))
  expect_true(temporal_phylo_third_pass_validate_plan(plan))

  altered <- plan[-1L, , drop = FALSE]
  expect_false(temporal_phylo_third_pass_validate_plan(altered))
})

test_that("third-pass receipt requires every exact continuation diagnostic", {
  source(testthat::test_path("..", "..", "dev", "temporal-program", "remote",
    "phylo-third-pass-common.R"), local = TRUE)
  receipt <- data.frame(
    role = "passing_control", phi = -.4, seed = 2609181L,
    pass_1_convergence = 0L, pass_2_convergence = 0L,
    pass_3_convergence = 0L, pass_2_accepted = TRUE,
    pass_3_accepted = TRUE, final_objective = 1,
    final_outer_gradient = 5e-4, final_fresh_state_ok = TRUE,
    final_fd_all_coordinates = TRUE, stringsAsFactors = FALSE
  )
  expect_true(temporal_phylo_third_pass_validate_receipt(receipt))

  receipt$final_fd_all_coordinates <- FALSE
  expect_false(temporal_phylo_third_pass_validate_receipt(receipt))
})

test_that("third-pass adjudication names every failed gate", {
  source(testthat::test_path("..", "..", "dev", "temporal-program", "remote",
    "phylo-third-pass-common.R"), local = TRUE)
  controls <- temporal_phylo_third_pass_controls()
  baseline <- list(
    history = data.frame(pass = 1:2, objective = c(2, 1),
      end = I(list(c(a = 1), c(a = 1)))),
    state = list(objective = 1, temporal_variance = 1, phylo_variance = 1,
      residual_variance = 1, eta = 1, phi = 0)
  )
  candidate <- list(
    history = data.frame(pass = 1:3, objective = c(2, 1, 1),
      convergence = c(0L, 0L, 0L), accepted = c(TRUE, TRUE, TRUE),
      finite_difference_all_finite = c(TRUE, TRUE, TRUE),
      finite_difference_n_coordinates = c(1L, 1L, 1L),
      finite_difference_n_finite = c(1L, 1L, 1L),
      fresh_state_ok = c(TRUE, TRUE, TRUE), fresh_objective = c(2, 1, 1),
      outer_gradient_max = c(0, 0, controls$gradient_gate * 2),
      end = I(list(c(a = 1), c(a = 1), c(a = 1)))),
    state = baseline$state
  )
  result <- temporal_phylo_third_pass_adjudicate(baseline, candidate)
  expect_false(result$accepted)
  expect_identical(result$rejection_reasons, "gradient")
})
