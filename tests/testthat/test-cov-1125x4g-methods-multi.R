## Coverage (cursor-cloud-1125x4g): R/methods-gllvmTMB.R S3 accessors on tiny fits.

.cov1125x4g_gauss <- function() {
  set.seed(112544)
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

test_that("update.gllvmTMB_multi() refuses non-temporal fits", {
  fit <- .cov1125x4g_gauss()
  expect_error(update(fit), "temporal")
})

test_that("stats::sigma() remains refused on multi fits", {
  fit <- .cov1125x4g_gauss()
  expect_error(stats::sigma(fit), "not defined")
})

test_that("logLik, AIC, BIC and deviance agree on a tiny gaussian fit", {
  fit <- .cov1125x4g_gauss()
  ll <- logLik(fit)
  expect_s3_class(ll, "logLik")
  expect_true(is.finite(as.numeric(ll)))
  expect_equal(as.numeric(deviance(fit)), -2 * as.numeric(ll), tolerance = 1e-6)
  aic <- AIC(fit)
  bic <- BIC(fit)
  expect_true(aic > as.numeric(ll))
  expect_true(bic >= aic)
  expect_equal(AIC(fit, k = 2), AIC(fit))
})

test_that("nobs() and fitted() return aligned lengths", {
  fit <- .cov1125x4g_gauss()
  expect_equal(nobs(fit), nrow(fit$data))
  fitv <- fitted(fit)
  expect_s3_class(fitv, "data.frame")
  expect_equal(nrow(fitv), nrow(fit$data))
  expect_true(all(is.finite(unlist(fitv))))
})

test_that("residuals() and model.matrix() expose training rows", {
  fit <- .cov1125x4g_gauss()
  r <- residuals(fit, type = "pearson")
  expect_length(r, nrow(fit$data))
  X <- model.matrix(fit)
  expect_equal(nrow(X), nrow(fit$data))
  expect_gt(ncol(X), 0L)
})

test_that("summary() and print() stay quiet on a converged tiny fit", {
  fit <- .cov1125x4g_gauss()
  expect_s3_class(summary(fit), "summary.gllvmTMB_multi")
  expect_output(print(fit), "gllvmTMB")
})

test_that("tidy.gllvmTMB_multi() returns fixed-effect rows", {
  fit <- .cov1125x4g_gauss()
  td <- tidy(fit)
  expect_s3_class(td, "data.frame")
  expect_gt(nrow(td), 0L)
  expect_true(all(c("term", "estimate") %in% names(td)))
})

test_that("coef() exposes named fixed effects", {
  fit <- .cov1125x4g_gauss()
  b <- coef(fit)
  expect_type(b, "double")
  expect_named(b)
  expect_gt(length(b), 0L)
  expect_error(vcov(fit), "standard errors")
})

test_that(".modal_integer_id() picks a modal value", {
  expect_equal(gllvmTMB:::.modal_integer_id(c(1L, 1L, 2L)), 1L)
  expect_equal(gllvmTMB:::.modal_integer_id(NA_integer_), NA_integer_)
  expect_equal(gllvmTMB:::.modal_integer_id(c(NA, 3L, 3L)), 3L)
})

test_that("family() and formula() accessors round-trip", {
  fit <- .cov1125x4g_gauss()
  expect_s3_class(family(fit), "family")
  expect_s3_class(formula(fit), "formula")
  expect_match(deparse(formula(fit)[[2]]), "value")
})

test_that("logLik and extractors stay finite on tiny fits", {
  fit <- .cov1125x4g_gauss()
  expect_true(is.finite(as.numeric(logLik(fit))))
  sig <- extract_Sigma(fit)
  expect_true(is.matrix(sig) || is.data.frame(sig))
  cor <- extract_correlations(fit)
  expect_s3_class(cor, "data.frame")
  expect_gt(nrow(cor), 0L)
})

test_that("predict() returns link-scale values in-sample", {
  fit <- .cov1125x4g_gauss()
  eta <- predict(fit)
  expect_length(eta, nrow(fit$data))
  expect_true(all(is.finite(eta)))
})