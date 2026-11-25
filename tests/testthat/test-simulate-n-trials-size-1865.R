## Twin of GLLVModels.jl #1208 / gllvmTMB #1865: trial-count payloads must
## match response dimensions before simulate() draws.

test_that(".draw_y_per_family() refuses a short n_trials vector (#1865)", {
  n <- 12L
  fit <- list(
    tmb_data = list(
      family_id_vec = rep(1L, n),
      link_id_vec = rep(0L, n),
      trait_id = rep(0L, n),
      n_trials = rep(5L, 8L)
    ),
    report = list()
  )
  expect_error(
    gllvmTMB:::.draw_y_per_family(fit, rep(0, n)),
    class = "gllvmTMB_simulate_n_trials_length"
  )
})

test_that("a matching-length n_trials vector still draws (#1865)", {
  set.seed(1865)
  n <- 200L
  Nt <- 8L
  fit <- list(
    tmb_data = list(
      family_id_vec = rep(1L, n),
      link_id_vec = rep(0L, n),
      trait_id = rep(0L, n),
      n_trials = rep(Nt, n)
    ),
    report = list()
  )
  y <- gllvmTMB:::.draw_y_per_family(fit, rep(qlogis(0.4), n))
  expect_equal(length(y), n)
  expect_true(all(y >= 0 & y <= Nt))
})

test_that(".gllvm_julia_check_N_dimensions() names the required size (#1865)", {
  err <- expect_error(
    gllvmTMB:::.gllvm_julia_check_N_dimensions(matrix(1, 2, 3), p = 2L, n = 10L),
    "`N` must be 2 x 10"
  )
  expect_match(conditionMessage(err), "traits x units", fixed = TRUE)
})