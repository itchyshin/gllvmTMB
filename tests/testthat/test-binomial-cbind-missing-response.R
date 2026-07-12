# Regression: cbind(succ, fail) binomial responses with masked rows under
# miss_control(response = "include") must not crash. Before the fix,
# `n_trials <- succ + fail` and the non-negativity / positive-trials checks
# ran on NA (masked) rows, so `if (any(succ < 0))` / `if (any(n_trials <= 0))`
# hit `if (NA)` -> "missing value where TRUE/FALSE needed"
# (R/fit-multi.R response-processing block).

test_that("cbind binomial + masked response (response='include') fits, no crash", {
  set.seed(1)
  n_unit <- 40L
  traits <- c("t1", "t2", "t3")
  df <- expand.grid(unit = factor(seq_len(n_unit)), trait = factor(traits))
  N <- 6L
  df$succ <- rbinom(nrow(df), N, 0.4)
  df$fail <- N - df$succ

  ## Mask two unit-trait cells: both columns NA, as response="include" expects.
  masked <- c(5L, 71L)
  df$succ[masked] <- NA
  df$fail[masked] <- NA

  fit <- gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit",
    family = binomial(),
    missing = miss_control(response = "include")
  )

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(is.finite(as.numeric(logLik(fit))))
  ## Masked rows are kept (response="include") and gated out, not dropped.
  expect_identical(sum(fit$tmb_data$is_y_observed == 0L), length(masked))
})
