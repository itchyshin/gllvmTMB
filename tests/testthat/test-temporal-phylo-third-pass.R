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
