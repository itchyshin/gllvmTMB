## The admitted native-family sentinel suite lives in
## test-missing-response-nongaussian.R. This sentinel retains the categorical
## multinomial likelihood because its existing fitted checks are skipped on
## CRAN. It tests an executable fit path, not coefficient recovery.

test_that("multinomial likelihood executes and fits all observed categories", {
  set.seed(71024)
  n <- 90L
  value <- factor(sample(c("a", "b", "c"), n, replace = TRUE),
                  levels = c("a", "b", "c"))
  dat <- data.frame(unit = factor(seq_len(n)), trait = factor("morph"), value)
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait, data = dat, family = gllvmTMB::multinomial(),
    trait = "trait", unit = "unit", silent = TRUE
  ))

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_identical(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_true(all(is.finite(fit$opt$par)))
  expect_true(all(fit$tmb_data$family_id_vec == 16L))
})
