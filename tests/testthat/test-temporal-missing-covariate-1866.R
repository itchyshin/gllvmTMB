## Twin of GLLVModels.jl #1287 / gllvmTMB #1866: missing covariates in
## temporal fits should error with the covariate, series, and time point.

.temporal_missing_cov_fixture <- function() {
  dat <- expand.grid(
    series = paste0("s", 1:2),
    occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  dat$value <- stats::rnorm(nrow(dat))
  dat$x <- stats::rnorm(nrow(dat))
  dat
}

test_that("temporal fits refuse a missing bare covariate with context (#1866)", {
  skip_on_cran()
  dat <- .temporal_missing_cov_fixture()
  bad_row <- 5L
  dat$x[bad_row] <- NA
  series <- dat$series[[bad_row]]
  occasion <- dat$occasion[[bad_row]]
  err <- expect_error(
    suppressWarnings(gllvmTMB(
      value ~ 0 + trait + x +
        temporal_indep(0 + trait | series, time = occasion),
      data = dat,
      unit = "series",
      trait = "trait",
      family = gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE),
      silent = TRUE
    )),
    class = "gllvmTMB_temporal_missing_covariate"
  )
  msg <- rlang::cnd_message(err)
  expect_match(msg, "`x`", fixed = TRUE)
  expect_match(msg, series, fixed = TRUE)
  expect_match(msg, as.character(occasion), fixed = TRUE)
})

test_that("complete covariates still allow a temporal fit (#1866)", {
  skip_on_cran()
  dat <- .temporal_missing_cov_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + x +
      temporal_indep(0 + trait | series, time = occasion),
    data = dat,
    unit = "series",
    trait = "trait",
    family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE),
    silent = TRUE
  ))
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active))
})