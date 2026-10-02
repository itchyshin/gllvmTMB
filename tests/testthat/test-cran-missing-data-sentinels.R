# Small fitted checks for the two documented missing-data reader workflows.
# These are executable path sentinels, not recovery or calibration evidence.

test_that("retained missing responses can be reconstructed", {
  set.seed(42)
  n_site <- 24L
  dat <- data.frame(site = factor(seq_len(n_site)), z = rnorm(n_site))
  dat$t1 <- 0.4 + 0.7 * dat$z + rnorm(n_site, sd = 0.4)
  dat$t2 <- -0.2 + 0.3 * dat$z + rnorm(n_site, sd = 0.5)
  dat$t1[c(3, 12)] <- NA_real_
  dat$t2[c(7, 19)] <- NA_real_

  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    traits(t1, t2) ~ 1 + z,
    data = dat,
    unit = "site",
    family = gaussian(),
    missing = miss_control(response = "include"),
    control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
  reconstructed <- predict_missing(fit, type = "response")

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_identical(fit$opt$convergence, 0L)
  expect_equal(nrow(reconstructed), 4L)
  expect_true(all(is.finite(reconstructed$est)))
})

test_that("modelled missing predictors can be read back with imputed()", {
  set.seed(47)
  n_site <- 30L
  dat <- data.frame(site = factor(seq_len(n_site)), z = rnorm(n_site))
  dat$x <- 0.3 + 0.8 * dat$z + rnorm(n_site, sd = 0.5)
  dat$t1 <- 0.5 + 1.1 * dat$x + rnorm(n_site, sd = 0.4)
  dat$t2 <- -0.2 + 1.1 * dat$x + rnorm(n_site, sd = 0.4)
  dat$x[c(4, 13, 21)] <- NA_real_

  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    traits(t1, t2) ~ 1 + mi(x),
    data = dat,
    unit = "site",
    family = gaussian(),
    impute = list(x = x ~ z),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = TRUE),
    silent = TRUE
  ))
  reconstructed <- imputed(fit)

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_identical(fit$opt$convergence, 0L)
  expect_true(all(c("variable", "level", "observed", "estimate") %in%
                    names(reconstructed)))
  expect_equal(nrow(reconstructed), 3L)
  expect_identical(reconstructed$variable, rep("x", 3L))
  expect_true(all(!reconstructed$observed))
  expect_true(all(is.finite(reconstructed$estimate)))
})
