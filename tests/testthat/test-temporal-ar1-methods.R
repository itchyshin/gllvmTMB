## Named migration fixture only.  Full lifecycle coverage lives in the
## sixth-source test files, where all AR1 and OU cells share one contract.
test_that("legacy temporal spelling resolves to the native temporal extractor", {
  dat <- expand.grid(series = paste0("s", 1:3), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  dat$value <- seq_len(nrow(dat)) / 10
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion,
      unique = TRUE), data = dat, unit = "series", family = gaussian(),
    silent = TRUE
  ))
  out <- extract_temporal(fit)
  expect_identical(out$parameters$mode, "latent")
  expect_identical(out$parameters$structure, "ar1")
  expect_true(all(out$variance$component == "temporal_Psi_variance"))
  expect_equal(nrow(out$pair_index), 9L)
})

test_that("temporal latent lifecycle retains public labels and guards", {
  set.seed(42)
  dat <- expand.grid(series = paste0("s", 1:3), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  dat$value <- rnorm(nrow(dat))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion,
      unique = TRUE), data = dat, unit = "series", family = gaussian(),
    silent = TRUE
  ))
  scores <- getLV(fit)
  ordination <- extract_ordination(fit, level = "unit")
  expect_equal(attr(scores, "temporal_index")$pair_id, rownames(scores))
  expect_equal(ordination$row_index$pair_id, rownames(ordination$scores))
  expect_equal(rownames(ordination$loadings), levels(fit$data$trait))
  prediction <- predict(fit)
  expect_equal(prediction[c("series", "occasion", "trait")],
    fit$data[c("series", "occasion", "trait")])
  expect_equal(dim(simulate(fit, nsim = 2, seed = 99)), c(nrow(dat), 2L))
  expect_s3_class(suppressWarnings(update(fit)), "gllvmTMB_multi")
  expect_error(predict(fit, newdata = dat), "newdata.*temporal")
  expect_error(confint(fit), "not available.*temporal")
  expect_error(bootstrap_Sigma(fit, n_boot = 2), "not available.*temporal")
  expect_error(ordination_uncertainty(fit), "not available.*temporal")
})

## Retain the old bounded acceptance checks that are independent of the retired
## IID-Psi/replicate interpretation.  Their more comprehensive six-source
## counterparts live in test-temporal-sixth-source-engine.R.
test_that("temporal reporting keeps the documented stable sign anchor", {
  loadings <- matrix(c(0, -2, 0.5), ncol = 1L,
    dimnames = list(c("first", "largest", "third"), "LV1"))
  sign <- gllvmTMB:::.temporal_report_sign(loadings)
  expect_true(sign$first_loading_negligible)
  expect_equal(sign$anchor_trait, "largest")
  expect_equal(sign$multiplier, -1)
})

test_that("temporal admission keeps missing-response, selection, and integration guards", {
  dat <- expand.grid(series = paste0("s", 1:3), occasion = 1:3,
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  dat$value <- seq_len(nrow(dat))
  missing <- dat
  missing$value[1L] <- NA_real_
  expect_error(gllvmTMB(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion),
    data = missing, unit = "series", family = gaussian()
  ), "complete Gaussian response")
  expect_error(select_lv(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion),
    data = dat, unit = "series", trait = "trait", d_max = 2
  ), "not available.*temporal")
  expect_error(gllvmTMB(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion),
    data = dat, unit = "series", family = gaussian(),
    control = gllvmTMBcontrol(integration = "va")
  ), "Laplace integration")
})
