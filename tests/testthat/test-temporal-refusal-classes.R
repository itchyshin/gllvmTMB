## Pins the condition classes (not just message text) of the temporal
## forecast / bootstrap / generic-inference refusals, plus the documented
## success shape of forecast_temporal().  Refs the temporal program tests.
skip_on_cran()

## Copy of .temporal_forecast_fixture() from test-temporal-program-forecast.R
## (test files cannot rely on each other).
.temporal_refusal_fixture <- function(structure = c("ar1", "ou")) {
  structure <- match.arg(structure)
  data <- expand.grid(
    series = c("s1", "s2"), occasion = c(1L, 2L, 3L),
    trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  data$elapsed <- c(0, 1.5, 4)[match(data$occasion, c(1L, 2L, 3L))]
  data$value <- with(data, as.numeric(factor(trait)) / 4 +
    as.numeric(factor(series)) / 5 + occasion / 10)
  list(
    data = data,
    time = if (identical(structure, "ar1")) "occasion" else "elapsed",
    structure = structure
  )
}

.refusal_ctl <- gllvmTMBcontrol(se = FALSE)

.refusal_fit_indep <- function() {
  fx <- .temporal_refusal_fixture("ar1")
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = fx$data, unit = "series", family = gaussian(), silent = TRUE,
    control = .refusal_ctl
  ))
}

.refusal_future <- function(times = 4L, series = c("s1", "s2")) {
  expand.grid(series = series, occasion = times,
    trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
}

## Larger panel for fits that need more than two series.
.refusal_bigger_data <- function() {
  d <- expand.grid(series = paste0("s", 1:4), occasion = 1:5,
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  set.seed(20261019L)
  d$value <- stats::rnorm(nrow(d))
  d
}

test_that("forecast_temporal refusal classes are stable", {
  fit <- .refusal_fit_indep()
  future <- .refusal_future()

  expect_error(forecast_temporal(fit, .refusal_future(series = c("s1", "new"))),
    class = "gllvmTMB_temporal_forecast_new_series")
  expect_error(forecast_temporal(fit, future[-1L, , drop = FALSE]),
    class = "gllvmTMB_temporal_forecast_panel")
  expect_error(forecast_temporal(fit, .refusal_future(times = 3L)),
    class = "gllvmTMB_temporal_forecast_not_future")
  expect_error(forecast_temporal(fit, .refusal_future(times = 1L)),
    class = "gllvmTMB_temporal_forecast_not_future")

  ## Only a late time for one series is enough to fail the whole request.
  mixed <- rbind(.refusal_future(times = 4L, series = "s1"),
    .refusal_future(times = 2L, series = "s2"))
  expect_error(forecast_temporal(fit, mixed),
    class = "gllvmTMB_temporal_forecast_not_future")
})

test_that("forecast_temporal refuses non-indep modes by class", {
  fx <- .temporal_refusal_fixture("ar1")
  fit_dep <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion),
    data = fx$data, unit = "series", family = gaussian(), silent = TRUE,
    control = .refusal_ctl
  ))
  expect_error(forecast_temporal(fit_dep, .refusal_future()),
    class = "gllvmTMB_temporal_forecast_mode")
})

test_that("forecast_temporal and bootstrap_temporal refuse replicated and composed fits by class", {
  d <- expand.grid(series = paste0("s", 1:3), occasion = 1:3,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  set.seed(260916L); d$value <- stats::rnorm(nrow(d))
  rep_fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion, replicate = measurement),
    data = d, unit = "series", family = gaussian(), silent = TRUE,
    control = .refusal_ctl))
  fut <- expand.grid(series = paste0("s", 1:3), occasion = 4L,
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  expect_error(forecast_temporal(rep_fit, fut),
    class = "gllvmTMB_temporal_forecast_replicated")

  big <- .refusal_bigger_data()
  comp_fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion) +
    indep(0 + trait | series),
    data = big, unit = "series", family = gaussian(), silent = TRUE,
    control = .refusal_ctl))
  fut_big <- .refusal_future(times = 6L, series = paste0("s", 1:4))
  expect_error(forecast_temporal(comp_fit, fut_big),
    class = "gllvmTMB_temporal_forecast_composed")
  expect_error(bootstrap_temporal(comp_fit, n_boot = 1L),
    class = "gllvmTMB_temporal_bootstrap_composed")
})

test_that("generic iid inference on a temporal_latent fit carries its class", {
  big <- .refusal_bigger_data()
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait +
    temporal_latent(0 + trait | series, time = occasion),
    data = big, unit = "series", family = gaussian(), silent = TRUE,
    control = .refusal_ctl))
  expect_error(confint(fit), class = "gllvmTMB_temporal_inference_unsupported")
  expect_error(profile_ci_communality(fit),
    class = "gllvmTMB_temporal_inference_unsupported")
  expect_error(bootstrap_Sigma(fit, n_boot = 2L),
    class = "gllvmTMB_temporal_inference_unsupported")
})

test_that("forecast_temporal success shape: columns, row order, se.fit", {
  fit <- .refusal_fit_indep()
  future <- .refusal_future(times = c(4L, 5L))

  plain <- forecast_temporal(fit, future)
  expect_identical(names(plain), c(names(future), "est"))
  expect_equal(nrow(plain), nrow(future))

  with_se <- forecast_temporal(fit, future, se.fit = TRUE)
  expect_identical(names(with_se), c(names(future), "est", "se.fit"))
  expect_equal(with_se$est, plain$est)
  expect_true(all(is.finite(with_se$se.fit)) && all(with_se$se.fit >= 0))
  expect_equal(as.character(with_se$series), future$series)
  expect_equal(as.character(with_se$trait), future$trait)
  expect_equal(with_se$occasion, future$occasion)

  ## Output row order follows newdata, whatever its order.
  set.seed(1L)
  perm <- sample(nrow(future))
  shuffled <- future[perm, , drop = FALSE]
  out <- forecast_temporal(fit, shuffled, se.fit = TRUE)
  expect_equal(as.character(out$series), shuffled$series)
  expect_equal(out$occasion, shuffled$occasion)
  expect_equal(as.character(out$trait), shuffled$trait)
  expect_equal(out$est, with_se$est[perm], tolerance = 1e-8)
  expect_equal(out$se.fit, with_se$se.fit[perm], tolerance = 1e-8)
})

test_that("forecast_temporal rejects duplicate rows and malformed se.fit", {
  fit <- .refusal_fit_indep()
  future <- .refusal_future()
  expect_error(forecast_temporal(fit, rbind(future, future[1L, ])),
    "duplicate")
  expect_error(forecast_temporal(fit, future, se.fit = "yes"), "se.fit")
  expect_error(forecast_temporal(fit, future, se.fit = c(TRUE, FALSE)), "se.fit")
  expect_error(forecast_temporal(fit, future, se.fit = NA), "se.fit")
  expect_error(forecast_temporal(fit, future, se.fit = NULL), "se.fit")
})
