test_that("bootstrap_temporal() refuses non-temporal fits", {
  fit <- structure(list(class = "gllvmTMB_multi"), class = "gllvmTMB_multi")
  expect_error(bootstrap_temporal(fit), "temporal fit")
})

test_that("bootstrap_temporal() validates n_boot", {
  fit <- structure(
    list(
      temporal = list(active = TRUE, mode = "indep", replicate_col = NULL),
      tmb_data = list(family_id_vec = 0L),
      formula = value ~ 1
    ),
    class = "gllvmTMB_multi"
  )
  expect_error(bootstrap_temporal(fit, n_boot = 0), "positive integer")
  expect_error(bootstrap_temporal(fit, n_boot = 1.5), "positive integer")
})

test_that("bootstrap_temporal() validates seed", {
  fit <- structure(
    list(
      temporal = list(active = TRUE, mode = "indep", replicate_col = NULL),
      tmb_data = list(family_id_vec = 0L),
      formula = value ~ 1
    ),
    class = "gllvmTMB_multi"
  )
  expect_error(bootstrap_temporal(fit, n_boot = 1L, seed = -1), "seed")
})

test_that(".temporal_bootstrap_time_estimate() maps AR1 and OU parameters", {
  ar1 <- structure(
    list(temporal = list(structure = "ar1")),
    class = "gllvmTMB_multi"
  )
  ou <- structure(
    list(temporal = list(structure = "ou")),
    class = "gllvmTMB_multi"
  )
  est_ar1 <- gllvmTMB:::.temporal_bootstrap_time_estimate(
    ar1, list(theta_temporal_time = 0.5)
  )
  est_ou <- gllvmTMB:::.temporal_bootstrap_time_estimate(
    ou, list(theta_temporal_time = log(2))
  )
  expect_true(est_ar1 > 0 && est_ar1 < 1)
  expect_equal(est_ou, 2)
})