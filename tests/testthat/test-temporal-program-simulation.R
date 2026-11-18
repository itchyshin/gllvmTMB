.temporal_program_simulation_fixture <- function(unique = FALSE) {
  phi <- 0.6
  z_innovation <- matrix(c(1, 0, 0), nrow = 1L)
  z_state <- matrix(c(1, phi, phi^2), nrow = 1L)
  q_innovation <- matrix(c(2, 0, 0), nrow = 1L)
  q_state <- matrix(c(4, 2.4, 1.44), nrow = 1L)
  list(
    temporal = list(active = TRUE, unique = unique, structure = "ar1"),
    tmb_data = list(
      trait_id = rep.int(0L, 3L), n_traits = 1L, n_temporal_states = 3L,
      temporal_state_id = 0:2, temporal_predecessor = c(-1L, 0L, 1L),
      temporal_rank = 1L, temporal_gap = c(0L, 1L, 1L),
      temporal_elapsed = c(0, 1, 1)
    ),
    tmb_obj = list(env = list(parList = function(...) list(
      z_temporal = z_innovation,
      q_temporal = q_innovation,
      theta_temporal_time = atanh(phi / (1 - 1e-6)),
      theta_temporal_diag = log(2),
      log_sigma_eps = log(0.25)
    ))),
    opt = list(par = 0),
    report = list(
      eta = drop(z_state + if (unique) q_state else 0),
      Lambda_temporal = matrix(1, nrow = 1L),
      z_temporal_state = z_state,
      q_temporal_state = q_state
    )
  )
}

test_that("unconditional temporal simulation removes fitted recursive states", {
  fit <- .temporal_program_simulation_fixture(unique = TRUE)
  local_mocked_bindings(rnorm = function(n, ...) rep.int(0, n), .package = "stats")

  draw <- gllvmTMB:::.simulate_temporal_response(fit, redraw_scores = TRUE)

  expect_equal(draw, rep.int(0, 3L), tolerance = 1e-14)
})

test_that("conditional temporal simulation remains centered on the fitted predictor", {
  fit <- .temporal_program_simulation_fixture(unique = TRUE)
  local_mocked_bindings(rnorm = function(n, ...) rep.int(0, n), .package = "stats")

  draw <- gllvmTMB:::.simulate_temporal_response(fit, redraw_scores = FALSE)

  expect_equal(draw, fit$report$eta, tolerance = 1e-14)
})
