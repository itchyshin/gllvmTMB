## Coverage (cursor-cloud-1125x4g): R/check-consistency.R and R/confint-inspect.R guards.

.cov1125x4g_gauss <- function() {
  set.seed(112542)
  n <- 12L
  df <- data.frame(
    unit = factor(rep(seq_len(n / 2L), each = 2L)),
    trait = factor(rep(c("a", "b"), n / 2L)),
    value = stats::rnorm(n)
  )
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    unit = "unit",
    trait = "trait",
    family = gaussian(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE, warn_runaway = FALSE),
    silent = TRUE
  )))
}

test_that(".gllvmTMB_cc_simulation_available() detects the live simulate path", {
  fit <- .cov1125x4g_gauss()
  expect_type(gllvmTMB:::.gllvmTMB_cc_simulation_available(fit), "logical")
})

test_that("gllvmTMB_check_consistency() aborts when simulation is unavailable", {
  fit <- structure(
    list(
      tmb_data = list(y = c(1, 2)),
      tmb_obj = list(simulate = function(...) list(y = c(1, 2)))
    ),
    class = "gllvmTMB_multi"
  )
  expect_error(
    gllvmTMB_check_consistency(fit, n_sim = 2L),
    class = "gllvmTMB_check_consistency_simulation_unavailable"
  )
})

test_that("print.gllvmTMB_check_consistency() returns its input", {
  x <- structure(
    list(
      n_sim = 5L,
      marginal_p_value = 0.12,
      joint_p_value = NA_real_,
      diagnostics = "no_centring_warning",
      flagged_parameters = character(),
      threshold = 0.1
    ),
    class = "gllvmTMB_check_consistency"
  )
  expect_identical(print(x), x)
  expect_equal(x$n_sim, 5L)
  expect_equal(x$diagnostics, "no_centring_warning")
})

test_that("print.gllvmTMB_check_consistency() preserves flagged parameters", {
  x <- structure(
    list(
      n_sim = 3L,
      marginal_p_value = NA_real_,
      joint_p_value = 0.5,
      diagnostics = c("information_matrix_singular"),
      flagged_parameters = c("b_fix[1]"),
      threshold = 0.05
    ),
    class = "gllvmTMB_check_consistency"
  )
  expect_identical(print(x), x)
  expect_equal(x$flagged_parameters, "b_fix[1]")
  expect_true("information_matrix_singular" %in% x$diagnostics)
})

test_that("confint_inspect() refuses non-multi fits", {
  expect_error(confint_inspect(data.frame(), parm = "x"), "gllvmTMB")
})

test_that("confint_inspect() validates parm", {
  fit <- .cov1125x4g_gauss()
  expect_error(confint_inspect(fit), "single character")
  expect_error(confint_inspect(fit, parm = c("a", "b")), "single character")
})

test_that("confint_inspect() errors on unknown profile targets", {
  fit <- .cov1125x4g_gauss()
  expect_error(
    confint_inspect(fit, parm = "___not_a_target___"),
    "No matching profile target"
  )
})