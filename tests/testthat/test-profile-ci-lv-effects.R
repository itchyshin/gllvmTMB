## Internal prototype checks for predictor-informed latent-score effects B_lv.
## The public route is withheld until the nonlinear constraint and status
## contracts are redesigned.

test_that("withdrawn inference and Julia registry helpers are not exported", {
  exports <- getNamespaceExports("gllvmTMB")
  withdrawn <- c(
    "bootstrap_ci_lv_effects",
    "profile_ci_communality",
    "profile_ci_correlation",
    "profile_ci_lv_effects",
    "profile_ci_proportions",
    "profile_ci_repeatability",
    "profile_communality",
    "profile_correlation",
    "profile_proportions",
    "profile_repeatability",
    "gllvm_julia_capabilities",
    "gllvm_julia_gate_registry"
  )
  expect_length(intersect(withdrawn, exports), 0L)
})
test_that("profile_ci_lv_effects errors without a predictor-informed latent term", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(1)
  n <- 20L
  df <- expand.grid(
    unit = factor(paste0("u", seq_len(n))),
    trait = factor(paste0("t", 1:3))
  )
  df$value <- stats::rnorm(nrow(df))
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df, unit = "unit", trait = "trait", family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ))
  expect_error(profile_ci_lv_effects(fit), regexp = "predictor-informed latent")
})

test_that("profile_ci_lv_effects defaults to chi-square and requires explicit t df", {
  fit <- structure(
    list(
      report = list(
        B_lv_unit = matrix(0.4, 1, 1, dimnames = list("t1", "x")),
        Lambda_B = matrix(1, 1, 1)
      ),
      opt = list(par = c(theta_rr_B = 1, alpha_lv_B = 0.4))
    ),
    class = "gllvmTMB_multi"
  )
  testthat::local_mocked_bindings(
    .profile_ci_via_refit = function(...) list(lower = 0.1, upper = 0.8),
    .package = "gllvmTMB"
  )

  default <- profile_ci_lv_effects(fit)
  expect_identical(default$reference, "chisq")
  expect_true(is.na(default$df))
  expect_error(
    profile_ci_lv_effects(fit, reference = "t"),
    regexp = "requires an explicit.*df"
  )
  sensitivity <- profile_ci_lv_effects(fit, reference = "t", df = 12)
  expect_identical(sensitivity$reference, "t")
  expect_equal(sensitivity$df, 12)
})

test_that("extract_lv_effects rejects withdrawn profile and bootstrap routes", {
  fit <- structure(
    list(
      use = list(lv_B = TRUE),
      data = data.frame(trait = factor("t1")),
      trait_col = "trait",
      lv = list(X_lv_B = matrix(1, 1, 1, dimnames = list(NULL, "x")))
    ),
    class = "gllvmTMB_multi"
  )
  expect_error(
    extract_lv_effects(fit, type = "trait_effect", method = "profile"),
    class = "gllvmTMB_lv_interval_withdrawn"
  )
  expect_error(
    extract_lv_effects(fit, type = "trait_effect", method = "bootstrap"),
    class = "gllvmTMB_lv_interval_withdrawn"
  )
})
